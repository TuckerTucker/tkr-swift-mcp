@preconcurrency import EventKit
import Foundation
import Testing
@testable import TKRMCPServer

/// E2E tests that exercise real system APIs (EKEventStore).
/// These require Calendar and Reminders permissions granted to the test runner.
/// Skip with: SKIP_E2E=1 environment variable.
@Suite("EventKit E2E", .enabled(if: ProcessInfo.processInfo.environment["SKIP_E2E"] == nil))
struct EventKitE2ETests {

    /// Directly deletes an event via EKEventStore (for cleanup outside actor context).
    private func cleanupEvent(identifier: String, store: EKEventStore) {
        guard let event = store.event(withIdentifier: identifier) else { return }
        try? store.remove(event, span: .thisEvent)
    }

    /// Directly deletes a reminder via EKEventStore (for cleanup outside actor context).
    private func cleanupReminder(identifier: String, store: EKEventStore) {
        guard let reminder = store.calendarItem(withIdentifier: identifier) as? EKReminder else { return }
        try? store.remove(reminder, commit: true)
    }

    @Test("Event CRUD cycle")
    func eventCRUDCycle() async throws {
        let ekStore = EKEventStore()
        if #available(macOS 14.0, *) {
            let access = try await ekStore.requestFullAccessToEvents()
            try #require(access, "Calendar access denied — grant in System Settings")
        } else {
            let access = try await ekStore.requestAccess(to: .event)
            try #require(access, "Calendar access denied — grant in System Settings")
        }

        let store = EventStore()
        let service = EventKitService(store: store)

        // Create
        let start = Date().addingTimeInterval(86400)
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
        let eventID = created.id

        // Ensure cleanup even on test failure
        defer { cleanupEvent(identifier: eventID, store: ekStore) }

        #expect(created.title == "[MCP-TEST] E2E Event")
        #expect(created.location == "Test Location")

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
        let ekStore = EKEventStore()
        if #available(macOS 14.0, *) {
            let access = try await ekStore.requestFullAccessToReminders()
            try #require(access, "Reminders access denied — grant in System Settings")
        } else {
            let access = try await ekStore.requestAccess(to: .reminder)
            try #require(access, "Reminders access denied — grant in System Settings")
        }

        let store = EventStore()
        let service = EventKitService(store: store)

        // Create
        let created = try await service.createReminder(
            title: "[MCP-TEST] E2E Reminder",
            calendarID: nil,
            dueDate: Date().addingTimeInterval(86400),
            priority: 5,
            notes: "Created by E2E test"
        )
        let reminderID = created.id

        // Ensure cleanup even on test failure
        defer { cleanupReminder(identifier: reminderID, store: ekStore) }

        #expect(created.title == "[MCP-TEST] E2E Reminder")
        #expect(created.priority == 5)

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
