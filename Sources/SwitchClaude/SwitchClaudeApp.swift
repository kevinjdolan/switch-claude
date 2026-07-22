import SwiftUI

@main
struct SwitchClaudeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Switch Claude", systemImage: "arrow.triangle.2.circlepath") {
            MenuContent()
                .environmentObject(appDelegate.store)
                .environmentObject(appDelegate)
        }
    }
}

struct MenuContent: View {
    @EnvironmentObject var store: AccountStore
    @EnvironmentObject var appDelegate: AppDelegate

    var body: some View {
        Button("Open Switcher (⌃⌥S)") { appDelegate.showSwitcher() }
        Divider()
        ForEach(store.accounts) { account in
            Button {
                appDelegate.requestSwitch(account)
            } label: {
                if account.id == store.currentAccountID {
                    Label(account.name, systemImage: "checkmark")
                } else {
                    Text(account.name)
                }
            }
        }
        Divider()
        Toggle("Start at Login", isOn: Binding(
            get: { appDelegate.launchAtLogin },
            set: { appDelegate.setLaunchAtLogin($0) }
        ))
        Divider()
        Button("Quit Switch Claude") { NSApp.terminate(nil) }
    }
}
