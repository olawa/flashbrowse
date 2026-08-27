import Foundation
import SwiftUI
import Darwin

public struct VolumeStorageInfo: Identifiable, Equatable, Sendable {
    public var id: String { volumeName + "\(totalBytes)" }
    public let volumeName: String
    public let totalBytes: Int64
    public let availableBytes: Int64
    public let usedBytes: Int64
    public let usagePercentage: Double // 0.0 to 1.0 (e.g. 0.98 = 98% used)
    public let freePercentage: Double  // 0.0 to 1.0 (e.g. 0.02 = 2% free)
    
    private static let byteFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f
    }()
    
    public init(
        volumeName: String,
        totalBytes: Int64,
        availableBytes: Int64,
        usedBytes: Int64,
        usagePercentage: Double,
        freePercentage: Double
    ) {
        self.volumeName = volumeName
        self.totalBytes = totalBytes
        self.availableBytes = availableBytes
        self.usedBytes = usedBytes
        self.usagePercentage = usagePercentage
        self.freePercentage = freePercentage
    }
    
    public var formattedTotal: String {
        Self.byteFormatter.string(fromByteCount: totalBytes)
    }
    
    public var formattedAvailable: String {
        Self.byteFormatter.string(fromByteCount: availableBytes)
    }
    
    public var formattedUsed: String {
        Self.byteFormatter.string(fromByteCount: usedBytes)
    }
    
    public var usedPercentInteger: Int {
        Int(round(usagePercentage * 100))
    }
    
    public var freePercentInteger: Int {
        Int(round(freePercentage * 100))
    }
    
    public var isLowSpace: Bool {
        // Less than 15% free or less than 20 GB free
        return freePercentage < 0.15 || availableBytes < 20_000_000_000
    }
    
    public var isCriticalSpace: Bool {
        // Less than 5% free or less than 8 GB free
        return freePercentage < 0.05 || availableBytes < 8_000_000_000
    }
    
    public var statusSummary: String {
        "\(formattedAvailable) free of \(formattedTotal)"
    }
    
    public var detailedTooltip: String {
        """
        💾 Disk Storage (df -h)
        Volume: \(volumeName)
        Total: \(formattedTotal)
        Used: \(formattedUsed) (\(usedPercentInteger)%)
        Available: \(formattedAvailable) (\(freePercentInteger)%)
        """
    }
}
