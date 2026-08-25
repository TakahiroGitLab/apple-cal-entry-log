import Foundation
import CalEntryCore
import CalEntryKit

// A thin way to run the thing from a terminal, ahead of any interface.
//
//   swift run entry-log                       today
//   swift run entry-log 2026-08-18            that day
//   swift run entry-log 2026-08-18 2026-08-20 that range
//   swift run entry-log --created             only what I wrote
//   swift run entry-log --invited             only what I was asked to

let arguments = Array(CommandLine.arguments.dropFirst())

guard !arguments.contains("--help"), !arguments.contains("-h") else {
    print("""
        usage: entry-log [start] [end] [--created] [--invited]

          start, end  days as yyyy-MM-dd, defaulting to today
          --created   only entries the user wrote
          --invited   only entries the user was invited to
                      (neither flag means both)
          --diagnose  report what EventKit can see, and how many
                      entries carry a creation date at all
        """)
    exit(0)
}

let flags = arguments.filter { $0.hasPrefix("--") }
let days = arguments.filter { !$0.hasPrefix("--") }

var roles: Set<EntryRole> = []
if flags.contains("--created") { roles.insert(.created) }
if flags.contains("--invited") { roles.insert(.invited) }
if roles.isEmpty { roles = Set(EntryRole.allCases) }

let timeZone = TimeZone.current

let today: String = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = timeZone
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: Date())
}()

let startDay = days.first ?? today
let endDay = days.count > 1 ? days[1] : startDay

let range: DayRange

do {
    range = try DayRange.between(
        startDay: startDay, endDay: endDay, timeZone: timeZone
    )
} catch {
    FileHandle.standardError.write(Data("\(error)\n".utf8))
    exit(2)
}

let stamp: (Date) -> String = { date in
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = timeZone
    formatter.dateFormat = "yyyy/MM/dd HH:mm"
    return formatter.string(from: date)
}

let clock: (Date) -> String = { date in
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = timeZone
    formatter.dateFormat = "HH:mm"
    return formatter.string(from: date)
}

let day: (Date) -> String = { date in
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = timeZone
    formatter.dateFormat = "yyyy/MM/dd"
    return formatter.string(from: date)
}

/// Terminals that understand OSC 8 turn the text into a link;
/// those that do not ignore the sequence. Skipped when the output is
/// not a terminal, so a redirected run stays plain text.
let outputIsATerminal = isatty(FileHandle.standardOutput.fileDescriptor) == 1

func hyperlink(_ text: String, to url: URL) -> String {

    guard outputIsATerminal else { return text }

    let escape = "\u{1B}"

    return escape + "]8;;" + url.absoluteString + escape + "\\"
        + text
        + escape + "]8;;" + escape + "\\"
}


/// When an entry runs, as one line: the start, the end in whichever
/// form is not repetitive, and how long that comes to.
func whenLine(_ entry: CalendarEntry) -> String? {

    guard let start = entry.startDate else { return nil }

    let length = entry.duration(in: timeZone)

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone

    guard let end = entry.endDate, end > start else {
        return entry.isAllDay ? "\(day(start)) (all day)" : stamp(start)
    }

    let sameDay = calendar.isDate(start, inSameDayAs: end)

    if entry.isAllDay {
        return sameDay
            ? "\(day(start)) (all day)"
            : "\(day(start)) - \(day(end)) (\(length ?? "all day"))"
    }

    // Repeating the date when it has not changed is just noise.
    let finish = sameDay ? clock(end) : stamp(end)
    let tail = length.map { " (\($0))" } ?? ""

    return "\(stamp(start)) - \(finish)\(tail)"
}

let source = EventKitSource()

do {
    try await EventKitSource.requestAccess()
} catch {
    FileHandle.standardError.write(Data("\(error)\n".utf8))
    exit(1)
}

