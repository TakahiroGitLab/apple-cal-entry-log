import Foundation

/// A link that opens an entry in Calendar.
///
/// The point of a log of what you wrote down is to go and do something
/// about it, so every row needs a way back to the entry itself.
public enum CalendarAppLink {

    /// Calendar registers the `ical:` scheme and shows a single entry
    /// when given its external identifier -- the stable one that
    /// survives a sync, not the local one.
    public static func show(_ externalIdentifier: String?) -> URL? {

        guard let externalIdentifier, !externalIdentifier.isEmpty else {
            return nil
        }

        // Identifiers routinely contain characters that would end the
        // path or start the query if left as they are.
        let escaped = externalIdentifier.addingPercentEncoding(
            withAllowedCharacters: .alphanumerics
        ) ?? externalIdentifier

        return URL(string: "ical://ekevent/\(escaped)?method=show&options=more")
    }
}
