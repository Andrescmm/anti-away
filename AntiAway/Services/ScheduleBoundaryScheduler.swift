import Foundation

@MainActor
protocol ScheduleBoundaryScheduling: AnyObject {
    func schedule(
        after delay: TimeInterval,
        action: @escaping @MainActor @Sendable () -> Void
    )
    func cancel()
}

/// Runs schedule boundaries independently of the menu-bar popover's run loop.
/// ContinuousClock advances while the Mac sleeps, so an elapsed boundary is
/// handled as soon as the process is scheduled again after wake.
@MainActor
final class ScheduleBoundaryScheduler: ScheduleBoundaryScheduling {
    private var task: Task<Void, Never>?

    deinit {
        task?.cancel()
    }

    func schedule(
        after delay: TimeInterval,
        action: @escaping @MainActor @Sendable () -> Void
    ) {
        cancel()

        let safeDelay = max(0, delay)
        task = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(
                    for: .seconds(safeDelay),
                    tolerance: .seconds(1),
                    clock: .continuous
                )
            } catch {
                return
            }

            guard let self, !Task.isCancelled else { return }
            self.task = nil
            action()
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}
