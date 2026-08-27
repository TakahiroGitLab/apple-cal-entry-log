import Foundation
import CalEntryCore

func roomLabelTests(_ h: Harness) {

    h.suite("Room label") { h in

        func room(name: String? = nil, email: String? = nil) -> Participant {
            Participant(name: name, email: email, kind: .room)
        }

        h.test("A named room is called by its name") {
            h.equal(RoomLabel.from(room(name: "OR 3")), "OR 3", "name")
            h.equal(
                RoomLabel.from(room(name: "OR 3", email: "or3@example.com")),
                "OR 3", "name wins over address"
            )
        }

        h.test("A nameless Google resource calendar is left out") {
            h.isNil(
                RoomLabel.from(room(
                    email: "amupras.jp_2d32333033313938392d3436"
                        + "@resource.calendar.google.com"
                )),
                "dropped"
            )
        }

        h.test("The host is matched whatever its case") {
            h.isNil(
                RoomLabel.from(room(email: "x_y@Resource.Calendar.Google.COM")),
                "dropped"
            )
        }

        h.test("Any other address is worth printing") {
            h.equal(
                RoomLabel.from(room(email: "or3@example.com")),
                "or3@example.com", "kept"
            )
        }

        h.test("A room with neither is nothing at all") {
            h.isNil(RoomLabel.from(room()), "dropped")
            h.isNil(RoomLabel.from(room(name: "", email: "")), "dropped")
        }

        h.test("An entry lists only the rooms that have a name") {
            let entry = CalendarEntry(
                id: "1",
                calendarTitle: "Work",
                attendees: [
                    room(name: "Seminar room 4"),
                    room(email: "example.com_abc@resource.calendar.google.com"),
                    Participant(name: "Robin", email: "robin@example.com")
                ]
            )

            h.equal(entry.rooms, ["Seminar room 4"], "rooms")
            h.equal(entry.guests, ["Robin"], "guests")
        }
    }
}
