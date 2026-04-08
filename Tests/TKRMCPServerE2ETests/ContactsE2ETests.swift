import Foundation
import Testing
@testable import TKRMCPServer

/// E2E tests that exercise real system APIs (CNContactStore).
/// These require Contacts permission granted to the test runner.
/// Skip with: SKIP_E2E=1 environment variable.
@Suite("Contacts E2E", .enabled(if: ProcessInfo.processInfo.environment["SKIP_E2E"] == nil))
struct ContactsE2ETests {

    @Test("Contact CRUD cycle")
    func contactCRUDCycle() async throws {
        let store = ContactStore()
        let granted = try await store.requestAccess(for: .contacts)
        try #require(granted, "Contacts access denied — grant in System Settings")

        let service = ContactsService(store: store)

        // Create
        let created = try await service.createContact(
            givenName: "__MCPTEST__",
            familyName: "E2EContact",
            organization: "TestOrg",
            jobTitle: nil,
            emails: [("work", "e2e@test.com")],
            phones: [("mobile", "+15550000")],
            notes: nil
        )
        #expect(created.givenName == "__MCPTEST__")
        #expect(created.familyName == "E2EContact")
        let contactID = created.id

        // Read
        let fetched = try await service.getContact(identifier: contactID)
        #expect(fetched != nil)
        #expect(fetched?.givenName == "__MCPTEST__")
        #expect(fetched?.organization == "TestOrg")

        // Search
        let searched = try await service.searchContacts(query: "__MCPTEST__")
        #expect(searched.contains { $0.id == contactID })

        // Update
        let updated = try await service.updateContact(
            identifier: contactID,
            givenName: nil,
            familyName: nil,
            organization: "UpdatedOrg",
            jobTitle: "Senior Engineer",
            notes: nil
        )
        #expect(updated?.organization == "UpdatedOrg")
        #expect(updated?.jobTitle == "Senior Engineer")

        // Delete
        let deleted = try await service.deleteContact(identifier: contactID)
        #expect(deleted == true)

        // Verify gone
        let afterDelete = try await service.getContact(identifier: contactID)
        #expect(afterDelete == nil)
    }
}
