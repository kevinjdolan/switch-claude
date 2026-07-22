#!/bin/bash
# Builds Switch Claude.app from the Swift package.
set -euo pipefail
cd "$(dirname "$0")"

APP="Switch Claude.app"

swift build -c release

# Generate the icon once (delete Support/AppIcon.icns to regenerate).
if [ ! -f Support/AppIcon.icns ]; then
    rm -rf .build/AppIcon.iconset
    swift scripts/make-icon.swift .build/AppIcon.iconset
    iconutil -c icns .build/AppIcon.iconset -o Support/AppIcon.icns
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/SwitchClaude "$APP/Contents/MacOS/SwitchClaude"
cp Support/Info.plist "$APP/Contents/Info.plist"
cp Support/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

codesign --force -s - "$APP"

echo "Built: $PWD/$APP"
