import Foundation
import AppKit
import SwiftUI
import UniformTypeIdentifiers

public enum FileCategory {
    case folder
    case image
    case video
    case audio
    case code
    case document
    case archive
    case executable
    case other
}

public struct FileItem: Identifiable, Hashable {
    public var id: URL { url }
    public let url: URL
    public let name: String
    public let lowercaseName: String
    public let isDirectory: Bool
    public let isPackage: Bool
    public let isSymlink: Bool
    public let isHidden: Bool
    public let size: Int64?
    public let dateModified: Date?
    public let kindDescription: String
    public let category: FileCategory
    public let sfSymbolName: String
    public let categoryColor: Color
    public var itemCount: Int?
    
    public static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter
    }()
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM HH:mm"
        return formatter
    }()
    
    public var formattedSize: String {
        if isDirectory {
            if let count = itemCount {
                return "\(count) items"
            }
            return "--"
        }
        guard let size = size else { return "--" }
        return FileItem.byteFormatter.string(fromByteCount: size)
    }
    
    public var formattedDate: String {
        guard let date = dateModified else { return "--" }
        return FileItem.dateFormatter.string(from: date)
    }
    
    public var shortFormattedDate: String {
        guard let date = dateModified else { return "--" }
        return FileItem.shortDateFormatter.string(from: date)
    }
    
    public init(url: URL, itemCount: Int? = nil) {
        self.url = url
        let n = url.lastPathComponent
        self.name = n
        self.lowercaseName = n.lowercased()
        self.isHidden = n.hasPrefix(".")
        self.itemCount = itemCount
        
        let resourceKeys: Set<URLResourceKey> = [
            .isDirectoryKey,
            .isPackageKey,
            .isSymbolicLinkKey,
            .fileSizeKey,
            .contentModificationDateKey,
            .localizedTypeDescriptionKey
        ]
        
        let values = try? url.resourceValues(forKeys: resourceKeys)
        
        var isDir = values?.isDirectory ?? false
        let isSymlink = values?.isSymbolicLink ?? false
        if isSymlink && !isDir {
            var targetIsDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &targetIsDir), targetIsDir.boolValue {
                isDir = true
            }
        }
        let isPkg = values?.isPackage ?? false
        self.isPackage = isPkg
        self.isDirectory = isDir && !isPkg
        self.isSymlink = isSymlink
        self.size = (self.isDirectory) ? nil : Int64(values?.fileSize ?? 0)
        self.dateModified = values?.contentModificationDate
        
        let ext = url.pathExtension.lowercased()
        if self.isDirectory {
            self.category = .folder
            self.kindDescription = "Folder"
            self.sfSymbolName = "folder.fill"
            self.categoryColor = Color.flashbrowseAccent // Ubuntu Orange #E95420
            
            // Item count loaded lazily to avoid blocking main thread
        } else {
            switch ext {
            case "png", "jpg", "jpeg", "gif", "webp", "svg", "bmp", "tiff", "heic":
                self.category = .image
                self.sfSymbolName = "photo.fill"
                self.categoryColor = Color(red: 0.2, green: 0.6, blue: 0.86)
            case "mp4", "mov", "mkv", "avi", "webm", "m4v":
                self.category = .video
                self.sfSymbolName = "film.fill"
                self.categoryColor = Color(red: 0.6, green: 0.3, blue: 0.8)
            case "mp3", "wav", "flac", "aac", "ogg", "m4a":
                self.category = .audio
                self.sfSymbolName = "music.note"
                self.categoryColor = Color(red: 0.9, green: 0.4, blue: 0.6)
            case "swift", "rs", "py", "c", "cpp", "h", "hpp", "js", "ts", "json", "toml", "yaml", "yml", "sh", "zsh", "go", "java", "html", "css":
                self.category = .code
                self.sfSymbolName = "curlybraces"
                self.categoryColor = Color(red: 0.18, green: 0.8, blue: 0.44)
            case "pdf", "txt", "md", "doc", "docx", "pages", "rtf", "csv", "tsv":
                self.category = .document
                self.sfSymbolName = "doc.text.fill"
                self.categoryColor = Color(red: 0.3, green: 0.5, blue: 0.9)
            case "zip", "tar", "gz", "bz2", "xz", "7z", "dmg", "pkg":
                self.category = .archive
                self.sfSymbolName = "archivebox.fill"
                self.categoryColor = Color(red: 0.95, green: 0.65, blue: 0.15)
            case "command", "app":
                self.category = .executable
                self.sfSymbolName = "terminal.fill"
                self.categoryColor = Color(red: 0.4, green: 0.75, blue: 0.4)
            default:
                self.category = .other
                self.sfSymbolName = "doc.fill"
                self.categoryColor = Color.secondary
            }
            
            if let typeDesc = values?.localizedTypeDescription {
                self.kindDescription = typeDesc
            } else {
                self.kindDescription = ext.isEmpty ? "File" : "\(ext.uppercased()) File"
            }
        }
    }
    
    /// Fast memory initializer for cached indexes without disk stat I/O
    public init(url: URL, size: Int64?, dateModified: Date?, kindDescription: String? = nil) {
        self.url = url
        let n = url.lastPathComponent
        self.name = n
        self.lowercaseName = n.lowercased()
        self.isHidden = n.hasPrefix(".")
        self.itemCount = nil
        self.isPackage = false
        self.isDirectory = false
        self.isSymlink = false
        self.size = size
        self.dateModified = dateModified
        
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "png", "jpg", "jpeg", "gif", "webp", "svg", "bmp", "tiff", "heic":
            self.category = .image
            self.sfSymbolName = "photo.fill"
            self.categoryColor = Color(red: 0.2, green: 0.6, blue: 0.86)
        case "mp4", "mov", "mkv", "avi", "webm", "m4v":
            self.category = .video
            self.sfSymbolName = "film.fill"
            self.categoryColor = Color(red: 0.6, green: 0.3, blue: 0.8)
        case "mp3", "wav", "flac", "aac", "ogg", "m4a":
            self.category = .audio
            self.sfSymbolName = "music.note"
            self.categoryColor = Color(red: 0.9, green: 0.4, blue: 0.6)
        case "swift", "rs", "py", "c", "cpp", "h", "hpp", "js", "ts", "json", "toml", "yaml", "yml", "sh", "zsh", "go", "java", "html", "css":
            self.category = .code
            self.sfSymbolName = "curlybraces"
            self.categoryColor = Color(red: 0.18, green: 0.8, blue: 0.44)
        case "pdf", "txt", "md", "doc", "docx", "pages", "rtf", "csv", "tsv":
            self.category = .document
            self.sfSymbolName = "doc.text.fill"
            self.categoryColor = Color(red: 0.3, green: 0.5, blue: 0.9)
        case "zip", "tar", "gz", "bz2", "xz", "7z", "dmg", "pkg":
            self.category = .archive
            self.sfSymbolName = "archivebox.fill"
            self.categoryColor = Color(red: 0.95, green: 0.65, blue: 0.15)
        case "command", "app":
            self.category = .executable
            self.sfSymbolName = "terminal.fill"
            self.categoryColor = Color(red: 0.4, green: 0.75, blue: 0.4)
        default:
            if ["bam", "sam", "cram", "bai", "crai"].contains(ext) {
                self.category = .other
                self.sfSymbolName = "dna"
                self.categoryColor = Color.flashbrowseAccent
            } else if ["vcf", "bcf"].contains(ext) {
                self.category = .other
                self.sfSymbolName = "waveform.path.ecg"
                self.categoryColor = Color(red: 0.85, green: 0.25, blue: 0.45)
            } else {
                self.category = .other
                self.sfSymbolName = "doc.fill"
                self.categoryColor = Color.secondary
            }
        }
        self.kindDescription = kindDescription ?? (ext.isEmpty ? "File" : "\(ext.uppercased()) File")
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
    
    public static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        lhs.url == rhs.url
    }
}
