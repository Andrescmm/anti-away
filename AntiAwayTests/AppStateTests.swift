import XCTest
@testable import AntiAway

final class AppStateTests: XCTestCase {
    @MainActor
    func testTurningSwitchOffBlocksAnAlreadyQueuedTimerCallback() {
        let defaults = makeDefaults()
        let recorder = ActivityRecorder(hasPermission: true)
        let state = AppState(defaults: defaults, simulator: recorder)

        state.setEnabled(true)
        XCTAssertTrue(state.isEnabled)
        XCTAssertEqual(recorder.postCount, 1, "Enabling posts the initial activity signal")

        state.handleActivityTimerFired()
        XCTAssertEqual(recorder.postCount, 2, "An active timer callback posts a signal")

        state.setEnabled(false)
        state.handleActivityTimerFired()

        XCTAssertFalse(state.isEnabled)
        XCTAssertFalse(defaults.bool(forKey: "isEnabled"))
        XCTAssertEqual(recorder.postCount, 2, "No signal is posted after the switch is off")
    }

    @MainActor
    func testTurningSwitchOffCancelsDeferredEnableAfterPermissionGrant() {
        let defaults = makeDefaults()
        let recorder = ActivityRecorder(hasPermission: false)
        let state = AppState(defaults: defaults, simulator: recorder)

        state.setEnabled(true)
        XCTAssertFalse(state.isEnabled)
        XCTAssertEqual(recorder.postCount, 0)

        state.setEnabled(false)
        recorder.hasPermission = true
        state.refreshPermission()

        XCTAssertFalse(state.isEnabled)
        XCTAssertEqual(recorder.postCount, 0, "Granting permission later must not reactivate an app the user switched off")
    }

    @MainActor
    func testDailyScheduleStartsAndStopsActivity() {
        let defaults = makeDefaults()
        let recorder = ActivityRecorder(hasPermission: true)
        let scheduledDay = Calendar.autoupdatingCurrent.date(byAdding: .day, value: 1, to: .now)!
        let tenAM = date(on: scheduledDay, hour: 10)
        let state = AppState(defaults: defaults, simulator: recorder, nowProvider: { tenAM })

        state.setScheduleStartTime(date(on: scheduledDay, hour: 9))
        state.setScheduleEndTime(date(on: scheduledDay, hour: 17))
        state.setScheduleEnabled(true)

        XCTAssertTrue(state.scheduleEnabled)
        XCTAssertTrue(state.isScheduledNow)
        XCTAssertTrue(state.isEnabled)
        XCTAssertEqual(recorder.postCount, 1)
        XCTAssertTrue(defaults.bool(forKey: "scheduleEnabled"))

        state.refreshSchedule(at: date(on: scheduledDay, hour: 18))
        state.handleActivityTimerFired()

        XCTAssertFalse(state.isScheduledNow)
        XCTAssertFalse(state.isEnabled)
        XCTAssertEqual(recorder.postCount, 1, "No activity may be posted after the scheduled end")
    }

    @MainActor
    func testScheduleBoundaryStartsAndStopsWithoutOpeningMenu() {
        let defaults = makeDefaults()
        let recorder = ActivityRecorder(hasPermission: true)
        let scheduler = ScheduleBoundarySchedulerSpy()
        let scheduledDay = Calendar.autoupdatingCurrent.date(byAdding: .day, value: 1, to: .now)!
        var now = date(on: scheduledDay, hour: 8)
        let state = AppState(
            defaults: defaults,
            simulator: recorder,
            nowProvider: { now },
            scheduleBoundaryScheduler: scheduler
        )

        state.setScheduleStartTime(date(on: scheduledDay, hour: 9))
        state.setScheduleEndTime(date(on: scheduledDay, hour: 17))
        state.setScheduleEnabled(true)

        XCTAssertFalse(state.isEnabled)
        XCTAssertFalse(state.isScheduledNow)
        XCTAssertEqual(scheduler.scheduledDelay ?? 0, 60 * 60 + 0.5, accuracy: 1)

        now = date(on: scheduledDay, hour: 9, minute: 1)
        scheduler.fire()

        XCTAssertTrue(state.isEnabled)
        XCTAssertTrue(state.isScheduledNow)
        XCTAssertEqual(recorder.postCount, 1)
        XCTAssertNotNil(scheduler.scheduledAction, "The end boundary must be scheduled immediately")

        now = date(on: scheduledDay, hour: 17, minute: 1)
        scheduler.fire()

        XCTAssertFalse(state.isEnabled)
        XCTAssertFalse(state.isScheduledNow)
        XCTAssertEqual(recorder.postCount, 1, "Stopping at the boundary must not post another signal")
        XCTAssertNotNil(scheduler.scheduledAction, "The next day's start must be scheduled")
    }

