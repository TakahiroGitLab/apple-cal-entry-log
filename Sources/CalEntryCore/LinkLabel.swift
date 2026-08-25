import Foundation

/// What an entry's link points at, in a couple of words.
///
/// Most entries written from an invitation carry a `message:` URL back
/// to the mail it came from. Printing that in full is a line of
/// message-id and no information: the reader wants to know there is a
/// mail behind this and to be able to open it, not to read its
/// identifier.
public enum LinkLabel {

    public static func describe(_ url: URL?) -> String? {

        guard let url, let scheme = url.scheme?.lowercased() else { return nil }

        switch scheme {

        // Mail's own scheme, pointing back at a specific message.
        case "message", "emailmessage":
            return "email"

        case "mailto":
            return MailtoAddress.from(url) ?? "email"

        case "http", "https":
            guard let host = url.host, !host.isEmpty else { return url.absoluteString }

            return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host

        default:
            return scheme
        }
    }
}
