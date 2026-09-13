import Foundation

public class DiskUsageService {
    public static let shared = DiskUsageService()
    
    private init() {}
    
    // MARK: - Scan Directory Disk Usage (du -h -d 1)
    public func analyzeDirectory(url: URL) async -> DirectoryUsageReport {
        let startTime = Date()
        let path = url.standardized.path
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let fm = FileManager.default
                var folderSizesKB: [String: Int64] = [:]
                
                // 1. Run du -k -d 1 for high-speed subfolder tree scanning.
                // du writes one line per subfolder and a "Permission denied" line
                // per unreadable one, so both streams are drained concurrently -
                // either of them filling its pipe buffer would hang the scan.
                do {
                    let result = try ProcessRunner.run(
                        executableURL: URL(fileURLWithPath: "/usr/bin/du"),
                        arguments: ["-k", "-d", "1", path]
                    )

                    for line in result.stdoutString.components(separatedBy: "\n") {
                        let parts = line.split(separator: "\t", maxSplits: 1).map(String.init)
                        if parts.count == 2 {
                            let kbStr = parts[0].trimmingCharacters(in: .whitespaces)
                            let itemPath = parts[1].trimmingCharacters(in: .whitespaces)
                            if let kb = Int64(kbStr), itemPath != path {
                                folderSizesKB[itemPath] = kb
                            }
                        }
                    }
                } catch {
                    // du failed, will fallback to FileManager
                }
                
                // 2. Read direct directory contents for accurate file & folder metadata
                var rawEntries: [(name: String, path: String, url: URL, size: Int64, isDir: Bool, count: Int?)] = []
                
                let options: FileManager.DirectoryEnumerationOptions = []
                let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey, .fileSizeKey, .isPackageKey]
                
                if let contents = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: Array(resourceKeys), options: options) {
                    for itemURL in contents {
                        let itemName = itemURL.lastPathComponent
                        let itemPath = itemURL.path
                        
                        var isDir: ObjCBool = false
                        fm.fileExists(atPath: itemPath, isDirectory: &isDir)
                        
                        var sizeBytes: Int64 = 0
                        var count: Int? = nil
                        
                        if isDir.boolValue {
                            if let kb = folderSizesKB[itemPath] {
                                sizeBytes = kb * 1024
                            } else {
                                // Fallback fast item count
                                if let subEntries = try? fm.contentsOfDirectory(atPath: itemPath) {
                                    count = subEntries.count
                                }
                                sizeBytes = 0
                            }
                        } else {
                            if let res = try? itemURL.resourceValues(forKeys: [.fileSizeKey]), let fSize = res.fileSize {
                                sizeBytes = Int64(fSize)
                            } else if let attrs = try? fm.attributesOfItem(atPath: itemPath), let aSize = attrs[.size] as? Int64 {
                                sizeBytes = aSize
                            }
                        }
                        
                        rawEntries.append((
                            name: itemName,
                            path: itemPath,
                            url: itemURL,
                            size: sizeBytes,
                            isDir: isDir.boolValue,
                            count: count
                        ))
                    }
                }
                
                let totalBytes = rawEntries.reduce(0) { $0 + $1.size }
                
                let entries: [FolderUsageEntry] = rawEntries.map { item in
                    let proportion = totalBytes > 0 ? Double(item.size) / Double(totalBytes) : 0.0
                    return FolderUsageEntry(
                        name: item.name,
                        path: item.path,
                        url: item.url,
                        sizeBytes: item.size,
                        isDirectory: item.isDir,
                        itemCount: item.count,
                        proportion: proportion
                    )
                }.sorted { a, b in
                    if a.sizeBytes != b.sizeBytes {
                        return a.sizeBytes > b.sizeBytes
                    }
                    if a.isDirectory != b.isDirectory {
                        return a.isDirectory && !b.isDirectory
                    }
                    return a.name.localizedStandardCompare(b.name) == .orderedAscending
                }
                
                let duration = Date().timeIntervalSince(startTime)
                let report = DirectoryUsageReport(
                    directoryURL: url,
                    totalSizeBytes: totalBytes,
                    entries: entries,
                    scanDuration: duration
                )
                
                continuation.resume(returning: report)
            }
        }
    }
    
    // MARK: - Single Folder / Item Size Calculation (du -sk)
    public func calculateSingleItemSize(url: URL) async -> Int64 {
        let path = url.standardized.path
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try ProcessRunner.run(
                        executableURL: URL(fileURLWithPath: "/usr/bin/du"),
                        arguments: ["-sk", path]
                    )

                    if let firstLine = result.stdoutString.components(separatedBy: "\n").first {
                        let parts = firstLine.split(separator: "\t", maxSplits: 1).map(String.init)
                        if let kbStr = parts.first?.trimmingCharacters(in: .whitespaces),
                           let kb = Int64(kbStr) {
                            continuation.resume(returning: kb * 1024)
                            return
                        }
                    }
                } catch {
                    // Fallback
                }
                
                // Fallback size using attributes
                if let attrs = try? FileManager.default.attributesOfItem(atPath: path),
                   let size = attrs[.size] as? Int64 {
                    continuation.resume(returning: size)
                } else {
                    continuation.resume(returning: 0)
                }
            }
        }
    }
}
