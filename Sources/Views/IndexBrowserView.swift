import SwiftUI

public struct IndexBrowserView: View {
    @ObservedObject var indexService = IndexService.shared
    @ObservedObject var navState: NavigationState
    @State private var hoveredURL: URL?
    @State private var showingBatchRename: Bool = false
    
    public init(navState: NavigationState) {
        self.navState = navState
    }
    
    private var selectedGroup: DirectoryIndexGroup? {
        guard let selected = indexService.selectedDirectory else { return indexService.indexedGroups.first }
        return indexService.indexedGroups.first(where: { $0.directoryURL == selected })
    }
    
    private var filteredItemsInSelectedGroup: [FileItem] {
        guard let group = selectedGroup else { return [] }
        let query = indexService.searchQuery.trimmingCharacters(in: .whitespaces).lowercased()
        if query.isEmpty {
            return group.items
        }
        return group.items.filter { $0.lowercaseName.contains(query) }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Index Header Bar
            HStack(spacing: 10) {
                if let index = indexService.activeIndex {
                    HStack(spacing: 6) {
                        Image(systemName: index.icon)
                            .foregroundColor(index.color)
                            .font(.system(size: 14))
                        
                        Text(index.name)
                            .font(.system(size: 13, weight: .bold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(index.color.opacity(0.12))
                    .cornerRadius(6)
                    
                    Text("• \(indexService.totalFilesFound) files in \(indexService.indexedGroups.count) folders")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    if indexService.isScanning {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 16, height: 16)
                    }
                }
                
                Spacer()
                
                // Search filter inside indexed files
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    TextField("Filter indexed files...", text: $indexService.searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .frame(width: 140)
                    
                    if !indexService.searchQuery.isEmpty {
                        Button(action: { indexService.searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 6)
                .frame(height: 26)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                )
                
                // Batch Rename button for indexed files
                Button(action: {
                    showingBatchRename = true
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "pencil.and.list.clipboard")
                        Text("Rename Group")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Batch rename files in the selected folder")
                
                // Close / Exit Index View
                Button(action: {
                    indexService.clearIndex()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close Index View")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            // Split View: Left = Directories, Right = Files
            if indexService.indexedGroups.isEmpty && !indexService.isScanning {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("No matching files found for this index")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .textBackgroundColor))
            } else {
                HSplitView {
                    // Left Pane: Directories List
                    directoryListPane
                        .frame(minWidth: 220, idealWidth: 280, maxWidth: 380)
                    
                    // Right Pane: Indexed Files in Selected Directory
                    filesListPane
                        .frame(minWidth: 350, maxWidth: .infinity)
                }
            }
        }
        .sheet(isPresented: $showingBatchRename) {
            if let items = selectedGroup?.items {
                BatchRenameView(items: items) {
                    if let index = indexService.activeIndex {
                        indexService.startIndexScan(for: index, in: navState.currentDirectory)
                    }
                }
            }
        }
    }
    
    // MARK: - Left Directory Pane
    private var directoryListPane: some View {
        VStack(spacing: 0) {
            HStack {
                Text("DIRECTORIES")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(indexService.indexedGroups.count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            
            Divider()
            
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(indexService.indexedGroups) { group in
                        let isSelected = indexService.selectedDirectory == group.directoryURL
                        
                        Button(action: {
                            indexService.selectedDirectory = group.directoryURL
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "folder.fill")
                                    .foregroundColor(Color.flashbrowseAccent)
                                    .font(.system(size: 13))
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(group.directoryName)
                                        .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                                        .foregroundColor(isSelected ? .white : .primary)
                                        .lineLimit(1)
                                    
                                    Text(group.relativePath)
                                        .font(.system(size: 10))
                                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                Text("\(group.items.count)")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(isSelected ? Color.white.opacity(0.25) : Color(nsColor: .controlBackgroundColor))
                                    .foregroundColor(isSelected ? .white : .secondary)
                                    .cornerRadius(8)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(isSelected ? Color.flashbrowseAccent : Color.clear)
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Open Folder in Flashbrowse") {
                                navState.navigateTo(url: group.directoryURL)
                                indexService.clearIndex()
                            }
                            
                            Button("Open in Terminal") {
                                FileSystemService.shared.openInTerminal(url: group.directoryURL)
                            }
                            
                            Button("Reveal in Finder") {
                                FileSystemService.shared.revealInFinder(url: group.directoryURL)
                            }
                        }
                    }
                }
                .padding(6)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }
    
    // MARK: - Right Files Pane
    private var filesListPane: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Text("FILE NAME")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("SIZE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 90, alignment: .trailing)
                
                Text("MODIFIED")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 140, alignment: .leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            
            Divider()
            
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(filteredItemsInSelectedGroup) { item in
                        let isHovered = hoveredURL == item.url
                        
                        HStack(spacing: 8) {
                            Image(systemName: item.sfSymbolName)
                                .foregroundColor(item.categoryColor)
                                .font(.system(size: 14))
                                .frame(width: 20)
                            
                            Text(item.name)
                                .font(.system(size: 12))
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Text(item.formattedSize)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(width: 90, alignment: .trailing)
                            
                            Text(item.formattedDate)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .frame(width: 140, alignment: .leading)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isHovered ? Color.flashbrowseAccent.opacity(0.12) : Color.clear)
                        )
                        .contentShape(Rectangle())
                        // Instant Hover + Debounced Inspector
                        .onHover { hovering in
                            if hovering {
                                hoveredURL = item.url
                                navState.scheduleInspectorUpdate(url: item.url)
                            } else if hoveredURL == item.url {
                                hoveredURL = nil
                            }
                        }
                        .onTapGesture {
                            FileSystemService.shared.openItem(url: item.url)
                        }
                        .contextMenu {
                            Button("Open File") {
                                FileSystemService.shared.openItem(url: item.url)
                            }
                            Button("Quick Look (Space)") {
                                QuickLookBridge.shared.toggleQuickLook(for: item.url)
                            }
                            Divider()
                            Button("Reveal in Finder") {
                                FileSystemService.shared.revealInFinder(url: item.url)
                            }
                            Button("Copy Path") {
                                FileSystemService.shared.copyPathToClipboard(urls: [item.url])
                            }
                        }
                    }
                }
                .padding(6)
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
    }
}
