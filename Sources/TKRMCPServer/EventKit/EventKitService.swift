@preconcurrency import EventKit
import Foundation

/// Thread-safe service wrapping EventKit operations.
actor EventKitService {
    private let store: any EventStoreProviding

    init(store: any EventStoreProviding = EventStore()) {
        self.store = store
    }

    // MARK: - Authorization

    func requestCalendarAccess() async throws -> Bool {
        try await store.requestCalendarAccess()
    }

    func requestReminderAccess() async throws -> Bool {
        try await store.requestReminderAccess()
    }

    // MARK: - Calendars

    func listCalendars(for entityType: EKEntityType) -> [CalendarDTO] {
        store.calendars(for: entityType).map { cal in
            CalendarDTO(
                id: cal.calendarIdentifier,
                title: cal.title,
                type: entityType == .event ? "event" : "reminder",
                source: cal.source?.title ?? "unknown"
            )
        }
    }

    /// Checks whether a calendar with the given identifier exists.
    func calendarExists(identifier: String) -> Bool {
        store.calendar(withIdentifier: identifier) != nil
    }

    // MARK: - Events

    func listEvents(calendarID: String?, startDate: Date, endDate: Date) -> [EventDTO] {
        let calendars: [EKCalendar]?
        if let id = calendarID, let cal = store.calendar(withIdentifier: id) {
            calendars = [cal]
        } else {
            calendars = nil
        }

        let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
        let events = store.events(matching: predicate)
        return events.map { EventDTO.from($0) }
    }

    func createEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        calendarID: String?,
        location: String?,
        notes: String?,
        isAllDay: Bool
    ) throws -> EventDTO {
        let event = store.makeEvent()
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.isAllDay = isAllDay
        event.location = location
        event.notes = notes

        if let id = calendarID, let cal = store.calendar(withIdentifier: id) {
            event.calendar = cal
        } else {
            event.calendar = store.defaultCalendarForNewEvents()
        }

        try store.save(event, span: .thisEvent)
        return EventDTO.from(event)
    }

    func deleteEvent(eventID: String, span: EKSpan = .thisEvent) throws -> Bool {
        guard let event = store.event(withIdentifier: eventID) else {
            return false
        }
        try store.remove(event, span: span)
        return true
    }

    // MARK: - Reminders

    func listReminders(calendarID: String?, completed: Bool?) async -> [ReminderDTO] {
        let calendars: [EKCalendar]?
        if let id = calendarID, let cal = store.calendar(withIdentifier: id) {
            calendars = [cal]
        } else {
            calendars = nil
        }

        let predicate: NSPredicate
        if let completed {
            if completed {
                predicate = store.predicateForCompletedReminders(
                    withCompletionDateStarting: nil,
                    ending: nil,
                    calendars: calendars
                )
            } else {
                predicate = store.predicateForIncompleteReminders(
                    withDueDateStarting: nil,
                    ending: nil,
                    calendars: calendars
                )
            }
        } else {
            predicate = store.predicateForReminders(in: calendars)
        }

        let reminders = await store.fetchReminders(matching: predicate)
        return reminders.map { ReminderDTO.from($0) }
    }

    func createReminder(
        title: String,
        calendarID: String?,
        dueDate: Date?,
        priority: Int?,
        notes: String?
    ) throws -> ReminderDTO {
        let reminder = store.makeReminder()
        reminder.title = title
        reminder.notes = notes
        reminder.priority = priority ?? 0

        if let id = calendarID, let cal = store.calendar(withIdentifier: id) {
            reminder.calendar = cal
        } else {
            reminder.calendar = store.defaultCalendarForNewReminders()
        }

        if let dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: dueDate
            )
        }

        try store.save(reminder, commit: true)
        return ReminderDTO.from(reminder)
    }

    func completeReminder(reminderID: String, completed: Bool) throws -> Bool {
        guard let reminder = store.calendarItem(withIdentifier: reminderID) as? EKReminder else {
            return false
        }
        reminder.isCompleted = completed
        if completed {
            reminder.completionDate = Date()
        }
        try store.save(reminder, commit: true)
        return true
    }

    func deleteReminder(reminderID: String) throws -> Bool {
        guard let reminder = store.calendarItem(withIdentifier: reminderID) as? EKReminder else {
            return false
        }
        try store.remove(reminder, commit: true)
        return true
    }
}
