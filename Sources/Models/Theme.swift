import SwiftUI

// MARK: - Flashbrowse Centralized Theme
public extension Color {
    /// Ubuntu Orange #E95420 — Primary accent color
    static let flashbrowseAccent = Color(red: 0.91, green: 0.33, blue: 0.13)
    
    /// Midnight dark background #0d1117
    static let flashbrowseBgDark = Color(red: 0.05, green: 0.07, blue: 0.09)
    
    /// Card / elevated surface dark
    static let flashbrowseCardDark = Color(red: 0.12, green: 0.12, blue: 0.14)
    
    /// Terminal background
    static let flashbrowseTerminalBg = Color(red: 0.08, green: 0.08, blue: 0.08)
}

// MARK: - Shell Escaping Utility
public extension String {
    /// Shell-escapes a string for safe interpolation into shell commands.
    /// Wraps the string in single quotes and escapes any embedded single quotes.
    var shellEscaped: String {
        "'" + self.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

// MARK: - App Notification Names
public extension Notification.Name {
    static let flashbrowseSwitchWorkspace = Notification.Name("flashbrowseSwitchWorkspace")
    static let flashbrowseSaveWorkspace = Notification.Name("flashbrowseSaveWorkspace")
}
