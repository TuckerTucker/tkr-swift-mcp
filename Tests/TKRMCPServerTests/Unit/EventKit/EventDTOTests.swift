import EventKit
import Foundation
import Testing
@testable import TKRMCPServer

@Suite("EventDTO")
struct EventDTOTests {

    @Test("CalendarDTO Codable round-trip")
    func calendarDTORoundTrip() throws {
        let dto = CalendarDTO(id: "cal-1", title: "Work", type: "event", source: "iCloud")
        let data = try JSONEncoder().encode(dto)
        let decoded = try JSONDecoder().decode(CalendarDTO.self, from: data)
        #expect(decoded == dto)
    }

    @Test("EventDTO Codable round-trip with all fields")
    func eventDTORoundTripFull() throws {
        let dto = EventDTO(
            id: "evt-1",
            title: "Meeting",
            startDate: "2026-01-15T14:00:00Z",
            endDate: "2026-01-15T15:00:00Z",
            isAllDay: false,
            calendar: "Work",
            location: "Room 42",
            notes: "Discuss Q1",
            url: "https://zoom.us/123"
        )
        let data = try JSONEncoder().encode(dto)
        let decoded = try JSONDecoder().decode(EventDTO.self, from: data)
        #expect(decoded == dto)
    }

    @Test("EventDTO Codable round-trip with minimal fields")
    func eventDTORoundTripMinimal() throws {
        let dto = EventDTO(
            id: "evt-2",
            title: "Quick sync",
            startDate: "2026-01-15T10:00:00Z",
            endDate: "2026-01-15T10:30:00Z",
            isAllDay: false,
            calendar: "Default"
        )
        let data = try JSONEncoder().encode(dto)
        let decoded = try JSONDecoder().decode(EventDTO.self, from: data)
        #expect(decoded == dto)
        #expect(decoded.location == nil)
        #expect(decoded.notes == nil)
        #expect(decoded.url == nil)
    }

    @Test("ReminderDTO Codable round-trip with all fields")
    func reminderDTORoundTripFull() throws {
        let dto = ReminderDTO(
            id: "rem-1",
            title: "Buy groceries",
            isCompleted: false,
            priority: 5,
            calendar: "Personal",
            notes: "Milk, eggs",
            dueDate: "2026-01-20T09:00:00Z",
            completionDate: nil
        )
        let data = try JSONEncoder().encode(dto)
        let decoded = try JSONDecoder().decode(ReminderDTO.self, from: data)
        #expect(decoded == dto)
    }

    @Test("ReminderDTO Codable round-trip completed")
    func reminderDTORoundTripCompleted() throws {
        let dto = ReminderDTO(
            id: "rem-2",
            title: "Done task",
            isCompleted: true,
            priority: 0,
            calendar: "Work",
            completionDate: "2026-01-18T15:00:00Z"
        )
        let data = try JSONEncoder().encode(dto)
        let decoded = try JSONDecoder().decode(ReminderDTO.self, from: data)
        #expect(decoded == dto)
    }

    @Test("EventDTO.from(EKEvent) converts fields")
    func fromEKEvent() {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.title = "Test Event"
        event.startDate = Date(timeIntervalSince1970: 0)
        event.endDate = Date(timeIntervalSince1970: 3600)
        event.location = "Office"
        event.notes = "Some notes"

        let dto = EventDTO.from(event)
        #expect(dto.title == "Test Event")
        #expect(dto.location == "Office")
        #expect(dto.notes == "Some notes")
        #expect(dto.isAllDay == false)
    }

    @Test("EventDTO.from(EKEvent) omits empty optional fields")
    func fromEKEventOmitsEmpty() {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.title = "Bare"
        event.startDate = Date()
        event.endDate = Date()

        let dto = EventDTO.from(event)
        #expect(dto.location == nil)
        #expect(dto.notes == nil)
        #expect(dto.url == nil)
    }

    @Test("ReminderDTO.from(EKReminder) converts fields")
    func fromEKReminder() {
        let store = EKEventStore()
        let reminder = EKReminder(eventStore: store)
        reminder.title = "Test Reminder"
        reminder.priority = 1
        reminder.notes = "High priority"

        let dto = ReminderDTO.from(reminder)
        #expect(dto.title == "Test Reminder")
        #expect(dto.priority == 1)
        #expect(dto.notes == "High priority")
        #expect(dto.isCompleted == false)
    }
}
