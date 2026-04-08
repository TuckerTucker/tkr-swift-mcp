@preconcurrency import Contacts
import Foundation

/// Thread-safe service wrapping contact store operations.
actor ContactsService {
    private let store: any ContactStoreProviding

    /// Keys fetched for list/search results.
    static let summaryKeys: [CNKeyDescriptor] = [
        CNContactIdentifierKey as CNKeyDescriptor,
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactOrganizationNameKey as CNKeyDescriptor,
        CNContactEmailAddressesKey as CNKeyDescriptor,
        CNContactPhoneNumbersKey as CNKeyDescriptor,
        CNContactJobTitleKey as CNKeyDescriptor,
        CNContactNicknameKey as CNKeyDescriptor,
        CNContactBirthdayKey as CNKeyDescriptor,
        CNContactPostalAddressesKey as CNKeyDescriptor,
        CNContactUrlAddressesKey as CNKeyDescriptor,
        CNContactNoteKey as CNKeyDescriptor,
        CNContactImageDataAvailableKey as CNKeyDescriptor,
    ]

    init(store: any ContactStoreProviding = ContactStore()) {
        self.store = store
    }

    // MARK: - Authorization

    func requestAccess() async throws -> Bool {
        try await store.requestAccess(for: .contacts)
    }

    // MARK: - Search

    func searchContacts(query: String, limit: Int = 50) throws -> [ContactDTO] {
        let predicate = CNContact.predicateForContacts(matchingName: query)
        let contacts = try store.unifiedContacts(
            matching: predicate,
            keysToFetch: Self.summaryKeys
        )
        return Array(contacts.prefix(limit)).map { ContactDTO.from($0) }
    }

    func getContact(identifier: String) throws -> ContactDTO? {
        let predicate = CNContact.predicateForContacts(withIdentifiers: [identifier])
        let contacts = try store.unifiedContacts(
            matching: predicate,
            keysToFetch: Self.summaryKeys
        )
        return contacts.first.map { ContactDTO.from($0) }
    }

    func listContacts(limit: Int = 100) throws -> [ContactDTO] {
        var results: [CNContact] = []
        let request = CNContactFetchRequest(keysToFetch: Self.summaryKeys)
        request.sortOrder = .givenName
        try store.enumerateContacts(with: request) { contact, stop in
            results.append(contact)
            if results.count >= limit {
                stop.pointee = true
            }
        }
        return results.map { ContactDTO.from($0) }
    }

    // MARK: - Groups

    func listGroups() throws -> [GroupDTO] {
        let groups = try store.groups(matching: nil)
        return groups.map { GroupDTO(id: $0.identifier, name: $0.name) }
    }

    func listContactsInGroup(groupID: String, limit: Int = 100) throws -> [ContactDTO] {
        let predicate = CNContact.predicateForContactsInGroup(withIdentifier: groupID)
        let contacts = try store.unifiedContacts(
            matching: predicate,
            keysToFetch: Self.summaryKeys
        )
        return Array(contacts.prefix(limit)).map { ContactDTO.from($0) }
    }

    // MARK: - Create

    func createContact(
        givenName: String?,
        familyName: String?,
        organization: String?,
        jobTitle: String?,
        emails: [(label: String, value: String)]?,
        phones: [(label: String, value: String)]?,
        notes: String?
    ) throws -> ContactDTO {
        let contact = CNMutableContact()
        if let givenName { contact.givenName = givenName }
        if let familyName { contact.familyName = familyName }
        if let organization { contact.organizationName = organization }
        if let jobTitle { contact.jobTitle = jobTitle }
        if let notes { contact.note = notes }

        if let emails {
            contact.emailAddresses = emails.map {
                CNLabeledValue(label: Self.mapLabel($0.label), value: $0.value as NSString)
            }
        }

        if let phones {
            contact.phoneNumbers = phones.map {
                CNLabeledValue(label: Self.mapLabel($0.label), value: CNPhoneNumber(stringValue: $0.value))
            }
        }

        let saveRequest = CNSaveRequest()
        saveRequest.add(contact, toContainerWithIdentifier: nil)
        try store.execute(saveRequest)

        return ContactDTO.from(contact)
    }

    // MARK: - Update

    func updateContact(
        identifier: String,
        givenName: String?,
        familyName: String?,
        organization: String?,
        jobTitle: String?,
        notes: String?
    ) throws -> ContactDTO? {
        let predicate = CNContact.predicateForContacts(withIdentifiers: [identifier])
        guard let contact = try store.unifiedContacts(
            matching: predicate,
            keysToFetch: Self.summaryKeys
        ).first else {
            return nil
        }

        guard let mutable = contact.mutableCopy() as? CNMutableContact else {
            return nil
        }
        if let givenName { mutable.givenName = givenName }
        if let familyName { mutable.familyName = familyName }
        if let organization { mutable.organizationName = organization }
        if let jobTitle { mutable.jobTitle = jobTitle }
        if let notes { mutable.note = notes }

        let saveRequest = CNSaveRequest()
        saveRequest.update(mutable)
        try store.execute(saveRequest)

        return ContactDTO.from(mutable)
    }

    // MARK: - Delete

    func deleteContact(identifier: String) throws -> Bool {
        let predicate = CNContact.predicateForContacts(withIdentifiers: [identifier])
        guard let contact = try store.unifiedContacts(
            matching: predicate,
            keysToFetch: [CNContactIdentifierKey as CNKeyDescriptor]
        ).first else {
            return false
        }

        guard let mutable = contact.mutableCopy() as? CNMutableContact else {
            return false
        }
        let saveRequest = CNSaveRequest()
        saveRequest.delete(mutable)
        try store.execute(saveRequest)
        return true
    }

    // MARK: - Helpers

    static func mapLabel(_ label: String) -> String {
        switch label.lowercased() {
        case "home": return CNLabelHome
        case "work": return CNLabelWork
        case "other": return CNLabelOther
        case "mobile": return CNLabelPhoneNumberMobile
        case "main": return CNLabelPhoneNumberMain
        case "iphone": return CNLabelPhoneNumberiPhone
        case "fax", "home fax": return CNLabelPhoneNumberHomeFax
        case "work fax": return CNLabelPhoneNumberWorkFax
        case "pager": return CNLabelPhoneNumberPager
        default: return label
        }
    }
}
