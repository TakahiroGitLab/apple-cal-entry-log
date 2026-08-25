# Apple Calendar Entry Log

Lists the Apple Calendar entries written down during a chosen range of
days -- by **when they were created**, not when they happen -- and says
whether the user wrote each one or was invited to it.

The same idea as [gcal-entry-log](https://github.com/TakahiroGitLab/gcal-entry-log)
for Google Calendar, rebuilt on EventKit.

## Status

The logic, the EventKit adapter, and a command line to run it. Not yet
tried against a real calendar.

```
swift run entry-log                       # today
swift run entry-log 2026-08-18 2026-08-20 # a range
swift run entry-log --created             # only what I wrote
swift run entry-log --diagnose            # what EventKit can see
```

Run `--diagnose` first. It lists the calendars EventKit can reach and,
more to the point, counts how many entries carry a `creationDate` at
all. That field is populated by the account an entry came from, not by
anything here: a local calendar always sets it, but an iCloud entry
only has one if the server sent `CREATED` with it. If the count comes
back at zero, the tool cannot work and nothing in this repo can fix
that.

On one iCloud account, 2150 of 2250 entries had one, the oldest
written in 2013. The hundred without were the subscribed holiday
calendar entire, plus twelve scattered across writable calendars --
those twelve are dropped from the log, quietly, by design.

A normal run searches only writable calendars. An entry on a read-only
one can be neither written by the user nor an invitation to them,
since an invitation has to land somewhere it can be accepted, so
skipping holidays and birthdays loses nothing and saves the reading.

The first run asks for calendar access. A command-line tool has no
bundle of its own, so macOS attributes the request to the terminal it
was launched from -- expect a prompt naming Terminal, not `entry-log`,
and look under System Settings > Privacy & Security > Calendars for
the same name. A real app later would need
`NSCalendarsFullAccessUsageDescription` in its own Info.plist.

## Layout

| | |
| --- | --- |
| `Sources/CalEntryCore` | The logic. Pure Foundation, no EventKit. |
| `Sources/CalEntryKit` | The EventKit adapter, and nothing else. |
| `Sources/EntryLogCLI` | The command line. |
| `Sources/CoreTests` | The tests, as a runnable executable. |

```
swift run core-tests
```

106 checks, no dependencies, and no Xcode: neither XCTest nor
swift-testing ships with the Command Line Tools, and reaching Xcode's
copy needs a licence agreement and `sudo`. The harness in
`Sources/CoreTests/Harness.swift` is about 100 lines and prints
`file:line` for anything that fails.

## Why the logic is split off from EventKit

`EKCalendarItem.creationDate` is **read-only**. Test events cannot be
backdated, so no real calendar -- a copied public one, or events
inserted locally -- can produce entries created last Tuesday. Range and
role filtering can only be exercised against synthetic data, which
means the rules have to live somewhere EventKit is not.

The adapter (step 2) will convert `EKEvent` into `CalendarEntry` and
nothing more.

## What the rules are

**Role.** EventKit records no creator, only an organizer, and an
organizer exists only once an entry has invitees:

| | |
| --- | --- |
| Organizer is the user | `created` |
| Organizer is somebody else, user on the guest list | `invited` |
| Organizer is somebody else, user not on it | neither |
| No organizer, calendar is writable | `created` |
| No organizer, calendar is read-only | neither |

The first two are checked in that order, so an entry the user organised
*and* attends counts once. The gap: a plain, invitee-less entry that
somebody else wrote into a calendar shared with the user for writing is
indistinguishable from the user's own. EventKit stores no author for
it.

**Days.** `DayRange` is half-open -- midnight on the first day to
midnight after the last -- so 23:59 on the final day is in. The end is
widened by calendar arithmetic rather than 86 400 seconds, so a range
crossing a daylight-saving change still covers whole days.

**The fetch plan.** EventKit can only be queried by when an entry
*happens*. So the store is over-fetched by event date and filtered on
`creationDate` afterwards. A single query cannot span more than four
years -- but nothing stops several of them, so `FetchPlanner` cuts the
searched span into abutting windows that each fit. The default is a
decade either side of the range, which is five queries over a local
store: cheap.

Windows abut rather than overlap, but EventKit returns any entry
*overlapping* a window, so one straddling a boundary comes back twice.
The adapter deduplicates by calendar item identifier -- which it must
do regardless, since every occurrence of a repeating entry shares one
identifier and one creation date.

The search is still bounded, so `FetchPlan.span` reports where it
stopped. Saying so is more honest than implying it looked everywhere.

## The invited role, on an account with no shared calendars

On the account this was built against, every entry is one the user
wrote: nothing is shared, so nothing is an invitation, and the invited
role is correctly empty rather than broken. That may change.

So the rule is not to remove the role but to stop showing it: the
listing tags entries with their role only when more than one role is
present. An always-empty filter is a dead control, and a filter that
appears the day a shared calendar turns up needs no setting and no
second thought.

## Next

- A way to open an entry in Calendar from the list.
- An interface. Note this is per-Mac: the iPhone would need an actual
  app.
