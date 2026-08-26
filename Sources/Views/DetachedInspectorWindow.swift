import SwiftUI
import AppKit
import WebKit
import CoreGraphics
import PDFKit
import QuickLookUI

// MARK: - Native QuickLook Preview Renderer
public struct QuickLookRepresentable: NSViewRepresentable {
    let url: URL
    
    public init(url: URL) {
        self.url = url
    }
    
    public func makeNSView(context: Context) -> QLPreviewView {
        let view = QLPreviewView(frame: .zero, style: .normal) ?? QLPreviewView()
        view.previewItem = url as QLPreviewItem
        view.autostarts = true
        return view
    }
    
    public func updateNSView(_ view: QLPreviewView, context: Context) {
        if (view.previewItem as? URL) != url {
            view.previewItem = url as QLPreviewItem
        }
    }
}

// MARK: - Native PDFKit Renderer
public struct PDFKitRepresentable: NSViewRepresentable {
    let url: URL
    
    public init(url: URL) {
        self.url = url
    }
    
    public func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.document = PDFDocument(url: url)
        return pdfView
    }
    
    public func updateNSView(_ pdfView: PDFView, context: Context) {
        if pdfView.document?.documentURL != url {
            pdfView.document = PDFDocument(url: url)
        }
    }
}

// MARK: - Native WebKit Renderer
public struct WebViewRenderer: NSViewRepresentable {
    let url: URL?
    let htmlContent: String?
    let baseURL: URL?
    @ObservedObject var inspectorState = SharedInspectorState.shared
    
    public init(url: URL? = nil, htmlContent: String? = nil, baseURL: URL? = nil) {
        self.url = url
        self.htmlContent = htmlContent
        self.baseURL = baseURL
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    public class Coordinator {
        var lastPulse: Int = -1
        var lastLoadedURL: URL?
        var lastLoadedHTML: String?
    }
    
    public func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }
    
    public func updateNSView(_ webView: WKWebView, context: Context) {
        if context.coordinator.lastPulse != inspectorState.scrollPulse {
            context.coordinator.lastPulse = inspectorState.scrollPulse
            let delta = inspectorState.scrollDeltaY
            if delta != 0 {
                webView.evaluateJavaScript("window.scrollBy({top: \(delta), left: 0, behavior: 'auto'});", completionHandler: nil)
            }
        }
        
        if let html = htmlContent {
            if context.coordinator.lastLoadedHTML != html {
                context.coordinator.lastLoadedHTML = html
                context.coordinator.lastLoadedURL = nil
                webView.loadHTMLString(html, baseURL: baseURL ?? url?.deletingLastPathComponent())
            }
        } else if let fileURL = url {
            if context.coordinator.lastLoadedURL != fileURL {
                context.coordinator.lastLoadedURL = fileURL
                context.coordinator.lastLoadedHTML = nil
                webView.loadFileURL(fileURL, allowingReadAccessTo: fileURL.deletingLastPathComponent())
            }
        }
    }
}

// MARK: - Markdown Renderer
public struct MarkdownRenderer {
    public static func wrapInGitHubStyleHTML(markdown: String, isDark: Bool = true) -> String {
        let escaped = markdown
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "</script>", with: "<\\/script>")
        
