import Foundation

/// The first glimpse of an entry's notes, for a list that has one line
/// to spare.
public enum NoteSummary {

    public static let defaultLimit = 50

    /// Notes flattened onto one line and cut to length, or nil when
    /// there is nothing to show.
    ///
    /// The whole note is collapsed rather than just its first line: a
    /// note whose opening line is a bare heading would otherwise show
    /// as nothing useful.
    public static func oneLine(
        _ notes: String?,
        limit: Int = defaultLimit
    ) -> String? {

        guard let notes else { return nil }

        let flattened = notes
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")

        guard !flattened.isEmpty else { return nil }

        guard flattened.count > limit else { return flattened }

        return flattened.prefix(limit) + "…"
    }
}
