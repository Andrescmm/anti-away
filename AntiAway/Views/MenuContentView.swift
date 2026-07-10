import AppKit
import SwiftUI

struct MenuContentView: View {
    @ObservedObject var appState: AppState
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 16) {
            header
            activityToggle
            Divider()
            intervalPicker
            loginItemToggle

            if let errorMessage = appState.errorMessage {
                errorNotice(errorMessage)
            }

            Divider()
            HStack {
                Button("Settings…") { openSettings() }
                Spacer()
                Button("Quit AntiAway") { NSApplication.shared.terminate(nil) }
            }
            .controlSize(.small)
        }
        .padding(16)
        .background(.regularMaterial)
        .onAppear { appState.refreshPermission() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            appState.refreshPermission()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: appState.isEnabled ? "checkmark.circle.fill" : "pause.circle.fill")
                .font(.system(size: 31, weight: .medium))
                .foregroundStyle(appState.isEnabled ? .green : .secondary)
                .symbolRenderingMode(.hierarchical)
            VStack(alignment: .leading, spacing: 2) {
                Text(appState.isEnabled ? "Staying active" : "AntiAway is off")
                    .font(.headline)
                Text(statusDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .padding(10)
        .liquidGlassSurface()
    }

    private var statusDetail: String {
        if !appState.accessibilityGranted {
            return "Accessibility permission required"
        }
        if let lastActivity = appState.lastActivityDate, appState.isEnabled {
            return "Last activity \(lastActivity.formatted(date: .omitted, time: .shortened))"
        }
        return appState.isEnabled ? "Posts a signal every \(appState.interval.shortTitle)" : "Ready when you are"
    }

    private var activityToggle: some View {
        Toggle(isOn: Binding(
            get: { appState.isEnabled },
            set: { appState.setEnabled($0) }
        )) {
            Label("Keep Teams active", systemImage: "figure.walk.motion")
        }
        .toggleStyle(.switch)
    }

    private var intervalPicker: some View {
        HStack {
            Label("Activity interval", systemImage: "timer")
            Spacer()
            Picker("Activity interval", selection: $appState.interval) {
                ForEach(ActivityInterval.allCases) { interval in
                    Text(interval.shortTitle).tag(interval)
                }
            }
            .labelsHidden()
            .frame(width: 100)
        }
    }

    private var loginItemToggle: some View {
        Toggle(isOn: Binding(
            get: { appState.loginItemEnabled },
            set: { appState.setLoginItemEnabled($0) }
        )) {
            Label("Launch at login", systemImage: "power")
        }
        .toggleStyle(.switch)
    }

    private func errorNotice(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
            Button("Open Settings") {
                openAccessibilitySettings()
            }
            .buttonStyle(.link)
            Spacer(minLength: 0)
            Button {
                appState.dismissError()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss error")
        }
        .padding(10)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
