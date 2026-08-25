import SwiftUI
import AppKit
import WebKit
import CoreGraphics

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

public struct MarkdownRenderer {
    public static func wrapInGitHubStyleHTML(markdown: String) -> String {
        let escaped = markdown
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "</script>", with: "<\\/script>")
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
        <style>
            :root {
                color-scheme: light dark;
                --bg: #ffffff;
                --text: #24292f;
                --border: #d0d7de;
                --code-bg: #f6f8fa;
                --accent: #e95420;
                --quote: #57606a;
            }
            @media (prefers-color-scheme: dark) {
                :root {
                    --bg: #1e1e1e;
                    --text: #e6edf3;
                    --border: #30363d;
                    --code-bg: #161b22;
                    --accent: #f07144;
                    --quote: #8b949e;
                }
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
            }
            code {
                font-family: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, monospace;
                font-size: 85%;
                background-color: var(--code-bg);
                padding: .2em .4em;
                border-radius: 4px;
            }
            pre code { background-color: transparent; padding: 0; }
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
            img { max-width: 100%; box-sizing: content-box; }
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

public struct RemoteScrollView<Content: View>: View {
    @ObservedObject var state = SharedInspectorState.shared
    let content: Content
    
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    public var body: some View {
        ScrollView {
            content
        }
    }
}

public struct InspectorView: View {
    @ObservedObject var state = SharedInspectorState.shared
    @State private var renderMode: Int = 0 // 0 = Rendered, 1 = Raw Source
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 8) {
                Image(systemName: "display.2")
                    .foregroundColor(Color(red: 0.91, green: 0.33, blue: 0.13))
                    .font(.system(size: 14))
                
                Text(state.metadata?.name ?? "No Selection")
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)
                
                // Toggle between Rendered & Raw Source for Markdown / HTML
                if state.contentType == .markdown || state.contentType == .html {
                    Picker("", selection: $renderMode) {
                        Text("👁 Rendered").tag(0)
                        Text("💻 Source").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 170)
                    .padding(.leading, 8)
                }
                
                Spacer()
                
                // Jump to Main Window Button
                Button(action: {
                    InspectorWindowController.shared.warpMouseToMainWindow()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "cursorarrow.motionlines")
                        Text("Jump to Browser (Cmd+\\)")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help("Teleport cursor and focus back to main Flashbrowse window (Cmd+\\)")
                
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
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(4)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
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
    }
    
    @ViewBuilder
    private func previewContainer(meta: ExtendedFileMetadata) -> some View {
        switch state.contentType {
        case .image:
            if let img = state.previewImage {
                ScrollView([.horizontal, .vertical]) {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(16)
                }
                .background(Color(nsColor: .textBackgroundColor))
            }
            
        case .html:
            if renderMode == 0, let url = state.currentURL {
                WebViewRenderer(url: url)
            } else if let text = state.textContent {
                codeViewer(text: text)
            }
            
        case .markdown:
            if renderMode == 0, let text = state.textContent {
                let html = MarkdownRenderer.wrapInGitHubStyleHTML(markdown: text)
                WebViewRenderer(htmlContent: html, baseURL: state.currentURL?.deletingLastPathComponent())
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
            .background(Color(nsColor: .textBackgroundColor))
            
        case .generic:
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
            .background(Color(nsColor: .textBackgroundColor))
        }
    }
    
    @ViewBuilder
    private func codeViewer(text: String) -> some View {
        ScrollView {
            Text(text)
                .font(.system(size: 12, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .textSelection(.enabled)
        }
        .background(Color(nsColor: .textBackgroundColor))
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
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                .cornerRadius(8)
                
                Text("LOCATION")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(meta.path)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
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
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                .cornerRadius(8)
            }
            .padding(14)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "hand.point.up.left.and.text")
                .font(.system(size: 44))
                .foregroundColor(.secondary.opacity(0.4))
            Text("Hover or select any file in Flashbrowse")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            Text("Live Markdown, HTML, images, and code preview will render here.")
                .font(.system(size: 12))
                .foregroundColor(.secondary.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
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
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }
}

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
                contentRect: NSRect(x: 100, y: 100, width: 750, height: 550),
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
    
    // MARK: - Mouse Warp / Teleportation between screens
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
