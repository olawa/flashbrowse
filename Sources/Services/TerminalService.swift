import Foundation
import Combine

public struct TerminalOutputLine: Identifiable, Hashable {
    private static var nextId: Int = 0
    private static func makeId() -> Int {
        nextId += 1
        return nextId
    }
    
    public let id: Int
    public let text: String
    public let isError: Bool
    public let isPrompt: Bool
    
    public init(text: String, isError: Bool = false, isPrompt: Bool = false) {
        self.id = Self.makeId()
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
    
    // Dual Terminal Split Support (Left Terminal | Right Terminal)
    @Published public var isDualTerminalSplit: Bool = false
    @Published public var rightWorkingDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    @Published public var rightOutputLines: [TerminalOutputLine] = []
    @Published public var isRightRunningCommand: Bool = false
    
    // SSH Remote Terminal State
    @Published public var isSSHTerminalMode: Bool = false
    @Published public var sshHost: SSHHost?
    @Published public var remoteWorkingDir: String = "~"
    
    // Focus Trigger
    @Published public var focusInputTrigger: UUID = UUID()
    
    public var commandHistory: [String] = []
    public var historyIndex: Int = -1
    public var rightCommandHistory: [String] = []
    public var rightHistoryIndex: Int = -1
    
    private var activeProcess: Process?
    private var activeRightProcess: Process?
    private var previousLocalDir: URL?
    private var previousRemoteDir: String?
    
    // Callbacks for 2-Way Sync (Terminal -> Browser)
    public var onLocalDirectoryChange: ((URL) -> Void)?
    public var onRightLocalDirectoryChange: ((URL) -> Void)?
    public var onRemoteDirectoryChange: ((String) -> Void)?
    
    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.workingDirectory = home
        self.rightWorkingDirectory = home
        appendLine("⚡ Flashbrowse Integrated Terminal (2-Way Synced)", isPrompt: true)
        appendLine("Commands like 'cd <path>' will move both terminal and browser in real time.", isPrompt: true)
        appendLine("----------------------------------------------------------------", isPrompt: true)
        
        appendRightLine("🌐 Remote / Secondary Terminal", isPrompt: true)
    }
    
    public func appendLine(_ text: String, isError: Bool = false, isPrompt: Bool = false) {
        outputLines.append(TerminalOutputLine(text: text, isError: isError, isPrompt: isPrompt))
        if outputLines.count > 1500 {
            outputLines.removeFirst(outputLines.count - 1500)
        }
    }
    
    public func appendRightLine(_ text: String, isError: Bool = false, isPrompt: Bool = false) {
        rightOutputLines.append(TerminalOutputLine(text: text, isError: isError, isPrompt: isPrompt))
        if rightOutputLines.count > 1500 {
            rightOutputLines.removeFirst(rightOutputLines.count - 1500)
        }
    }
    
    public func focusTerminal() {
        if !isOpen {
            isOpen = true
        }
        focusInputTrigger = UUID()
    }
    
