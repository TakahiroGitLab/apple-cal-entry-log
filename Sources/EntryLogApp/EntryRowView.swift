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

    /// The note as written, when there is more of it than the line
    /// showed.
    private var fullNote: String? {
        guard let notes = entry.notes?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ), !notes.isEmpty, notes != entry.noteSummary
        else { return nil }

        return notes
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
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.tint.opacity(0.15), in: Capsule())
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
                       icon: "text.alignleft")
                    .lineLimit(showingNote ? nil : 1)
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

    private func detail(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(scale.font(12))
            // Darker than plain secondary. These lines are the ones
            // being read, and losing them into the background to make
            // the stamp recede would be the wrong trade.
            .foregroundStyle(.primary.opacity(0.78))
            .textSelection(.enabled)
    }

    private func showInCalendar() {
        CalendarNavigator.show(entry, timeZone: timeZone)
    }
}
