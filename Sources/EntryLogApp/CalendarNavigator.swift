import AppKit
import Foundation
import CalEntryCore

/// Sends Calendar to the entry, and selects it where it can.
///
/// Two things happen, in order. The month the entry falls in is put on
/// screen, and then Calendar is asked to select the entry itself, so
/// that the right square is picked out rather than merely the right
/// page.
///
/// The month, rather than the day, deliberately. `view calendar at`
/// honours the date and ignores the time, so day view lands on the
/// right day scrolled to the wrong hour -- a four o'clock entry shown
/// against eight in the morning, which reads as the wrong entry. A
/// month has no hours to be wrong about.
///
/// Selecting the entry is a direct lookup by identifier,
/// `event id ... of calendar ...`, which answers in about a quarter of
/// a second. An earlier attempt at `whose uid = ...` ran for over two
/// minutes without finishing, because that scans; and the
/// `ical://ekevent/` scheme, with or without Spotlight's
/// `?method=show&options=more`, opens Calendar and then ignores the
/// identifier entirely.
///
/// A repeating entry is left unselected. Every occurrence of a series
/// shares the one identifier, and Calendar's scripting cannot address
/// an occurrence, so asking it to show a series jumps to whichever
/// occurrence it likes -- April for an entry the log is showing in
/// July. Landing on the wrong date is worse than landing on the right
/// one unhighlighted.
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
            \(selectClause(for: entry))
            end tell
            """

        var failure: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&failure)

        // Most likely the user has not allowed Entry Log to control
        // Calendar. Opening it plain is better than doing nothing.
        if failure != nil { openCalendar() }
    }

    /// The lines that select the entry, or none at all.
    ///
    /// Wrapped in `try` because the lookup fails for an entry Calendar
    /// no longer has, or one on the second of two calendars sharing a
    /// name. The month is on screen by then either way, which is the
    /// result the plain path gives.
    private static func selectClause(for entry: CalendarEntry) -> String {
        guard entry.isPinpointable, let uid = entry.externalId else {
            return ""
        }

        return """
                try
                    show (event id "\(quoted(uid))" ¬
                        of calendar "\(quoted(entry.calendarTitle))")
                end try
            """
    }

    /// Escapes what goes inside an AppleScript string literal. A
    /// calendar can be named anything, quotation marks included.
    private static func quoted(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    @MainActor
    private static func openCalendar() {
        guard let url = URL(string: "ical://") else { return }
        NSWorkspace.shared.open(url)
    }
}
