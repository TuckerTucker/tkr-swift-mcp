import Foundation
import MCP

/// Defines and dispatches MCP tools for Apple Contacts.
enum ContactsToolHandler {

    /// All contact-related MCP tool definitions.
    static let tools: [Tool] = [
        Tool(
            name: "search_contacts",
            description: "Search contacts by name. Returns matching contacts with phone, email, address, etc.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "query": .object(["type": "string", "description": "Name to search for"]),
                    "limit": .object(["type": "integer", "description": "Max results (default 50)"]),
                ]),
                "required": .array([.string("query")]),
            ])
        ),
        Tool(
            name: "get_contact",
            description: "Get a single contact by its identifier.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "id": .object(["type": "string", "description": "Contact identifier"]),
                ]),
                "required": .array([.string("id")]),
            ])
        ),
        Tool(
            name: "list_contacts",
            description: "List all contacts sorted by first name. Use search_contacts for targeted lookups.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "limit": .object(["type": "integer", "description": "Max results (default 100)"]),
                ]),
            ])
        ),
        Tool(
            name: "list_groups",
            description: "List all contact groups.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([:]),
            ])
        ),
        Tool(
            name: "list_contacts_in_group",
            description: "List contacts belonging to a specific group.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "groupID": .object(["type": "string", "description": "Group identifier"]),
                    "limit": .object(["type": "integer", "description": "Max results (default 100)"]),
                ]),
                "required": .array([.string("groupID")]),
            ])
        ),
        Tool(
            name: "create_contact",
            description: "Create a new contact. At least one of givenName or familyName is recommended.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "givenName": .object(["type": "string"]),
                    "familyName": .object(["type": "string"]),
                    "organization": .object(["type": "string"]),
                    "jobTitle": .object(["type": "string"]),
                    "notes": .object(["type": "string"]),
                    "emails": .object([
                        "type": "array",
                        "items": .object([
                            "type": "object",
                            "properties": .object([
                                "label": .object(["type": "string", "description": "home, work, other"]),
                                "value": .object(["type": "string"]),
                            ]),
                        ]),
                        "description": "Array of {label, value} email entries",
                    ]),
                    "phones": .object([
                        "type": "array",
                        "items": .object([
                            "type": "object",
                            "properties": .object([
                                "label": .object(["type": "string", "description": "home, work, mobile, main, iphone"]),
                                "value": .object(["type": "string"]),
                            ]),
                        ]),
                        "description": "Array of {label, value} phone entries",
                    ]),
                ]),
            ])
        ),
        Tool(
            name: "update_contact",
            description: "Update fields on an existing contact. Only provided fields are changed.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "id": .object(["type": "string", "description": "Contact identifier"]),
                    "givenName": .object(["type": "string"]),
                    "familyName": .object(["type": "string"]),
                    "organization": .object(["type": "string"]),
                    "jobTitle": .object(["type": "string"]),
                    "notes": .object(["type": "string"]),
                ]),
                "required": .array([.string("id")]),
            ])
        ),
        Tool(
            name: "delete_contact",
            description: "Permanently delete a contact by its identifier.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "id": .object(["type": "string", "description": "Contact identifier"]),
                ]),
                "required": .array([.string("id")]),
            ])
        ),
    ]

    /// Dispatches a tool call to the appropriate contacts service method.
    static func handle(
        _ params: CallTool.Parameters,
        service: ContactsService
    ) async throws -> String {
        let args = params.arguments ?? [:]

        switch params.name {
        case "search_contacts":
            guard let query = args["query"]?.stringValue else {
                throw ToolError.invalidArguments("query is required")
            }
            let limit = try validLimit(args["limit"]?.intValue, default: 50)
            let contacts = try await service.searchContacts(query: query, limit: limit)
            return try encodeJSON(contacts)

        case "get_contact":
            guard let id = args["id"]?.stringValue else {
                throw ToolError.invalidArguments("id is required")
            }
            guard let contact = try await service.getContact(identifier: id) else {
                throw ToolError.notFound("Contact '\(id)' not found")
            }
            return try encodeJSON(contact)

        case "list_contacts":
            let limit = try validLimit(args["limit"]?.intValue, default: 100)
            let contacts = try await service.listContacts(limit: limit)
            return try encodeJSON(contacts)

        case "list_groups":
            let groups = try await service.listGroups()
            return try encodeJSON(groups)

        case "list_contacts_in_group":
            guard let groupID = args["groupID"]?.stringValue else {
                throw ToolError.invalidArguments("groupID is required")
            }
            let limit = try validLimit(args["limit"]?.intValue, default: 100)
            let contacts = try await service.listContactsInGroup(groupID: groupID, limit: limit)
            return try encodeJSON(contacts)

        case "create_contact":
            let givenName = args["givenName"]?.stringValue
            let familyName = args["familyName"]?.stringValue
            if (givenName ?? "").isEmpty && (familyName ?? "").isEmpty {
                throw ToolError.invalidArguments("at least one of givenName or familyName is required")
            }
            let emails = parseLabeled(args["emails"])
            let phones = parseLabeled(args["phones"])
            let contact = try await service.createContact(
                givenName: givenName,
                familyName: familyName,
                organization: args["organization"]?.stringValue,
                jobTitle: args["jobTitle"]?.stringValue,
                emails: emails,
                phones: phones,
                notes: args["notes"]?.stringValue
            )
            return try encodeJSON(contact)

        case "update_contact":
            guard let id = args["id"]?.stringValue else {
                throw ToolError.invalidArguments("id is required")
            }
            guard let contact = try await service.updateContact(
                identifier: id,
                givenName: args["givenName"]?.stringValue,
                familyName: args["familyName"]?.stringValue,
                organization: args["organization"]?.stringValue,
                jobTitle: args["jobTitle"]?.stringValue,
                notes: args["notes"]?.stringValue
            ) else {
                throw ToolError.notFound("Contact '\(id)' not found")
            }
            return try encodeJSON(contact)

        case "delete_contact":
            guard let id = args["id"]?.stringValue else {
                throw ToolError.invalidArguments("id is required")
            }
            let deleted = try await service.deleteContact(identifier: id)
            return try encodeJSON(["deleted": deleted])

        default:
            throw ToolError.unknownTool(params.name)
        }
    }

    /// Validates a limit parameter, returning the default if nil or throwing if < 1.
    private static func validLimit(_ value: Int?, default defaultValue: Int) throws -> Int {
        guard let value else { return defaultValue }
        guard value >= 1 else {
            throw ToolError.invalidArguments("limit must be >= 1, got \(value)")
        }
        return value
    }

    /// Parses an array of `{label, value}` objects from MCP `Value`.
    private static func parseLabeled(_ value: Value?) -> [(label: String, value: String)]? {
        guard case .array(let items) = value else { return nil }
        return items.compactMap { item -> (label: String, value: String)? in
            guard case .object(let obj) = item,
                  let label = obj["label"]?.stringValue,
                  let val = obj["value"]?.stringValue
            else { return nil }
            return (label: label, value: val)
        }
    }
}
