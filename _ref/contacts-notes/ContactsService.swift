import Contacts
import Foundation

/// Thread-safe wrapper around CNContactStore for MCP tool handlers.
actor ContactsService {
    private let store = CNContactStore()

    // MARK: - Authorization

    func requestAccess() async throws -> Bool {
        try await store.requestAccess(for: .contacts)
    }

    // MARK: - Key sets

    /// Keys fetched for list/search results (lightweight).
    private static let summaryKeys: [CNKeyDescriptor] = [
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

    // MARK: - Search

    func searchContacts(query: String, limit: Int = 50) throws -> [[String: Any]] {
        let predicate = CNContact.predicateForContacts(matchingName: query)
        let contacts = try store.unifiedContacts(
            matching: predicate,
            keysToFetch: Self.summaryKeys
        )
        return Array(contacts.prefix(limit)).map { contactToDict($0) }
    }

    func getContact(identifier: String) throws -> [String: Any]? {
        let predicate = CNContact.predicateForContacts(withIdentifiers: [identifier])
        let contacts = try store.unifiedContacts(
            matching: predicate,
            keysToFetch: Self.summaryKeys
        )
        return contacts.first.map { contactToDict($0) }
    }

    func listContacts(limit: Int = 100) throws -> [[String: Any]] {
        var results: [CNContact] = []
        let request = CNContactFetchRequest(keysToFetch: Self.summaryKeys)
        request.sortOrder = .givenName
        try store.enumerateContacts(with: request) { contact, stop in
            results.append(contact)
            if results.count >= limit {
                stop.pointee = true
            }
        }
        return results.map { contactToDict($0) }
    }

    // MARK: - Groups

    func listGroups() throws -> [[String: String]] {
        let groups = try store.groups(matching: nil)
        return groups.map { group in
            [
                "id": group.identifier,
                "name": group.name,
            ]
        }
    }

    func listContactsInGroup(groupID: String, limit: Int = 100) throws -> [[String: Any]] {
        let predicate = CNContact.predicateForContactsInGroup(withIdentifier: groupID)
        let contacts = try store.unifiedContacts(
            matching: predicate,
            keysToFetch: Self.summaryKeys
        )
        return Array(contacts.prefix(limit)).map { contactToDict($0) }
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
    ) throws -> [String: Any] {
        let contact = CNMutableContact()
        if let givenName { contact.givenName = givenName }
        if let familyName { contact.familyName = familyName }
        if let organization { contact.organizationName = organization }
        if let jobTitle { contact.jobTitle = jobTitle }
        if let notes { contact.note = notes }

        if let emails {
            contact.emailAddresses = emails.map {
                CNLabeledValue(label: mapLabel($0.label), value: $0.value as NSString)
            }
        }

        if let phones {
            contact.phoneNumbers = phones.map {
                CNLabeledValue(label: mapLabel($0.label), value: CNPhoneNumber(stringValue: $0.value))
            }
        }

        let saveRequest = CNSaveRequest()
        saveRequest.add(contact, toContainerWithIdentifier: nil)
        try store.execute(saveRequest)

        return contactToDict(contact)
    }

    // MARK: - Update

    func updateContact(
        identifier: String,
        givenName: String?,
        familyName: String?,
        organization: String?,
        jobTitle: String?,
        notes: String?
    ) throws -> [String: Any]? {
        let predicate = CNContact.predicateForContacts(withIdentifiers: [identifier])
        guard let contact = try store.unifiedContacts(
            matching: predicate,
            keysToFetch: Self.summaryKeys
        ).first else {
            return nil
        }

        let mutable = contact.mutableCopy() as! CNMutableContact
        if let givenName { mutable.givenName = givenName }
        if let familyName { mutable.familyName = familyName }
        if let organization { mutable.organizationName = organization }
        if let jobTitle { mutable.jobTitle = jobTitle }
        if let notes { mutable.note = notes }

        let saveRequest = CNSaveRequest()
        saveRequest.update(mutable)
        try store.execute(saveRequest)

        return contactToDict(mutable)
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

        let mutable = contact.mutableCopy() as! CNMutableContact
        let saveRequest = CNSaveRequest()
        saveRequest.delete(mutable)
        try store.execute(saveRequest)
        return true
    }

    // MARK: - Serialization

    private nonisolated func contactToDict(_ contact: CNContact) -> [String: Any] {
        var dict: [String: Any] = [
            "id": contact.identifier,
            "givenName": contact.givenName,
            "familyName": contact.familyName,
        ]

        if !contact.organizationName.isEmpty { dict["organization"] = contact.organizationName }
        if !contact.jobTitle.isEmpty { dict["jobTitle"] = contact.jobTitle }
        if !contact.nickname.isEmpty { dict["nickname"] = contact.nickname }
        if !contact.note.isEmpty { dict["notes"] = contact.note }
        if contact.imageDataAvailable { dict["hasImage"] = true }

        if !contact.emailAddresses.isEmpty {
            dict["emails"] = contact.emailAddresses.map { labeled in
                [
                    "label": CNLabeledValue<NSString>.localizedString(forLabel: labeled.label ?? "other"),
                    "value": labeled.value as String,
                ]
            }
        }

        if !contact.phoneNumbers.isEmpty {
            dict["phones"] = contact.phoneNumbers.map { labeled in
                [
                    "label": CNLabeledValue<CNPhoneNumber>.localizedString(forLabel: labeled.label ?? "other"),
                    "value": labeled.value.stringValue,
                ]
            }
        }

        if !contact.postalAddresses.isEmpty {
            dict["addresses"] = contact.postalAddresses.map { labeled in
                let addr = labeled.value
                return [
                    "label": CNLabeledValue<CNPostalAddress>.localizedString(forLabel: labeled.label ?? "other"),
                    "street": addr.street,
                    "city": addr.city,
                    "state": addr.state,
                    "postalCode": addr.postalCode,
                    "country": addr.country,
                ]
            }
        }

        if !contact.urlAddresses.isEmpty {
            dict["urls"] = contact.urlAddresses.map { labeled in
                [
                    "label": CNLabeledValue<NSString>.localizedString(forLabel: labeled.label ?? "other"),
                    "value": labeled.value as String,
                ]
            }
        }

        if let birthday = contact.birthday, let date = Calendar.current.date(from: birthday) {
            dict["birthday"] = ISO8601DateFormatter().string(from: date)
        }

        return dict
    }

    private nonisolated func mapLabel(_ label: String) -> String {
        switch label.lowercased() {
        case "home": return CNLabelHome
        case "work": return CNLabelWork
        case "mobile": return CNLabelPhoneNumberMobile
        case "main": return CNLabelPhoneNumberMain
        case "iphone": return CNLabelPhoneNumberiPhone
        default: return label
        }
    }
}
