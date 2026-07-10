import Foundation
import Combine
import AppKit

@MainActor
final class AppState: ObservableObject {
    private enum Key {
        static let isEnabled = "isEnabled"
        static let interval = "activityInterval"
        static let showDockIcon = "showDockIcon"
    }

    private let defaults: UserDefaults
    private let simulator: any ActivityPosting
    private let loginItemService: LoginItemService
    private var timer: Timer?
    private var permissionTimer: Timer?
    private var shouldEnableWhenPermitted: Bool

    @Published private(set) var isEnabled: Bool
    @Published var interval: ActivityInterval {
        didSet {
            defaults.set(interval.rawValue, forKey: Key.interval)
            if isEnabled { scheduleTimer() }
        }
    }
    @Published var showDockIcon: Bool {
        didSet {
            defaults.set(showDockIcon, forKey: Key.showDockIcon)
            NSApp?.setActivationPolicy(showDockIcon ? .regular : .accessory)
        }
    }
    @Published private(set) var accessibilityGranted: Bool
    @Published private(set) var loginItemEnabled: Bool
    @Published private(set) var lastActivityDate: Date?
    @Published var errorMessage: String?

    init(
        defaults: UserDefaults = .standard,
        simulator: any ActivityPosting = ActivitySimulator(),
        loginItemService: LoginItemService = LoginItemService()
    ) {
        self.defaults = defaults
        self.simulator = simulator
        self.loginItemService = loginItemService
        self.shouldEnableWhenPermitted = defaults.bool(forKey: Key.isEnabled)
        self.isEnabled = false
        self.interval = ActivityInterval(rawValue: defaults.integer(forKey: Key.interval)) ?? .every60Seconds
        self.showDockIcon = defaults.bool(forKey: Key.showDockIcon)
        self.accessibilityGranted = simulator.hasAccessibilityPermission()
        self.loginItemEnabled = loginItemService.isEnabled()

        NSApp?.setActivationPolicy(showDockIcon ? .regular : .accessory)

        if shouldEnableWhenPermitted && accessibilityGranted {
            startActivity()
        } else if shouldEnableWhenPermitted {
            schedulePermissionPolling()
        }
    }

    func refreshPermission() {
        accessibilityGranted = simulator.hasAccessibilityPermission()
        if accessibilityGranted {
            stopPermissionPolling()
            if shouldEnableWhenPermitted && !isEnabled {
                startActivity()
            }
        } else if shouldEnableWhenPermitted && !isEnabled {
            schedulePermissionPolling()
        }
    }

    func setEnabled(_ enabled: Bool) {
        errorMessage = nil
        if enabled {
            shouldEnableWhenPermitted = true
            defaults.set(true, forKey: Key.isEnabled)
            refreshPermission()
            guard accessibilityGranted || simulator.requestAccessibilityPermission() else {
                accessibilityGranted = false
                schedulePermissionPolling()
                errorMessage = "Allow the current AntiAway app in System Settings › Privacy & Security › Accessibility. Return here; AntiAway will keep checking and start automatically. If it still shows required, quit and relaunch this same app build."
                return
            }
            accessibilityGranted = true
            startActivity()
        } else {
            shouldEnableWhenPermitted = false
            defaults.set(false, forKey: Key.isEnabled)
            stopActivity()
            stopPermissionPolling()
        }
    }

    func setLoginItemEnabled(_ enabled: Bool) {
        errorMessage = nil
        do {
            try loginItemService.setEnabled(enabled)
            loginItemEnabled = loginItemService.isEnabled()
        } catch {
            loginItemEnabled = loginItemService.isEnabled()
            errorMessage = "Could not update launch at login: \(error.localizedDescription)"
        }
    }

    func dismissError() {
        errorMessage = nil
    }

    private func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(interval.rawValue), repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.postActivity()
            }
        }
        // Tolerance lets macOS coalesce wake-ups for lower battery impact.
        timer?.tolerance = min(5, TimeInterval(interval.rawValue) * 0.1)
    }

    private func startActivity() {
        guard !isEnabled else { return }
        isEnabled = true
        do {
            try simulator.postActivity()
            lastActivityDate = .now
            stopPermissionPolling()
            scheduleTimer()
        } catch {
            isEnabled = false
            timer?.invalidate()
            timer = nil
            accessibilityGranted = simulator.hasAccessibilityPermission()
            if shouldEnableWhenPermitted && !accessibilityGranted {
                schedulePermissionPolling()
            }
            errorMessage = error.localizedDescription
        }
    }

    private func stopActivity() {
        isEnabled = false
        timer?.invalidate()
        timer = nil
    }

    private func postActivity() {
        do {
            try simulator.postActivity()
            lastActivityDate = .now
        } catch {
            stopActivity()
            accessibilityGranted = simulator.hasAccessibilityPermission()
            if shouldEnableWhenPermitted && !accessibilityGranted {
                schedulePermissionPolling()
            }
            errorMessage = error.localizedDescription
        }
    }

    private func schedulePermissionPolling() {
        guard permissionTimer == nil else { return }

        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshPermission()
            }
        }
        permissionTimer?.tolerance = 0.5
    }

    private func stopPermissionPolling() {
        permissionTimer?.invalidate()
        permissionTimer = nil
    }
}
