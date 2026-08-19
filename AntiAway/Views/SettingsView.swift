import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var updateService: UpdateService
    @State private var automaticallyChecksForUpdates: Bool

    init(appState: AppState, updateService: UpdateService) {
        self.appState = appState
        self.updateService = updateService
        _automaticallyChecksForUpdates = State(
            initialValue: updateService.automaticallyChecksForUpdates
        )
    }

    var body: some View {
        Form {
            Section("Activity") {
                Toggle("Stay active", isOn: Binding(
                    get: { appState.isEnabled },
                    set: { appState.setEnabled($0) }
                ))
                Picker("Activity interval", selection: $appState.interval) {
                    ForEach(ActivityInterval.allCases) { interval in
                        Text(interval.title).tag(interval)
                    }
                }
                Text("AntiAway posts a mouse-moved event at the pointer’s current location. It never clicks, types, or moves the pointer.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Startup") {
                Toggle("Launch AntiAway at login", isOn: Binding(
                    get: { appState.loginItemEnabled },
                    set: { appState.setLoginItemEnabled($0) }
                ))
            }

            Section("Appearance") {
                Toggle("Show AntiAway in the Dock", isOn: $appState.showDockIcon)
                Text("AntiAway starts as a menu-bar-only app. Enable this only if you want a Dock icon and a regular app window presence.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Show welcome screen") { appState.showOnboarding() }
            }

            Section("Permission") {
                LabeledContent("Accessibility") {
                    Text(appState.accessibilityGranted ? "Allowed" : "Not allowed")
                        .foregroundStyle(appState.accessibilityGranted ? .green : .orange)
                }
                Button("Refresh permission") { appState.refreshPermission() }
                if !appState.accessibilityGranted {
                    Button("Open Accessibility Settings") {
                        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
                        NSWorkspace.shared.open(url)
                    }
                }
            }

            Section("Updates") {
                Toggle("Automatically check for updates", isOn: $automaticallyChecksForUpdates)
                    .onChange(of: automaticallyChecksForUpdates) { _, enabled in
                        updateService.setAutomaticallyChecksForUpdates(enabled)
                    }

                Button("Check for Updates…") {
                    updateService.checkForUpdates()
                }
                .disabled(!updateService.canCheckForUpdates)

                LabeledContent("Installed version", value: installedVersion)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 430)
        .padding()
    }

    private var installedVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(version) (\(build))"
    }
}
