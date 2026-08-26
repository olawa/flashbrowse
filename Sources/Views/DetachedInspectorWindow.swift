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
            webView.loadHTMLString(html, baseURL: baseURL ?? url?.deletingLastPathComponent())
        } else if let fileURL = url {
            webView.loadFileURL(fileURL, allowingReadAccessTo: fileURL.deletingLastPathComponent())
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
                    .foregroundColor(Color(red: 0.91, green: 0.33, blue: 0.13))
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
                HSplitView {
                    // Preview Area (Left / Main)
                    previewContainer(meta: meta)
                        .frame(minWidth: 350, maxWidth: .infinity, minHeight: 350)
                    
                    // Metadata Panel (Right)
                    metadataSidebar(meta: meta)
                        .frame(minWidth: 220, idealWidth: 260, maxWidth: 320)
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
                ScrollView([.horizontal, .vertical]) {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(16)
                }
                .background(contentBgColor)
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
                    .foregroundColor(Color(red: 0.91, green: 0.33, blue: 0.13))
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
                                    .foregroundColor(isHeader ? (isDarkTheme ? .cyan : Color(red: 0.91, green: 0.33, blue: 0.13)) : (isDarkTheme ? .white : .primary))
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
