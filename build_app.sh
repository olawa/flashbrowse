#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "⚡ Compiling Flashbrowse 3.0 (Swift 6 + AppKit + WebKit)..."
mkdir -p cache
xcrun swiftc -O -module-cache-path ./cache \
    Sources/Models/*.swift \
    Sources/Services/*.swift \
    Sources/Views/*.swift \
    Sources/App.swift \
    -framework Cocoa \
    -framework SwiftUI \
    -framework Quartz \
    -framework QuickLookUI \
    -framework WebKit \
    -framework PDFKit \
    -o Flashbrowse

echo "📦 Packaging Flashbrowse.app..."
rm -rf Flashbrowse.app
mkdir -p Flashbrowse.app/Contents/MacOS
mkdir -p Flashbrowse.app/Contents/Resources

cp Flashbrowse Flashbrowse.app/Contents/MacOS/
cp Info.plist Flashbrowse.app/Contents/

chmod +x Flashbrowse.app/Contents/MacOS/Flashbrowse

echo "✍️ Ad-hoc codesigning Flashbrowse.app..."
codesign --force --deep --sign - Flashbrowse.app

echo "🚀 Flashbrowse.app ready!"
echo "   Run: open Flashbrowse.app"
