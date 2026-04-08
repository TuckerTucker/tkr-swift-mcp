import Foundation
import MCP
import Testing
@testable import TKRMCPServer

@Suite("ContactsToolHandler")
struct ContactsToolHandlerTests {

    private func makeService() -> (ContactsService, MockContactStore) {
        let mock = MockContactStore()
        mock.addContact(givenName: "Alice", familyName: "Smith")
        let service = ContactsService(store: mock)
        return (service, mock)
    }

    @Test("tools array has 8 contact tools")
    func toolCount() {
        #expect(ContactsToolHandler.tools.count == 8)
    }

    @Test("tool names are unique")
    func toolNamesUnique() {
        let names = ContactsToolHandler.tools.map(\.name)
        #expect(Set(names).count == names.count)
    }

    @Test("list_contacts returns valid JSON")
    func listContactsReturnsJSON() async throws {
        let (service, _) = makeService()
        let params = CallTool.Parameters(name: "list_contacts", arguments: nil)
        let result = try await ContactsToolHandler.handle(params, service: service)
        let data = result.data(using: .utf8)!
        let parsed = try JSONDecoder().decode([ContactDTO].self, from: data)
        #expect(parsed.count == 1)
        #expect(parsed[0].givenName == "Alice")
    }

    @Test("list_contacts respects limit argument")
    func listContactsWithLimit() async throws {
        let (service, _) = makeService()
        let params = CallTool.Parameters(
            name: "list_contacts",
            arguments: ["limit": .int(1)]
        )
        let result = try await ContactsToolHandler.handle(params, service: service)
        let data = result.data(using: .utf8)!
        let parsed = try JSONDecoder().decode([ContactDTO].self, from: data)
        #expect(parsed.count == 1)
    }

    @Test("list_contacts rejects zero limit")
    func listContactsRejectsZeroLimit() async throws {
        let (service, _) = makeService()
        let params = CallTool.Parameters(
            name: "list_contacts",
            arguments: ["limit": .int(0)]
        )
        await #expect(throws: ToolError.self) {
            try await ContactsToolHandler.handle(params, service: service)
        }
    }

    @Test("list_contacts rejects negative limit")
    func listContactsRejectsNegativeLimit() async throws {
        let (service, _) = makeService()
        let params = CallTool.Parameters(
            name: "list_contacts",
            arguments: ["limit": .int(-5)]
        )
        await #expect(throws: ToolError.self) {
            try await ContactsToolHandler.handle(params, service: service)
        }
    }

    @Test("search_contacts requires query argument")
    func searchContactsRequiresQuery() async throws {
        let (service, _) = makeService()
        let params = CallTool.Parameters(name: "search_contacts", arguments: [:])

        await #expect(throws: ToolError.self) {
            try await ContactsToolHandler.handle(params, service: service)
        }
    }

    @Test("get_contact requires id argument")
    func getContactRequiresId() async throws {
        let (service, _) = makeService()
        let params = CallTool.Parameters(name: "get_contact", arguments: [:])

        await #expect(throws: ToolError.self) {
            try await ContactsToolHandler.handle(params, service: service)
        }
    }

    @Test("get_contact throws notFound for unknown id")
    func getContactNotFound() async throws {
        let (service, _) = makeService()
        let params = CallTool.Parameters(
            name: "get_contact",
            arguments: ["id": .string("nonexistent")]
        )
        await #expect(throws: ToolError.self) {
            try await ContactsToolHandler.handle(params, service: service)
        }
    }

    @Test("update_contact throws notFound for unknown id")
    func updateContactNotFound() async throws {
        let (service, _) = makeService()
        let params = CallTool.Parameters(
            name: "update_contact",
            arguments: [
                "id": .string("nonexistent"),
                "givenName": .string("Updated"),
            ]
        )
        await #expect(throws: ToolError.self) {
            try await ContactsToolHandler.handle(params, service: service)
        }
    }

    @Test("delete_contact requires id argument")
    func deleteContactRequiresId() async throws {
        let (service, _) = makeService()
        let params = CallTool.Parameters(name: "delete_contact", arguments: [:])

        await #expect(throws: ToolError.self) {
            try await ContactsToolHandler.handle(params, service: service)
        }
    }

    @Test("create_contact triggers save")
    func createContactTriggersSave() async throws {
        let (service, mock) = makeService()
        let params = CallTool.Parameters(
            name: "create_contact",
            arguments: [
                "givenName": .string("New"),
                "familyName": .string("Contact"),
            ]
        )
        let result = try await ContactsToolHandler.handle(params, service: service)
        let data = result.data(using: .utf8)!
        let parsed = try JSONDecoder().decode(ContactDTO.self, from: data)
        #expect(parsed.givenName == "New")
        #expect(mock.executedSaveRequests == 1)
    }

    @Test("create_contact rejects empty names")
    func createContactRejectsEmpty() async throws {
        let (service, _) = makeService()
        let params = CallTool.Parameters(
            name: "create_contact",
            arguments: [
                "organization": .string("Orphan Corp"),
            ]
        )
        await #expect(throws: ToolError.self) {
            try await ContactsToolHandler.handle(params, service: service)
        }
    }

    @Test("create_contact with emails parses labeled values")
    func createContactWithEmails() async throws {
        let (service, mock) = makeService()
        let params = CallTool.Parameters(
            name: "create_contact",
            arguments: [
                "givenName": .string("Test"),
                "emails": .array([
                    .object(["label": .string("work"), "value": .string("t@example.com")]),
                ]),
            ]
        )
        let result = try await ContactsToolHandler.handle(params, service: service)
        let parsed = try JSONDecoder().decode(ContactDTO.self, from: result.data(using: .utf8)!)
        #expect(parsed.givenName == "Test")
        #expect(mock.executedSaveRequests == 1)
    }

    @Test("create_contact propagates store errors")
    func createContactStoreError() async throws {
        let mock = MockContactStore()
        mock.shouldThrowOnExecute = NSError(domain: "test", code: 1)
        let service = ContactsService(store: mock)
        let params = CallTool.Parameters(
            name: "create_contact",
            arguments: [
                "givenName": .string("Fail"),
                "familyName": .string("Contact"),
            ]
        )
        await #expect(throws: Error.self) {
            try await ContactsToolHandler.handle(params, service: service)
        }
    }

    @Test("unknown tool throws ToolError")
    func unknownToolThrows() async throws {
        let (service, _) = makeService()
        let params = CallTool.Parameters(name: "nonexistent_tool", arguments: nil)

        await #expect(throws: ToolError.self) {
            try await ContactsToolHandler.handle(params, service: service)
        }
    }

    @Test("list_groups returns valid JSON")
    func listGroupsReturnsJSON() async throws {
        let mock = MockContactStore()
        mock.addGroup(name: "Family")
        let service = ContactsService(store: mock)
        let params = CallTool.Parameters(name: "list_groups", arguments: nil)
        let result = try await ContactsToolHandler.handle(params, service: service)
        let data = result.data(using: .utf8)!
        let parsed = try JSONDecoder().decode([GroupDTO].self, from: data)
        #expect(parsed.count == 1)
        #expect(parsed[0].name == "Family")
    }
}
