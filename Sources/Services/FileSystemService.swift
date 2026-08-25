import Foundation
import AppKit

public enum SortField: String, CaseIterable, Identifiable {
    case name = "Name"
    case dateModified = "Date Modified"
    case size = "Size"
    case kind = "Kind"
    
    public var id: String { rawValue }
}

public class FileSystemService {
    public static let shared = FileSystemService()
    
    private var directorySource: DispatchSourceFileSystemObject?
    private var directoryFileDescriptor: Int32 = -1
    
    private init() {}
    
    public func contentsOfDirectory(at url: URL, showHidden: Bool) -> [FileItem] {
        let fileManager = FileManager.default
        let options: FileManager.DirectoryEnumerationOptions = showHidden ? [] : [.skipsHiddenFiles]
        
        guard let fileURLs = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [
                .isDirectoryKey,
                .isPackageKey,
                .fileSizeKey,
                .contentModificationDateKey,
                .localizedTypeDescriptionKey
            ],
            options: options
        ) else {
            return []
        }
        
        return fileURLs.map { FileItem(url: $0) }
    }
    
    public func recursiveSearch(query: String, in rootURL: URL, showHidden: Bool, maxResults: Int = 200) -> [FileItem] {
        let fm = FileManager.default
        let options: FileManager.DirectoryEnumerationOptions = showHidden ? [] : [.skipsHiddenFiles]
        
        guard let enumerator = fm.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
            options: options
        ) else {
            return []
        }
        
        let q = query.lowercased()
        var results: [FileItem] = []
        
        while let fileURL = enumerator.nextObject() as? URL {
            if fileURL.lastPathComponent.lowercased().contains(q) {
                results.append(FileItem(url: fileURL))
                if results.count >= maxResults {
                    break
                }
            }
        }
        
        return results
    }
    
    public func sort(
        items: [FileItem],
        by field: SortField,
        ascending: Bool,
        foldersFirst: Bool
    ) -> [FileItem] {
        return items.sorted { a, b in
            if foldersFirst && a.isDirectory != b.isDirectory {
                return a.isDirectory && !b.isDirectory
            }
            
            let comparison: ComparisonResult
            switch field {
            case .name:
                comparison = a.name.localizedStandardCompare(b.name)
            case .dateModified:
                let d1 = a.dateModified ?? Date.distantPast
                let d2 = b.dateModified ?? Date.distantPast
                if d1 == d2 {
                    comparison = a.name.localizedStandardCompare(b.name)
                } else {
                    comparison = d1 < d2 ? .orderedAscending : .orderedDescending
                }
            case .size:
                let s1 = a.size ?? (a.isDirectory ? -1 : 0)
                let s2 = b.size ?? (b.isDirectory ? -1 : 0)
                if s1 == s2 {
                    comparison = a.name.localizedStandardCompare(b.name)
                } else {
                    comparison = s1 < s2 ? .orderedAscending : .orderedDescending
                }
            case .kind:
                if a.kindDescription == b.kindDescription {
                    comparison = a.name.localizedStandardCompare(b.name)
                } else {
                    comparison = a.kindDescription.localizedStandardCompare(b.kindDescription)
                }
            }
            
            return ascending ? (comparison == .orderedAscending) : (comparison == .orderedDescending)
        }
    }
    
    // MARK: - Directory Live Monitoring
    public func startMonitoring(url: URL, onChange: @escaping () -> Void) {
        stopMonitoring()
        
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }
        
        self.directoryFileDescriptor = fd
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .link, .delete, .rename, .attrib],
            queue: DispatchQueue.main
        )
        
        source.setEventHandler {
            onChange()
        }
        
        source.setCancelHandler {
            close(fd)
        }
        
        source.resume()
        self.directorySource = source
    }
    
    public func stopMonitoring() {
        if let source = directorySource {
            source.cancel()
            directorySource = nil
            directoryFileDescriptor = -1
        }
    }
    
    // MARK: - Actions
    public func openItem(url: URL) {
        NSWorkspace.shared.open(url)
    }
    
    public func openInTerminal(url: URL) {
        let targetDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true ? url.path : url.deletingLastPathComponent().path
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Terminal", targetDirectory]
        try? process.run()
    }
    
    public func revealInFinder(url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    
    public func moveToTrash(urls: [URL]) {
        for url in urls {
            try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
        }
    }
    
    public func copyItems(urls: [URL], to destinationDirectory: URL) {
        let fm = FileManager.default
        for url in urls {
            let dest = destinationDirectory.appendingPathComponent(url.lastPathComponent)
            try? fm.copyItem(at: url, to: dest)
        }
    }
    
    public func moveItems(urls: [URL], to destinationDirectory: URL) {
        let fm = FileManager.default
        for url in urls {
            let dest = destinationDirectory.appendingPathComponent(url.lastPathComponent)
            try? fm.moveItem(at: url, to: dest)
        }
    }
    
    public func createDirectory(named name: String, in parentURL: URL) {
        let target = parentURL.appendingPathComponent(name)
        try? FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
    }
    
    public func copyPathToClipboard(urls: [URL]) {
        let paths = urls.map { $0.path }.joined(separator: "\n")
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(paths, forType: .string)
    }
    
    // MARK: - Volume Info
    public func volumeAvailableCapacity(at url: URL) -> String {
        do {
            let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey])
            if let available = values.volumeAvailableCapacityForImportantUsage,
               let total = values.volumeTotalCapacity {
                let formatter = ByteCountFormatter()
                formatter.countStyle = .file
                let freeStr = formatter.string(fromByteCount: available)
                let totalStr = formatter.string(fromByteCount: Int64(total))
                return "\(freeStr) free of \(totalStr)"
            }
        } catch {
            // Fallback
        }
        return ""
    }
}
