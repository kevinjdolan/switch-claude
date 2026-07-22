import Foundation

struct Account: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String
    /// Directory name under Profiles/, or nil for Claude's standard data directory.
    var profileDirName: String?

    var isDefault: Bool { profileDirName == nil }
}

enum AccountError: LocalizedError {
    case emptyName

    var errorDescription: String? {
        switch self {
        case .emptyName: return "Account name can't be empty."
        }
    }
}

@MainActor
final class AccountStore: ObservableObject {
    @Published var accounts: [Account] = []
    @Published var currentAccountID: UUID?

    static let appSupportDir: URL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("SwitchClaude", isDirectory: true)
    static let profilesDir: URL = appSupportDir.appendingPathComponent("Profiles", isDirectory: true)
    private static let configURL: URL = appSupportDir.appendingPathComponent("accounts.json")

    private struct Config: Codable {
        var accounts: [Account]
        var currentAccountID: UUID?
    }

    init() {
        load()
    }

    func profileURL(for account: Account) -> URL? {
        guard let dir = account.profileDirName else { return nil }
        return Self.profilesDir.appendingPathComponent(dir, isDirectory: true)
    }

    func load() {
        if let data = try? Data(contentsOf: Self.configURL),
           let config = try? JSONDecoder().decode(Config.self, from: data) {
            accounts = config.accounts
            currentAccountID = config.currentAccountID
        }
        if accounts.isEmpty {
            let def = Account(id: UUID(), name: "Default", profileDirName: nil)
            accounts = [def]
            currentAccountID = def.id
            save()
        }
    }

    func save() {
        do {
            try FileManager.default.createDirectory(at: Self.appSupportDir, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(Config(accounts: accounts, currentAccountID: currentAccountID))
            try data.write(to: Self.configURL, options: .atomic)
        } catch {
            NSLog("SwitchClaude: failed to save config: \(error)")
        }
    }

    @discardableResult
    func addAccount(named name: String) throws -> Account {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AccountError.emptyName }

        var slug = String(trimmed.lowercased().map { ($0.isLetter || $0.isNumber) ? $0 : "-" })
        while slug.contains("--") { slug = slug.replacingOccurrences(of: "--", with: "-") }
        slug = slug.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        if slug.isEmpty { slug = "account" }

        var unique = slug
        var n = 2
        while accounts.contains(where: { $0.profileDirName == unique }) {
            unique = "\(slug)-\(n)"
            n += 1
        }

        try FileManager.default.createDirectory(
            at: Self.profilesDir.appendingPathComponent(unique, isDirectory: true),
            withIntermediateDirectories: true
        )
        let account = Account(id: UUID(), name: trimmed, profileDirName: unique)
        accounts.append(account)
        save()
        return account
    }

    /// Trims edited names, restoring a fallback for any left empty, then persists.
    func sanitizeNames() {
        for i in accounts.indices {
            let trimmed = accounts[i].name.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                accounts[i].name = accounts[i].isDefault ? "Default" : (accounts[i].profileDirName ?? "Account")
            } else {
                accounts[i].name = trimmed
            }
        }
        save()
    }

    func removeAccount(_ account: Account, trashData: Bool) {
        guard !account.isDefault else { return }
        accounts.removeAll { $0.id == account.id }
        if currentAccountID == account.id { currentAccountID = nil }
        if trashData,
           let url = profileURL(for: account),
           FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
        }
        save()
    }
}
