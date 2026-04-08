import Contacts
import Foundation
import Testing
@testable import TKRMCPServer

@Suite("ContactDTO")
struct ContactDTOTests {

    @Test("Codable round-trip preserves all fields")
    func codableRoundTrip() throws {
        let dto = ContactDTO(
            id: "abc-123",
            givenName: "Jane",
            familyName: "Doe",
            organization: "Acme",
            jobTitle: "Engineer",
            nickname: "JD",
            notes: "Test note",
            hasImage: true,
            emails: [LabeledValue(label: "work", value: "jane@acme.com")],
            phones: [LabeledValue(label: "mobile", value: "+1234567890")],
            addresses: [AddressDTO(label: "home", street: "123 Main", city: "SF", state: "CA", postalCode: "94105", country: "US")],
            urls: [LabeledValue(label: "homepage", value: "https://example.com")],
            birthday: "2000-01-15T00:00:00Z"
        )

        let data = try JSONEncoder().encode(dto)
        let decoded = try JSONDecoder().decode(ContactDTO.self, from: data)
        #expect(decoded == dto)
    }

    @Test("Codable round-trip with minimal fields")
    func codableRoundTripMinimal() throws {
        let dto = ContactDTO(id: "x", givenName: "", familyName: "")
        let data = try JSONEncoder().encode(dto)
        let decoded = try JSONDecoder().decode(ContactDTO.self, from: data)
        #expect(decoded == dto)
        #expect(decoded.organization == nil)
        #expect(decoded.emails == nil)
    }

    @Test("from(CNContact) converts basic fields")
    func fromCNContact() {
        let contact = CNMutableContact()
        contact.givenName = "Alice"
        contact.familyName = "Smith"
        contact.organizationName = "Corp"
        contact.jobTitle = "Manager"

        let dto = ContactDTO.from(contact)
        #expect(dto.givenName == "Alice")
        #expect(dto.familyName == "Smith")
        #expect(dto.organization == "Corp")
        #expect(dto.jobTitle == "Manager")
    }

    @Test("from(CNContact) omits empty optional fields")
    func fromCNContactOmitsEmpty() {
        let contact = CNMutableContact()
        contact.givenName = "Bob"
        contact.familyName = "Jones"

        let dto = ContactDTO.from(contact)
        #expect(dto.organization == nil)
        #expect(dto.jobTitle == nil)
        #expect(dto.nickname == nil)
        #expect(dto.emails == nil)
        #expect(dto.phones == nil)
    }

    @Test("from(CNContact) converts emails")
    func fromCNContactWithEmails() {
        let contact = CNMutableContact()
        contact.givenName = "Test"
        contact.familyName = "User"
        contact.emailAddresses = [
            CNLabeledValue(label: CNLabelWork, value: "test@work.com" as NSString),
        ]

        let dto = ContactDTO.from(contact)
        #expect(dto.emails?.count == 1)
        #expect(dto.emails?.first?.value == "test@work.com")
    }

    @Test("from(CNContact) converts phone numbers")
    func fromCNContactWithPhones() {
        let contact = CNMutableContact()
        contact.givenName = "Test"
        contact.familyName = "User"
        contact.phoneNumbers = [
            CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: "+15551234")),
        ]

        let dto = ContactDTO.from(contact)
        #expect(dto.phones?.count == 1)
        #expect(dto.phones?.first?.value == "+15551234")
    }

    @Test("GroupDTO Codable round-trip")
    func groupDTORoundTrip() throws {
        let dto = GroupDTO(id: "g1", name: "Work")
        let data = try JSONEncoder().encode(dto)
        let decoded = try JSONDecoder().decode(GroupDTO.self, from: data)
        #expect(decoded == dto)
    }
}
