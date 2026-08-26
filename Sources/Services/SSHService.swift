import Foundation
import Combine

@MainActor
public class SSHService: ObservableObject {
    public static let shared = SSHService()
    
    @Published public var savedHosts: [SSHHost] = []
    @Published public var activeHost: SSHHost?
    @Published public var currentRemotePath: String = "~"
    @Published public var remoteItems: [RemoteFileItem] = []
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    @Published public var isRemoteBrowserOpen: Bool = false
    
    private var pathHistory: [String] = []
    private var forwardPathHistory: [String] = []
    
    private init() {
        loadHosts()
    }
    
    // MARK: - SSH Config Parsing & Persistence
    public func loadHosts() {
        var hostsMap: [String: SSHHost] = [:]
        
        // 1. Parse ~/.ssh/config if available
        let sshConfigURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ssh/config")
        if let content = try? String(contentsOf: sshConfigURL, encoding: .utf8) {
            let parsed = parseSSHConfig(content)
            for h in parsed {
                hostsMap[h.alias] = h
            }
        }
        
        // 2. Load custom user hosts from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "flashbrowse_custom_ssh_hosts"),
           let userHosts = try? JSONDecoder().decode([SSHHost].self, from: data) {
            for h in userHosts {
                hostsMap[h.alias] = h
            }
        }
        
        self.savedHosts = Array(hostsMap.values).sorted { $0.alias.localizedStandardCompare($1.alias) == .orderedAscending }
    }
    
    public func saveCustomHost(_ host: SSHHost) {
        if let idx = savedHosts.firstIndex(where: { $0.alias == host.alias }) {
            savedHosts[idx] = host
        } else {
            savedHosts.append(host)
        }
        
        if let data = try? JSONEncoder().encode(savedHosts) {
            UserDefaults.standard.set(data, forKey: "flashbrowse_custom_ssh_hosts")
        }
    }
    
    public func removeHost(alias: String) {
        savedHosts.removeAll(where: { $0.alias == alias })
        if let data = try? JSONEncoder().encode(savedHosts) {
            UserDefaults.standard.set(data, forKey: "flashbrowse_custom_ssh_hosts")
        }
    }
    
    private func parseSSHConfig(_ content: String) -> [SSHHost] {
        var results: [SSHHost] = []
        var curAlias = ""
        var curHostName = ""
        var curUser = ""
        var curPort = 22
        var curKey: String? = nil
        
        let lines = content.components(separatedBy: "\n")
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            
            let parts = line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true).map(String.init)
            guard parts.count == 2 else { continue }
            let key = parts[0].lowercased()
            let val = parts[1].trimmingCharacters(in: .whitespaces)
            
