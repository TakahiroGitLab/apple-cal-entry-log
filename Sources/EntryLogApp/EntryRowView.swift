import AppKit
import SwiftUI
import CalEntryCore

struct EntryRowView: View {

    let logged: LoggedEntry
    let formatting: Formatting
    let showsRole: Bool
    let timeZone: TimeZone
    let scale: TextScale

    private var entry: CalendarEntry { logged.entry }

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

                Text(formatting.stamp(logged.creationDate))
                    .font(scale.font(11))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
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
                // The whole note on hover: the line only has room for
                // the opening of it.
                detail(note, icon: "text.alignleft")
                    .help(entry.notes ?? note)
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
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
    }

    private func showInCalendar() {
        CalendarNavigator.show(entry, timeZone: timeZone)
    }
}
