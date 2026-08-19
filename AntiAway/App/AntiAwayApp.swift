import AppKit
import SwiftUI

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
    @StateObject private var updateService = UpdateService()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(appState: appState)
                .frame(width: 400)
        } label: {
            MenuBarStatusIcon(isEnabled: appState.isEnabled)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(appState: appState, updateService: updateService)
        }
    }
}

private struct MenuBarStatusIcon: View {
    let isEnabled: Bool

    var body: some View {
        Image(systemName: isEnabled ? "bolt.fill" : "bolt")
            .font(.system(size: 17, weight: .bold))
            .symbolRenderingMode(.monochrome)
            .accessibilityLabel(isEnabled ? "AntiAway active" : "AntiAway inactive")
            .help(isEnabled ? "AntiAway is active" : "AntiAway is off")
    }
}