    @MainActor
    func testSystemClockChangeReevaluatesScheduleWithoutOpeningMenu() async {
        let defaults = makeDefaults()
        let recorder = ActivityRecorder(hasPermission: true)
        let scheduler = ScheduleBoundarySchedulerSpy()
        let scheduledDay = Calendar.autoupdatingCurrent.date(byAdding: .day, value: 1, to: .now)!
        var now = date(on: scheduledDay, hour: 10)
        let state = AppState(
            defaults: defaults,
            simulator: recorder,
            nowProvider: { now },
            scheduleBoundaryScheduler: scheduler
        )

        state.setScheduleStartTime(date(on: scheduledDay, hour: 9))
        state.setScheduleEndTime(date(on: scheduledDay, hour: 17))
        state.setScheduleEnabled(true)
        XCTAssertTrue(state.isEnabled)

        now = date(on: scheduledDay, hour: 18)
        NotificationCenter.default.post(
            name: Notification.Name("NSSystemClockDidChangeNotification"),
            object: nil
        )
        await Task.yield()
        await Task.yield()

        XCTAssertFalse(state.isEnabled)
        XCTAssertFalse(state.isScheduledNow)
    }

    private func date(on day: Date, hour: Int, minute: Int = 0) -> Date {
        Calendar.autoupdatingCurrent.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: day
        )!
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "AppStateTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

final class DailyScheduleTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testDaytimeWindow() {
        let schedule = DailySchedule(startMinutes: 9 * 60, endMinutes: 17 * 60)

        XCTAssertTrue(schedule.contains(date(hour: 9), calendar: calendar))
        XCTAssertTrue(schedule.contains(date(hour: 16, minute: 59), calendar: calendar))
        XCTAssertFalse(schedule.contains(date(hour: 17), calendar: calendar))
        XCTAssertFalse(schedule.contains(date(hour: 8, minute: 59), calendar: calendar))
    }

    func testOvernightWindow() {
        let schedule = DailySchedule(startMinutes: 22 * 60, endMinutes: 6 * 60)

        XCTAssertTrue(schedule.contains(date(hour: 23), calendar: calendar))
        XCTAssertTrue(schedule.contains(date(hour: 5, minute: 59), calendar: calendar))
        XCTAssertFalse(schedule.contains(date(hour: 6), calendar: calendar))
        XCTAssertFalse(schedule.contains(date(hour: 12), calendar: calendar))
    }

    func testEqualTimesMeanAllDay() {
        let schedule = DailySchedule(startMinutes: 8 * 60, endMinutes: 8 * 60)

        XCTAssertTrue(schedule.contains(date(hour: 0), calendar: calendar))
        XCTAssertTrue(schedule.contains(date(hour: 23, minute: 59), calendar: calendar))
        XCTAssertNil(schedule.nextBoundary(after: date(hour: 12), calendar: calendar))
    }

    private func date(hour: Int, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(
            year: 2026,
            month: 1,
            day: 15,
            hour: hour,
            minute: minute
        ))!
    }
}

final class UpdateConfigurationTests: XCTestCase {
    func testBundledUpdateConfigurationUsesHTTPSAndSignedArchives() throws {
        let info = try XCTUnwrap(Bundle.main.infoDictionary)
        let feedValue = try XCTUnwrap(info["SUFeedURL"] as? String)
        let feedURL = try XCTUnwrap(URL(string: feedValue))
        let publicKey = try XCTUnwrap(info["SUPublicEDKey"] as? String)

        XCTAssertEqual(feedURL.scheme, "https")
        XCTAssertFalse(publicKey.isEmpty)
        XCTAssertEqual(info["SUVerifyUpdateBeforeExtraction"] as? Bool, true)
        XCTAssertEqual(info["SUEnableSystemProfiling"] as? Bool, false)
    }
}

private final class ActivityRecorder: @unchecked Sendable, ActivityPosting {
    var hasPermission: Bool
    private(set) var postCount = 0

    init(hasPermission: Bool) {
        self.hasPermission = hasPermission
    }

    func hasAccessibilityPermission() -> Bool {
        hasPermission
    }

    func requestAccessibilityPermission() -> Bool {
        hasPermission
    }

    func postActivity() throws {
        postCount += 1
    }
}

@MainActor
private final class ScheduleBoundarySchedulerSpy: ScheduleBoundaryScheduling {
    private(set) var scheduledDelay: TimeInterval?
    private(set) var scheduledAction: (@MainActor @Sendable () -> Void)?

    func schedule(
        after delay: TimeInterval,
        action: @escaping @MainActor @Sendable () -> Void
    ) {
        scheduledDelay = delay
        scheduledAction = action
    }

    func cancel() {
        scheduledDelay = nil
        scheduledAction = nil
    }

    func fire() {
        let action = scheduledAction
        scheduledAction = nil
        action?()
    }
}
