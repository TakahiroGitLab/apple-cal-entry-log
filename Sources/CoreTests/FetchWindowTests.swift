import Foundation
import CalEntryCore

func fetchWindowTests(_ h: Harness) {

    h.suite("Fetch window") { h in

        h.test("The window always covers the days asked for") {
            let range = try Fixture.range("2026-08-18", "2026-08-20")

            let window = FetchWindowPolicy.standard.window(
                for: range, timeZone: Fixture.tokyo
            )

            h.expect(window.start <= range.start, "reaches the first day")
            h.expect(window.end >= range.endExclusive, "reaches the last day")
        }

        h.test("It reaches further ahead than behind") {
            let range = try Fixture.range("2026-08-20", "2026-08-20")

            let window = FetchWindowPolicy.standard.window(
                for: range, timeZone: Fixture.tokyo
            )

            h.equal(window.start, Fixture.date(2025, 8, 20), "a year behind")
            h.equal(window.end, Fixture.date(2028, 8, 21), "two years ahead")
        }

        h.test("A long range is trimmed at the past end, not the future one") {
            // Three years of days, plus a year behind and two ahead,
            // would be six years -- more than EventKit will accept.
            let range = try Fixture.range("2023-01-01", "2025-12-31")

            let window = FetchWindowPolicy.standard.window(
                for: range, timeZone: Fixture.tokyo
            )

            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = Fixture.tokyo

            let months = calendar.dateComponents(
                [.month], from: window.start, to: window.end
            ).month ?? .max

            h.expect(months <= FetchWindowPolicy.maximumSpanInMonths,
                     "within EventKit's four years, got \(months) months")
            h.equal(window.end, Fixture.date(2028, 1, 1), "future end kept")
        }

        h.test("Trimming can undercut the range itself, which is a real gap") {
            let range = try Fixture.range("2015-01-01", "2025-12-31")

            let window = FetchWindowPolicy.standard.window(
                for: range, timeZone: Fixture.tokyo
            )

            // Documented, not desired: past about four years the
            // window can no longer reach the start of the range, so
            // entries both written and happening early in it are
            // missed. The UI has to keep ranges short rather than rely
            // on this.
            h.expect(window.start > range.start, "the gap is real")
        }

        h.test("A custom policy is honoured") {
            let range = try Fixture.range("2026-08-20", "2026-08-20")

            let window = FetchWindowPolicy(monthsBefore: 1, monthsAfter: 1)
                .window(for: range, timeZone: Fixture.tokyo)

            h.equal(window.start, Fixture.date(2026, 7, 20), "a month behind")
            h.equal(window.end, Fixture.date(2026, 9, 21), "a month ahead")
        }
    }
}
