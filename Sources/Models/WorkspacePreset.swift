import Foundation
import SwiftUI

public struct WorkspacePreset: Identifiable, Codable, Hashable {
    public var id: Int // 1..9
    public var name: String
    public var leftPath: String
    public var rightPath: String
    public var isDualPane: Bool
    public var isCommanderMode: Bool
    public var isTerminalOpen: Bool
    public var isInspectorOpen: Bool
    
    public init(
        id: Int,
        name: String,
        leftPath: String,
        rightPath: String = "",
        isDualPane: Bool = false,
        isCommanderMode: Bool = false,
        isTerminalOpen: Bool = false,
        isInspectorOpen: Bool = false
    ) {
        self.id = id
        self.name = name
        self.leftPath = leftPath
        self.rightPath = rightPath.isEmpty ? leftPath : rightPath
        self.isDualPane = isDualPane
        self.isCommanderMode = isCommanderMode
        self.isTerminalOpen = isTerminalOpen
        self.isInspectorOpen = isInspectorOpen
    }
    
    public static func defaultPresets() -> [WorkspacePreset] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let devDir = (FileManager.default.fileExists(atPath: "\(home)/dev")) ? "\(home)/dev" : home
        
        return [
            WorkspacePreset(
                id: 1,
                name: "Standard Browser",
                leftPath: home,
                isDualPane: false,
                isCommanderMode: false,
                isTerminalOpen: false,
                isInspectorOpen: false
            ),
            WorkspacePreset(
                id: 2,
                name: "Dual-Screen Studio",
                leftPath: devDir,
                isDualPane: false,
                isCommanderMode: false,
                isTerminalOpen: false,
                isInspectorOpen: true
            ),
            WorkspacePreset(
                id: 3,
                name: "Developer / Terminal",
                leftPath: devDir,
                isDualPane: false,
                isCommanderMode: false,
                isTerminalOpen: true,
                isInspectorOpen: false
            ),
            WorkspacePreset(
                id: 4,
                name: "Classic Commander",
                leftPath: home,
                rightPath: devDir,
                isDualPane: true,
                isCommanderMode: true,
                isTerminalOpen: false,
                isInspectorOpen: false
            )
        ]
    }
}
