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

let source = EventKitSource()

do {
    try await source.requestAccess()
} catch {
    FileHandle.standardError.write(Data("\(error)\n".utf8))
    exit(1)
}

let planner = FetchPlanner.standard
let plan = planner.plan(for: range, timeZone: timeZone)
let log = source.log(
    createdIn: range, roles: roles, planner: planner, timeZone: timeZone
)

let stamp: (Date) -> String = { date in
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = timeZone
    formatter.dateFormat = "yyyy/MM/dd HH:mm"
    return formatter.string(from: date)
}

let day: (Date) -> String = { date in
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = timeZone
    formatter.dateFormat = "yyyy/MM/dd"
    return formatter.string(from: date)
}

print("")
print(startDay == endDay ? startDay : "\(startDay) - \(endDay)")

guard !log.isEmpty else {
    print("Nothing was written down in this range.")
    exit(0)
}

for entry in log {
    print("")
    print("  \(stamp(entry.creationDate))  [\(entry.role.rawValue)]")
    print("  \(entry.entry.displayTitle)")

    if let start = entry.entry.startDate {
        let when = entry.entry.isAllDay ? day(start) : stamp(start)
        print("    when:      \(when)")
    }

    print("    calendar:  \(entry.entry.calendarTitle)")

    if let organizer = entry.entry.organizerLabel {
        print("    set up by: \(organizer)")
    }

    let rooms = entry.entry.rooms
    if !rooms.isEmpty { print("    room:      \(rooms.joined(separator: ", "))") }

    let guests = entry.entry.guests
    if !guests.isEmpty { print("    guests:    \(guests.joined(separator: ", "))") }
}

print("")
print("\(log.count) entries. "
      + "Searched \(day(plan.span.start)) to \(day(plan.span.end)) "
      + "in \(plan.windows.count) queries.")
