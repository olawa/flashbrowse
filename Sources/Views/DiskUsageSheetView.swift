import SwiftUI

public struct DiskUsageSheetView: View {
    @ObservedObject var state: NavigationState
    @Environment(\.dismiss) private var dismiss
    
    @State private var report: DirectoryUsageReport?
    @State private var isLoading: Bool = true
    @State private var searchText: String = ""
    @State private var selectedFilter: UsageFilter = .all
    
    public enum UsageFilter: String, CaseIterable, Identifiable {
        case all = "All Items"
        case folders = "Folders Only"
        case files = "Files Only"
        
        public var id: String { rawValue }
    }
    
    public init(state: NavigationState) {
        self.state = state
    }
    
    private var filteredEntries: [FolderUsageEntry] {
        guard let report = report else { return [] }
        var list = report.entries
        
        switch selectedFilter {
        case .all:
            break
        case .folders:
            list = list.filter { $0.isDirectory }
        case .files:
            list = list.filter { !$0.isDirectory }
        }
        
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty {
            list = list.filter { $0.name.lowercased().contains(q) }
        }
        
        return list
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color.flashbrowseAccent)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Directory Disk Usage (du -h)")
                            .font(.system(size: 14, weight: .bold))
                        
                        Text(state.currentDirectory.path)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.8))
            
            Divider()
            
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.regular)
                    Text("Calculating recursive directory sizes with du -h...")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let rep = report {
                VStack(spacing: 0) {
                    // KPI Summary Cards
                    HStack(spacing: 10) {
                        kpiCard(title: "TOTAL SIZE", value: rep.formattedTotalSize, icon: "scalemass.fill", color: Color.flashbrowseAccent)
                        kpiCard(title: "ITEMS", value: "\(rep.entries.count) (\(rep.folderCount) dirs, \(rep.fileCount) files)", icon: "folder.fill", color: .blue)
                        if let vol = state.volumeStorage {
                            kpiCard(title: "FREE ON DISK", value: vol.formattedAvailable, icon: "internaldrive.fill", color: vol.isLowSpace ? .orange : .green)
                        }
                        kpiCard(title: "SCAN TIME", value: "\(String(format: "%.2f", rep.scanDuration))s", icon: "stopwatch.fill", color: .secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    
                    Divider()
                    
                    // Filter & Search Bar
                    HStack(spacing: 8) {
                        Picker("", selection: $selectedFilter) {
                            ForEach(UsageFilter.allCases) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 250)
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            
                            TextField("Filter results...", text: $searchText)
                                .textFieldStyle(.plain)
                                .font(.system(size: 11))
                                .frame(width: 140)
                            
                            if !searchText.isEmpty {
                                Button(action: { searchText = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(5)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                        )
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    
                    Divider()
                    
                    // Table Header
                    HStack(spacing: 8) {
                        Text("NAME")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text("SIZE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 80, alignment: .trailing)
                        
                        Text("PROPORTION")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 140, alignment: .leading)
                        
                        Text("ACTIONS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 60, alignment: .center)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
                    
                    Divider()
                    
                    // Table Rows
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(filteredEntries) { entry in
                                entryRow(entry: entry)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Text("No items found or failed to calculate disk usage.")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            Divider()
            
            // Footer Controls
            HStack {
                Button(action: {
                    if let rep = report {
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.setString(rep.cliFormattedText, forType: .string)
                        state.showToast("📋 Copied du -h summary to clipboard")
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10))
                        Text("Copy du -h Report")
                            .font(.system(size: 11))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button(action: {
                    loadUsage()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                        Text("Rescan")
                            .font(.system(size: 11))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 580, idealWidth: 640, minHeight: 460, idealHeight: 520)
        .onAppear {
            loadUsage()
        }
    }
    
    private func loadUsage() {
        isLoading = true
        Task {
            let res = await DiskUsageService.shared.analyzeDirectory(url: state.currentDirectory)
            await MainActor.run {
                self.report = res
                self.isLoading = false
                
                // Cache individual folder sizes in state
                for entry in res.entries where entry.isDirectory {
                    state.setFolderSizeCache(url: entry.url, size: entry.sizeBytes)
                }
            }
        }
    }
    
    @ViewBuilder
    private func kpiCard(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
        }
        .padding(7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.7))
        .cornerRadius(6)
    }
    
    @ViewBuilder
    private func entryRow(entry: FolderUsageEntry) -> some View {
        HStack(spacing: 8) {
            // Icon + Name
            HStack(spacing: 6) {
                Image(systemName: entry.iconName)
                    .font(.system(size: 12))
                    .foregroundColor(entry.isDirectory ? Color.flashbrowseAccent : .secondary)
                    .frame(width: 16)
                
                Text(entry.name)
                    .font(.system(size: 11.5, weight: entry.isDirectory ? .semibold : .regular))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Size
            Text(entry.formattedSize)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(entry.sizeBytes >= 50_000_000 ? Color.flashbrowseAccent : .primary)
                .frame(width: 80, alignment: .trailing)
            
            // Proportion Progress Bar
            HStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.15))
                            .frame(height: 6)
                        
                        Capsule()
                            .fill(
                                entry.sizeBytes >= 1_000_000_000
                                ? Color.flashbrowseAccent
                                : (entry.sizeBytes >= 100_000_000 ? Color.orange : Color.cyan)
                            )
                            .frame(width: max(2, geo.size.width * CGFloat(entry.proportion)), height: 6)
                    }
                }
                .frame(height: 6)
                
                Text(entry.percentString)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 44, alignment: .trailing)
            }
            .frame(width: 140)
            
            // Action Buttons
            HStack(spacing: 4) {
                if entry.isDirectory {
                    Button(action: {
                        dismiss()
                        state.navigateTo(url: entry.url)
                    }) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color.flashbrowseAccent)
                    }
                    .buttonStyle(.plain)
                    .help("Jump into this folder")
                } else {
                    Button(action: {
                        QuickLookBridge.shared.toggleQuickLook(for: entry.url)
                    }) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Quick Look preview")
                }
            }
            .frame(width: 60, alignment: .center)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .background(
            entry.isDirectory && entry.proportion >= 0.1
            ? Color.flashbrowseAccent.opacity(0.05)
            : Color.clear
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            if entry.isDirectory {
                dismiss()
                state.navigateTo(url: entry.url)
            } else {
                FileSystemService.shared.openItem(url: entry.url)
            }
        }
    }
}
