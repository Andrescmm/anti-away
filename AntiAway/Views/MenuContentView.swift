import AppKit
import SwiftUI

struct MenuContentView: View {
    @ObservedObject var appState: AppState
    @Environment(\.openSettings) private var openSettings

    private enum Theme {
        static let accent = Color(red: 0.78, green: 1.0, blue: 0.20)
        static let panel = Color(red: 0.12, green: 0.13, blue: 0.11)
        static let topBar = Color.white.opacity(0.07)
        static let surface = Color.black.opacity(0.30)
        static let line = Color.white.opacity(0.11)
        static let secondaryText = Color.white.opacity(0.55)
    }

    var body: some View {
        VStack(spacing: 0) {
            titleBar

            VStack(spacing: 0) {
                statusCard
                    .padding(.top, 16)
                    .padding(.bottom, 7)

                activityToggle
                separator
                intervalPicker
                separator
                scheduleControls
                loginItemToggle

                privacyNotice
                    .padding(.top, 7)

                if let errorMessage = appState.errorMessage {
                    errorNotice(errorMessage)
                        .padding(.top, 10)
                }

                footer
                    .padding(.top, 14)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
        }
        .foregroundStyle(.white)
        .background(Theme.panel.opacity(0.93))
        .background(.ultraThinMaterial)
        .preferredColorScheme(.dark)
        .onAppear {
            appState.refreshSchedule()
            appState.refreshPermission()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            appState.refreshSchedule()
            appState.refreshPermission()
        }
        .sheet(isPresented: $appState.isOnboardingPresented) {
            OnboardingView(appState: appState)
        }
    }

    private var titleBar: some View {
        HStack(spacing: 10) {
            Text("AntiAway")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.secondaryText)

            Spacer()

            Image(systemName: appState.isEnabled ? "bolt.fill" : "bolt")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(appState.isEnabled ? Theme.accent : Theme.secondaryText)

            Text(Date.now, style: .time)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.66))
        }
        .padding(.horizontal, 18)
        .frame(height: 46)
        .background(Theme.topBar)
        .accessibilityElement(children: .combine)
    }

    private var statusCard: some View {
        HStack(spacing: 13) {
            ZStack {
                Circle()
                    .fill(statusColor)
                Image(systemName: statusSymbol)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(statusSymbolColor)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(statusTitle)
                    .font(.system(size: 15, weight: .semibold))
                Text(statusDetail)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondaryText)
            }

            Spacer()

            Circle()
                .fill(statusDotColor)
                .frame(width: 7, height: 7)
                .padding(6)
                .background(statusDotColor.opacity(0.12), in: Circle())
        }
        .padding(.horizontal, 15)
        .frame(minHeight: 66)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var statusTitle: String {
        if appState.scheduleEnabled && !appState.isScheduledNow { return "Waiting for schedule" }
        if !appState.accessibilityGranted { return "Permission required" }
        return appState.isEnabled ? "Staying active" : "AntiAway is off"
    }

    private var statusSymbol: String {
        if appState.scheduleEnabled && !appState.isScheduledNow { return "clock.fill" }
        if !appState.accessibilityGranted { return "exclamationmark" }
        return appState.isEnabled ? "checkmark" : "pause.fill"
    }

    private var statusColor: Color {
        if appState.scheduleEnabled && !appState.isScheduledNow { return Color.white.opacity(0.17) }
        if !appState.accessibilityGranted { return .orange }
        return appState.isEnabled ? Theme.accent : Color.white.opacity(0.17)
    }

    private var statusSymbolColor: Color {
        if appState.scheduleEnabled && !appState.isScheduledNow { return Color.white.opacity(0.68) }
        if !appState.accessibilityGranted { return Theme.panel }
        return appState.isEnabled ? Theme.panel : Color.white.opacity(0.68)
    }

    private var statusDotColor: Color {
        if appState.scheduleEnabled && !appState.isScheduledNow { return Color.white.opacity(0.28) }
        if !appState.accessibilityGranted { return .orange }
        return appState.isEnabled ? Theme.accent : Color.white.opacity(0.28)
    }

    private var statusDetail: String {
        if appState.scheduleEnabled && !appState.isScheduledNow {
            return appState.scheduleStatusDescription
        }
        if !appState.accessibilityGranted {
            return "Accessibility access is needed"
        }
        if let lastActivity = appState.lastActivityDate, appState.isEnabled {
            if Date.now.timeIntervalSince(lastActivity) < 60 {
                return "Last signal just now"
            }
            return "Last signal at \(lastActivity.formatted(date: .omitted, time: .shortened))"
        }
        return appState.isEnabled ? "Signal every \(appState.interval.shortTitle)" : "Ready when you are"
    }

    private var activityToggle: some View {
        HStack(spacing: 12) {
            rowLabel("Stay active", systemImage: "figure.walk.motion")
            Spacer()
            Toggle("Stay active", isOn: Binding(
                get: { appState.isEnabled },
                set: { appState.setEnabled($0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .tint(Theme.accent)
            .disabled(appState.scheduleEnabled)
        }
        .frame(height: 62)
        .opacity(appState.scheduleEnabled ? 0.58 : 1)
    }

    private var intervalPicker: some View {
        HStack(spacing: 12) {
            rowLabel("Activity interval", systemImage: "timer")
            Spacer()
            Menu {
                ForEach(ActivityInterval.allCases) { interval in
                    Button {
                        appState.interval = interval
                    } label: {
                        if interval == appState.interval {
                            Label(interval.shortTitle, systemImage: "checkmark")
                        } else {
                            Text(interval.shortTitle)
                        }
                    }
                }
            } label: {
                HStack(spacing: 9) {
                    Text(appState.interval.shortTitle)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.accent)
                }
                .foregroundStyle(Color.white.opacity(0.88))
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("Activity interval")
            .accessibilityValue(appState.interval.shortTitle)
        }
        .frame(height: 62)
    }

    private var loginItemToggle: some View {
        HStack(spacing: 12) {
            rowLabel("Launch at login", systemImage: "power")
            Spacer()
            Toggle("Launch at login", isOn: Binding(
                get: { appState.loginItemEnabled },
                set: { appState.setLoginItemEnabled($0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .tint(Theme.accent)
        }
        .frame(height: 62)
    }

    private var scheduleControls: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                rowLabel("Daily schedule", systemImage: "calendar.badge.clock")
                Spacer()
                Toggle("Daily schedule", isOn: Binding(
                    get: { appState.scheduleEnabled },
                    set: { appState.setScheduleEnabled($0) }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(Theme.accent)
            }
            .frame(height: 62)

            if appState.scheduleEnabled {
                HStack(spacing: 8) {
                    Text("From")
                        .foregroundStyle(Theme.secondaryText)
                    schedulePicker(
                        selection: Binding(
                            get: { appState.scheduleStartTime },
                            set: { appState.setScheduleStartTime($0) }
                        ),
                        accessibilityLabel: "Schedule start"
                    )

                    Image(systemName: "arrow.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.secondaryText)

                    Text("To")
                        .foregroundStyle(Theme.secondaryText)
                    schedulePicker(
                        selection: Binding(
                            get: { appState.scheduleEndTime },
                            set: { appState.setScheduleEndTime($0) }
                        ),
                        accessibilityLabel: "Schedule end"
                    )
                }
                .font(.system(size: 11, weight: .medium))
                .frame(height: 42)

                Text(appState.scheduleStatusDescription)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(appState.isScheduledNow ? Theme.accent : Theme.secondaryText)
                    .padding(.bottom, 8)
            }
        }
    }

    private func schedulePicker(
        selection: Binding<Date>,
        accessibilityLabel: String
    ) -> some View {
        DatePicker(
            accessibilityLabel,
            selection: selection,
            displayedComponents: .hourAndMinute
        )
        .labelsHidden()
        .datePickerStyle(.field)
        .fixedSize()
        .accessibilityLabel(accessibilityLabel)
    }

    private func rowLabel(_ title: String, systemImage: String) -> some View {
        Label {
            Text(title)
                .font(.system(size: 13, weight: .medium))
        } icon: {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.secondaryText)
                .frame(width: 20)
        }
    }

    private var separator: some View {
        Theme.line.frame(height: 1)
    }

    private var privacyNotice: some View {
        HStack(spacing: 9) {
            Image(systemName: "diamond")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Theme.accent)
            Text("Local only. No clicks, typing, or tracking.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.60))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 42)
        .background(Theme.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(Theme.accent.opacity(0.30), lineWidth: 1)
        }
    }

    private var footer: some View {
        HStack {
            Button {
                openSettings()
            } label: {
                Label("Settings", systemImage: "gearshape")
            }

            Spacer()

            Button {
                NSApplication.shared.keyWindow?.orderOut(nil)
            } label: {
                Label("Close", systemImage: "xmark")
            }
        }
        .buttonStyle(.plain)
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(Color.white.opacity(0.48))
    }

    private func errorNotice(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button {
                    appState.dismissError()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss error")
            }

            Button("Open Accessibility Settings") {
                openAccessibilitySettings()
            }
            .buttonStyle(.link)
            .font(.system(size: 11, weight: .medium))
        }
        .padding(11)
        .background(.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
