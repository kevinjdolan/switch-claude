import AppKit
import ServiceManagement
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    static private(set) var shared: AppDelegate?

    let store = AccountStore()
    let switcher = Switcher()
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        HotKeyManager.shared.onHotKey = { [weak self] in
            self?.toggleSwitcher()
        }
        HotKeyManager.shared.register()
        showSwitcher()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSwitcher()
        return true
    }

    func toggleSwitcher() {
        if let window, window.isVisible, NSApp.isActive {
            hideSwitcher()
        } else {
            showSwitcher()
        }
    }

    func showSwitcher() {
        if window == nil {
            let content = ContentView()
                .environmentObject(store)
                .environmentObject(switcher)
            let hosting = NSHostingController(rootView: content)
            let w = NSWindow(contentViewController: hosting)
            w.title = "Switch Claude"
            w.isReleasedWhenClosed = false
            w.setContentSize(NSSize(width: 480, height: 400))
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func hideSwitcher() {
        window?.orderOut(nil)
    }

    var launchAtLogin: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("SwitchClaude: launch-at-login change failed: \(error)")
        }
        objectWillChange.send()
    }

    /// Switch initiated from the menu bar menu — confirms via alert when Claude is running.
    func requestSwitch(_ account: Account) {
        Task {
            if ClaudeApp.isRunning {
                let alert = NSAlert()
                alert.messageText = "Quit Claude and switch?"
                alert.informativeText = "Claude is currently running. Switching to “\(account.name)” will quit it, ending any sessions or responses in progress."
                alert.addButton(withTitle: "Quit & Switch")
                alert.addButton(withTitle: "Cancel")
                NSApp.activate(ignoringOtherApps: true)
                guard alert.runModal() == .alertFirstButtonReturn else { return }
            }
            await switcher.switchTo(account, store: store)
        }
    }
}
