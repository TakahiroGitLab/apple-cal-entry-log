import Foundation

/// A calendar that does not exist, for screenshots and for looking at
/// the window without a Mac full of real entries.
///
/// Every entry here is invented. That is the point: a listing of a
/// real calendar carries names, addresses and whatever the notes
/// happen to hold, and none of that belongs in a screenshot. The
/// entries are built relative to a reference moment so that Yesterday
/// and Today land on something whatever day it is run.
///
/// It lives in the core rather than the app because it is data, and
/// because the command line can use it too.
public enum DemoLog {

    /// The invented calendars, so that the filter has something to
    /// offer. Their identifiers are their titles, which is what lets
    /// the demo be filtered without inventing a store as well.
    public static let calendars: [CalendarSummary] = [
        CalendarSummary(id: "Home", title: "Home", source: "iCloud"),
        CalendarSummary(id: "Work", title: "Work", source: "iCloud")
    ]

    public static func entries(
        around reference: Date = .now,
        timeZone: TimeZone = .current
    ) -> [CalendarEntry] {

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        /// A time on the day `days` ago.
        func written(_ days: Int, _ hour: Int, _ minute: Int) -> Date {
            let day = calendar.date(byAdding: .day, value: -days, to: reference)
                ?? reference

            return calendar.date(
                bySettingHour: hour, minute: minute, second: 0, of: day
            ) ?? day
        }

        /// A time on the day `days` from now.
        func happening(_ days: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            let day = calendar.date(byAdding: .day, value: days, to: reference)
                ?? reference

            return calendar.date(
                bySettingHour: hour, minute: minute, second: 0, of: day
            ) ?? day
        }

        let me = Participant(
            name: "Ash Miyake", email: "ash@example.com", isCurrentUser: true
        )

        let colleague = Participant(
            name: "Robin Sato", email: "robin@example.com"
        )

        let registrar = Participant(name: "Kim Ono", email: "kim@example.com")

        let room = Participant(name: "Seminar room 4", kind: .room)

        // Booked through Google Workspace, so it has no name and an
        // address that is mostly a generated identifier. It is not
        // listed -- that is the point of it being here.
        let namelessRoom = Participant(
            name: nil,
            email: "example.com_1a2b3c4d5e6f@resource.calendar.google.com",
            kind: .room
        )

        return [

            // Plain, no invitees: the commonest thing in the log, and
            // the case with no organizer to read a role from.
            CalendarEntry(
                id: "demo-1",
                externalId: "demo-1",
                title: "Journal club — read the trial before this",
                creationDate: written(1, 8, 12),
                startDate: happening(6, 18),
                endDate: happening(6, 19),
                calendarId: "Work",
                calendarTitle: "Work",
                calendarSource: "iCloud"
            ),

            // Somebody else's meeting: organizer, guests, a room, and
            // a link back to the mail it arrived in.
            CalendarEntry(
                id: "demo-2",
                externalId: "demo-2",
                title: "Theatre list planning",
                creationDate: written(0, 8, 3),
                startDate: happening(9, 8),
                endDate: happening(9, 12),
                location: "Theatre admin, floor 3",
                notes: "Bring the revised list. Parking is full after 07:30, "
                    + "so the side entrance is the one to use.",
                url: URL(string: "message://%3Cdemo-invite%3E"),
                calendarId: "Work",
                calendarTitle: "Work",
                calendarSource: "iCloud",
                organizer: colleague,
                attendees: [colleague, me, registrar, room, namelessRoom]
            ),

            // All day, and a location as Maps hands it over: name,
            // postcode, address, country.
            CalendarEntry(
                id: "demo-3",
                externalId: "demo-3",
                title: "Conference — day 1",
                creationDate: written(0, 7, 41),
                startDate: happening(21, 0),
                endDate: happening(21, 23, 59),
                isAllDay: true,
                location: "Sakura Convention Centre\n"
                    + "〒123-4567 桜県桜井市桜町 1-2-3\nJapan",
                url: URL(string: "https://www.example.com/conference/2027"),
                calendarId: "Work",
                calendarTitle: "Work",
                calendarSource: "iCloud"
            ),

            // Short, and written minutes ago: what the tool is for.
            CalendarEntry(
                id: "demo-4",
                externalId: "demo-4",
                title: "Ring the lab about Friday's results",
                creationDate: written(0, 9, 26),
                startDate: happening(2, 16),
                endDate: happening(2, 16, 15),
                calendarId: "Work",
                calendarTitle: "Work",
                calendarSource: "iCloud"
            ),

            // A note longer than the line, to show the cut.
            CalendarEntry(
                id: "demo-5",
                externalId: "demo-5",
                title: "Follow-up clinic",
                creationDate: written(0, 11, 58),
                startDate: happening(14, 10),
                endDate: happening(14, 12, 30),
                location: "Outpatients, floor 2",
                notes: "Chase the imaging report, and check whether the "
                    + "referral letter went out. Ask about the dressing.",
                calendarId: "Work",
                calendarTitle: "Work",
                calendarSource: "iCloud"
            ),

            // A note of several lines. This is the shape that used
            // to take the window down when it opened on hover, so it
            // is worth having one to hover over.
            CalendarEntry(
                id: "demo-7",
                externalId: "demo-7",
                title: "Handover",
                creationDate: written(0, 12, 5),
                startDate: happening(1, 8, 30),
                endDate: happening(1, 9),
                notes: """
                    Bed 4 discharge letter still unsigned.
                    Bed 9 waiting on the second sample; chase at 09:00.
                    Theatre list moved to Thursday — tell the ward.
                    Ask about the trainee's rota swap before Friday.
                    """,
                calendarId: "Work",
                calendarTitle: "Work",
                calendarSource: "iCloud"
            ),

            // Not work, so the listing is not all one colour.
            CalendarEntry(
                id: "demo-6",
                externalId: "demo-6",
                title: "Dentist",
                creationDate: written(0, 12, 40),
                startDate: happening(11, 17, 30),
                endDate: happening(11, 18, 15),
                location: "Sakura Dental, 〒123-4567 桜県桜井市桜町 5-6",
                calendarId: "Home",
                calendarTitle: "Home",
                calendarSource: "iCloud"
            )
        ]
    }
}
