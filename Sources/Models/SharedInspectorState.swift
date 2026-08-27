import Foundation
import SwiftUI
import AppKit
import Combine
import CoreGraphics

public struct ExtendedFileMetadata {
    public let name: String
    public let path: String
    public let sizeFormatted: String
    public let exactBytes: Int64
    public let dateCreated: String
    public let dateModified: String
    public let permissions: String
    public let kindDescription: String
    public let isDirectory: Bool
    public let dimensions: String?
    
    public init(url: URL) {
        self.name = url.lastPathComponent
        self.path = url.path
        
        let fm = FileManager.default
        let attrs = (try? fm.attributesOfItem(atPath: url.path)) ?? [:]
        
        let exact = (attrs[.size] as? Int64) ?? 0
        self.exactBytes = exact
        
        let byteFormatter = ByteCountFormatter()
        byteFormatter.countStyle = .file
        self.sizeFormatted = byteFormatter.string(fromByteCount: exact)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d MMM yyyy, HH:mm"
        
        let created = attrs[.creationDate] as? Date ?? Date()
        let modified = attrs[.modificationDate] as? Date ?? Date()
        self.dateCreated = dateFormatter.string(from: created)
        self.dateModified = dateFormatter.string(from: modified)
        
        let posix = (attrs[.posixPermissions] as? NSNumber)?.intValue ?? 0o644
        self.permissions = String(format: "%o", posix)
        
        var isDir: ObjCBool = false
        fm.fileExists(atPath: url.path, isDirectory: &isDir)
        self.isDirectory = isDir.boolValue
        
        let typeVals = try? url.resourceValues(forKeys: [.localizedTypeDescriptionKey])
        self.kindDescription = typeVals?.localizedTypeDescription ?? (isDir.boolValue ? "Folder" : "File")
        
        // Image Dimensions if applicable
        if let imgSource = CGImageSourceCreateWithURL(url as CFURL, nil),
           let properties = CGImageSourceCopyPropertiesAtIndex(imgSource, 0, nil) as? [CFString: Any],
           let width = properties[kCGImagePropertyPixelWidth] as? Int,
           let height = properties[kCGImagePropertyPixelHeight] as? Int {
            self.dimensions = "\(width) × \(height) px"
        } else {
            self.dimensions = nil
        }
    }
}

public enum InspectorContentType {
    case image
    case pdf
    case spreadsheet
    case officeDoc
    case media
    case markdown
    case html
    case code
    case text
    case folder
    case generic
}

public enum PhotoOrganizerAction {
    case trashed(originalURL: URL)
    case picked(originalURL: URL, pickedURL: URL)
}

@MainActor
public class SharedInspectorState: ObservableObject {
    public static let shared = SharedInspectorState()
    
    public static let imageExtensions = ["png", "jpg", "jpeg", "webp", "gif", "svg", "bmp", "tiff", "heic", "ico", "psd", "dng", "cr2", "nef", "arw", "raw"]
    
    @Published public var currentURL: URL? {
        didSet {
            loadPreview()
        }
    }
    
    @Published public var metadata: ExtendedFileMetadata?
    @Published public var contentType: InspectorContentType = .generic
    @Published public var textContent: String?
    @Published public var previewImage: NSImage?
    @Published public var parsedTableRows: [[String]] = []
    @Published public var isInspectorWindowOpen: Bool = false
    @Published public var isInspectorVisible: Bool = true
    @Published public var isInspectorDetached: Bool = false
    
    // Photo Organizer & Sibling Navigation
    @Published public var siblingImageURLs: [URL] = []
    @Published public var isPhotoOrganizerActive: Bool = false
    @Published public var isLightboxMode: Bool = false
    @Published public var photoActionBanner: String? = nil
    @Published public var undoStack: [PhotoOrganizerAction] = []
    
    private var bannerTask: Task<Void, Never>?
    
    // Remote Scroll Channel
    @Published public var scrollDeltaY: CGFloat = 0
    @Published public var scrollPulse: Int = 0
    
    // Live Trackpad / Touch Horizontal Swipe
    @Published public var cumulativeSwipeOffset: CGFloat = 0
    private var lastSwipeActionTime: Date = Date.distantPast
    private var resetSwipeTask: Task<Void, Never>?
    
