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
    public func requestAccess() async throws {

        let status = EKEventStore.authorizationStatus(for: .event)

        if status == .fullAccess { return }
        if status == .restricted { throw CalendarAccessError.restricted }

        guard status == .notDetermined else {
            throw CalendarAccessError.denied
        }

        let granted: Bool

        do {
            granted = try await store.requestFullAccessToEvents()
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

    /// The whole job: search, filter by creation date, tag by role.
    public func log(
        createdIn range: DayRange,
        roles: Set<EntryRole> = Set(EntryRole.allCases),
        planner: FetchPlanner = .standard,
        timeZone: TimeZone = .current,
        in calendars: [EKCalendar]? = nil
    ) -> [LoggedEntry] {

        let plan = planner.plan(for: range, timeZone: timeZone)

        return EntryLog.entries(
            from: entries(matching: plan, in: calendars),
            createdIn: range,
            roles: roles
        )
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
