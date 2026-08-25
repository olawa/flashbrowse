import Foundation
import Combine

public struct TerminalOutputLine: Identifiable, Hashable {
    public let id = UUID()
    public let text: String
    public let isError: Bool
    public let isPrompt: Bool
    
    public init(text: String, isError: Bool = false, isPrompt: Bool = false) {
        self.text = text
        self.isError = isError
        self.isPrompt = isPrompt
    }
}

@MainActor
public class TerminalService: ObservableObject {
    public static let shared = TerminalService()
    
    @Published public var isOpen: Bool = false
    @Published public var workingDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    @Published public var outputLines: [TerminalOutputLine] = []
    @Published public var isRunningCommand: Bool = false
    @Published public var autoSyncWithBrowser: Bool = true
    
    public var commandHistory: [String] = []
    public var historyIndex: Int = -1
    private var activeProcess: Process?
    
    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.workingDirectory = home
        appendLine("⚡ Flashbrowse Integrated Terminal (zsh)", isPrompt: true)
        appendLine("Type commands or navigate folders in Flashbrowse (Auto-CD enabled).", isPrompt: true)
        appendLine("----------------------------------------------------------------", isPrompt: true)
    }
    
    public func appendLine(_ text: String, isError: Bool = false, isPrompt: Bool = false) {
        outputLines.append(TerminalOutputLine(text: text, isError: isError, isPrompt: isPrompt))
        if outputLines.count > 1000 {
            outputLines.removeFirst(outputLines.count - 1000)
        }
    }
    
    public func toggleTerminal() {
        isOpen.toggle()
    }
    
    public func syncWorkingDirectory(_ url: URL) {
        guard autoSyncWithBrowser else { return }
        let target = url.standardized
        if target != workingDirectory {
            workingDirectory = target
            appendLine("📂 cd \(target.path)", isPrompt: true)
        }
    }
    
    public func clear() {
        outputLines.removeAll()
        appendLine("⚡ Flashbrowse Terminal - \(workingDirectory.path)", isPrompt: true)
    }
    
    public func cancelRunningCommand() {
        if let proc = activeProcess, proc.isRunning {
            proc.terminate()
            appendLine("^C (Command cancelled)", isError: true)
            isRunningCommand = false
            activeProcess = nil
        }
    }
    
    public func executeCommand(_ rawCommand: String) {
        let trimmed = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        commandHistory.append(trimmed)
        historyIndex = commandHistory.count
        
        // Print prompt line
        let promptPath = workingDirectory.path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~")
        appendLine("➜ \(promptPath) $ \(trimmed)", isPrompt: true)
        
        // Built-in commands
        if trimmed == "clear" {
            clear()
            return
        }
        
        if trimmed.hasPrefix("cd ") {
            let pathArg = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            handleCD(path: pathArg)
            return
        }
        
        if trimmed == "cd" {
            workingDirectory = FileManager.default.homeDirectoryForCurrentUser
            return
        }
        
        // Run via subprocess
        isRunningCommand = true
        let process = Process()
        let pipe = Pipe()
        let errPipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "cd '\(workingDirectory.path)' && \(trimmed)"]
        process.standardOutput = pipe
        process.standardError = errPipe
        
        // Pass parent environment including PATH
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        process.environment = env
        
        self.activeProcess = process
        
        // Asynchronous streaming output
        let outHandle = pipe.fileHandleForReading
        let errHandle = errPipe.fileHandleForReading
        
        outHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            if let str = String(data: data, encoding: .utf8) {
                Task { @MainActor in
                    for line in str.components(separatedBy: "\n") {
                        if !line.isEmpty {
                            self?.appendLine(line)
                        }
                    }
                }
            }
        }
        
        errHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            if let str = String(data: data, encoding: .utf8) {
                Task { @MainActor in
                    for line in str.components(separatedBy: "\n") {
                        if !line.isEmpty {
                            self?.appendLine(line, isError: true)
                        }
                    }
                }
            }
        }
        
        process.terminationHandler = { [weak self] proc in
            Task { @MainActor in
                outHandle.readabilityHandler = nil
                errHandle.readabilityHandler = nil
                self?.isRunningCommand = false
                self?.activeProcess = nil
            }
        }
        
        do {
            try process.run()
        } catch {
            appendLine("Error executing command: \(error.localizedDescription)", isError: true)
            isRunningCommand = false
            activeProcess = nil
        }
    }
    
    private func handleCD(path: String) {
        let expanded = NSString(string: path).expandingTildeInPath
        let targetURL: URL
        if expanded.hasPrefix("/") {
            targetURL = URL(fileURLWithPath: expanded).standardized
        } else {
            targetURL = workingDirectory.appendingPathComponent(expanded).standardized
        }
        
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: targetURL.path, isDirectory: &isDir), isDir.boolValue {
            workingDirectory = targetURL
        } else {
            appendLine("cd: no such file or directory: \(path)", isError: true)
        }
    }
}
