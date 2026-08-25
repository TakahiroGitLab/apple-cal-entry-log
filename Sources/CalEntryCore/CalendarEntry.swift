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

    /// The identifier that survives a sync, which is the one Calendar
    /// accepts in a link. Nil for an entry that has never left this
    /// Mac.
    public var externalId: String?

    public var title: String?

    /// When the entry was written down -- the axis the whole tool is
    /// built around. Optional because EventKit leaves it nil for some
    /// imported and subscribed items.
    public var creationDate: Date?

    /// When the entry happens. Unrelated to `creationDate`, and the
    /// reason the fetch window has to be widened (see `FetchWindow`).
    public var startDate: Date?

    /// When it finishes. For an all-day entry this is the last
    /// moment of its final day, not the following midnight.
    public var endDate: Date?

    public var isAllDay: Bool

    public var location: String?
    public var notes: String?
    public var url: URL?

    public var calendarTitle: String

    /// The account the calendar belongs to. Two calendars can share a
    /// title -- a subscribed holiday calendar and an iCloud copy of
    /// the same one -- and only this tells them apart.
    public var calendarSource: String

    /// Whether the user can edit this calendar. Used to tell an entry
    /// the user typed in from one that merely appeared on a subscribed
    /// calendar, since neither carries an organizer.
    public var calendarIsWritable: Bool

    /// Nil for a plain entry with no invitees.
    public var organizer: Participant?
    public var attendees: [Participant]

    public init(
        id: String,
        externalId: String? = nil,
        title: String? = nil,
        creationDate: Date? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        isAllDay: Bool = false,
        location: String? = nil,
        notes: String? = nil,
        url: URL? = nil,
        calendarTitle: String = "",
        calendarSource: String = "",
        calendarIsWritable: Bool = true,
        organizer: Participant? = nil,
        attendees: [Participant] = []
    ) {
        self.id = id
        self.externalId = externalId
        self.title = title
        self.creationDate = creationDate
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.location = location
        self.notes = notes
        self.url = url
        self.calendarTitle = calendarTitle
        self.calendarSource = calendarSource
        self.calendarIsWritable = calendarIsWritable
        self.organizer = organizer
        self.attendees = attendees
    }

    /// A link that opens this entry in Calendar.
    public var calendarAppLink: URL? {
        CalendarAppLink.show(externalId)
    }

    /// How long it runs: "2h", "45m", "3 days".
    public func duration(in timeZone: TimeZone) -> String? {
        DurationLabel.from(
            start: startDate, end: endDate, isAllDay: isAllDay,
            timeZone: timeZone
        )
    }

    /// The notes on one line, cut to length.
    public var noteSummary: String? {
        NoteSummary.oneLine(notes)
    }

    /// The location, minus the postcode and the country.
    public var locationLabel: String? {
        LocationLabel.tidy(location)
    }

    /// "iCloud / Work", or just the title when there is no account to
    /// name.
    public var calendarLabel: String {
        calendarSource.isEmpty
            ? calendarTitle
            : "\(calendarSource) / \(calendarTitle)"
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
