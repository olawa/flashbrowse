import Foundation
import Combine

public struct DirectoryIndexGroup: Identifiable, Hashable {
    public var id: URL { directoryURL }
    public let directoryURL: URL
    public let directoryName: String
    public let relativePath: String
    public var items: [FileItem]
    
    public init(directoryURL: URL, baseRoot: URL, items: [FileItem]) {
        self.directoryURL = directoryURL
        self.directoryName = directoryURL.lastPathComponent.isEmpty ? "/" : directoryURL.lastPathComponent
        
        let full = directoryURL.path
        let rootPath = baseRoot.path
        if full.hasPrefix(rootPath) {
            let rel = String(full.dropFirst(rootPath.count))
            self.relativePath = rel.isEmpty ? "./" : (rel.hasPrefix("/") ? String(rel.dropFirst()) : rel)
        } else {
            self.relativePath = directoryURL.path
        }
        self.items = items
    }
}

public struct CachedFileRecord: Codable {
    public let path: String
    public let size: Int64?
    public let dateModified: Date?
    public let kindDescription: String?
}

public struct CachedGroupRecord: Codable {
    public let directoryPath: String
    public let relativePath: String
    public let items: [CachedFileRecord]
}

public struct CachedIndexPayload: Codable {
    public let formatVersion: Int
    public let appVersion: String
    public let indexId: String
    public let rootPath: String
    public let createdAt: Date
    public let totalFiles: Int
    public let groups: [CachedGroupRecord]
}

@MainActor
public class IndexService: ObservableObject {
    public static let shared = IndexService()
    
