#!/bin/bash
# Build TileAll.app, sign it with a stable identity (so the Accessibility grant
# survives rebuilds), install to /Applications and launch it.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
APP="build/TileAll.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/TileAll "$APP/Contents/MacOS/TileAll"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>com.cadenburleson.tileall</string>
    <key>CFBundleName</key><string>Tile All</string>
    <key>CFBundleExecutable</key><string>TileAll</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning | grep -m1 'Developer ID Application' | sed -E 's/.*"(.*)"/\1/')}"
codesign --force --options runtime --sign "${IDENTITY:--}" "$APP"

pkill -x TileAll 2>/dev/null || true
rm -rf "/Applications/TileAll.app"
cp -R "$APP" "/Applications/"
open "/Applications/TileAll.app"
echo "Installed /Applications/TileAll.app (signed: ${IDENTITY:-ad-hoc})"
