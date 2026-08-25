import Foundation
import CalEntryCore

func fetchPlanTests(_ h: Harness) {

    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Fixture.tokyo
        return calendar
    }()

    func months(_ window: FetchWindow) -> Int {
        calendar.dateComponents(
            [.month], from: window.start, to: window.end
        ).month ?? .max
    }

    h.suite("Fetch plan") { h in

        h.test("The plan covers the days asked for") {
            let range = try Fixture.range("2026-08-18", "2026-08-20")

            let plan = FetchPlanner.standard.plan(
                for: range, timeZone: Fixture.tokyo
            )

            h.expect(plan.span.start <= range.start, "reaches the first day")
            h.expect(plan.span.end >= range.endExclusive, "reaches the last day")
        }

        h.test("It reaches a decade either side") {
            let range = try Fixture.range("2026-08-20", "2026-08-20")

            let plan = FetchPlanner.standard.plan(
                for: range, timeZone: Fixture.tokyo
            )

            h.equal(plan.span.start, Fixture.date(2016, 8, 20), "ten years back")
            h.equal(plan.span.end, Fixture.date(2036, 8, 21), "ten years on")
        }

        h.test("No single window exceeds what EventKit will accept") {
            let range = try Fixture.range("2026-08-20", "2026-08-20")

            let plan = FetchPlanner.standard.plan(
                for: range, timeZone: Fixture.tokyo
            )

            for window in plan.windows {
                h.expect(
                    months(window) <= FetchPlanner.maximumWindowInMonths,
                    "window of \(months(window)) months is within the limit"
                )
            }
        }

        h.test("The windows abut, leaving no day unsearched") {
            let range = try Fixture.range("2026-08-20", "2026-08-20")

            let plan = FetchPlanner.standard.plan(
                for: range, timeZone: Fixture.tokyo
            )

            h.equal(plan.windows.first?.start, plan.span.start, "starts at the span")
            h.equal(plan.windows.last?.end, plan.span.end, "ends at the span")

            for (earlier, later) in zip(plan.windows, plan.windows.dropFirst()) {
                h.equal(earlier.end, later.start, "no gap between windows")
            }
        }

        h.test("A span far beyond four years is simply cut into more windows") {
            let range = try Fixture.range("2015-01-01", "2025-12-31")

            let plan = FetchPlanner.standard.plan(
                for: range, timeZone: Fixture.tokyo
            )

            // The whole of a thirty-one year span is searched. This is
            // the difference from a single bounded window, which had
            // to give up the far end and silently miss entries.
            h.equal(plan.span.start, Fixture.date(2005, 1, 1), "the earliest day")
            h.equal(plan.span.end, Fixture.date(2036, 1, 1), "the latest day")
            h.expect(plan.windows.count >= 8,
                     "cut into \(plan.windows.count) windows")

            for window in plan.windows {
                h.expect(months(window) <= FetchPlanner.maximumWindowInMonths,
                         "each window stays within the limit")
            }
        }

        h.test("A narrower policy is honoured") {
            let range = try Fixture.range("2026-08-20", "2026-08-20")

            let plan = FetchPlanner(yearsBefore: 1, yearsAfter: 1)
                .plan(for: range, timeZone: Fixture.tokyo)

            h.equal(plan.span.start, Fixture.date(2025, 8, 20), "a year behind")
            h.equal(plan.span.end, Fixture.date(2027, 8, 21), "a year ahead")
            h.equal(plan.windows.count, 1, "fits in one query")
        }

        h.test("Searching only the range itself still yields a window") {
            let range = try Fixture.range("2026-08-20", "2026-08-20")

            let plan = FetchPlanner(yearsBefore: 0, yearsAfter: 0)
                .plan(for: range, timeZone: Fixture.tokyo)

            h.equal(plan.windows.count, 1, "one window")
            h.equal(plan.windows.first?.start, range.start, "the range start")
            h.equal(plan.windows.first?.end, range.endExclusive, "the range end")
        }
    }
}
