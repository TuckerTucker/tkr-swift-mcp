@preconcurrency import EventKit
import Foundation

/// Production conformance delegating to `EKEventStore`.
final class EventStore: EventStoreProviding, @unchecked Sendable {
    private let store = EKEventStore()

    func requestCalendarAccess() async throws -> Bool {
        if #available(macOS 14.0, *) {
            return try await store.requestFullAccessToEvents()
        } else {
            return try await store.requestAccess(to: .event)
        }
    }

    func requestReminderAccess() async throws -> Bool {
        if #available(macOS 14.0, *) {
            return try await store.requestFullAccessToReminders()
        } else {
            return try await store.requestAccess(to: .reminder)
        }
    }

    // MARK: - Calendars

    func calendars(for entityType: EKEntityType) -> [EKCalendar] {
        store.calendars(for: entityType)
    }

    func calendar(withIdentifier identifier: String) -> EKCalendar? {
        store.calendar(withIdentifier: identifier)
    }

    func defaultCalendarForNewEvents() -> EKCalendar? {
        store.defaultCalendarForNewEvents
    }

    func defaultCalendarForNewReminders() -> EKCalendar? {
        store.defaultCalendarForNewReminders()
    }

    // MARK: - Events

    func predicateForEvents(withStart start: Date, end: Date, calendars: [EKCalendar]?) -> NSPredicate {
        store.predicateForEvents(withStart: start, end: end, calendars: calendars)
    }

    func events(matching predicate: NSPredicate) -> [EKEvent] {
        store.events(matching: predicate)
    }

    func event(withIdentifier identifier: String) -> EKEvent? {
        store.event(withIdentifier: identifier)
    }

    func save(_ event: EKEvent, span: EKSpan) throws {
        try store.save(event, span: span)
    }

    func remove(_ event: EKEvent, span: EKSpan) throws {
        try store.remove(event, span: span)
    }

    // MARK: - Reminders

    func predicateForReminders(in calendars: [EKCalendar]?) -> NSPredicate {
        store.predicateForReminders(in: calendars)
    }

    func predicateForCompletedReminders(
        withCompletionDateStarting start: Date?,
        ending end: Date?,
        calendars: [EKCalendar]?
    ) -> NSPredicate {
        store.predicateForCompletedReminders(
            withCompletionDateStarting: start,
            ending: end,
            calendars: calendars
        )
    }

    func predicateForIncompleteReminders(
        withDueDateStarting start: Date?,
        ending end: Date?,
        calendars: [EKCalendar]?
    ) -> NSPredicate {
        store.predicateForIncompleteReminders(
            withDueDateStarting: start,
            ending: end,
            calendars: calendars
        )
    }

    func fetchReminders(matching predicate: NSPredicate) async -> [EKReminder] {
        await withCheckedContinuation { cont in
            store.fetchReminders(matching: predicate) { reminders in
                nonisolated(unsafe) let result = reminders ?? []
                cont.resume(returning: result)
            }
        }
    }

    func calendarItem(withIdentifier identifier: String) -> EKCalendarItem? {
        store.calendarItem(withIdentifier: identifier)
    }

    func save(_ reminder: EKReminder, commit: Bool) throws {
        try store.save(reminder, commit: commit)
    }

    func remove(_ reminder: EKReminder, commit: Bool) throws {
        try store.remove(reminder, commit: commit)
    }

    // MARK: - Factory

    func makeEvent() -> EKEvent {
        EKEvent(eventStore: store)
    }

    func makeReminder() -> EKReminder {
        EKReminder(eventStore: store)
    }
}
