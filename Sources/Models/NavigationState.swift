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

public enum ClickOpenMode: String, CaseIterable, Identifiable, Codable {
    case foldersOnly = "Folders Only (Safe)"
    case always = "Folders & Files"
    case doubleClick = "Double Click All"
    
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

public struct BreadcrumbItem: Identifiable, Hashable, Sendable {
    public var id: String { url.path }
    public let name: String
    public let url: URL
    
    public init(name: String, url: URL) {
        self.name = name
        self.url = url
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
    @Published public var clickMode: ClickOpenMode = {
        if let raw = UserDefaults.standard.string(forKey: "flashbrowse_click_mode"),
           let mode = ClickOpenMode(rawValue: raw) {
            return mode
        }
        return .foldersOnly
    }() {
        didSet {
            UserDefaults.standard.set(clickMode.rawValue, forKey: "flashbrowse_click_mode")
        }
    }
    
    public var singleClickToOpen: Bool {
        get { clickMode != .doubleClick }
        set { clickMode = newValue ? .foldersOnly : .doubleClick }
    }
    
    // Window Pinning (Always on Top)
    @Published public var isPinnedAlwaysOnTop: Bool = UserDefaults.standard.bool(forKey: "flashbrowse_always_on_top") {
        didSet {
            UserDefaults.standard.set(isPinnedAlwaysOnTop, forKey: "flashbrowse_always_on_top")
            applyWindowPinning()
        }
    }
    
    public func applyWindowPinning() {
        for window in NSApp.windows where !(window is NSPanel) {
            window.level = isPinnedAlwaysOnTop ? .floating : .normal
        }
        InspectorWindowController.shared.updateWindowLevel()
    }
    
    public func togglePinWindow() {
        isPinnedAlwaysOnTop.toggle()
        showToast(isPinnedAlwaysOnTop ? "📌 Window Pinned (Always on Top)" : "📌 Window Unpinned (Normal)")
    }
    
    // Smart Hover Preview (Previews images, scripts, logs, text on hover WITHOUT altering file selection)
    @Published public var smartHoverPreview: Bool = {
        if UserDefaults.standard.object(forKey: "flashbrowse_smart_hover_preview") != nil {
            return UserDefaults.standard.bool(forKey: "flashbrowse_smart_hover_preview")
        }
        return true // Enabled by default
    }() {
        didSet {
            UserDefaults.standard.set(smartHoverPreview, forKey: "flashbrowse_smart_hover_preview")
        }
    }
    
    public static func isSmartHoverPreviewCandidate(item: FileItem) -> Bool {
        if item.isDirectory { return false }
        let ext = item.url.pathExtension.lowercased()
        
        // 1. All images (PNG, JPG, JPEG, WEBP, GIF, SVG, TIFF, HEIC, etc.)
        if SharedInspectorState.imageExtensions.contains(ext) {
            return true
        }
        
        // 2. Text files, logs, scripts, markdown, code, config (< 5 MB)
        let textExtensions: Set<String> = [
            "log", "txt", "text", "md", "markdown", "py", "pyw", "ipynb", "smk", "sh", "bash", "zsh", "fish", "command",
            "json", "jsonl", "geojson", "csv", "tsv", "tab", "yaml", "yml", "toml", "ini", "conf", "cfg", "env",
            "xml", "html", "htm", "css", "scss", "sass", "less", "js", "ts", "jsx", "tsx", "mjs", "cjs", "swift",
            "c", "cpp", "cc", "cxx", "h", "hpp", "r", "rmd", "rs", "go", "java", "kt", "kts", "scala", "lua", "perl", "pl", "pm", "rb", "php",
            "sql", "fasta", "fa", "fna", "faa", "bed", "gtf", "gff", "gff3", "vcf", "dockerfile", "makefile", "diff", "patch"
        ]
        
        let filenameLower = item.url.lastPathComponent.lowercased()
        let isCommonCodeFile = filenameLower == "makefile" || filenameLower.hasPrefix("makefile.") ||
                               filenameLower == "dockerfile" || filenameLower.hasPrefix("dockerfile.") ||
                               filenameLower == "snakefile" || filenameLower.hasPrefix(".bash") ||
                               filenameLower.hasPrefix(".zsh") || filenameLower.hasPrefix(".env") ||
                               filenameLower == ".gitignore" || filenameLower == ".dockerignore"
        
        if textExtensions.contains(ext) || isCommonCodeFile {
            return (item.size ?? 0) < 5 * 1024 * 1024 // < 5MB
        }
        
        // 3. Audio & small PDFs (< 10 MB)
        if ["pdf", "mp3", "wav", "m4a", "flac", "ogg"].contains(ext) {
            return (item.size ?? 0) < 10 * 1024 * 1024 // < 10MB
        }
        
        return false
    }
    
    @Published public var hoverToSelect: Bool = false
    
    // Multi-Selection Helper
    public func selectItem(
        _ item: FileItem,
        isShiftPressed: Bool = NSEvent.modifierFlags.contains(.shift),
        isCommandPressed: Bool = NSEvent.modifierFlags.contains(.command)
    ) {
        if isCommandPressed {
            if selectedURLs.contains(item.url) {
                selectedURLs.remove(item.url)
                if lastSelectedURL == item.url {
                    lastSelectedURL = selectedURLs.first
                }
            } else {
                selectedURLs.insert(item.url)
                lastSelectedURL = item.url
            }
        } else if isShiftPressed, let last = lastSelectedURL,
                  let lastIdx = filteredItems.firstIndex(where: { $0.url == last }),
                  let curIdx = filteredItems.firstIndex(where: { $0.url == item.url }) {
            let start = min(lastIdx, curIdx)
            let end = max(lastIdx, curIdx)
            let range = filteredItems[start...end].map { $0.url }
            selectedURLs = Set(range)
            lastSelectedURL = item.url
        } else {
            selectedURLs = [item.url]
            lastSelectedURL = item.url
        }
    }
    
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
    @Published public var volumeStorage: VolumeStorageInfo? = nil
    
    private var backStack: [URL] = []
    private var forwardStack: [URL] = []
    private var lastPinchTime: Date = Date.distantPast
    private var inspectorDebounceTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?
    
    public var canGoBack: Bool { !backStack.isEmpty }
    public var canGoForward: Bool { !forwardStack.isEmpty }
    public var canGoUp: Bool { currentDirectory.path != "/" }
    
    public var breadcrumbs: [BreadcrumbItem] {
        var crumbs: [BreadcrumbItem] = []
        var cur = currentDirectory.standardized
        
        while cur.path != "/" && !cur.path.isEmpty {
            crumbs.insert(BreadcrumbItem(name: cur.lastPathComponent, url: cur), at: 0)
            cur = cur.deletingLastPathComponent().standardized
        }
        crumbs.insert(BreadcrumbItem(name: "Computer", url: URL(fileURLWithPath: "/")), at: 0)
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
        DispatchQueue.main.async {
            self.applyWindowPinning()
        }
        
        NotificationCenter.default.addObserver(forName: .flashbrowseInspectorSelectedURL, object: nil, queue: .main) { [weak self] notif in
            guard let targetURL = notif.object as? URL else { return }
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let parent = targetURL.deletingLastPathComponent().standardized
                if parent == self.currentDirectory.standardized {
                    self.selectedURLs = [targetURL]
                    self.lastSelectedURL = targetURL
                }
            }
        }
        
        NotificationCenter.default.addObserver(forName: .flashbrowseReloadDirectory, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.reload()
            }
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
            try? await Task.sleep(nanoseconds: 35_000_000) // 35ms fast & smooth debounce
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
            let errors = FileSystemService.shared.copyItems(urls: urls, to: currentDirectory)
            reload()
            if errors.isEmpty {
                showToast("📋 Copied \(urls.count) file(s)")
            } else {
                showToast("⚠️ \(errors.first!)")
            }
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
    
    private var lastNavigationTime: Date = Date.distantPast
    
    // MARK: - Rename Item
    @Published public var renamingURL: URL?
    @Published public var renameText: String = ""
    
    public func startRename(url: URL) {
        self.renamingURL = url
        self.renameText = url.lastPathComponent
    }
    
    public func commitRename() -> String? {
        guard let url = renamingURL else { return nil }
        let newName = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty, newName != url.lastPathComponent else {
            cancelRename()
            return nil
        }
        
        let newURL = url.deletingLastPathComponent().appendingPathComponent(newName)
        do {
            try FileManager.default.moveItem(at: url, to: newURL)
            cancelRename()
            reload()
            selectedURLs = [newURL]
            return nil
        } catch {
            cancelRename()
            return "Rename failed: \(error.localizedDescription)"
        }
    }
    
    public func cancelRename() {
        renamingURL = nil
        renameText = ""
    }
    
    public func openItem(_ item: FileItem) {
        let now = Date()
        // Prevent accidental double-clicks from propagating down into child directories
        guard now.timeIntervalSince(lastNavigationTime) > 0.35 else { return }
        
        if item.isDirectory {
            lastNavigationTime = now
            navigateTo(url: item.url)
        } else {
            FileSystemService.shared.openItem(url: item.url)
        }
    }
    
    public func navigateTo(url: URL, addToHistory: Bool = true) {
        let target = url.standardized
        guard target.path != currentDirectory.path else { return }
        lastNavigationTime = Date()
        
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
        let storage = FileSystemService.shared.getVolumeStorageInfo(at: currentDirectory)
        self.volumeStorage = storage
        self.volumeInfo = storage?.statusSummary ?? FileSystemService.shared.volumeAvailableCapacity(at: currentDirectory)
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
