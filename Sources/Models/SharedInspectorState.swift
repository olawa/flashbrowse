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
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        
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
    case markdown
    case html
    case code
    case text
    case folder
    case generic
}

@MainActor
public class SharedInspectorState: ObservableObject {
    public static let shared = SharedInspectorState()
    
    @Published public var currentURL: URL? {
        didSet {
            loadPreview()
        }
    }
    
    @Published public var metadata: ExtendedFileMetadata?
    @Published public var contentType: InspectorContentType = .generic
    @Published public var textContent: String?
    @Published public var previewImage: NSImage?
    @Published public var isInspectorWindowOpen: Bool = false
    
    // Remote Scroll Channel
    @Published public var scrollDeltaY: CGFloat = 0
    @Published public var scrollPulse: Int = 0
    
    private init() {}
    
    public func updateTarget(url: URL?) {
        guard self.currentURL != url else { return }
        self.currentURL = url
    }
    
    public func scrollInspector(by delta: CGFloat) {
        self.scrollDeltaY = delta
        self.scrollPulse &+= 1
    }
    
    private func loadPreview() {
        guard let url = currentURL else {
            metadata = nil
            contentType = .generic
            textContent = nil
            previewImage = nil
            return
        }
        
        self.metadata = ExtendedFileMetadata(url: url)
        
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            contentType = .folder
            textContent = nil
            previewImage = nil
            return
        }
        
        let ext = url.pathExtension.lowercased()
        
        // Image Preview
        if ["png", "jpg", "jpeg", "webp", "gif", "svg", "bmp", "tiff", "heic", "ico"].contains(ext) {
            if let img = NSImage(contentsOf: url) {
                self.contentType = .image
                self.previewImage = img
                self.textContent = nil
                return
            }
        }
        
        // HTML Preview
        if ["html", "htm", "xhtml"].contains(ext) {
            if let data = try? Data(contentsOf: url, options: .mappedIfSafe),
               let str = String(data: data.prefix(1000000), encoding: .utf8) {
                self.contentType = .html
                self.textContent = str
                self.previewImage = nil
                return
            }
        }
        
        // Markdown Preview
        if ["md", "markdown", "mdown", "mkdn"].contains(ext) {
            if let data = try? Data(contentsOf: url, options: .mappedIfSafe),
               let str = String(data: data.prefix(500000), encoding: .utf8) {
                self.contentType = .markdown
                self.textContent = str
                self.previewImage = nil
                return
            }
        }
        
        // Code / Text Preview
        let codeExtensions = [
            "swift", "rs", "py", "c", "cpp", "h", "hpp", "js", "ts", "jsx", "tsx",
            "json", "toml", "yaml", "yml", "sh", "zsh", "bash", "go", "java", "kt",
            "css", "scss", "sass", "less", "sql", "xml", "plist", "csv", "tsv", "log", "txt"
        ]
        
        if codeExtensions.contains(ext) {
            if let data = try? Data(contentsOf: url, options: .mappedIfSafe),
               let str = String(data: data.prefix(65536), encoding: .utf8) {
                self.contentType = .code
                self.textContent = str
                self.previewImage = nil
                return
            }
        }
        
        self.contentType = .generic
        self.textContent = nil
        self.previewImage = nil
    }
}
