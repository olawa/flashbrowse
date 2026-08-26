<div align="center">

# ⚡ Flashbrowse

### The blazing fast, keyboard-driven file manager & command center for macOS

[![macOS](https://img.shields.io/badge/platform-macOS%2014%2B-black?style=flat-square&logo=apple)](https://github.com/olawa/flashbrowse)
[![Swift 6](https://img.shields.io/badge/Swift-6.0-orange?style=flat-square&logo=swift)](https://swift.org)
[![Release](https://img.shields.io/github/v/release/olawa/flashbrowse?color=blue&style=flat-square)](https://github.com/olawa/flashbrowse/releases)
[![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)](LICENSE)

<br />

<!-- MAIN HERO PREVIEW / VIDEO / GIF PLACEHOLDER -->
<p align="center">
  <img src="assets/hero_preview.png" alt="Flashbrowse Hero Preview" width="850" />
</p>

*Native AppKit + SwiftUI • 0% Electron • ~2.2 MB Binary • Instant Hover Selection • Multi-Screen Studio*

<br />

[**📥 Download Latest Release (v0.1.0)**](https://github.com/olawa/flashbrowse/releases/latest) • [**✨ Features**](#-key-features) • [**⌨️ Keyboard Cheatsheet**](#️-keyboard-shortcuts) • [**🛠️ Build from Source**](#️-building-from-source)

</div>

---

## 💡 Why Flashbrowse?

macOS Finder can be frustrating: slow list sorting, lack of responsive previews, awkward multi-window sprawl, and no integration with your development terminal or external monitors. 

**Flashbrowse** was built from scratch to fix this with zero bloat and absolute speed:

| Feature | macOS Finder | ⚡ Flashbrowse |
| :--- | :--- | :--- |
| **Selection Speed** | Click to select, double click | **Instant hover-to-select (0 ms latency)** |
| **Multi-Monitor Preview** | Trapped in single window | **Detached live sync window (`Cmd+Option+I`)** |
| **Document Rendering** | Basic text QuickLook | **Full Markdown & HTML live rendering (WebKit)** |
| **Integrated Terminal** | Open separate app | **Built-in VS Code style drawer with Auto-CD (`Cmd+J`)** |
| **Bioinformatics Indexes** | Manual folder digging | **1-Click BAM, VCF, FASTQ & Sample Sheet Splitviews** |
| **Navigation** | Clunky path bar | **Ubuntu-style interactive breadcrumb pills + `Cmd+L`** |
| **Workspaces** | None | **Instant layout presets (`Cmd+1..4`) & custom saves** |
| **Binary Footprint** | System process | **Ultra-lean ~2.2 MB native Swift binary (0% Electron)** |

---

## ✨ Key Features

### 🖥️ 1. Multi-Monitor Live Inspector (`Cmd + Option + I`)
Drag the Inspector to your secondary monitor. As you hover over files on your main screen, the external display instantly renders:
- **Rich Markdown (`.md`)**: GitHub-style typography, styled code blocks, tables, and dark mode.
- **Interactive HTML (`.html`)**: Live WebKit layout with instant toggle between `[ 👁 Rendered | 💻 Source ]`.
- **Media & Source Code**: High-resolution image viewer, syntax-highlighted code, and POSIX metadata.
- **Frictionless Control**:
  - **`Cmd + <`**: Teleport your mouse cursor directly between screens.
  - **`Cmd + Scroll`**: Scroll the external document from your file list without moving the mouse!

<div align="center">
  <img src="assets/inspector_preview.png" alt="Multi-Monitor Inspector Preview" width="800" />
</div>

<br />

---

### 💻 2. Integrated Terminal Drawer (`Cmd + J`)
- Bottom-docked interactive `zsh` terminal with real-time output and history (`Up`/`Down`).
- **Auto-CD Synchronization**: Automatically switches the working directory to the folder you click on in Flashbrowse.
- Run `git`, `cargo`, `swift`, `samtools`, `python`, and your favorite command-line tools without context switching.

<div align="center">
  <img src="assets/terminal_preview.png" alt="Integrated Terminal Preview" width="800" />
</div>

<br />

---

### 🗂️ 3. Specialized File Type Indexes (Bioinformatics & Code)
A dedicated hub in the sidebar that instantly indexes and groups matching files in a split-view (directories on the left, matching files on the right):
- **🧬 BAM / SAM / CRAM Alignments** (`.bam`, `.sam`, `.cram`, `.bai`)
- **📈 VCF / BCF Variants** (`.vcf`, `.vcf.gz`, `.bcf`, `.tbi`)
- **🧬 FASTQ / FQ Reads** (`.fq`, `.fastq`, `.fq.gz`)
- **🔖 Annotations** (`.gtf`, `.gff`, `.bed`, `.bigwig`)
- **📊 Sample Sheets & Tables** (`.tsv`, `.csv`, `.tab`)
- **💻 Source Code** (`.swift`, `.rs`, `.py`, `.c`, `.sh`, `.ts`)
- **📄 Markdown & Docs** (`.md`, `.pdf`, `.txt`)

<div align="center">
  <img src="assets/indexes_preview.png" alt="File Type Indexes Preview" width="800" />
</div>

<br />

---

### 🪟 4. Customizable Workspaces & Classic Commander Mode
- **`Cmd + 1`**: *Standard Browser* (Clean, single-pane view).
- **`Cmd + 2`**: *Dual-Screen Studio* (Activates external screen inspector).
- **`Cmd + 3`**: *Developer Focus* (Spacious browser + integrated terminal drawer).
- **`Cmd + 4`**: *Classic Commander* (Dual-pane Midnight Blue theme with Norton Commander bottom function bar).
- **`Cmd + Option + 1..4`**: Save your current window setup, directories, and panel states to any preset slot.

<div align="center">
  <img src="assets/commander_preview.png" alt="Classic Commander Mode Preview" width="800" />
</div>

<br />

---

### 🔍 5. Spotlight Command Palette (`Cmd + K` / `Cmd + P`)
Press `Cmd + K` anywhere to open a clean fuzzy-search overlay:
- Jump to favorite directories and workspaces.
- Execute actions (*"Batch Rename"*, *"Toggle Terminal"*, *"Toggle Commander"*, *"Paste Clipboard as File"*).
- **0% background UI overhead**.

---

### 📋 6. Clipboard-to-File & Storage Heatmaps
- **`Cmd + V` on empty list**: Directly saves copied screenshots as `screenshot_YYYY-MM-DD.png` or copied code as `snippet_YYYY-MM-DD.txt`.
- **Fixed-Scale Large File Indicator**: Storage consumers (≥ 50 MB) show a discrete proportional bar (1 GB = 100% width) with warm highlights for gigabyte files.
- **Live Git Status**: Subtle branch indicator in the status bar (e.g., `⎇ main (clean)`).

---

## ⌨️ Keyboard Shortcuts

| Shortcut | Action |
| :--- | :--- |
| **`Cmd + 1..4`** | Switch to Workspace Preset 1..4 |
| **`Cmd + Option + 1..4`** | Save Current Layout to Preset 1..4 |
| **`Cmd + K` / `Cmd + P`** | Open Spotlight Command Palette |
| **`Cmd + J`** | Toggle Integrated Terminal Drawer |
| **`Cmd + <`** | Warp Mouse Cursor between Primary & External Screen |
| **`Cmd + Option + I`** | Open / Close Multi-Monitor Live Inspector |
| **`Cmd + Scroll`** / **`Option + Up/Down`** | Remote Scroll Inspector Document from File List |
| **`Cmd + V`** | Paste Clipboard Directly as New File |
| **`Cmd + Shift + R`** | Open Batch Rename Tool with Live Diff |
| **`Cmd + D`** / **`F3`** | Toggle Dual-Pane Split View |
| **`Cmd + Shift + .`** | Toggle Hidden Dotfiles |
| **`Cmd + L`** | Jump to Path Input Bar |
| **`Space`** | macOS Quick Look Preview |
| **`Return`** | Open File or Drill into Folder |
| **`Pinch In / Out`** | Trackpad gesture to Navigate Up / Open Folder |

---

## 📥 Installation

1. Download **`Flashbrowse-v0.1.0-macos.zip`** from [GitHub Releases](https://github.com/olawa/flashbrowse/releases/latest).
2. Unzip and drag **`Flashbrowse.app`** to your `/Applications` folder.
3. Open **Flashbrowse**!

---

## 🛠️ Building from Source

Requirements: macOS 14+, Xcode 15+ or Command Line Tools (Swift 6).

```bash
# Clone the repository
git clone https://github.com/olawa/flashbrowse.git
cd flashbrowse

# Compile native binary and package Flashbrowse.app
./build_app.sh

# Run
open Flashbrowse.app
```

---

## 📄 License

Distributed under the MIT License.