    public var currentImageIndex: Int {
        guard let cur = currentURL, let idx = siblingImageURLs.firstIndex(of: cur) else { return 0 }
        return idx
    }
    
    public var totalImageCount: Int {
        siblingImageURLs.count
    }
    
    public var canUndo: Bool {
        !undoStack.isEmpty
    }
    
    private init() {}
    
    public func toggleInspector() {
        if isInspectorDetached {
            if isInspectorWindowOpen {
                InspectorWindowController.shared.closeWindow()
            } else {
                InspectorWindowController.shared.showWindow()
            }
        } else {
            isInspectorVisible.toggle()
        }
    }
    
    public func detachInspector() {
        isInspectorDetached = true
        InspectorWindowController.shared.showWindow()
    }
    
    public func dockInspector() {
        isInspectorDetached = false
        InspectorWindowController.shared.closeWindow()
        isInspectorVisible = true
    }
    
    public func updateTarget(url: URL?) {
        guard self.currentURL != url else { return }
        self.currentURL = url
    }
    
    public func scrollInspector(by delta: CGFloat) {
        self.scrollDeltaY = delta
        self.scrollPulse &+= 1
    }
    
    public func handleHorizontalScroll(deltaX: CGFloat) {
        guard contentType == .image else { return }
        let now = Date()
        guard now.timeIntervalSince(lastSwipeActionTime) > 0.35 else { return }
        
        cumulativeSwipeOffset += deltaX
        
        resetSwipeTask?.cancel()
        resetSwipeTask = Task {
            try? await Task.sleep(nanoseconds: 220_000_000)
            if !Task.isCancelled {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    self.cumulativeSwipeOffset = 0
                }
            }
        }
        
