import SwiftUI

public struct TerminalPanelView: View {
    @ObservedObject var terminalService = TerminalService.shared
    @State private var inputCommand: String = ""
    @FocusState private var isInputFocused: Bool
    
    public init() {}
    
    private var promptText: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = terminalService.workingDirectory.path.replacingOccurrences(of: home, with: "~")
        return "➜ \(path) $"
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Mini Toolbar
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "terminal.fill")
                        .foregroundColor(Color(red: 0.91, green: 0.33, blue: 0.13))
                        .font(.system(size: 11))
                    
                    Text("TERMINAL (zsh)")
                        .font(.system(size: 11, weight: .bold))
                }
                
                Text("• \(terminalService.workingDirectory.path)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Spacer()
                
                // Auto-CD Toggle
                Button(action: {
                    terminalService.autoSyncWithBrowser.toggle()
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Auto-CD")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(terminalService.autoSyncWithBrowser ? Color(red: 0.91, green: 0.33, blue: 0.13).opacity(0.2) : Color.clear)
                    .foregroundColor(terminalService.autoSyncWithBrowser ? Color(red: 0.91, green: 0.33, blue: 0.13) : .secondary)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help("Automatically cd to active folder when navigating in Flashbrowse")
                
                if terminalService.isRunningCommand {
                    Button(action: {
                        terminalService.cancelRunningCommand()
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "stop.circle.fill")
                            Text("Stop")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Cancel running command (Ctrl+C)")
                }
                
                // Clear Button
                Button(action: {
                    terminalService.clear()
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
                .help("Hide Terminal (Cmd+J)")
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
            
            // Terminal Output Buffer
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
                        
                        Color.clear
                            .frame(height: 1)
                            .id("terminalBottom")
                    }
                    .padding(8)
                }
                .background(Color(red: 0.08, green: 0.08, blue: 0.08))
                .onChange(of: terminalService.outputLines.count) {
                    proxy.scrollTo("terminalBottom", anchor: .bottom)
                }
            }
            
            // Interactive Input Bar
            HStack(spacing: 6) {
                Text(promptText)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color(red: 0.91, green: 0.33, blue: 0.13))
                
                TextField("", text: $inputCommand)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white)
                    .focused($isInputFocused)
                    .onSubmit {
                        submitCommand()
                    }
                    .onKeyPress(.upArrow) {
                        historyPrevious()
                        return .handled
                    }
                    .onKeyPress(.downArrow) {
                        historyNext()
                        return .handled
                    }
                
                if terminalService.isRunningCommand {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 14, height: 14)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(red: 0.1, green: 0.1, blue: 0.1))
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Color.white.opacity(0.15)),
                alignment: .top
            )
        }
        .frame(minHeight: 140, idealHeight: 200, maxHeight: 400)
        .onAppear {
            isInputFocused = true
        }
    }
    
    private func submitCommand() {
        let cmd = inputCommand
        inputCommand = ""
        terminalService.executeCommand(cmd)
    }
    
    private func historyPrevious() {
        let history = terminalService.commandHistory
        guard !history.isEmpty else { return }
        
        if terminalService.historyIndex > 0 {
            terminalService.historyIndex -= 1
            inputCommand = history[terminalService.historyIndex]
        }
    }
    
    private func historyNext() {
        let history = terminalService.commandHistory
        guard !history.isEmpty else { return }
        
        if terminalService.historyIndex + 1 < history.count {
            terminalService.historyIndex += 1
            inputCommand = history[terminalService.historyIndex]
        } else {
            terminalService.historyIndex = history.count
            inputCommand = ""
        }
    }
}
