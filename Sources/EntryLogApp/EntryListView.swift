import AppKit
import SwiftUI
import CalEntryCore
import CalEntryKit

struct EntryListView: View {

    @Bindable var model: EntryLogModel

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
        .task {
            // An entry added in Calendar, or arriving from the phone,
            // should appear here without being asked for.
            for await _ in NotificationCenter.default.notifications(
                named: EventKitSource.storeChanged
            ) {
                model.reloadSoon()
            }
        }
    }


    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack(spacing: 8) {
                dayField(.start, selection: $model.startDay)

                Text("to")
                    .foregroundStyle(.secondary)

                dayField(.end, selection: $model.endDay)

                // Beside the dates, because it acts on them. The
                // list keeps itself up to date, so this is only ever a
                // retry, and an icon is as much room as that deserves.
                Button {
                    Task { await model.reload() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .keyboardShortcut("r")
                .help("Read again (⌘R)")
                .disabled(model.state == .loading)

                Spacer()

                textSizeControls
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

            if model.showsCalendarFilter { calendarFilter }
        }
        .padding(12)
    }

    /// Which calendars to read, pinned above the listing.
    ///
    /// Unticking one keeps it out of the search rather than out of the
    /// results: a calendar the reader does not want to see is a
    /// calendar there is no reason to open.
    private var calendarFilter: some View {
        VStack(alignment: .leading, spacing: 6) {

            Divider()

            WrapLayout {
                Text("Calendars")
                    .foregroundStyle(.secondary)

                ForEach(model.calendars) { calendar in
                    Toggle(calendar.title, isOn: Binding(
                        get: { model.isReading(calendar) },
                        set: { model.setReading(calendar, $0) }
                    ))
                    .toggleStyle(.checkbox)
                    .help(calendar.label)
                }

                Button("All") { model.readEveryCalendar() }
                    .buttonStyle(.link)
                    .disabled(model.excludedCalendars.isEmpty)

                Button("None") { model.readNoCalendar() }
                    .buttonStyle(.link)
                    .disabled(model.everyCalendarIsExcluded)
            }
        }
    }

    /// The same two commands the View menu carries, where the eye
    /// already is. The shortcuts live on the menu items, which is
    /// where a reader looks for them.
    private var textSizeControls: some View {
        HStack(spacing: 2) {

            Button {
                model.resize(by: -1)
            } label: {
                Image(systemName: "textformat.size.smaller")
            }
            .help("Smaller text (⌘-)")
            .disabled(!model.textScale.canShrink)

            Button {
                model.resize(by: 1)
            } label: {
                Image(systemName: "textformat.size.larger")
            }
            .help("Larger text (⌘+)")
            .disabled(!model.textScale.canGrow)
        }
    }

    /// Only for the two date fields: `2026/08/27`, whatever the Mac's
    /// region says. Nothing else in the window is localised by it.
    private static let dateFieldLocale = Locale(identifier: "ja_JP")

    /// A date field with its own pair of arrows.
    ///
    /// The stepper is separate from the field on purpose. The stock
    /// `.stepperField` picker steps whichever component is selected,
    /// which is the year until something is clicked -- so the first
    /// press of the arrow moved the range twelve months. Stepping is
    /// by the day, always, because that is the size of the question
    /// this window answers.
    private func dayField(
        _ edge: EntryLogModel.Edge, selection: Binding<Date>
    ) -> some View {
        HStack(spacing: 2) {
            DatePicker("", selection: selection, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.field)
                // Year first, to match the stamps in the listing and
                // the order the days are asked for on the command
                // line. The field otherwise follows the Mac's region,
                // which puts the month first here.
                .environment(\.locale, Self.dateFieldLocale)

            Stepper(
                "",
                onIncrement: { model.nudge(edge, byDays: 1) },
                onDecrement: { model.nudge(edge, byDays: -1) }
            )
            .labelsHidden()
        }
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
                    // Nothing across nine calendars is a quiet week.
                    // Nothing across none of them is a permission
                    // problem, and saying which saves an hour.
                    description: Text(emptyReason)
                )
            }

        case .ready:
            List(model.visible) { logged in
                EntryRowView(
                    logged: logged,
                    formatting: formatting,
                    showsRole: model.showsRoleFilter,
                    timeZone: model.timeZone,
                    scale: model.textScale
                )
            }
            .listStyle(.inset)
        }
    }

    private var emptyReason: String {

        if model.everyCalendarIsExcluded {
            return "No calendars are ticked, so nothing was read."
        }

        switch model.calendarsSearched {
        case 0:
            return "No calendars could be read. Check that Entry Log "
                + "has calendar access in Privacy Settings."
        case 1:
            return "No entries were created in this range, in the one "
                + "calendar you can write to."
        default:
            return "No entries were created in this range, across "
                + "\(model.calendarsSearched) calendars."
        }
    }

    private func centred<Inner: View>(@ViewBuilder _ inner: () -> Inner) -> some View {
        inner()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }


    private var footer: some View {
        HStack {
            Text(count)

            if model.isDemo {
                // A screenshot of this should never be mistaken for a
                // screenshot of somebody's calendar.
                Text("demo data")
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(.tint.opacity(0.15), in: Capsule())
            }

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
