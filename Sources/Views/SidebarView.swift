import SwiftUI
import UniformTypeIdentifiers

struct SidebarLocation: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let url: URL
}

public struct SidebarView: View {
    @ObservedObject var state: NavigationState
    @ObservedObject var indexService = IndexService.shared
    @State private var isDropTargeted: Bool = false
    
    private var standardLocations: [SidebarLocation] {
        let fm = FileManager.default
        var locs: [SidebarLocation] = []
        
        let home = fm.homeDirectoryForCurrentUser
        locs.append(SidebarLocation(name: "Home", icon: "house.fill", url: home))
        
        if let desktop = fm.urls(for: .desktopDirectory, in: .userDomainMask).first {
            locs.append(SidebarLocation(name: "Desktop", icon: "menubar.dock.rectangle", url: desktop))
        }
        if let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
            locs.append(SidebarLocation(name: "Documents", icon: "doc.text.fill", url: docs))
        }
        if let downloads = fm.urls(for: .downloadsDirectory, in: .userDomainMask).first {
            locs.append(SidebarLocation(name: "Downloads", icon: "arrow.down.circle.fill", url: downloads))
        }
        
        return locs
    }
    
    private var systemLocations: [SidebarLocation] {
        return [
            SidebarLocation(name: "File System", icon: "internaldrive.fill", url: URL(fileURLWithPath: "/")),
            SidebarLocation(name: "Applications", icon: "square.grid.2x2.fill", url: URL(fileURLWithPath: "/Applications")),
            SidebarLocation(name: "Temporary (/tmp)", icon: "clock.arrow.circlepath", url: URL(fileURLWithPath: "/tmp"))
        ]
    }
    
    public init(state: NavigationState) {
        self.state = state
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Flashbrowse Header Branding
            HStack(spacing: 6) {
                Image(systemName: "bolt.horizontal.fill")
                    .foregroundColor(Color(red: 0.91, green: 0.33, blue: 0.13))
                    .font(.system(size: 14))
                Text("Flashbrowse")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // Standard Places
                    VStack(alignment: .leading, spacing: 2) {
                        Text("PLACES")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.bottom, 2)
                        
                        ForEach(standardLocations) { loc in
                            sidebarRow(name: loc.name, icon: loc.icon, url: loc.url)
                        }
                    }
                    
                    // File Type Indexes Hub (Bioinformatics & Developers)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("FILE TYPE INDEXES")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.bottom, 2)
                        
                        ForEach(FileTypeIndex.defaultPresets) { index in
                            indexRow(for: index)
                        }
                    }
                    
                    // User Custom Favorites / Bookmarks with Drag & Drop
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("FAVORITES")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button(action: {
                                state.addBookmark(url: state.currentDirectory)
                            }) {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Pin current folder to Favorites")
                        }
                        .padding(.horizontal, 10)
                        .padding(.bottom, 2)
                        
                        if state.customBookmarks.isEmpty {
                            HStack {
                                Image(systemName: "arrow.down.doc")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary.opacity(0.6))
                                Text("Drop folders here")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary.opacity(0.7))
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                                    .foregroundColor(Color.secondary.opacity(0.3))
                            )
                        } else {
                            ForEach(state.customBookmarks) { b in
                                favoriteRow(for: b)
                            }
                        }
                    }
                    .padding(4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isDropTargeted ? Color(red: 0.91, green: 0.33, blue: 0.13).opacity(0.15) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isDropTargeted ? Color(red: 0.91, green: 0.33, blue: 0.13) : Color.clear, lineWidth: 1.5)
                    )
                    .onDrop(of: [UTType.fileURL.identifier, UTType.utf8PlainText.identifier], isTargeted: $isDropTargeted) { providers in
                        handleDrop(providers: providers)
                    }
                    
                    // Drives & System
                    VStack(alignment: .leading, spacing: 2) {
                        Text("DRIVES & SYSTEM")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.bottom, 2)
                        
                        ForEach(systemLocations) { loc in
                            sidebarRow(name: loc.name, icon: loc.icon, url: loc.url)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(minWidth: 180, idealWidth: 210, maxWidth: 260)
    }
    
    @ViewBuilder
    private func indexRow(for index: FileTypeIndex) -> some View {
        let isSelected = indexService.activeIndex?.id == index.id
        
        Button(action: {
            if isSelected {
                indexService.clearIndex()
            } else {
                indexService.startIndexScan(for: index, in: state.currentDirectory)
            }
        }) {
            HStack(spacing: 7) {
                Image(systemName: index.icon)
                    .foregroundColor(isSelected ? .white : index.color)
                    .font(.system(size: 12))
                    .frame(width: 18)
                
                Text(index.name)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                    .lineLimit(1)
                
                Spacer()
                
                if isSelected && indexService.isScanning {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? index.color : Color.clear)
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func sidebarRow(name: String, icon: String, url: URL) -> some View {
        let isSelected = indexService.activeIndex == nil && state.currentDirectory.path == url.path
        
        Button(action: {
            indexService.clearIndex()
            state.navigateTo(url: url)
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(isSelected ? .white : Color(red: 0.91, green: 0.33, blue: 0.13))
                    .font(.system(size: 13))
                    .frame(width: 18)
                
                Text(name)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                
                Spacer()
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color(red: 0.91, green: 0.33, blue: 0.13) : Color.clear)
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func favoriteRow(for bookmark: BookmarkItem) -> some View {
        let isSelected = indexService.activeIndex == nil && state.currentDirectory.path == bookmark.url.path
        
        Button(action: {
            indexService.clearIndex()
            state.navigateTo(url: bookmark.url)
        }) {
            HStack(spacing: 8) {
                Image(systemName: bookmark.icon)
                    .foregroundColor(isSelected ? .white : Color(red: 0.91, green: 0.33, blue: 0.13))
                    .font(.system(size: 13))
                    .frame(width: 18)
                
                Text(bookmark.name)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color(red: 0.91, green: 0.33, blue: 0.13) : Color.clear)
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive, action: {
                state.removeBookmark(url: bookmark.url)
            }) {
                Label("Remove from Favorites", systemImage: "star.slash")
            }
            
            Divider()
            
            Button(action: {
                FileSystemService.shared.openInTerminal(url: bookmark.url)
            }) {
                Label("Open in Terminal", systemImage: "terminal")
            }
            
            Button(action: {
                FileSystemService.shared.copyPathToClipboard(urls: [bookmark.url])
            }) {
                Label("Copy Path", systemImage: "doc.on.doc")
            }
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    var targetURL: URL?
                    if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        targetURL = url
                    } else if let url = item as? URL {
                        targetURL = url
                    } else if let nsURL = item as? NSURL {
                        targetURL = nsURL as URL
                    }
                    
                    if let url = targetURL {
                        var isDir: ObjCBool = false
                        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                            Task { @MainActor in
                                self.state.addBookmark(url: url)
                            }
                        }
                    }
                }
                return true
            }
        }
        return false
    }
}
