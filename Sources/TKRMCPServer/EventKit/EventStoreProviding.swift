import EventKit
import Foundation

/// Abstracts `EKEventStore` operations for testability.
protocol EventStoreProviding: Sendable {
    func requestCalendarAccess() async throws -> Bool
    func requestReminderAccess() async throws -> Bool

    // Calendars
    func calendars(for entityType: EKEntityType) -> [EKCalendar]
    func calendar(withIdentifier identifier: String) -> EKCalendar?
    func defaultCalendarForNewEvents() -> EKCalendar?
    func defaultCalendarForNewReminders() -> EKCalendar?

    // Events
    func predicateForEvents(withStart start: Date, end: Date, calendars: [EKCalendar]?) -> NSPredicate
    func events(matching predicate: NSPredicate) -> [EKEvent]
    func event(withIdentifier identifier: String) -> EKEvent?
    func save(_ event: EKEvent, span: EKSpan) throws
    func remove(_ event: EKEvent, span: EKSpan) throws

    // Reminders
    func predicateForReminders(in calendars: [EKCalendar]?) -> NSPredicate
    func predicateForCompletedReminders(
        withCompletionDateStarting start: Date?,
        ending end: Date?,
        calendars: [EKCalendar]?
    ) -> NSPredicate
    func predicateForIncompleteReminders(
        withDueDateStarting start: Date?,
        ending end: Date?,
        calendars: [EKCalendar]?
    ) -> NSPredicate
    func fetchReminders(matching predicate: NSPredicate) async -> [EKReminder]
    func calendarItem(withIdentifier identifier: String) -> EKCalendarItem?
    func save(_ reminder: EKReminder, commit: Bool) throws
    func remove(_ reminder: EKReminder, commit: Bool) throws

    // Factory — needed so tests/production can create EKEvent/EKReminder bound to the store
    func makeEvent() -> EKEvent
    func makeReminder() -> EKReminder
}
