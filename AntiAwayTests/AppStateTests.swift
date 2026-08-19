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

    private func makeDefaults() -> UserDefaults {
        let suiteName = "AppStateTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
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
