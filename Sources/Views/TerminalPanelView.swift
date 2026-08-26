import SwiftUI

public struct TerminalPanelView: View {
    @ObservedObject var terminalService = TerminalService.shared
    @ObservedObject var sshService = SSHService.shared
    
    @State private var inputCommand: String = ""
    @State private var rightInputCommand: String = ""
    
    @FocusState private var isLeftInputFocused: Bool
    @FocusState private var isRightInputFocused: Bool
    
    public init() {}
    
    private var leftPromptText: String {
        if terminalService.isSSHTerminalMode && !terminalService.isDualTerminalSplit, let host = terminalService.sshHost {
            return "➜ \(host.alias):\(terminalService.remoteWorkingDir) $"
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = terminalService.workingDirectory.path.replacingOccurrences(of: home, with: "~")
        return "➜ \(path) $"
    }
    
    private var rightPromptText: String {
        if terminalService.isSSHTerminalMode, let host = terminalService.sshHost {
            return "➜ \(host.alias):\(terminalService.remoteWorkingDir) $"
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = terminalService.rightWorkingDirectory.path.replacingOccurrences(of: home, with: "~")
        return "➜ \(path) $"
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Mini Toolbar
            HStack(spacing: 8) {
                // Session Type Badge / Switcher
                if let host = sshService.activeHost {
                    HStack(spacing: 2) {
                        Button(action: {
                            terminalService.switchToLocalSession()
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "laptopcomputer")
                                Text("Local")
                            }
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(!terminalService.isSSHTerminalMode ? Color.flashbrowseAccent : Color.clear)
                            .foregroundColor(!terminalService.isSSHTerminalMode ? .white : .secondary)
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            terminalService.startSSHSession(host: host, remotePath: sshService.currentRemotePath)
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "server.rack")
                                Text("SSH: \(host.alias)")
                            }
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(terminalService.isSSHTerminalMode ? Color.green : Color.clear)
                            .foregroundColor(terminalService.isSSHTerminalMode ? .black : .secondary)
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(2)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(5)
                } else {
                    HStack(spacing: 5) {
                        Image(systemName: "terminal.fill")
                            .foregroundColor(Color.flashbrowseAccent)
                            .font(.system(size: 11))
                        
                        Text("TERMINAL (zsh)")
                            .font(.system(size: 11, weight: .bold))
                    }
                }
                
                // Dual Terminal Split Switcher
                Button(action: {
                    terminalService.isDualTerminalSplit.toggle()
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: terminalService.isDualTerminalSplit ? "square.split.2x1.fill" : "square.split.2x1")
                        Text(terminalService.isDualTerminalSplit ? "Dual Terminal" : "Split Terminal")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(terminalService.isDualTerminalSplit ? Color.cyan.opacity(0.2) : Color.clear)
                    .foregroundColor(terminalService.isDualTerminalSplit ? Color.cyan : .secondary)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help("Toggle Side-by-Side Dual Terminals matching your split view")
                
                Spacer()
                
                // Interactive 2-Way Sync Toggle Button
                Button(action: {
                    terminalService.autoSyncWithBrowser.toggle()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 9, weight: .bold))
                        Text(terminalService.autoSyncWithBrowser ? "2-Way Sync: ON" : "2-Way Sync: OFF")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(terminalService.autoSyncWithBrowser ? Color.flashbrowseAccent : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        terminalService.autoSyncWithBrowser
                        ? Color.flashbrowseAccent.opacity(0.2)
                        : Color.white.opacity(0.08)
                    )
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help("Click to toggle automatic 2-way sync: 'cd <dir>' in terminal moves the browser, and browsing folders moves the terminal")
                
                // Clear Button
                Button(action: {
                    terminalService.clear()
                    terminalService.clearRight()
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear Terminal")
                
                // Close / Minimize Button
                Button(action: {
                    terminalService.isOpen = false
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Hide Terminal (Cmd+J / Esc)")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(red: 0.12, green: 0.12, blue: 0.12))
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Color.white.opacity(0.1)),
                alignment: .bottom
            )
            
            // Terminal Panels Body (Single or Dual Split)
            if terminalService.isDualTerminalSplit {
                HSplitView {
                    leftTerminalView
                    rightTerminalView
                }
            } else {
                leftTerminalView
            }
        }
        .frame(minHeight: 140, idealHeight: 200, maxHeight: 400)
        .onAppear {
            isLeftInputFocused = true
        }
        .onChange(of: terminalService.focusInputTrigger) {
            isLeftInputFocused = true
        }
    }
    
    // MARK: - Left / Primary Terminal
    private var leftTerminalView: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(terminalService.outputLines) { line in
                            Text(line.text)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(
                                    line.isError
                                    ? Color.red.opacity(0.9)
                                    : (line.isPrompt ? Color.cyan : Color(red: 0.9, green: 0.9, blue: 0.9))
                                )
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        Color.clear.frame(height: 1).id("leftBottom")
                    }
                    .padding(8)
                }
                .background(Color(red: 0.08, green: 0.08, blue: 0.08))
                .onChange(of: terminalService.outputLines.count) {
                    proxy.scrollTo("leftBottom", anchor: .bottom)
                }
            }
            
            HStack(spacing: 6) {
                Text(leftPromptText)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(terminalService.isSSHTerminalMode && !terminalService.isDualTerminalSplit ? Color.green : Color.flashbrowseAccent)
                
                TextField("", text: $inputCommand)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white)
                    .focused($isLeftInputFocused)
                    .onSubmit {
                        let cmd = inputCommand
                        inputCommand = ""
                        terminalService.executeCommand(cmd)
                    }
                    .onKeyPress(.upArrow) {
                        historyPrevious(isRight: false)
                        return .handled
                    }
                    .onKeyPress(.downArrow) {
                        historyNext(isRight: false)
                        return .handled
                    }
                    .onExitCommand {
                        isLeftInputFocused = false
                    }
                
                if terminalService.isRunningCommand {
                    ProgressView().scaleEffect(0.5).frame(width: 14, height: 14)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(red: 0.1, green: 0.1, blue: 0.1))
            .overlay(
                Rectangle().frame(height: 0.5).foregroundColor(Color.white.opacity(0.15)),
                alignment: .top
            )
        }
    }
    
