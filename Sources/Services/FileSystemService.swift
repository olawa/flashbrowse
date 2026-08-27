import Foundation
import AppKit
import Darwin

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
        foldersFirst: Bool,
        folderSizes: [URL: Int64]? = nil
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
                let s1 = (a.isDirectory ? folderSizes?[a.url] : a.size) ?? (a.isDirectory ? -1 : 0)
                let s2 = (b.isDirectory ? folderSizes?[b.url] : b.size) ?? (b.isDirectory ? -1 : 0)
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
    
    public func moveToTrash(urls: [URL]) -> [String] {
        var errors: [String] = []
        for url in urls {
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            } catch {
                errors.append("\(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        return errors
    }
    
    public func copyItems(urls: [URL], to destinationDirectory: URL) -> [String] {
        let fm = FileManager.default
        var errors: [String] = []
        for url in urls {
            let dest = destinationDirectory.appendingPathComponent(url.lastPathComponent)
            do {
                try fm.copyItem(at: url, to: dest)
            } catch {
                errors.append("\(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        return errors
    }
    
    public func moveItems(urls: [URL], to destinationDirectory: URL) -> [String] {
        let fm = FileManager.default
        var errors: [String] = []
        for url in urls {
            let dest = destinationDirectory.appendingPathComponent(url.lastPathComponent)
            do {
                try fm.moveItem(at: url, to: dest)
            } catch {
                errors.append("\(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        return errors
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
    
    // MARK: - Volume & Disk Storage (df -h)
    public func getVolumeStorageInfo(at url: URL) -> VolumeStorageInfo? {
        let path = (url.path.isEmpty ? "/" : url.path)
        var stat = statvfs()
        
        var total: Int64 = 0
        var available: Int64 = 0
        var used: Int64 = 0
        
        if statvfs(path, &stat) == 0 {
            let frSize = Int64(stat.f_frsize)
            total = Int64(stat.f_blocks) * frSize
            available = Int64(stat.f_bavail) * frSize
            let free = Int64(stat.f_bfree) * frSize
            used = max(0, total - free)
        }
        
        // Fallback or validation
        if total <= 0 {
            if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: path) {
                total = (attrs[.systemSize] as? Int64) ?? 0
                let free = (attrs[.systemFreeSize] as? Int64) ?? 0
                available = free
                used = max(0, total - free)
            }
        }
        
        guard total > 0 else { return nil }
        
        var volumeName = "Macintosh HD"
        if let values = try? url.resourceValues(forKeys: [.volumeNameKey]),
           let vName = values.volumeName, !vName.isEmpty {
            volumeName = vName
        } else if path != "/" && !path.hasPrefix("/Users") {
            volumeName = url.lastPathComponent
        }
        
        let usedRatio = min(1.0, max(0.0, Double(used) / Double(total)))
        let freeRatio = max(0.0, 1.0 - usedRatio)
        
        return VolumeStorageInfo(
            volumeName: volumeName,
            totalBytes: total,
            availableBytes: available,
            usedBytes: used,
            usagePercentage: usedRatio,
            freePercentage: freeRatio
        )
    }
    
    public func volumeAvailableCapacity(at url: URL) -> String {
        if let info = getVolumeStorageInfo(at: url) {
            return info.statusSummary
        }
        return ""
    }
}
