import Foundation
import SwiftUI
import AppKit
import Combine
import UniformTypeIdentifiers

public enum SearchScope: String, CaseIterable, Identifiable {
    case currentFolder = "Current Folder"
    case includeSubfolders = "Subfolders"
    
    public var id: String { rawValue }
}

public enum ViewMode: String, CaseIterable, Identifiable {
    case list = "List"
    case grid = "Grid"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .list: return "list.bullet"
        case .grid: return "square.grid.2x2"
        }
    }
}

public struct BookmarkItem: Identifiable, Codable, Hashable {
    public var id: String { path }
    public let name: String
    public let path: String
    public let icon: String
    
    public var url: URL {
        URL(fileURLWithPath: path)
    }
    
    public init(name: String, url: URL, icon: String = "folder.fill") {
        self.name = name
        self.path = url.path
        self.icon = icon
    }
}

@MainActor
public class NavigationState: ObservableObject {
    @Published public var currentDirectory: URL {
        didSet {
            pathInputText = currentDirectory.path
            reload()
            startDirectoryWatcher()
            TerminalService.shared.syncWorkingDirectory(currentDirectory)
            updateGitStatus()
        }
    }
    
    @Published public var viewMode: ViewMode = .list
    @Published public var items: [FileItem] = []
    @Published public var filteredItems: [FileItem] = []
    @Published public var selectedURLs: Set<URL> = [] {
        didSet {
            if let first = selectedURLs.first {
                lastSelectedURL = first
                QuickLookBridge.shared.currentPreviewURL = first
                scheduleInspectorUpdate(url: first)
            }
        }
    }
    @Published public var lastSelectedURL: URL?
    
    // Search & Scope
    @Published public var searchQuery: String = "" {
        didSet {
            applyFilterAndSort()
        }
    }
    @Published public var searchScope: SearchScope = .currentFolder {
        didSet {
            applyFilterAndSort()
        }
    }
    
    @Published public var showHiddenFiles: Bool = false {
        didSet {
            reload()
        }
    }
    
    @Published public var foldersFirst: Bool = true {
        didSet {
            applyFilterAndSort()
        }
    }
    
    @Published public var sortField: SortField = .name {
        didSet {
            applyFilterAndSort()
        }
    }
    
    @Published public var sortAscending: Bool = true {
        didSet {
            applyFilterAndSort()
        }
    }
    
    // User Interaction Preferences
    @Published public var singleClickToOpen: Bool = true
    @Published public var hoverToSelect: Bool = true
    
    // Custom User Bookmarks / Favorites (Persisted in UserDefaults)
    @Published public var customBookmarks: [BookmarkItem] = [] {
        didSet {
            saveBookmarks()
        }
    }
    
    // Workspace Presets (1..9)
    @Published public var workspacePresets: [WorkspacePreset] = [] {
        didSet {
            savePresets()
        }
    }
    @Published public var activePresetId: Int = 1
    
    // UI Status & Git
    @Published public var gitStatus: String?
    @Published public var toastMessage: String?
    @Published public var isEditingPath: Bool = false
    @Published public var pathInputText: String = ""
    @Published public var volumeInfo: String = ""
    
    private var backStack: [URL] = []
    private var forwardStack: [URL] = []
    private var lastPinchTime: Date = Date.distantPast
    private var inspectorDebounceTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?
    
    public var canGoBack: Bool { !backStack.isEmpty }
    public var canGoForward: Bool { !forwardStack.isEmpty }
    public var canGoUp: Bool { currentDirectory.path != "/" }
    
    public var breadcrumbs: [(name: String, url: URL)] {
        var crumbs: [(name: String, url: URL)] = []
        var cur = currentDirectory.standardized
        
        while cur.path != "/" {
            crumbs.insert((name: cur.lastPathComponent, url: cur), at: 0)
            cur = cur.deletingLastPathComponent()
        }
        crumbs.insert((name: "Computer", url: URL(fileURLWithPath: "/")), at: 0)
        return crumbs
    }
    
    public init(initialDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.currentDirectory = initialDirectory.standardized
        self.pathInputText = self.currentDirectory.path
        loadBookmarks()
        loadPresets()
        reload()
        startDirectoryWatcher()
        updateGitStatus()
        
        // 2-Way Sync: When terminal runs 'cd <dir>', navigate the file browser!
        TerminalService.shared.onLocalDirectoryChange = { [weak self] newURL in
            self?.navigateTo(url: newURL)
        }
    }
    
