import Foundation
import CalEntryCore

/// Written just before the 18th, on its midnight, mid-range, on the
/// last second of the 20th, and just after -- so both boundaries of an
/// 18th-to-20th range are exercised by real entries on either side.
private func spread() -> [CalendarEntry] {
    [
        Fixture.plain("before",
                      created: Fixture.date(2026, 8, 17, 23, 59, 59),
                      title: "Too early"),
        Fixture.plain("first",
                      created: Fixture.date(2026, 8, 18, 0, 0, 0),
                      title: "On the first midnight"),
        Fixture.meeting("middle",
                        created: Fixture.date(2026, 8, 19, 10, 0),
                        organizer: Fixture.colleague,
                        attendees: [Fixture.me],
                        title: "Invited"),
        Fixture.plain("last",
                      created: Fixture.date(2026, 8, 20, 23, 59, 59),
                      title: "On the last second"),
        Fixture.plain("after",
                      created: Fixture.date(2026, 8, 21, 0, 0, 0),
                      title: "Too late")
    ]
}

func entryLogTests(_ h: Harness) {

    h.suite("Entry log") { h in

        h.test("Only the entries written inside the range come back") {
            let log = EntryLog.entries(
                from: spread(),
                createdIn: try Fixture.range("2026-08-18", "2026-08-20")
            )

            h.equal(log.map(\.id), ["first", "middle", "last"], "ids")
        }

        h.test("The log is in the order things were written") {
            let log = EntryLog.entries(
                from: spread().reversed(),
                createdIn: try Fixture.range("2026-08-18", "2026-08-20")
            )

            h.equal(log.map(\.creationDate),
                    log.map(\.creationDate).sorted(), "creation order")
        }

        h.test("Entries written in the same second keep a stable order") {
            let sameMoment = Fixture.date(2026, 8, 19, 9, 0)

            let entries = [
                Fixture.plain("z", created: sameMoment, title: "B"),
                Fixture.plain("a", created: sameMoment, title: "B"),
                Fixture.plain("m", created: sameMoment, title: "A")
            ]

            let log = EntryLog.entries(
                from: entries,
                createdIn: try Fixture.range("2026-08-19", "2026-08-19")
            )

            h.equal(log.map(\.id), ["m", "a", "z"], "title then id")
        }

        h.test("An entry with no creation date is left out, not guessed at") {
            let log = EntryLog.entries(
                from: [Fixture.plain("unknown", created: nil)],
                createdIn: try Fixture.range("2026-08-01", "2026-12-31")
            )

            h.expect(log.isEmpty, "dropped")
        }

        h.test("Entries the user has no part in never appear") {
            let entries = [
                Fixture.meeting("theirs",
                                created: Fixture.date(2026, 8, 19),
                                organizer: Fixture.colleague,
                                attendees: [Fixture.colleague]),
                Fixture.plain("holiday",
                              created: Fixture.date(2026, 8, 19),
                              writable: false)
            ]

            let log = EntryLog.entries(
                from: entries,
                createdIn: try Fixture.range("2026-08-19", "2026-08-19")
            )

            h.expect(log.isEmpty, "both left out")
        }

        h.test("Each role can be asked for on its own") {
            let range = try Fixture.range("2026-08-18", "2026-08-20")
            let entries = spread()

            let created = EntryLog.entries(
                from: entries, createdIn: range, roles: [.created]
            )
            let invited = EntryLog.entries(
                from: entries, createdIn: range, roles: [.invited]
            )

            h.equal(created.map(\.id), ["first", "last"], "created")
            h.equal(invited.map(\.id), ["middle"], "invited")
            h.expect(created.allSatisfy { $0.role == .created },
                     "every row carries its role")
        }

        h.test("Both roles together list everything exactly once") {
            let range = try Fixture.range("2026-08-18", "2026-08-20")
            let entries = spread()

            let both = EntryLog.entries(from: entries, createdIn: range)
            let separately =
                EntryLog.entries(from: entries, createdIn: range, roles: [.created])
                + EntryLog.entries(from: entries, createdIn: range, roles: [.invited])

            h.equal(both.count, separately.count, "no double counting")
            h.equal(Set(both.map(\.id)), Set(separately.map(\.id)), "same entries")
        }

        h.test("Asking for no roles shows nothing") {
            let log = EntryLog.entries(
                from: spread(),
                createdIn: try Fixture.range("2026-08-18", "2026-08-20"),
                roles: []
            )

            h.expect(log.isEmpty, "both boxes unticked")
        }
    }
}
