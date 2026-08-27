import SwiftUI
import AppKit
import WebKit

// MARK: - VS Code Syntax Highlighting Renderer
public struct CodeSyntaxRenderer {
    
    public struct LanguageMeta {
        public let name: String
        public let emoji: String
        public let hljsLang: String
    }
    
    public static func detectLanguage(filename: String, code: String) -> LanguageMeta {
        let lower = filename.lowercased()
        let ext = (filename as NSString).pathExtension.lowercased()
        
        // Exact filename matching
        if lower == "makefile" || lower.hasPrefix("makefile.") {
            return LanguageMeta(name: "Makefile", emoji: "🔨", hljsLang: "makefile")
        }
        if lower == "dockerfile" || lower.hasPrefix("dockerfile.") {
            return LanguageMeta(name: "Dockerfile", emoji: "🐳", hljsLang: "dockerfile")
        }
        if lower == "snakefile" || lower.hasSuffix(".smk") {
            return LanguageMeta(name: "Snakemake", emoji: "🐍", hljsLang: "python")
        }
        if lower == "gemfile" || lower == "rakefile" {
            return LanguageMeta(name: "Ruby", emoji: "💎", hljsLang: "ruby")
        }
        if lower.hasPrefix(".bash") || lower.hasPrefix(".zsh") || lower == ".profile" {
            return LanguageMeta(name: "Shell Script", emoji: "🐚", hljsLang: "bash")
        }
        if lower == ".env" || lower.hasPrefix(".env.") {
            return LanguageMeta(name: "Environment Config", emoji: "⚙️", hljsLang: "ini")
        }
        if lower == ".gitignore" || lower == ".dockerignore" {
            return LanguageMeta(name: "Ignore Config", emoji: "🚫", hljsLang: "plaintext")
        }
        
        // Extension mapping
        switch ext {
        case "py", "pyw", "ipynb":
            return LanguageMeta(name: "Python", emoji: "🐍", hljsLang: "python")
        case "sh", "bash", "zsh", "fish", "command":
            return LanguageMeta(name: "Shell", emoji: "🐚", hljsLang: "bash")
        case "r", "rmd":
            return LanguageMeta(name: "R", emoji: "📊", hljsLang: "r")
        case "swift":
            return LanguageMeta(name: "Swift", emoji: "⚡", hljsLang: "swift")
        case "c", "h":
            return LanguageMeta(name: "C", emoji: "🇨", hljsLang: "c")
        case "cpp", "hpp", "cc", "cxx", "c++", "h++":
            return LanguageMeta(name: "C++", emoji: "⚙️", hljsLang: "cpp")
        case "rs":
            return LanguageMeta(name: "Rust", emoji: "🦀", hljsLang: "rust")
        case "go":
            return LanguageMeta(name: "Go", emoji: "🐹", hljsLang: "go")
        case "js", "mjs", "cjs":
            return LanguageMeta(name: "JavaScript", emoji: "🟨", hljsLang: "javascript")
        case "jsx":
            return LanguageMeta(name: "React JSX", emoji: "⚛️", hljsLang: "javascript")
        case "ts":
            return LanguageMeta(name: "TypeScript", emoji: "🟦", hljsLang: "typescript")
        case "tsx":
            return LanguageMeta(name: "React TSX", emoji: "⚛️", hljsLang: "typescript")
        case "json", "jsonl", "geojson":
            return LanguageMeta(name: "JSON", emoji: "📦", hljsLang: "json")
        case "yaml", "yml":
            return LanguageMeta(name: "YAML", emoji: "📄", hljsLang: "yaml")
        case "toml":
            return LanguageMeta(name: "TOML", emoji: "⚙️", hljsLang: "ini")
        case "ini", "cfg", "conf", "config", "properties":
            return LanguageMeta(name: "Config", emoji: "⚙️", hljsLang: "ini")
        case "sql":
            return LanguageMeta(name: "SQL", emoji: "🗄️", hljsLang: "sql")
        case "html", "htm", "xhtml":
            return LanguageMeta(name: "HTML", emoji: "🌐", hljsLang: "xml")
        case "xml", "svg", "plist", "xsd", "xsl", "kml":
            return LanguageMeta(name: "XML", emoji: "📑", hljsLang: "xml")
        case "css":
            return LanguageMeta(name: "CSS", emoji: "🎨", hljsLang: "css")
        case "scss", "sass", "less":
            return LanguageMeta(name: "SCSS/Sass", emoji: "🎨", hljsLang: "scss")
        case "md", "markdown", "mdown":
            return LanguageMeta(name: "Markdown", emoji: "📝", hljsLang: "markdown")
        case "java":
            return LanguageMeta(name: "Java", emoji: "☕", hljsLang: "java")
        case "kt", "kts":
            return LanguageMeta(name: "Kotlin", emoji: "🟣", hljsLang: "kotlin")
        case "lua":
            return LanguageMeta(name: "Lua", emoji: "🌙", hljsLang: "lua")
        case "pl", "pm":
            return LanguageMeta(name: "Perl", emoji: "🐪", hljsLang: "perl")
        case "rb":
            return LanguageMeta(name: "Ruby", emoji: "💎", hljsLang: "ruby")
        case "php":
            return LanguageMeta(name: "PHP", emoji: "🐘", hljsLang: "php")
        case "fasta", "fa", "fna", "faa":
            return LanguageMeta(name: "FASTA Sequence", emoji: "🧬", hljsLang: "plaintext")
        case "bed":
            return LanguageMeta(name: "BED Genomic Regions", emoji: "🧬", hljsLang: "plaintext")
        case "gtf", "gff", "gff3":
            return LanguageMeta(name: "GTF/GFF Annotation", emoji: "🧬", hljsLang: "plaintext")
        case "vcf":
            return LanguageMeta(name: "VCF Variants", emoji: "🧬", hljsLang: "plaintext")
        case "log":
            return LanguageMeta(name: "Log File", emoji: "📋", hljsLang: "plaintext")
        case "txt", "text":
            return LanguageMeta(name: "Text File", emoji: "📄", hljsLang: "plaintext")
        default:
            break
        }
        
        // Shebang inspection
        if code.hasPrefix("#!") {
            let firstLine = code.components(separatedBy: "\n").first?.lowercased() ?? ""
            if firstLine.contains("python") {
                return LanguageMeta(name: "Python", emoji: "🐍", hljsLang: "python")
            }
            if firstLine.contains("bash") || firstLine.contains("sh") || firstLine.contains("zsh") {
                return LanguageMeta(name: "Shell", emoji: "🐚", hljsLang: "bash")
            }
            if firstLine.contains("rscript") {
                return LanguageMeta(name: "R", emoji: "📊", hljsLang: "r")
            }
            if firstLine.contains("node") {
                return LanguageMeta(name: "JavaScript", emoji: "🟨", hljsLang: "javascript")
            }
            if firstLine.contains("perl") {
                return LanguageMeta(name: "Perl", emoji: "🐪", hljsLang: "perl")
            }
            if firstLine.contains("ruby") {
                return LanguageMeta(name: "Ruby", emoji: "💎", hljsLang: "ruby")
            }
        }
        
        return LanguageMeta(name: ext.isEmpty ? "Plain Text" : ext.uppercased(), emoji: "📄", hljsLang: "plaintext")
    }
    
