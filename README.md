# Apple Calendar Entry Log

Lists the Apple Calendar entries written down during a chosen range of
days -- by **when they were created**, not when they happen -- and says
whether the user wrote each one or was invited to it.

The same idea as [gcal-entry-log](https://github.com/TakahiroGitLab/gcal-entry-log)
for Google Calendar, rebuilt on EventKit.

## Status

Step 1 of the port: the entry model and the filtering and role rules.
No EventKit yet -- nothing here imports it.

## Layout

| | |
| --- | --- |
| `Sources/CalEntryCore` | The logic. Pure Foundation. |
| `Sources/CoreTests` | The tests, as a runnable executable. |

```
swift run core-tests
```

52 checks, no dependencies, and no Xcode: neither XCTest nor
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

**The fetch window is the awkward part.** EventKit can only be queried
by when an entry *happens*. So the store has to be over-fetched by
event date and filtered on `creationDate` afterwards. Unlike the Google
version's `updatedMin`, this prefilter is **not** guaranteed to be a
superset: an entry written today for a clinic three years out falls
outside any sane window, and nothing in the store hints that it was
missed. `FetchWindowPolicy` defaults to a year behind and two years
ahead, and clamps to the four years EventKit will accept -- trimming
the past first, since entries are usually written for what is coming.

## Next

- EventKit adapter: authorisation, `predicateForEvents`, `EKEvent` ->
  `CalendarEntry`.
- A front end. Note this is per-Mac: the iPhone would need an actual
  app.
