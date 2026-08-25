import Foundation
import CalEntryCore

enum Fixture {

    static let tokyo = TimeZone(identifier: "Asia/Tokyo")!
    static let newYork = TimeZone(identifier: "America/New_York")!

    static func date(
        _ year: Int, _ month: Int, _ day: Int,
        _ hour: Int = 0, _ minute: Int = 0, _ second: Int = 0,
        in zone: TimeZone = tokyo
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone

        return calendar.date(from: DateComponents(
            year: year, month: month, day: day,
            hour: hour, minute: minute, second: second
        ))!
    }

    static func range(
        _ startDay: String, _ endDay: String,
        in zone: TimeZone = tokyo
    ) throws -> DayRange {
        try DayRange.between(
            startDay: startDay, endDay: endDay, timeZone: zone
        )
    }

    static let me = Participant(
        name: "Takahiro", email: "me@example.com", isCurrentUser: true
    )

    static let colleague = Participant(
        name: "Dr Sato", email: "sato@example.com"
    )

    static let operatingRoom = Participant(
        name: "OR 3", email: "or3@example.com", kind: .room
    )

    /// An entry with no invitees, on a calendar the user can write to.
    static func plain(
        _ id: String,
        created: Date?,
        title: String = "Follow-up",
        writable: Bool = true
    ) -> CalendarEntry {
        CalendarEntry(
            id: id,
            title: title,
            creationDate: created,
            startDate: created,
            calendarTitle: "Personal",
            calendarIsWritable: writable
        )
    }

    /// A meeting, with whoever set it up as organizer.
    static func meeting(
        _ id: String,
        created: Date?,
        organizer: Participant,
        attendees: [Participant],
        title: String = "Pre-op review"
    ) -> CalendarEntry {
        CalendarEntry(
            id: id,
            title: title,
            creationDate: created,
            startDate: created,
            calendarTitle: "Work",
            calendarIsWritable: true,
            organizer: organizer,
            attendees: attendees
        )
    }
}
