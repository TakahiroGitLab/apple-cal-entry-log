import Foundation
import CalEntryCore

func roleTests(_ h: Harness) {

    h.suite("Role") { h in

        h.test("The organiser being the user means created") {
            let entry = Fixture.meeting(
                "1", created: Fixture.date(2026, 8, 20),
                organizer: Fixture.me,
                attendees: [Fixture.colleague]
            )

            h.equal(entry.role, .created, "role")
        }

        h.test("Someone else's meeting with the user on the list means invited") {
            let entry = Fixture.meeting(
                "2", created: Fixture.date(2026, 8, 20),
                organizer: Fixture.colleague,
                attendees: [Fixture.colleague, Fixture.me]
            )

            h.equal(entry.role, .invited, "role")
        }

        h.test("Someone else's meeting the user is not on means neither") {
            let entry = Fixture.meeting(
                "3", created: Fixture.date(2026, 8, 20),
                organizer: Fixture.colleague,
                attendees: [Fixture.colleague]
            )

            h.isNil(entry.role, "role")
        }

        h.test("Organising something the user also attends counts once, as created") {
            let entry = Fixture.meeting(
                "4", created: Fixture.date(2026, 8, 20),
                organizer: Fixture.me,
                attendees: [Fixture.me, Fixture.colleague]
            )

            h.equal(entry.role, .created, "role")
        }

        h.test("A plain entry on a writable calendar is the user's own") {
            let entry = Fixture.plain("5", created: Fixture.date(2026, 8, 20))

            h.equal(entry.role, .created, "role")
        }

        h.test("A plain entry on a read-only calendar is nobody's") {
            let entry = Fixture.plain(
                "6", created: Fixture.date(2026, 8, 20),
                title: "Public holiday", writable: false
            )

            h.isNil(entry.role, "role")
        }
    }


    h.suite("Participants") { h in

        h.test("Rooms are listed apart from guests") {
            let entry = Fixture.meeting(
                "7", created: Fixture.date(2026, 8, 20),
                organizer: Fixture.me,
                attendees: [Fixture.colleague, Fixture.operatingRoom, Fixture.me]
            )

            h.equal(entry.rooms, ["OR 3"], "rooms")
            // The user's own name is not news to the user.
            h.equal(entry.guests, ["Dr Sato"], "guests")
        }

        h.test("A participant with no name falls back to the address") {
            h.equal(
                Participant(email: "anon@example.com").label,
                "anon@example.com", "label"
            )
            h.equal(Participant().label, "(unnamed)", "empty label")
        }

        h.test("The organiser is only named when it is not the user") {
            let mine = Fixture.meeting(
                "8", created: nil, organizer: Fixture.me, attendees: []
            )
            let theirs = Fixture.meeting(
                "9", created: nil, organizer: Fixture.colleague,
                attendees: [Fixture.me]
            )

            h.isNil(mine.organizerLabel, "own entry")
            h.equal(theirs.organizerLabel, "Dr Sato", "someone else's entry")
        }

        h.test("An untitled entry still shows something") {
            h.equal(
                Fixture.plain("10", created: nil, title: "").displayTitle,
                "(No title)", "displayTitle"
            )
        }
    }
}
