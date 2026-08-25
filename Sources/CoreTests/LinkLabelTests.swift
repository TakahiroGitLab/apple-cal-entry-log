import Foundation
import CalEntryCore

func linkLabelTests(_ h: Harness) {

    func label(_ text: String) -> String? {
        LinkLabel.describe(URL(string: text))
    }

    h.suite("Link label") { h in

        h.test("A link back to a mail says so, and not which one") {
            h.equal(label("message:%3C1A2B3C%40mail.example.com%3E"),
                    "email", "message scheme")
        }

        h.test("An address shows as itself, being short already") {
            h.equal(label("mailto:sato@example.com"),
                    "sato@example.com", "mailto")
        }

        h.test("A web link shows its host rather than its path") {
            h.equal(label("https://zoom.us/j/12345678901?pwd=abcdef"),
                    "zoom.us", "host")
            h.equal(label("https://www.example.com/a/very/long/path"),
                    "example.com", "www dropped")
        }

        h.test("Anything else is named by its scheme") {
            h.equal(label("x-apple-reminderkit://REMCDReminder/abc"),
                    "x-apple-reminderkit", "scheme")
        }

        h.test("Nothing to link to shows nothing") {
            h.isNil(LinkLabel.describe(nil), "no url")
            h.isNil(label("not a url at all"), "no scheme")
        }
    }
}
