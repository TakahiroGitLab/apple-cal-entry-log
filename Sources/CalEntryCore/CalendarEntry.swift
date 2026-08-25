import Foundation

/// One participant of an entry.
///
/// This mirrors the parts of `EKParticipant` the log actually needs.
/// Keeping it separate means the filtering and role rules can be
/// tested without an event store.
public struct Participant: Sendable, Equatable {

    /// What kind of invitee this is.
    ///
    /// Apple reports rooms and equipment as participant types of their
    /// own, so unlike the Google version there is no need to guess at a
    /// meeting room from its email address.
    public enum Kind: String, Sendable, Equatable {
        case person
        case room
        case resource
        case group
        case unknown
    }

    public var name: String?
    public var email: String?
    public var kind: Kind
    public var isCurrentUser: Bool

    public init(
        name: String? = nil,
        email: String? = nil,
        kind: Kind = .person,
        isCurrentUser: Bool = false
    ) {
        self.name = name
        self.email = email
        self.kind = kind
        self.isCurrentUser = isCurrentUser
    }

    /// A room or a piece of equipment rather than a human guest.
    public var isResource: Bool {
        kind == .room || kind == .resource
    }

    /// What to show on screen for this participant.
    public var label: String {
        if let name, !name.isEmpty { return name }
        if let email, !email.isEmpty { return email }
        return "(unnamed)"
    }
}


/// A calendar entry, reduced to the fields this tool reasons about.
///
/// The EventKit adapter converts `EKEvent` into this; nothing else in
/// the package knows that EventKit exists.
public struct CalendarEntry: Sendable, Equatable, Identifiable {

    public var id: String
    public var title: String?

    /// When the entry was written down -- the axis the whole tool is
    /// built around. Optional because EventKit leaves it nil for some
    /// imported and subscribed items.
    public var creationDate: Date?

    /// When the entry happens. Unrelated to `creationDate`, and the
    /// reason the fetch window has to be widened (see `FetchWindow`).
    public var startDate: Date?

    public var isAllDay: Bool

    public var calendarTitle: String

    /// Whether the user can edit this calendar. Used to tell an entry
    /// the user typed in from one that merely appeared on a subscribed
    /// calendar, since neither carries an organizer.
    public var calendarIsWritable: Bool

    /// Nil for a plain entry with no invitees.
    public var organizer: Participant?
    public var attendees: [Participant]

    public init(
        id: String,
        title: String? = nil,
        creationDate: Date? = nil,
        startDate: Date? = nil,
        isAllDay: Bool = false,
        calendarTitle: String = "",
        calendarIsWritable: Bool = true,
        organizer: Participant? = nil,
        attendees: [Participant] = []
    ) {
        self.id = id
        self.title = title
        self.creationDate = creationDate
        self.startDate = startDate
        self.isAllDay = isAllDay
        self.calendarTitle = calendarTitle
        self.calendarIsWritable = calendarIsWritable
        self.organizer = organizer
        self.attendees = attendees
    }

    public var displayTitle: String {
        guard let title, !title.isEmpty else { return "(No title)" }
        return title
    }

    /// Rooms and equipment, listed apart from the human guests.
    public var rooms: [String] {
        attendees.filter(\.isResource).map(\.label)
    }

    /// Human guests, minus the user, whose own presence on the list
    /// says nothing worth showing.
    public var guests: [String] {
        attendees
            .filter { !$0.isResource && !$0.isCurrentUser }
            .map(\.label)
    }

    /// Who set this up, when that was somebody else.
    public var organizerLabel: String? {
        guard let organizer, !organizer.isCurrentUser else { return nil }
        return organizer.label
    }
}