            if key == "host" {
                if !curAlias.isEmpty && !curAlias.contains("*") {
                    let host = SSHHost(
                        alias: curAlias,
                        hostName: curHostName.isEmpty ? curAlias : curHostName,
                        user: curUser,
                        port: curPort,
                        identityFile: curKey
                    )
                    results.append(host)
                }
                curAlias = val
                curHostName = ""
                curUser = ""
                curPort = 22
                curKey = nil
            } else if key == "hostname" {
                curHostName = val
            } else if key == "user" {
                curUser = val
            } else if key == "port", let p = Int(val) {
                curPort = p
            } else if key == "identityfile" {
                curKey = val
            }
        }
        
        if !curAlias.isEmpty && !curAlias.contains("*") {
            let host = SSHHost(
                alias: curAlias,
                hostName: curHostName.isEmpty ? curAlias : curHostName,
                user: curUser,
                port: curPort,
                identityFile: curKey
            )
            results.append(host)
        }
        
        return results
    }
    
    // MARK: - Connect & Navigation
    public func connect(to host: SSHHost, initialPath: String? = nil) {
        self.activeHost = host
        self.currentRemotePath = initialPath ?? host.initialDirectory
        self.isRemoteBrowserOpen = true
        self.errorMessage = nil
        self.pathHistory.removeAll()
        self.forwardPathHistory.removeAll()
        
        Task {
            await listRemoteDirectory(path: self.currentRemotePath)
        }
    }
    
    public func disconnect() {
        self.activeHost = nil
        self.isRemoteBrowserOpen = false
        self.remoteItems.removeAll()
        self.errorMessage = nil
    }
    
    public func navigateToRemote(path: String, addToHistory: Bool = true) {
        if addToHistory {
            pathHistory.append(currentRemotePath)
            forwardPathHistory.removeAll()
        }
        self.currentRemotePath = path
        Task {
            await listRemoteDirectory(path: path)
        }
    }
    
    public func goBack() {
        guard let prev = pathHistory.popLast() else { return }
        forwardPathHistory.append(currentRemotePath)
        self.currentRemotePath = prev
        Task {
            await listRemoteDirectory(path: prev)
        }
    }
    
    public func goForward() {
        guard let next = forwardPathHistory.popLast() else { return }
        pathHistory.append(currentRemotePath)
        self.currentRemotePath = next
        Task {
            await listRemoteDirectory(path: next)
        }
    }
    
    public func goUp() {
        if currentRemotePath == "/" || currentRemotePath == "~" { return }
        let parent = (currentRemotePath as NSString).deletingLastPathComponent
        navigateToRemote(path: parent.isEmpty ? "/" : parent)
    }
    
    // MARK: - Remote Directory Listing
    public func listRemoteDirectory(path: String) async {
        guard let host = activeHost else { return }
        self.isLoading = true
        self.errorMessage = nil
        
        let script = "cd \(path) && pwd && ls -la"
        do {
            let output = try await runSSHCommand(host: host, command: script)
            parseRemoteLsOutput(output: output, basePath: path)
            self.isLoading = false
        } catch {
            self.isLoading = false
            self.errorMessage = "Failed to connect to \(host.alias): \(error.localizedDescription)"
        }
    }
    
    private func parseRemoteLsOutput(output: String, basePath: String) {
        let lines = output.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard lines.count >= 1 else { return }
        
        // First line contains resolved absolute path if pwd succeeded
        var resolvedPath = basePath
        var itemLines = lines
        if let first = lines.first, first.hasPrefix("/") {
            resolvedPath = first
            self.currentRemotePath = resolvedPath
            itemLines = Array(lines.dropFirst())
        }
        
        var parsedItems: [RemoteFileItem] = []
        
        for line in itemLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("total ") || trimmed.isEmpty { continue }
            
            // Typical ls -la output format: drwxr-xr-x 5 user group 4096 Aug 25 14:02 folderName
            let cols = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard cols.count >= 8 else { continue }
            
            let permissions = cols[0]
            let isDir = permissions.hasPrefix("d")
            let size = Int64(cols[4]) ?? 0
            
            // Date is usually cols 5, 6, 7 (e.g. Aug 25 14:02 or 2026-08-25 14:02)
            let dateStr = "\(cols[5]) \(cols[6]) \(cols[7])"
            
            // Name is remaining columns joined by space
            let name = cols.dropFirst(8).joined(separator: " ")
            if name == "." || name == ".." { continue }
            
            let fullRemotePath = (resolvedPath == "/" ? "/\(name)" : "\(resolvedPath)/\(name)")
            
            let item = RemoteFileItem(
                name: name,
                remotePath: fullRemotePath,
                isDirectory: isDir,
                sizeBytes: size,
                permissions: permissions,
                modifiedString: dateStr
            )
            parsedItems.append(item)
        }
        
        // Sort: folders first, then natural compare
        self.remoteItems = parsedItems.sorted { a, b in
            if a.isDirectory != b.isDirectory {
                return a.isDirectory && !b.isDirectory
            }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
    }
    
    // MARK: - SSH Execution & File Transfer
    public func runSSHCommand(host: SSHHost, command: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let pipe = Pipe()
            let errPipe = Pipe()
            
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
            
            var args = [
                "-o", "BatchMode=yes",
                "-o", "ConnectTimeout=8",
                "-o", "StrictHostKeyChecking=accept-new"
            ]
            args.append(contentsOf: host.sshCommandArgs)
            args.append(command)
            
            process.arguments = args
            process.standardOutput = pipe
            process.standardError = errPipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                if process.terminationStatus == 0 {
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let str = String(data: data, encoding: .utf8) ?? ""
                    continuation.resume(returning: str)
                } else {
                    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                    let errStr = String(data: errData, encoding: .utf8) ?? "Exit code \(process.terminationStatus)"
                    continuation.resume(throwing: NSError(domain: "SSHService", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: errStr]))
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    // MARK: - Download Remote File to Local Cache for Live Preview
    public func downloadToCache(item: RemoteFileItem) async throws -> URL {
        guard let host = activeHost else {
            throw NSError(domain: "SSHService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No active host"])
        }
        
        let cacheDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("flashbrowse_ssh_cache")
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        
        let safeName = item.name.replacingOccurrences(of: "/", with: "_")
        let localTarget = cacheDir.appendingPathComponent("\(host.alias)_\(safeName)")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/scp")
        
        var args = [
            "-o", "BatchMode=yes",
            "-o", "ConnectTimeout=8"
        ]
        if host.port != 22 {
            args.append(contentsOf: ["-P", "\(host.port)"])
        }
        if let key = host.identityFile, !key.isEmpty {
            args.append(contentsOf: ["-i", NSString(string: key).expandingTildeInPath])
        }
        
        let remoteSource = host.user.isEmpty ? "\(host.hostName):\(item.remotePath)" : "\(host.user)@\(host.hostName):\(item.remotePath)"
        args.append(remoteSource)
        args.append(localTarget.path)
        
        process.arguments = args
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus == 0 {
            return localTarget
        } else {
            throw NSError(domain: "SSHService", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "Failed to download preview"])
        }
    }
    
    // MARK: - Download File to Local Folder
    public func downloadFile(item: RemoteFileItem, to destinationFolder: URL) async throws {
        guard let host = activeHost else { return }
        
        let localTarget = destinationFolder.appendingPathComponent(item.name)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/scp")
        
        var args = ["-r", "-o", "BatchMode=yes", "-o", "ConnectTimeout=10"]
        if host.port != 22 {
            args.append(contentsOf: ["-P", "\(host.port)"])
        }
        if let key = host.identityFile, !key.isEmpty {
            args.append(contentsOf: ["-i", NSString(string: key).expandingTildeInPath])
        }
        
        let remoteSource = host.user.isEmpty ? "\(host.hostName):\(item.remotePath)" : "\(host.user)@\(host.hostName):\(item.remotePath)"
        args.append(remoteSource)
        args.append(localTarget.path)
        
        process.arguments = args
        try process.run()
        process.waitUntilExit()
    }
}
