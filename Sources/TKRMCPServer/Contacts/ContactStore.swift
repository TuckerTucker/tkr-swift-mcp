import Contacts
import Foundation

/// Production conformance delegating to `CNContactStore`.
final class ContactStore: ContactStoreProviding, @unchecked Sendable {
    private let store = CNContactStore()

    func requestAccess(for entityType: CNEntityType) async throws -> Bool {
        try await store.requestAccess(for: entityType)
    }

    func unifiedContacts(
        matching predicate: NSPredicate,
        keysToFetch keys: [CNKeyDescriptor]
    ) throws -> [CNContact] {
        try store.unifiedContacts(matching: predicate, keysToFetch: keys)
    }

    func enumerateContacts(
        with request: CNContactFetchRequest,
        usingBlock: (CNContact, UnsafeMutablePointer<ObjCBool>) -> Void
    ) throws {
        try store.enumerateContacts(with: request, usingBlock: usingBlock)
    }

    func groups(matching predicate: NSPredicate?) throws -> [CNGroup] {
        try store.groups(matching: predicate)
    }

    func execute(_ request: CNSaveRequest) throws {
        try store.execute(request)
    }
}
