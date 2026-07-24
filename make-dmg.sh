#!/bin/bash
# Builds, signs, and packages Claude Swap Mac into a drag-to-Applications DMG.
#
# If notarization credentials are stored in the keychain (one-time setup:
#   xcrun notarytool store-credentials claude-swap-mac-notary \
#     --apple-id <your-apple-id> --team-id J3BZJ3LKTQ
# using an app-specific password from account.apple.com), the app and the DMG
# are notarized and stapled, so downloads open with no Gatekeeper warning.
set -euo pipefail
cd "$(dirname "$0")"

APP="Claude Swap Mac.app"
DMG="ClaudeSwapMac.dmg"
NOTARY_PROFILE="${NOTARY_PROFILE:-claude-swap-mac-notary}"

./build-app.sh

notarize() {
    echo "Notarizing $1 (typically 1–5 minutes)…"
    xcrun notarytool submit "$1" --keychain-profile "$NOTARY_PROFILE" --wait
}

HAVE_NOTARY=0
if xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
    HAVE_NOTARY=1
elif xcrun notarytool history --keychain-profile switch-claude-notary >/dev/null 2>&1; then
    # Credentials stored under the app's pre-rename profile name still work.
    NOTARY_PROFILE=switch-claude-notary
    HAVE_NOTARY=1
else
    echo "No notarization credentials (keychain profile '$NOTARY_PROFILE') — skipping notarization."
fi

# Notarize and staple the app itself first, so the copy inside the DMG
# carries its own ticket (works offline, and when dragged out of the DMG).
if [ "$HAVE_NOTARY" = 1 ]; then
    ditto -c -k --sequesterRsrc --keepParent "$APP" .build/notarize-app.zip
    notarize .build/notarize-app.zip
    rm -f .build/notarize-app.zip
    xcrun stapler staple "$APP"
fi

# Fancy DMG (custom background + pinned icon layout) via dmgbuild, which
# writes the Finder layout directly — no Finder scripting or permissions.
# Falls back to a plain app+symlink image if dmgbuild can't be run.
ART=".build/dmg-art"
if [ ! -f "$ART/background.tiff" ]; then
    swift scripts/make-dmg-background.swift "$ART"
    tiffutil -cathidpicheck "$ART/background.png" "$ART/background@2x.png" \
        -out "$ART/background.tiff" >/dev/null 2>&1
fi

DMGBUILD_CMD=""
if command -v dmgbuild >/dev/null 2>&1; then
    DMGBUILD_CMD="dmgbuild"
elif command -v uvx >/dev/null 2>&1; then
    DMGBUILD_CMD="uvx dmgbuild"
fi

rm -f "$DMG"
if [ -n "$DMGBUILD_CMD" ] && [ -f "$ART/background.tiff" ]; then
    $DMGBUILD_CMD -s scripts/dmg-settings.py \
        -D app="$APP" -D background="$ART/background.tiff" \
        "Claude Swap Mac" "$DMG"
else
    echo "dmgbuild unavailable (pip install dmgbuild, or install uv) — building plain DMG."
    STAGING=".build/dmg-staging"
    rm -rf "$STAGING"
    mkdir -p "$STAGING"
    cp -R "$APP" "$STAGING/"
    ln -s /Applications "$STAGING/Applications"
    hdiutil create -volname "Claude Swap Mac" -srcfolder "$STAGING" -ov -format UDZO -quiet "$DMG"
    rm -rf "$STAGING"
fi

SIGN_IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Developer ID Application/ {print $2; exit}')}"
if [ -n "$SIGN_IDENTITY" ] && [ "$SIGN_IDENTITY" != "-" ]; then
    codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG"
fi

if [ "$HAVE_NOTARY" = 1 ]; then
    notarize "$DMG"
    xcrun stapler staple "$DMG"
    echo "Notarized and stapled."
fi

echo "Built: $PWD/$DMG"
