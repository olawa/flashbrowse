import SwiftUI
import UniformTypeIdentifiers

public struct RemoteBrowserView: View {
    @ObservedObject var sshService = SSHService.shared
    @ObservedObject var localState: NavigationState
    @State private var hoveredRemotePath: String?
    @State private var selectedRemoteItems: Set<String> = []
    @State private var isDownloading: Bool = false
    @State private var isUploading: Bool = false
    @State private var isRemoteDropTargeted: Bool = false
    @State private var isLocalDropTargeted: Bool = false
    
    // Direct Remote Path Input
    @State private var isEditingRemotePath: Bool = false
    @State private var remotePathInputText: String = ""
    @FocusState private var isRemotePathFocused: Bool
    @State private var lastRemoteNavTime: Date = Date.distantPast
    
    public init(localState: NavigationState) {
        self.localState = localState
    }
    
    private func handleRemoteTap(item: RemoteFileItem) {
        let now = Date()
        // Prevent accidental double-clicks from opening sub-items
        guard now.timeIntervalSince(lastRemoteNavTime) > 0.35 else { return }
        
        if item.isDirectory {
            lastRemoteNavTime = now
            sshService.navigateToRemote(path: item.remotePath)
        } else {
            downloadItemToLocal(item)
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Split-Screen Toolbar Header
            HStack(spacing: 12) {
                // Remote Host Connection Info
                if let host = sshService.activeHost {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        
                        Text(host.alias)
                            .font(.system(size: 12, weight: .bold))
                        
                        Text("(\(host.connectionString))")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.12))
                    .cornerRadius(6)
                }
                
                Spacer()
                
                // Transfer Quick Action Buttons
                HStack(spacing: 6) {
                    Button(action: {
                        uploadSelectedLocalToRemote()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundColor(Color(red: 0.91, green: 0.33, blue: 0.13))
                            Text("Upload to Remote ->")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .disabled(localState.selectedURLs.isEmpty || isUploading)
                    .help("Upload selected local files to remote folder")
                    
                    Button(action: {
                        downloadSelectedRemoteToLocal()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.left.circle.fill")
                                .foregroundColor(.green)
                            Text("<- Download to Local")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedRemoteItems.isEmpty || isDownloading)
                    .help("Download selected remote files to local folder")
                }
                
                if sshService.isLoading || isDownloading || isUploading {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)
                }
                
                // Open Remote Terminal
                Button(action: {
                    openRemoteTerminal()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "terminal.fill")
                        Text("SSH Terminal")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Open interactive SSH shell in terminal (Cmd+J)")
                
                // Disconnect Button
                Button(action: {
                    sshService.disconnect()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Disconnect from SSH")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            // Side-by-Side Dual-Pane Split (Local on Left | Remote on Right)
            HSplitView {
                // LEFT PANE: LOCAL SYSTEM
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "laptopcomputer")
                            .foregroundColor(Color(red: 0.91, green: 0.33, blue: 0.13))
                            .font(.system(size: 12))
                        
                        Text("LOCAL: \(localState.currentDirectory.lastPathComponent)")
                            .font(.system(size: 11, weight: .bold))
                        
                        Spacer()
                        
                        Text("\(localState.filteredItems.count) files")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                    
                    Divider()
                    
                    BreadcrumbBarView(state: localState)
                    
                    Divider()
                    
                    FileTableView(state: localState)
                }
                .frame(minWidth: 320)
                .background(
                    RoundedRectangle(cornerRadius: 0)
                        .fill(isLocalDropTargeted ? Color.green.opacity(0.12) : Color.clear)
                )
                .overlay(
                    Rectangle()
                        .stroke(isLocalDropTargeted ? Color.green : Color.clear, lineWidth: 2)
                )
                .onDrop(of: [UTType.utf8PlainText.identifier, UTType.plainText.identifier, UTType.fileURL.identifier], isTargeted: $isLocalDropTargeted) { providers in
                    handleLocalDrop(providers: providers)
                }
                
                // RIGHT PANE: REMOTE SSH SERVER
                VStack(spacing: 0) {
                    // Remote Path Bar with Direct Input / Cmd+G Support
                    HStack(spacing: 6) {
                        Image(systemName: "server.rack")
                            .foregroundColor(Color.green)
                            .font(.system(size: 12))
                        
                        if isEditingRemotePath {
                            HStack(spacing: 4) {
                                TextField("Enter remote path e.g. /data/projects", text: $remotePathInputText)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 11, design: .monospaced))
                                    .focused($isRemotePathFocused)
                                    .onSubmit {
                                        commitRemotePath()
                                    }
                                    .onExitCommand {
                                        isEditingRemotePath = false
                                    }
                                
                                Button(action: { commitRemotePath() }) {
                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color.green)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(nsColor: .textBackgroundColor))
                            .cornerRadius(4)
                        } else {
                            Button(action: {
                                remotePathInputText = sshService.currentRemotePath
                                isEditingRemotePath = true
                                isRemotePathFocused = true
                            }) {
                                HStack(spacing: 4) {
                                    Text("REMOTE: \(sshService.currentRemotePath)")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .lineLimit(1)
                                    
                                    Image(systemName: "pencil")
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary.opacity(0.6))
                                }
                            }
                            .buttonStyle(.plain)
                            .help("Click or press Cmd+G to jump to remote path")
                        }
                        
                        Spacer()
                        
                        // Remote Navigation Buttons
                        HStack(spacing: 2) {
                            Button(action: { sshService.goBack() }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .buttonStyle(.plain)
                            .frame(width: 18, height: 18)
                            
                            Button(action: { sshService.goForward() }) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .buttonStyle(.plain)
                            .frame(width: 18, height: 18)
                            
                            Button(action: { sshService.goUp() }) {
                                Image(systemName: "chevron.up")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .buttonStyle(.plain)
                            .frame(width: 18, height: 18)
                            
                            Button(action: {
                                Task { await sshService.listRemoteDirectory(path: sshService.currentRemotePath) }
                            }) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 10))
                            }
                            .buttonStyle(.plain)
                            .frame(width: 18, height: 18)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                    
                    Divider()
                    
                    remoteFilesList
                }
                .frame(minWidth: 350)
                .background(
                    RoundedRectangle(cornerRadius: 0)
                        .fill(isRemoteDropTargeted ? Color(red: 0.91, green: 0.33, blue: 0.13).opacity(0.12) : Color.clear)
                )
                .overlay(
                    Rectangle()
                        .stroke(isRemoteDropTargeted ? Color(red: 0.91, green: 0.33, blue: 0.13) : Color.clear, lineWidth: 2)
                )
                .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isRemoteDropTargeted) { providers in
                    handleRemoteDrop(providers: providers)
                }
            }
        }
        .onAppear {
            // Setup 2-Way Remote Terminal Callback
            TerminalService.shared.onRemoteDirectoryChange = { [weak sshService] newRemotePath in
                sshService?.navigateToRemote(path: newRemotePath, addToHistory: true)
            }
        }
        .onKeyPress { press in
            if press.modifiers.contains(.command) && (press.characters == "g" || press.characters == "G") {
                remotePathInputText = sshService.currentRemotePath
                isEditingRemotePath = true
                isRemotePathFocused = true
                return .handled
            }
            return .ignored
        }
    }
    
    private func commitRemotePath() {
        let clean = remotePathInputText.trimmingCharacters(in: .whitespaces)
        if !clean.isEmpty {
            sshService.navigateToRemote(path: clean)
        }
        isEditingRemotePath = false
    }
    
    // MARK: - Remote Files Table
    private var remoteFilesList: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Text("REMOTE NAME")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("PERM")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 85, alignment: .leading)
                
                Text("SIZE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 75, alignment: .trailing)
                
                Text("MODIFIED")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 120, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
            
            Divider()
            
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(sshService.remoteItems) { item in
                        let isSelected = selectedRemoteItems.contains(item.remotePath)
                        let isHovered = hoveredRemotePath == item.remotePath
                        
                        HStack(spacing: 8) {
                            Image(systemName: item.sfSymbolName)
                                .foregroundColor(item.isDirectory ? Color(red: 0.91, green: 0.33, blue: 0.13) : .primary)
                                .font(.system(size: 13))
                                .frame(width: 18)
                            
                            Text(item.name)
                                .font(.system(size: 12, weight: item.isDirectory ? .medium : .regular))
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Text(item.permissions)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                                .frame(width: 85, alignment: .leading)
                            
                            Text(item.formattedSize)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                                .frame(width: 75, alignment: .trailing)
                            
                            Text(item.modifiedString)
                                .font(.system(size: 11))
                                .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                                .frame(width: 120, alignment: .leading)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(isSelected
                                      ? Color(red: 0.91, green: 0.33, blue: 0.13)
                                      : (isHovered ? Color(red: 0.91, green: 0.33, blue: 0.13).opacity(0.12) : Color.clear))
                        )
                        .contentShape(Rectangle())
                        .onDrag {
                            NSItemProvider(object: item.remotePath as NSString)
                        }
                        .onHover { hovering in
                            if hovering {
                                hoveredRemotePath = item.remotePath
                                selectedRemoteItems = [item.remotePath]
                                previewRemoteItem(item)
                            } else if hoveredRemotePath == item.remotePath {
                                hoveredRemotePath = nil
                            }
                        }
                        .onTapGesture {
                            handleRemoteTap(item: item)
                        }
                        .contextMenu {
                            if item.isDirectory {
                                Button("Open Folder") {
                                    sshService.navigateToRemote(path: item.remotePath)
                                }
                            } else {
                                Button("Download to Local (\(localState.currentDirectory.lastPathComponent))") {
                                    downloadItemToLocal(item)
                                }
                            }
                            
                            Button("Copy Remote Path") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(item.remotePath, forType: .string)
                            }
                            
                            Button("Open Remote Terminal Here") {
                                openRemoteTerminal(at: item.isDirectory ? item.remotePath : (item.remotePath as NSString).deletingLastPathComponent)
                            }
                        }
                    }
                }
                .padding(4)
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
    }
    
    // MARK: - Transfer & Actions
    private func previewRemoteItem(_ item: RemoteFileItem) {
        guard !item.isDirectory else { return }
        Task {
            if let cachedURL = try? await sshService.downloadToCache(item: item) {
                localState.scheduleInspectorUpdate(url: cachedURL)
            }
        }
    }
    
    private func downloadItemToLocal(_ item: RemoteFileItem) {
        isDownloading = true
        localState.showToast("⬇️ Downloading \(item.name)...")
        
        Task {
            do {
                try await sshService.downloadFile(item: item, to: localState.currentDirectory)
                isDownloading = false
                localState.reload()
                localState.showToast("✅ Downloaded \(item.name)")
            } catch {
                isDownloading = false
                localState.showToast("Download failed")
            }
        }
    }
    
    private func downloadSelectedRemoteToLocal() {
        let targets = sshService.remoteItems.filter { selectedRemoteItems.contains($0.remotePath) }
        guard !targets.isEmpty else { return }
        
        isDownloading = true
        localState.showToast("⬇️ Downloading \(targets.count) file(s)...")
        
        Task {
            for item in targets {
                try? await sshService.downloadFile(item: item, to: localState.currentDirectory)
            }
            isDownloading = false
            localState.reload()
            localState.showToast("✅ Downloaded \(targets.count) file(s)")
        }
    }
    
    private func uploadSelectedLocalToRemote() {
        let targets = Array(localState.selectedURLs)
        guard !targets.isEmpty else { return }
        
        isUploading = true
        localState.showToast("⬆️ Uploading \(targets.count) file(s)...")
        
        Task {
            for url in targets {
                try? await sshService.uploadFile(localURL: url, to: sshService.currentRemotePath)
            }
            isUploading = false
            localState.showToast("✅ Uploaded \(targets.count) file(s)")
        }
    }
    
    private func handleRemoteDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    var targetURL: URL?
                    if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        targetURL = url
                    } else if let url = item as? URL {
                        targetURL = url
                    } else if let nsURL = item as? NSURL {
                        targetURL = nsURL as URL
                    }
                    
                    if let url = targetURL {
                        Task { @MainActor in
                            self.isUploading = true
                            self.localState.showToast("⬆️ Uploading \(url.lastPathComponent)...")
                            try? await self.sshService.uploadFile(localURL: url, to: self.sshService.currentRemotePath)
                            self.isUploading = false
                            self.localState.showToast("✅ Uploaded \(url.lastPathComponent)")
                        }
                    }
                }
                return true
            }
        }
        return false
    }
    
    private func handleLocalDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) || provider.hasItemConformingToTypeIdentifier(UTType.utf8PlainText.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                    if let remotePath = item as? String {
                        Task { @MainActor in
                            if let remoteItem = self.sshService.remoteItems.first(where: { $0.remotePath == remotePath }) {
                                self.downloadItemToLocal(remoteItem)
                            }
                        }
                    }
                }
                return true
            }
        }
        return false
    }
    
    private func openRemoteTerminal(at customPath: String? = nil) {
        guard let host = sshService.activeHost else { return }
        let path = customPath ?? sshService.currentRemotePath
        TerminalService.shared.startSSHSession(host: host, remotePath: path)
    }
}
