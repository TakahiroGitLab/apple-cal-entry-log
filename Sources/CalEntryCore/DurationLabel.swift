import Foundation

/// How long an entry lasts, as something short enough to sit on the
/// same line as when it starts.
public enum DurationLabel {

    /// "45m", "2h", "1h30m", "1d 6h", or "3 days" for an all-day
    /// entry. Nil when there is nothing sensible to say.
    public static func from(
        start: Date?,
        end: Date?,
        isAllDay: Bool,
        timeZone: TimeZone,
        calendar: Calendar = .init(identifier: .gregorian)
    ) -> String? {

        guard let start, let end, end > start else { return nil }

        var calendar = calendar
        calendar.timeZone = timeZone

        if isAllDay { return allDayLabel(start: start, end: end, calendar: calendar) }

        let minutes = Int(end.timeIntervalSince(start) / 60)

        guard minutes > 0 else { return nil }

        return timedLabel(minutes: minutes)
    }

    /// An all-day entry ends at the last moment of its final day, so
    /// the day count is inclusive of both ends.
    private static func allDayLabel(
        start: Date, end: Date, calendar: Calendar
    ) -> String? {

        let span = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: start),
            to: calendar.startOfDay(for: end)
        )

        guard let elapsed = span.day else { return nil }

        let days = elapsed + 1

        return days == 1 ? "1 day" : "\(days) days"
    }

    private static func timedLabel(minutes: Int) -> String {

        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours == 0 { return "\(remainingMinutes)m" }

        // Past a day, hours stop being easy to read at a glance.
        if hours >= 24 {
            let days = hours / 24
            let remainingHours = hours % 24

            return remainingHours == 0
                ? "\(days)d"
                : "\(days)d \(remainingHours)h"
        }

        return remainingMinutes == 0 ? "\(hours)h" : "\(hours)h\(remainingMinutes)m"
    }
}
