#!/bin/bash
# Build MacBroom and install to /Applications
set -e

cd "$(dirname "$0")"

APP="/Applications/MacBroom.app"
RESOURCES="$APP/Contents/Resources"
ASSETS="Sources/MacBroom/Assets"

echo "🔨 Building MacBroom (Release)..."
swift build -c release

BINARY=".build/arm64-apple-macosx/release/MacBroom"

if [ ! -d "$APP" ]; then
    echo "❌ $APP not found. Please install MacBroom first."
    exit 1
fi

echo "📦 Installing binary..."
cp "$BINARY" "$APP/Contents/MacOS/MacBroom"

echo "🔧 Adding Frameworks rpath..."
if ! otool -l "$APP/Contents/MacOS/MacBroom" | grep -q "@loader_path/../Frameworks"; then
    install_name_tool -add_rpath @loader_path/../Frameworks "$APP/Contents/MacOS/MacBroom"
fi

echo "📂 Copying resources..."
cp "$ASSETS/MenuBarIcon.png" "$RESOURCES/" 2>/dev/null || true
cp "$ASSETS/Logo.png" "$RESOURCES/" 2>/dev/null || true
cp "$ASSETS/AppIcon.png" "$RESOURCES/" 2>/dev/null || true

# Copy Info.plist (contains version number)
cp "$ASSETS/Info.plist" "$APP/Contents/" 2>/dev/null || true

echo "🔏 Re-signing..."
codesign --force --deep --sign - "$APP"

echo "✅ Done! Run 'open $APP' to launch."
