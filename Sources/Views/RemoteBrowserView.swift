import SwiftUI

public struct RemoteBrowserView: View {
    @ObservedObject var sshService = SSHService.shared
    @ObservedObject var localState: NavigationState
    @State private var hoveredRemotePath: String?
    @State private var selectedRemotePath: String?
    @State private var isDownloading: Bool = false
    
    public init(localState: NavigationState) {
        self.localState = localState
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Remote Header Bar
            HStack(spacing: 8) {
                if let host = sshService.activeHost {
                    HStack(spacing: 5) {
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
                
                // Back / Forward / Up Buttons
                HStack(spacing: 2) {
                    Button(action: { sshService.goBack() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    .frame(width: 24, height: 24)
                    
                    Button(action: { sshService.goForward() }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    .frame(width: 24, height: 24)
                    
                    Button(action: { sshService.goUp() }) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    .frame(width: 24, height: 24)
                }
                
                // Remote Path Pill Bar
                HStack(spacing: 4) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 11))
                        .foregroundColor(Color(red: 0.91, green: 0.33, blue: 0.13))
                    
                    Text(sshService.currentRemotePath)
                        .font(.system(size: 12, design: .monospaced))
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(6)
                
                if sshService.isLoading || isDownloading {
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
                        Text("Remote Shell")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Open SSH shell in terminal (Cmd+J)")
                
                // Refresh
                Button(action: {
                    Task { await sshService.listRemoteDirectory(path: sshService.currentRemotePath) }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                
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
            
            // Remote Files Table / Error State
            if let err = sshService.errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.orange)
                    Text("Connection Issue")
                        .font(.headline)
                    Text(err)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    Button("Retry Connection") {
                        Task { await sshService.listRemoteDirectory(path: sshService.currentRemotePath) }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .textBackgroundColor))
            } else {
                remoteTable
            }
        }
    }
    
    // MARK: - Remote Table
    private var remoteTable: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Text("NAME")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("PERMISSIONS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 90, alignment: .leading)
                
                Text("SIZE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .trailing)
                
                Text("MODIFIED")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 130, alignment: .leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
            
            Divider()
            
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(sshService.remoteItems) { item in
                        let isSelected = selectedRemotePath == item.remotePath
                        let isHovered = hoveredRemotePath == item.remotePath
                        
                        HStack(spacing: 8) {
                            Image(systemName: item.sfSymbolName)
                                .foregroundColor(item.isDirectory ? Color(red: 0.91, green: 0.33, blue: 0.13) : .primary)
                                .font(.system(size: 14))
                                .frame(width: 20)
                            
                            Text(item.name)
                                .font(.system(size: 12, weight: item.isDirectory ? .medium : .regular))
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Text(item.permissions)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                                .frame(width: 90, alignment: .leading)
                            
                            Text(item.formattedSize)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                                .frame(width: 80, alignment: .trailing)
                            
                            Text(item.modifiedString)
                                .font(.system(size: 11))
                                .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                                .frame(width: 130, alignment: .leading)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isSelected
                                      ? Color(red: 0.91, green: 0.33, blue: 0.13)
                                      : (isHovered ? Color(red: 0.91, green: 0.33, blue: 0.13).opacity(0.12) : Color.clear))
                        )
                        .contentShape(Rectangle())
                        .onHover { hovering in
                            if hovering {
                                hoveredRemotePath = item.remotePath
                                selectedRemotePath = item.remotePath
                                previewRemoteItem(item)
                            } else if hoveredRemotePath == item.remotePath {
                                hoveredRemotePath = nil
                            }
                        }
                        .onTapGesture {
                            if item.isDirectory {
                                sshService.navigateToRemote(path: item.remotePath)
                            } else {
                                downloadItemToLocal(item)
                            }
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
                .padding(6)
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
    }
    
    // MARK: - Actions
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
                localState.showToast("Failed to download \(item.name)")
            }
        }
    }
    
    private func openRemoteTerminal(at customPath: String? = nil) {
        guard let host = sshService.activeHost else { return }
        let path = customPath ?? sshService.currentRemotePath
        
        TerminalService.shared.isOpen = true
        let sshTarget = host.user.isEmpty ? host.hostName : "\(host.user)@\(host.hostName)"
        var cmd = "ssh"
        if host.port != 22 { cmd += " -p \(host.port)" }
        if let key = host.identityFile, !key.isEmpty { cmd += " -i \(key)" }
        cmd += " -t \(sshTarget) 'cd \(path) && exec $SHELL -l'"
        
        TerminalService.shared.executeCommand(cmd)
    }
}
