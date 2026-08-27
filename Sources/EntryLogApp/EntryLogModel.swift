import Foundation
import Observation
import CalEntryCore

@MainActor
@Observable
final class EntryLogModel {

    enum State: Equatable {
        case loading
        case ready
        case needsAccess(String)
        case failed(String)
    }

    var startDay: Date = .now
    var endDay: Date = .now

    /// Show an invented calendar instead of the real one. Starts on
    /// when the app was launched with `--demo`, and can be turned on
    /// and off from the menu afterwards.
    var isDemo: Bool = Launch.isDemo

    /// The writable calendars, as offered by the filter. Empty until
    /// the first read, since asking needs access.
    private(set) var calendars: [CalendarSummary] = []

    /// Which calendars are not to be shown.
    ///
    /// A filter over what has already been read, not over what gets
    /// read: skipping calendars in the search saves about forty
    /// milliseconds out of two hundred, which is not worth making
    /// every tick of a box wait for a fresh read.
    ///
    /// Kept as the exclusions rather than the inclusions so that a
    /// calendar added next month arrives switched on. Remembered
    /// between launches: this is the machine that has the work
    /// calendars on it, and that does not change day to day.
    var excludedCalendars: Set<String> = CalendarFilter.remembered() {
        didSet { CalendarFilter.remember(excludedCalendars) }
    }

    /// Which roles to show. Only ever offered when the results
    /// actually contain more than one.
    var roles: Set<EntryRole> = Set(EntryRole.allCases)

    private(set) var state: State = .loading

    /// Everything that came back, both roles. Filtering by role works
    /// on this rather than searching again, so ticking a box is
    /// instant.
    private(set) var loaded: [LoggedEntry] = []

    private(set) var searched: FetchWindow?
    private(set) var queries = 0
    private(set) var calendarsSearched = 0

    let timeZone = TimeZone.current

    /// Remembered between launches: a size chosen once for this screen
    /// should not have to be chosen again tomorrow.
    var textScale: TextScale = .remembered() {
        didSet { textScale.remember() }
    }

    func resize(by direction: Int) {
        textScale = textScale.stepped(by: direction)
    }

    func resetTextSize() {
        textScale = .standard
    }

    private let reader = CalendarReader()
    private var pending: Task<Void, Never>?

    /// Changes only when the chosen *days* change, so picking a
    /// different time on the same day does not set off a search.
    var fetchKey: String {
        DayRange.day(startDay, timeZone: timeZone)
            + "/"
            + DayRange.day(endDay, timeZone: timeZone)
            + (isDemo ? "/demo" : "")
    }

    /// Whether the filter is worth showing. One calendar cannot be
    /// filtered down to anything useful.
    var showsCalendarFilter: Bool { calendars.count > 1 }

    var everyCalendarIsExcluded: Bool {
        !calendars.isEmpty
            && Set(calendars.map(\.id)).isSubset(of: excludedCalendars)
    }

    func isReading(_ calendar: CalendarSummary) -> Bool {
        !excludedCalendars.contains(calendar.id)
    }

    func setReading(_ calendar: CalendarSummary, _ wanted: Bool) {
        if wanted {
            excludedCalendars.remove(calendar.id)
        } else {
            excludedCalendars.insert(calendar.id)
        }
    }

    func readEveryCalendar() {
        excludedCalendars = []
    }

    func readNoCalendar() {
        excludedCalendars = Set(calendars.map(\.id))
    }

    var availableRoles: Set<EntryRole> {
        Set(loaded.map(\.role))
    }

    /// An always-empty filter is a dead control. It appears by itself
    /// the day a shared calendar turns up.
    var showsRoleFilter: Bool {
        availableRoles.count > 1
    }

    var visible: [LoggedEntry] {
        loaded.filter { logged in
            if showsRoleFilter, !roles.contains(logged.role) { return false }

            return !excludedCalendars.contains(logged.entry.calendarId)
        }
    }

    /// Which end of the range a nudge moves.
    enum Edge { case start, end }

    /// Move one end of the range by whole days.
    ///
    /// The other end is dragged along rather than crossed. Start and
    /// end are equal most of the time -- that is what the presets
    /// leave behind -- and an arrow that refuses to move a one-day
    /// range is an arrow that does nothing.
    func nudge(_ edge: Edge, byDays days: Int) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        switch edge {
        case .start:
            guard let moved = calendar.date(
                byAdding: .day, value: days, to: startDay
            ) else { return }

            startDay = moved
            if moved > endDay { endDay = moved }

        case .end:
            guard let moved = calendar.date(
                byAdding: .day, value: days, to: endDay
            ) else { return }

            endDay = moved
            if moved < startDay { startDay = moved }
        }
    }

    func show(daysAgo: Int) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let day = calendar.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now

        startDay = day
        endDay = day
    }

    func isShowing(daysAgo: Int) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: .now)
        else { return false }

        return calendar.isDate(startDay, inSameDayAs: day)
            && calendar.isDate(endDay, inSameDayAs: day)
    }

    /// Read again shortly.
    ///
    /// A sync posts a burst of change notifications rather than one,
    /// so each request cancels the last and only the final one runs.
    func reloadSoon() {
        pending?.cancel()

        pending = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(800))

            guard !Task.isCancelled else { return }

            await self?.reload()
        }
    }

    func reload() async {

        let range: DayRange

        do {
            range = try DayRange.covering(
                startDay, through: endDay, timeZone: timeZone
            )
        } catch {
            state = .failed("\(error)")
            return
        }

        state = .loading

        if isDemo {
            showDemo(in: range)
            return
        }

        do {
            try await reader.requestAccess()
        } catch {
            state = .needsAccess("\(error)")
            return
        }

        calendars = await reader.calendars()

        let reading = await reader.log(createdIn: range, timeZone: timeZone)

        // A search the user has already moved on from should not
        // overwrite the one they are waiting for.
        guard !Task.isCancelled else { return }

        loaded = reading.entries
        searched = reading.plan.span
        queries = reading.plan.windows.count
        calendarsSearched = reading.calendarsSearched
        state = .ready
    }

    /// The invented calendar, filtered by the same rules as a real
    /// one, so that the presets and the role boxes behave.
    private func showDemo(in range: DayRange) {

        let plan = FetchPlanner.standard.plan(for: range, timeZone: timeZone)

        calendars = DemoLog.calendars

        loaded = EntryLog.entries(
            from: DemoLog.entries(timeZone: timeZone), createdIn: range
        )

        searched = plan.span
        queries = plan.windows.count
        calendarsSearched = calendars.count
        state = .ready
    }
}
