import AppKit
import SwiftUI
import CalEntryCore

struct EntryListView: View {

    @State private var model = EntryLogModel()

    private var formatting: Formatting {
        Formatting(timeZone: model.timeZone)
    }

    var body: some View {
        VStack(spacing: 0) {
            controls
            Divider()
            content
            Divider()
            footer
        }
        .task(id: model.fetchKey) {
            // A date picker can report several changes as it is being
            // used. Waiting a moment means one search, not four.
            try? await Task.sleep(for: .milliseconds(250))

            guard !Task.isCancelled else { return }

            await model.reload()
        }
    }


    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack(spacing: 8) {
                DatePicker("", selection: $model.startDay, displayedComponents: .date)
                    .labelsHidden()

                Text("to")
                    .foregroundStyle(.secondary)

                DatePicker("", selection: $model.endDay, displayedComponents: .date)
                    .labelsHidden()

                Spacer()

                Button {
                    Task { await model.reload() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(model.state == .loading)
            }

            HStack(spacing: 8) {
                preset("Yesterday", daysAgo: 1)
                preset("Today", daysAgo: 0)

                if model.showsRoleFilter {
                    Divider().frame(height: 16)

                    ForEach(EntryRole.allCases, id: \.self) { role in
                        Toggle(role.rawValue, isOn: binding(for: role))
                            .toggleStyle(.checkbox)
                    }
                }

                Spacer()
            }
        }
        .padding(12)
    }

    private func preset(_ title: String, daysAgo: Int) -> some View {
        Button(title) {
            model.show(daysAgo: daysAgo)
        }
        .buttonStyle(.bordered)
        .tint(model.isShowing(daysAgo: daysAgo) ? .accentColor : nil)
    }

    private func binding(for role: EntryRole) -> Binding<Bool> {
        Binding(
            get: { model.roles.contains(role) },
            set: { wanted in
                if wanted { model.roles.insert(role) } else { model.roles.remove(role) }
            }
        )
    }


    @ViewBuilder
    private var content: some View {
        switch model.state {

        case .loading:
            centred { ProgressView("Reading the calendar") }

        case .needsAccess(let why):
            centred {
                ContentUnavailableView {
                    Label("No calendar access", systemImage: "lock")
                } description: {
                    Text(why)
                } actions: {
                    Button("Open Privacy Settings") { openPrivacySettings() }
                }
            }

        case .failed(let why):
            centred {
                ContentUnavailableView {
                    Label("Could not read the calendar", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(why)
                }
            }

        case .ready where model.visible.isEmpty:
            centred {
                ContentUnavailableView(
                    "Nothing was written down",
                    systemImage: "calendar.badge.clock",
                    description: Text("No entries were created in this range.")
                )
            }

        case .ready:
            List(model.visible) { logged in
                EntryRowView(
                    logged: logged,
                    formatting: formatting,
                    showsRole: model.showsRoleFilter
                )
            }
            .listStyle(.inset)
        }
    }

    private func centred<Inner: View>(@ViewBuilder _ inner: () -> Inner) -> some View {
        inner()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }


    private var footer: some View {
        HStack {
            Text(count)

            Spacer()

            if let searched = model.searched {
                // The search is bounded. Saying where it stopped is
                // more honest than implying it looked everywhere.
                Text("searched \(formatting.day(searched.start))"
                     + " to \(formatting.day(searched.end))"
                     + " in \(model.queries) queries")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var count: String {
        let shown = model.visible.count

        guard model.showsRoleFilter, shown != model.loaded.count else {
            return shown == 1 ? "1 entry" : "\(shown) entries"
        }

        return "\(shown) of \(model.loaded.count) entries"
    }

    private func openPrivacySettings() {
        guard let url = URL(string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars"
        ) else { return }

        NSWorkspace.shared.open(url)
    }
}