    public func toggleTerminal() {
        if !isOpen {
            isOpen = true
            focusInputTrigger = UUID()
        } else {
            isOpen = false
        }
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
    
    public func syncRightWorkingDirectory(_ url: URL) {
        guard autoSyncWithBrowser else { return }
        let target = url.standardized
        if target != rightWorkingDirectory {
            rightWorkingDirectory = target
            appendRightLine("📂 cd \(target.path)", isPrompt: true)
        }
    }
    
    public func syncRemoteDirectory(_ path: String) {
        guard autoSyncWithBrowser, isSSHTerminalMode else { return }
        if path != remoteWorkingDir {
            remoteWorkingDir = path
            if isDualTerminalSplit {
                appendRightLine("🌐 cd \(path)", isPrompt: true)
            } else {
                appendLine("🌐 cd \(path)", isPrompt: true)
            }
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
        focusInputTrigger = UUID()
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
    
    public func clearRight() {
        rightOutputLines.removeAll()
        appendRightLine("⚡ Flashbrowse Terminal [Right] - \(rightWorkingDirectory.path)", isPrompt: true)
    }
    
    public func cancelRunningCommand() {
        if let proc = activeProcess, proc.isRunning {
            proc.terminate()
            appendLine("^C (Command cancelled)", isError: true)
            isRunningCommand = false
            activeProcess = nil
        }
    }
    
    public func cancelRightRunningCommand() {
        if let proc = activeRightProcess, proc.isRunning {
            proc.terminate()
            appendRightLine("^C (Command cancelled)", isError: true)
            isRightRunningCommand = false
            activeRightProcess = nil
        }
    }
    
    // MARK: - Command Execution (Left / Primary)
    public func executeCommand(_ rawCommand: String) {
        let trimmed = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        commandHistory.append(trimmed)
        historyIndex = commandHistory.count
        
        if isSSHTerminalMode && !isDualTerminalSplit {
            executeRemoteCommand(trimmed)
        } else {
            executeLocalCommand(trimmed)
        }
    }
    
    // MARK: - Command Execution (Right / Secondary in Dual-Split)
    public func executeRightCommand(_ rawCommand: String) {
        let trimmed = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        rightCommandHistory.append(trimmed)
        rightHistoryIndex = rightCommandHistory.count
        
        if isSSHTerminalMode {
            executeRemoteRightCommand(trimmed)
        } else {
            executeLocalRightCommand(trimmed)
        }
    }
    
    private func executeLocalCommand(_ trimmed: String) {
        let promptPath = workingDirectory.path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~")
        appendLine("➜ \(promptPath) $ \(trimmed)", isPrompt: true)
        
        if trimmed == "clear" {
            clear()
            return
        }
        
        if trimmed == "pwd" {
            appendLine(workingDirectory.path)
            return
        }
        
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
        
        runSubprocess(
            executableURL: URL(fileURLWithPath: "/bin/zsh"),
            arguments: ["-c", "cd \(workingDirectory.path.shellEscaped) && \(trimmed)"],
            environment: ProcessInfo.processInfo.environment,
            isRight: false
        )
    }
    
    private func executeLocalRightCommand(_ trimmed: String) {
        let promptPath = rightWorkingDirectory.path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~")
        appendRightLine("➜ \(promptPath) $ \(trimmed)", isPrompt: true)
        
        if trimmed == "clear" {
            clearRight()
            return
        }
        
        if trimmed == "pwd" {
            appendRightLine(rightWorkingDirectory.path)
            return
        }
        
        if trimmed.hasPrefix("cd ") {
            let pathArg = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            let expanded = NSString(string: pathArg).expandingTildeInPath
            let targetURL = expanded.hasPrefix("/") ? URL(fileURLWithPath: expanded).standardized : rightWorkingDirectory.appendingPathComponent(expanded).standardized
            
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: targetURL.path, isDirectory: &isDir), isDir.boolValue {
                rightWorkingDirectory = targetURL
                onRightLocalDirectoryChange?(targetURL)
            } else {
                appendRightLine("cd: no such file or directory: \(pathArg)", isError: true)
            }
            return
        }
        
        runSubprocess(
            executableURL: URL(fileURLWithPath: "/bin/zsh"),
            arguments: ["-c", "cd \(rightWorkingDirectory.path.shellEscaped) && \(trimmed)"],
            environment: ProcessInfo.processInfo.environment,
            isRight: true
        )
    }
    
    private func handleLocalCD(path: String) {
        var cleanPath = path
        let user = NSUserName()
        let homePath = FileManager.default.homeDirectoryForCurrentUser.path
        if cleanPath.hasPrefix("/home/\(user)") {
            cleanPath = cleanPath.replacingOccurrences(of: "/home/\(user)", with: homePath)
        } else if cleanPath.hasPrefix("/home/users/\(user)") {
            cleanPath = cleanPath.replacingOccurrences(of: "/home/users/\(user)", with: homePath)
        }
        
        let expanded = NSString(string: cleanPath).expandingTildeInPath
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
            onLocalDirectoryChange?(targetURL)
        } else {
            appendLine("cd: no such file or directory: \(path)", isError: true)
        }
    }
    
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
        
        let target = host.user.isEmpty ? host.hostName : "\(host.user)@\(host.hostName)"
        var sshArgs = ["-o", "BatchMode=yes", "-o", "ConnectTimeout=8"]
        if host.port != 22 { sshArgs.append(contentsOf: ["-p", "\(host.port)"]) }
        if let key = host.identityFile, !key.isEmpty { sshArgs.append(contentsOf: ["-i", NSString(string: key).expandingTildeInPath]) }
        sshArgs.append(target)
        let remotePathArg = SSHService.escapeRemoteShellPath(remoteWorkingDir)
        sshArgs.append("cd \(remotePathArg) && \(trimmed)")
        
        runSubprocess(
            executableURL: URL(fileURLWithPath: "/usr/bin/ssh"),
            arguments: sshArgs,
            environment: ProcessInfo.processInfo.environment,
            isRight: false
        )
    }
    
