import Contacts
import Foundation

/// Abstracts `CNContactStore` operations for testability.
protocol ContactStoreProviding: Sendable {
    func requestAccess(for entityType: CNEntityType) async throws -> Bool

    func unifiedContacts(
        matching predicate: NSPredicate,
        keysToFetch keys: [CNKeyDescriptor]
    ) throws -> [CNContact]

    func enumerateContacts(
        with request: CNContactFetchRequest,
        usingBlock: (CNContact, UnsafeMutablePointer<ObjCBool>) -> Void
    ) throws

    func groups(matching predicate: NSPredicate?) throws -> [CNGroup]

    func execute(_ request: CNSaveRequest) throws
}
