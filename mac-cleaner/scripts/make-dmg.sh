#!/bin/bash
# Emballe build/MacNettoyeur.app dans build/MacNettoyeur.dmg (glisser-déposer vers Applications).
set -euo pipefail
cd "$(dirname "$0")/.."

STAGE="build/dmg"
rm -rf "$STAGE" build/MacNettoyeur.dmg
mkdir -p "$STAGE"
cp -R build/MacNettoyeur.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp "Support/À lire avant d'ouvrir.txt" "$STAGE/"

hdiutil create -volname "MacNettoyeur" -srcfolder "$STAGE" -ov -format UDZO build/MacNettoyeur.dmg
echo "DMG prêt : $(pwd)/build/MacNettoyeur.dmg"
