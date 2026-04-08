@preconcurrency import Contacts
import Foundation
@testable import TKRMCPServer

/// In-memory mock of `ContactStoreProviding` for unit testing.
/// Uses real `CNMutableContact` objects but stores them in memory.
final class MockContactStore: ContactStoreProviding, @unchecked Sendable {
    var contacts: [CNMutableContact] = []
    var groups: [CNMutableGroup] = []
    var accessGranted: Bool = true

    // Call tracking
    private(set) var executedSaveRequests: Int = 0

    func requestAccess(for entityType: CNEntityType) async throws -> Bool {
        accessGranted
    }

    func unifiedContacts(
        matching predicate: NSPredicate,
        keysToFetch keys: [CNKeyDescriptor]
    ) throws -> [CNContact] {
        contacts.filter { predicate.evaluate(with: $0) }
    }

    func enumerateContacts(
        with request: CNContactFetchRequest,
        usingBlock: (CNContact, UnsafeMutablePointer<ObjCBool>) -> Void
    ) throws {
        var stop: ObjCBool = false
        for contact in contacts {
            usingBlock(contact, &stop)
            if stop.boolValue { break }
        }
    }

    func groups(matching predicate: NSPredicate?) throws -> [CNGroup] {
        if let predicate {
            return groups.filter { predicate.evaluate(with: $0) }
        }
        return groups
    }

    func execute(_ request: CNSaveRequest) throws {
        executedSaveRequests += 1
    }

    // MARK: - Test Helpers

    /// Creates and stores a mock contact with the given fields.
    @discardableResult
    func addContact(
        givenName: String = "",
        familyName: String = "",
        organization: String = "",
        jobTitle: String = "",
        email: (label: String, value: String)? = nil,
        phone: (label: String, value: String)? = nil
    ) -> CNMutableContact {
        let contact = CNMutableContact()
        contact.givenName = givenName
        contact.familyName = familyName
        contact.organizationName = organization
        contact.jobTitle = jobTitle
        if let email {
            contact.emailAddresses = [
                CNLabeledValue(label: email.label, value: email.value as NSString)
            ]
        }
        if let phone {
            contact.phoneNumbers = [
                CNLabeledValue(label: phone.label, value: CNPhoneNumber(stringValue: phone.value))
            ]
        }
        contacts.append(contact)
        return contact
    }

    /// Creates and stores a mock group.
    @discardableResult
    func addGroup(name: String) -> CNMutableGroup {
        let group = CNMutableGroup()
        group.name = name
        groups.append(group)
        return group
    }
}
