import Foundation

/// One calendar, as far as this tool cares.
///
/// A description rather than a handle: it says what to show in the
/// filter and what to remember a choice by, and it knows nothing about
/// where it came from. `CalEntryKit` builds one from an `EKCalendar`.
public struct CalendarSummary: Sendable, Equatable, Hashable, Identifiable {

    /// The store's own identifier, and what a filter is remembered by.
    /// Two calendars can share a title; nothing else tells them apart.
    public let id: String

    public let title: String
    public let source: String
    public let kind: String
    public let isWritable: Bool
    public let isSubscribed: Bool

    public init(
        id: String,
        title: String,
        source: String = "",
        kind: String = "unknown",
        isWritable: Bool = true,
        isSubscribed: Bool = false
    ) {
        self.id = id
        self.title = title
        self.source = source
        self.kind = kind
        self.isWritable = isWritable
        self.isSubscribed = isSubscribed
    }

    /// "iCloud / Work", or just the title when there is no account to
    /// name.
    public var label: String {
        source.isEmpty ? title : "\(source) / \(title)"
    }
}
