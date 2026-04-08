import EventKit
import Foundation
import Testing
@testable import TKRMCPServer

/// E2E tests that exercise real system APIs (EKEventStore).
/// These require Calendar and Reminders permissions granted to the test runner.
/// Skip with: SKIP_E2E=1 environment variable.
@Suite("EventKit E2E", .enabled(if: ProcessInfo.processInfo.environment["SKIP_E2E"] == nil))
struct EventKitE2ETests {

    @Test("Event CRUD cycle")
    func eventCRUDCycle() async throws {
        let store = EventStore()
        let calAccess = try await store.requestCalendarAccess()
        try #require(calAccess, "Calendar access denied — grant in System Settings")

        let service = EventKitService(store: store)

        // Create
        let start = Date().addingTimeInterval(86400) // tomorrow
        let end = start.addingTimeInterval(3600)
        let created = try await service.createEvent(
            title: "[MCP-TEST] E2E Event",
            startDate: start,
            endDate: end,
            calendarID: nil,
            location: "Test Location",
            notes: "Created by E2E test",
            isAllDay: false
        )
        #expect(created.title == "[MCP-TEST] E2E Event")
        #expect(created.location == "Test Location")
        let eventID = created.id

        // List — should appear in range
        let events = await service.listEvents(
            calendarID: nil,
            startDate: start.addingTimeInterval(-3600),
            endDate: end.addingTimeInterval(3600)
        )
        #expect(events.contains { $0.id == eventID })

        // Delete
        let deleted = try await service.deleteEvent(eventID: eventID)
        #expect(deleted == true)

        // Verify gone
        let afterDelete = await service.listEvents(
            calendarID: nil,
            startDate: start.addingTimeInterval(-3600),
            endDate: end.addingTimeInterval(3600)
        )
        #expect(!afterDelete.contains { $0.id == eventID })
    }

    @Test("Reminder CRUD cycle")
    func reminderCRUDCycle() async throws {
        let store = EventStore()
        let remAccess = try await store.requestReminderAccess()
        try #require(remAccess, "Reminders access denied — grant in System Settings")

        let service = EventKitService(store: store)

        // Create
        let created = try await service.createReminder(
            title: "[MCP-TEST] E2E Reminder",
            calendarID: nil,
            dueDate: Date().addingTimeInterval(86400),
            priority: 5,
            notes: "Created by E2E test"
        )
        #expect(created.title == "[MCP-TEST] E2E Reminder")
        #expect(created.priority == 5)
        let reminderID = created.id

        // List — should appear
        let reminders = await service.listReminders(calendarID: nil, completed: false)
        #expect(reminders.contains { $0.id == reminderID })

        // Complete
        let completed = try await service.completeReminder(reminderID: reminderID, completed: true)
        #expect(completed == true)

        // Delete
        let deleted = try await service.deleteReminder(reminderID: reminderID)
        #expect(deleted == true)
    }
}
