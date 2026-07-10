import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let showDockIcon = UserDefaults.standard.bool(forKey: "showDockIcon")
        NSApp.setActivationPolicy(showDockIcon ? .regular : .accessory)
    }
}

@main
struct AntiAwayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(appState: appState)
                .frame(width: 330)
        } label: {
            MenuBarStatusIcon(isEnabled: appState.isEnabled)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(appState: appState)
        }
    }
}

private struct MenuBarStatusIcon: View {
    let isEnabled: Bool

    var body: some View {
        Image(systemName: isEnabled ? "bolt.circle.fill" : "bolt.circle")
            .font(.system(size: 16, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(isEnabled ? .green : .secondary)
            .accessibilityLabel(isEnabled ? "AntiAway active" : "AntiAway inactive")
            .help(isEnabled ? "AntiAway is active" : "AntiAway is off")
    }
}
