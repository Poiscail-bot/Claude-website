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

# Icône : générée à partir d'un symbole SF, puis convertie en .icns.
ICONSET="build/AppIcon.iconset"
rm -rf "$ICONSET" && mkdir -p "$ICONSET"
if swift scripts/make-icon.swift build/icon-1024.png; then
    for size in 16 32 128 256 512; do
        sips -z $size $size build/icon-1024.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
        double=$((size * 2))
        sips -z $double $double build/icon-1024.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
    done
    iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
else
    echo "Icône non générée, l'app utilisera l'icône par défaut."
fi

codesign --force --sign - "$APP"
echo "Application prête : $(pwd)/$APP"
echo "Pour l'installer : cp -R \"$APP\" /Applications/"
