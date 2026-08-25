import Foundation

/// The span of *event* dates to ask the store for.
///
/// EventKit can only be queried by when an entry happens, never by
/// when it was written. So the log has to over-fetch by event date and
/// filter on `creationDate` afterwards -- the same shape of workaround
/// the Google version needs, but on a different axis: there the
/// prefilter (`updatedMin`) is guaranteed to be a superset, here it is
/// not. An entry written today for a clinic two years out falls
/// outside any modest window, and nothing in the store hints that it
/// was missed.
public struct FetchWindow: Sendable, Equatable {

    public let start: Date
    public let end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }
}


/// How far either side of the asked-for days to look for entries.
public struct FetchWindowPolicy: Sendable, Equatable {

    public var monthsBefore: Int
    public var monthsAfter: Int

    /// A year back and two years forward. Entries are usually written
    /// for something ahead of the writing, so the window leans forward;
    /// the year behind catches entries added after the fact.
    public static let standard = FetchWindowPolicy(
        monthsBefore: 12, monthsAfter: 24
    )

    /// EventKit refuses a predicate spanning more than four years.
    public static let maximumSpanInMonths = 48

    public init(monthsBefore: Int, monthsAfter: Int) {
        self.monthsBefore = monthsBefore
        self.monthsAfter = monthsAfter
    }

    /// The event-date window that should be searched to find
    /// everything written during `range`.
    ///
    /// Where the total would exceed EventKit's four-year limit, the
    /// past end is pulled in first: an entry written now for something
    /// long past is rarer than one written now for something ahead.
    public func window(
        for range: DayRange,
        timeZone: TimeZone,
        calendar: Calendar = .init(identifier: .gregorian)
    ) -> FetchWindow {

        var calendar = calendar
        calendar.timeZone = timeZone

        let start = calendar.date(
            byAdding: .month, value: -monthsBefore, to: range.start
        ) ?? range.start

        let end = calendar.date(
            byAdding: .month, value: monthsAfter, to: range.endExclusive
        ) ?? range.endExclusive

        let earliestAllowed = calendar.date(
            byAdding: .month,
            value: -Self.maximumSpanInMonths,
            to: end
        ) ?? start

        return FetchWindow(start: max(start, earliestAllowed), end: end)
    }
}
