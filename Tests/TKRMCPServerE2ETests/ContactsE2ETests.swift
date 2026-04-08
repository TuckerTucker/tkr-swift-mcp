@preconcurrency import Contacts
import Foundation
import Testing
@testable import TKRMCPServer

/// E2E tests that exercise real system APIs (CNContactStore).
/// These require Contacts permission granted to the test runner.
/// Skip with: SKIP_E2E=1 environment variable.
@Suite("Contacts E2E", .enabled(if: ProcessInfo.processInfo.environment["SKIP_E2E"] == nil))
struct ContactsE2ETests {

    /// Directly deletes a contact via CNContactStore (for cleanup outside actor context).
    private func cleanupContact(identifier: String, store: CNContactStore) {
        let predicate = CNContact.predicateForContacts(withIdentifiers: [identifier])
        guard let contact = try? store.unifiedContacts(
            matching: predicate,
            keysToFetch: [CNContactIdentifierKey as CNKeyDescriptor]
        ).first,
            let mutable = contact.mutableCopy() as? CNMutableContact
        else { return }
        let request = CNSaveRequest()
        request.delete(mutable)
        try? store.execute(request)
    }

    @Test("Contact CRUD cycle")
    func contactCRUDCycle() async throws {
        let cnStore = CNContactStore()
        let granted = try await cnStore.requestAccess(for: .contacts)
        try #require(granted, "Contacts access denied — grant in System Settings")

        let store = ContactStore()
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
        let contactID = created.id

        // Ensure cleanup even on test failure
        defer { cleanupContact(identifier: contactID, store: cnStore) }

        #expect(created.givenName == "__MCPTEST__")
        #expect(created.familyName == "E2EContact")

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
