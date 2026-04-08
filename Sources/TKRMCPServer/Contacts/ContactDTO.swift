import Contacts
import Foundation

/// A labeled string pair (e.g., email or phone with label).
struct LabeledValue: Codable, Equatable, Sendable {
    let label: String
    let value: String
}

/// Postal address representation.
struct AddressDTO: Codable, Equatable, Sendable {
    let label: String
    let street: String
    let city: String
    let state: String
    let postalCode: String
    let country: String
}

/// Contact group representation.
struct GroupDTO: Codable, Equatable, Sendable {
    let id: String
    let name: String
}

/// Full contact representation returned by MCP tools.
struct ContactDTO: Codable, Equatable, Sendable {
    let id: String
    let givenName: String
    let familyName: String
    var organization: String?
    var jobTitle: String?
    var nickname: String?
    var notes: String?
    var hasImage: Bool?
    var emails: [LabeledValue]?
    var phones: [LabeledValue]?
    var addresses: [AddressDTO]?
    var urls: [LabeledValue]?
    var birthday: String?
}

// MARK: - CNContact Conversion

extension ContactDTO {
    /// Creates a `ContactDTO` from an Apple `CNContact`.
    static func from(_ contact: CNContact) -> ContactDTO {
        var dto = ContactDTO(
            id: contact.identifier,
            givenName: contact.givenName,
            familyName: contact.familyName
        )

        if !contact.organizationName.isEmpty { dto.organization = contact.organizationName }
        if !contact.jobTitle.isEmpty { dto.jobTitle = contact.jobTitle }
        if !contact.nickname.isEmpty { dto.nickname = contact.nickname }
        if !contact.note.isEmpty { dto.notes = contact.note }
        if contact.imageDataAvailable { dto.hasImage = true }

        if !contact.emailAddresses.isEmpty {
            dto.emails = contact.emailAddresses.map { labeled in
                LabeledValue(
                    label: CNLabeledValue<NSString>.localizedString(forLabel: labeled.label ?? "other"),
                    value: labeled.value as String
                )
            }
        }

        if !contact.phoneNumbers.isEmpty {
            dto.phones = contact.phoneNumbers.map { labeled in
                LabeledValue(
                    label: CNLabeledValue<CNPhoneNumber>.localizedString(forLabel: labeled.label ?? "other"),
                    value: labeled.value.stringValue
                )
            }
        }

        if !contact.postalAddresses.isEmpty {
            dto.addresses = contact.postalAddresses.map { labeled in
                let addr = labeled.value
                return AddressDTO(
                    label: CNLabeledValue<CNPostalAddress>.localizedString(forLabel: labeled.label ?? "other"),
                    street: addr.street,
                    city: addr.city,
                    state: addr.state,
                    postalCode: addr.postalCode,
                    country: addr.country
                )
            }
        }

        if !contact.urlAddresses.isEmpty {
            dto.urls = contact.urlAddresses.map { labeled in
                LabeledValue(
                    label: CNLabeledValue<NSString>.localizedString(forLabel: labeled.label ?? "other"),
                    value: labeled.value as String
                )
            }
        }

        if let birthday = contact.birthday, let date = Calendar.current.date(from: birthday) {
            dto.birthday = ISO8601DateFormatter().string(from: date)
        }

        return dto
    }
}
