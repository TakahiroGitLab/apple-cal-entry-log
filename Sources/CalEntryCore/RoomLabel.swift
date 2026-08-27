import Foundation

/// What to call a meeting room that has no name.
///
/// A room booked through Google Workspace arrives as a participant
/// whose address is a resource calendar:
///
///     amupras.jp_2d32333033313938392d3436@resource.calendar.google.com
///
/// Everything after the underscore is a generated identifier. Printing
/// it costs a whole line and tells the reader nothing they can use --
/// the room's actual name is usually on the entry's location line
/// anyway. Only the domain in front of the underscore says anything.
public enum RoomLabel {

    private static let resourceHost = "@resource.calendar.google.com"

    /// The address shortened if it is a resource calendar, unchanged
    /// if it is anything else.
    public static func tidy(_ label: String) -> String {

        let lowered = label.lowercased()

        guard lowered.hasSuffix(resourceHost) else { return label }

        let local = label.dropLast(resourceHost.count)

        guard let underscore = local.firstIndex(of: "_") else {
            return local.isEmpty ? label : String(local)
        }

        let domain = local[local.startIndex..<underscore]

        return domain.isEmpty ? String(local) : String(domain)
    }
}
