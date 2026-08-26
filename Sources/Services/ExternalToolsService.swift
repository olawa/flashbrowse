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
        // Search common locations for rsnap
        let candidatePaths = [
            "/Users/olwal516/dev/bin/rsnap",
            "/usr/local/bin/rsnap",
            "/opt/homebrew/bin/rsnap",
            NSString(string: "~/.cargo/bin/rsnap").expandingTildeInPath,
            NSString(string: "~/bin/rsnap").expandingTildeInPath
        ]
        
        let fm = FileManager.default
        for path in candidatePaths {
            if fm.isExecutableFile(atPath: path) {
                self.hasRsnap = true
                self.rsnapPath = path
                break
            }
        }
        
        // Also check if rsnap is in PATH via `which`
        if !hasRsnap {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
            process.arguments = ["rsnap"]
            let pipe = Pipe()
            process.standardOutput = pipe
            try? process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !str.isEmpty {
                    self.hasRsnap = true
                    self.rsnapPath = str
                }
            }
        }
        
        // Check for IGV application
        self.hasIGV = fm.fileExists(atPath: "/Applications/IGV.app") || fm.fileExists(atPath: NSString(string: "~/Applications/IGV.app").expandingTildeInPath)
    }
    
    /// Launch rsnap interactive viewer with one or multiple files/directories
    public func openInRsnap(urls: [URL]) {
        guard let exe = rsnapPath else { return }
        
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
            try? process.run()
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
                    try? process.run()
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
