import SwiftUI

// MARK: - Data Model
struct SubdirNode: Identifiable {
    let id = UUID()
    let name: String
    let url: URL
    var children: [SubdirNode]
    var hasMore: Bool
}

// MARK: - Async Loader
func loadSubdirTree(url: URL, maxDepth: Int, maxPerLevel: Int) -> [SubdirNode] {
    func buildTree(dir: URL, depth: Int) -> [SubdirNode] {
        guard depth <= maxDepth else { return [] }
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        let subdirs = entries
            .filter { url in
                (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }

        let hasMore = subdirs.count > maxPerLevel
        let slice = Array(subdirs.prefix(maxPerLevel))

        return slice.enumerated().map { idx, subdir in
            let children = buildTree(dir: subdir, depth: depth + 1)
            return SubdirNode(
                name: subdir.lastPathComponent,
                url: subdir,
                children: children,
                hasMore: hasMore && idx == slice.count - 1
            )
        }
    }
    return buildTree(dir: url, depth: 1)
}

// MARK: - Hover Dir Tree View
struct HoverDirTreeView: View {
    let rootURL: URL
    let onNavigate: (URL) -> Void
    let onClose: () -> Void

    @State private var nodes: [SubdirNode] = []
    @State private var isLoading = true
    @State private var expandedL1URL: URL? = nil
    @State private var expandedL2URL: URL? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 5) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 9))
                    .foregroundColor(Color.flashbrowseAccent)
                Text(rootURL.lastPathComponent)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.7))

            Divider()

            if isLoading {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.6).frame(width: 14, height: 14)
                    Text("Laddar...").font(.system(size: 11)).foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
            } else if nodes.isEmpty {
                Text("Inga underkataloger")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .italic()
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(nodes) { node in
                            let isExpanded = expandedL1URL == node.url
                            VStack(spacing: 0) {
                                HoverTreeRow(
                                    node: node,
                                    depth: 0,
                                    isExpanded: isExpanded,
                                    onHover: { hovering in
                                        if hovering {
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                                if expandedL1URL != node.url {
                                                    expandedL1URL = node.url
                                                    expandedL2URL = nil
                                                }
                                            }
                                        }
                                    },
                                    onNavigate: { url in
                                        onNavigate(url)
                                        onClose()
                                    }
                                )

                                // Level 1 children (inline, indented)
                                if isExpanded && !node.children.isEmpty {
                                    VStack(spacing: 0) {
                                        ForEach(node.children) { child in
                                            let isL2Expanded = expandedL2URL == child.url
                                            VStack(spacing: 0) {
                                                HoverTreeRow(
                                                    node: child,
                                                    depth: 1,
                                                    isExpanded: isL2Expanded,
                                                    onHover: { hovering in
                                                        if hovering {
                                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                                                expandedL2URL = child.url
                                                            }
                                                        }
                                                    },
                                                    onNavigate: { url in
                                                        onNavigate(url)
                                                        onClose()
                                                    }
                                                )

                                                // Level 2 grandchildren (inline, deeper indented)
                                                if isL2Expanded && !child.children.isEmpty {
                                                    VStack(spacing: 0) {
                                                        ForEach(child.children) { grandchild in
                                                            HoverTreeRow(
                                                                node: grandchild,
                                                                depth: 2,
                                                                isExpanded: false,
                                                                onHover: { _ in },
                                                                onNavigate: { url in
                                                                    onNavigate(url)
                                                                    onClose()
                                                                }
                                                            )
                                                        }
                                                        if child.hasMore {
                                                            HoverTreeMoreRow(depth: 2)
                                                        }
                                                    }
                                                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.12))
                                                }
                                            }
                                        }
                                        if node.hasMore {
                                            HoverTreeMoreRow(depth: 1)
                                        }
                                    }
                                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.08))
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 280)
            }
        }
        .frame(width: 220)
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 4)
        .onAppear {
            DispatchQueue.global(qos: .userInitiated).async {
                let result = loadSubdirTree(url: rootURL, maxDepth: 3, maxPerLevel: 8)
                DispatchQueue.main.async {
                    nodes = result
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Single Row
struct HoverTreeRow: View {
    let node: SubdirNode
    let depth: Int
    let isExpanded: Bool
    let onHover: (Bool) -> Void
    let onNavigate: (URL) -> Void

    @State private var isHovered = false

    var indent: CGFloat { CGFloat(depth) * 14 + 8 }

    var body: some View {
        Button(action: { onNavigate(node.url) }) {
            HStack(spacing: 5) {
                Spacer().frame(width: indent)
                Image(systemName: "folder.fill")
                    .font(.system(size: 11))
                    .foregroundColor(Color.flashbrowseAccent.opacity(depth == 0 ? 1.0 : (depth == 1 ? 0.75 : 0.55)))
                Text(node.name)
                    .font(.system(size: 11, weight: depth == 0 ? .medium : .regular))
                    .lineLimit(1)
                    .foregroundColor(isHovered ? .white : .primary)
                Spacer(minLength: 4)
                if !node.children.isEmpty {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(isHovered ? .white.opacity(0.7) : .secondary.opacity(0.5))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(isHovered ? Color.flashbrowseAccent : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
            onHover(hovering)
        }
    }
}

// MARK: - "More..." Row
struct HoverTreeMoreRow: View {
    let depth: Int
    var indent: CGFloat { CGFloat(depth) * 14 + 8 }

    var body: some View {
        HStack(spacing: 5) {
            Spacer().frame(width: indent)
            Image(systemName: "ellipsis")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            Text("fler...")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .italic()
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

// MARK: - DispatchWorkItemBox (ref-type wrapper for cancellable work)
final class DispatchWorkItemBox {
    var item: DispatchWorkItem?
    func cancel() {
        item?.cancel()
        item = nil
    }
}
