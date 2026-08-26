import Foundation
import CalEntryCore

func locationLabelTests(_ h: Harness) {

    h.suite("Location") { h in

        h.test("What Maps puts there is reduced to the useful part") {
            let fromMaps = """
                桜井市スポーツセンター
                〒123-4567 桜県桜井市桜町架空池30
                Japan
                """

            h.equal(LocationLabel.tidy(fromMaps),
                    "桜井市スポーツセンター, 桜県桜井市桜町架空池30",
                    "tidied")
        }

        h.test("A postcode goes whether or not it has its mark") {
            h.equal(LocationLabel.tidy("〒123-4567 桜県桜井市"),
                    "桜県桜井市", "with the mark")
            h.equal(LocationLabel.tidy("〒1234567 桜県桜井市"),
                    "桜県桜井市", "without the dash")
            h.equal(LocationLabel.tidy("123-4567 桜県桜井市"),
                    "桜県桜井市", "bare")
        }

        h.test("A street number is not mistaken for a postcode") {
            // Three digits, a dash and four would match; 1-2-3 must
            // not, and neither must a number attached to a name.
            h.equal(LocationLabel.tidy("桜県桜井市桜町 1-2-3"),
                    "桜県桜井市桜町 1-2-3", "block number")
            h.equal(LocationLabel.tidy("架空池30"), "架空池30", "house number")
        }

        h.test("The country goes, as a line or on the end of one") {
            h.equal(LocationLabel.tidy("Tokyo Station, Japan"),
                    "Tokyo Station", "its own segment")
            h.equal(LocationLabel.tidy("Tokyo Station Japan"),
                    "Tokyo Station", "on the end")
            h.equal(LocationLabel.tidy("東京駅\n日本"), "東京駅", "in Japanese")
        }

        h.test("Somewhere abroad keeps its country, which is the point") {
            h.equal(LocationLabel.tidy("Royal Free Hospital, London, UK"),
                    "Royal Free Hospital, London, UK", "kept")
        }

        h.test("A place that merely contains the word survives") {
            h.equal(LocationLabel.tidy("Japan Post Hospital"),
                    "Japan Post Hospital", "not stripped")
        }

        h.test("Nothing worth showing shows nothing") {
            h.isNil(LocationLabel.tidy(nil), "no location")
            h.isNil(LocationLabel.tidy("   \n  "), "only whitespace")
            h.isNil(LocationLabel.tidy("〒123-4567\nJapan"), "only a postcode")
        }
    }
}
