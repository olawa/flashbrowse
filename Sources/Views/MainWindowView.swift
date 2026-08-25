import SwiftUI

public struct MainWindowView: View {
    @StateObject private var leftState = NavigationState()
    @StateObject private var rightState = NavigationState()
    @ObservedObject private var indexService = IndexService.shared
    @ObservedObject private var terminalService = TerminalService.shared
    @State private var activePane: ActivePane = .left
    @State private var isDualPane: Bool = false
    @State private var isCommanderMode: Bool = false
    @State private var showingBatchRename: Bool = false
    @State private var isCommandPaletteOpen: Bool = false
    
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
                    if indexService.activeIndex != nil {
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
            .navigationTitle(indexService.activeIndex != nil ? "Index: \(indexService.activeIndex!.name)" : (currentActiveState.currentDirectory.lastPathComponent.isEmpty ? "/" : currentActiveState.currentDirectory.lastPathComponent))
            .navigationSubtitle(indexService.activeIndex != nil ? "\(indexService.totalFilesFound) matching files across workspace" : currentActiveState.currentDirectory.path)
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
                    HStack(spacing: 3) {
                        Image(systemName: "terminal.fill")
                        if terminalService.isOpen {
                            Text("Terminal")
                                .font(.system(size: 11, weight: .bold))
                        }
                    }
                    .foregroundColor(terminalService.isOpen ? Color(red: 0.91, green: 0.33, blue: 0.13) : .primary)
                }
                .help("Toggle Integrated Terminal (Cmd+J)")
                
                // Dual Pane Toggle (only in normal view)
                if indexService.activeIndex == nil {
                    Button(action: {
                        isDualPane.toggle()
                    }) {
                        Image(systemName: isDualPane ? "square.split.2x1.fill" : "square.split.2x1")
                            .foregroundColor(isDualPane ? Color(red: 0.91, green: 0.33, blue: 0.13) : .primary)
                    }
                    .help("Toggle Dual-Pane Split View (Cmd+D / F3)")
                    
                    // Classic Commander Theme Toggle
                    Button(action: {
                        isCommanderMode.toggle()
                        if isCommanderMode { isDualPane = true }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "terminal")
                            Text("Commander")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(isCommanderMode ? Color.cyan.opacity(0.2) : Color.clear)
                        .foregroundColor(isCommanderMode ? Color.cyan : .primary)
                        .cornerRadius(4)
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
                
                // Detached Multi-Monitor Inspector
                Button(action: {
                    InspectorWindowController.shared.toggleWindow()
                }) {
                    Image(systemName: "display.2")
                }
                .help("Open Live Inspector on External Monitor (Cmd+Option+I)")
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
        // Keyboard Shortcuts
        .keyboardShortcut("d", modifiers: .command)
        .onCommand(#selector(NSResponder.selectAll(_:))) {
            currentActiveState.selectedURLs = Set(currentActiveState.filteredItems.map { $0.url })
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
