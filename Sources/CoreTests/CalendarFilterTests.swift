import Foundation
import CalEntryCore

func calendarFilterTests(_ h: Harness) {

    h.suite("Calendar filter") { h in

        h.test("Every demo entry names the calendar it is on") {
            let entries = DemoLog.entries()
            let known = Set(DemoLog.calendars.map(\.id))

            for entry in entries {
                h.expect(
                    known.contains(entry.calendarId),
                    "\(entry.displayTitle) is on a calendar the filter offers"
                )
            }
        }

        h.test("The demo offers both of its calendars something to show") {
            let entries = DemoLog.entries()

            for calendar in DemoLog.calendars {
                h.expect(
                    entries.contains { $0.calendarId == calendar.id },
                    "\(calendar.title) has at least one entry"
                )
            }
        }
    }
}
