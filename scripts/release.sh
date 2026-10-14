#!/bin/bash
# Maintainer script: publishes a GitHub release with a notarized TileAll.dmg.
#
#   scripts/release.sh 1.0.0
#
# Needs a Developer ID certificate, the asc CLI (for notarization) and gh. Run it from a
# clean, pushed checkout; the release is tagged at the current commit.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=${1:?usage: scripts/release.sh <version>}
APP=build/TileAll.app
ZIP=build/TileAll.zip
DMG=build/TileAll.dmg

if [ -n "$(git status --porcelain)" ]; then
    echo "Commit or stash your changes first." >&2
    exit 1
fi

scripts/build-app.sh "$VERSION"
ditto -c -k --keepParent "$APP" "$ZIP"
asc notarization submit --file "$ZIP" --wait
xcrun stapler staple "$APP"

# The disk image shows the app next to an Applications shortcut to drag it onto.
STAGE=$(mktemp -d)
ditto "$APP" "$STAGE/TileAll.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "Tile All" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG"
rm -rf "$STAGE"
IDENTITY=$(security find-identity -v -p codesigning | awk -F'"' '/Developer ID Application/ {print $2; exit}')
codesign --sign "$IDENTITY" --timestamp "$DMG"
asc notarization submit --file "$DMG" --wait
xcrun stapler staple "$DMG"

gh release create "v$VERSION" "$DMG" --target "$(git rev-parse HEAD)" --title "v$VERSION" --generate-notes
