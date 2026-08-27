import AppKit
import SwiftUI
import CalEntryCore

struct EntryRowView: View {

    let logged: LoggedEntry
    let formatting: Formatting
    let showsRole: Bool
    let timeZone: TimeZone
    let scale: TextScale

    @State private var showingNote = false

    private var entry: CalendarEntry { logged.entry }

    /// The whole note as one paragraph, when there is more of it than
    /// the line showed.
    ///
    /// Flattened rather than shown as written: a note of twenty short
    /// lines would otherwise open into twenty, throwing the rest of
    /// the list off the screen. The breaks carry no meaning worth that.
    private var fullNote: String? {
        guard let notes = entry.notes else { return nil }

        let flattened = notes
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "  ")

        guard !flattened.isEmpty, flattened != entry.noteSummary else {
            return nil
        }

        return flattened
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {

            // The title reads first and the stamp sits out of its way,
            // in the corner, where a date is looked for rather than
            // read through.
            HStack(alignment: .firstTextBaseline, spacing: 10) {

                Text(entry.displayTitle)
                    .font(scale.font(13, weight: .semibold))

                Spacer(minLength: 12)

                if showsRole {
                    Text(logged.role.rawValue)
                        .font(scale.font(10))
                        .foregroundStyle(colour(of: logged.role))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            colour(of: logged.role).opacity(0.15), in: Capsule()
                        )
                }

                // Lighter than the details below it. The stamp is
                // what the list is sorted by and hardly ever what is
                // being read; it wants to be findable, not loud.
                Text(formatting.stamp(logged.creationDate))
                    .font(scale.font(11))
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
                    .fixedSize()
            }

            if let when = formatting.when(entry) {
                detail(when, icon: "clock")
            }

            if let place = entry.locationLabel {
                detail(place, icon: "mappin.and.ellipse")
            }

            detail(entry.calendarLabel, icon: "calendar")

            if let organizer = entry.organizerLabel {
                detail(organizer, icon: "person")
            }

            if !entry.rooms.isEmpty {
                detail(entry.rooms.joined(separator: ", "), icon: "door.left.hand.open")
            }

            if !entry.guests.isEmpty {
                detail(entry.guests.joined(separator: ", "), icon: "person.2")
            }

            if let note = entry.noteSummary {
                // The whole note on hover. The line has room for the
                // opening of it and no more, and a note is the one
                // field where the part that matters is as likely to be
                // at the end.
                detail(showingNote ? (fullNote ?? note) : note,
                       icon: "text.alignleft",
                       selectable: false)
                    // Bounded: an opened note should not push the rows
                    // under it off the window.
                    .lineLimit(showingNote ? 8 : 1)
                    .onHover { hovering in
                        showingNote = hovering && fullNote != nil
                    }
            }

            if let url = entry.url, let label = LinkLabel.describe(url) {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Label(label, systemImage: "link")
                        .font(scale.font(11))
                }
                .buttonStyle(.link)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { showInCalendar() }
        .contextMenu {
            Button("Show in Calendar") { showInCalendar() }
        }
        .help("Double-click to show the day in Calendar")
    }

    /// One detail line.
    ///
    /// `selectable` is off for the note. Selectable text is drawn by a
    /// text view of its own, and swapping the string under one while
    /// the row is also changing height took the window down.
    private func detail(
        _ text: String, icon: String, selectable: Bool = true
    ) -> some View {
        Label(text, systemImage: icon)
            .font(scale.font(12))
            // Darker than plain secondary. These lines are the ones
            // being read, and losing them into the background to make
            // the stamp recede would be the wrong trade.
            .foregroundStyle(.primary.opacity(0.78))
            .modifier(Selectable(enabled: selectable))
    }

    /// One colour per role, since the badge exists to tell them apart
    /// and two capsules in the same colour do not.
    ///
    /// Blue for what you wrote, orange for what arrived from somebody
    /// else: a warm colour for the entries that came from outside.
    private func colour(of role: EntryRole) -> Color {
        switch role {
        case .created: .blue
        case .invited: .orange
        }
    }

    private func showInCalendar() {
        CalendarNavigator.show(entry, timeZone: timeZone)
    }
}


/// `.textSelection` takes two different types for on and off, so a
/// ternary between them will not compile.
private struct Selectable: ViewModifier {

    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.textSelection(.enabled)
        } else {
            content.textSelection(.disabled)
        }
    }
}
