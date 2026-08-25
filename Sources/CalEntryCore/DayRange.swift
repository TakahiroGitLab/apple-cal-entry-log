import Foundation

/// A span of whole days, resolved to absolute instants.
///
/// Half-open: `start` is midnight on the first day, `endExclusive` is
/// midnight on the day *after* the last, so an entry written at 23:59
/// on the final day is included.
public struct DayRange: Sendable, Equatable {

    public let start: Date
    public let endExclusive: Date

    public init(start: Date, endExclusive: Date) {
        self.start = start
        self.endExclusive = endExclusive
    }

    public func contains(_ date: Date) -> Bool {
        date >= start && date < endExclusive
    }
}


public enum DayRangeError: Error, Equatable, CustomStringConvertible {

    case missingDay
    case malformedDay(String)
    case startAfterEnd(start: String, end: String)

    public var description: String {
        switch self {
        case .missingDay:
            return "Please select both a start and an end date."
        case .malformedDay(let text):
            return "\(text) is not a date in yyyy-MM-dd form."
        case .startAfterEnd(let start, let end):
            return "Start date must be on or before end date (\(start) is after \(end))."
        }
    }
}


extension DayRange {

    /// Build a range from two `yyyy-MM-dd` strings, read in the given
    /// time zone.
    ///
    /// The end day is widened to its own midnight-to-midnight span by
    /// calendar arithmetic rather than by adding 86 400 seconds, so a
    /// range crossing a daylight-saving change still covers whole days.
    public static func between(
        startDay: String,
        endDay: String,
        timeZone: TimeZone,
        calendar: Calendar = .init(identifier: .gregorian)
    ) throws -> DayRange {

        guard !startDay.isEmpty, !endDay.isEmpty else {
            throw DayRangeError.missingDay
        }

        var calendar = calendar
        calendar.timeZone = timeZone

        let start = try midnight(on: startDay, calendar: calendar)
        let lastDay = try midnight(on: endDay, calendar: calendar)

        guard start <= lastDay else {
            throw DayRangeError.startAfterEnd(start: startDay, end: endDay)
        }

        guard let endExclusive = calendar.date(
            byAdding: .day, value: 1, to: lastDay
        ) else {
            throw DayRangeError.malformedDay(endDay)
        }

        return DayRange(start: start, endExclusive: endExclusive)
    }

    /// Midnight on a single day, in the calendar's time zone.
    private static func midnight(
        on day: String,
        calendar: Calendar
    ) throws -> Date {

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false

        guard let parsed = formatter.date(from: day),
              // The formatter rolls impossible days over rather than
              // refusing them, so 2026-02-31 only shows up as a
              // mismatch on the way back out.
              formatter.string(from: parsed) == day
        else {
            throw DayRangeError.malformedDay(day)
        }

        return calendar.startOfDay(for: parsed)
    }
}
