import Foundation

/// An entry's location, reduced to the part worth reading.
///
/// EventKit hands over whatever Maps put there, which for a place
/// picked on a phone is typically the name, then the full postal
/// address, then the country, across several lines. Almost all of that
/// is already known to the person reading their own calendar.
public enum LocationLabel {

    /// Countries dropped as redundant. Only the one the user lives in
    /// belongs here: "Japan" on every entry says nothing, but a
    /// location abroad is exactly the sort of thing worth seeing.
    static let assumedCountries: Set<String> = ["japan", "日本"]

    public static func tidy(_ location: String?) -> String? {

        guard let location else { return nil }

        let segments = location
            .split(whereSeparator: { $0.isNewline || $0 == "," || $0 == "、" })
            .map { strip(String($0)) }
            .filter { !$0.isEmpty }
            .filter { !assumedCountries.contains($0.lowercased()) }

        let joined = segments.joined(separator: ", ")

        return joined.isEmpty ? nil : joined
    }

    private static func strip(_ segment: String) -> String {

        var text = segment

        // 〒470-0131, or the same without the dash.
        text = text.replacingOccurrences(
            of: "〒\\s*\\d{3}-?\\d{4}",
            with: "",
            options: .regularExpression
        )

        // A bare Japanese postcode, only as a word of its own -- a
        // street number like 1-2-3 must survive.
        text = text.replacingOccurrences(
            of: "(^|\\s)\\d{3}-\\d{4}(?=\\s|$)",
            with: " ",
            options: .regularExpression
        )

        // A country tacked on the end of a line rather than sitting in
        // a segment of its own.
        for country in assumedCountries {
            text = text.replacingOccurrences(
                of: "\\s+\(country)\\s*$",
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }

        return text
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}
