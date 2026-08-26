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
    
    // SSH Remote Terminal State
    @Published public var isSSHTerminalMode: Bool = false
    @Published public var sshHost: SSHHost?
    @Published public var remoteWorkingDir: String = "~"
    
    public var commandHistory: [String] = []
    public var historyIndex: Int = -1
    private var activeProcess: Process?
    private var previousLocalDir: URL?
    private var previousRemoteDir: String?
    
    // Callbacks for 2-Way Sync (Terminal -> Browser)
    public var onLocalDirectoryChange: ((URL) -> Void)?
    public var onRemoteDirectoryChange: ((String) -> Void)?
    
    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.workingDirectory = home
        appendLine("⚡ Flashbrowse Integrated Terminal (2-Way Synced)", isPrompt: true)
        appendLine("Commands like 'cd <path>' will move both terminal and browser in real time.", isPrompt: true)
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
    
    // MARK: - Browser -> Terminal Sync
    public func syncWorkingDirectory(_ url: URL) {
        guard autoSyncWithBrowser, !isSSHTerminalMode else { return }
        let target = url.standardized
        if target != workingDirectory {
            workingDirectory = target
            appendLine("📂 cd \(target.path)", isPrompt: true)
        }
    }
    
    public func syncRemoteDirectory(_ path: String) {
        guard autoSyncWithBrowser, isSSHTerminalMode else { return }
        if path != remoteWorkingDir {
            remoteWorkingDir = path
            appendLine("🌐 cd \(path)", isPrompt: true)
        }
    }
    
    // MARK: - SSH Mode Switchers
    public func startSSHSession(host: SSHHost, remotePath: String = "~") {
        self.isSSHTerminalMode = true
        self.sshHost = host
        self.remoteWorkingDir = remotePath
        self.isOpen = true
        
        appendLine("\n🌐 Connected SSH Terminal to \(host.alias) (\(host.connectionString))", isPrompt: true)
        appendLine("Remote path: \(remotePath)", isPrompt: true)
    }
    
    public func switchToLocalSession() {
        self.isSSHTerminalMode = false
        self.sshHost = nil
        appendLine("\n💻 Switched to Local Terminal: \(workingDirectory.path)", isPrompt: true)
    }
    
    public func clear() {
        outputLines.removeAll()
        if isSSHTerminalMode, let host = sshHost {
            appendLine("🌐 Flashbrowse SSH Terminal [\(host.alias)] - \(remoteWorkingDir)", isPrompt: true)
        } else {
            appendLine("⚡ Flashbrowse Terminal [Local] - \(workingDirectory.path)", isPrompt: true)
        }
    }
    
    public func cancelRunningCommand() {
        if let proc = activeProcess, proc.isRunning {
            proc.terminate()
            appendLine("^C (Command cancelled)", isError: true)
            isRunningCommand = false
            activeProcess = nil
        }
    }
    
    // MARK: - Command Execution with 2-Way Sync
    public func executeCommand(_ rawCommand: String) {
        let trimmed = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        commandHistory.append(trimmed)
        historyIndex = commandHistory.count
        
        if isSSHTerminalMode {
            executeRemoteCommand(trimmed)
        } else {
            executeLocalCommand(trimmed)
        }
    }
    
    // MARK: - Local Command Execution
    private func executeLocalCommand(_ trimmed: String) {
        let promptPath = workingDirectory.path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~")
        appendLine("➜ \(promptPath) $ \(trimmed)", isPrompt: true)
        
        if trimmed == "clear" {
            clear()
            return
        }
        
        // 2-Way CD: Move Terminal AND Move Browser!
        if trimmed == "cd" {
            let home = FileManager.default.homeDirectoryForCurrentUser
            previousLocalDir = workingDirectory
            workingDirectory = home
            onLocalDirectoryChange?(home)
            return
        }
        
        if trimmed == "cd -" {
            if let prev = previousLocalDir {
                previousLocalDir = workingDirectory
                workingDirectory = prev
                onLocalDirectoryChange?(prev)
                appendLine("📂 \(prev.path)", isPrompt: true)
            }
            return
        }
        
        if trimmed.hasPrefix("cd ") {
            let pathArg = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            handleLocalCD(path: pathArg)
            return
        }
        
        // Execute shell subprocess
        runSubprocess(
            executableURL: URL(fileURLWithPath: "/bin/zsh"),
            arguments: ["-l", "-c", "cd '\(workingDirectory.path)' && \(trimmed)"],
            environment: ProcessInfo.processInfo.environment
        )
    }
    
    private func handleLocalCD(path: String) {
        let expanded = NSString(string: path).expandingTildeInPath
        let targetURL: URL
        if expanded.hasPrefix("/") {
            targetURL = URL(fileURLWithPath: expanded).standardized
        } else {
            targetURL = workingDirectory.appendingPathComponent(expanded).standardized
        }
        
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: targetURL.path, isDirectory: &isDir), isDir.boolValue {
            previousLocalDir = workingDirectory
            workingDirectory = targetURL
            // 2-Way Sync: Update Browser!
            onLocalDirectoryChange?(targetURL)
        } else {
            appendLine("cd: no such file or directory: \(path)", isError: true)
        }
    }
    
    // MARK: - Remote SSH Command Execution
    private func executeRemoteCommand(_ trimmed: String) {
        guard let host = sshHost else {
            switchToLocalSession()
            return
        }
        
        appendLine("➜ \(host.alias):\(remoteWorkingDir) $ \(trimmed)", isPrompt: true)
        
        if trimmed == "clear" {
            clear()
            return
        }
        
        if trimmed == "exit" {
            switchToLocalSession()
            return
        }
        
        // 2-Way Remote CD: Move Terminal AND Move Remote Browser!
        if trimmed == "cd" || trimmed == "cd ~" {
            previousRemoteDir = remoteWorkingDir
            remoteWorkingDir = "~"
            onRemoteDirectoryChange?("~")
            return
        }
        
        if trimmed.hasPrefix("cd ") {
            let pathArg = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            handleRemoteCD(path: pathArg)
            return
        }
        
        // Run remote command over SSH
        let target = host.user.isEmpty ? host.hostName : "\(host.user)@\(host.hostName)"
        var sshArgs = ["-o", "BatchMode=yes", "-o", "ConnectTimeout=8"]
        if host.port != 22 { sshArgs.append(contentsOf: ["-p", "\(host.port)"]) }
        if let key = host.identityFile, !key.isEmpty { sshArgs.append(contentsOf: ["-i", NSString(string: key).expandingTildeInPath]) }
        sshArgs.append(target)
        sshArgs.append("cd \(remoteWorkingDir) && \(trimmed)")
        
        runSubprocess(
            executableURL: URL(fileURLWithPath: "/usr/bin/ssh"),
            arguments: sshArgs,
            environment: ProcessInfo.processInfo.environment
        )
    }
    
    private func handleRemoteCD(path: String) {
        let newPath: String
        if path.hasPrefix("/") || path.hasPrefix("~") {
            newPath = path
        } else if path == ".." {
            let parent = (remoteWorkingDir as NSString).deletingLastPathComponent
            newPath = parent.isEmpty ? "/" : parent
        } else {
            newPath = (remoteWorkingDir == "/" ? "/\(path)" : "\(remoteWorkingDir)/\(path)")
        }
        
        previousRemoteDir = remoteWorkingDir
        remoteWorkingDir = newPath
        // 2-Way Sync: Update Remote Browser!
        onRemoteDirectoryChange?(newPath)
    }
    
    // MARK: - Subprocess Streaming Helper
    private func runSubprocess(executableURL: URL, arguments: [String], environment: [String: String]) {
        isRunningCommand = true
        let process = Process()
        let pipe = Pipe()
        let errPipe = Pipe()
        
        process.executableURL = executableURL
        process.arguments = arguments
        var env = environment
        env["TERM"] = "xterm-256color"
        process.environment = env
        
        self.activeProcess = process
        
        let outHandle = pipe.fileHandleForReading
        let errHandle = errPipe.fileHandleForReading
        
        outHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            if let str = String(data: data, encoding: .utf8) {
                Task { @MainActor in
                    for line in str.components(separatedBy: "\n") where !line.isEmpty {
                        self?.appendLine(line)
                    }
                }
            }
        }
        
        errHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            if let str = String(data: data, encoding: .utf8) {
                Task { @MainActor in
                    for line in str.components(separatedBy: "\n") where !line.isEmpty {
                        self?.appendLine(line, isError: true)
                    }
                }
            }
        }
        
        process.terminationHandler = { [weak self] _ in
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
            appendLine("Execution error: \(error.localizedDescription)", isError: true)
            isRunningCommand = false
            activeProcess = nil
        }
    }
}
