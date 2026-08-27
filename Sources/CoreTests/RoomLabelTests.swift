import Foundation
import CalEntryCore

func roomLabelTests(_ h: Harness) {

    h.suite("Room label") { h in

        h.test("A Google resource calendar keeps only its domain") {
            h.equal(
                RoomLabel.tidy(
                    "amupras.jp_2d32333033313938392d3436@resource.calendar.google.com"
                ),
                "amupras.jp",
                "shortened"
            )
        }

        h.test("The host is matched whatever its case") {
            h.equal(
                RoomLabel.tidy("example.com_abc@Resource.Calendar.Google.COM"),
                "example.com",
                "shortened"
            )
        }

        h.test("A named room is left alone") {
            h.equal(RoomLabel.tidy("OR 3"), "OR 3", "unchanged")
            h.equal(RoomLabel.tidy("or3@example.com"), "or3@example.com", "unchanged")
        }

        h.test("A resource address with nothing to cut keeps what it has") {
            h.equal(
                RoomLabel.tidy("room@resource.calendar.google.com"),
                "room", "no underscore"
            )
            h.equal(
                RoomLabel.tidy("_abc@resource.calendar.google.com"),
                "_abc", "nothing in front of it"
            )
        }
    }
}
