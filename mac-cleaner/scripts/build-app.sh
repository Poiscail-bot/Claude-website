#!/bin/bash
# Compile MacNettoyeur et l'emballe dans build/MacNettoyeur.app (signature ad hoc).
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --arch arm64
BIN_DIR="$(swift build -c release --arch arm64 --show-bin-path)"

APP="build/MacNettoyeur.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/MacNettoyeur" "$APP/Contents/MacOS/MacNettoyeur"
cp Support/Info.plist "$APP/Contents/Info.plist"

codesign --force --sign - "$APP"
echo "Application prête : $(pwd)/$APP"
echo "Pour l'installer : cp -R \"$APP\" /Applications/"
