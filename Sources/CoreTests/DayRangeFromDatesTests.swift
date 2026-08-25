import Foundation
import CalEntryCore

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
