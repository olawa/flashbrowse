# ⚡ Flashbrowse

A blazing fast, keyboard-driven native macOS file browser and command center built with Swift 6, AppKit, SwiftUI, and WebKit. Designed for power users, developers, and bioinformaticians who demand instant navigation, multi-screen workflows, and zero bloat.

---

## ✨ Features

- **⚡ Blazing Fast Native Architecture**: Zero Electron, ~2.2 MB binary size, deterministic natural alphanumeric sorting with folders always on top.
- **🧭 Interactive Breadcrumb Path Bar**: 1-click ancestor navigation, `Cmd+L` direct path typing, local and recursive subfolder search.
- **🖱️ Hover-to-Select & Single-Click-to-Open**: Glides across hundreds of files at 120 Hz with 0 ms selection latency.
- **🤏 Trackpad Pinch Gestures**: Pinch-in to navigate up to parent folder; pinch-out to open/drill down.
- **🖥️ Multi-Monitor Detached Inspector (`Cmd+Option+I`)**: Live synchronized preview for secondary displays with real-time **Markdown** and **HTML** rendering (via WebKit), syntax-highlighted code, image viewer, and POSIX metadata.
- **🔭 Remote Scrolling (`Cmd + Scroll` / `Option + Up/Down`)**: Scroll documents on the external screen directly from the file list without moving your cursor.
- **🖱️ Cursor Teleportation (`Cmd + <`)**: Warp mouse cursor between primary and secondary screens instantly (optimized for Swedish & Nordic layouts).
- **🗂️ File Type Indexes**: Built-in instant split-view indexes for **BAM/SAM**, **VCF/BCF**, **FASTQ/FQ**, **Annotations (GTF/BED)**, **Sample Sheets/TSV**, **Source Code**, and **Markdown**.
- **💻 Integrated Terminal Drawer (`Cmd + J`)**: VS Code-style bottom-docked zsh terminal with automatic `cd` synchronization when browsing folders.
- **🪟 Customizable Workspaces (`Cmd + 1..4` & `Cmd + Option + 1..4`)**:
  - `Cmd + 1`: Standard Clean Browser
  - `Cmd + 2`: Dual-Screen Studio (Inspector open)
  - `Cmd + 3`: Developer Focus (Terminal drawer open)
  - `Cmd + 4`: Classic Commander (Midnight Blue Norton Commander dual-pane)
  - `Cmd + Option + 1..4`: Save current layout to custom workspace slot.
- **🔍 Spotlight Command Palette (`Cmd + K` / `Cmd + P`)**: Floating fuzzy-search for fast keyboard navigation and commands.
- **📋 Paste Clipboard as File (`Cmd + V`)**: Direct clipboard screenshots/text snippets saved as timestamped files in active directory.
- **📊 Fixed-Scale Large File Indicator**: Visual size bar for storage consumers (≥ 50 MB, 1 GB = 100%).
- **🏷️ Live Git Branch & Status**: Non-intrusive status bar indicator (`⎇ main (clean)`).
- **✏️ Batch Rename Tool (`Cmd + Shift + R`)**: Live-diff pattern replacement, prefix/suffix, case change, and sequence numbering.

---

## 🚀 Building & Running

### Build Native App Bundle:

```bash
cd /Users/olwal516/dev/projects/flashbrowse
./build_app.sh
```

### Launch:

```bash
open Flashbrowse.app
```

---

## ⌨️ Keyboard Shortcuts Reference

| Shortcut | Action |
| :--- | :--- |
| **`Cmd + 1..4`** | Switch to Workspace Preset 1..4 |
| **`Cmd + Option + 1..4`** | Save Current Layout to Preset 1..4 |
| **`Cmd + K` / `Cmd + P`** | Open Command Palette |
| **`Cmd + J`** | Toggle Integrated Terminal Drawer |
| **`Cmd + <`** | Jump Mouse Cursor between Primary & External Screen |
| **`Cmd + Option + I`** | Open / Close Multi-Monitor Live Inspector |
| **`Cmd + Scroll`** | Remote Scroll Inspector Document from File List |
| **`Cmd + V`** | Paste Clipboard Directly as New File |
| **`Cmd + Shift + R`** | Open Batch Rename Tool |
| **`Cmd + D` / `F3`** | Toggle Dual-Pane Split View |
| **`Cmd + Shift + .`** | Toggle Hidden Dotfiles |
| **`Cmd + L`** | Jump to Path Input Bar |
| **`Space`** | macOS Quick Look Preview |
| **`Return`** | Open File or Drill into Folder |

---

## 📄 License

MIT License.
