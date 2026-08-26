import SwiftUI

public enum RenameMode: String, CaseIterable, Identifiable {
    case findReplace = "Find & Replace"
    case format = "Add Prefix / Suffix"
    case sequence = "Numbering Sequence"
    case textCase = "Change Case"
    
    public var id: String { rawValue }
}

public enum TextCaseMode: String, CaseIterable, Identifiable {
    case lowercase = "lowercase"
    case uppercase = "UPPERCASE"
    case capitalized = "Capitalized Words"
    
    public var id: String { rawValue }
}

public struct BatchRenameItem: Identifiable {
    public var id: URL { originalURL }
    public let originalURL: URL
    public let originalName: String
    public let newName: String
    public var isChanged: Bool { originalName != newName }
}

public struct BatchRenameView: View {
    let items: [FileItem]
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var mode: RenameMode = .findReplace
    @State private var findText: String = ""
    @State private var replaceText: String = ""
    @State private var prefixText: String = ""
    @State private var suffixText: String = ""
    @State private var seqPrefix: String = "file_"
    @State private var seqStart: Int = 1
    @State private var seqPadding: Int = 3
    @State private var caseMode: TextCaseMode = .lowercase
    @State private var applyToExtension: Bool = false
    
    public init(items: [FileItem], onComplete: @escaping () -> Void) {
        self.items = items
        self.onComplete = onComplete
    }
    
    private var previewItems: [BatchRenameItem] {
        items.map { item in
            let origName = item.name
            let ext = item.url.pathExtension
            let nameWithoutExt = (ext.isEmpty || item.isDirectory) ? origName : (origName as NSString).deletingPathExtension
            var computedNameWithoutExt = nameWithoutExt
            var computedExt = ext
            
            switch mode {
            case .findReplace:
                if !findText.isEmpty {
                    if applyToExtension && !ext.isEmpty {
                        let full = origName.replacingOccurrences(of: findText, with: replaceText)
                        return BatchRenameItem(originalURL: item.url, originalName: origName, newName: full)
                    } else {
                        computedNameWithoutExt = nameWithoutExt.replacingOccurrences(of: findText, with: replaceText)
                    }
                }
            case .format:
                computedNameWithoutExt = "\(prefixText)\(nameWithoutExt)\(suffixText)"
            case .sequence:
                if let idx = items.firstIndex(where: { $0.url == item.url }) {
                    let num = seqStart + idx
                    let paddedNum = String(format: "%0\(seqPadding)d", num)
                    computedNameWithoutExt = "\(seqPrefix)\(paddedNum)"
                }
            case .textCase:
                switch caseMode {
                case .lowercase:
                    computedNameWithoutExt = nameWithoutExt.lowercased()
                    if applyToExtension { computedExt = ext.lowercased() }
                case .uppercase:
                    computedNameWithoutExt = nameWithoutExt.uppercased()
                    if applyToExtension { computedExt = ext.uppercased() }
                case .capitalized:
                    computedNameWithoutExt = nameWithoutExt.capitalized
                }
            }
            
            let finalName: String
            if ext.isEmpty || item.isDirectory {
                finalName = computedNameWithoutExt
            } else {
                finalName = computedExt.isEmpty ? computedNameWithoutExt : "\(computedNameWithoutExt).\(computedExt)"
            }
            
            return BatchRenameItem(originalURL: item.url, originalName: origName, newName: finalName)
        }
    }
    
