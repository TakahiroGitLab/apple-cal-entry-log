import Foundation
import CalEntryCore
import CalEntryKit

/// Owns the event store and keeps every touch of it off the main
/// thread and on one thread of its own.
///
/// Reading a decade takes about a second, which is nothing to wait for
/// and far too long to make the window wait for.
actor CalendarReader {

    private let source = EventKitSource()

    nonisolated func requestAccess() async throws {
        try await EventKitSource.requestAccess()
    }

    func log(
        createdIn range: DayRange,
        timeZone: TimeZone
    ) -> (entries: [LoggedEntry], plan: FetchPlan) {

        let planner = FetchPlanner.standard

        return (
            source.log(createdIn: range, planner: planner, timeZone: timeZone),
            planner.plan(for: range, timeZone: timeZone)
        )
    }
}
