import SwiftUI

public struct StatusBarView: View {
    @ObservedObject var state: NavigationState
    
    public init(state: NavigationState) {
        self.state = state
    }
    
    public var body: some View {
        HStack(spacing: 10) {
            // Toast notification banner or Item count
            if let toast = state.toastMessage {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color.flashbrowseAccent)
                        .font(.system(size: 11))
                    Text(toast)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color.flashbrowseAccent)
                }
                .transition(.opacity)
            } else {
                if state.selectedURLs.isEmpty {
                    Text("\(state.filteredItems.count) items")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                } else {
                    Text("\(state.selectedURLs.count) of \(state.filteredItems.count) selected")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
            
            if !state.searchQuery.isEmpty {
                Text("• Filtered by \"\(state.searchQuery)\"")
                    .font(.system(size: 11))
                    .italic()
                    .foregroundColor(.secondary)
            }
            
            // Git Status
            if let git = state.gitStatus {
                HStack(spacing: 4) {
                    Text("•")
                        .foregroundColor(.secondary.opacity(0.5))
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 10))
                        .foregroundColor(git.contains("modified") ? .orange : .green)
                    Text(git)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Refresh Button
            Button(action: {
                state.reload()
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Refresh (Cmd+R)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(nsColor: .separatorColor)),
            alignment: .top
        )
    }
}