        let bgColor = isDark ? "#0d1117" : "#ffffff"
        let textColor = isDark ? "#e6edf3" : "#24292f"
        let borderColor = isDark ? "#30363d" : "#d0d7de"
        let codeBg = isDark ? "#161b22" : "#f6f8fa"
        let accentColor = "#e95420"
        let quoteColor = isDark ? "#8b949e" : "#57606a"
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
        <style>
            :root {
                color-scheme: \(isDark ? "dark" : "light");
                --bg: \(bgColor);
                --text: \(textColor);
                --border: \(borderColor);
                --code-bg: \(codeBg);
                --accent: \(accentColor);
                --quote: \(quoteColor);
            }
            body {
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "Noto Sans", Helvetica, Arial, sans-serif;
                font-size: 14px;
                line-height: 1.6;
                background-color: var(--bg);
                color: var(--text);
                padding: 24px;
                margin: 0;
                word-wrap: break-word;
            }
            h1, h2, h3, h4, h5, h6 {
                margin-top: 24px;
                margin-bottom: 16px;
                font-weight: 600;
                line-height: 1.25;
                color: var(--text);
            }
            h1 { font-size: 2em; border-bottom: 1px solid var(--border); padding-bottom: .3em; }
            h2 { font-size: 1.5em; border-bottom: 1px solid var(--border); padding-bottom: .3em; }
            h3 { font-size: 1.25em; }
            a { color: var(--accent); text-decoration: none; }
            a:hover { text-decoration: underline; }
            pre {
                background-color: var(--code-bg);
                padding: 16px;
                border-radius: 6px;
                overflow: auto;
                font-size: 12px;
                font-family: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, monospace;
                border: 1px solid var(--border);
            }
            code {
                font-family: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, monospace;
                font-size: 85%;
                background-color: var(--code-bg);
                padding: .2em .4em;
                border-radius: 4px;
            }
            pre code { background-color: transparent; padding: 0; border: 0; }
            blockquote {
                padding: 0 1em;
                color: var(--quote);
                border-left: .25em solid var(--border);
                margin: 0 0 16px 0;
            }
            table {
                border-spacing: 0;
                border-collapse: collapse;
                margin: 16px 0;
                width: 100%;
            }
            table th, table td {
                padding: 6px 13px;
                border: 1px solid var(--border);
            }
            table tr:nth-child(2n) { background-color: var(--code-bg); }
            img { max-width: 100%; box-sizing: content-box; border-radius: 6px; }
            hr { height: .25em; padding: 0; margin: 24px 0; background-color: var(--border); border: 0; }
        </style>
        </head>
        <body>
        <div id="content"></div>
        <script>
            const rawMarkdown = `\(escaped)`;
            if (typeof marked !== 'undefined') {
                document.getElementById('content').innerHTML = marked.parse(rawMarkdown);
            } else {
                document.getElementById('content').innerText = rawMarkdown;
            }
        </script>
        </body>
        </html>
        """
    }
}

// MARK: - Main Inspector View
public struct InspectorView: View {
    @ObservedObject var state = SharedInspectorState.shared
    @State private var renderMode: Int = 0 // 0 = Rendered / Visual, 1 = Source / Grid
    @AppStorage("flashbrowse_inspector_dark_theme") private var isDarkTheme: Bool = true
    @State private var tableFilter: String = ""
    
    public init() {}
    
    // Theme Palette Colors
    private var bgColor: Color {
        isDarkTheme ? Color(red: 0.08, green: 0.08, blue: 0.09) : Color(nsColor: .windowBackgroundColor)
    }
    
    private var contentBgColor: Color {
        isDarkTheme ? Color(red: 0.05, green: 0.05, blue: 0.06) : Color(nsColor: .textBackgroundColor)
    }
    
    private var cardBgColor: Color {
        isDarkTheme ? Color(red: 0.12, green: 0.12, blue: 0.14) : Color(nsColor: .controlBackgroundColor).opacity(0.6)
    }
    
    private var borderColor: Color {
        isDarkTheme ? Color.white.opacity(0.1) : Color(nsColor: .separatorColor)
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 8) {
                Image(systemName: "display.2")
                    .foregroundColor(Color.flashbrowseAccent)
                    .font(.system(size: 14))
                
                Text(state.metadata?.name ?? "No Selection")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(isDarkTheme ? .white : .primary)
                    .lineLimit(1)
                
                // Toggle Rendered vs Source / Grid
                if state.contentType == .markdown || state.contentType == .html {
                    Picker("", selection: $renderMode) {
                        Text("👁 Rendered").tag(0)
                        Text("💻 Source").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 170)
                    .padding(.leading, 8)
                } else if state.contentType == .spreadsheet && !state.parsedTableRows.isEmpty {
                    Picker("", selection: $renderMode) {
                        Text("📊 Grid Table").tag(0)
                        Text("👁 Native Sheet").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 190)
                    .padding(.leading, 8)
                } else if state.contentType == .image {
                    // Photo Culling & Lightbox Controls
                    HStack(spacing: 6) {
                        Text("\(state.currentImageIndex + 1)/\(max(1, state.totalImageCount))")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(cardBgColor)
                            .cornerRadius(4)
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                state.isPhotoOrganizerActive.toggle()
                                if state.isPhotoOrganizerActive {
                                    state.isLightboxMode = true
                                }
                            }
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: state.isPhotoOrganizerActive ? "sparkles.rectangle.stack.fill" : "sparkles.rectangle.stack")
                                Text(state.isPhotoOrganizerActive ? "📸 Culler Active" : "📸 Photo Culler")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(state.isPhotoOrganizerActive ? Color.green.opacity(0.25) : cardBgColor)
                            .foregroundColor(state.isPhotoOrganizerActive ? Color.green : .primary)
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        .help("Toggle Photo Culler & Organizer mode (Swipe Right to Keep, Swipe Left to Discard)")
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                state.isLightboxMode.toggle()
                            }
                        }) {
                            Image(systemName: state.isLightboxMode ? "sidebar.right" : "rectangle.inset.filled")
                                .font(.system(size: 11))
                                .foregroundColor(state.isLightboxMode ? Color.flashbrowseAccent : .secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(cardBgColor)
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        .help(state.isLightboxMode ? "Show Metadata Sidebar" : "Hide Sidebar (100% Lightbox on iPad)")
                    }
                    .padding(.leading, 8)
                }
                
                Spacer()
                
                // Dark Theme Toggle
                Button(action: {
                    isDarkTheme.toggle()
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: isDarkTheme ? "moon.stars.fill" : "sun.max.fill")
                            .foregroundColor(isDarkTheme ? .yellow : .orange)
                        Text(isDarkTheme ? "Dark" : "Light")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(cardBgColor)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help("Toggle Inspector Dark/Light Theme")
                
                // Jump to Main Window Button
                Button(action: {
                    InspectorWindowController.shared.warpMouseToMainWindow()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "cursorarrow.motionlines")
                        Text("Jump to Browser (Cmd+<)")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(cardBgColor)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help("Teleport cursor and focus back to main Flashbrowse window (Cmd+<)")
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 7, height: 7)
                    Text("LIVE SYNC")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(cardBgColor)
                .cornerRadius(4)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(bgColor)
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(borderColor),
                alignment: .bottom
            )
            
            if let meta = state.metadata {
                if state.isLightboxMode {
                    previewContainer(meta: meta)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    HSplitView {
                        // Preview Area (Left / Main)
                        previewContainer(meta: meta)
                            .frame(minWidth: 350, maxWidth: .infinity, minHeight: 350)
                        
                        // Metadata Panel (Right)
                        metadataSidebar(meta: meta)
                            .frame(minWidth: 220, idealWidth: 260, maxWidth: 320)
                    }
                }
            } else {
                emptyState
            }
        }
        .background(bgColor)
        .preferredColorScheme(isDarkTheme ? .dark : .light)
    }
    
    @ViewBuilder
    private func previewContainer(meta: ExtendedFileMetadata) -> some View {
        switch state.contentType {
        case .pdf:
            if let url = state.currentURL {
                PDFKitRepresentable(url: url)
                    .background(contentBgColor)
            }
            
        case .officeDoc, .media:
            if let url = state.currentURL {
                QuickLookRepresentable(url: url)
                    .background(contentBgColor)
            }
            
        case .spreadsheet:
            if let url = state.currentURL {
                if renderMode == 0 && !state.parsedTableRows.isEmpty {
                    spreadsheetTableView
                } else {
                    QuickLookRepresentable(url: url)
                        .background(contentBgColor)
                }
            }
            
        case .image:
            if let img = state.previewImage {
                InteractivePhotoView(img: img, meta: meta, isDarkTheme: isDarkTheme)
            }
            
        case .html:
            if renderMode == 0, let url = state.currentURL {
                WebViewRenderer(url: url)
                    .background(contentBgColor)
            } else if let text = state.textContent {
                codeViewer(text: text)
            }
            
        case .markdown:
            if renderMode == 0, let text = state.textContent {
                let html = MarkdownRenderer.wrapInGitHubStyleHTML(markdown: text, isDark: isDarkTheme)
                WebViewRenderer(htmlContent: html, baseURL: state.currentURL?.deletingLastPathComponent())
                    .background(contentBgColor)
            } else if let text = state.textContent {
                codeViewer(text: text)
            }
            
        case .code, .text:
            if let text = state.textContent {
                codeViewer(text: text)
            }
            
        case .folder:
            VStack(spacing: 12) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 64))
                    .foregroundColor(Color.flashbrowseAccent)
                Text(meta.name)
                    .font(.system(size: 16, weight: .bold))
                Text("Folder")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(contentBgColor)
            
        case .generic:
            if let url = state.currentURL {
                QuickLookRepresentable(url: url)
                    .background(contentBgColor)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 54))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text(meta.name)
                        .font(.system(size: 14, weight: .medium))
                    Text(meta.kindDescription)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(contentBgColor)
            }
        }
    }
    
    // MARK: - Spreadsheet / Data Table View
    private var spreadsheetTableView: some View {
        VStack(spacing: 0) {
            // Table Filter Bar
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .foregroundColor(.secondary)
                TextField("Filter rows in table...", text: $tableFilter)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                
                Spacer()
                
                Text("\(filteredRows.count) rows")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(cardBgColor)
            
            Divider()
            
            ScrollView([.horizontal, .vertical]) {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(Array(filteredRows.enumerated()), id: \.offset) { rowIdx, row in
                        let isHeader = (rowIdx == 0)
                        
                        HStack(spacing: 1) {
                            // Row Number Column
                            Text("\(rowIdx + 1)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(width: 35, alignment: .trailing)
                                .padding(.trailing, 6)
                                .padding(.vertical, 4)
                                .background(cardBgColor.opacity(0.8))
                            
                            // Cells
                            ForEach(Array(row.enumerated()), id: \.offset) { colIdx, cell in
                                Text(cell)
                                    .font(.system(size: 11, weight: isHeader ? .bold : .regular, design: .monospaced))
                                    .foregroundColor(isHeader ? (isDarkTheme ? .cyan : Color.flashbrowseAccent) : (isDarkTheme ? .white : .primary))
                                    .lineLimit(1)
                                    .frame(minWidth: 100, maxWidth: 300, alignment: .leading)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(isHeader ? cardBgColor : (rowIdx % 2 == 0 ? contentBgColor : cardBgColor.opacity(0.3)))
                            }
                        }
                    }
                }
                .padding(4)
            }
            .background(contentBgColor)
        }
    }
    
    private var filteredRows: [[String]] {
        let rows = state.parsedTableRows
        guard !tableFilter.trimmingCharacters(in: .whitespaces).isEmpty else { return rows }
        let query = tableFilter.lowercased()
        
        // Preserve header (row 0) and filter the rest
        if let header = rows.first {
            let matches = rows.dropFirst().filter { row in
                row.contains(where: { $0.lowercased().contains(query) })
            }
            return [header] + matches
        }
        return rows
    }
    
    @ViewBuilder
    private func codeViewer(text: String) -> some View {
        ScrollView {
            Text(text)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(isDarkTheme ? Color(red: 0.9, green: 0.9, blue: 0.9) : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .textSelection(.enabled)
        }
        .background(contentBgColor)
    }
    
    @ViewBuilder
    private func metadataSidebar(meta: ExtendedFileMetadata) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("INFORMATION")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                
                VStack(spacing: 8) {
                    metaRow(label: "Kind", value: meta.kindDescription)
                    metaRow(label: "Size", value: "\(meta.sizeFormatted) (\(meta.exactBytes) bytes)")
                    if let dim = meta.dimensions {
                        metaRow(label: "Dimensions", value: dim)
                    }
                    metaRow(label: "Modified", value: meta.dateModified)
                    metaRow(label: "Created", value: meta.dateCreated)
                    metaRow(label: "Permissions", value: meta.permissions)
                }
                .padding(10)
                .background(cardBgColor)
                .cornerRadius(8)
                
                Text("LOCATION")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(meta.path)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(isDarkTheme ? Color.white.opacity(0.8) : .secondary)
                        .textSelection(.enabled)
                    
                    HStack {
                        Button("Copy Path") {
                            let pasteboard = NSPasteboard.general
                            pasteboard.clearContents()
                            pasteboard.setString(meta.path, forType: .string)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button("Reveal in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: meta.path)])
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.top, 4)
                }
                .padding(10)
                .background(cardBgColor)
                .cornerRadius(8)
            }
            .padding(14)
        }
        .background(bgColor)
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "hand.point.up.left.and.text")
                .font(.system(size: 44))
                .foregroundColor(.secondary.opacity(0.4))
            Text("Hover or select any file in Flashbrowse")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            Text("PDFs, Excel spreadsheets, Word docs, Markdown, images, and code will render here instantly.")
                .font(.system(size: 12))
                .foregroundColor(.secondary.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(contentBgColor)
    }
    
    @ViewBuilder
    private func metaRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.system(size: 11))
                .foregroundColor(isDarkTheme ? .white : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }
}

// MARK: - Interactive Touch & Gesture Photo Viewer
public struct InteractivePhotoView: View {
    let img: NSImage
    let meta: ExtendedFileMetadata
    let isDarkTheme: Bool
    @ObservedObject var state = SharedInspectorState.shared
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    // Swipe / Card Dragging
    @State private var swipeTranslation: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var isHoveringLeftChevron: Bool = false
    @State private var isHoveringRightChevron: Bool = false
    
    public init(img: NSImage, meta: ExtendedFileMetadata, isDarkTheme: Bool) {
        self.img = img
        self.meta = meta
        self.isDarkTheme = isDarkTheme
    }
    
    public var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background
                (isDarkTheme ? Color(red: 0.05, green: 0.05, blue: 0.06) : Color(nsColor: .textBackgroundColor))
                    .ignoresSafeArea()
                
                // Photo Image with Zoom, Pan, & Swipe Animations
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(
                        x: scale > 1.05 ? offset.width : swipeTranslation,
                        y: scale > 1.05 ? offset.height : 0
                    )
                    .rotationEffect(.degrees(scale <= 1.05 ? Double(swipeTranslation / 24.0) : 0))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(scale <= 1.05 ? 16 : 0)
                    .contentShape(Rectangle())
                    // Double Tap Gesture to Toggle Fit vs 2.5x Zoom
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            if scale > 1.05 {
                                scale = 1.0
                                lastScale = 1.0
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                scale = 2.5
                                lastScale = 2.5
                            }
                        }
                    }
                    // Pinch to Zoom (iPad Touch & Trackpad)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { val in
                                let newScale = lastScale * val
                                scale = min(max(newScale, 0.75), 8.0)
                            }
                            .onEnded { _ in
                                if scale < 1.05 {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        scale = 1.0
                                        lastScale = 1.0
                                        offset = .zero
                                        lastOffset = .zero
                                    }
                                } else {
                                    lastScale = scale
                                }
                            }
                    )
                    // Drag to Pan (when zoomed) or Swipe / Cull (when at 1.0x)
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { val in
                                if scale > 1.05 {
                                    offset = CGSize(
                                        width: lastOffset.width + val.translation.width,
                                        height: lastOffset.height + val.translation.height
                                    )
                                } else {
                                    swipeTranslation = val.translation.width
                                    isDragging = true
                                }
                            }
                            .onEnded { val in
                                if scale > 1.05 {
                                    lastOffset = offset
                                } else {
                                    isDragging = false
                                    let threshold: CGFloat = 85
                                    if state.isPhotoOrganizerActive {
                                        if val.translation.width > threshold {
                                            // Swipe Right -> KEEP / PICK
                                            withAnimation(.easeOut(duration: 0.18)) {
                                                swipeTranslation = 600
                                            }
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                                state.pickCurrentImage()
                                                swipeTranslation = 0
                                            }
                                        } else if val.translation.width < -threshold {
                                            // Swipe Left -> DISCARD / TRASH
                                            withAnimation(.easeOut(duration: 0.18)) {
                                                swipeTranslation = -600
                                            }
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                                state.trashCurrentImage()
                                                swipeTranslation = 0
                                            }
                                        } else {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                swipeTranslation = 0
                                            }
                                        }
                                    } else {
                                        // Normal browsing mode: Swipe Left = Next, Swipe Right = Prev
                                        if val.translation.width > threshold {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                                state.previousImage()
                                                swipeTranslation = 0
                                            }
                                        } else if val.translation.width < -threshold {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                                state.nextImage()
                                                swipeTranslation = 0
                                            }
                                        } else {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                swipeTranslation = 0
                                            }
                                        }
                                    }
                                }
                            }
                    )
                
                // Side Quick-Touch Navigation Chevrons (Left & Right)
                if scale <= 1.05 {
                    HStack {
                        Button(action: {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                state.previousImage()
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 48, height: 80)
                                .background(Color.black.opacity(isHoveringLeftChevron ? 0.6 : 0.25))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .padding(.leading, 12)
                        }
                        .buttonStyle(.plain)
                        .onHover { isHoveringLeftChevron = $0 }
                        .disabled(state.currentImageIndex <= 0)
                        .opacity(state.currentImageIndex <= 0 ? 0.15 : 0.85)
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                state.nextImage()
                            }
                        }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 48, height: 80)
                                .background(Color.black.opacity(isHoveringRightChevron ? 0.6 : 0.25))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .padding(.trailing, 12)
                        }
                        .buttonStyle(.plain)
                        .onHover { isHoveringRightChevron = $0 }
                        .disabled(state.currentImageIndex >= state.totalImageCount - 1)
                        .opacity(state.currentImageIndex >= state.totalImageCount - 1 ? 0.15 : 0.85)
                    }
                }
                
                // Dynamic Swipe Badges (KEEP / DISCARD in Organizer Mode)
                if state.isPhotoOrganizerActive && scale <= 1.05 && swipeTranslation != 0 {
                    if swipeTranslation > 25 {
                        VStack {
                            HStack {
                                Text("⭐ KEEP")
                                    .font(.system(size: 26, weight: .black))
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.black.opacity(0.75))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.green, lineWidth: 3)
                                    )
                                    .cornerRadius(10)
                                    .rotationEffect(.degrees(-15))
                                    .opacity(min(1.0, Double(swipeTranslation) / 80.0))
                                    .padding(32)
                                Spacer()
                            }
                            Spacer()
                        }
                    } else if swipeTranslation < -25 {
                        VStack {
                            HStack {
                                Spacer()
                                Text("🗑️ DISCARD")
                                    .font(.system(size: 26, weight: .black))
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.black.opacity(0.75))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.red, lineWidth: 3)
                                    )
                                    .cornerRadius(10)
                                    .rotationEffect(.degrees(15))
                                    .opacity(min(1.0, Double(-swipeTranslation) / 80.0))
                                    .padding(32)
                            }
                            Spacer()
                        }
                    }
                }
                
                // Floating Action Toast Banner
                if let banner = state.photoActionBanner {
                    VStack {
                        Text(banner)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.85))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                            .shadow(radius: 8)
                            .padding(.top, 16)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        Spacer()
                    }
                }
                
                // Big Touch HUD Control Bar at Bottom
                VStack {
                    Spacer()
                    touchControlBar
                        .padding(.bottom, 16)
                }
            }
        }
        .focusable()
        // Keyboard Shortcuts for Rapid Culling & Navigation
        .onKeyPress(.leftArrow) {
            state.previousImage()
            return .handled
        }
        .onKeyPress(.rightArrow) {
            state.nextImage()
            return .handled
        }
        .onKeyPress(.space) {
            if state.isPhotoOrganizerActive {
                state.pickCurrentImage()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.delete) {
            if state.isPhotoOrganizerActive {
                state.trashCurrentImage()
                return .handled
            }
            return .ignored
        }
        .onKeyPress("u") {
            if state.canUndo {
                state.undoLastAction()
                return .handled
            }
            return .ignored
        }
    }
    
    // MARK: - Big Touch Control Bar for iPad / Mouse
    private var touchControlBar: some View {
        HStack(spacing: 10) {
            if state.isPhotoOrganizerActive {
                // 🔴 Discard Button
                Button(action: {
                    withAnimation(.easeOut(duration: 0.15)) {
                        state.trashCurrentImage()
                    }
                }) {
                    VStack(spacing: 2) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 18, weight: .bold))
                        Text("Discard")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(width: 68, height: 48)
                    .background(Color.red)
                    .cornerRadius(10)
                    .shadow(color: .red.opacity(0.4), radius: 4)
                }
                .buttonStyle(.plain)
                .help("Move photo to Trash (Swipe Left / Delete)")
                
                // ◀️ Prev Button
                Button(action: { state.previousImage() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 48)
                        .background(Color.white.opacity(0.18))
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .disabled(state.currentImageIndex <= 0)
                .opacity(state.currentImageIndex <= 0 ? 0.35 : 1.0)
                
                // Index Info & Help Pill
                VStack(spacing: 1) {
                    Text("\(state.currentImageIndex + 1) / \(max(1, state.totalImageCount))")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                    Text("Swipe or Tap")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 8)
                
                // ↩️ Undo Button
                if state.canUndo {
                    Button(action: { state.undoLastAction() }) {
                        VStack(spacing: 2) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 14, weight: .bold))
                            Text("Undo")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(width: 44, height: 48)
                        .background(Color.orange.opacity(0.9))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .help("Undo last action (Cmd+Z)")
                }
                
                // ▶️ Next Button
                Button(action: { state.nextImage() }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 48)
                        .background(Color.white.opacity(0.18))
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .disabled(state.currentImageIndex >= state.totalImageCount - 1)
                .opacity(state.currentImageIndex >= state.totalImageCount - 1 ? 0.35 : 1.0)
                
                // 🟢 Keep Button
                Button(action: {
                    withAnimation(.easeOut(duration: 0.15)) {
                        state.pickCurrentImage()
                    }
                }) {
                    VStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 18, weight: .bold))
                        Text("Keep")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(width: 68, height: 48)
                    .background(Color.green)
                    .cornerRadius(10)
                    .shadow(color: .green.opacity(0.4), radius: 4)
                }
                .buttonStyle(.plain)
                .help("Keep photo in _picked folder (Swipe Right / Space)")
            } else {
                // Normal Preview Touch Controls
                Button(action: { state.previousImage() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Prev")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.18))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(state.currentImageIndex <= 0)
                .opacity(state.currentImageIndex <= 0 ? 0.35 : 1.0)
                
                Text("\(state.currentImageIndex + 1) of \(max(1, state.totalImageCount))")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                
                Button(action: { state.nextImage() }) {
                    HStack(spacing: 4) {
                        Text("Next")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.18))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(state.currentImageIndex >= state.totalImageCount - 1)
                .opacity(state.currentImageIndex >= state.totalImageCount - 1 ? 0.35 : 1.0)
                
                Divider().frame(height: 18)
                
                // Zoom Toggle Button
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        if scale > 1.05 {
                            scale = 1.0
                            lastScale = 1.0
                            offset = .zero
                            lastOffset = .zero
                        } else {
                            scale = 2.5
                            lastScale = 2.5
                        }
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: scale > 1.05 ? "minus.magnifyingglass" : "plus.magnifyingglass")
                        Text(scale > 1.05 ? "Fit" : "2.5x")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.18))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .help("Toggle Zoom (Double Tap / Pinch)")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.5), radius: 10, y: 5)
    }
}

// MARK: - Multi-Monitor Window Controller
@MainActor
public class InspectorWindowController: NSObject {
    public static let shared = InspectorWindowController()
    public var window: NSWindow?
    
    public func toggleWindow() {
        if let win = window, win.isVisible {
            win.orderOut(nil)
            SharedInspectorState.shared.isInspectorWindowOpen = false
        } else {
            showWindow()
        }
    }
    
    public func showWindow() {
        if window == nil {
            let win = NSWindow(
                contentRect: NSRect(x: 100, y: 100, width: 850, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            win.title = "Flashbrowse Inspector (Multi-Monitor)"
            win.isReleasedWhenClosed = false
            win.contentView = NSHostingView(rootView: InspectorView())
            self.window = win
        }
        
        window?.makeKeyAndOrderFront(nil)
        SharedInspectorState.shared.isInspectorWindowOpen = true
    }
    
    public func warpMouseToInspector() {
        showWindow()
        guard let win = window else { return }
        
        let frame = win.frame
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 1080
        let targetPoint = CGPoint(x: frame.midX, y: primaryHeight - frame.midY)
        
        CGWarpMouseCursorPosition(targetPoint)
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    public func warpMouseToMainWindow() {
        guard let mainWin = NSApp.windows.first(where: { $0 != self.window && $0.isVisible }) else { return }
        
        let frame = mainWin.frame
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 1080
        let targetPoint = CGPoint(x: frame.midX, y: primaryHeight - frame.midY)
        
        CGWarpMouseCursorPosition(targetPoint)
        mainWin.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    public func toggleMouseBetweenScreens() {
        if NSApp.keyWindow == self.window {
            warpMouseToMainWindow()
        } else {
            warpMouseToInspector()
        }
    }
}
