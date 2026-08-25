import Foundation
import CalEntryCore

func dayRangeTests(_ h: Harness) {

    h.suite("Day range") { h in

        h.test("A single day runs from its midnight to the next") {
            let range = try Fixture.range("2026-08-20", "2026-08-20")

            h.equal(range.start, Fixture.date(2026, 8, 20, 0, 0, 0), "start")
            h.equal(range.endExclusive,
                    Fixture.date(2026, 8, 21, 0, 0, 0), "endExclusive")
        }

        h.test("The last day is included right up to its final second") {
            let range = try Fixture.range("2026-08-18", "2026-08-20")

            h.expect(range.contains(Fixture.date(2026, 8, 18, 0, 0, 0)),
                     "first midnight is in")
            h.expect(range.contains(Fixture.date(2026, 8, 20, 23, 59, 59)),
                     "last second is in")
            h.expect(!range.contains(Fixture.date(2026, 8, 21, 0, 0, 0)),
                     "next midnight is out")
            h.expect(!range.contains(Fixture.date(2026, 8, 17, 23, 59, 59)),
                     "the second before is out")
        }

        h.test("Days stay whole across a daylight-saving change") {
            // Clocks in New York go forward on 8 March 2026.
            let range = try DayRange.between(
                startDay: "2026-03-08", endDay: "2026-03-08",
                timeZone: Fixture.newYork
            )

            // 23 hours of real time, but still exactly one calendar
            // day -- which adding 86 400 seconds would have got wrong.
            h.equal(range.endExclusive.timeIntervalSince(range.start),
                    23 * 3600, "span in seconds")
            h.expect(range.contains(
                Fixture.date(2026, 3, 8, 23, 30, in: Fixture.newYork)
            ), "late evening is still that day")
        }

        h.test("The same days mean different instants in different zones") {
            let tokyo = try Fixture.range("2026-08-20", "2026-08-20")
            let newYork = try Fixture.range(
                "2026-08-20", "2026-08-20", in: Fixture.newYork
            )

            h.expect(tokyo.start != newYork.start, "zone shifts the boundary")
        }

        h.test("A missing day is refused") {
            h.throwsError(DayRangeError.missingDay, "empty start") {
                try Fixture.range("", "2026-08-20")
            }
            h.throwsError(DayRangeError.missingDay, "empty end") {
                try Fixture.range("2026-08-20", "")
            }
        }

        h.test("Days that are not dates are refused") {
            for text in [
                "20/08/2026", "2026-8-20", "tomorrow", "2026-02-31", "2026-13-01"
            ] {
                h.throwsError(DayRangeError.malformedDay(text), text) {
                    try Fixture.range(text, "2026-08-20")
                }
            }
        }

        h.test("A backwards range is refused") {
            h.throwsError(
                DayRangeError.startAfterEnd(start: "2026-08-21", end: "2026-08-20"),
                "start after end"
            ) {
                try Fixture.range("2026-08-21", "2026-08-20")
            }
        }

        h.test("Errors read as something worth showing on screen") {
            h.equal(DayRangeError.missingDay.description,
                    "Please select both a start and an end date.", "missingDay")
            h.expect(
                DayRangeError.malformedDay("nope").description
                    .contains("yyyy-MM-dd"),
                "malformedDay names the expected form"
            )
        }
    }
}
