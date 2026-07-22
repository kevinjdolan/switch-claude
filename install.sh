#!/bin/bash
# Installs Switch Claude to /Applications from the latest GitHub release.
set -euo pipefail

REPO="kevinjdolan/switch-claude"
APP="Switch Claude.app"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Downloading Switch Claude…"
curl -fsSL "https://github.com/$REPO/releases/latest/download/SwitchClaude.zip" -o "$TMP/SwitchClaude.zip"
ditto -x -k "$TMP/SwitchClaude.zip" "$TMP"

echo "Installing to /Applications…"
rm -rf "/Applications/$APP"
ditto "$TMP/$APP" "/Applications/$APP"
xattr -dr com.apple.quarantine "/Applications/$APP" 2>/dev/null || true

echo "Installed. Launching…"
open "/Applications/$APP"