        let threshold: CGFloat = 35.0
        if cumulativeSwipeOffset > threshold {
            lastSwipeActionTime = now
            resetSwipeTask?.cancel()
            withAnimation(.easeOut(duration: 0.15)) {
                self.cumulativeSwipeOffset = 180
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                if self.isPhotoOrganizerActive {
                    self.pickCurrentImage()
                } else {
                    self.previousImage()
                }
                self.cumulativeSwipeOffset = 0
            }
        } else if cumulativeSwipeOffset < -threshold {
            lastSwipeActionTime = now
            resetSwipeTask?.cancel()
            withAnimation(.easeOut(duration: 0.15)) {
                self.cumulativeSwipeOffset = -180
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                if self.isPhotoOrganizerActive {
                    self.trashCurrentImage()
                } else {
                    self.nextImage()
                }
                self.cumulativeSwipeOffset = 0
            }
        }
    }
    
    public func showBanner(_ message: String) {
        self.photoActionBanner = message
        bannerTask?.cancel()
        bannerTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if !Task.isCancelled {
                self.photoActionBanner = nil
            }
        }
    }
    
    // MARK: - Sibling Image Navigation
    public func scanSiblingImages(for url: URL) {
        let parent = url.deletingLastPathComponent()
        guard let contents = try? FileManager.default.contentsOfDirectory(at: parent, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            self.siblingImageURLs = [url]
            return
        }
        
        let images = contents.filter { file in
            let ext = file.pathExtension.lowercased()
            return Self.imageExtensions.contains(ext)
        }.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        
        self.siblingImageURLs = images
    }
    
    public func nextImage() {
        guard !siblingImageURLs.isEmpty else { return }
        let idx = currentImageIndex
        if idx + 1 < siblingImageURLs.count {
            let nextURL = siblingImageURLs[idx + 1]
            self.currentURL = nextURL
            NotificationCenter.default.post(name: .flashbrowseInspectorSelectedURL, object: nextURL)
        } else {
            showBanner("Reached last image")
        }
    }
    
    public func previousImage() {
        guard !siblingImageURLs.isEmpty else { return }
        let idx = currentImageIndex
        if idx > 0 {
            let prevURL = siblingImageURLs[idx - 1]
            self.currentURL = prevURL
            NotificationCenter.default.post(name: .flashbrowseInspectorSelectedURL, object: prevURL)
        } else {
            showBanner("At first image")
        }
    }
    
    // MARK: - Photo Organizing Actions (Keep / Discard / Undo)
    public func pickCurrentImage(subfolder: String = "_picked") {
        guard let url = currentURL else { return }
        let parent = url.deletingLastPathComponent()
        let destDir = parent.appendingPathComponent(subfolder)
        let destURL = destDir.appendingPathComponent(url.lastPathComponent)
        
        let fm = FileManager.default
        do {
            if !fm.fileExists(atPath: destDir.path) {
                try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
            }
            try fm.moveItem(at: url, to: destURL)
            undoStack.append(.picked(originalURL: url, pickedURL: destURL))
            
            showBanner("⭐ Picked → \(subfolder)/\(url.lastPathComponent)")
            
            // Advance to next image
            advanceAfterRemoval(of: url)
            NotificationCenter.default.post(name: .flashbrowseReloadDirectory, object: nil)
        } catch {
            showBanner("⚠️ Failed to pick: \(error.localizedDescription)")
        }
    }
    
    public func trashCurrentImage() {
        guard let url = currentURL else { return }
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            undoStack.append(.trashed(originalURL: url))
            
            showBanner("🗑️ Discarded \(url.lastPathComponent)")
            
            // Advance to next image
            advanceAfterRemoval(of: url)
            NotificationCenter.default.post(name: .flashbrowseReloadDirectory, object: nil)
        } catch {
            showBanner("⚠️ Failed to trash: \(error.localizedDescription)")
        }
    }
    
    private func advanceAfterRemoval(of removedURL: URL) {
        if let idx = siblingImageURLs.firstIndex(of: removedURL) {
            siblingImageURLs.remove(at: idx)
            if idx < siblingImageURLs.count {
                let nextURL = siblingImageURLs[idx]
                self.currentURL = nextURL
                NotificationCenter.default.post(name: .flashbrowseInspectorSelectedURL, object: nextURL)
            } else if !siblingImageURLs.isEmpty {
                let prevURL = siblingImageURLs.last!
                self.currentURL = prevURL
                NotificationCenter.default.post(name: .flashbrowseInspectorSelectedURL, object: prevURL)
            } else {
                self.currentURL = nil
            }
        }
    }
    
    public func undoLastAction() {
        guard let lastAction = undoStack.popLast() else { return }
        let fm = FileManager.default
        
        switch lastAction {
        case .picked(let originalURL, let pickedURL):
            do {
                if fm.fileExists(atPath: pickedURL.path) {
                    try fm.moveItem(at: pickedURL, to: originalURL)
                    scanSiblingImages(for: originalURL)
                    self.currentURL = originalURL
                    showBanner("↩️ Restored \(originalURL.lastPathComponent)")
                    NotificationCenter.default.post(name: .flashbrowseInspectorSelectedURL, object: originalURL)
                    NotificationCenter.default.post(name: .flashbrowseReloadDirectory, object: nil)
                }
            } catch {
                showBanner("⚠️ Undo failed: \(error.localizedDescription)")
            }
        case .trashed(let originalURL):
            showBanner("↩️ Trashed item is in macOS Trash (open Trash to put back)")
            scanSiblingImages(for: originalURL)
        }
    }
    
    private func loadPreview() {
        guard let url = currentURL else {
            metadata = nil
            contentType = .generic
            textContent = nil
            previewImage = nil
            parsedTableRows = []
            return
        }
        
        self.metadata = ExtendedFileMetadata(url: url)
        self.parsedTableRows = []
        
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            contentType = .folder
            textContent = nil
            previewImage = nil
            return
        }
        
        let ext = url.pathExtension.lowercased()
        
        // 1. PDF Documents
        if ext == "pdf" {
            self.contentType = .pdf
            self.textContent = nil
            self.previewImage = nil
            return
        }
        
        // 2. Spreadsheet Documents (Excel .xlsx, .xls, Numbers, CSV, TSV)
        if ["xlsx", "xls", "numbers", "csv", "tsv", "tab"].contains(ext) {
            self.contentType = .spreadsheet
            self.previewImage = nil
            
            // For CSV/TSV: parse fast structured table preview
            if ["csv", "tsv", "tab"].contains(ext) {
                if let data = try? Data(contentsOf: url, options: .mappedIfSafe),
                   let str = String(data: data.prefix(500000), encoding: .utf8) {
                    let delimiter: Character = (ext == "csv") ? "," : "\t"
                    let rows = str.components(separatedBy: "\n").prefix(200).compactMap { line -> [String]? in
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.isEmpty { return nil }
                        return trimmed.split(separator: delimiter, omittingEmptySubsequences: false).map(String.init)
                    }
                    self.parsedTableRows = rows
                    self.textContent = str
                }
            }
            return
        }
        
        // 3. Office & Rich Documents (Word .docx, .doc, Pages, Keynote, PPTX, RTF)
        if ["docx", "doc", "pages", "rtf", "rtfd", "odt", "pptx", "ppt", "keynote"].contains(ext) {
            self.contentType = .officeDoc
            self.textContent = nil
            self.previewImage = nil
            return
        }
        
        // 4. Audio & Video Media
        if ["mp4", "mov", "m4v", "m4a", "mp3", "wav", "flac", "aac", "avi", "mkv", "webm"].contains(ext) {
            self.contentType = .media
            self.textContent = nil
            self.previewImage = nil
            return
        }
        
        // 5. Image Preview
        if Self.imageExtensions.contains(ext) {
            if let img = NSImage(contentsOf: url) {
                self.contentType = .image
                self.previewImage = img
                self.textContent = nil
                if !siblingImageURLs.contains(url) {
                    scanSiblingImages(for: url)
                }
                return
            }
        }
        
        // 6. HTML Preview
        if ["html", "htm", "xhtml"].contains(ext) {
            if let data = try? Data(contentsOf: url, options: .mappedIfSafe),
               let str = String(data: data.prefix(1000000), encoding: .utf8) {
                self.contentType = .html
                self.textContent = str
                self.previewImage = nil
                return
            }
        }
        
        // 7. Markdown Preview
        if ["md", "markdown", "mdown", "mkdn"].contains(ext) {
            if let data = try? Data(contentsOf: url, options: .mappedIfSafe),
               let str = String(data: data.prefix(500000), encoding: .utf8) {
                self.contentType = .markdown
                self.textContent = str
                self.previewImage = nil
                return
            }
        }
        
        // 8. Code / Script / Text Preview (VS Code Highlighting)
        let codeExtensions: Set<String> = [
            "swift", "rs", "py", "pyw", "ipynb", "r", "rmd", "smk", "c", "cpp", "cc", "cxx", "c++", "h", "hpp", "h++",
            "js", "ts", "jsx", "tsx", "mjs", "cjs", "json", "jsonl", "geojson", "toml", "yaml", "yml",
            "sh", "zsh", "bash", "fish", "command", "go", "java", "kt", "kts", "scala", "lua", "perl", "pl", "pm", "rb", "php",
            "css", "scss", "sass", "less", "sql", "xml", "plist", "log", "txt", "text", "vcf", "bed", "gtf", "gff", "gff3",
            "fasta", "fa", "fna", "faa", "dockerfile", "makefile", "env", "ini", "conf", "cfg", "diff", "patch"
        ]
        
        let filenameLower = url.lastPathComponent.lowercased()
        let isCommonCodeFile = filenameLower == "makefile" || filenameLower.hasPrefix("makefile.") ||
                               filenameLower == "dockerfile" || filenameLower.hasPrefix("dockerfile.") ||
                               filenameLower == "snakefile" || filenameLower.hasPrefix(".bash") ||
                               filenameLower.hasPrefix(".zsh") || filenameLower.hasPrefix(".env") ||
                               filenameLower == ".gitignore" || filenameLower == ".dockerignore"
        
        if codeExtensions.contains(ext) || isCommonCodeFile {
            if let data = try? Data(contentsOf: url, options: .mappedIfSafe),
               let str = String(data: data.prefix(2_000_000), encoding: .utf8) {
                self.contentType = .code
                self.textContent = str
                self.previewImage = nil
                return
            }
        }
        
        // Fallback: Check if smaller unknown file (< 500KB) is plain UTF-8 text / script
        if let data = try? Data(contentsOf: url, options: .mappedIfSafe), data.count < 500_000,
           let str = String(data: data, encoding: .utf8), !str.contains("\0") {
            self.contentType = .code
            self.textContent = str
            self.previewImage = nil
            return
        }
        
        self.contentType = .generic
        self.textContent = nil
        self.previewImage = nil
    }
}
