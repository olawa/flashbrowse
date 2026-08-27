import Foundation
import SwiftUI

public struct FolderUsageEntry: Identifiable, Sendable, Hashable {
    public var id: String { path }
    public let name: String
    public let path: String
    public let url: URL
    public let sizeBytes: Int64
    public let isDirectory: Bool
    public let itemCount: Int?
    public let proportion: Double // 0.0 to 1.0
    
    private static let byteFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f
    }()
    
    public init(
        name: String,
        path: String,
        url: URL,
        sizeBytes: Int64,
        isDirectory: Bool,
        itemCount: Int? = nil,
        proportion: Double = 0.0
    ) {
        self.name = name
        self.path = path
        self.url = url
        self.sizeBytes = sizeBytes
        self.isDirectory = isDirectory
        self.itemCount = itemCount
        self.proportion = proportion
    }
    
    public var formattedSize: String {
        Self.byteFormatter.string(fromByteCount: sizeBytes)
    }
    
    public var percentString: String {
        let pct = proportion * 100.0
        if pct < 0.1 && pct > 0 {
            return "< 0.1%"
        }
        return String(format: "%.1f%%", pct)
    }
    
    public var iconName: String {
        if isDirectory { return "folder.fill" }
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "bam", "sam", "cram": return "dna"
        case "vcf", "bcf": return "waveform.path.ecg"
        case "fq", "fastq": return "text.alignleft"
        case "gtf", "gff", "bed": return "bookmark.circle.fill"
        case "tsv", "csv", "tab": return "tablecells"
        case "py", "sh", "rs", "c", "cpp", "swift", "ts", "js": return "curlybraces"
        case "md", "txt", "pdf": return "doc.text.fill"
        case "png", "jpg", "jpeg", "svg": return "photo"
        case "zip", "tar", "gz", "bz2", "xz": return "doc.zipper"
        case "app": return "app.dashed"
        default: return "doc.fill"
        }
    }
}

public struct DirectoryUsageReport: Sendable {
    public let directoryURL: URL
    public let totalSizeBytes: Int64
    public let entries: [FolderUsageEntry]
    public let scanDuration: TimeInterval
    
    private static let byteFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f
    }()
    
    public init(
        directoryURL: URL,
        totalSizeBytes: Int64,
        entries: [FolderUsageEntry],
        scanDuration: TimeInterval
    ) {
        self.directoryURL = directoryURL
        self.totalSizeBytes = totalSizeBytes
        self.entries = entries
        self.scanDuration = scanDuration
    }
    
    public var formattedTotalSize: String {
        Self.byteFormatter.string(fromByteCount: totalSizeBytes)
    }
    
    public var folderCount: Int {
        entries.filter { $0.isDirectory }.count
    }
    
    public var fileCount: Int {
        entries.filter { !$0.isDirectory }.count
    }
    
    public var summaryText: String {
        "\(formattedTotalSize) • \(entries.count) items (\(folderCount) folders, \(fileCount) files)"
    }
    
    public var cliFormattedText: String {
        var lines: [String] = []
        lines.append("# Disk Usage (du -h) for: \(directoryURL.path)")
        lines.append("# Total: \(formattedTotalSize) in \(entries.count) items (scanned in \(String(format: "%.2f", scanDuration))s)")
        lines.append("SIZE\tPERCENT\tTYPE\tNAME")
        for entry in entries {
            let typeStr = entry.isDirectory ? "DIR" : "FILE"
            lines.append("\(entry.formattedSize)\t\(entry.percentString)\t\(typeStr)\t\(entry.name)")
        }
        return lines.joined(separator: "\n")
    }
}
