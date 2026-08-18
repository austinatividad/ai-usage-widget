#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

echo "Building release binary..."
swift build -c release

APP_NAME="tacho.app"
BUILD_DIR="$DIR/.build/arm64-apple-macosx/release"
APP_BUNDLE="$DIR/$APP_NAME"

echo "Creating App Bundle at $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/tacho" "$APP_BUNDLE/Contents/MacOS/tacho"

# Copy resource bundle if it exists
if [ -d "$BUILD_DIR/tacho_tacho.bundle" ]; then
    cp -R "$BUILD_DIR/tacho_tacho.bundle" "$APP_BUNDLE/Contents/Resources/"
elif [ -d "$BUILD_DIR/AIUsageWidget_AIUsageWidget.bundle" ]; then
    cp -R "$BUILD_DIR/AIUsageWidget_AIUsageWidget.bundle" "$APP_BUNDLE/Contents/Resources/"
fi

# Info.plist
cat <<EOF > "$APP_BUNDLE/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>tacho</string>
    <key>CFBundleIdentifier</key>
    <string>com.ity.tacho</string>
    <key>CFBundleName</key>
    <string>tacho</string>
    <key>CFBundleDisplayName</key>
    <string>tacho</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>LSUIElement</key>
    <string>1</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

chmod +x "$APP_BUNDLE/Contents/MacOS/tacho"

echo "Signing application bundle with stable identifier..."
codesign --force --deep --sign - --identifier "com.ity.tacho" "$APP_BUNDLE"

echo "✅ $APP_NAME successfully created and signed at $APP_BUNDLE"
