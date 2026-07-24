import AppKit

enum ClaudeAppError: LocalizedError {
    case notInstalled
    case didNotQuit

    var errorDescription: String? {
        switch self {
        case .notInstalled:
            return "Couldn't find the Claude desktop app. Is it installed in /Applications?"
        case .didNotQuit:
            return "Claude didn't quit in time — it may be waiting on a dialog. Quit it manually and try again."
        }
    }
}

/// Locates, quits, and relaunches the Claude desktop app.
enum ClaudeApp {
    static let fallbackBundleID = "com.anthropic.claudefordesktop"

    static var appURL: URL? {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: fallbackBundleID) {
            return url
        }
        let candidates = ["/Applications/Claude.app", NSHomeDirectory() + "/Applications/Claude.app"]
        for path in candidates where FileManager.default.fileExists(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    static var bundleID: String {
        if let url = appURL, let id = Bundle(url: url)?.bundleIdentifier {
            return id
        }
        return fallbackBundleID
    }

    static var runningApp: NSRunningApplication? {
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
            return app
        }
        // Fallback in case the installed bundle ID ever differs.
        return NSWorkspace.shared.runningApplications.first {
            $0.bundleURL?.lastPathComponent == "Claude.app"
        }
    }

    static var isRunning: Bool { runningApp != nil }

    /// Asks Claude to quit gracefully and waits for it to exit.
    static func quitAndWait(timeout: TimeInterval = 12) async -> Bool {
        guard let app = runningApp else { return true }
        app.terminate()
        let deadline = Date().addingTimeInterval(timeout)
        while !app.isTerminated && Date() < deadline {
            try? await Task.sleep(for: .milliseconds(150))
        }
        return app.isTerminated
    }

    /// Launches Claude, optionally pointed at a separate user data directory.
    static func launch(userDataDir: URL?) async throws {
        guard let url = appURL else { throw ClaudeAppError.notInstalled }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        if let dir = userDataDir {
            config.arguments = ["--user-data-dir=\(dir.path)"]
        }
        _ = try await NSWorkspace.shared.openApplication(at: url, configuration: config)
    }
}

/// Drives the quit → relaunch sequence and publishes progress for the UI.
@MainActor
final class Switcher: ObservableObject {
    enum Purpose {
        case switchTo
        case authorize
    }

    @Published var busy = false
    @Published var status: String?
    @Published var lastError: String?

    func switchTo(_ account: Account, store: AccountStore, purpose: Purpose = .switchTo) async {
        guard !busy else { return }
        busy = true
        lastError = nil
        defer { busy = false }

        status = "Quitting Claude…"
        guard await ClaudeApp.quitAndWait() else {
            status = nil
            lastError = ClaudeAppError.didNotQuit.localizedDescription
            return
        }
        // Give the old instance a beat to fully release its data directory.
        try? await Task.sleep(for: .milliseconds(400))

        status = "Opening Claude as “\(account.name)”…"
        do {
            var dir: URL?
            if let url = store.profileURL(for: account) {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                dir = url
            }
            try await ClaudeApp.launch(userDataDir: dir)
            store.currentAccountID = account.id
            store.save()
            switch purpose {
            case .switchTo:
                status = "Switched to “\(account.name)”."
            case .authorize:
                status = "Claude opened as “\(account.name)” — sign in to that account in the Claude window."
            }
        } catch {
            status = nil
            lastError = error.localizedDescription
        }
    }
}
