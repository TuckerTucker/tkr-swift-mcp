import Foundation
import Logging
import MCP
import ServiceLifecycle

@main
struct EventKitMCPServerApp {
    static func main() async throws {
        // Configure logging to stderr (stdout is for MCP protocol)
        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardError(label: label)
            handler.logLevel = .warning
            return handler
        }
        let logger = Logger(label: "com.eventkit-mcp-server")

        let ekService = EventKitService()

        // Request access up front
        let calAccess = try await ekService.requestCalendarAccess()
        let remAccess = try await ekService.requestReminderAccess()
        guard calAccess && remAccess else {
            logger.error("EventKit access denied. Grant access in System Settings > Privacy & Security.")
            Foundation.exit(1)
        }

        // Create MCP server
        let server = Server(
            name: "eventkit-mcp-server",
            version: "1.0.0",
            capabilities: .init(
                tools: .init(listChanged: false)
            )
        )

        // ── Tool Definitions ──────────────────────────────────────────────

        let tools: [Tool] = [
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

        // ── Register Handlers ─────────────────────────────────────────────

        await server.withMethodHandler(ListTools.self) { _ in
            .init(tools: tools)
        }

        await server.withMethodHandler(CallTool.self) { params in
            do {
                let result = try await handleToolCall(params: params, ekService: ekService)
                return .init(content: [.text(result)], isError: false)
            } catch {
                return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
            }
        }

        // ── Start Server via stdio ────────────────────────────────────────

        let transport = StdioTransport(logger: logger)

        struct MCPService: Service {
            let server: Server
            let transport: StdioTransport
            func run() async throws {
                try await server.start(transport: transport)
                try await Task.sleep(for: .seconds(365 * 24 * 3600))
            }
        }

        let serviceGroup = ServiceGroup(
            services: [MCPService(server: server, transport: transport)],
            configuration: .init(gracefulShutdownSignals: [.sigterm, .sigint]),
            logger: logger
        )
        try await serviceGroup.run()
    }
}

// MARK: - Tool Dispatch

private func handleToolCall(params: CallTool.Parameters, ekService: EventKitService) async throws -> String {
    let args = params.arguments ?? [:]
    let fmt = ISO8601DateFormatter()

    switch params.name {
    case "list_calendars":
        let typeStr = args["type"]?.stringValue ?? "event"
        let entityType: EKEntityType = typeStr == "reminder" ? .reminder : .event
        let calendars = await ekService.listCalendars(for: entityType)
        return toJSON(calendars)

    case "list_events":
        guard let startStr = args["startDate"]?.stringValue,
              let endStr = args["endDate"]?.stringValue,
              let start = fmt.date(from: startStr),
              let end = fmt.date(from: endStr)
        else {
            throw ToolError.invalidArguments("startDate and endDate required in ISO 8601 format")
        }
        let calID = args["calendarID"]?.stringValue
        let events = await ekService.listEvents(calendarID: calID, startDate: start, endDate: end)
        return toJSON(events)

    case "create_event":
        guard let title = args["title"]?.stringValue,
              let startStr = args["startDate"]?.stringValue,
              let endStr = args["endDate"]?.stringValue,
              let start = fmt.date(from: startStr),
              let end = fmt.date(from: endStr)
        else {
            throw ToolError.invalidArguments("title, startDate, endDate required")
        }
        let event = try await ekService.createEvent(
            title: title,
            startDate: start,
            endDate: end,
            calendarID: args["calendarID"]?.stringValue,
            location: args["location"]?.stringValue,
            notes: args["notes"]?.stringValue,
            isAllDay: args["isAllDay"]?.boolValue ?? false
        )
        return toJSON(event)

    case "delete_event":
        guard let eventID = args["eventID"]?.stringValue else {
            throw ToolError.invalidArguments("eventID required")
        }
        let deleted = try await ekService.deleteEvent(eventID: eventID)
        return toJSON(["deleted": deleted])

    case "list_reminders":
        let calID = args["calendarID"]?.stringValue
        let completed = args["completed"]?.boolValue
        let reminders = await ekService.listReminders(calendarID: calID, completed: completed)
        return toJSON(reminders)

    case "create_reminder":
        guard let title = args["title"]?.stringValue else {
            throw ToolError.invalidArguments("title required")
        }
        let dueDate: Date? = args["dueDate"]?.stringValue.flatMap { fmt.date(from: $0) }
        let priority = args["priority"]?.intValue
        let reminder = try await ekService.createReminder(
            title: title,
            calendarID: args["calendarID"]?.stringValue,
            dueDate: dueDate,
            priority: priority.map(Int.init),
            notes: args["notes"]?.stringValue
        )
        return toJSON(reminder)

    case "complete_reminder":
        guard let reminderID = args["reminderID"]?.stringValue else {
            throw ToolError.invalidArguments("reminderID required")
        }
        let completed = args["completed"]?.boolValue ?? true
        let success = try await ekService.completeReminder(reminderID: reminderID, completed: completed)
        return toJSON(["success": success])

    case "delete_reminder":
        guard let reminderID = args["reminderID"]?.stringValue else {
            throw ToolError.invalidArguments("reminderID required")
        }
        let deleted = try await ekService.deleteReminder(reminderID: reminderID)
        return toJSON(["deleted": deleted])

    default:
        throw ToolError.unknownTool(params.name)
    }
}

// MARK: - Helpers

enum ToolError: LocalizedError {
    case invalidArguments(String)
    case unknownTool(String)

    var errorDescription: String? {
        switch self {
        case .invalidArguments(let msg): return "Invalid arguments: \(msg)"
        case .unknownTool(let name): return "Unknown tool: \(name)"
        }
    }
}

private func toJSON(_ value: Any) -> String {
    guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]),
          let str = String(data: data, encoding: .utf8)
    else { return "{}" }
    return str
}

// MARK: - Value Extensions

import struct MCP.Value

extension Value {
    var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }

    var intValue: Int64? {
        if case .int(let i) = self { return i }
        return nil
    }
}