if flags.contains("--diagnose") {

    print("")
    print("Calendars")

    for calendar in source.calendars() {
        let access = calendar.isWritable ? "writable" : "read-only"
        let subscribed = calendar.isSubscribed ? ", subscribed" : ""
        print("  \(calendar.source) / \(calendar.title)")
        print("      \(calendar.kind), \(access)\(subscribed)")
    }

    // The whole tool rests on creationDate being populated, and
    // whether it is depends on the account an entry came from rather
    // than on anything here. So: count.
    let wide = FetchPlanner.standard.plan(for: range, timeZone: timeZone)

    print("")
    print("Reading every calendar, \(day(wide.span.start))"
          + " to \(day(wide.span.end)), in \(wide.windows.count) queries."
          + " A normal run searches only the writable ones.")

    let all = source.entries(matching: wide)

    var missingByCalendar: [String: Int] = [:]
    var totalByCalendar: [String: Int] = [:]
    var dated: [Date] = []

    for entry in all {
        totalByCalendar[entry.calendarLabel, default: 0] += 1

        if let created = entry.creationDate {
            dated.append(created)
        } else {
            missingByCalendar[entry.calendarLabel, default: 0] += 1
        }
    }

    print("")
    print("Creation dates")
    print("  \(all.count) entries, \(dated.count) with a creation date")

    if let earliest = dated.min(), let latest = dated.max() {
        print("  earliest written \(stamp(earliest))")
        print("  latest written   \(stamp(latest))")
    }

    if missingByCalendar.isEmpty {
        print("  none missing")
    } else {
        print("  missing:")
        for (calendar, count) in missingByCalendar.sorted(by: { $0.key < $1.key }) {
            let total = totalByCalendar[calendar] ?? count
            print("    \(calendar): \(count) of \(total)")
        }
    }

    // Whether nobody invites the user, or whether EventKit fails to
    // recognise the user when somebody does, look identical in the
    // role tally. These tell them apart.
    var withOrganizer = 0
    var organizedByUser = 0
    var withAttendees = 0
    var userOnTheList = 0

    for entry in all {
        if let organizer = entry.organizer {
            withOrganizer += 1
            if organizer.isCurrentUser { organizedByUser += 1 }
        }

        if !entry.attendees.isEmpty {
            withAttendees += 1
            if entry.attendees.contains(where: \.isCurrentUser) {
                userOnTheList += 1
            }
        }
    }

    print("")
    print("Invitations")
    print("  \(withOrganizer) entries name an organiser,"
          + " \(organizedByUser) of them you")
    print("  \(withAttendees) entries have a guest list,"
          + " \(userOnTheList) of them include you")

    var byRole: [String: Int] = [:]
    for entry in all {
        byRole[entry.role?.rawValue ?? "neither", default: 0] += 1
    }

    print("")
    print("Roles")
    for (role, count) in byRole.sorted(by: { $0.key < $1.key }) {
        print("  \(role): \(count)")
    }

    print("")
    exit(0)
}

source.refresh()

let reading = source.log(
    createdIn: range, roles: roles, planner: .standard, timeZone: timeZone
)

let log = reading.entries
let plan = reading.plan

print("")
print(startDay == endDay ? startDay : "\(startDay) - \(endDay)")

guard !log.isEmpty else {
    print("Nothing was written down in this range.")
    exit(0)
}

// Only worth saying which role an entry has when there is more than
// one to tell apart. On an account nobody shares a calendar with,
// every entry is one the user wrote, and tagging each of them
// "created" says nothing. It starts appearing on its own the day a
// shared calendar turns up.
let rolesPresent = Set(log.map(\.role))
let showRole = rolesPresent.count > 1

for entry in log {
    let tag = showRole ? "  [\(entry.role.rawValue)]" : ""

    print("")
    print("  \(stamp(entry.creationDate))\(tag)")
    print("  \(entry.entry.displayTitle)")

    if let when = whenLine(entry.entry) {
        print("    when:      \(when)")
    }

    if let where_ = entry.entry.locationLabel {
        print("    where:     \(where_)")
    }

    print("    calendar:  \(entry.entry.calendarLabel)")

    if let organizer = entry.entry.organizerLabel {
        print("    set up by: \(organizer)")
    }

    let rooms = entry.entry.rooms
    if !rooms.isEmpty { print("    room:      \(rooms.joined(separator: ", "))") }

    let guests = entry.entry.guests
    if !guests.isEmpty { print("    guests:    \(guests.joined(separator: ", "))") }

    if let note = entry.entry.noteSummary {
        print("    note:      \(note)")
    }

    if let url = entry.entry.url, let label = LinkLabel.describe(url) {
        print("    link:      \(hyperlink(label, to: url))")
    }
}

print("")
print("\(log.count) entries. "
      + "Searched \(reading.calendarsSearched) calendars, "
      + "\(day(plan.span.start)) to \(day(plan.span.end)), "
      + "in \(plan.windows.count) queries.")
