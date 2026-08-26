import Foundation
import CalEntryCore

func pinpointTests(_ h: Harness) {

    h.suite("Pinpointable") { h in

        func entry(
            externalId: String? = "UID-1",
            recurring: Bool = false,
            calendar: String = "Work"
        ) -> CalendarEntry {
            CalendarEntry(
                id: "1",
                externalId: externalId,
                title: "Ward round",
                creationDate: Fixture.date(2026, 8, 20),
                startDate: Fixture.date(2026, 8, 21),
                isRecurring: recurring,
                calendarTitle: calendar
            )
        }

        h.test("A one-off entry with a sync identifier can be selected") {
            h.equal(entry().isPinpointable, true, "pinpointable")
        }

        h.test("A repeating entry cannot: its occurrences share one identifier") {
            h.equal(entry(recurring: true).isPinpointable, false, "pinpointable")
        }

        h.test("An entry that has never synced has no identifier to look up") {
            h.equal(entry(externalId: nil).isPinpointable, false, "pinpointable")
            h.equal(entry(externalId: "").isPinpointable, false, "pinpointable")
        }

        h.test("An unnamed calendar cannot be looked up in") {
            h.equal(entry(calendar: "").isPinpointable, false, "pinpointable")
        }
    }
}
