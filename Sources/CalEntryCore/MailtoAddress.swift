import Foundation

/// EventKit hands a participant's address over as a `mailto:` URL
/// rather than a string.
///
/// Pulling the address back out lives here, away from EventKit, so the
/// awkward cases can be tested: the scheme in any case, a query
/// tacked on the end, percent-encoding, and URLs that are not mail
/// addresses at all.
public enum MailtoAddress {

    public static func from(_ url: URL?) -> String? {

        guard let url,
              url.scheme?.lowercased() == "mailto"
        else { return nil }

        // Everything after the scheme, minus any ?subject=... tail.
        var address = url.absoluteString.dropFirst("mailto:".count)

        if let query = address.firstIndex(of: "?") {
            address = address[..<query]
        }

        let decoded = String(address).removingPercentEncoding ?? String(address)

        return decoded.isEmpty ? nil : decoded
    }
}
