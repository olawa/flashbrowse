import Foundation
import SwiftUI

public struct FileTypeIndex: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let icon: String
    public let color: Color
    public let extensions: Set<String>
    
    public init(id: String, name: String, icon: String, color: Color, extensions: Set<String>) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.extensions = extensions
    }
    
    public static let defaultPresets: [FileTypeIndex] = [
        FileTypeIndex(
            id: "bam",
            name: "BAM / SAM Alignments",
            icon: "dna",
            color: Color(red: 0.91, green: 0.33, blue: 0.13), // Ubuntu Orange
            extensions: ["bam", "sam", "cram", "bai", "crai"]
        ),
        FileTypeIndex(
            id: "vcf",
            name: "VCF / BCF Variants",
            icon: "waveform.path.ecg",
            color: Color(red: 0.85, green: 0.25, blue: 0.45),
            extensions: ["vcf", "bcf", "gz", "tbi", "csi"]
        ),
        FileTypeIndex(
            id: "fastq",
            name: "FASTQ / FQ Reads",
            icon: "text.alignleft",
            color: Color(red: 0.2, green: 0.6, blue: 0.86),
            extensions: ["fq", "fastq", "fq.gz", "fastq.gz"]
        ),
        FileTypeIndex(
            id: "annotations",
            name: "Annotations (GTF / BED)",
            icon: "bookmark.circle.fill",
            color: Color(red: 0.18, green: 0.75, blue: 0.45),
            extensions: ["gtf", "gff", "gff3", "bed", "bigwig", "bw"]
        ),
        FileTypeIndex(
            id: "samplesheets",
            name: "Sample Sheets & TSV / CSV",
            icon: "tablecells.badge.ellipsis",
            color: Color(red: 0.95, green: 0.65, blue: 0.15),
            extensions: ["tsv", "csv", "tab", "xlsx"]
        ),
        FileTypeIndex(
            id: "code",
            name: "Source Code",
            icon: "curlybraces",
            color: Color(red: 0.6, green: 0.35, blue: 0.85),
            extensions: ["swift", "rs", "py", "c", "cpp", "h", "hpp", "sh", "zsh", "go", "java", "ts", "js", "toml", "json"]
        ),
        FileTypeIndex(
            id: "markdown",
            name: "Markdown & Docs",
            icon: "doc.richtext.fill",
            color: Color(red: 0.3, green: 0.5, blue: 0.9),
            extensions: ["md", "markdown", "pdf", "txt"]
        ),
        FileTypeIndex(
            id: "images",
            name: "Images & Media",
            icon: "photo.stack.fill",
            color: Color(red: 0.95, green: 0.45, blue: 0.2),
            extensions: ["png", "jpg", "jpeg", "webp", "gif", "svg", "heic", "mp4", "mov"]
        )
    ]
}
