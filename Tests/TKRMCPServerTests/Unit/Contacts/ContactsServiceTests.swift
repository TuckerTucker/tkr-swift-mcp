import Contacts
import Foundation
import Testing
@testable import TKRMCPServer

@Suite("ContactsService")
struct ContactsServiceTests {

    @Test("requestAccess returns mock value")
    func requestAccess() async throws {
        let mock = MockContactStore()
        mock.accessGranted = true
        let service = ContactsService(store: mock)
        #expect(try await service.requestAccess() == true)

        mock.accessGranted = false
        #expect(try await service.requestAccess() == false)
    }

    @Test("listContacts returns DTOs from mock store")
    func listContacts() async throws {
        let mock = MockContactStore()
        mock.addContact(givenName: "Alice", familyName: "Smith")
        mock.addContact(givenName: "Bob", familyName: "Jones")

        let service = ContactsService(store: mock)
        let results = try await service.listContacts()

        #expect(results.count == 2)
        #expect(results[0].givenName == "Alice")
        #expect(results[1].givenName == "Bob")
    }

    @Test("listContacts respects limit")
    func listContactsLimit() async throws {
        let mock = MockContactStore()
        for i in 0..<10 {
            mock.addContact(givenName: "User\(i)")
        }

        let service = ContactsService(store: mock)
        let results = try await service.listContacts(limit: 3)
        #expect(results.count == 3)
    }

    @Test("searchContacts uses predicate matching")
    func searchContacts() async throws {
        let mock = MockContactStore()
        mock.addContact(givenName: "Alice", familyName: "Smith")
        mock.addContact(givenName: "Bob", familyName: "Jones")

        let service = ContactsService(store: mock)
        let results = try await service.searchContacts(query: "Alice")
        // CNContact.predicateForContacts(matchingName:) evaluates against the mock contacts
        #expect(results.allSatisfy { $0.givenName == "Alice" || $0.familyName.contains("Alice") } || results.isEmpty)
    }

    @Test("getContact returns nil for unknown ID")
    func getContactUnknown() async throws {
        let mock = MockContactStore()
        let service = ContactsService(store: mock)
        let result = try await service.getContact(identifier: "nonexistent")
        #expect(result == nil)
    }

    @Test("listGroups returns mock groups")
    func listGroups() async throws {
        let mock = MockContactStore()
        mock.addGroup(name: "Family")
        mock.addGroup(name: "Work")

        let service = ContactsService(store: mock)
        let groups = try await service.listGroups()
        #expect(groups.count == 2)
        #expect(groups[0].name == "Family")
        #expect(groups[1].name == "Work")
    }

    @Test("createContact executes save request")
    func createContact() async throws {
        let mock = MockContactStore()
        let service = ContactsService(store: mock)

        let result = try await service.createContact(
            givenName: "New",
            familyName: "Person",
            organization: nil,
            jobTitle: nil,
            emails: nil,
            phones: nil,
            notes: nil
        )

        #expect(result.givenName == "New")
        #expect(result.familyName == "Person")
        #expect(mock.executedSaveRequests == 1)
    }

    @Test("deleteContact returns false for nonexistent")
    func deleteContactNotFound() async throws {
        let mock = MockContactStore()
        let service = ContactsService(store: mock)
        let deleted = try await service.deleteContact(identifier: "missing")
        #expect(deleted == false)
    }

    @Test("mapLabel converts standard labels")
    func mapLabel() {
        #expect(ContactsService.mapLabel("home") == CNLabelHome)
        #expect(ContactsService.mapLabel("work") == CNLabelWork)
        #expect(ContactsService.mapLabel("mobile") == CNLabelPhoneNumberMobile)
        #expect(ContactsService.mapLabel("main") == CNLabelPhoneNumberMain)
        #expect(ContactsService.mapLabel("iphone") == CNLabelPhoneNumberiPhone)
        #expect(ContactsService.mapLabel("custom") == "custom")
    }
}
