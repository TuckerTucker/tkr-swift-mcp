import Foundation
import MCP
import Testing
@testable import TKRMCPServer

/// Integration tests exercising the full MCP Client↔Server flow via InMemoryTransport.
/// Uses mock stores — no system permissions required.
@Suite("MCP Integration")
struct MCPIntegrationTests {

    /// Creates an in-process Client + Server pair connected via InMemoryTransport.
    private func makeClientAndServer() async throws -> (Client, Server) {
        // Seed mock data
        let mockContactStore = MockContactStore()
        mockContactStore.addContact(givenName: "Alice", familyName: "Smith", organization: "Acme")
        mockContactStore.addContact(givenName: "Bob", familyName: "Jones")
        mockContactStore.addGroup(name: "Work")

        let mockEventStore = MockEventStore()
        let event = mockEventStore.makeEvent()
        event.title = "Daily standup"
        event.startDate = Date()
        event.endDate = Date().addingTimeInterval(1800)
        mockEventStore.storedEvents.append(event)

        let reminder = mockEventStore.makeReminder()
        reminder.title = "Buy milk"
        reminder.priority = 5
        mockEventStore.storedReminders.append(reminder)

        let contactsService = ContactsService(store: mockContactStore)
        let eventKitService = EventKitService(store: mockEventStore)

        // Create transports
        let (clientTransport, serverTransport) = await InMemoryTransport.createConnectedPair()

        // Create and start server
        let server = await createServer(
            contactsService: contactsService,
            eventKitService: eventKitService
        )
        try await server.start(transport: serverTransport)

        // Create and connect client
        let client = Client(
            name: "test-client",
            version: "1.0.0",
            capabilities: .init()
        )
        try await client.connect(transport: clientTransport)

        return (client, server)
    }

    @Test("listTools returns all 16 tools")
    func listToolsReturnsAll() async throws {
        let (client, _) = try await makeClientAndServer()
        let result = try await client.listTools()
        #expect(result.tools.count == 16)
    }

    @Test("listTools includes both contacts and eventkit tools")
    func listToolsIncludesBothModules() async throws {
        let (client, _) = try await makeClientAndServer()
        let result = try await client.listTools()
        let names = Set(result.tools.map(\.name))

        // Contacts tools
        #expect(names.contains("search_contacts"))
        #expect(names.contains("list_contacts"))
        #expect(names.contains("create_contact"))

        // EventKit tools
        #expect(names.contains("list_calendars"))
        #expect(names.contains("list_events"))
        #expect(names.contains("create_reminder"))
    }

    @Test("callTool list_contacts returns seeded data")
    func callToolListContacts() async throws {
        let (client, _) = try await makeClientAndServer()
        let result = try await client.callTool(name: "list_contacts")

        #expect(result.isError != true)
        #expect(result.content.count == 1)

        // Extract text from the response
        guard case .text(let text, _, _) = result.content.first else {
            Issue.record("Expected text content")
            return
        }

        let contacts = try JSONDecoder().decode([ContactDTO].self, from: text.data(using: .utf8)!)
        #expect(contacts.count == 2)
        #expect(contacts.contains { $0.givenName == "Alice" })
        #expect(contacts.contains { $0.givenName == "Bob" })
    }

    @Test("callTool list_groups returns seeded groups")
    func callToolListGroups() async throws {
        let (client, _) = try await makeClientAndServer()
        let result = try await client.callTool(name: "list_groups")

        #expect(result.isError != true)
        guard case .text(let text, _, _) = result.content.first else {
            Issue.record("Expected text content")
            return
        }

        let groups = try JSONDecoder().decode([GroupDTO].self, from: text.data(using: .utf8)!)
        #expect(groups.count == 1)
        #expect(groups[0].name == "Work")
    }

    @Test("callTool create_contact returns new contact")
    func callToolCreateContact() async throws {
        let (client, _) = try await makeClientAndServer()
        let result = try await client.callTool(
            name: "create_contact",
            arguments: [
                "givenName": .string("Charlie"),
                "familyName": .string("Brown"),
            ]
        )

        #expect(result.isError != true)
        guard case .text(let text, _, _) = result.content.first else {
            Issue.record("Expected text content")
            return
        }

        let contact = try JSONDecoder().decode(ContactDTO.self, from: text.data(using: .utf8)!)
        #expect(contact.givenName == "Charlie")
        #expect(contact.familyName == "Brown")
    }

    @Test("callTool list_events returns seeded events")
    func callToolListEvents() async throws {
        let (client, _) = try await makeClientAndServer()
        let fmt = ISO8601DateFormatter()
        let result = try await client.callTool(
            name: "list_events",
            arguments: [
                "startDate": .string(fmt.string(from: Date().addingTimeInterval(-86400))),
                "endDate": .string(fmt.string(from: Date().addingTimeInterval(86400))),
            ]
        )

        #expect(result.isError != true)
        guard case .text(let text, _, _) = result.content.first else {
            Issue.record("Expected text content")
            return
        }

        let events = try JSONDecoder().decode([EventDTO].self, from: text.data(using: .utf8)!)
        #expect(events.count == 1)
        #expect(events[0].title == "Daily standup")
    }

    @Test("callTool list_reminders returns seeded reminders")
    func callToolListReminders() async throws {
        let (client, _) = try await makeClientAndServer()
        let result = try await client.callTool(name: "list_reminders")

        #expect(result.isError != true)
        guard case .text(let text, _, _) = result.content.first else {
            Issue.record("Expected text content")
            return
        }

        let reminders = try JSONDecoder().decode([ReminderDTO].self, from: text.data(using: .utf8)!)
        #expect(reminders.count == 1)
        #expect(reminders[0].title == "Buy milk")
        #expect(reminders[0].priority == 5)
    }

    @Test("callTool with missing required args returns error")
    func callToolMissingArgs() async throws {
        let (client, _) = try await makeClientAndServer()
        let result = try await client.callTool(
            name: "search_contacts",
            arguments: [:]  // missing "query"
        )

        #expect(result.isError == true)
        guard case .text(let text, _, _) = result.content.first else {
            Issue.record("Expected text content")
            return
        }
        #expect(text.contains("query is required"))
    }

    @Test("callTool with unknown tool returns error")
    func callToolUnknown() async throws {
        let (client, _) = try await makeClientAndServer()
        let result = try await client.callTool(name: "nonexistent_tool")

        #expect(result.isError == true)
        guard case .text(let text, _, _) = result.content.first else {
            Issue.record("Expected text content")
            return
        }
        #expect(text.contains("Unknown tool"))
    }

    @Test("callTool create_reminder saves and returns DTO")
    func callToolCreateReminder() async throws {
        let (client, _) = try await makeClientAndServer()
        let result = try await client.callTool(
            name: "create_reminder",
            arguments: [
                "title": .string("Integration test reminder"),
                "priority": .int(1),
            ]
        )

        #expect(result.isError != true)
        guard case .text(let text, _, _) = result.content.first else {
            Issue.record("Expected text content")
            return
        }

        let reminder = try JSONDecoder().decode(ReminderDTO.self, from: text.data(using: .utf8)!)
        #expect(reminder.title == "Integration test reminder")
        #expect(reminder.priority == 1)
    }
}
