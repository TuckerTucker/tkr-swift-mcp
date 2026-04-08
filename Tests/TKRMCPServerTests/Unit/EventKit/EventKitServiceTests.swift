import EventKit
import Foundation
import Testing
@testable import TKRMCPServer

@Suite("EventKitService")
struct EventKitServiceTests {

    @Test("requestCalendarAccess returns mock value")
    func requestCalendarAccess() async throws {
        let mock = MockEventStore()
        mock.calendarAccessGranted = true
        let service = EventKitService(store: mock)
        #expect(try await service.requestCalendarAccess() == true)

        mock.calendarAccessGranted = false
        #expect(try await service.requestCalendarAccess() == false)
    }

    @Test("requestReminderAccess returns mock value")
    func requestReminderAccess() async throws {
        let mock = MockEventStore()
        mock.reminderAccessGranted = false
        let service = EventKitService(store: mock)
        #expect(try await service.requestReminderAccess() == false)
    }

    @Test("listEvents returns DTOs from mock")
    func listEvents() async throws {
        let mock = MockEventStore()
        let event = mock.makeEvent()
        event.title = "Team standup"
        event.startDate = Date()
        event.endDate = Date().addingTimeInterval(3600)
        mock.storedEvents.append(event)

        let service = EventKitService(store: mock)
        let results = await service.listEvents(
            calendarID: nil,
            startDate: Date().addingTimeInterval(-86400),
            endDate: Date().addingTimeInterval(86400)
        )
        #expect(results.count == 1)
        #expect(results[0].title == "Team standup")
    }

    @Test("createEvent saves and returns DTO")
    func createEvent() async throws {
        let mock = MockEventStore()
        let service = EventKitService(store: mock)

        let result = try await service.createEvent(
            title: "New meeting",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            calendarID: nil,
            location: "Room A",
            notes: nil,
            isAllDay: false
        )

        #expect(result.title == "New meeting")
        #expect(result.location == "Room A")
        #expect(mock.savedEvents == 1)
    }

    @Test("deleteEvent returns false for nonexistent")
    func deleteEventNotFound() async throws {
        let mock = MockEventStore()
        let service = EventKitService(store: mock)
        let deleted = try await service.deleteEvent(eventID: "missing")
        #expect(deleted == false)
    }

    @Test("listReminders returns DTOs from mock")
    func listReminders() async throws {
        let mock = MockEventStore()
        let reminder = mock.makeReminder()
        reminder.title = "Buy milk"
        reminder.priority = 5
        mock.storedReminders.append(reminder)

        let service = EventKitService(store: mock)
        let results = await service.listReminders(calendarID: nil, completed: nil)
        #expect(results.count == 1)
        #expect(results[0].title == "Buy milk")
        #expect(results[0].priority == 5)
    }

    @Test("createReminder saves and returns DTO")
    func createReminder() async throws {
        let mock = MockEventStore()
        let service = EventKitService(store: mock)

        let result = try await service.createReminder(
            title: "New reminder",
            calendarID: nil,
            dueDate: nil,
            priority: 1,
            notes: "Important"
        )

        #expect(result.title == "New reminder")
        #expect(result.priority == 1)
        #expect(result.notes == "Important")
        #expect(mock.savedReminders == 1)
    }

    @Test("deleteReminder returns false for nonexistent")
    func deleteReminderNotFound() async throws {
        let mock = MockEventStore()
        let service = EventKitService(store: mock)
        let deleted = try await service.deleteReminder(reminderID: "missing")
        #expect(deleted == false)
    }

    @Test("completeReminder returns false for nonexistent")
    func completeReminderNotFound() async throws {
        let mock = MockEventStore()
        let service = EventKitService(store: mock)
        let success = try await service.completeReminder(reminderID: "missing", completed: true)
        #expect(success == false)
    }
}
