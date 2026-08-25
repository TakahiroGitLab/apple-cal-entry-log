import Foundation
import CalEntryCore

func mailtoAddressTests(_ h: Harness) {

    h.suite("Mailto address") { h in

        h.test("A plain address comes back as written") {
            h.equal(MailtoAddress.from(URL(string: "mailto:sato@example.com")),
                    "sato@example.com", "address")
        }

        h.test("The scheme is matched in any case") {
            h.equal(MailtoAddress.from(URL(string: "MAILTO:sato@example.com")),
                    "sato@example.com", "address")
        }

        h.test("A query tacked on the end is dropped") {
            h.equal(
                MailtoAddress.from(
                    URL(string: "mailto:sato@example.com?subject=Pre-op")
                ),
                "sato@example.com", "address"
            )
        }

        h.test("Percent-encoding is undone") {
            h.equal(
                MailtoAddress.from(URL(string: "mailto:a%2Bb@example.com")),
                "a+b@example.com", "address"
            )
        }

        h.test("Anything that is not mail is refused") {
            h.isNil(MailtoAddress.from(URL(string: "https://example.com")),
                    "https")
            h.isNil(MailtoAddress.from(URL(string: "mailto:")), "empty mailto")
            h.isNil(MailtoAddress.from(nil), "no url at all")
        }
    }
}
