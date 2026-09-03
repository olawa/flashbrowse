import SwiftUI
import AppKit

public struct FileTableView: View {
    @ObservedObject var state: NavigationState
    @FocusState private var isListFocused: Bool
    @State private var hoveredURL: URL?
    @GestureState private var pinchScale: CGFloat = 1.0
    @State private var showingDeleteConfirmation: Bool = false
    @State private var pendingDeleteURLs: [URL] = []
    @FocusState private var isRenameFieldFocused: Bool
    @State private var lastClickedURL: URL?
    @State private var lastClickTimestamp: Date = Date.distantPast

    // Hover Dir Tree
    @State private var hoverTreeURL: URL? = nil
    @State private var hoverTreeAnchorPoint: CGPoint = .zero
    private let hoverTreeWorkItem = DispatchWorkItemBox()
    public init(state: NavigationState) {
        self.state = state
    }
    
    public var body: some View {
        ZStack(alignment: .topLeading) {
            Color(nsColor: .textBackgroundColor)
                .ignoresSafeArea()
            
            if state.filteredItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: state.searchQuery.isEmpty ? "folder.badge.questionmark" : "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.4))
                    
                    Text(state.searchQuery.isEmpty ? "This folder is empty" : "No files matching \"\(state.searchQuery)\"")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                if state.viewMode == .list {
                    listView
                } else {
                    gridView
                }
            }

            // Hover Dir Tree Overlay
            if let treeURL = hoverTreeURL {
                HoverDirTreeView(
                    rootURL: treeURL,
                    onNavigate: { url in
                        hoverTreeURL = nil
                        state.navigateTo(url: url)
                    },
                    onClose: { hoverTreeURL = nil }
                )
                .offset(x: min(hoverTreeAnchorPoint.x, 20), y: max(hoverTreeAnchorPoint.y, 4))
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .topLeading)))
                .animation(.easeOut(duration: 0.12), value: hoverTreeURL)
                .zIndex(100)
            }
        }
        .focusable()
        .focused($isListFocused)
        .onAppear {
            isListFocused = true
        }
        // MARK: - Trackpad Pinch Gesture (Pinch In = Up, Pinch Out = Open)
        .gesture(
            MagnificationGesture()
                .updating($pinchScale) { value, scale, _ in
                    scale = value
                }
                .onChanged { scale in
                    state.handlePinch(scale: scale)
                }
                .onEnded { scale in
                    state.handlePinch(scale: scale)
                }
        )
        // MARK: - Keyboard Navigation
        .onKeyPress(.space) {
            if let selected = state.selectedURLs.first {
                QuickLookBridge.shared.toggleQuickLook(for: selected)
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.return) {
            // Enter = rename selected file (if not renaming, start rename)
            if state.renamingURL != nil {
                return .ignored // Let TextField handle it
            }
            if let selectedURL = state.selectedURLs.first {
                state.startRename(url: selectedURL)
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.upArrow) {
            selectPrevious()
            return .handled
        }
        .onKeyPress(.downArrow) {
            selectNext()
            return .handled
        }
        .onKeyPress(.delete) {
            let urlsToDelete = Array(state.selectedURLs)
            if !urlsToDelete.isEmpty {
                pendingDeleteURLs = urlsToDelete
                showingDeleteConfirmation = true
                return .handled
            }
            return .ignored
        }
        .alert("Flytta till papperskorgen?", isPresented: $showingDeleteConfirmation) {
            Button("Avbryt", role: .cancel) {
                pendingDeleteURLs = []
            }
            Button("Radera", role: .destructive) {
                let errors = FileSystemService.shared.moveToTrash(urls: pendingDeleteURLs)
                if !errors.isEmpty {
                    state.showToast("⚠️ \(errors.first!)")
                }
                state.reload()
                pendingDeleteURLs = []
            }
        } message: {
            Text("Vill du flytta \(pendingDeleteURLs.count) objekt till papperskorgen?")
        }
    }
    
    // MARK: - List View (Detailed Table)
    private var listView: some View {
        GeometryReader { geo in
            let isCompact = geo.size.width < 520
            let isUltraCompact = geo.size.width < 380
            
            VStack(spacing: 0) {
                // Sort Header Bar (Ubuntu Nautilus Style)
                HStack(spacing: 0) {
                    headerButton("Name", field: .name, width: nil, alignment: .leading)
                    
                    Divider().frame(height: 14)
                    headerButton("Size", field: .size, width: isCompact ? 75 : 90, alignment: .trailing)
                    
                    if !isUltraCompact {
                        Divider().frame(height: 14)
                        headerButton("Modified", field: .dateModified, width: isCompact ? 105 : 135, alignment: .leading)
                    }
                    
                    if !isCompact {
                        Divider().frame(height: 14)
                        headerButton("Type", field: .kind, width: 110, alignment: .leading)
                    }
                }
                .padding(.horizontal, isCompact ? 8 : 12)
                .padding(.vertical, 5)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.8))
                .overlay(
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundColor(Color(nsColor: .separatorColor)),
                    alignment: .bottom
                )
                
                // Scrollable List
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(state.filteredItems) { item in
                            listRow(for: item, isCompact: isCompact, isUltraCompact: isUltraCompact)
                                .id(item.url)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 4)
                }
            }
        }
    }
    
    @ViewBuilder
    private func headerButton(_ title: String, field: SortField, width: CGFloat?, alignment: Alignment) -> some View {
        Button(action: {
            state.toggleSort(field: field)
        }) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(state.sortField == field ? Color.flashbrowseAccent : .secondary)
                
                if state.sortField == field {
                    Image(systemName: state.sortAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color.flashbrowseAccent)
                }
                
                if alignment == .leading && width == nil {
                    Spacer()
                }
            }
            .frame(width: width, alignment: alignment)
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func listRow(for item: FileItem, isCompact: Bool, isUltraCompact: Bool) -> some View {
        let isSelected = state.selectedURLs.contains(item.url)
        let isHovered = hoveredURL == item.url
        
        HStack(spacing: 6) {
            // Icon + Name
            HStack(spacing: 6) {
                ZStack {
                    if item.isDirectory {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 15))
                            .foregroundColor(Color.flashbrowseAccent) // Ubuntu Orange
                    } else {
                        Image(systemName: item.sfSymbolName)
                            .font(.system(size: 14))
                            .foregroundColor(item.categoryColor)
                    }
                }
                .frame(width: 20, height: 20)
                
                if state.renamingURL == item.url {
                    TextField("", text: $state.renameText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(3)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(Color.flashbrowseAccent, lineWidth: 1)
                        )
                        .focused($isRenameFieldFocused)
                        .onAppear { isRenameFieldFocused = true }
                        .onSubmit {
                            if let err = state.commitRename() {
                                state.showToast(err)
                            }
                        }
                        .onExitCommand {
                            state.cancelRename()
                        }
                } else {
                    Text(item.name)
                        .font(.system(size: 12, weight: item.isDirectory ? .medium : .regular))
                        .foregroundColor(isSelected ? .white : (item.isHidden ? .secondary : .primary))
                        .lineLimit(1)
                }
                
                if item.isSymlink {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 8))
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
                
                Spacer(minLength: 4)
            }
            
            // Size Column with Fixed-Scale Indicator for Large Files & Calculated Folders (>= 50 MB, 1 GB = 100%)
            let effectiveBytes = (item.isDirectory ? state.folderSizesCache[item.url] : item.size)
            let formattedSizeText: String = {
                if let cached = state.folderSizesCache[item.url] {
                    return FileItem.byteFormatter.string(fromByteCount: cached)
                }
                return item.formattedSize
            }()
            let hasCalculatedFolderSize = item.isDirectory && state.folderSizesCache[item.url] != nil
            
            ZStack(alignment: .trailing) {
                if let bytes = effectiveBytes, bytes >= 50_000_000 {
                    let proportion = min(1.0, Double(bytes) / 1_073_741_824.0) // 1 GB is 100%
                    let isGigabyte = bytes >= 1_000_000_000
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            isSelected
                            ? Color.white.opacity(0.3)
                            : (isGigabyte ? Color.flashbrowseAccent.opacity(0.25) : Color.cyan.opacity(0.18))
                        )
                        .frame(width: (isCompact ? 70 : 85) * proportion, height: 16)
                }
                
                Text(formattedSizeText)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(
                        isSelected
                        ? .white
                        : (hasCalculatedFolderSize ? Color.flashbrowseAccent : .secondary)
                    )
                    .padding(.horizontal, 2)
            }
            .frame(width: isCompact ? 75 : 90, alignment: .trailing)
            .padding(.trailing, 2)
            
            // Date Modified
            if !isUltraCompact {
                Text(isCompact ? item.shortFormattedDate : item.formattedDate)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .frame(width: isCompact ? 105 : 135, alignment: .leading)
                    .padding(.horizontal, 2)
                    .lineLimit(1)
            }
            
            // Kind (only on wider views)
            if !isCompact {
                Text(item.kindDescription)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .frame(width: 110, alignment: .leading)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, isCompact ? 6 : 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isSelected
                      ? Color.flashbrowseAccent
                      : (isHovered ? Color.flashbrowseAccent.opacity(0.12) : Color.clear))
        )
        .contentShape(Rectangle())
        // Drag & Drop
        .onDrag {
            if !state.selectedURLs.contains(item.url) {
                state.selectedURLs = [item.url]
                state.lastSelectedURL = item.url
            }
            return NSItemProvider(object: item.url as NSURL)
        }
        // Hover: Smart Live Preview for images/logs/text WITHOUT altering selection!
        .onHover { hovering in
            if hovering {
                hoveredURL = item.url
                if state.hoverToSelect {
                    state.selectedURLs = [item.url]
                    state.lastSelectedURL = item.url
                } else if state.smartHoverPreview && NavigationState.isSmartHoverPreviewCandidate(item: item) {
                    state.scheduleInspectorUpdate(url: item.url)
                }

                // Hover Dir Tree: schedule for directories
                if item.isDirectory {
                    hoverTreeWorkItem.cancel()
                    let work = DispatchWorkItem {
                        if hoveredURL == item.url {
                            hoverTreeURL = item.url
                        }
                    }
                    hoverTreeWorkItem.item = work
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
                } else {
                    hoverTreeWorkItem.cancel()
                    if hoverTreeURL != nil { hoverTreeURL = nil }
                }
            } else if hoveredURL == item.url {
                hoveredURL = nil
                // Don't cancel hoverTreeURL — mouse may be entering the tooltip
                hoverTreeWorkItem.cancel()
            }
        }
        // Single Click, Multi-Select (Shift/Cmd), and Delayed Rename (Finder Style)
        .onTapGesture {
            let now = Date()
            let isShift = NSEvent.modifierFlags.contains(.shift)
            let isCmd = NSEvent.modifierFlags.contains(.command)
            
            // Inactive window safety check
            let wasJustActivated = now.timeIntervalSince(AppDelegate.lastWindowActivationTime) < 0.25
            if wasJustActivated {
                state.selectItem(item, isShiftPressed: false, isCommandPressed: false)
                lastClickedURL = item.url
                lastClickTimestamp = now
                return
            }
            
            // Multi-selection if Shift or Command is held
            if isShift || isCmd {
                state.selectItem(item, isShiftPressed: isShift, isCommandPressed: isCmd)
                lastClickedURL = item.url
                lastClickTimestamp = now
                return
            }
            
            // Finder-Style Delayed Click on Already-Selected Item to Rename
            let isAlreadySingleSelected = state.selectedURLs.contains(item.url) && state.selectedURLs.count == 1
            let timeSinceLastClick = now.timeIntervalSince(lastClickTimestamp)
            
            if isAlreadySingleSelected && lastClickedURL == item.url && timeSinceLastClick > 0.45 && timeSinceLastClick < 2.5 {
                state.startRename(url: item.url)
                lastClickedURL = nil
                return
            }
            
            lastClickedURL = item.url
            lastClickTimestamp = now
            
            switch state.clickMode {
            case .foldersOnly:
                if item.isDirectory {
                    state.openItem(item)
                } else {
                    state.selectItem(item, isShiftPressed: false, isCommandPressed: false)
                }
            case .always:
                state.openItem(item)
            case .doubleClick:
                state.selectItem(item, isShiftPressed: false, isCommandPressed: false)
            }
        }
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                if state.clickMode == .doubleClick || (!item.isDirectory && state.clickMode == .foldersOnly) {
                    state.openItem(item)
                }
            }
        )
        .contextMenu {
            contextMenuItems(for: item)
        }
    }
    
    // MARK: - Grid View (Nautilus Icon Grid)
    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 105, maximum: 130), spacing: 14)], spacing: 14) {
                ForEach(state.filteredItems) { item in
                    gridCard(for: item)
                }
            }
            .padding(16)
        }
    }
    
    @ViewBuilder
    private func gridCard(for item: FileItem) -> some View {
        let isSelected = state.selectedURLs.contains(item.url)
        let isHovered = hoveredURL == item.url
        
        VStack(spacing: 6) {
            ZStack {
                if item.isDirectory {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 46))
                        .foregroundColor(Color.flashbrowseAccent)
                } else {
                    Image(systemName: item.sfSymbolName)
                        .font(.system(size: 40))
                        .foregroundColor(item.categoryColor)
                }
                
                if item.isSymlink {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "arrow.up.right.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .background(Circle().fill(Color.black.opacity(0.7)))
                        }
                    }
                    .frame(width: 46, height: 46)
                }
            }
            .frame(height: 52)
            
            if state.renamingURL == item.url {
                TextField("", text: $state.renameText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(Color.flashbrowseAccent, lineWidth: 1)
                    )
                    .focused($isRenameFieldFocused)
                    .onAppear { isRenameFieldFocused = true }
                    .onSubmit {
                        if let err = state.commitRename() {
                            state.showToast(err)
                        }
                    }
                    .onExitCommand {
                        state.cancelRename()
                    }
                    .frame(maxWidth: .infinity)
            } else {
                Text(item.name)
                    .font(.system(size: 12, weight: item.isDirectory ? .medium : .regular))
                    .foregroundColor(isSelected ? .white : (item.isHidden ? .secondary : .primary))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected
                      ? Color.flashbrowseAccent
                      : (isHovered
                         ? Color.flashbrowseAccent.opacity(0.15)
                         : (item.isDirectory ? Color(nsColor: .controlBackgroundColor).opacity(0.5) : Color.clear)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.clear : (isHovered ? Color.flashbrowseAccent.opacity(0.5) : Color(nsColor: .separatorColor).opacity(0.3)), lineWidth: 1)
        )
        .contentShape(Rectangle())
        // Drag & Drop
        .onDrag {
            if !state.selectedURLs.contains(item.url) {
                state.selectedURLs = [item.url]
                state.lastSelectedURL = item.url
            }
            return NSItemProvider(object: item.url as NSURL)
        }
        // Hover: Smart Live Preview for images/logs/text WITHOUT altering selection!
        .onHover { hovering in
            if hovering {
                hoveredURL = item.url
                if state.hoverToSelect {
                    state.selectedURLs = [item.url]
                    state.lastSelectedURL = item.url
                } else if state.smartHoverPreview && NavigationState.isSmartHoverPreviewCandidate(item: item) {
                    state.scheduleInspectorUpdate(url: item.url)
                }
            } else if hoveredURL == item.url {
                hoveredURL = nil
            }
        }
        // Single Click, Multi-Select (Shift/Cmd), and Delayed Rename (Finder Style)
        .onTapGesture {
            let now = Date()
            let isShift = NSEvent.modifierFlags.contains(.shift)
            let isCmd = NSEvent.modifierFlags.contains(.command)
            
            // Inactive window safety check
            let wasJustActivated = now.timeIntervalSince(AppDelegate.lastWindowActivationTime) < 0.25
            if wasJustActivated {
                state.selectItem(item, isShiftPressed: false, isCommandPressed: false)
                lastClickedURL = item.url
                lastClickTimestamp = now
                return
            }
            
            // Multi-selection if Shift or Command is held
            if isShift || isCmd {
                state.selectItem(item, isShiftPressed: isShift, isCommandPressed: isCmd)
                lastClickedURL = item.url
                lastClickTimestamp = now
                return
            }
            
            // Finder-Style Delayed Click on Already-Selected Item to Rename
            let isAlreadySingleSelected = state.selectedURLs.contains(item.url) && state.selectedURLs.count == 1
            let timeSinceLastClick = now.timeIntervalSince(lastClickTimestamp)
            
            if isAlreadySingleSelected && lastClickedURL == item.url && timeSinceLastClick > 0.45 && timeSinceLastClick < 2.5 {
                state.startRename(url: item.url)
                lastClickedURL = nil
                return
            }
            
            lastClickedURL = item.url
            lastClickTimestamp = now
            
            switch state.clickMode {
            case .foldersOnly:
                if item.isDirectory {
                    state.openItem(item)
                } else {
                    state.selectItem(item, isShiftPressed: false, isCommandPressed: false)
                }
            case .always:
                state.openItem(item)
            case .doubleClick:
                state.selectItem(item, isShiftPressed: false, isCommandPressed: false)
            }
        }
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                if state.clickMode == .doubleClick || (!item.isDirectory && state.clickMode == .foldersOnly) {
                    state.openItem(item)
                }
            }
        )
        .contextMenu {
            contextMenuItems(for: item)
        }
    }
    
    // MARK: - Helpers
    private func selectNext() {
        guard let current = state.selectedURLs.first,
              let idx = state.filteredItems.firstIndex(where: { $0.url == current }),
              idx + 1 < state.filteredItems.count else {
            if let first = state.filteredItems.first {
                state.selectedURLs = [first.url]
            }
            return
        }
        state.selectedURLs = [state.filteredItems[idx + 1].url]
    }
    
    private func selectPrevious() {
        guard let current = state.selectedURLs.first,
              let idx = state.filteredItems.firstIndex(where: { $0.url == current }),
              idx > 0 else {
            return
        }
        state.selectedURLs = [state.filteredItems[idx - 1].url]
    }
    
    @ViewBuilder
    private func contextMenuItems(for item: FileItem) -> some View {
        let targets = state.selectedURLs.contains(item.url) ? Array(state.selectedURLs) : [item.url]
        
        Button(action: {
            state.openItem(item)
        }) {
            Label(item.isDirectory ? "Open Folder" : "Open File", systemImage: item.isDirectory ? "folder" : "arrow.up.forward.app")
        }
        
        if !item.isDirectory {
            let ext = item.url.pathExtension.lowercased()
            let isExcel = ["xlsx", "xls", "csv", "tsv", "tab"].contains(ext) || item.name.hasSuffix(".csv.gz") || item.name.hasSuffix(".tsv.gz")
            let isWord = ["docx", "doc", "rtf", "odt", "txt"].contains(ext)
            let isCode = ["py", "rs", "sh", "json", "yaml", "yml", "toml", "md", "c", "cpp", "h", "swift", "js", "ts", "r", "smk"].contains(ext)
            
            if isExcel {
                Button(action: { openWithApp(urls: targets, appName: "Microsoft Excel") }) {
                    Label("Öppna i Microsoft Excel", systemImage: "tablecells.fill")
                }
            } else if isWord {
                Button(action: { openWithApp(urls: targets, appName: "Microsoft Word") }) {
                    Label("Öppna i Microsoft Word", systemImage: "doc.richtext.fill")
                }
            } else if isCode {
                Button(action: { openWithApp(urls: targets, appName: "Visual Studio Code") }) {
                    Label("Öppna i VS Code", systemImage: "curlybraces")
                }
            }
            
            Menu("Öppna med...") {
                Button("Microsoft Excel") { openWithApp(urls: targets, appName: "Microsoft Excel") }
                Button("Microsoft Word") { openWithApp(urls: targets, appName: "Microsoft Word") }
                Button("Visual Studio Code") { openWithApp(urls: targets, appName: "Visual Studio Code") }
                Button("TextEdit") { openWithApp(urls: targets, appName: "TextEdit") }
                Divider()
                Button("Standardprogram (Default)") { for u in targets { NSWorkspace.shared.open(u) } }
            }
        }
        
        Button(action: {
            QuickLookBridge.shared.toggleQuickLook(for: item.url)
        }) {
            Label("Quick Look (Space)", systemImage: "eye")
        }
        
        if item.isDirectory {
            Divider()
            
            Button(action: {
                state.toggleBookmark(url: item.url)
            }) {
                if state.isBookmarked(url: item.url) {
                    Label("Remove from Favorites", systemImage: "star.slash")
                } else {
                    Label("Pin to Favorites", systemImage: "star.fill")
                }
            }
        }
        
        Divider()
        
        if item.isDirectory {
            Button(action: {
                state.calculateSize(for: item)
            }) {
                Label("Calculate Size (du -h)", systemImage: "scalemass")
            }
        }
        
        Button(action: {
            state.showingDiskUsageSheet = true
        }) {
            Label("Directory Disk Usage (du -h)...", systemImage: "chart.bar.xaxis")
        }
        
        Button(action: {
            FileSystemService.shared.openInTerminal(url: item.url)
        }) {
            Label("Open in Terminal", systemImage: "terminal")
        }
        
        Menu("Copy Path As...") {
            Button("Absolute POSIX Path") {
                FileSystemService.shared.copyPathToClipboard(urls: targets)
            }
            Button("CLI Quoted Path") {
                let quoted = targets.map { "'\($0.path)'" }.joined(separator: " ")
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(quoted, forType: .string)
            }
            Button("file:// URI") {
                let uris = targets.map { $0.absoluteString }.joined(separator: "\n")
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(uris, forType: .string)
            }
        }
        
        Button(action: {
            FileSystemService.shared.revealInFinder(url: item.url)
        }) {
            Label("Reveal in Finder", systemImage: "macwindow")
        }
        
        let toolsService = ExternalToolsService.shared
        let isBamOrCram = ["bam", "cram"].contains(item.url.pathExtension.lowercased()) || item.url.lastPathComponent.hasSuffix(".bam") || item.url.lastPathComponent.hasSuffix(".cram")
        
        if toolsService.hasRsQc && isBamOrCram {
            Button(action: {
                toolsService.runRsQc(urls: targets)
            }) {
                Label(targets.count > 1 ? "Kör rs-qc (\(targets.count) filer)" : "Kör rs-qc (Alignment QC)", systemImage: "waveform.badge.magnifyingglass")
            }
        }
        
        if toolsService.hasRsnap && ExternalToolsService.isGenomicsFile(url: item.url) {
            Button(action: {
                toolsService.openInRsnap(urls: targets)
            }) {
                Label(targets.count > 1 ? "Open \(targets.count) Files in rsnap" : "Open in rsnap", systemImage: "waveform.path.ecg")
            }
        }
        
        if toolsService.hasIGV && ExternalToolsService.isGenomicsFile(url: item.url) {
            Button(action: {
                toolsService.openInIGV(urls: targets)
            }) {
                Label(targets.count > 1 ? "Load \(targets.count) Files into IGV" : "Load into IGV", systemImage: "dna")
            }
        }
        
        Divider()
        
        Button(action: {
            state.startRename(url: item.url)
        }) {
            Label("Rename (Enter / F2)", systemImage: "pencil")
        }
        
        Button(role: .destructive, action: {
            let errors = FileSystemService.shared.moveToTrash(urls: targets)
            if !errors.isEmpty {
                state.showToast("⚠️ \(errors.first!)")
            }
            state.reload()
        }) {
            Label("Move to Trash", systemImage: "trash")
        }
    }
    
    private func openWithApp(urls: [URL], appName: String) {
        for url in urls {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-a", appName, url.path]
            do {
                try process.run()
            } catch {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
