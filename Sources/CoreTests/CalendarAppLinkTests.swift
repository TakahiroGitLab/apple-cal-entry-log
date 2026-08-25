import Foundation
import CalEntryCore

func calendarAppLinkTests(_ h: Harness) {

    h.suite("Calendar link") { h in

        h.test("An identifier becomes a link Calendar understands") {
            h.equal(CalendarAppLink.show("ABC123")?.absoluteString,
                    "ical://ekevent/ABC123?method=show&options=more", "link")
        }

        h.test("Characters that would break the link are escaped") {
            // An identifier ending the path or opening a query would
            // send Calendar somewhere else entirely.
            let link = CalendarAppLink.show("a/b?c=d&e")?.absoluteString

            h.equal(link,
                    "ical://ekevent/a%2Fb%3Fc%3Dd%26e?method=show&options=more",
                    "link")
        }

        h.test("An entry that has never synced has no link") {
            h.isNil(CalendarAppLink.show(nil), "no identifier")
            h.isNil(CalendarAppLink.show(""), "empty identifier")
        }
    }
}


func dayRangeFromDatesTests(_ h: Harness) {

    h.suite("Range from picked dates") { h in

        h.test("The whole day is taken, whatever time was picked") {
            let range = try DayRange.covering(
                Fixture.date(2026, 8, 18, 16, 42),
                through: Fixture.date(2026, 8, 20, 3, 5),
                timeZone: Fixture.tokyo
            )

            h.equal(range.start, Fixture.date(2026, 8, 18, 0, 0), "from midnight")
            h.equal(range.endExclusive,
                    Fixture.date(2026, 8, 21, 0, 0), "to the next midnight")
        }

        h.test("One day picked twice is one whole day") {
            let noon = Fixture.date(2026, 8, 20, 12, 0)

            let range = try DayRange.covering(
                noon, through: noon, timeZone: Fixture.tokyo
            )

            h.equal(range.start, Fixture.date(2026, 8, 20, 0, 0), "start")
            h.equal(range.endExclusive, Fixture.date(2026, 8, 21, 0, 0), "end")
        }

        h.test("Backwards is refused, and says which days") {
            h.throwsError(
                DayRangeError.startAfterEnd(start: "2026-08-21", end: "2026-08-20"),
                "backwards"
            ) {
                try DayRange.covering(
                    Fixture.date(2026, 8, 21, 9, 0),
                    through: Fixture.date(2026, 8, 20, 23, 0),
                    timeZone: Fixture.tokyo
                )
            }
        }

        h.test("Later on the same day is not backwards") {
            let range = try DayRange.covering(
                Fixture.date(2026, 8, 20, 23, 0),
                through: Fixture.date(2026, 8, 20, 1, 0),
                timeZone: Fixture.tokyo
            )

            h.equal(range.start, Fixture.date(2026, 8, 20, 0, 0), "same day")
        }
    }
}
