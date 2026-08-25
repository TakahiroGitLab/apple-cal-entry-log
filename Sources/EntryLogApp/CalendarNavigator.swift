import AppKit
import Foundation
import CalEntryCore

/// Sends Calendar to the day an entry falls on.
///
/// In month view, deliberately. `view calendar at` honours the date
/// and ignores the time, so day view lands on the right day scrolled
/// to the wrong hour -- a four o'clock entry shown against eight in
/// the morning, which reads as the wrong entry. A month has no hours
/// to be wrong about.
///
/// Selecting the entry itself is not on offer. Calendar's scripting
/// dictionary can find an event by its uid, but only by scanning, and
/// a scan across these calendars ran for over two minutes without
/// finishing. The `ical://ekevent/` scheme opens Calendar but does not
/// navigate. Opening the right day in day view puts the entry on
/// screen in under half a second, which is the whole point.
enum CalendarNavigator {

    @MainActor
    static func show(_ entry: CalendarEntry, timeZone: TimeZone) {

        guard let moment = entry.startDate ?? entry.creationDate else {
            openCalendar()
            return
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let parts = calendar.dateComponents(
            [.year, .month, .day], from: moment
        )

        guard let year = parts.year, let month = parts.month, let day = parts.day
        else {
            openCalendar()
            return
        }

        let script = """
            set d to current date
            -- Set the day twice: the first, to a date every month has,
            -- stops the month change rolling over from, say, the 31st.
            set day of d to 1
            set year of d to \(year)
            set month of d to \(month)
            set day of d to \(day)
            tell application "Calendar"
                activate
                switch view to month view
                view calendar at d
            end tell
            """

        var failure: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&failure)

        // Most likely the user has not allowed Entry Log to control
        // Calendar. Opening it plain is better than doing nothing.
        if failure != nil { openCalendar() }
    }

    @MainActor
    private static func openCalendar() {
        guard let url = URL(string: "ical://") else { return }
        NSWorkspace.shared.open(url)
    }
}
