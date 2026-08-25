import Foundation

/// One span of *event* dates to ask the store for.
public struct FetchWindow: Sendable, Equatable {

    public let start: Date
    public let end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }
}


/// The set of queries needed to find everything written during a range
/// of days.
///
/// EventKit can only be searched by when an entry *happens*, never by
/// when it was written, so the store has to be over-fetched by event
/// date and filtered on `creationDate` afterwards. A single query
/// cannot span more than four years, but nothing stops several of
/// them: the plan is a contiguous run of windows, each inside that
/// limit, together covering the whole searched span.
///
/// Windows abut rather than overlap, but EventKit matches any entry
/// *overlapping* a window, so one straddling a boundary comes back
/// from both. The caller must deduplicate by calendar item identifier
/// -- which it has to do anyway, since every occurrence of a repeating
/// entry shares one identifier and one creation date.
public struct FetchPlan: Sendable, Equatable {

    public let windows: [FetchWindow]

    /// The whole span the plan covers, worth showing on screen: the
    /// search is bounded, and saying where it stopped is more honest
    /// than implying it looked everywhere.
    public let span: FetchWindow

    public init(windows: [FetchWindow], span: FetchWindow) {
        self.windows = windows
        self.span = span
    }
}


/// How far either side of the asked-for days to search, and how to cut
/// that into queries EventKit will accept.
public struct FetchPlanner: Sendable, Equatable {

    /// EventKit refuses a single predicate spanning more than four
    /// years.
    public static let maximumWindowInMonths = 48

    public var yearsBefore: Int
    public var yearsAfter: Int

    /// A decade either side. Wide enough that an entry written now for
    /// something years out is still found, and cheap enough that it
    /// does not matter: enumerating a personal calendar is a local
    /// query over a few thousand items.
    public static let standard = FetchPlanner(yearsBefore: 10, yearsAfter: 10)

    public init(yearsBefore: Int, yearsAfter: Int) {
        self.yearsBefore = max(0, yearsBefore)
        self.yearsAfter = max(0, yearsAfter)
    }

    public func plan(
        for range: DayRange,
        timeZone: TimeZone,
        calendar: Calendar = .init(identifier: .gregorian)
    ) -> FetchPlan {

        var calendar = calendar
        calendar.timeZone = timeZone

        let start = calendar.date(
            byAdding: .year, value: -yearsBefore, to: range.start
        ) ?? range.start

        let end = calendar.date(
            byAdding: .year, value: yearsAfter, to: range.endExclusive
        ) ?? range.endExclusive

        return FetchPlan(
            windows: split(from: start, to: end, calendar: calendar),
            span: FetchWindow(start: start, end: end)
        )
    }

    /// Cut a span into abutting windows no longer than the limit.
    private func split(
        from start: Date,
        to end: Date,
        calendar: Calendar
    ) -> [FetchWindow] {

        guard start < end else { return [FetchWindow(start: start, end: end)] }

        var windows: [FetchWindow] = []
        var cursor = start

        while cursor < end {

            let next = calendar.date(
                byAdding: .month,
                value: Self.maximumWindowInMonths,
                to: cursor
            ) ?? end

            windows.append(FetchWindow(start: cursor, end: min(next, end)))

            // Calendar arithmetic that fails to advance would spin
            // here; there is no sensible plan in that case.
            guard next > cursor else { break }

            cursor = next
        }

        return windows
    }
}
