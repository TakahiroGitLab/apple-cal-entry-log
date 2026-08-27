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
        content
            // The chrome the system draws, rather than a strip of
            // buttons pretending to be it: glass, the scroll-edge
            // treatment, and whatever the next release does to
            // toolbars all arrive without being asked for.
            .toolbar { toolbar }
            // The filters stay on screen -- knowing at a glance which
            // calendars are being read is the whole point of them --
            // but as a bar the scroll runs under, not a block of the
            // window nailed above it.
            .safeAreaBar(edge: .top) { filters }
            .safeAreaBar(edge: .bottom) { footer }
            .task(id: model.fetchKey) {
                // A date picker can report several changes as it is
                // being used. Waiting a moment means one search, not
                // four.
                try? await Task.sleep(for: .milliseconds(250))

                guard !Task.isCancelled else { return }

                await model.reload()
            }
            .task {
                // An entry added in Calendar, or arriving from the
                // phone, should appear here without being asked for.
                for await _ in NotificationCenter.default.notifications(
                    named: EventKitSource.storeChanged
                ) {
                    model.reloadSoon()
                }
            }
    }


    /// Only what acts on the whole window. A toolbar row is one
    /// control tall, and a date field with a stepper beside it is
    /// not: the first attempt at this put the arrows through the top
    /// and bottom of the title bar.
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {

        ToolbarItemGroup(placement: .primaryAction) {

            Button {
                Task { await model.reload() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .keyboardShortcut("r")
            .help("Read again (⌘R)")
            .disabled(model.state == .loading)

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

    /// Two rows that never trade places.
    ///
    /// What is being asked for on top, what is being shown underneath.
    /// Each group is anchored to an edge, because the role boxes come
    /// and go with the data and everything sharing a row with them
    /// used to slide as they did.
    private var filters: some View {
        VStack(alignment: .leading, spacing: 8) {

            HStack(spacing: 8) {
                dayField(.start, selection: $model.startDay)

                Text("to")
                    .foregroundStyle(.secondary)

                dayField(.end, selection: $model.endDay)

                Spacer(minLength: 12)

                // Commands, not state: they set the range and then
                // have nothing to say about it. Bordered, so they do
                // not read as another pair of switches.
                preset("Yesterday", daysAgo: 1)
                preset("Today", daysAgo: 0)
            }

            if model.showsCalendarFilter || model.showsRoleFilter {
                HStack(alignment: .firstTextBaseline, spacing: 10) {

                    if model.showsCalendarFilter { calendarFilter }

                    Spacer(minLength: 16)

                    if model.showsRoleFilter {
                        ForEach(EntryRole.allCases, id: \.self) { role in
                            Toggle(role.rawValue, isOn: binding(for: role))
                                .toggleStyle(.checkbox)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var calendarFilter: some View {

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

        Menu {
            Button("All Calendars") { model.readEveryCalendar() }
                .disabled(model.excludedCalendars.isEmpty)

            Button("No Calendars") { model.readNoCalendar() }
                .disabled(model.everyCalendarIsExcluded)
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Show every calendar, or none")
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

    @ViewBuilder
    private func preset(_ title: String, daysAgo: Int) -> some View {
        let showing = model.isShowing(daysAgo: daysAgo)

        Button(title) { model.show(daysAgo: daysAgo) }
            .buttonStyle(.bordered)
            .tint(showing ? .accentColor : nil)
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
            // The rows should pass under the bars rather than stop at
            // them, which is the whole reason the bars are glass.
            .scrollEdgeEffectStyle(.soft, for: .all)
            .scrollContentBackground(.hidden)
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
