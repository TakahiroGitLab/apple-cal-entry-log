import AppKit
import SwiftUI
import CalEntryCore

struct EntryRowView: View {

    let logged: LoggedEntry
    let formatting: Formatting
    let showsRole: Bool

    private var entry: CalendarEntry { logged.entry }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {

            HStack(spacing: 8) {
                Text(formatting.stamp(logged.creationDate))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)

                if showsRole {
                    Text(logged.role.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.tint.opacity(0.15), in: Capsule())
                }
            }

            Text(entry.displayTitle)
                .font(.headline)

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
                        .font(.caption)
                }
                .buttonStyle(.link)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { openInCalendar() }
        .contextMenu {
            Button("Open in Calendar") { openInCalendar() }
                .disabled(entry.calendarAppLink == nil)
        }
        .help("Double-click to open in Calendar")
    }

    private func detail(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.callout)
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
    }

    private func openInCalendar() {
        guard let link = entry.calendarAppLink else { return }
        NSWorkspace.shared.open(link)
    }
}
