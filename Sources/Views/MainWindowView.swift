import SwiftUI

public struct MainWindowView: View {
    @StateObject private var leftState = NavigationState()
    @StateObject private var rightState = NavigationState()
    @ObservedObject private var indexService = IndexService.shared
    @ObservedObject private var sshService = SSHService.shared
    @ObservedObject private var terminalService = TerminalService.shared
    @ObservedObject private var inspectorState = SharedInspectorState.shared
    @State private var activePane: ActivePane = .left
    @State private var isDualPane: Bool = false
    @State private var isCommanderMode: Bool = false
    @State private var showingBatchRename: Bool = false
    @State private var isCommandPaletteOpen: Bool = false
    @AppStorage("flashbrowse_side_inspector_open") private var isSideInspectorOpen: Bool = true
    
    public init() {}
    
    private var currentActiveState: NavigationState {
        activePane == .left ? leftState : rightState
    }
    
    public var body: some View {
        ZStack {
            NavigationSplitView {
                SidebarView(state: currentActiveState)
            } detail: {
                VStack(spacing: 0) {
                    if sshService.isRemoteBrowserOpen {
                        RemoteBrowserView(localState: leftState)
                    } else if indexService.activeIndex != nil {
                        IndexBrowserView(navState: currentActiveState)
                    } else {
                        DualPaneContainerView(
                            leftState: leftState,
                            rightState: rightState,
                            activePane: $activePane,
                            isDualPane: $isDualPane,
                            isCommanderMode: $isCommanderMode
                        )
                    }
                    
                    // Embedded Terminal Drawer (VS Code style)
                    if terminalService.isOpen {
                        Divider()
                        TerminalPanelView()
                            .transition(.move(edge: .bottom))
                    }
                }
            }
            .navigationTitle(
                sshService.isRemoteBrowserOpen
                ? "SSH: \(sshService.activeHost?.alias ?? "Remote")"
                : (indexService.activeIndex != nil ? "Index: \(indexService.activeIndex!.name)" : (currentActiveState.currentDirectory.lastPathComponent.isEmpty ? "/" : currentActiveState.currentDirectory.lastPathComponent))
            )
            .navigationSubtitle(
                sshService.isRemoteBrowserOpen
                ? "\(sshService.activeHost?.connectionString ?? ""):\(sshService.currentRemotePath)"
                : (indexService.activeIndex != nil ? "\(indexService.totalFilesFound) matching files across workspace" : currentActiveState.currentDirectory.path)
            )
            .frame(minWidth: 800, minHeight: 520)
            
            // Command Palette Overlay (Cmd+K / Cmd+P)
            if isCommandPaletteOpen {
                CommandPaletteView(
                    state: currentActiveState,
                    isPresented: $isCommandPaletteOpen,
                    onSelectWorkspace: { presetId in
                        applyWorkspacePreset(id: presetId)
                    },
                    onSaveWorkspace: { presetId in
                        saveWorkspacePreset(id: presetId)
                    },
                    onToggleTerminal: {
                        withAnimation { terminalService.toggleTerminal() }
                    },
                    onToggleInspector: {
                        InspectorWindowController.shared.toggleWindow()
                    },
                    onToggleCommander: {
                        isCommanderMode.toggle()
                        if isCommanderMode { isDualPane = true }
                    },
                    onOpenBatchRename: {
                        showingBatchRename = true
                    }
                )
                .transition(.opacity)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                // Workspace Presets Quick Selector
                Menu {
                    Section("Switch Workspace (Cmd+1..4)") {
                        ForEach(currentActiveState.workspacePresets) { p in
                            Button(p.name) {
                                applyWorkspacePreset(id: p.id)
                            }
                        }
                    }
                    
                    Divider()
                    
                    Section("Save Current Layout (Cmd+Option+1..4)") {
                        ForEach(1...4, id: \.self) { slot in
                            Button("Save to Preset \(slot)") {
                                saveWorkspacePreset(id: slot)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "rectangle.3.group")
                        Text("W\(currentActiveState.activePresetId)")
                            .font(.system(size: 11, weight: .bold))
                    }
                }
                .menuStyle(.borderlessButton)
                .help("Workspaces & Layout Presets (Cmd+1..4, Cmd+Option+1..4 to save)")
                
                // Command Palette Button (Cmd+K)
                Button(action: {
                    withAnimation { isCommandPaletteOpen.toggle() }
                }) {
                    Image(systemName: "magnifyingglass.circle")
                }
                .help("Command Palette & Quick Jump (Cmd+K / Cmd+P)")
                
                // Integrated Terminal Toggle (Cmd+J)
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        terminalService.toggleTerminal()
                    }
                }) {
                    Image(systemName: terminalService.isOpen ? "terminal.fill" : "terminal")
                        .foregroundColor(terminalService.isOpen ? Color.flashbrowseAccent : .primary)
                }
                .help("Toggle Integrated Terminal (Cmd+J)")
                
                // Dual Pane Toggle (only in normal view)
                if indexService.activeIndex == nil && !sshService.isRemoteBrowserOpen {
                    Button(action: {
                        isDualPane.toggle()
                    }) {
                        Image(systemName: isDualPane ? "square.split.2x1.fill" : "square.split.2x1")
                            .foregroundColor(isDualPane ? Color.flashbrowseAccent : .primary)
                    }
                    .help("Toggle Dual-Pane View (Cmd+D / F3)")
                    
                    // Classic Commander Theme Toggle
                    Button(action: {
                        isCommanderMode.toggle()
                        if isCommanderMode { isDualPane = true }
                    }) {
                        Image(systemName: isCommanderMode ? "slider.horizontal.2.square" : "slider.horizontal.2.square")
                            .foregroundColor(isCommanderMode ? Color.cyan : .secondary)
                    }
                    .help("Toggle Classic Norton Commander Mode")
                }
                
                // Batch Rename Tool
                Button(action: {
                    showingBatchRename = true
                }) {
                    Image(systemName: "pencil.and.list.clipboard")
                }
                .help("Batch Rename Tool (Cmd+Shift+R)")
                
                // Disk Usage Analyzer (Option+S)
                Button(action: {
                    currentActiveState.showingDiskUsageSheet = true
                }) {
                    Image(systemName: "chart.bar.xaxis")
                }
                .help("Directory Disk Usage & Subfolder Sizes (du -h) — Option+S")
                
                // Inspector Companion & iPad Window Toggle (Cmd+I / Cmd+Option+I)
                Button(action: {
                    InspectorWindowController.shared.toggleWindow()
                }) {
                    Image(systemName: inspectorState.isInspectorWindowOpen ? "sidebar.right" : "sidebar.right")
                        .foregroundColor(inspectorState.isInspectorWindowOpen ? Color.flashbrowseAccent : .primary)
                }
                .help("Toggle Inspector Companion / iPad Window (Cmd+I / Cmd+Option+I)")
            }
        }
        .sheet(isPresented: $showingBatchRename) {
            let targets = (currentActiveState.selectedURLs.count <= 1)
                ? currentActiveState.filteredItems
                : currentActiveState.filteredItems.filter { currentActiveState.selectedURLs.contains($0.url) }
            
            BatchRenameView(items: targets) {
                currentActiveState.reload()
            }
        }
        .sheet(isPresented: Binding(
            get: { currentActiveState.showingDiskUsageSheet },
            set: { currentActiveState.showingDiskUsageSheet = $0 }
        )) {
            DiskUsageSheetView(state: currentActiveState)
        }
        // Keyboard Shortcuts
        .keyboardShortcut("d", modifiers: .command)
        .keyboardShortcut("i", modifiers: .command)
        .onKeyPress { press in
            if press.modifiers.contains(.option) && (press.characters == "s" || press.characters == "S" || press.characters == "ß") {
                currentActiveState.showingDiskUsageSheet.toggle()
                return .handled
            }
            return .ignored
        }
        .onCommand(#selector(NSResponder.selectAll(_:))) {
            currentActiveState.selectedURLs = Set(currentActiveState.filteredItems.map { $0.url })
        }
        .onAppear {
            updateTerminalCallback()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if UserDefaults.standard.object(forKey: "flashbrowse_auto_open_inspector") == nil || UserDefaults.standard.bool(forKey: "flashbrowse_auto_open_inspector") {
                    InspectorWindowController.shared.showWindow()
                }
            }
        }
        .onChange(of: activePane) {
            updateTerminalCallback()
        }
        .onChange(of: sshService.isRemoteBrowserOpen) {
            if sshService.isRemoteBrowserOpen {
                activePane = .left
                leftState.reload()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .flashbrowseSwitchWorkspace)) { notif in
            if let id = notif.object as? Int {
                applyWorkspacePreset(id: id)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .flashbrowseSaveWorkspace)) { notif in
            if let id = notif.object as? Int {
                saveWorkspacePreset(id: id)
            }
        }
    }
    
    private func updateTerminalCallback() {
        TerminalService.shared.onLocalDirectoryChange = { [weak leftState, weak rightState] targetURL in
            if activePane == .left {
                leftState?.navigateTo(url: targetURL)
            } else {
                rightState?.navigateTo(url: targetURL)
            }
        }
    }
    
    // MARK: - Workspace Presets Coordinator
    private func applyWorkspacePreset(id: Int) {
        guard let preset = currentActiveState.getPreset(id: id) else { return }
        
        currentActiveState.activePresetId = id
        leftState.navigateTo(url: URL(fileURLWithPath: preset.leftPath))
        if !preset.rightPath.isEmpty {
            rightState.navigateTo(url: URL(fileURLWithPath: preset.rightPath))
        }
        
        self.isDualPane = preset.isDualPane
        self.isCommanderMode = preset.isCommanderMode
        
        withAnimation {
            terminalService.isOpen = preset.isTerminalOpen
        }
        
        if preset.isInspectorOpen {
            InspectorWindowController.shared.showWindow()
        }
        
        currentActiveState.showToast("⚡ Switched to \(preset.name)")
    }
    
    private func saveWorkspacePreset(id: Int) {
        currentActiveState.saveCurrentStateToPreset(
            id: id,
            rightPath: rightState.currentDirectory.path,
            isDualPane: isDualPane,
            isCommanderMode: isCommanderMode,
            isTerminalOpen: terminalService.isOpen,
            isInspectorOpen: SharedInspectorState.shared.isInspectorWindowOpen
        )
    }
}