    // MARK: - Toast Message Helper
    public func showToast(_ message: String) {
        self.toastMessage = message
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if !Task.isCancelled {
                self.toastMessage = nil
            }
        }
    }
    
    // MARK: - Debounced Inspector Update
    public func scheduleInspectorUpdate(url: URL?) {
        inspectorDebounceTask?.cancel()
        inspectorDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 100_000_000)
            if !Task.isCancelled {
                SharedInspectorState.shared.updateTarget(url: url)
            }
        }
    }
    
    // MARK: - Paste Clipboard As File (Cmd+V)
    public func pasteClipboardAsFile() {
        let pasteboard = NSPasteboard.general
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        
        // 1. Check for Image in Clipboard
        if let image = NSImage(pasteboard: pasteboard) {
            if let tiffData = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                let targetURL = currentDirectory.appendingPathComponent("screenshot_\(timestamp).png")
                do {
                    try pngData.write(to: targetURL)
                    reload()
                    selectedURLs = [targetURL]
                    showToast("📋 Saved screenshot_\(timestamp).png")
                    return
                } catch {
                    showToast("Failed to save image")
                }
            }
        }
        
        // 2. Check for Text in Clipboard
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            let targetURL = currentDirectory.appendingPathComponent("snippet_\(timestamp).txt")
            do {
                try text.write(to: targetURL, atomically: true, encoding: .utf8)
                reload()
                selectedURLs = [targetURL]
                showToast("📋 Saved snippet_\(timestamp).txt")
                return
            } catch {
                showToast("Failed to save text snippet")
            }
        }
        
        // 3. Check for File URLs copied in Finder / Flashbrowse
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty {
            FileSystemService.shared.copyItems(urls: urls, to: currentDirectory)
            reload()
            showToast("📋 Copied \(urls.count) file(s)")
        }
    }
    
    // MARK: - Git Status Detection
    public func updateGitStatus() {
        let path = currentDirectory.path
        Task.detached(priority: .background) {
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = ["-C", path, "status", "--porcelain", "-b"]
            process.standardOutput = pipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                    let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }
                    guard let branchLine = lines.first, branchLine.hasPrefix("## ") else {
                        await MainActor.run { self.gitStatus = nil }
                        return
                    }
                    
                    let branchPart = String(branchLine.dropFirst(3)).components(separatedBy: "...").first ?? "main"
                    let modifiedCount = lines.count - 1
                    
                    let statusStr: String
                    if modifiedCount > 0 {
                        statusStr = "⎇ \(branchPart) (\(modifiedCount) modified)"
                    } else {
                        statusStr = "⎇ \(branchPart) (clean)"
                    }
                    
                    await MainActor.run {
                        self.gitStatus = statusStr
                    }
                } else {
                    await MainActor.run { self.gitStatus = nil }
                }
            } catch {
                await MainActor.run { self.gitStatus = nil }
            }
        }
    }
    
    // MARK: - Workspace Presets Management
    public func saveCurrentStateToPreset(
        id: Int,
        rightPath: String = "",
        isDualPane: Bool = false,
        isCommanderMode: Bool = false,
        isTerminalOpen: Bool = false,
        isInspectorOpen: Bool = false
    ) {
        let name = "Preset \(id): \(currentDirectory.lastPathComponent)"
        let preset = WorkspacePreset(
            id: id,
            name: name,
            leftPath: currentDirectory.path,
            rightPath: rightPath.isEmpty ? currentDirectory.path : rightPath,
            isDualPane: isDualPane,
            isCommanderMode: isCommanderMode,
            isTerminalOpen: isTerminalOpen,
            isInspectorOpen: isInspectorOpen
        )
        
        if let idx = workspacePresets.firstIndex(where: { $0.id == id }) {
            workspacePresets[idx] = preset
        } else {
            workspacePresets.append(preset)
        }
        
        showToast("💾 Saved Workspace Preset \(id)")
    }
    
    public func getPreset(id: Int) -> WorkspacePreset? {
        workspacePresets.first(where: { $0.id == id })
    }
    
    private func savePresets() {
        if let data = try? JSONEncoder().encode(workspacePresets) {
            UserDefaults.standard.set(data, forKey: "flashbrowse_workspace_presets")
        }
    }
    
    private func loadPresets() {
        if let data = UserDefaults.standard.data(forKey: "flashbrowse_workspace_presets"),
           let loaded = try? JSONDecoder().decode([WorkspacePreset].self, from: data), !loaded.isEmpty {
            self.workspacePresets = loaded
        } else {
            self.workspacePresets = WorkspacePreset.defaultPresets()
        }
    }
    
    public func openItem(_ item: FileItem) {
        if item.isDirectory {
            navigateTo(url: item.url)
        } else {
            FileSystemService.shared.openItem(url: item.url)
        }
    }
    
    public func navigateTo(url: URL, addToHistory: Bool = true) {
        let target = url.standardized
        guard target != currentDirectory else { return }
        
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: target.path, isDirectory: &isDir), isDir.boolValue {
            let isPkg = (try? target.resourceValues(forKeys: [.isPackageKey]).isPackage) ?? false
            if !isPkg {
                if addToHistory {
                    backStack.append(currentDirectory)
                    forwardStack.removeAll()
                }
                selectedURLs.removeAll()
                currentDirectory = target
                return
            }
        }
        
        FileSystemService.shared.openItem(url: target)
    }
    
    public func goBack() {
        guard let prev = backStack.popLast() else { return }
        forwardStack.append(currentDirectory)
        selectedURLs.removeAll()
        currentDirectory = prev
    }
    
    public func goForward() {
        guard let next = forwardStack.popLast() else { return }
        backStack.append(currentDirectory)
        selectedURLs.removeAll()
        currentDirectory = next
    }
    
    public func goUp() {
        guard canGoUp else { return }
        let parent = currentDirectory.deletingLastPathComponent()
        navigateTo(url: parent)
    }
    
    // MARK: - Trackpad Pinch Gesture Handler
    public func handlePinch(scale: CGFloat) {
        let now = Date()
        guard now.timeIntervalSince(lastPinchTime) > 0.4 else { return }
        
        if scale < 0.82 { // Pinch-in -> Go up one level
            lastPinchTime = now
            goUp()
        } else if scale > 1.25 { // Pinch-out -> Open selected/hovered item
            lastPinchTime = now
            if let target = lastSelectedURL,
               let item = filteredItems.first(where: { $0.url == target }) {
                openItem(item)
            }
        }
    }
    
    // MARK: - Bookmark Management
    public func isBookmarked(url: URL) -> Bool {
        let path = url.standardized.path
        return customBookmarks.contains(where: { $0.path == path })
    }
    
    public func toggleBookmark(url: URL) {
        if isBookmarked(url: url) {
            removeBookmark(url: url)
        } else {
            addBookmark(url: url)
        }
    }
    
    public func addBookmark(url: URL) {
        let target = url.standardized
        guard !customBookmarks.contains(where: { $0.path == target.path }) else { return }
        
        let name = target.lastPathComponent.isEmpty ? target.path : target.lastPathComponent
        let bookmark = BookmarkItem(name: name, url: target)
        customBookmarks.append(bookmark)
    }
    
    public func removeBookmark(url: URL) {
        let path = url.standardized.path
        customBookmarks.removeAll(where: { $0.path == path })
    }
    
    public func removeBookmark(id: String) {
        customBookmarks.removeAll(where: { $0.id == id })
    }
    
    private func saveBookmarks() {
        if let data = try? JSONEncoder().encode(customBookmarks) {
            UserDefaults.standard.set(data, forKey: "flashbrowse_custom_bookmarks")
        }
    }
    
    private func loadBookmarks() {
        if let data = UserDefaults.standard.data(forKey: "flashbrowse_custom_bookmarks"),
           let loaded = try? JSONDecoder().decode([BookmarkItem].self, from: data) {
            self.customBookmarks = loaded
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser
            let devDir = home.appendingPathComponent("dev")
            if FileManager.default.fileExists(atPath: devDir.path) {
                self.customBookmarks = [BookmarkItem(name: "dev", url: devDir, icon: "hammer.fill")]
            }
        }
    }
    
    public func reload() {
        let rawItems = FileSystemService.shared.contentsOfDirectory(
            at: currentDirectory,
            showHidden: showHiddenFiles
        )
        self.items = rawItems
        self.volumeInfo = FileSystemService.shared.volumeAvailableCapacity(at: currentDirectory)
        applyFilterAndSort()
    }
    
    public func applyFilterAndSort() {
        let query = searchQuery.trimmingCharacters(in: .whitespaces).lowercased()
        
        if query.isEmpty {
            self.filteredItems = FileSystemService.shared.sort(
                items: items,
                by: sortField,
                ascending: sortAscending,
                foldersFirst: foldersFirst
            )
            return
        }
        
        if searchScope == .includeSubfolders {
            let deepResults = FileSystemService.shared.recursiveSearch(
                query: query,
                in: currentDirectory,
                showHidden: showHiddenFiles
            )
            self.filteredItems = FileSystemService.shared.sort(
                items: deepResults,
                by: sortField,
                ascending: sortAscending,
                foldersFirst: foldersFirst
            )
        } else {
            let matches = items.filter { $0.lowercaseName.contains(query) }
            self.filteredItems = FileSystemService.shared.sort(
                items: matches,
                by: sortField,
                ascending: sortAscending,
                foldersFirst: foldersFirst
            )
        }
    }
    
    public func commitPathInput() {
        let expanded = NSString(string: pathInputText).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded).standardized
        
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            navigateTo(url: url)
            isEditingPath = false
        } else {
            pathInputText = currentDirectory.path
            isEditingPath = false
        }
    }
    
    public func toggleSort(field: SortField) {
        if sortField == field {
            sortAscending.toggle()
        } else {
            sortField = field
            sortAscending = true
        }
    }
    
    private func startDirectoryWatcher() {
        FileSystemService.shared.startMonitoring(url: currentDirectory) { [weak self] in
            Task { @MainActor in
                self?.reload()
            }
        }
    }
}