    public static func renderHTML(code: String, filename: String, isDark: Bool = true) -> String {
        let lang = detectLanguage(filename: filename, code: code)
        let lines = code.components(separatedBy: "\n")
        let lineCount = lines.count
        
        // HTML encode code to prevent XSS / broken markup
        let escapedCode = code
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
        
        let byteCount = code.utf8.count
        let sizeFormatted: String
        if byteCount < 1024 {
            sizeFormatted = "\(byteCount) B"
        } else if byteCount < 1024 * 1024 {
            sizeFormatted = String(format: "%.1f KB", Double(byteCount) / 1024.0)
        } else {
            sizeFormatted = String(format: "%.2f MB", Double(byteCount) / (1024.0 * 1024.0))
        }
        
        // Build line number string
        var lineNumbersHTML = ""
        for i in 1...max(1, lineCount) {
            lineNumbersHTML += "<span>\(i)</span>\n"
        }
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(filename)</title>
        <!-- Highlight.js for 190+ Language Parsing with VS Code Themes -->
        <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/\(isDark ? "vs2015" : "vs").min.css">
        <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>
        <style>
            :root {
                --bg: \(isDark ? "#1e1e1e" : "#ffffff");
                --fg: \(isDark ? "#d4d4d4" : "#1f2328");
                --gutter-bg: \(isDark ? "#1e1e1e" : "#f8f9fa");
                --gutter-fg: \(isDark ? "#858585" : "#6e7781");
                --gutter-border: \(isDark ? "#2d2d2d" : "#e1e4e8");
                --header-bg: \(isDark ? "#252526" : "#f6f8fa");
                --header-border: \(isDark ? "#333333" : "#d0d7de");
                --header-fg: \(isDark ? "#cccccc" : "#24292f");
                --badge-bg: \(isDark ? "#333a42" : "#eaeef2");
                --badge-fg: \(isDark ? "#569cd6" : "#0969da");
                --btn-bg: \(isDark ? "#333333" : "#ffffff");
                --btn-hover: \(isDark ? "#444444" : "#f3f4f6");
                --btn-border: \(isDark ? "#444444" : "#d0d7de");
                --btn-fg: \(isDark ? "#cccccc" : "#24292f");
                --selection-bg: \(isDark ? "#264f78" : "#add6ff");
                --row-hover: \(isDark ? "rgba(255, 255, 255, 0.04)" : "rgba(0, 0, 0, 0.03)");
            }

            * { box-sizing: border-box; }
            ::selection { background: var(--selection-bg); }

            html, body {
                margin: 0;
                padding: 0;
                background-color: var(--bg);
                color: var(--fg);
                font-family: ui-monospace, "SF Mono", Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
                font-size: 12.5px;
                line-height: 20px;
                -webkit-font-smoothing: antialiased;
                height: 100%;
            }

            /* Sticky VS Code Header */
            .sticky-header {
                position: sticky;
                top: 0;
                left: 0;
                right: 0;
                z-index: 100;
                display: flex;
                align-items: center;
                justify-content: space-between;
                padding: 6px 12px;
                background-color: var(--header-bg);
                border-bottom: 1px solid var(--header-border);
                font-size: 11px;
                user-select: none;
            }

            .file-meta {
                display: flex;
                align-items: center;
                gap: 8px;
            }

            .lang-pill {
                display: inline-flex;
                align-items: center;
                gap: 4px;
                background: var(--badge-bg);
                color: var(--badge-fg);
                padding: 2px 7px;
                border-radius: 4px;
                font-size: 11px;
                font-weight: 600;
            }

            .stat-pill {
                color: #888888;
                font-size: 11px;
            }

            .header-actions {
                display: flex;
                align-items: center;
                gap: 6px;
            }

            .action-btn {
                display: inline-flex;
                align-items: center;
                gap: 4px;
                background: var(--btn-bg);
                color: var(--btn-fg);
                border: 1px solid var(--btn-border);
                border-radius: 4px;
                padding: 3px 8px;
                font-size: 11px;
                cursor: pointer;
                font-family: inherit;
                transition: background-color 0.15s ease;
            }
            .action-btn:hover {
                background: var(--btn-hover);
                color: \(isDark ? "#ffffff" : "#000000");
            }

            /* Code Area with Synchronized Line Numbers */
            .editor-container {
                display: flex;
                min-width: 100%;
                width: max-content;
            }

            .line-numbers {
                position: sticky;
                left: 0;
                z-index: 20;
                display: flex;
                flex-direction: column;
                min-width: 48px;
                padding: 12px 10px 30px 12px;
                text-align: right;
                color: var(--gutter-fg);
                background-color: var(--gutter-bg);
                border-right: 1px solid var(--gutter-border);
                user-select: none;
                font-size: 11px;
                line-height: 20px;
            }

            .code-pane {
                margin: 0;
                padding: 12px 16px 30px 14px;
                font-family: inherit;
                font-size: 12.5px;
                line-height: 20px;
                tab-size: 4;
                white-space: pre;
                overflow: visible;
                background: transparent;
                flex-grow: 1;
            }

            .code-pane code {
                font-family: inherit;
                font-size: inherit;
                line-height: inherit;
                background: transparent !important;
                padding: 0 !important;
            }

            /* Wrap mode */
            .wrap-active .editor-container {
                width: 100%;
            }
            .wrap-active .code-pane {
                white-space: pre-wrap;
                word-break: break-all;
            }

            /* Offline Token Fallback Styles (VS Code Dark+ Palette) */
            .tok-kw { color: #569cd6; font-weight: 600; }
            .tok-fn { color: #dcdcaa; }
            .tok-str { color: #ce9178; }
            .tok-num { color: #b5cea8; }
            .tok-cmt { color: #6a9955; font-style: italic; }
            .tok-typ { color: #4ec9b0; }
            .tok-dec { color: #d7ba7d; }
            .tok-var { color: #9cdcfe; }
        </style>
        </head>
        <body>
        <div class="sticky-header">
            <div class="file-meta">
                <span class="lang-pill">\(lang.emoji) \(lang.name)</span>
                <span class="stat-pill">\(lineCount) lines</span>
                <span class="stat-pill">•</span>
                <span class="stat-pill">\(sizeFormatted)</span>
            </div>
            <div class="header-actions">
                <button class="action-btn" id="wrap-btn" onclick="toggleWrap()">Wrap: Off</button>
                <button class="action-btn" id="copy-btn" onclick="copyCode()">Copy Code</button>
            </div>
        </div>

        <div class="editor-container" id="editor">
            <div class="line-numbers">\(lineNumbersHTML)</div>
            <pre class="code-pane"><code class="language-\(lang.hljsLang)" id="code-content">\(escapedCode)</code></pre>
        </div>

        <script>
            // Initialize Highlighting (Highlight.js if loaded, or fast offline tokenizer)
            function initHighlight() {
                const codeEl = document.getElementById('code-content');
                if (!codeEl) return;
                
                if (typeof hljs !== 'undefined') {
                    try {
                        hljs.highlightElement(codeEl);
                    } catch (e) {
                        applyOfflineTokenizer(codeEl, "\(lang.hljsLang)");
                    }
                } else {
                    applyOfflineTokenizer(codeEl, "\(lang.hljsLang)");
                }
            }

            // Built-in Fast Offline Tokenizer (Zero latency, works offline anywhere)
            function applyOfflineTokenizer(el, lang) {
                let txt = el.innerHTML;
                
                if (lang === 'python') {
                    // Python Comments
                    txt = txt.replace(/(#[^\\n]*)/g, '<span class="tok-cmt">$1</span>');
                    // Strings
                    txt = txt.replace(/(&quot;[^&]*&quot;|&#39;[^&]*&#39;)/g, '<span class="tok-str">$1</span>');
                    // Decorators
                    txt = txt.replace(/(@[a-zA-Z_]\\w*)/g, '<span class="tok-dec">$1</span>');
                    // Keywords
                    txt = txt.replace(/\\b(def|class|import|from|as|return|if|elif|else|while|for|in|try|except|finally|with|lambda|yield|raise|pass|break|continue|async|await|global|assert|and|or|not|is)\\b/g, '<span class="tok-kw">$1</span>');
                    // Types & Builtins
                    txt = txt.replace(/\\b(self|cls|True|False|None|print|len|range|str|int|float|list|dict|set|tuple|bool|open|type)\\b/g, '<span class="tok-typ">$1</span>');
                    // Numbers
                    txt = txt.replace(/\\b(\\d+(\\.\\d+)?)\\b/g, '<span class="tok-num">$1</span>');
                } else if (lang === 'bash' || lang === 'shell') {
                    txt = txt.replace(/(#[^\\n]*)/g, '<span class="tok-cmt">$1</span>');
                    txt = txt.replace(/(&quot;[^&]*&quot;|&#39;[^&]*&#39;)/g, '<span class="tok-str">$1</span>');
                    txt = txt.replace(/(\\b(echo|cd|ls|mkdir|rm|cp|mv|cat|grep|sed|awk|export|source|exit)\\b)/g, '<span class="tok-fn">$1</span>');
                    txt = txt.replace(/(\\b(if|then|else|elif|fi|for|while|do|done|case|esac|function)\\b)/g, '<span class="tok-kw">$1</span>');
                    txt = txt.replace(/(\\$[a-zA-Z_0-9]+|\\$\\{[^}]+\\})/g, '<span class="tok-var">$1</span>');
                } else if (lang === 'json') {
                    txt = txt.replace(/(&quot;[^&]+&quot;)(?=\\s*:)/g, '<span class="tok-var">$1</span>');
                    txt = txt.replace(/:\\s*(&quot;[^&]*&quot;)/g, ': <span class="tok-str">$1</span>');
                    txt = txt.replace(/\\b(true|false|null)\\b/g, '<span class="tok-kw">$1</span>');
                    txt = txt.replace(/\\b(\\d+(\\.\\d+)?)\\b/g, '<span class="tok-num">$1</span>');
                }
                
                el.innerHTML = txt;
            }

            let isWrapped = false;
            function toggleWrap() {
                isWrapped = !isWrapped;
                document.body.classList.toggle('wrap-active', isWrapped);
                document.getElementById('wrap-btn').innerText = isWrapped ? 'Wrap: On' : 'Wrap: Off';
            }

            function copyCode() {
                const codeEl = document.getElementById('code-content');
                if (!codeEl) return;
                const rawText = codeEl.innerText;
                navigator.clipboard.writeText(rawText).then(() => {
                    const btn = document.getElementById('copy-btn');
                    btn.innerText = '✓ Copied!';
                    setTimeout(() => { btn.innerText = 'Copy Code'; }, 1800);
                });
            }

            // Run on load
            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', initHighlight);
            } else {
                initHighlight();
            }
        </script>
        </body>
        </html>
        """
    }
}
