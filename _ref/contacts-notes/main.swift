import Contacts
import Foundation
import Logging
import MCP
import ServiceLifecycle

@main
struct ContactsMCPServerApp {
    static func main() async throws {
        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardError(label: label)
            handler.logLevel = .warning
            return handler
        }
        let logger = Logger(label: "com.contacts-mcp-server")

        let service = ContactsService()

        let access = try await service.requestAccess()
        guard access else {
            logger.error("Contacts access denied. Grant in System Settings > Privacy & Security > Contacts.")
            Foundation.exit(1)
        }

        let server = Server(
            name: "contacts-mcp-server",
            version: "1.0.0",
            capabilities: .init(tools: .init(listChanged: false))
        )

        // ── Tool Definitions ──────────────────────────────────────────

        let tools: [Tool] = [
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

        // ── Register Handlers ─────────────────────────────────────────

        await server.withMethodHandler(ListTools.self) { _ in .init(tools: tools) }

        await server.withMethodHandler(CallTool.self) { params in
            do {
                let result = try await handleToolCall(params: params, service: service)
                return .init(content: [.text(result)], isError: false)
            } catch {
                return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
            }
        }

        // ── Start ─────────────────────────────────────────────────────

        let transport = StdioTransport(logger: logger)

        struct MCPService: Service {
            let server: Server
            let transport: StdioTransport
            func run() async throws {
                try await server.start(transport: transport)
                try await Task.sleep(for: .seconds(365 * 24 * 3600))
            }
        }

        let serviceGroup = ServiceGroup(
            services: [MCPService(server: server, transport: transport)],
            configuration: .init(gracefulShutdownSignals: [.sigterm, .sigint]),
            logger: logger
        )
        try await serviceGroup.run()
    }
}

// MARK: - Tool Dispatch

private func handleToolCall(params: CallTool.Parameters, service: ContactsService) async throws -> String {
    let args = params.arguments ?? [:]

    switch params.name {
    case "search_contacts":
        guard let query = args["query"]?.stringValue else {
            throw ToolError.invalidArguments("query is required")
        }
        let limit = args["limit"]?.intValue.map(Int.init) ?? 50
        let contacts = try await service.searchContacts(query: query, limit: limit)
        return toJSON(contacts)

    case "get_contact":
        guard let id = args["id"]?.stringValue else {
            throw ToolError.invalidArguments("id is required")
        }
        if let contact = try await service.getContact(identifier: id) {
            return toJSON(contact)
        }
        return toJSON(["error": "Contact not found"])

    case "list_contacts":
        let limit = args["limit"]?.intValue.map(Int.init) ?? 100
        let contacts = try await service.listContacts(limit: limit)
        return toJSON(contacts)

    case "list_groups":
        let groups = try await service.listGroups()
        return toJSON(groups)

    case "list_contacts_in_group":
        guard let groupID = args["groupID"]?.stringValue else {
            throw ToolError.invalidArguments("groupID is required")
        }
        let limit = args["limit"]?.intValue.map(Int.init) ?? 100
        let contacts = try await service.listContactsInGroup(groupID: groupID, limit: limit)
        return toJSON(contacts)

    case "create_contact":
        let emails = parseLabeled(args["emails"])
        let phones = parseLabeled(args["phones"])
        let contact = try await service.createContact(
            givenName: args["givenName"]?.stringValue,
            familyName: args["familyName"]?.stringValue,
            organization: args["organization"]?.stringValue,
            jobTitle: args["jobTitle"]?.stringValue,
            emails: emails,
            phones: phones,
            notes: args["notes"]?.stringValue
        )
        return toJSON(contact)

    case "update_contact":
        guard let id = args["id"]?.stringValue else {
            throw ToolError.invalidArguments("id is required")
        }
        if let contact = try await service.updateContact(
            identifier: id,
            givenName: args["givenName"]?.stringValue,
            familyName: args["familyName"]?.stringValue,
            organization: args["organization"]?.stringValue,
            jobTitle: args["jobTitle"]?.stringValue,
            notes: args["notes"]?.stringValue
        ) {
            return toJSON(contact)
        }
        return toJSON(["error": "Contact not found"])

    case "delete_contact":
        guard let id = args["id"]?.stringValue else {
            throw ToolError.invalidArguments("id is required")
        }
        let deleted = try await service.deleteContact(identifier: id)
        return toJSON(["deleted": deleted])

    default:
        throw ToolError.unknownTool(params.name)
    }
}

// MARK: - Helpers

private func parseLabeled(_ value: Value?) -> [(label: String, value: String)]? {
    guard case .array(let items) = value else { return nil }
    return items.compactMap { item -> (label: String, value: String)? in
        guard case .object(let obj) = item,
              let label = obj["label"]?.stringValue,
              let val = obj["value"]?.stringValue
        else { return nil }
        return (label: label, value: val)
    }
}

enum ToolError: LocalizedError {
    case invalidArguments(String)
    case unknownTool(String)
    var errorDescription: String? {
        switch self {
        case .invalidArguments(let msg): return "Invalid arguments: \(msg)"
        case .unknownTool(let name): return "Unknown tool: \(name)"
        }
    }
}

private func toJSON(_ value: Any) -> String {
    guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]),
          let str = String(data: data, encoding: .utf8)
    else { return "{}" }
    return str
}

import struct MCP.Value

extension Value {
    var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }
    var intValue: Int64? {
        if case .int(let i) = self { return i }
        return nil
    }
}
