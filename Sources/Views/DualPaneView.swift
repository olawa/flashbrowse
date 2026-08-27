import SwiftUI

public enum ActivePane {
    case left
    case right
}

public struct DualPaneContainerView: View {
    @ObservedObject var leftState: NavigationState
    @ObservedObject var rightState: NavigationState
    @ObservedObject var inspectorState = SharedInspectorState.shared
    @Binding var activePane: ActivePane
    @Binding var isDualPane: Bool
    @Binding var isCommanderMode: Bool
    public var isDualInspectorEnabled: Bool = true
    
    @State private var showingNewFolderAlert: Bool = false
    @State private var newFolderName: String = ""
    @State private var showingBatchRename: Bool = false
    
    public init(
        leftState: NavigationState,
        rightState: NavigationState,
        activePane: Binding<ActivePane>,
        isDualPane: Binding<Bool>,
        isCommanderMode: Binding<Bool>,
        isDualInspectorEnabled: Bool = true
    ) {
        self.leftState = leftState
        self.rightState = rightState
        self._activePane = activePane
        self._isDualPane = isDualPane
        self._isCommanderMode = isCommanderMode
        self.isDualInspectorEnabled = isDualInspectorEnabled
    }
    
    private var activeState: NavigationState {
        activePane == .left ? leftState : rightState
    }
    
    private var inactiveState: NavigationState {
        activePane == .left ? rightState : leftState
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            if isDualPane {
                HSplitView {
                    paneWrapper(state: leftState, isFocused: activePane == .left) {
                        activePane = .left
                    }
                    .frame(minWidth: 260)
                    
                    if isDualInspectorEnabled && inspectorState.isInspectorVisible && !inspectorState.isInspectorDetached {
                        InspectorView(state: SharedInspectorState.left, titlePrefix: "Left: ")
                            .frame(minWidth: 240, idealWidth: 360, maxWidth: 800)
                    }
                    
                    paneWrapper(state: rightState, isFocused: activePane == .right) {
                        activePane = .right
                    }
                    .frame(minWidth: 260)
                    
                    if isDualInspectorEnabled && inspectorState.isInspectorVisible && !inspectorState.isInspectorDetached {
                        InspectorView(state: SharedInspectorState.right, titlePrefix: "Right: ")
                            .frame(minWidth: 240, idealWidth: 360, maxWidth: 800)
                    }
                }
            } else {
                paneWrapper(state: leftState, isFocused: true) {
                    activePane = .left
                }
            }
            
            // Classic Commander Function Keys Bottom Bar
            if isCommanderMode {
                commanderFunctionBar
            }
        }
        .sheet(isPresented: $showingBatchRename) {
            // Default to entire directory if 0 or 1 file is selected; use selection only if 2+ selected
            let targets = (activeState.selectedURLs.count <= 1)
                ? activeState.filteredItems
                : activeState.filteredItems.filter { activeState.selectedURLs.contains($0.url) }
            
            BatchRenameView(items: targets) {
                activeState.reload()
            }
        }
        .sheet(isPresented: $showingNewFolderAlert) {
            VStack(spacing: 14) {
                Text("Create New Directory")
                    .font(.headline)
                
                TextField("Directory Name", text: $newFolderName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 260)
                
                HStack {
                    Button("Cancel") {
                        showingNewFolderAlert = false
                        newFolderName = ""
                    }
                    .keyboardShortcut(.cancelAction)
                    
                    Button("Create") {
                        if !newFolderName.trimmingCharacters(in: .whitespaces).isEmpty {
                            FileSystemService.shared.createDirectory(named: newFolderName, in: activeState.currentDirectory)
                            activeState.reload()
                        }
                        showingNewFolderAlert = false
                        newFolderName = ""
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
            .frame(width: 320)
        }
    }
    
    @ViewBuilder
    private func paneWrapper(state: NavigationState, isFocused: Bool, onSelect: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            BreadcrumbBarView(state: state)
            
            Divider()
            
            FileTableView(state: state)
            
            StatusBarView(state: state)
        }
        .background(isCommanderMode ? Color(red: 0.0, green: 0.11, blue: 0.22) : Color(nsColor: .windowBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(isFocused && isDualPane ? (isCommanderMode ? Color.cyan : Color.flashbrowseAccent) : Color.clear, lineWidth: 2)
        )
        .onTapGesture {
            onSelect()
        }
    }
    
    // MARK: - Classic Commander F-Key Bottom Bar
    private var commanderFunctionBar: some View {
        HStack(spacing: 2) {
            fKeyButton(key: "F3", label: "View") {
                if let sel = activeState.selectedURLs.first {
                    QuickLookBridge.shared.toggleQuickLook(for: sel)
                }
            }
            fKeyButton(key: "F4", label: "Inspect") {
                InspectorWindowController.shared.toggleWindow()
            }
            fKeyButton(key: "F5", label: "Copy ->") {
                copyToOtherPane()
            }
            fKeyButton(key: "F6", label: "Move ->") {
                moveToOtherPane()
            }
            fKeyButton(key: "F7", label: "New Folder") {
                showingNewFolderAlert = true
            }
            fKeyButton(key: "F8", label: "Delete") {
                deleteSelected()
            }
            fKeyButton(key: "F9", label: "Batch Rename") {
                showingBatchRename = true
            }
            fKeyButton(key: "Tab", label: "Switch Pane") {
                activePane = (activePane == .left) ? .right : .left
            }
        }
        .padding(3)
        .background(Color(red: 0.0, green: 0.08, blue: 0.16))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.cyan.opacity(0.4)),
            alignment: .top
        )
    }
    
    @ViewBuilder
    private func fKeyButton(key: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Text(key)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.cyan)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(3)
                
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background(Color(red: 0.0, green: 0.16, blue: 0.32))
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Commander Actions
    private func copyToOtherPane() {
        let targets = Array(activeState.selectedURLs)
        guard !targets.isEmpty else { return }
        
        let destination = inactiveState.currentDirectory
        let errors = FileSystemService.shared.copyItems(urls: targets, to: destination)
        if !errors.isEmpty {
            activeState.showToast("⚠️ \(errors.first!)")
        }
        inactiveState.reload()
    }
    
    private func moveToOtherPane() {
        let targets = Array(activeState.selectedURLs)
        guard !targets.isEmpty else { return }
        
        let destination = inactiveState.currentDirectory
        let errors = FileSystemService.shared.moveItems(urls: targets, to: destination)
        if !errors.isEmpty {
            activeState.showToast("⚠️ \(errors.first!)")
        }
        activeState.reload()
        inactiveState.reload()
    }
    
    private func deleteSelected() {
        let targets = Array(activeState.selectedURLs)
        guard !targets.isEmpty else { return }
        
        let errors = FileSystemService.shared.moveToTrash(urls: targets)
        if !errors.isEmpty {
            activeState.showToast("⚠️ \(errors.first!)")
        }
        activeState.reload()
    }
}
