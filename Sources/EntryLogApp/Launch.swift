import Foundation

/// How this copy was started.
enum Launch {

    /// `--demo` fills the window with an invented calendar and never
    /// touches EventKit.
    ///
    /// For screenshots, mostly. A listing of a real calendar carries
    /// names, addresses and whatever the notes happen to hold, which
    /// makes every screenshot of the working tool unpublishable. It is
    /// also the only way to see the window on a Mac that has not
    /// granted access.
    static let isDemo = CommandLine.arguments.contains("--demo")

    static var windowTitle: String {
        isDemo ? "Entry Log (demo)" : "Entry Log"
    }
}
