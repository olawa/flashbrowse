#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "⚡ Compiling Flashbrowse (Universal 2: Apple Silicon + Intel)..."
mkdir -p cache_arm64 cache_x86_64

echo "  -> Compiling arm64 (Apple Silicon)..."
xcrun swiftc -O -target arm64-apple-macos14.0 -module-cache-path ./cache_arm64 \
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
    -o Flashbrowse_arm64

echo "  -> Compiling x86_64 (Intel)..."
xcrun swiftc -O -target x86_64-apple-macos14.0 -module-cache-path ./cache_x86_64 \
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
    -o Flashbrowse_x86_64

echo "🔗 Merging into Universal 2 binary with lipo..."
lipo -create -output Flashbrowse Flashbrowse_arm64 Flashbrowse_x86_64
rm -f Flashbrowse_arm64 Flashbrowse_x86_64

echo "📦 Packaging Flashbrowse.app..."
rm -rf Flashbrowse.app
mkdir -p Flashbrowse.app/Contents/MacOS
mkdir -p Flashbrowse.app/Contents/Resources

cp Flashbrowse Flashbrowse.app/Contents/MacOS/
cp Info.plist Flashbrowse.app/Contents/

chmod +x Flashbrowse.app/Contents/MacOS/Flashbrowse

echo "✍️ Ad-hoc codesigning Flashbrowse.app..."
codesign --force --deep --sign - Flashbrowse.app

echo "🚀 Flashbrowse.app ready (Universal 2: Apple Silicon + Intel)!"
file Flashbrowse.app/Contents/MacOS/Flashbrowse
