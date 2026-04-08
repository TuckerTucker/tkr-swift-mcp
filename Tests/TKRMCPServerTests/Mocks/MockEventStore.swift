@preconcurrency import EventKit
import Foundation
@testable import TKRMCPServer

/// In-memory mock of `EventStoreProviding` for unit testing.
/// Uses a real `EKEventStore` for object creation but does not persist.
final class MockEventStore: EventStoreProviding, @unchecked Sendable {
    let backingStore = EKEventStore()

    var calendarAccessGranted: Bool = true
    var reminderAccessGranted: Bool = true

    // In-memory storage
    var storedEvents: [EKEvent] = []
    var storedReminders: [EKReminder] = []
    var storedCalendars: [EKCalendar] = []

    // Call tracking
    private(set) var savedEvents: Int = 0
    private(set) var removedEvents: Int = 0
    private(set) var savedReminders: Int = 0
    private(set) var removedReminders: Int = 0

    // MARK: - Authorization

    func requestCalendarAccess() async throws -> Bool {
        calendarAccessGranted
    }

    func requestReminderAccess() async throws -> Bool {
        reminderAccessGranted
    }

    // MARK: - Calendars

    func calendars(for entityType: EKEntityType) -> [EKCalendar] {
        storedCalendars.filter { cal in
            if entityType == .event {
                return cal.allowedEntityTypes.contains(.event)
            } else {
                return cal.allowedEntityTypes.contains(.reminder)
            }
        }
    }

    func calendar(withIdentifier identifier: String) -> EKCalendar? {
        storedCalendars.first { $0.calendarIdentifier == identifier }
    }

    func defaultCalendarForNewEvents() -> EKCalendar? {
        storedCalendars.first
    }

    func defaultCalendarForNewReminders() -> EKCalendar? {
        storedCalendars.first
    }

    // MARK: - Events

    func predicateForEvents(withStart start: Date, end: Date, calendars: [EKCalendar]?) -> NSPredicate {
        backingStore.predicateForEvents(withStart: start, end: end, calendars: calendars)
    }

    func events(matching predicate: NSPredicate) -> [EKEvent] {
        storedEvents
    }

    func event(withIdentifier identifier: String) -> EKEvent? {
        storedEvents.first { $0.eventIdentifier == identifier }
    }

    func save(_ event: EKEvent, span: EKSpan) throws {
        savedEvents += 1
        if !storedEvents.contains(where: { $0 === event }) {
            storedEvents.append(event)
        }
    }

    func remove(_ event: EKEvent, span: EKSpan) throws {
        removedEvents += 1
        storedEvents.removeAll { $0 === event }
    }

    // MARK: - Reminders

    func predicateForReminders(in calendars: [EKCalendar]?) -> NSPredicate {
        backingStore.predicateForReminders(in: calendars)
    }

    func predicateForCompletedReminders(
        withCompletionDateStarting start: Date?,
        ending end: Date?,
        calendars: [EKCalendar]?
    ) -> NSPredicate {
        backingStore.predicateForCompletedReminders(
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
        backingStore.predicateForIncompleteReminders(
            withDueDateStarting: start,
            ending: end,
            calendars: calendars
        )
    }

    func fetchReminders(matching predicate: NSPredicate) async -> [EKReminder] {
        storedReminders
    }

    func calendarItem(withIdentifier identifier: String) -> EKCalendarItem? {
        storedReminders.first { $0.calendarItemIdentifier == identifier }
    }

    func save(_ reminder: EKReminder, commit: Bool) throws {
        savedReminders += 1
        if !storedReminders.contains(where: { $0 === reminder }) {
            storedReminders.append(reminder)
        }
    }

    func remove(_ reminder: EKReminder, commit: Bool) throws {
        removedReminders += 1
        storedReminders.removeAll { $0 === reminder }
    }

    // MARK: - Factory

    func makeEvent() -> EKEvent {
        EKEvent(eventStore: backingStore)
    }

    func makeReminder() -> EKReminder {
        EKReminder(eventStore: backingStore)
    }
}
