import EventKit
import Foundation
import MCP

/// Defines and dispatches MCP tools for Apple EventKit (Calendars & Reminders).
enum EventKitToolHandler {

    /// All EventKit-related MCP tool definitions.
    static let tools: [Tool] = [
        Tool(
            name: "list_calendars",
            description: "List all calendars. Set type to 'event' or 'reminder'.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "type": .object([
                        "type": "string",
                        "enum": .array([.string("event"), .string("reminder")]),
                        "description": "Calendar type: 'event' or 'reminder'",
                    ]),
                ]),
            ])
        ),
        Tool(
            name: "list_events",
            description: "List calendar events in a date range.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "startDate": .object(["type": "string", "description": "ISO 8601 start date"]),
                    "endDate": .object(["type": "string", "description": "ISO 8601 end date"]),
                    "calendarID": .object(["type": "string", "description": "Optional calendar ID filter"]),
                ]),
                "required": .array([.string("startDate"), .string("endDate")]),
            ])
        ),
        Tool(
            name: "create_event",
            description: "Create a calendar event.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "title": .object(["type": "string"]),
                    "startDate": .object(["type": "string", "description": "ISO 8601"]),
                    "endDate": .object(["type": "string", "description": "ISO 8601"]),
                    "calendarID": .object(["type": "string"]),
                    "location": .object(["type": "string"]),
                    "notes": .object(["type": "string"]),
                    "isAllDay": .object(["type": "boolean"]),
                ]),
                "required": .array([.string("title"), .string("startDate"), .string("endDate")]),
            ])
        ),
        Tool(
            name: "delete_event",
            description: "Delete a calendar event by its ID.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "eventID": .object(["type": "string"]),
                ]),
                "required": .array([.string("eventID")]),
            ])
        ),
        Tool(
            name: "list_reminders",
            description: "List reminders. Optionally filter by calendar and completion status.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "calendarID": .object(["type": "string"]),
                    "completed": .object(["type": "boolean", "description": "Filter: true=completed, false=incomplete, omit=all"]),
                ]),
            ])
        ),
        Tool(
            name: "create_reminder",
            description: "Create a new reminder.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "title": .object(["type": "string"]),
                    "calendarID": .object(["type": "string"]),
                    "dueDate": .object(["type": "string", "description": "ISO 8601"]),
                    "priority": .object(["type": "integer", "description": "0=none, 1=high, 5=medium, 9=low"]),
                    "notes": .object(["type": "string"]),
                ]),
                "required": .array([.string("title")]),
            ])
        ),
        Tool(
            name: "complete_reminder",
            description: "Mark a reminder as completed or incomplete.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "reminderID": .object(["type": "string"]),
                    "completed": .object(["type": "boolean"]),
                ]),
                "required": .array([.string("reminderID"), .string("completed")]),
            ])
        ),
        Tool(
            name: "delete_reminder",
            description: "Delete a reminder by its ID.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "reminderID": .object(["type": "string"]),
                ]),
                "required": .array([.string("reminderID")]),
            ])
        ),
    ]

    /// Dispatches a tool call to the appropriate EventKit service method.
    static func handle(
        _ params: CallTool.Parameters,
        service: EventKitService
    ) async throws -> String {
        let args = params.arguments ?? [:]
        let fmt = ISO8601DateFormatter()

        switch params.name {
        case "list_calendars":
            let typeStr = args["type"]?.stringValue ?? "event"
            let entityType: EKEntityType = typeStr == "reminder" ? .reminder : .event
            let calendars = await service.listCalendars(for: entityType)
            return try encodeJSON(calendars)

        case "list_events":
            guard let startStr = args["startDate"]?.stringValue,
                  let endStr = args["endDate"]?.stringValue,
                  let start = fmt.date(from: startStr),
                  let end = fmt.date(from: endStr)
            else {
                throw ToolError.invalidArguments("startDate and endDate required in ISO 8601 format")
            }
            let calID = args["calendarID"]?.stringValue
            let events = await service.listEvents(calendarID: calID, startDate: start, endDate: end)
            return try encodeJSON(events)

        case "create_event":
            guard let title = args["title"]?.stringValue,
                  let startStr = args["startDate"]?.stringValue,
                  let endStr = args["endDate"]?.stringValue,
                  let start = fmt.date(from: startStr),
                  let end = fmt.date(from: endStr)
            else {
                throw ToolError.invalidArguments("title, startDate, endDate required")
            }
            let event = try await service.createEvent(
                title: title,
                startDate: start,
                endDate: end,
                calendarID: args["calendarID"]?.stringValue,
                location: args["location"]?.stringValue,
                notes: args["notes"]?.stringValue,
                isAllDay: args["isAllDay"]?.boolValue ?? false
            )
            return try encodeJSON(event)

        case "delete_event":
            guard let eventID = args["eventID"]?.stringValue else {
                throw ToolError.invalidArguments("eventID required")
            }
            let deleted = try await service.deleteEvent(eventID: eventID)
            return try encodeJSON(["deleted": deleted])

        case "list_reminders":
            let calID = args["calendarID"]?.stringValue
            let completed = args["completed"]?.boolValue
            let reminders = await service.listReminders(calendarID: calID, completed: completed)
            return try encodeJSON(reminders)

        case "create_reminder":
            guard let title = args["title"]?.stringValue else {
                throw ToolError.invalidArguments("title required")
            }
            let dueDate: Date? = args["dueDate"]?.stringValue.flatMap { fmt.date(from: $0) }
            let priority = args["priority"]?.intValue
            let reminder = try await service.createReminder(
                title: title,
                calendarID: args["calendarID"]?.stringValue,
                dueDate: dueDate,
                priority: priority,
                notes: args["notes"]?.stringValue
            )
            return try encodeJSON(reminder)

        case "complete_reminder":
            guard let reminderID = args["reminderID"]?.stringValue else {
                throw ToolError.invalidArguments("reminderID required")
            }
            let completed = args["completed"]?.boolValue ?? true
            let success = try await service.completeReminder(reminderID: reminderID, completed: completed)
            return try encodeJSON(["success": success])

        case "delete_reminder":
            guard let reminderID = args["reminderID"]?.stringValue else {
                throw ToolError.invalidArguments("reminderID required")
            }
            let deleted = try await service.deleteReminder(reminderID: reminderID)
            return try encodeJSON(["deleted": deleted])

        default:
            throw ToolError.unknownTool(params.name)
        }
    }
}
