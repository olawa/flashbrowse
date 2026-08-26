import Foundation

public struct SSHHost: Identifiable, Codable, Hashable, Sendable {
    public var id: String { alias }
    public let alias: String
    public let hostName: String
    public let user: String
    public let port: Int
    public let identityFile: String?
    public let initialDirectory: String
    
    public init(
        alias: String,
        hostName: String,
        user: String = "",
        port: Int = 22,
        identityFile: String? = nil,
        initialDirectory: String = "~"
    ) {
        self.alias = alias
        self.hostName = hostName
        self.user = user
        self.port = port
        self.identityFile = identityFile
        self.initialDirectory = initialDirectory
    }
    
    public var connectionString: String {
        if !user.isEmpty {
            return "\(user)@\(hostName)\(port != 22 ? ":\(port)" : "")"
        }
        return "\(hostName)\(port != 22 ? ":\(port)" : "")"
    }
    
    public var sshCommandArgs: [String] {
        var args: [String] = []
        if port != 22 {
            args.append(contentsOf: ["-p", "\(port)"])
        }
        if let key = identityFile, !key.isEmpty {
            args.append(contentsOf: ["-i", NSString(string: key).expandingTildeInPath])
        }
        let target = user.isEmpty ? hostName : "\(user)@\(hostName)"
        args.append(target)
        return args
    }
}

public struct RemoteFileItem: Identifiable, Hashable, Sendable {
    public var id: String { remotePath }
    public let name: String
    public let remotePath: String
    public let isDirectory: Bool
    public let sizeBytes: Int64
    public let permissions: String
    public let modifiedString: String
    
    public init(
        name: String,
        remotePath: String,
        isDirectory: Bool,
        sizeBytes: Int64 = 0,
        permissions: String = "",
        modifiedString: String = ""
    ) {
        self.name = name
        self.remotePath = remotePath
        self.isDirectory = isDirectory
        self.sizeBytes = sizeBytes
        self.permissions = permissions
        self.modifiedString = modifiedString
    }
    
    private static let byteFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f
    }()
    
    public var formattedSize: String {
        if isDirectory {
            return "--"
        }
        return Self.byteFormatter.string(fromByteCount: sizeBytes)
    }
    
    public var sfSymbolName: String {
        if isDirectory { return "folder.fill" }
        let ext = (remotePath as NSString).pathExtension.lowercased()
        switch ext {
        case "bam", "sam", "cram": return "dna"
        case "vcf", "bcf": return "waveform.path.ecg"
        case "fq", "fastq", "gz": return "text.alignleft"
        case "gtf", "gff", "bed": return "bookmark.circle.fill"
        case "tsv", "csv", "tab": return "tablecells"
        case "swift", "rs", "py", "c", "cpp", "h", "sh", "ts", "js": return "curlybraces"
        case "md", "txt", "pdf": return "doc.text.fill"
        case "png", "jpg", "jpeg", "svg", "gif": return "photo"
        case "zip", "tar", "bz2", "xz": return "doc.zipper"
        default: return "doc.fill"
        }
    }
}
