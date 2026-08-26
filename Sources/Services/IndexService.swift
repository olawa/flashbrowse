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

@MainActor
public class IndexService: ObservableObject {
    public static let shared = IndexService()
    
    @Published public var activeIndex: FileTypeIndex?
    @Published public var indexedGroups: [DirectoryIndexGroup] = []
    @Published public var selectedDirectories: Set<URL> = []
    @Published public var isScanning: Bool = false
    @Published public var totalFilesFound: Int = 0
    @Published public var searchQuery: String = ""
    
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
    
    private init() {}
    
    public func startIndexScan(for index: FileTypeIndex, in rootURL: URL) {
        self.activeIndex = index
        self.indexedGroups = []
        self.selectedDirectory = nil
        self.isScanning = true
        self.totalFilesFound = 0
        
        scanTask?.cancel()
        scanTask = Task {
            let extensions = index.extensions
            let fm = FileManager.default
            let options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsPackageDescendants]
            
            guard let enumerator = fm.enumerator(
                at: rootURL,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
                options: options
            ) else {
                self.isScanning = false
                return
            }
            
            var groupsMap: [URL: [FileItem]] = [:]
            var count = 0
            
            while let fileURL = enumerator.nextObject() as? URL {
                if Task.isCancelled { break }
                
                let isDir = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                if isDir { continue }
                
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
                
                self.indexedGroups = computedGroups
                self.totalFilesFound = count
                self.isScanning = false
                
                // Select first directory by default
                if let first = computedGroups.first {
                    self.selectedDirectory = first.directoryURL
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
    }
}
