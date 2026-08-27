import Foundation

/// Which calendars the window has been told not to read.
///
/// Remembered between launches. The machine that carries the work
/// calendars is the machine that carries them tomorrow as well, and
/// re-unticking six boxes every morning is not a filter anybody uses.
enum CalendarFilter {

    private static let key = "excludedCalendars"

    static func remembered() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    static func remember(_ excluded: Set<String>) {
        UserDefaults.standard.set(excluded.sorted(), forKey: key)
    }
}