    private func executeRemoteRightCommand(_ trimmed: String) {
        guard let host = sshHost else { return }
        
        appendRightLine("➜ \(host.alias):\(remoteWorkingDir) $ \(trimmed)", isPrompt: true)
        
        if trimmed == "clear" {
            clearRight()
            return
        }
        
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
        
        let target = host.user.isEmpty ? host.hostName : "\(host.user)@\(host.hostName)"
        var sshArgs = ["-o", "BatchMode=yes", "-o", "ConnectTimeout=8"]
        if host.port != 22 { sshArgs.append(contentsOf: ["-p", "\(host.port)"]) }
        if let key = host.identityFile, !key.isEmpty { sshArgs.append(contentsOf: ["-i", NSString(string: key).expandingTildeInPath]) }
        sshArgs.append(target)
        let remotePathArg = SSHService.escapeRemoteShellPath(remoteWorkingDir)
        sshArgs.append("cd \(remotePathArg) && \(trimmed)")
        
        runSubprocess(
            executableURL: URL(fileURLWithPath: "/usr/bin/ssh"),
            arguments: sshArgs,
            environment: ProcessInfo.processInfo.environment,
            isRight: true
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
        onRemoteDirectoryChange?(newPath)
    }
    
    // MARK: - Subprocess Execution
    private func runSubprocess(executableURL: URL, arguments: [String], environment: [String: String], isRight: Bool) {
        if isRight {
            isRightRunningCommand = true
        } else {
            isRunningCommand = true
        }
        
        Task.detached(priority: .userInitiated) {
            let process = Process()
            let outPipe = Pipe()
            let errPipe = Pipe()
            
            process.executableURL = executableURL
            process.arguments = arguments
            var env = environment
            env["TERM"] = "xterm-256color"
            process.environment = env
            process.standardOutput = outPipe
            process.standardError = errPipe
            
            await MainActor.run {
                if isRight {
                    self.activeRightProcess = process
                } else {
                    self.activeProcess = process
                }
            }
            
            do {
                try process.run()
                
                let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                
                let outStr = String(data: outData, encoding: .utf8) ?? ""
                let errStr = String(data: errData, encoding: .utf8) ?? ""
                
                await MainActor.run {
                    if isRight {
                        if !outStr.isEmpty {
                            for line in outStr.components(separatedBy: "\n") where !line.isEmpty {
                                self.appendRightLine(line)
                            }
                        }
                        if !errStr.isEmpty {
                            for line in errStr.components(separatedBy: "\n") where !line.isEmpty {
                                self.appendRightLine(line, isError: true)
                            }
                        }
                        self.isRightRunningCommand = false
                        self.activeRightProcess = nil
                    } else {
                        if !outStr.isEmpty {
                            for line in outStr.components(separatedBy: "\n") where !line.isEmpty {
                                self.appendLine(line)
                            }
                        }
                        if !errStr.isEmpty {
                            for line in errStr.components(separatedBy: "\n") where !line.isEmpty {
                                self.appendLine(line, isError: true)
                            }
                        }
                        self.isRunningCommand = false
                        self.activeProcess = nil
                    }
                }
            } catch {
                await MainActor.run {
                    if isRight {
                        self.appendRightLine("Execution error: \(error.localizedDescription)", isError: true)
                        self.isRightRunningCommand = false
                        self.activeRightProcess = nil
                    } else {
                        self.appendLine("Execution error: \(error.localizedDescription)", isError: true)
                        self.isRunningCommand = false
                        self.activeProcess = nil
                    }
                }
            }
        }
    }
}
