import Foundation

struct DailySchedule: Equatable, Sendable {
    static let minutesPerDay = 24 * 60

    let startMinutes: Int
    let endMinutes: Int

    init(startMinutes: Int, endMinutes: Int) {
        self.startMinutes = Self.normalized(startMinutes)
        self.endMinutes = Self.normalized(endMinutes)
    }

    /// Equal start and end times represent an all-day schedule.
    func contains(_ date: Date, calendar: Calendar = .autoupdatingCurrent) -> Bool {
        guard startMinutes != endMinutes else { return true }

        let components = calendar.dateComponents([.hour, .minute], from: date)
        let currentMinutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)

        if startMinutes < endMinutes {
            return currentMinutes >= startMinutes && currentMinutes < endMinutes
        }

        // Overnight window, for example 22:00–06:00.
        return currentMinutes >= startMinutes || currentMinutes < endMinutes
    }

    func nextBoundary(after date: Date, calendar: Calendar = .autoupdatingCurrent) -> Date? {
        guard startMinutes != endMinutes else { return nil }

        return [startMinutes, endMinutes]
            .compactMap { minutes in
                calendar.nextDate(
                    after: date,
                    matching: DateComponents(
                        hour: minutes / 60,
                        minute: minutes % 60,
                        second: 0
                    ),
                    matchingPolicy: .nextTime,
                    repeatedTimePolicy: .first,
                    direction: .forward
                )
            }
            .min()
    }

    static func minutes(from date: Date, calendar: Calendar = .autoupdatingCurrent) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return normalized((components.hour ?? 0) * 60 + (components.minute ?? 0))
    }

    static func date(for minutes: Int, referenceDate: Date = .now, calendar: Calendar = .autoupdatingCurrent) -> Date {
        let normalizedMinutes = normalized(minutes)
        return calendar.date(
            bySettingHour: normalizedMinutes / 60,
            minute: normalizedMinutes % 60,
            second: 0,
            of: referenceDate
        ) ?? referenceDate
    }

    private static func normalized(_ minutes: Int) -> Int {
        ((minutes % minutesPerDay) + minutesPerDay) % minutesPerDay
    }
}
