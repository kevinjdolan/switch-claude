#!/bin/bash
# Builds Claude Swap Mac.app from the Swift package.
# Signs with a Developer ID Application identity when one is in the keychain
# (hardened runtime + timestamp, as notarization requires); otherwise ad-hoc.
# Override with SIGN_IDENTITY=<identity> or SIGN_IDENTITY=- (force ad-hoc).
set -euo pipefail
cd "$(dirname "$0")"

APP="Claude Swap Mac.app"
SIGN_IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Developer ID Application/ {print $2; exit}')}"

swift build -c release

# Generate the icon once (delete Support/AppIcon.icns to regenerate).
if [ ! -f Support/AppIcon.icns ]; then
    rm -rf .build/AppIcon.iconset
    swift scripts/make-icon.swift .build/AppIcon.iconset
    iconutil -c icns .build/AppIcon.iconset -o Support/AppIcon.icns
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/ClaudeSwapMac "$APP/Contents/MacOS/ClaudeSwapMac"
cp Support/Info.plist "$APP/Contents/Info.plist"
cp Support/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

if [ -n "$SIGN_IDENTITY" ] && [ "$SIGN_IDENTITY" != "-" ]; then
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
    echo "Signed as: $SIGN_IDENTITY"
else
    codesign --force -s - "$APP"
    echo "Ad-hoc signed (no Developer ID identity found)"
fi

echo "Built: $PWD/$APP"
