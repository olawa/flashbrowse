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
            
            // Intuitive Disk Storage with Progress Bar (df -h)
            if let storage = state.volumeStorage {
                HStack(spacing: 5) {
                    Image(systemName: "internaldrive.fill")
                        .font(.system(size: 10))
                        .foregroundColor(
                            storage.isCriticalSpace
                            ? .red
                            : (storage.isLowSpace ? .orange : Color.flashbrowseAccent)
                        )
                    
                    // Graphical Progress Bar Capsule
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(width: 46, height: 5.5)
                        
                        Capsule()
                            .fill(
                                storage.isCriticalSpace
                                ? Color.red
                                : (storage.isLowSpace ? Color.orange : Color.flashbrowseAccent)
                            )
                            .frame(width: max(2.5, 46 * CGFloat(storage.usagePercentage)), height: 5.5)
                    }
                    
                    Text("\(storage.formattedAvailable) free of \(storage.formattedTotal)")
                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                        .foregroundColor(
                            storage.isCriticalSpace
                            ? .red
                            : (storage.isLowSpace ? .orange : .secondary)
                        )
                    
                    Text("(\(storage.usedPercentInteger)%)")
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.75))
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    storage.isCriticalSpace
                    ? Color.red.opacity(0.12)
                    : (storage.isLowSpace ? Color.orange.opacity(0.1) : Color.clear)
                )
                .cornerRadius(4)
                .help(storage.detailedTooltip)
            } else if !state.volumeInfo.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "internaldrive")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text(state.volumeInfo)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            
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
