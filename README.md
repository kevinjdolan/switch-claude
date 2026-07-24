# Claude Swap Mac

A tiny native macOS menu bar app for switching which account the [Claude desktop app](https://claude.ai/download) is signed in to.

Claude Desktop has no built-in profile switcher — if you have a personal and a work account, you're stuck logging out and back in. Claude Swap Mac fixes that: each account keeps its own Claude data directory, so **every account stays signed in permanently**, and switching takes one keystroke.

- **⌃⌥S from anywhere** summons a keyboard-focused switcher: ↑/↓ to pick an account, Return to switch. Escape (or ⌃⌥S again) hides it.
- Switching quits Claude and relaunches it pointed at the selected account's data directory. If Claude is running, you're asked to confirm first, since in-progress sessions end.
- Lives in the menu bar (swap-arrows icon) with one-click account switching, a **Start at Login** toggle, and account management.

## Install

**Download:** grab `ClaudeSwapMac.dmg` from the [latest release](https://github.com/kevinjdolan/claude-swap-mac/releases/latest), open it, and drag `Claude Swap Mac.app` into Applications. Releases are Developer ID–signed and notarized by Apple, so the app opens with no security warnings. (A `ClaudeSwapMac.zip` is also available if you prefer.)

**Or a one-liner:**

```sh
curl -fsSL https://raw.githubusercontent.com/kevinjdolan/claude-swap-mac/main/install.sh | bash
```

This downloads the latest release into `/Applications` and launches it.

**From source:**

```sh
git clone https://github.com/kevinjdolan/claude-swap-mac.git
cd claude-swap-mac
./build-app.sh
cp -R "Claude Swap Mac.app" /Applications/
```

Requires macOS 14+ and the Xcode command line tools. `./make-dmg.sh` additionally packages the built app into a drag-to-Applications `ClaudeSwapMac.dmg` with custom background art, and — when a Developer ID identity and stored notarytool credentials are present — signs, notarizes, and staples both the app and the DMG (see the header comment in `make-dmg.sh`).

## Usage

1. **First run:** the switcher window opens and the swap-arrows icon appears in your menu bar. Your existing Claude login is the seeded **Default** account. Turn on **Start at Login** in the menu bar menu so the hotkey survives reboots.
2. **Add your second account:** click **Manage Accounts** → type a name (e.g. "Work") → **Add** → **Authorize**. Claude restarts with a fresh profile for that account — sign in there once. After that, switching never asks for a login again.
3. **Switch:** press **⌃⌥S**, arrow to the account, hit Return. Done — Claude relaunches as that account, and the switcher tucks itself away.

Also in **Manage Accounts**: rename any account (click its name or the pencil — works for Default too; labels only, logins untouched), and remove accounts with the trash icon (choosing whether to keep or trash the profile data — kept data means re-adding later needs no sign-in).

Closing the switcher window keeps the app running in the menu bar; quit it from the menu bar menu.

## How it works

Claude Desktop is an Electron app, so it honors Chromium's `--user-data-dir` flag. Each account you add gets its own data directory under `~/Library/Application Support/ClaudeSwapMac/Profiles/<name>`; the Default account uses Claude's standard directory. Switching is just: quit Claude → relaunch it with `--user-data-dir` pointed at the selected profile. Settings live in `~/Library/Application Support/ClaudeSwapMac/accounts.json`.

Only one Claude instance runs at a time by design. If you ever want two accounts open side by side, launch a second instance manually:

```sh
open -n -a Claude --args --user-data-dir="$HOME/Library/Application Support/ClaudeSwapMac/Profiles/<name>"
```

## Notes

- If Claude refuses to quit (e.g. it's showing a modal dialog), the switch aborts with an error rather than force-killing it.
- The hotkey uses Carbon's `RegisterEventHotKey` — no accessibility permission needed. To rebind it, edit the key code/modifiers in `Sources/ClaudeSwapMac/HotKeyManager.swift` and rebuild.
- **Start at Login** registers the app at its current path; if you move the app, toggle it off and on again.
- Uninstall: quit from the menu bar, delete `/Applications/Claude Swap Mac.app`, and optionally remove `~/Library/Application Support/ClaudeSwapMac` (this deletes the extra account profiles and their logins).

## License

[MIT](LICENSE)
