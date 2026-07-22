import SwiftUI

struct ManageAccountsView: View {
    @EnvironmentObject var store: AccountStore
    @EnvironmentObject var switcher: Switcher
    @Environment(\.dismiss) private var dismiss

    @State private var newName = ""
    @State private var addError: String?
    @State private var accountPendingRemoval: Account?
    @State private var accountPendingAuthorize: Account?
    @FocusState private var editingNameID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Manage Accounts")
                .font(.title3.bold())
            Text("Each account keeps its own Claude data directory, so every account stays signed in at once. Add an account, then click Authorize — Claude will restart with that account's profile so you can sign in there. Click an account's name to rename it.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            List {
                ForEach($store.accounts) { $account in
                    row(for: $account)
                }
            }
            .frame(minHeight: 170)

            HStack {
                TextField("New account name (e.g. Work)", text: $newName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(add)
                Button("Add", action: add)
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            if let addError {
                Text(addError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack(spacing: 8) {
                if switcher.busy, let status = switcher.status {
                    ProgressView().controlSize(.small)
                    Text(status).font(.caption)
                } else if let status = switcher.status {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") {
                    store.sanitizeNames()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
        .frame(width: 500)
        .onDisappear { store.sanitizeNames() }
        .alert(
            "Quit Claude and authorize?",
            isPresented: Binding(
                get: { accountPendingAuthorize != nil },
                set: { if !$0 { accountPendingAuthorize = nil } }
            ),
            presenting: accountPendingAuthorize
        ) { account in
            Button("Quit & Authorize") {
                Task { await switcher.switchTo(account, store: store, purpose: .authorize) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { account in
            Text("Claude is currently running. Authorizing “\(account.name)” will quit it, ending any sessions or responses in progress, then reopen it with that account's profile.")
        }
        .alert(
            "Remove account?",
            isPresented: Binding(
                get: { accountPendingRemoval != nil },
                set: { if !$0 { accountPendingRemoval = nil } }
            ),
            presenting: accountPendingRemoval
        ) { account in
            Button("Remove, Keep Data") {
                store.removeAccount(account, trashData: false)
            }
            Button("Remove & Trash Data", role: .destructive) {
                store.removeAccount(account, trashData: true)
            }
            Button("Cancel", role: .cancel) {}
        } message: { account in
            Text("Keeping the data lets you re-add “\(account.name)” later without signing in again. Trashing it moves the profile folder to the Trash.")
        }
    }

    @ViewBuilder
    private func row(for binding: Binding<Account>) -> some View {
        let account = binding.wrappedValue
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    TextField("Name", text: binding.name)
                        .textFieldStyle(.plain)
                        .focused($editingNameID, equals: account.id)
                        .onSubmit { store.sanitizeNames() }
                        .fixedSize(horizontal: true, vertical: false)
                    Button {
                        editingNameID = account.id
                    } label: {
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Rename this account")
                }
                Text(pathDescription(for: account))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            if account.id == store.currentAccountID {
                Text("Current")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
            Button("Authorize") { requestAuthorize(account) }
                .disabled(switcher.busy)
                .help("Restart Claude with this account's profile so you can sign in to it.")
            Button {
                accountPendingRemoval = account
            } label: {
                Image(systemName: "trash")
            }
            .disabled(account.isDefault || switcher.busy)
            .help(account.isDefault ? "The default account can't be removed." : "Remove this account")
        }
        .padding(.vertical, 2)
    }

    private func pathDescription(for account: Account) -> String {
        let home = NSHomeDirectory()
        let path: String
        if let url = store.profileURL(for: account) {
            path = url.path
        } else {
            path = home + "/Library/Application Support/Claude"
        }
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }

    private func requestAuthorize(_ account: Account) {
        guard !switcher.busy else { return }
        if ClaudeApp.isRunning {
            accountPendingAuthorize = account
        } else {
            Task { await switcher.switchTo(account, store: store, purpose: .authorize) }
        }
    }

    private func add() {
        addError = nil
        do {
            try store.addAccount(named: newName)
            newName = ""
        } catch {
            addError = error.localizedDescription
        }
    }
}