    // MARK: - Right / Secondary Terminal (Dual-Split)
    private var rightTerminalView: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(terminalService.rightOutputLines) { line in
                            Text(line.text)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(
                                    line.isError
                                    ? Color.red.opacity(0.9)
                                    : (line.isPrompt ? Color.green : Color(red: 0.9, green: 0.9, blue: 0.9))
                                )
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        Color.clear.frame(height: 1).id("rightBottom")
                    }
                    .padding(8)
                }
                .background(Color(red: 0.06, green: 0.08, blue: 0.06))
                .onChange(of: terminalService.rightOutputLines.count) {
                    proxy.scrollTo("rightBottom", anchor: .bottom)
                }
            }
            
            HStack(spacing: 6) {
                Text(rightPromptText)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(terminalService.isSSHTerminalMode ? Color.green : Color.cyan)
                
                TextField("", text: $rightInputCommand)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white)
                    .focused($isRightInputFocused)
                    .onSubmit {
                        let cmd = rightInputCommand
                        rightInputCommand = ""
                        terminalService.executeRightCommand(cmd)
                    }
                    .onKeyPress(.upArrow) {
                        historyPrevious(isRight: true)
                        return .handled
                    }
                    .onKeyPress(.downArrow) {
                        historyNext(isRight: true)
                        return .handled
                    }
                    .onExitCommand {
                        isRightInputFocused = false
                    }
                
                if terminalService.isRightRunningCommand {
                    ProgressView().scaleEffect(0.5).frame(width: 14, height: 14)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(red: 0.08, green: 0.1, blue: 0.08))
            .overlay(
                Rectangle().frame(height: 0.5).foregroundColor(Color.white.opacity(0.15)),
                alignment: .top
            )
        }
    }
    
    private func historyPrevious(isRight: Bool) {
        let history = isRight ? terminalService.rightCommandHistory : terminalService.commandHistory
        guard !history.isEmpty else { return }
        
        if isRight {
            if terminalService.rightHistoryIndex > 0 {
                terminalService.rightHistoryIndex -= 1
                rightInputCommand = history[terminalService.rightHistoryIndex]
            }
        } else {
            if terminalService.historyIndex > 0 {
                terminalService.historyIndex -= 1
                inputCommand = history[terminalService.historyIndex]
            }
        }
    }
    
    private func historyNext(isRight: Bool) {
        let history = isRight ? terminalService.rightCommandHistory : terminalService.commandHistory
        guard !history.isEmpty else { return }
        
        if isRight {
            if terminalService.rightHistoryIndex + 1 < history.count {
                terminalService.rightHistoryIndex += 1
                rightInputCommand = history[terminalService.rightHistoryIndex]
            } else {
                terminalService.rightHistoryIndex = history.count
                rightInputCommand = ""
            }
        } else {
            if terminalService.historyIndex + 1 < history.count {
                terminalService.historyIndex += 1
                inputCommand = history[terminalService.historyIndex]
            } else {
                terminalService.historyIndex = history.count
                inputCommand = ""
            }
        }
    }
}
