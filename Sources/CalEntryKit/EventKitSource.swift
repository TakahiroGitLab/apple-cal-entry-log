import EventKit
import Foundation
import CalEntryCore

public enum CalendarAccessError: Error, Equatable, CustomStringConvertible {

    case denied
    case restricted
    case failed(String)

    public var description: String {
        switch self {
        case .denied:
            return """
                Calendar access was refused. Grant it in System Settings \
                > Privacy & Security > Calendars.
                """
        case .restricted:
            return "Calendar access is not allowed on this Mac."
        case .failed(let detail):
            return "Could not reach the calendar store: \(detail)"
        }
    }
}


/// Reads Apple Calendar and hands back neutral entries.
public final class EventKitSource {

    private let store: EKEventStore

    public init(store: EKEventStore = EKEventStore()) {
        self.store = store
    }

    /// Ask for read access, or confirm it is already granted.
    ///
    /// Write-only access counts as refused: it is enough to add an
    /// entry and not enough to read one back, which is all this does.
    ///
    /// Static because authorisation belongs to the process rather than
    /// to any one store, and because asking through an instance would
    /// mean handing a store that is not Sendable across to whichever
    /// thread the system answers on.
    public static func requestAccess() async throws {

        let status = EKEventStore.authorizationStatus(for: .event)

        if status == .fullAccess { return }
        if status == .restricted { throw CalendarAccessError.restricted }

        guard status == .notDetermined else {
            throw CalendarAccessError.denied
        }

        let granted: Bool

        do {
            granted = try await EKEventStore().requestFullAccessToEvents()
        } catch {
            throw CalendarAccessError.failed(error.localizedDescription)
        }

        guard granted else { throw CalendarAccessError.denied }
    }

    /// Every entry the plan's windows touch, each one once.
    ///
    /// A repeating entry is enumerated once per occurrence and an
    /// entry straddling two windows comes back from both, so both are
    /// collapsed on the identifier. That is correct rather than merely
    /// tidy: the log is about when something was written down, and a
    /// weekly clinic was written down once.
    public func entries(
        matching plan: FetchPlan,
        in calendars: [EKCalendar]? = nil
    ) -> [CalendarEntry] {

        let collected = Collector()

        for window in plan.windows {

            let predicate = store.predicateForEvents(
                withStart: window.start,
                end: window.end,
                calendars: calendars
            )

            store.enumerateEvents(matching: predicate) { event, _ in
                collected.add(event)
            }
        }

        return collected.entries
    }

    /// What EventKit can see, before any filtering.
    ///
    /// Worth having separately: whether an entry carries a creation
    /// date at all is decided by the account it came from, not by this
    /// code, and that is the one thing the whole tool rests on.
    public func calendars() -> [CalendarSummary] {

        store.calendars(for: .event)
            .map(CalendarSummary.init)
            .sorted { ($0.source, $0.title) < ($1.source, $1.title) }
    }

    /// Posted when anything in the calendar database changes --
    /// an entry added here, or one arriving from another device.
    ///
    /// Re-exported so that a caller can watch for changes without
    /// importing EventKit itself.
    public static let storeChanged = Notification.Name.EKEventStoreChanged

    /// Drop whatever the store has cached.
    ///
    /// Needed in two situations that look nothing alike. A store made
    /// before the user granted access keeps reporting an empty
    /// calendar afterwards, and a long-lived store can lag behind
    /// entries added in Calendar since it was made. Both are fixed by
    /// the same call, so a refresh does it every time.
    public func refresh() {
        store.reset()
    }

    /// The calendars worth searching.
    ///
    /// An entry on a read-only calendar -- holidays, birthdays,
    /// somebody's published calendar -- can be neither created by the
    /// user nor an invitation to them, since an invitation has to land
    /// somewhere they can accept it. So skipping those loses nothing
    /// the log would have shown and saves enumerating them.
    public func writableCalendars() -> [EKCalendar] {
        store.calendars(for: .event)
            .filter { $0.allowsContentModifications }
    }

    /// The whole job: search, filter by creation date, tag by role.
    ///
    /// Searches the writable calendars unless told otherwise.
    public func log(
        createdIn range: DayRange,
        roles: Set<EntryRole> = Set(EntryRole.allCases),
        planner: FetchPlanner = .standard,
        timeZone: TimeZone = .current,
        in calendars: [EKCalendar]? = nil
    ) -> Reading {

        let plan = planner.plan(for: range, timeZone: timeZone)
        let searched = calendars ?? writableCalendars()

        return Reading(
            entries: EntryLog.entries(
                from: entries(matching: plan, in: searched),
                createdIn: range,
                roles: roles
            ),
            plan: plan,
            // Worth reporting when the answer is nothing: no entries
            // across nine calendars is a quiet day, and no entries
            // across none of them is a permission problem.
            calendarsSearched: searched.count
        )
    }
}


/// What one search found, and what it looked through to find it.
public struct Reading: Sendable {

    public let entries: [LoggedEntry]
    public let plan: FetchPlan
    public let calendarsSearched: Int

    public init(entries: [LoggedEntry], plan: FetchPlan, calendarsSearched: Int) {
        self.entries = entries
        self.plan = plan
        self.calendarsSearched = calendarsSearched
    }
}


/// One calendar, as far as this tool cares.
public struct CalendarSummary: Sendable, Equatable {

    public let title: String
    public let source: String
    public let kind: String
    public let isWritable: Bool
    public let isSubscribed: Bool

    init(_ calendar: EKCalendar) {
        self.title = calendar.title
        self.source = calendar.source?.title ?? "(no source)"
        self.kind = Self.describe(calendar.source?.sourceType)
        self.isWritable = calendar.allowsContentModifications
        self.isSubscribed = calendar.isSubscribed
    }

    private static func describe(_ type: EKSourceType?) -> String {
        switch type {
        case .local: return "local"
        case .exchange: return "exchange"
        case .calDAV: return "caldav"
        case .mobileMe: return "mobileme"
        case .subscribed: return "subscribed"
        case .birthdays: return "birthdays"
        default: return "unknown"
        }
    }
}


/// Somewhere for `enumerateEvents` to put things.
///
/// A class rather than local variables because the enumeration hands
/// results to a closure, and mutating captured state from one is what
/// strict concurrency exists to complain about.
private final class Collector {

    private(set) var entries: [CalendarEntry] = []
    private var seen = Set<String>()

    func add(_ event: EKEvent) {
        guard seen.insert(event.calendarItemIdentifier).inserted else { return }
        entries.append(CalendarEntry(event))
    }
}
