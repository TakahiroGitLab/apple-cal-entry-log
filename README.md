# Apple Calendar Entry Log

Lists the Apple Calendar entries written down during a chosen range of
days -- by **when they were created**, not when they happen -- and says
whether you wrote each one or were invited to it.

The same idea as [gcal-entry-log](https://github.com/TakahiroGitLab/gcal-entry-log)
for Google Calendar, rebuilt on EventKit. Working against real iCloud
calendars.

## Running it

```
./Scripts/install.sh              # build, and put it in /Applications
./Scripts/make-app.sh             # build into build/ only
```

No Xcode: SwiftPM builds the binary against the Command Line Tools SDK
and the script assembles the bundle around it, ad-hoc signed.

Use `install.sh` once a copy lives in `/Applications`. Building into
`build/` alone leaves that copy stale, and running yesterday's app
while editing today's is a confusing afternoon. It quits a running
copy, replaces the installed one outright rather than copying over it,
and checks the signature afterwards.

The window takes a range, has Yesterday and Today to hand, and lists
what was written down in it, oldest first. Ticking a role filters what
is already loaded rather than searching again. It reads again by itself
whenever the calendar changes -- an entry added here, or arriving from
the phone -- so the reload button (⌘R) is only ever a retry.

Double-click a row to open it in Calendar: the month it falls in,
with the entry itself selected. A repeating entry is an exception --
the month, unhighlighted -- for the reason under the findings below.
There is also a command line, which prints the same thing:

```
swift run entry-log                       # today
swift run entry-log 2026-08-18 2026-08-20 # a range
swift run entry-log --created             # only what I wrote
swift run entry-log --diagnose            # what EventKit can see
```

`--diagnose` is worth running first on any new account. It lists the
calendars EventKit can reach and counts how many entries carry a
`creationDate` at all -- see below for why that is the question the
whole tool rests on.

## Permissions

The app asks for two, both in its own name, because the bundle carries
an Info.plist saying why:

- **Calendars**, to read them. Nothing is ever written.
- **Apple Events**, to send Calendar to a day. No other command is
  sent.

The command line has no bundle, so macOS attributes its request to the
terminal it was launched from. Expect a prompt naming Terminal, and
look for the same name under System Settings > Privacy & Security.

## What is where

| | |
| --- | --- |
| `Sources/CalEntryCore` | Every decision. Pure Foundation, no EventKit. |
| `Sources/CalEntryKit` | The EventKit adapter, and nothing else. |
| `Sources/EntryLogApp` | The SwiftUI window. |
| `Sources/EntryLogCLI` | The command line. |
| `Sources/CoreTests` | The tests, as a runnable executable. |

```
swift run core-tests
```

133 checks, no dependencies, and no Xcode -- neither XCTest nor
swift-testing ships with the Command Line Tools, and reaching Xcode's
copy needs a licence agreement and `sudo`. The harness in
`Sources/CoreTests/Harness.swift` is about a hundred lines and prints
`file:line` for anything that fails.

**Why the split.** `EKCalendarItem.creationDate` is read-only. Test
entries cannot be backdated, so no real calendar -- a copied public
one, or entries inserted locally -- can produce something created last
Tuesday. The range and role rules can only be exercised against
synthetic data, which means they have to live somewhere EventKit is
not. `CalEntryKit` converts `EKEvent` into `CalendarEntry` and makes no
decisions at all.

## The rules

**Role.** EventKit records no creator, only an organizer, and an
organizer exists only once an entry has invitees:

| | |
| --- | --- |
| Organizer is you | `created` |
| Organizer is somebody else, you are on the guest list | `invited` |
| Organizer is somebody else, you are not | neither |
| No organizer, calendar is writable | `created` |
| No organizer, calendar is read-only | neither |

The first two are checked in that order, so an entry you organised
*and* attend counts once. The gap: a plain, invitee-less entry that
somebody else wrote into a calendar shared with you for writing is
indistinguishable from your own. EventKit stores no author for it.

Only writable calendars are searched. An entry on a read-only one can
be neither written by you nor an invitation to you, since an invitation
has to land somewhere it can be accepted, so skipping holidays and
birthdays loses nothing and saves the reading.

**The invited role, with nothing shared.** On the account this was
built against nothing is shared, so nothing is an invitation, and the
role is correctly empty rather than broken. The answer is not to remove
it but to stop showing it: the role is named, and its filter offered,
only when more than one role is present. An always-empty filter is a
dead control, and one that appears by itself the day a shared calendar
turns up needs no setting and no second thought.

**Days.** `DayRange` is half-open -- midnight on the first day to
midnight after the last -- so 23:59 on the final day is in. The end is
widened by calendar arithmetic rather than 86 400 seconds, so a range
crossing a daylight-saving change still covers whole days.

**The fetch plan.** EventKit can only be queried by when an entry
*happens*, so the store is over-fetched by event date and filtered on
`creationDate` afterwards. A single query cannot span more than four
years -- but nothing stops several of them, so `FetchPlanner` cuts the
searched span into abutting windows that each fit. The default reaches
a decade either side of the range, six queries over a local store,
which takes about a second.

Windows abut rather than overlap, but EventKit returns any entry
*overlapping* a window, so one straddling a boundary comes back twice.
The adapter deduplicates by calendar item identifier -- which it must
do regardless, since every occurrence of a repeating entry shares one
identifier and one creation date.

The search is bounded, so `FetchPlan.span` reports where it stopped,
and both front ends show it. Saying so is more honest than implying it
looked everywhere.

## What the listing shows

What the reader does not already know, and no more.

A location from Maps arrives as name, postal address and country
across three lines. The postcode goes, and so does "Japan" -- but only
Japan: a country that is *not* home is exactly the sort of thing worth
seeing. A street number is never mistaken for a postcode, and a place
merely containing the word, like Japan Post, keeps its name.

Notes are flattened to one line and cut to 50 characters, by character
rather than by byte, so Japanese is neither mangled nor cut three
characters in. The window shows the whole note on hover.

Links are named, not spelled out. An entry written from an invitation
carries a `message:` URL back to the mail it came from, which in full
is a line of message-id and no information; it reads "email". A web
link shows its host. In the window it is a button; the command line
wraps it in an OSC 8 escape, so terminals that understand one make it
clickable, terminals that do not -- Terminal.app among them -- print
the label plain, and a redirected run stays plain text.

A row with nothing to say on a line does not print that line.

## What EventKit would not do

Six findings that cost real time, kept here so they are not
rediscovered.

**A store made before access is granted stays empty afterwards.** The
window showed nothing on first launch while the command line worked,
because the command line already had access when it made its store. The
store is now made on first use, after authorisation, and reset before
every read -- which is also what lets a reload pick up an entry added
in Calendar a minute ago.

**`ical://ekevent/<id>` ignores the id** -- with Spotlight's
`?method=show&options=more` on the end as much as without. Calendar
opens and stays where it was. What does work is AppleScript, and which
AppleScript matters by two orders of magnitude: `first event whose uid
= ...` scans, and a scan across these calendars ran two minutes without
finishing, while `event id "..." of calendar "..."` is a direct lookup
and answers in a quarter of a second. `show` on the result selects the
entry in month view without leaving it.

**A repeating entry cannot be selected, only landed near.** Every
occurrence of a series carries the one identifier, and Calendar's
scripting has no way to name an occurrence, so `show` picks whichever
it likes -- April, for an entry the log is listing under July. Those
rows are sent to the month and left unhighlighted, which is the lesser
wrong.

**`view calendar at` honours a date and ignores the time.** So day view
lands on the right day scrolled to the wrong hour -- a four o'clock
entry shown against eight in the morning, which reads as the wrong
entry entirely. The jump uses month view, which has no hours to be
wrong about.

**The four-year limit is per predicate, not per search.** This one
nearly ended the project: read as a limit on the search, it means
entries can be missed with no way to know. Read correctly, it means
writing a loop.

**iCloud does populate `creationDate`** -- which was not a given, since
a CalDAV entry only has one if the server sent `CREATED` with it. On
this account, 2150 entries of 2250 had one, the oldest written in 2013.
The hundred without were a subscribed holiday calendar entire, plus
twelve strays on writable calendars; those twelve are dropped from the
log, quietly, by design.

## Next

- The row layout is being reconsidered. It is all in
  `Sources/EntryLogApp/EntryRowView.swift`.
- If this is ever published, notes should show as a marker rather than
  their opening line, revealed on hover or a click. A calendar note is
  as likely to hold a door code as a reminder, and a listing that puts
  one on screen is a listing that puts one in a screenshot.

This is per-Mac. The iPhone would need an actual app.

## Licence

MIT. See [LICENSE](LICENSE).
