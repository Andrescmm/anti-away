import Foundation
import Combine
import AppKit

@MainActor
final class AppState: ObservableObject {
    private enum Key {
        static let isEnabled = "isEnabled"
        static let interval = "activityInterval"
        static let showDockIcon = "showDockIcon"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let scheduleEnabled = "scheduleEnabled"
        static let scheduleStartMinutes = "scheduleStartMinutes"
        static let scheduleEndMinutes = "scheduleEndMinutes"
    }

    private let defaults: UserDefaults
    private let simulator: any ActivityPosting
    private let loginItemService: LoginItemService
    private let nowProvider: () -> Date
    private var timer: Timer?
    private var permissionTimer: Timer?
    private var scheduleBoundaryTimer: Timer?
    private var manualEnabled: Bool
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
    @Published var isOnboardingPresented: Bool
    @Published private(set) var accessibilityGranted: Bool
    @Published private(set) var loginItemEnabled: Bool
    @Published private(set) var lastActivityDate: Date?
    @Published private(set) var scheduleEnabled: Bool
    @Published private(set) var scheduleStartMinutes: Int
    @Published private(set) var scheduleEndMinutes: Int
    @Published private(set) var isScheduledNow: Bool
    @Published var errorMessage: String?

    init(
        defaults: UserDefaults = .standard,
        simulator: any ActivityPosting = ActivitySimulator(),
        loginItemService: LoginItemService = LoginItemService(),
        nowProvider: @escaping () -> Date = { .now }
    ) {
        self.defaults = defaults
        self.simulator = simulator
        self.loginItemService = loginItemService
        self.nowProvider = nowProvider
        self.manualEnabled = defaults.bool(forKey: Key.isEnabled)
        self.shouldEnableWhenPermitted = false
        self.isEnabled = false
        self.interval = ActivityInterval(rawValue: defaults.integer(forKey: Key.interval)) ?? .every60Seconds
        self.showDockIcon = defaults.bool(forKey: Key.showDockIcon)
        self.isOnboardingPresented = !defaults.bool(forKey: Key.hasCompletedOnboarding)
        self.accessibilityGranted = simulator.hasAccessibilityPermission()
        self.loginItemEnabled = loginItemService.isEnabled()
        self.scheduleEnabled = defaults.bool(forKey: Key.scheduleEnabled)
        self.scheduleStartMinutes = defaults.object(forKey: Key.scheduleStartMinutes) as? Int ?? 9 * 60
        self.scheduleEndMinutes = defaults.object(forKey: Key.scheduleEndMinutes) as? Int ?? 17 * 60
        self.isScheduledNow = false

        NSApp?.setActivationPolicy(showDockIcon ? .regular : .accessory)

        if scheduleEnabled {
            let now = nowProvider()
            isScheduledNow = dailySchedule.contains(now)
            shouldEnableWhenPermitted = isScheduledNow
            scheduleNextBoundary(after: now)
        } else {
            shouldEnableWhenPermitted = manualEnabled
        }

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
        guard !scheduleEnabled else { return }

        manualEnabled = enabled
        defaults.set(enabled, forKey: Key.isEnabled)
        updateDesiredActivity(enabled, requestPermission: enabled)
    }

    func setScheduleEnabled(_ enabled: Bool) {
        errorMessage = nil
        scheduleEnabled = enabled
        defaults.set(enabled, forKey: Key.scheduleEnabled)

        if enabled {
            evaluateSchedule(at: nowProvider(), requestPermission: true)
        } else {
            scheduleBoundaryTimer?.invalidate()
            scheduleBoundaryTimer = nil
            isScheduledNow = false
            updateDesiredActivity(manualEnabled, requestPermission: manualEnabled)
        }
    }

    func setScheduleStartTime(_ date: Date) {
        scheduleStartMinutes = DailySchedule.minutes(from: date)
        defaults.set(scheduleStartMinutes, forKey: Key.scheduleStartMinutes)
        if scheduleEnabled { evaluateSchedule(at: nowProvider(), requestPermission: true) }
    }

    func setScheduleEndTime(_ date: Date) {
        scheduleEndMinutes = DailySchedule.minutes(from: date)
        defaults.set(scheduleEndMinutes, forKey: Key.scheduleEndMinutes)
        if scheduleEnabled { evaluateSchedule(at: nowProvider(), requestPermission: true) }
    }

