import Foundation

/// An entry that made it through the filter, paired with the role it
/// matched on.
public struct LoggedEntry: Sendable, Equatable, Identifiable {

    public let entry: CalendarEntry
    public let role: EntryRole

    /// Non-optional here: an entry without one cannot be in the log.
    public let creationDate: Date

    public var id: String { entry.id }

    public init(entry: CalendarEntry, role: EntryRole, creationDate: Date) {
        self.entry = entry
        self.role = role
        self.creationDate = creationDate
    }
}


public enum EntryLog {

    /// The entries written down inside `range`, in the order they were
    /// written.
    ///
    /// Entries EventKit gives no creation date for are dropped rather
    /// than guessed at: the whole point of the log is the creation
    /// timestamp, and an entry with an invented one would sit in the
    /// list looking exactly as trustworthy as the rest.
    ///
    /// Passing an empty `roles` yields nothing, which is what the two
    /// unticked checkboxes should show.
    public static func entries(
        from entries: [CalendarEntry],
        createdIn range: DayRange,
        roles: Set<EntryRole> = Set(EntryRole.allCases)
    ) -> [LoggedEntry] {

        entries
            .compactMap { entry -> LoggedEntry? in

                guard let created = entry.creationDate,
                      range.contains(created),
                      let role = entry.role,
                      roles.contains(role)
                else { return nil }

                return LoggedEntry(
                    entry: entry, role: role, creationDate: created
                )
            }
            .sorted(by: writtenEarlier)
    }

    /// Creation order, with a stable tiebreak so that two entries saved
    /// in the same second do not swap places between runs.
    private static func writtenEarlier(_ a: LoggedEntry, _ b: LoggedEntry) -> Bool {
        if a.creationDate != b.creationDate {
            return a.creationDate < b.creationDate
        }
        if a.entry.displayTitle != b.entry.displayTitle {
            return a.entry.displayTitle < b.entry.displayTitle
        }
        return a.entry.id < b.entry.id
    }
}
