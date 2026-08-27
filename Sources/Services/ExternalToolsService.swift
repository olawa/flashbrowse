import Foundation
import AppKit

@MainActor
public class ExternalToolsService: ObservableObject {
    public static let shared = ExternalToolsService()
    
    @Published public var hasRsnap: Bool = false
    @Published public var rsnapPath: String?
    
    @Published public var hasIGV: Bool = false
    
    private init() {
        checkInstalledTools()
    }
    
    public func checkInstalledTools() {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        
        var candidateDirs = [
            "\(home)/dev/bin",
            "\(home)/.cargo/bin",
            "\(home)/bin",
            "\(home)/.local/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin"
        ]
        
        // Scan environment PATH as well
        if let pathEnv = ProcessInfo.processInfo.environment["PATH"] {
            let envDirs = pathEnv.split(separator: ":").map(String.init)
            for dir in envDirs where !candidateDirs.contains(dir) {
                candidateDirs.append(dir)
            }
        }
        
        var foundRsnap: String? = nil
        for dir in candidateDirs {
            let fullPath = (dir as NSString).expandingTildeInPath + "/rsnap"
            if fm.isExecutableFile(atPath: fullPath) {
                foundRsnap = fullPath
                break
            }
        }
        
        self.hasRsnap = (foundRsnap != nil)
        self.rsnapPath = foundRsnap
        
        // Check for IGV application
        self.hasIGV = fm.fileExists(atPath: "/Applications/IGV.app")
            || fm.fileExists(atPath: "\(home)/Applications/IGV.app")
            || fm.fileExists(atPath: "\(home)/Desktop/IGV.app")
    }
    
    /// Launch rsnap interactive viewer with one or multiple files/directories
    public func openInRsnap(urls: [URL]) {
        guard let exe = rsnapPath, FileManager.default.isExecutableFile(atPath: exe) else { return }
        
        // Filter bam, cram, sam, vcf, bed files
        var args: [String] = ["--viewer"]
        for url in urls {
            let ext = url.pathExtension.lowercased()
            if ["bam", "cram", "sam"].contains(ext) {
                args.append(contentsOf: ["-b", url.path])
            } else if ["vcf", "bcf", "gz"].contains(ext) {
                args.append(contentsOf: ["-v", url.path])
            } else if ["bed", "bw", "bigwig", "bedgraph"].contains(ext) {
                args.append(contentsOf: ["--peak-track", url.path])
            } else {
                // If it's a directory or generic file, pass via -b
                args.append(contentsOf: ["-b", url.path])
            }
        }
        
        Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: exe)
            process.arguments = args
            do {
                try process.run()
            } catch {
                // Handle/ignore process execution error safely without crashing
            }
        }
    }
    
    /// Launch or send track to IGV
    public func openInIGV(urls: [URL]) {
        let paths = urls.map { $0.path }.joined(separator: ",")
        
        // 1. Try sending via IGV HTTP Port 60151 first if IGV is running
        if let portURL = URL(string: "http://127.0.0.1:60151/load?file=\(paths.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? paths)") {
            var request = URLRequest(url: portURL)
            request.timeoutInterval = 1.0
            URLSession.shared.dataTask(with: request) { _, response, _ in
                if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 {
                    return
                }
                // Fallback: Launch IGV via open -a IGV
                DispatchQueue.main.async {
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                    process.arguments = ["-a", "IGV", "--args"] + urls.map { $0.path }
                    do {
                        try process.run()
                    } catch {
                        // Handle/ignore process execution error safely without crashing
                    }
                }
            }.resume()
        }
    }
    
    /// Check if a file is supported by genomics viewers
    public static func isGenomicsFile(url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        let name = url.lastPathComponent.lowercased()
        return ["bam", "cram", "sam", "vcf", "bcf", "bed", "bw", "bigwig", "bedgraph", "gff", "gtf"].contains(ext)
            || name.hasSuffix(".vcf.gz")
            || name.hasSuffix(".bam")
            || name.hasSuffix(".cram")
    }
}
