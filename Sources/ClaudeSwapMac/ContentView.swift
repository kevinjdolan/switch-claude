import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: AccountStore
    @EnvironmentObject var switcher: Switcher

    @State private var selection: UUID?
    @FocusState private var listFocused: Bool
    @State private var showManage = false
    @State private var accountPendingQuitConfirm: Account?

    private var selectedAccount: Account? {
        guard let id = selection else { return nil }
        return store.accounts.first { $0.id == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                ForEach(store.accounts) { account in
                    AccountRow(account: account, isCurrent: account.id == store.currentAccountID)
                        .tag(account.id)
                        .contentShape(Rectangle())
                        .simultaneousGesture(TapGesture(count: 2).onEnded {
                            requestSwitch(account)
                        })
                }
            }
            .focused($listFocused)
            .onKeyPress(.return) {
                triggerSwitch()
                return .handled
            }

            Divider()
            footer
        }
        .onKeyPress(.escape) {
            AppDelegate.shared?.hideSwitcher()
            return .handled
        }
        .frame(minWidth: 460, minHeight: 340)
        .defaultFocus($listFocused, true)
        .onAppear {
            selection = store.currentAccountID ?? store.accounts.first?.id
            DispatchQueue.main.async { listFocused = true }
        }
        .onChange(of: store.accounts) {
            if let sel = selection, !store.accounts.contains(where: { $0.id == sel }) {
                selection = store.accounts.first?.id
            }
        }
        .sheet(isPresented: $showManage) {
            ManageAccountsView()
        }
        .alert(
            "Quit Claude and switch?",
            isPresented: Binding(
                get: { accountPendingQuitConfirm != nil },
                set: { if !$0 { accountPendingQuitConfirm = nil } }
            ),
            presenting: accountPendingQuitConfirm
        ) { account in
            Button("Quit & Switch") {
                performSwitch(account)
            }
            Button("Cancel", role: .cancel) {}
        } message: { account in
            Text("Claude is currently running. Switching to “\(account.name)” will quit it, ending any sessions or responses in progress.")
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            statusLine
            HStack {
                Button("Manage Accounts") { showManage = true }
                    .disabled(switcher.busy)
                Spacer()
                Button("Switch") { triggerSwitch() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selectedAccount == nil || switcher.busy)
            }
        }
        .padding(12)
    }

    @ViewBuilder
    private var statusLine: some View {
        if switcher.busy, let status = switcher.status {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text(status)
            }
            .font(.callout)
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if let error = switcher.lastError {
            Label(error, systemImage: "exclamationmark.triangle.fill")
                .font(.callout)
                .foregroundStyle(.red)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if let status = switcher.status {
            Text(status)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text("↑↓ to choose an account · Return to switch")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func triggerSwitch() {
        guard let account = selectedAccount else { return }
        requestSwitch(account)
    }

    private func requestSwitch(_ account: Account) {
        guard !switcher.busy else { return }
        if ClaudeApp.isRunning {
            accountPendingQuitConfirm = account
        } else {
            performSwitch(account)
        }
    }

    private func performSwitch(_ account: Account) {
        Task {
            await switcher.switchTo(account, store: store)
            // Tuck the switcher away once Claude is relaunching.
            if switcher.lastError == nil {
                AppDelegate.shared?.hideSwitcher()
            }
        }
    }
}

struct AccountRow: View {
    let account: Account
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.crop.circle")
                .font(.title2)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                Text(account.isDefault ? "Claude's standard data directory" : "Separate profile")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isCurrent {
                Label("Current", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 4)
    }
}
