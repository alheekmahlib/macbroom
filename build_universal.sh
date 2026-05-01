#!/bin/bash
# Build MacBroom Universal Binary (arm64 + x86_64) and install to /Applications
set -e

cd "$(dirname "$0")"

APP="/Applications/MacBroom.app"
RESOURCES="$APP/Contents/Resources"
ASSETS="Sources/MacBroom/Assets"

echo "🔨 Building MacBroom for arm64..."
swift build -c release --arch arm64 2>&1 | grep -E "error:|Build complete"

echo "🔨 Building MacBroom for x86_64..."
swift build -c release --arch x86_64 2>&1 | grep -E "error:|Build complete"

echo "🔗 Creating universal binary..."
mkdir -p .build/universal-release
lipo -create \
  .build/arm64-apple-macosx/release/MacBroom \
  .build/x86_64-apple-macosx/release/MacBroom \
  -output .build/universal-release/MacBroom

echo "📦 Installing universal binary..."
cp .build/universal-release/MacBroom "$APP/Contents/MacOS/MacBroom"

echo "🔧 Adding Frameworks rpath..."
if ! otool -l "$APP/Contents/MacOS/MacBroom" | grep -q "@loader_path/../Frameworks"; then
    install_name_tool -add_rpath @loader_path/../Frameworks "$APP/Contents/MacOS/MacBroom"
fi

echo "📂 Copying resources..."
cp "$ASSETS/MenuBarIcon.png" "$RESOURCES/" 2>/dev/null || true
cp "$ASSETS/Logo.png" "$RESOURCES/" 2>/dev/null || true
cp "$ASSETS/AppIcon.png" "$RESOURCES/" 2>/dev/null || true
cp "$ASSETS/AppIcon.icns" "$RESOURCES/" 2>/dev/null || true

# Copy Info.plist (contains version number)
cp "$ASSETS/Info.plist" "$APP/Contents/" 2>/dev/null || true

# Remove macOS resource fork files that break codesign
find "$APP" -name "._*" -delete 2>/dev/null

echo "🔏 Re-signing (ad-hoc for local)..."
# Remove stale signatures
rm -rf "$APP/Contents/_CodeSignature" "$APP/Contents/CodeResources" 2>/dev/null
rm -rf "$APP/Contents/Frameworks/Sparkle.framework/Versions/B/_CodeSignature" 2>/dev/null

codesign --force --deep --sign - "$APP"

echo "✅ Done! Run 'open $APP' to launch."
