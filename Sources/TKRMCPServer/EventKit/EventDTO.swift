import EventKit
import Foundation

/// Calendar representation returned by MCP tools.
struct CalendarDTO: Codable, Equatable, Sendable {
    let id: String
    let title: String
    let type: String
    let source: String
}

/// Calendar event representation returned by MCP tools.
struct EventDTO: Codable, Equatable, Sendable {
    let id: String
    let title: String
    let startDate: String
    let endDate: String
    let isAllDay: Bool
    let calendar: String
    var location: String?
    var notes: String?
    var url: String?
}

/// Reminder representation returned by MCP tools.
struct ReminderDTO: Codable, Equatable, Sendable {
    let id: String
    let title: String
    let isCompleted: Bool
    let priority: Int
    let calendar: String
    var notes: String?
    var dueDate: String?
    var completionDate: String?
}

// MARK: - EKEvent / EKReminder Conversion

extension EventDTO {
    static func from(_ event: EKEvent) -> EventDTO {
        let fmt = ISO8601DateFormatter()
        var dto = EventDTO(
            id: event.eventIdentifier ?? "",
            title: event.title ?? "",
            startDate: fmt.string(from: event.startDate),
            endDate: fmt.string(from: event.endDate),
            isAllDay: event.isAllDay,
            calendar: event.calendar?.title ?? ""
        )
        if let location = event.location, !location.isEmpty { dto.location = location }
        if let notes = event.notes, !notes.isEmpty { dto.notes = notes }
        if let url = event.url { dto.url = url.absoluteString }
        return dto
    }
}

extension ReminderDTO {
    static func from(_ reminder: EKReminder) -> ReminderDTO {
        let fmt = ISO8601DateFormatter()
        var dto = ReminderDTO(
            id: reminder.calendarItemIdentifier,
            title: reminder.title ?? "",
            isCompleted: reminder.isCompleted,
            priority: reminder.priority,
            calendar: reminder.calendar?.title ?? ""
        )
        if let notes = reminder.notes, !notes.isEmpty { dto.notes = notes }
        if let due = reminder.dueDateComponents, let date = Calendar.current.date(from: due) {
            dto.dueDate = fmt.string(from: date)
        }
        if let completionDate = reminder.completionDate {
            dto.completionDate = fmt.string(from: completionDate)
        }
        return dto
    }
}
