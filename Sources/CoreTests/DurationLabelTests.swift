import Foundation
import CalEntryCore

func durationLabelTests(_ h: Harness) {

    func label(
        _ start: Date?, _ end: Date?, allDay: Bool = false
    ) -> String? {
        DurationLabel.from(
            start: start, end: end, isAllDay: allDay, timeZone: Fixture.tokyo
        )
    }

    h.suite("Duration") { h in

        h.test("Under an hour reads in minutes") {
            h.equal(label(Fixture.date(2026, 8, 20, 9, 0),
                          Fixture.date(2026, 8, 20, 9, 45)),
                    "45m", "45 minutes")
        }

        h.test("A whole number of hours drops the minutes") {
            h.equal(label(Fixture.date(2026, 8, 20, 9, 0),
                          Fixture.date(2026, 8, 20, 11, 0)),
                    "2h", "two hours")
        }

        h.test("Otherwise both are shown") {
            h.equal(label(Fixture.date(2026, 8, 20, 9, 0),
                          Fixture.date(2026, 8, 20, 10, 30)),
                    "1h30m", "an hour and a half")
        }

        h.test("Past a day, hours stop being readable and days take over") {
            h.equal(label(Fixture.date(2026, 8, 20, 9, 0),
                          Fixture.date(2026, 8, 21, 15, 0)),
                    "1d 6h", "thirty hours")
            h.equal(label(Fixture.date(2026, 8, 20, 9, 0),
                          Fixture.date(2026, 8, 22, 9, 0)),
                    "2d", "exactly two days")
        }

        h.test("An all-day entry counts days, both ends included") {
            // EventKit ends an all-day entry at the last moment of its
            // final day, not the next midnight.
            h.equal(label(Fixture.date(2026, 8, 20, 0, 0),
                          Fixture.date(2026, 8, 20, 23, 59, 59),
                          allDay: true),
                    "1 day", "one day")
            h.equal(label(Fixture.date(2026, 8, 20, 0, 0),
                          Fixture.date(2026, 8, 22, 23, 59, 59),
                          allDay: true),
                    "3 days", "three days")
        }

        h.test("Nothing sensible to say means nothing is said") {
            h.isNil(label(nil, Fixture.date(2026, 8, 20, 9, 0)), "no start")
            h.isNil(label(Fixture.date(2026, 8, 20, 9, 0), nil), "no end")
            h.isNil(label(Fixture.date(2026, 8, 20, 9, 0),
                          Fixture.date(2026, 8, 20, 9, 0)), "no length")
            h.isNil(label(Fixture.date(2026, 8, 20, 9, 0),
                          Fixture.date(2026, 8, 20, 8, 0)), "ends before it starts")
        }
    }
}


func noteSummaryTests(_ h: Harness) {

    h.suite("Note summary") { h in

        h.test("A short note comes through whole") {
            h.equal(NoteSummary.oneLine("Bring the consent form"),
                    "Bring the consent form", "note")
        }

        h.test("Several lines are flattened into one") {
            h.equal(NoteSummary.oneLine("Consent form\nX-rays\n\nBloods"),
                    "Consent form X-rays Bloods", "note")
        }

        h.test("A long note is cut and marked") {
            let long = String(repeating: "a", count: 200)

            let summary = NoteSummary.oneLine(long, limit: 10)

            h.equal(summary, String(repeating: "a", count: 10) + "…", "note")
        }

        h.test("A note exactly at the limit is not marked") {
            h.equal(NoteSummary.oneLine("abcde", limit: 5), "abcde", "note")
        }

        h.test("Counting is by character, so Japanese is not cut short") {
            // Ten characters, thirty bytes in UTF-8. Cutting on bytes
            // would take three of them and could split one in half.
            let japanese = "手術予定確認外来記録"

            h.equal(NoteSummary.oneLine(japanese, limit: 10), japanese, "whole")
            h.equal(NoteSummary.oneLine(japanese, limit: 4), "手術予定…", "cut")
        }

        h.test("Nothing worth showing shows nothing") {
            h.isNil(NoteSummary.oneLine(nil), "no note")
            h.isNil(NoteSummary.oneLine(""), "empty")
            h.isNil(NoteSummary.oneLine("  \n\t "), "only whitespace")
        }
    }
}