    private var changeCount: Int {
        previewItems.filter { $0.isChanged }.count
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "pencil.and.list.clipboard")
                    .foregroundColor(Color.flashbrowseAccent)
                    .font(.system(size: 16))
                Text("Batch Rename (\(items.count) items)")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                
                Picker("Mode", selection: $mode) {
                    ForEach(RenameMode.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 380)
            }
            .padding(14)
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            // Parameters Controls
            VStack(spacing: 10) {
                switch mode {
                case .findReplace:
                    HStack(spacing: 12) {
                        HStack {
                            Text("Find:")
                                .font(.system(size: 12, weight: .medium))
                                .frame(width: 40, alignment: .trailing)
                            TextField("Text to find...", text: $findText)
                                .textFieldStyle(.roundedBorder)
                        }
                        HStack {
                            Text("Replace:")
                                .font(.system(size: 12, weight: .medium))
                                .frame(width: 55, alignment: .trailing)
                            TextField("Replacement...", text: $replaceText)
                                .textFieldStyle(.roundedBorder)
                        }
                        Toggle("Include Ext", isOn: $applyToExtension)
                            .font(.system(size: 11))
                    }
                case .format:
                    HStack(spacing: 12) {
                        HStack {
                            Text("Prefix:")
                                .font(.system(size: 12, weight: .medium))
                                .frame(width: 45, alignment: .trailing)
                            TextField("Prefix text...", text: $prefixText)
                                .textFieldStyle(.roundedBorder)
                        }
                        HStack {
                            Text("Suffix:")
                                .font(.system(size: 12, weight: .medium))
                                .frame(width: 45, alignment: .trailing)
                            TextField("Suffix text...", text: $suffixText)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                case .sequence:
                    HStack(spacing: 12) {
                        HStack {
                            Text("Prefix:")
                                .font(.system(size: 12, weight: .medium))
                                .frame(width: 45, alignment: .trailing)
                            TextField("Prefix (e.g. img_)", text: $seqPrefix)
                                .textFieldStyle(.roundedBorder)
                        }
                        HStack {
                            Text("Start #:")
                                .font(.system(size: 12, weight: .medium))
                            TextField("1", value: $seqStart, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 50)
                        }
                        HStack {
                            Text("Digits:")
                                .font(.system(size: 12, weight: .medium))
                            Picker("", selection: $seqPadding) {
                                Text("1 (1, 2, 3)").tag(1)
                                Text("2 (01, 02)").tag(2)
                                Text("3 (001, 002)").tag(3)
                                Text("4 (0001)").tag(4)
                            }
                            .frame(width: 120)
                        }
                    }
                case .textCase:
                    HStack(spacing: 16) {
                        Picker("Case Conversion:", selection: $caseMode) {
                            ForEach(TextCaseMode.allCases) { c in
                                Text(c.rawValue).tag(c)
                            }
                        }
                        .frame(width: 280)
                        
                        Toggle("Include Extension", isOn: $applyToExtension)
                            .font(.system(size: 11))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            
            Divider()
            
            // Live Diff Preview Table
            VStack(spacing: 0) {
                HStack {
                    Text("ORIGINAL NAME")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .frame(width: 30)
                    
                    Text("NEW NAME (LIVE PREVIEW)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlBackgroundColor))
                
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(previewItems) { item in
                            HStack {
                                Text(item.originalName)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .lineLimit(1)
                                
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 10))
                                    .foregroundColor(item.isChanged ? Color.flashbrowseAccent : .secondary.opacity(0.4))
                                    .frame(width: 30)
                                
                                HStack(spacing: 6) {
                                    Text(item.newName)
                                        .font(.system(size: 12, weight: item.isChanged ? .semibold : .regular))
                                        .foregroundColor(item.isChanged ? .primary : .secondary)
                                        .lineLimit(1)
                                    
                                    if item.isChanged {
                                        Text("MODIFIED")
                                            .font(.system(size: 9, weight: .bold))
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.flashbrowseAccent.opacity(0.15))
                                            .foregroundColor(Color.flashbrowseAccent)
                                            .cornerRadius(3)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 4)
                            .background(item.isChanged ? Color.flashbrowseAccent.opacity(0.06) : Color.clear)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .background(Color(nsColor: .textBackgroundColor))
            
            Divider()
            
            // Bottom Action Bar
            HStack {
                Text("\(changeCount) of \(items.count) files will be renamed")
                    .font(.system(size: 12))
                    .foregroundColor(changeCount > 0 ? .primary : .secondary)
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Rename \(changeCount) Files") {
                    executeRename()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.flashbrowseAccent)
                .disabled(changeCount == 0)
                .keyboardShortcut(.defaultAction)
            }
            .padding(14)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 620, idealWidth: 700, minHeight: 450, idealHeight: 520)
    }
    
    private func executeRename() {
        let fm = FileManager.default
        for item in previewItems where item.isChanged {
            let targetURL = item.originalURL.deletingLastPathComponent().appendingPathComponent(item.newName)
            try? fm.moveItem(at: item.originalURL, to: targetURL)
        }
        onComplete()
        dismiss()
    }
}
