import EventKit
import Foundation
import CalEntryCore

/// Converting EventKit's types into the neutral ones.
///
/// This file is the whole of what knows EventKit exists. It makes no
/// decisions -- no filtering, no role rules -- so that everything that
/// does can be tested against synthetic entries.

extension CalendarEntry {

    init(_ event: EKEvent) {
        self.init(
            // Shared by every occurrence of a repeating entry, which
            // is what makes it the right key to deduplicate on: the
            // entry was written down once.
            id: event.calendarItemIdentifier,
            externalId: event.calendarItemExternalIdentifier,
            title: event.title,
            creationDate: event.creationDate,
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            isRecurring: event.hasRecurrenceRules,
            location: event.location,
            notes: event.notes,
            url: event.url,
            calendarTitle: event.calendar?.title ?? "",
            calendarSource: event.calendar?.source?.title ?? "",
            // Missing rather than false would be the safer default,
            // but a calendar EventKit will not describe is not one the
            // user can write to either.
            calendarIsWritable: event.calendar?.allowsContentModifications ?? false,
            organizer: event.organizer.map(Participant.init),
            attendees: (event.attendees ?? []).map(Participant.init)
        )
    }
}


extension Participant {

    init(_ participant: EKParticipant) {
        self.init(
            name: participant.name,
            // EventKit gives the address as a mailto: URL.
            email: MailtoAddress.from(participant.url),
            kind: Kind(participant.participantType),
            isCurrentUser: participant.isCurrentUser
        )
    }
}


extension Participant.Kind {

    init(_ type: EKParticipantType) {
        switch type {
        case .person: self = .person
        case .room: self = .room
        case .resource: self = .resource
        case .group: self = .group
        // Includes .unknown and anything a later release adds.
        default: self = .unknown
        }
    }
}
