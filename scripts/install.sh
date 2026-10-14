#!/bin/bash
# Build TileAll.app, install it to /Applications and launch it. Signing with a stable
# identity keeps the Accessibility permission across rebuilds.
set -euo pipefail
cd "$(dirname "$0")/.."

scripts/build-app.sh "$@"
pkill -x TileAll 2>/dev/null || true
rm -rf /Applications/TileAll.app
cp -R build/TileAll.app /Applications/
open /Applications/TileAll.app
echo "Installed /Applications/TileAll.app"
