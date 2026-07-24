#!/bin/bash
# Installs Claude Swap Mac to /Applications from the latest GitHub release.
set -euo pipefail

REPO="kevinjdolan/claude-swap-mac"
APP="Claude Swap Mac.app"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Downloading Claude Swap Mac…"
curl -fsSL "https://github.com/$REPO/releases/latest/download/ClaudeSwapMac.zip" -o "$TMP/ClaudeSwapMac.zip"
ditto -x -k "$TMP/ClaudeSwapMac.zip" "$TMP"

echo "Installing to /Applications…"
rm -rf "/Applications/$APP"
ditto "$TMP/$APP" "/Applications/$APP"
xattr -dr com.apple.quarantine "/Applications/$APP" 2>/dev/null || true

echo "Installed. Launching…"
open "/Applications/$APP"
