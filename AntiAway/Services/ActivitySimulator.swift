import CoreGraphics
import Foundation
import ApplicationServices

protocol ActivityPosting: Sendable {
    func hasAccessibilityPermission() -> Bool
    func requestAccessibilityPermission() -> Bool
    func postActivity() throws
}

enum ActivitySimulationError: LocalizedError {
    case accessibilityDenied
    case eventCreationFailed

    var errorDescription: String? {
        switch self {
        case .accessibilityDenied:
            "Accessibility permission is required to send the activity signal."
        case .eventCreationFailed:
            "macOS could not create the activity event. Please try again."
        }
    }
}

/// Sends the narrowest useful activity signal: a mouse-moved event at the
/// current pointer location. It never changes pointer position or emits keys.
struct ActivitySimulator: ActivityPosting {
    func hasAccessibilityPermission() -> Bool {
        // CGPreflightPostEventAccess is the authoritative check for Quartz
        // event posting. The modern Accessibility trust API is a useful
        // fallback while System Settings is propagating a newly granted
        // entitlement.
        CGPreflightPostEventAccess() || AXIsProcessTrustedWithOptions(nil)
    }

    /// Calling this may show the system Accessibility consent prompt.
    func requestAccessibilityPermission() -> Bool {
        CGRequestPostEventAccess()
    }

    func postActivity() throws {
        guard hasAccessibilityPermission() else {
            throw ActivitySimulationError.accessibilityDenied
        }

        // Read the location from Quartz itself. AppKit's mouseLocation uses a
        // different origin on macOS and can produce an unintended jump when
        // passed directly to CGEvent.
        guard let pointerLocation = CGEvent(source: nil)?.location else {
            throw ActivitySimulationError.eventCreationFailed
        }

        guard let event = CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: pointerLocation,
            mouseButton: .left
        ) else {
            throw ActivitySimulationError.eventCreationFailed
        }

        // Posting at the existing location makes this visually inert. The event
        // is still observable as system activity by apps that honor it.
        event.post(tap: .cghidEventTap)
    }
}
