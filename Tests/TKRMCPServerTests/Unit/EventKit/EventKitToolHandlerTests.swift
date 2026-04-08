import EventKit
import Foundation
import MCP
import Testing
@testable import TKRMCPServer

@Suite("EventKitToolHandler")
struct EventKitToolHandlerTests {

    private func makeService() -> (EventKitService, MockEventStore) {
        let mock = MockEventStore()
        let event = mock.makeEvent()
        event.title = "Standup"
        event.startDate = Date()
        event.endDate = Date().addingTimeInterval(1800)
        mock.storedEvents.append(event)

        let reminder = mock.makeReminder()
        reminder.title = "Buy groceries"
        reminder.priority = 5
        mock.storedReminders.append(reminder)

        let service = EventKitService(store: mock)
        return (service, mock)
    }

    @Test("tools array has 8 eventkit tools")
    func toolCount() {
        #expect(EventKitToolHandler.tools.count == 8)
    }

    @Test("tool names are unique")
    func toolNamesUnique() {
        let names = EventKitToolHandler.tools.map(\.name)
        #expect(Set(names).count == names.count)
    }

    @Test("list_calendars returns valid JSON")
    func listCalendarsReturnsJSON() async throws {
        let (service, _) = makeService()
        let params = CallTool.Parameters(name: "list_calendars", arguments: nil)
        let result = try await EventKitToolHandler.handle(params, service: service)
        let data = result.data(using: .utf8)!
        let parsed = try JSONDecoder().decode([CalendarDTO].self, from: data)
        // Mock has no calendars, so empty array
        #expect(parsed.isEmpty)
    }

    @Test("list_events requires startDate and endDate")
    func listEventsRequiresDates() async throws {
        let (service, _) = makeService()
        let params = CallTool.Parameters(name: "list_events", arguments: [:])

        await #expect(throws: ToolError.self) {
            try await EventKitToolHandler.handle(params, service: service)
        }
    }

    @Test("list_events with valid dates returns JSON")
    func listEventsWithDates() async throws {
        let (service, _) = makeService()
        let fmt = ISO8601DateFormatter()
        let start = fmt.string(from: Date().addingTimeInterval(-86400))
        let end = fmt.string(from: Date().addingTimeInterval(86400))

        let params = CallTool.Parameters(
            name: "list_events",
            arguments: [
                "startDate": .string(start),
                "endDate": .string(end),
            ]
        )
        let result = try await EventKitToolHandler.handle(params, service: service)
        let data = result.data(using: .utf8)!
        let parsed = try JSONDecoder().decode([EventDTO].self, from: data)
        #expect(parsed.count == 1)
        #expect(parsed[0].title == "Standup")
    }

    @Test("list_events rejects invalid date format")
    func listEventsInvalidDates() async throws {
        let (service, _) = makeService()
        let params = CallTool.Parameters(
            name: "list_events",
            arguments: [
                "startDate": .string("not-a-date"),
                "endDate": .string("also-not"),
            ]
        )

        await #expect(throws: ToolError.self) {
            try await EventKitToolHandler.handle(params, service: service)
        }
    }

    @Test("create_event requires title, startDate, endDate")
    func createEventRequiresFields() async throws {
        let (service, _) = makeService()
        let params = CallTool.Parameters(
            name: "create_event",
            arguments: ["title": .string("Test")]
        )

        await #expect(throws: ToolError.self) {
            try await EventKitToolHandler.handle(params, service: service)
        }
    }

    @Test("create_event with valid args saves and returns JSON")
    func createEventValid() async throws {
        let (service, mock) = makeService()
        let fmt = ISO8601DateFormatter()
        let start = fmt.string(from: Date())
        let end = fmt.string(from: Date().addingTimeInterval(3600))

        let params = CallTool.Parameters(
            name: "create_event",
            arguments: [
                "title": .string("New Event"),
                "startDate": .string(start),
                "endDate": .string(end),
                "location": .string("Room B"),
            ]
        )
        let result = try await EventKitToolHandler.handle(params, service: service)
        let data = result.data(using: .utf8)!
        let parsed = try JSONDecoder().decode(EventDTO.self, from: data)
        #expect(parsed.title == "New Event")
        #expect(parsed.location == "Room B")
        #expect(mock.savedEvents == 1)
    }

    @Test("delete_event requires eventID")
    func deleteEventRequiresID() async throws {
        let (service, _) = makeService()
        let params = CallTool.Parameters(name: "delete_event", arguments: [:])

        await #expect(throws: ToolError.self) {
            try await EventKitToolHandler.handle(params, service: service)
        }
    }

    @Test("create_reminder requires title")
    func createReminderRequiresTitle() async throws {
        let (service, _) = makeService()
        let params = CallTool.Parameters(name: "create_reminder", arguments: [:])

        await #expect(throws: ToolError.self) {
            try await EventKitToolHandler.handle(params, service: service)
        }
    }

    @Test("create_reminder with valid args saves")
    func createReminderValid() async throws {
        let (service, mock) = makeService()
        let params = CallTool.Parameters(
            name: "create_reminder",
            arguments: [
                "title": .string("Do laundry"),
                "priority": .int(9),
            ]
        )
        let result = try await EventKitToolHandler.handle(params, service: service)
        let data = result.data(using: .utf8)!
        let parsed = try JSONDecoder().decode(ReminderDTO.self, from: data)
        #expect(parsed.title == "Do laundry")
        #expect(parsed.priority == 9)
        #expect(mock.savedReminders == 1)
    }

    @Test("complete_reminder requires reminderID")
    func completeReminderRequiresID() async throws {
        let (service, _) = makeService()
        let params = CallTool.Parameters(name: "complete_reminder", arguments: [:])

        await #expect(throws: ToolError.self) {
            try await EventKitToolHandler.handle(params, service: service)
        }
    }

    @Test("delete_reminder requires reminderID")
    func deleteReminderRequiresID() async throws {
        let (service, _) = makeService()
        let params = CallTool.Parameters(name: "delete_reminder", arguments: [:])

        await #expect(throws: ToolError.self) {
            try await EventKitToolHandler.handle(params, service: service)
        }
    }

    @Test("list_reminders returns JSON")
    func listRemindersReturnsJSON() async throws {
        let (service, _) = makeService()
        let params = CallTool.Parameters(name: "list_reminders", arguments: nil)
        let result = try await EventKitToolHandler.handle(params, service: service)
        let data = result.data(using: .utf8)!
        let parsed = try JSONDecoder().decode([ReminderDTO].self, from: data)
        #expect(parsed.count == 1)
        #expect(parsed[0].title == "Buy groceries")
    }

    @Test("unknown tool throws ToolError")
    func unknownToolThrows() async throws {
        let (service, _) = makeService()
        let params = CallTool.Parameters(name: "nonexistent", arguments: nil)

        await #expect(throws: ToolError.self) {
            try await EventKitToolHandler.handle(params, service: service)
        }
    }
}
