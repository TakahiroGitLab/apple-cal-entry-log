import Foundation
import CalEntryCore
import CalEntryKit

/// Owns the event store and keeps every touch of it off the main
/// thread and on one thread of its own.
///
/// Reading a decade takes about a second, which is nothing to wait for
/// and far too long to make the window wait for.
actor CalendarReader {

    /// Made on first use rather than at startup, so that it is never
    /// made before the user has granted access: a store that predates
    /// the grant goes on reporting an empty calendar afterwards.
    private var source: EventKitSource?

    nonisolated func requestAccess() async throws {
        try await EventKitSource.requestAccess()
    }

    func log(createdIn range: DayRange, timeZone: TimeZone) -> Reading {

        ready().log(
            createdIn: range, planner: .standard, timeZone: timeZone
        )
    }

    /// The writable calendars, for the filter to offer.
    func calendars() -> [CalendarSummary] {
        ready().writableCalendarSummaries()
    }

    private func ready() -> EventKitSource {
        let source = self.source ?? EventKitSource()
        self.source = source

        // Whatever it has cached is at best one refresh out of date.
        source.refresh()

        return source
    }
}