    nonisolated public static var currentAppVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.6.0"
    }
    
    /// Protected system & heavy cache directories that trigger TCC permission popups or stall scans
    nonisolated public static let excludedDirectoryNames: Set<String> = [
        "music",
        "pictures",
        "photos library.photoslibrary",
        "movies",
        "podcasts",
        "library",
        "node_modules",
        "target",
        "build",
        "dist",
        ".trash",
        "caches",
        ".cache",
        ".cargo",
        ".rustup",
        ".npm",
        ".git",
        ".svn",
        ".hg"
    ]
    
    @Published public var activeIndex: FileTypeIndex?
    @Published public var currentRootURL: URL?
    @Published public var indexedGroups: [DirectoryIndexGroup] = []
    @Published public var selectedDirectories: Set<URL> = []
    @Published public var isScanning: Bool = false
    @Published public var totalFilesFound: Int = 0
    @Published public var searchQuery: String = ""
    @Published public var lastIndexDate: Date? = nil
    @Published public var lastIndexAppVersion: String? = nil
    @Published public var hasLoadedIndex: Bool = false
    
    public var isFromPreviousAppVersion: Bool {
        guard let version = lastIndexAppVersion else { return false }
        return version != Self.currentAppVersion
    }
    
    public var isAllSelected: Bool {
        !indexedGroups.isEmpty && selectedDirectories.count == indexedGroups.count
    }
    
    public var selectedDirectory: URL? {
        get { selectedDirectories.first }
        set {
            if let val = newValue {
                selectedDirectories = [val]
            } else {
                selectedDirectories = []
            }
        }
    }
    
    public func selectAllDirectories() {
        selectedDirectories = Set(indexedGroups.map { $0.directoryURL })
    }
    
    public func deselectAllDirectories() {
        selectedDirectories = []
    }
    
    public func toggleDirectorySelection(url: URL, isShiftPressed: Bool = false, isCommandPressed: Bool = false) {
        if isShiftPressed, let lastSelected = selectedDirectories.first, let lastIdx = indexedGroups.firstIndex(where: { $0.directoryURL == lastSelected }), let targetIdx = indexedGroups.firstIndex(where: { $0.directoryURL == url }) {
            let start = min(lastIdx, targetIdx)
            let end = max(lastIdx, targetIdx)
            let rangeGroups = indexedGroups[start...end]
            for g in rangeGroups {
                selectedDirectories.insert(g.directoryURL)
            }
        } else if isCommandPressed {
            if selectedDirectories.contains(url) {
                if selectedDirectories.count > 1 {
                    selectedDirectories.remove(url)
                }
            } else {
                selectedDirectories.insert(url)
            }
        } else {
            selectedDirectories = [url]
        }
    }
    
    private var scanTask: Task<Void, Never>?
    
    private var cacheDirectoryURL: URL {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        let dir = appSupport.appendingPathComponent("Flashbrowse/indexes", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    private func cacheFile(for indexId: String, rootURL: URL) -> URL {
        let pathStr = rootURL.standardizedFileURL.path
        let safeName = pathStr.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: " ", with: "-")
        let truncated = safeName.count > 45 ? String(safeName.suffix(45)) : safeName
        let hash = abs(pathStr.hashValue)
        return cacheDirectoryURL.appendingPathComponent("\(indexId)_\(truncated)_\(hash).json")
    }
    
    private init() {}
    
    /// Opens available index from cache if present; otherwise opens view without auto-scanning so user can initiate it
    public func openIndex(for index: FileTypeIndex, preferredRoot: URL) {
        self.activeIndex = index
        self.searchQuery = ""
        
        // 1. Check if already active with loaded data
        if hasLoadedIndex, currentRootURL?.standardizedFileURL.path == preferredRoot.standardizedFileURL.path, !indexedGroups.isEmpty {
            return
        }
        
        // 2. Try loading cached index for preferredRoot
        if loadCachedIndex(for: index.id, rootURL: preferredRoot) {
            return
        }
        
        // 3. Try loading last used root for this index preset
        if let lastPath = UserDefaults.standard.string(forKey: "flashbrowse_last_index_root_\(index.id)") {
            let lastURL = URL(fileURLWithPath: lastPath)
            if lastURL.standardizedFileURL.path != preferredRoot.standardizedFileURL.path {
                if loadCachedIndex(for: index.id, rootURL: lastURL) {
                    return
                }
            }
        }
        
        // 4. Look for ANY existing cache file on disk for this indexId
        if let anyRoot = findAnyCachedRoot(for: index.id) {
            if loadCachedIndex(for: index.id, rootURL: anyRoot) {
                return
            }
        }
        
        // 5. No index found: Prepare unindexed state for user to trigger scanning
        self.currentRootURL = preferredRoot
        self.indexedGroups = []
        self.selectedDirectories = []
        self.totalFilesFound = 0
        self.hasLoadedIndex = false
        self.lastIndexDate = nil
        self.lastIndexAppVersion = nil
        self.isScanning = false
    }
    
    private func findAnyCachedRoot(for indexId: String) -> URL? {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: cacheDirectoryURL, includingPropertiesForKeys: nil) else { return nil }
        for file in files where file.lastPathComponent.hasPrefix("\(indexId)_") && file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file),
               let payload = try? JSONDecoder().decode(CachedIndexPayload.self, from: data) {
                return URL(fileURLWithPath: payload.rootPath)
            }
        }
        return nil
    }
    
    public func loadCachedIndex(for indexId: String, rootURL: URL) -> Bool {
        let file = cacheFile(for: indexId, rootURL: rootURL)
        guard let data = try? Data(contentsOf: file) else { return false }
        guard let payload = try? JSONDecoder().decode(CachedIndexPayload.self, from: data) else { return false }
        
        var groups: [DirectoryIndexGroup] = []
        for g in payload.groups {
            let items: [FileItem] = g.items.map { itemRecord in
                FileItem(
                    url: URL(fileURLWithPath: itemRecord.path),
                    size: itemRecord.size,
                    dateModified: itemRecord.dateModified,
                    kindDescription: itemRecord.kindDescription
                )
            }
            let group = DirectoryIndexGroup(
                directoryURL: URL(fileURLWithPath: g.directoryPath),
                baseRoot: URL(fileURLWithPath: payload.rootPath),
                items: items
            )
            groups.append(group)
        }
        
        self.currentRootURL = URL(fileURLWithPath: payload.rootPath)
        self.indexedGroups = groups
        self.totalFilesFound = payload.totalFiles
        self.lastIndexDate = payload.createdAt
        self.lastIndexAppVersion = payload.appVersion
        self.hasLoadedIndex = true
        self.isScanning = false
        
        if let first = groups.first {
            self.selectedDirectory = first.directoryURL
        } else {
            self.selectedDirectories = []
        }
        return true
    }
    
    private func saveIndexToCache(indexId: String, rootURL: URL, groups: [DirectoryIndexGroup], totalCount: Int) {
        let groupRecords = groups.map { g in
            CachedGroupRecord(
                directoryPath: g.directoryURL.path,
                relativePath: g.relativePath,
                items: g.items.map { item in
                    CachedFileRecord(
                        path: item.url.path,
                        size: item.size,
                        dateModified: item.dateModified,
                        kindDescription: item.kindDescription
                    )
                }
            )
        }
        
        let payload = CachedIndexPayload(
            formatVersion: 1,
            appVersion: Self.currentAppVersion,
            indexId: indexId,
            rootPath: rootURL.standardizedFileURL.path,
            createdAt: Date(),
            totalFiles: totalCount,
            groups: groupRecords
        )
        
        if let data = try? JSONEncoder().encode(payload) {
            let file = cacheFile(for: indexId, rootURL: rootURL)
            try? data.write(to: file, options: [.atomic])
            UserDefaults.standard.set(rootURL.standardizedFileURL.path, forKey: "flashbrowse_last_index_root_\(indexId)")
        }
    }
    
    public func startIndexScan(for index: FileTypeIndex, in rootURL: URL) {
        self.activeIndex = index
        self.currentRootURL = rootURL
        self.indexedGroups = []
        self.selectedDirectory = nil
        self.isScanning = true
        self.totalFilesFound = 0
        
        scanTask?.cancel()
        // Execute recursive scan entirely in a background utility task to never block the main UI thread
        scanTask = Task.detached(priority: .utility) {
            let extensions = index.extensions
            let fm = FileManager.default
            let options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsPackageDescendants]
            let excluded = Self.excludedDirectoryNames
            let rootPath = rootURL.standardizedFileURL.path
            
            guard let enumerator = fm.enumerator(
                at: rootURL,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
                options: options,
                errorHandler: { _, _ in
                    // Silently ignore permissions errors without raising system TCC popups
                    return true
                }
            ) else {
                await MainActor.run {
                    self.isScanning = false
                }
                return
            }
            
            var groupsMap: [URL: [FileItem]] = [:]
            var count = 0
            
            while let fileURL = enumerator.nextObject() as? URL {
                if Task.isCancelled { break }
                
                let isDir = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                if isDir {
                    let dirName = fileURL.lastPathComponent.lowercased()
                    // Never traverse into TCC-protected system folders (Music, Pictures, Library, etc.) or build caches
                    if fileURL.standardizedFileURL.path != rootPath {
                        if excluded.contains(dirName) || fileURL.lastPathComponent.hasPrefix(".") {
                            enumerator.skipDescendants()
                            continue
                        }
                    }
                    continue
                }
                
                let ext = fileURL.pathExtension.lowercased()
                let fileName = fileURL.lastPathComponent.lowercased()
                
                // Match extension or compound extensions like .vcf.gz or .fastq.gz
                var matched = extensions.contains(ext)
                if !matched {
                    for customExt in extensions {
                        if fileName.hasSuffix(".\(customExt)") {
                            matched = true
                            break
                        }
                    }
                }
                
                if matched {
                    let parentDir = fileURL.deletingLastPathComponent().standardized
                    let item = FileItem(url: fileURL)
                    groupsMap[parentDir, default: []].append(item)
                    count += 1
                }
            }
            
            if !Task.isCancelled {
                var computedGroups: [DirectoryIndexGroup] = []
                for (dirURL, items) in groupsMap {
                    let sortedItems = items.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                    let group = DirectoryIndexGroup(directoryURL: dirURL, baseRoot: rootURL, items: sortedItems)
                    computedGroups.append(group)
                }
                
                computedGroups.sort { $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending }
                
                let finalGroups = computedGroups
                let finalCount = count
                await MainActor.run {
                    self.indexedGroups = finalGroups
                    self.totalFilesFound = finalCount
                    self.isScanning = false
                    self.hasLoadedIndex = true
                    self.lastIndexDate = Date()
                    self.lastIndexAppVersion = Self.currentAppVersion
                    
                    // Persist to disk cache
                    self.saveIndexToCache(indexId: index.id, rootURL: rootURL, groups: finalGroups, totalCount: finalCount)
                    
                    // Select first directory by default
                    if let first = finalGroups.first {
                        self.selectedDirectory = first.directoryURL
                    }
                }
            } else {
                await MainActor.run {
                    self.isScanning = false
                }
            }
        }
    }
    
    public func clearIndex() {
        scanTask?.cancel()
        self.activeIndex = nil
        self.indexedGroups = []
        self.selectedDirectories = []
        self.isScanning = false
        self.hasLoadedIndex = false
    }
}
