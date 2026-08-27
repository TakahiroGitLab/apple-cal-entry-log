import Foundation

/// What to call a meeting room, when there is anything worth calling
/// it.
///
/// A room booked through Google Workspace arrives as a participant
/// with no name and an address like:
///
///     amupras.jp_2d32333033313938392d3436@resource.calendar.google.com
///
/// Everything after the underscore is a generated identifier, and the
/// domain in front of it is already on the calendar line. The room's
/// real name comes through as the entry's location, so the line costs
/// a row of the listing and adds nothing to it. Such a room is left
/// out.
public enum RoomLabel {

    private static let resourceHost = "@resource.calendar.google.com"

    /// The room's name, or nothing when it has none worth printing.
    public static func from(_ participant: Participant) -> String? {

        if let name = participant.name, !name.isEmpty { return name }

        guard let email = participant.email, !email.isEmpty else { return nil }

        return isGenerated(email) ? nil : email
    }

    /// A Google resource calendar address: a domain, an underscore, a
    /// generated identifier.
    private static func isGenerated(_ email: String) -> Bool {
        email.lowercased().hasSuffix(resourceHost)
    }
}
