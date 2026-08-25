import Foundation

/// How the user is involved in an entry.
///
/// The two are mutually exclusive, so asking for both lists every
/// entry exactly once.
public enum EntryRole: String, Sendable, CaseIterable, Equatable {

    /// The user wrote this entry down.
    case created

    /// Somebody else set it up and put the user on the guest list.
    case invited
}


extension CalendarEntry {

    /// Which role the user has in this entry, or nil when neither --
    /// somebody else's entry that is merely visible to the user.
    ///
    /// EventKit exposes no creator, only an organizer, and an
    /// organizer exists only once an entry has invitees. A plain entry
    /// with nobody invited is therefore attributed by whether the user
    /// can write to the calendar it sits on: an entry the user typed
    /// into their own calendar counts as created, while one that
    /// arrived on a read-only subscription (holidays, a colleague's
    /// published calendar) counts as neither.
    ///
    /// The gap this leaves: a plain, invitee-less entry that somebody
    /// else wrote into a calendar shared with the user for writing is
    /// indistinguishable from the user's own. EventKit records no
    /// author for it, so no rule here can recover one.
    public var role: EntryRole? {

        if let organizer {

            // Checked first, so an entry the user organised and is
            // also an attendee of counts once, as created.
            if organizer.isCurrentUser { return .created }

            if attendees.contains(where: \.isCurrentUser) { return .invited }

            return nil
        }

        return calendarIsWritable ? .created : nil
    }
}
