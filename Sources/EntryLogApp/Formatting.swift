import Foundation
import CalEntryCore

/// Dates, in the few shapes the window needs them.
struct Formatting {

    let timeZone: TimeZone

    private func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = format
        return formatter
    }

    func stamp(_ date: Date) -> String { formatter("yyyy/MM/dd HH:mm").string(from: date) }
    func day(_ date: Date) -> String { formatter("yyyy/MM/dd").string(from: date) }
    func clock(_ date: Date) -> String { formatter("HH:mm").string(from: date) }

    /// When an entry runs, as one line. The date is not repeated when
    /// it has not changed.
    func when(_ entry: CalendarEntry) -> String? {

        guard let start = entry.startDate else { return nil }

        let length = entry.duration(in: timeZone)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        guard let end = entry.endDate, end > start else {
            return entry.isAllDay ? "\(day(start)) (all day)" : stamp(start)
        }

        let sameDay = calendar.isDate(start, inSameDayAs: end)

        if entry.isAllDay {
            return sameDay
                ? "\(day(start)) (all day)"
                : "\(day(start)) - \(day(end)) (\(length ?? "all day"))"
        }

        let finish = sameDay ? clock(end) : stamp(end)
        let tail = length.map { " (\($0))" } ?? ""

        return "\(stamp(start)) - \(finish)\(tail)"
    }
}
