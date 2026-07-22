#!/bin/bash
# Builds Switch Claude.app and packages it into a drag-to-Applications DMG.
set -euo pipefail
cd "$(dirname "$0")"

./build-app.sh

STAGING=".build/dmg-staging"
rm -rf "$STAGING" SwitchClaude.dmg
mkdir -p "$STAGING"
cp -R "Switch Claude.app" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create -volname "Switch Claude" -srcfolder "$STAGING" -ov -format UDZO -quiet SwitchClaude.dmg
rm -rf "$STAGING"
echo "Built: $PWD/SwitchClaude.dmg"