    func refreshSchedule(at date: Date? = nil) {
        guard scheduleEnabled else { return }
        evaluateSchedule(at: date ?? nowProvider(), requestPermission: false)
    }

    var scheduleStartTime: Date {
        DailySchedule.date(for: scheduleStartMinutes, referenceDate: nowProvider())
    }

    var scheduleEndTime: Date {
        DailySchedule.date(for: scheduleEndMinutes, referenceDate: nowProvider())
    }

    var scheduleWindowDescription: String {
        "\(scheduleStartTime.formatted(date: .omitted, time: .shortened))–\(scheduleEndTime.formatted(date: .omitted, time: .shortened))"
    }

    var scheduleStatusDescription: String {
        if scheduleStartMinutes == scheduleEndMinutes { return "Scheduled all day" }
        return isScheduledNow
            ? "Active until \(scheduleEndTime.formatted(date: .omitted, time: .shortened))"
            : "Starts at \(scheduleStartTime.formatted(date: .omitted, time: .shortened))"
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

    func completeOnboarding() {
        defaults.set(true, forKey: Key.hasCompletedOnboarding)
        isOnboardingPresented = false
    }

    func showOnboarding() {
        isOnboardingPresented = true
    }

    func requestAccessibilityPermission() {
        _ = simulator.requestAccessibilityPermission()
        refreshPermission()
    }

    private var dailySchedule: DailySchedule {
        DailySchedule(startMinutes: scheduleStartMinutes, endMinutes: scheduleEndMinutes)
    }

    private func updateDesiredActivity(_ enabled: Bool, requestPermission: Bool) {
        shouldEnableWhenPermitted = enabled

        guard enabled else {
            stopActivity()
            stopPermissionPolling()
            return
        }

        accessibilityGranted = simulator.hasAccessibilityPermission()
        if accessibilityGranted {
            startActivity()
            return
        }

        if requestPermission, simulator.requestAccessibilityPermission() {
            accessibilityGranted = true
            startActivity()
            return
        }

        accessibilityGranted = false
        schedulePermissionPolling()
        if requestPermission {
            errorMessage = "Allow the current AntiAway app in System Settings › Privacy & Security › Accessibility. Return here; AntiAway will keep checking and start automatically. If it still shows required, quit and relaunch this same app build."
        }
    }

    private func evaluateSchedule(at date: Date, requestPermission: Bool) {
        let shouldBeActive = dailySchedule.contains(date)
        isScheduledNow = shouldBeActive
        updateDesiredActivity(shouldBeActive, requestPermission: requestPermission && shouldBeActive)
        scheduleNextBoundary(after: date)
    }

    private func scheduleNextBoundary(after date: Date) {
        scheduleBoundaryTimer?.invalidate()
        scheduleBoundaryTimer = nil

        guard scheduleEnabled, let boundary = dailySchedule.nextBoundary(after: date) else { return }

        let boundaryTimer = Timer(fire: boundary.addingTimeInterval(0.5), interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshSchedule()
            }
        }
        boundaryTimer.tolerance = 1
        RunLoop.main.add(boundaryTimer, forMode: .common)
        scheduleBoundaryTimer = boundaryTimer
    }

    private func scheduleTimer() {
        guard shouldEnableWhenPermitted, isEnabled else {
            timer?.invalidate()
            timer = nil
            return
        }

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(interval.rawValue), repeats: true) { [weak self] timer in
            guard timer.isValid else { return }
            Task { @MainActor [weak self] in
                self?.handleActivityTimerFired()
            }
        }
        // Tolerance lets macOS coalesce wake-ups for lower battery impact.
        timer?.tolerance = min(5, TimeInterval(interval.rawValue) * 0.1)
    }

    private func startActivity() {
        guard shouldEnableWhenPermitted, !isEnabled else { return }
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

    /// Re-checks the user's intent at execution time. A timer callback can
    /// already be queued when the switch is turned off, so invalidating the
    /// timer alone is not sufficient to guarantee that no final event posts.
    func handleActivityTimerFired() {
        guard shouldEnableWhenPermitted, isEnabled else { return }

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
