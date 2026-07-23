#!/bin/bash
# Builds, signs, and packages Switch Claude into a drag-to-Applications DMG.
#
# If notarization credentials are stored in the keychain (one-time setup:
#   xcrun notarytool store-credentials switch-claude-notary \
#     --apple-id <your-apple-id> --team-id J3BZJ3LKTQ
# using an app-specific password from account.apple.com), the app and the DMG
# are notarized and stapled, so downloads open with no Gatekeeper warning.
set -euo pipefail
cd "$(dirname "$0")"

APP="Switch Claude.app"
DMG="SwitchClaude.dmg"
NOTARY_PROFILE="${NOTARY_PROFILE:-switch-claude-notary}"

./build-app.sh

notarize() {
    echo "Notarizing $1 (typically 1–5 minutes)…"
    xcrun notarytool submit "$1" --keychain-profile "$NOTARY_PROFILE" --wait
}

HAVE_NOTARY=0
if xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
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

STAGING=".build/dmg-staging"
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "Switch Claude" -srcfolder "$STAGING" -ov -format UDZO -quiet "$DMG"
rm -rf "$STAGING"

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
