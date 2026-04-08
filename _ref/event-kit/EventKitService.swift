import EventKit
import Foundation

/// Wraps EventKit with async/await and JSON-friendly outputs.
actor EventKitService {
    private let store = EKEventStore()

    // MARK: - Authorization

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

    func listCalendars(for entityType: EKEntityType) -> [[String: String]] {
        store.calendars(for: entityType).map { cal in
            [
                "id": cal.calendarIdentifier,
                "title": cal.title,
                "type": entityType == .event ? "event" : "reminder",
                "source": cal.source?.title ?? "unknown",
            ]
        }
    }

    // MARK: - Events

    func listEvents(
        calendarID: String?,
        startDate: Date,
        endDate: Date
    ) -> [[String: Any]] {
        let calendars: [EKCalendar]?
        if let id = calendarID, let cal = store.calendar(withIdentifier: id) {
            calendars = [cal]
        } else {
            calendars = nil
        }

        let predicate = store.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: calendars
        )
        let events = store.events(matching: predicate)
        return events.map { eventToDict($0) }
    }

    func createEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        calendarID: String?,
        location: String?,
        notes: String?,
        isAllDay: Bool
    ) throws -> [String: Any] {
        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.isAllDay = isAllDay
        event.location = location
        event.notes = notes

        if let id = calendarID, let cal = store.calendar(withIdentifier: id) {
            event.calendar = cal
        } else {
            event.calendar = store.defaultCalendarForNewEvents
        }

        try store.save(event, span: .thisEvent)
        return eventToDict(event)
    }

    func deleteEvent(eventID: String) throws -> Bool {
        guard let event = store.event(withIdentifier: eventID) else {
            return false
        }
        try store.remove(event, span: .thisEvent)
        return true
    }

    // MARK: - Reminders

    func listReminders(
        calendarID: String?,
        completed: Bool?
    ) async -> [[String: Any]] {
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

        return await withCheckedContinuation { cont in
            store.fetchReminders(matching: predicate) { reminders in
                let result = (reminders ?? []).map { self.reminderToDict($0) }
                cont.resume(returning: result)
            }
        }
    }

    func createReminder(
        title: String,
        calendarID: String?,
        dueDate: Date?,
        priority: Int?,
        notes: String?
    ) throws -> [String: Any] {
        let reminder = EKReminder(eventStore: store)
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
        return reminderToDict(reminder)
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

    // MARK: - Serialization Helpers

    private nonisolated func eventToDict(_ event: EKEvent) -> [String: Any] {
        var dict: [String: Any] = [
            "id": event.eventIdentifier ?? "",
            "title": event.title ?? "",
            "startDate": ISO8601DateFormatter().string(from: event.startDate),
            "endDate": ISO8601DateFormatter().string(from: event.endDate),
            "isAllDay": event.isAllDay,
            "calendar": event.calendar?.title ?? "",
        ]
        if let location = event.location { dict["location"] = location }
        if let notes = event.notes { dict["notes"] = notes }
        if let url = event.url { dict["url"] = url.absoluteString }
        return dict
    }

    private nonisolated func reminderToDict(_ reminder: EKReminder) -> [String: Any] {
        var dict: [String: Any] = [
            "id": reminder.calendarItemIdentifier,
            "title": reminder.title ?? "",
            "isCompleted": reminder.isCompleted,
            "priority": reminder.priority,
            "calendar": reminder.calendar?.title ?? "",
        ]
        if let notes = reminder.notes { dict["notes"] = notes }
        if let due = reminder.dueDateComponents,
           let date = Calendar.current.date(from: due)
        {
            dict["dueDate"] = ISO8601DateFormatter().string(from: date)
        }
        if let completionDate = reminder.completionDate {
            dict["completionDate"] = ISO8601DateFormatter().string(from: completionDate)
        }
        return dict
    }
}
