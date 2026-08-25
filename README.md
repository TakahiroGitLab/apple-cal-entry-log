# Apple Calendar Entry Log

Lists the Apple Calendar entries written down during a chosen range of
days -- by **when they were created**, not when they happen -- and says
whether the user wrote each one or was invited to it.

The same idea as [gcal-entry-log](https://github.com/TakahiroGitLab/gcal-entry-log)
for Google Calendar, rebuilt on EventKit.

## Status

A window, a command line, and the logic behind both. Working against a
real iCloud calendar.

```
./Scripts/make-app.sh && open build/EntryLog.app
```

That builds `EntryLog.app` -- no Xcode: SwiftPM builds the binary
against the Command Line Tools SDK and the script assembles the bundle
around it, ad-hoc signed. The bundle matters for more than
double-clicking: it carries the Info.plist, and the Info.plist is what
lets macOS ask for calendar access in this app's name instead of the
terminal's.

The window takes a range, has Yesterday and Today to hand, and lists
what was written down in it. Ticking a role filters what is already
loaded rather than searching again. Double-click a row, or use its
context menu, to open the entry in Calendar.

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
| `Sources/EntryLogApp` | The SwiftUI window. |
| `Sources/EntryLogCLI` | The command line. |
| `Sources/CoreTests` | The tests, as a runnable executable. |

```
swift run core-tests
```

137 checks, no dependencies, and no Xcode: neither XCTest nor
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

## Reading, not archiving

The listing shows what the reader does not already know. A location
from Maps arrives as name, postal address and country across three
lines; the postcode and "Japan" are dropped, and a country that is
*not* Japan is kept, because that is exactly the sort of thing worth
seeing. Notes are cut to 50 characters on one line. The role is named
only when more than one is present.

Links are named, not spelled out. An entry written from an invitation
carries a `message:` URL back to the mail it came from, which in full
is a line of message-id and no information; it shows as "email", and
the listing wraps it in an OSC 8 escape so terminals that understand
one make it clickable. A web link shows its host. Terminals that do
not understand OSC 8 -- Terminal.app among them -- just print the
label, and a redirected run stays plain text.

An entry with nothing to say on a line does not print that line.

## Next

- Live with it for a while.
- If it is ever published: notes should show as a marker rather than
  their opening line, revealed on hover or a click. A calendar note is
  as likely to hold a door code as a reminder, and a listing that puts
  one on screen is a listing that puts one in a screenshot.

Note this is per-Mac. The iPhone would need an actual app.
