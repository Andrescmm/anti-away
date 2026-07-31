import AppKit
import SwiftUI

struct OnboardingView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bolt.circle.fill")
                .font(.system(size: 56, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.green)
                .padding(.top, 8)

            VStack(spacing: 8) {
                Text("Welcome to AntiAway")
                    .font(.title2.weight(.semibold))
                Text("Keep your work presence active with a small, local signal that never moves your pointer, clicks, or types.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 12) {
                OnboardingRow(icon: "hand.raised.fill", title: "One permission", detail: "Accessibility access is required to post the signal.")
                OnboardingRow(icon: "eye.slash.fill", title: "Private by design", detail: "No screenshots, keystroke recording, network calls, or analytics.")
                OnboardingRow(icon: "menubar.rectangle", title: "Lives in the menu bar", detail: "The app stays out of your Dock unless you explicitly enable it.")
            }
            .padding(14)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            HStack {
                Button("Open Accessibility Settings") {
                    appState.requestAccessibilityPermission()
                    openAccessibilitySettings()
                }
                .buttonStyle(.link)

                Spacer()

                Button("Continue") {
                    appState.completeOnboarding()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 430)
    }

    private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

private struct OnboardingRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .frame(width: 22)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
