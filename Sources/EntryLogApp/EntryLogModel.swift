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

    private let reader = CalendarReader()
    private var pending: Task<Void, Never>?

    /// Changes only when the chosen *days* change, so picking a
    /// different time on the same day does not set off a search.
    var fetchKey: String {
        DayRange.day(startDay, timeZone: timeZone)
            + "/"
            + DayRange.day(endDay, timeZone: timeZone)
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
        showsRoleFilter ? loaded.filter { roles.contains($0.role) } : loaded
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

        do {
            try await reader.requestAccess()
        } catch {
            state = .needsAccess("\(error)")
            return
        }

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
}
