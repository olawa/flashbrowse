import SwiftUI

public struct PaletteCommand: Identifiable {
    public let id = UUID()
    public let title: String
    public let subtitle: String
    public let icon: String
    public let category: String
    public let action: () -> Void
}

public struct CommandPaletteView: View {
    @ObservedObject var state: NavigationState
    let onSelectWorkspace: (Int) -> Void
    let onSaveWorkspace: (Int) -> Void
    let onToggleTerminal: () -> Void
    let onToggleInspector: () -> Void
    let onToggleCommander: () -> Void
    let onOpenBatchRename: () -> Void
    @Binding var isPresented: Bool
    
    @State private var searchText: String = ""
    @State private var selectedIndex: Int = 0
    @FocusState private var isFieldFocused: Bool
    
    public init(
        state: NavigationState,
        isPresented: Binding<Bool>,
        onSelectWorkspace: @escaping (Int) -> Void,
        onSaveWorkspace: @escaping (Int) -> Void,
        onToggleTerminal: @escaping () -> Void,
        onToggleInspector: @escaping () -> Void,
        onToggleCommander: @escaping () -> Void,
        onOpenBatchRename: @escaping () -> Void
    ) {
        self.state = state
        self._isPresented = isPresented
        self.onSelectWorkspace = onSelectWorkspace
        self.onSaveWorkspace = onSaveWorkspace
        self.onToggleTerminal = onToggleTerminal
        self.onToggleInspector = onToggleInspector
        self.onToggleCommander = onToggleCommander
        self.onOpenBatchRename = onOpenBatchRename
    }
    
    private var allCommands: [PaletteCommand] {
        var list: [PaletteCommand] = []
        
        // Workspace Presets
        for preset in state.workspacePresets {
            list.append(PaletteCommand(
                title: "Switch to \(preset.name)",
                subtitle: "Shortcut: Cmd+\(preset.id)",
                icon: "rectangle.3.group",
                category: "WORKSPACES"
            ) {
                onSelectWorkspace(preset.id)
            })
        }
        
        // Save to Presets (Safe Cmd+Option+1..4)
        for i in 1...4 {
            list.append(PaletteCommand(
                title: "Save Current Layout to Preset \(i)",
                subtitle: "Shortcut: Cmd+Option+\(i)",
                icon: "square.and.arrow.down",
                category: "SAVE WORKSPACE"
            ) {
                onSaveWorkspace(i)
            })
        }
        
        // Favorites
        for bookmark in state.customBookmarks {
            list.append(PaletteCommand(
                title: "Go to \(bookmark.name)",
                subtitle: bookmark.path,
                icon: bookmark.icon,
                category: "FAVORITES"
            ) {
                state.navigateTo(url: bookmark.url)
            })
        }
        
        // Quick Actions
        list.append(PaletteCommand(
            title: "Paste Clipboard as File",
            subtitle: "Save copied image or text directly to active folder (Cmd+V)",
            icon: "doc.on.clipboard",
            category: "ACTIONS"
        ) {
            state.pasteClipboardAsFile()
        })
        
        list.append(PaletteCommand(
            title: "Batch Rename Files",
            subtitle: "Pattern replace, numbering, case changes (Cmd+Shift+R)",
            icon: "pencil.and.list.clipboard",
            category: "ACTIONS"
        ) {
            onOpenBatchRename()
        })
        
        list.append(PaletteCommand(
            title: "Toggle Integrated Terminal",
            subtitle: "Open/close VS Code style bottom drawer (Cmd+J)",
            icon: "terminal.fill",
            category: "ACTIONS"
        ) {
            onToggleTerminal()
        })
        
        list.append(PaletteCommand(
            title: "Open Multi-Monitor Inspector",
            subtitle: "Live Markdown, HTML, and media preview (Cmd+Option+I)",
            icon: "display.2",
            category: "ACTIONS"
        ) {
            onToggleInspector()
        })
        
        list.append(PaletteCommand(
            title: "Toggle Classic Commander Mode",
            subtitle: "Dual-pane Midnight Blue retro layout",
            icon: "square.split.2x1",
            category: "ACTIONS"
        ) {
            onToggleCommander()
        })
        
        list.append(PaletteCommand(
            title: "Toggle Hidden Dotfiles",
            subtitle: "Show/hide .files (Cmd+Shift+.)",
            icon: "eye.slash",
            category: "ACTIONS"
        ) {
            state.showHiddenFiles.toggle()
        })
        
        return list
    }
    
    private var filteredCommands: [PaletteCommand] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if q.isEmpty {
            return allCommands
        }
        return allCommands.filter {
            $0.title.lowercased().contains(q) || $0.subtitle.lowercased().contains(q) || $0.category.lowercased().contains(q)
        }
    }
    
    public var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
            
            VStack(spacing: 0) {
                // Search Input Field
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16))
                        .foregroundColor(Color.flashbrowseAccent)
                    
                    TextField("Type a command, folder name, or action...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .focused($isFieldFocused)
                        .onSubmit {
                            executeSelected()
                        }
                        .onExitCommand {
                            isPresented = false
                        }
                        .onKeyPress(.upArrow) {
                            if selectedIndex > 0 { selectedIndex -= 1 }
                            return .handled
                        }
                        .onKeyPress(.downArrow) {
                            if selectedIndex + 1 < filteredCommands.count { selectedIndex += 1 }
                            return .handled
                        }
                }
                .padding(14)
                .background(Color(nsColor: .windowBackgroundColor))
                
                Divider()
                
                // Commands List
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(filteredCommands.enumerated()), id: \.element.id) { idx, cmd in
                                let isSelected = (idx == selectedIndex)
                                
                                Button(action: {
                                    cmd.action()
                                    isPresented = false
                                }) {
                                    commandRow(cmd: cmd, isSelected: isSelected)
                                }
                                .buttonStyle(.plain)
                                .id(idx)
                            }
                        }
                        .padding(8)
                    }
                    .frame(maxHeight: 320)
                    .onChange(of: selectedIndex) {
                        proxy.scrollTo(selectedIndex, anchor: .center)
                    }
                }
            }
            .frame(width: 560)
            .background(Color(nsColor: .windowBackgroundColor))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.35), radius: 20, x: 0, y: 10)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
        }
        .onAppear {
            isFieldFocused = true
            selectedIndex = 0
        }
        .onChange(of: searchText) {
            selectedIndex = 0
        }
    }
    
    private func executeSelected() {
        guard selectedIndex >= 0, selectedIndex < filteredCommands.count else { return }
        filteredCommands[selectedIndex].action()
        isPresented = false
    }
    
    @ViewBuilder
    private func commandRow(cmd: PaletteCommand, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: cmd.icon)
                .font(.system(size: 14))
                .foregroundColor(isSelected ? .white : Color.flashbrowseAccent)
                .frame(width: 22)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(cmd.title)
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(cmd.subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }
            
            Spacer()
            
            Text(cmd.category)
                .font(.system(size: 9, weight: .bold))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(isSelected ? Color.white.opacity(0.25) : Color(nsColor: .controlBackgroundColor))
                .foregroundColor(isSelected ? .white : .secondary)
                .cornerRadius(4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.flashbrowseAccent : Color.clear)
        )
    }
}
