#!/bin/bash
# Build build/TileAll.app, signed with your Developer ID if you have one (ad-hoc otherwise).
#
#   scripts/build-app.sh [version]
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=${1:-1.0.0}
swift build -c release
APP="build/TileAll.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/TileAll "$APP/Contents/MacOS/TileAll"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>com.cadenburleson.tileall</string>
    <key>CFBundleName</key><string>Tile All</string>
    <key>CFBundleExecutable</key><string>TileAll</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning | awk -F'"' '/Developer ID Application/ {print $2; exit}')}"
if [ -n "$IDENTITY" ]; then
    codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
else
    codesign --force --sign - "$APP"
fi
echo "Built $APP (signed: ${IDENTITY:-ad-hoc})"
