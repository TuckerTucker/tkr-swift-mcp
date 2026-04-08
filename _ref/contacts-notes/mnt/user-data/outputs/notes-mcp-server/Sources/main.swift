import Foundation
import Logging
import MCP
import ServiceLifecycle

@main
struct NotesMCPServerApp {
    static func main() async throws {
        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardError(label: label)
            handler.logLevel = .warning
            return handler
        }
        let logger = Logger(label: "com.notes-mcp-server")

        let service = NotesService()

        let server = Server(
            name: "notes-mcp-server",
            version: "1.0.0",
            capabilities: .init(tools: .init(listChanged: false))
        )

        // ── Tool Definitions ──────────────────────────────────────────

        let tools: [Tool] = [
            Tool(
                name: "list_folders",
                description: "List all folders/notebooks in Apple Notes.",
                inputSchema: .object(["type": "object", "properties": .object([:])])
            ),
            Tool(
                name: "list_notes",
                description: "List notes, optionally filtered by folder name.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "folderName": .object(["type": "string", "description": "Folder name to filter by"]),
                        "limit": .object(["type": "integer", "description": "Max results (default 50)"]),
                    ]),
                ])
            ),
            Tool(
                name: "search_notes",
                description: "Search notes by keyword in title and body.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "query": .object(["type": "string", "description": "Search keyword"]),
                        "limit": .object(["type": "integer", "description": "Max results (default 30)"]),
                    ]),
                    "required": .array([.string("query")]),
                ])
            ),
            Tool(
                name: "get_note",
                description: "Get the full content of a note by its ID.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "noteID": .object(["type": "string", "description": "Note identifier"]),
                    ]),
                    "required": .array([.string("noteID")]),
                ])
            ),
            Tool(
                name: "create_note",
                description: "Create a new note in Apple Notes.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "title": .object(["type": "string"]),
                        "body": .object(["type": "string", "description": "Plain text body content"]),
                        "folderName": .object(["type": "string", "description": "Folder to create in (default: Notes)"]),
                    ]),
                    "required": .array([.string("title"), .string("body")]),
                ])
            ),
            Tool(
                name: "update_note",
                description: "Replace the body content of an existing note.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "noteID": .object(["type": "string", "description": "Note identifier"]),
                        "body": .object(["type": "string", "description": "New plain text body content"]),
                    ]),
                    "required": .array([.string("noteID"), .string("body")]),
                ])
            ),
            Tool(
                name: "append_to_note",
                description: "Append text to the end of an existing note.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "noteID": .object(["type": "string", "description": "Note identifier"]),
                        "text": .object(["type": "string", "description": "Text to append"]),
                    ]),
                    "required": .array([.string("noteID"), .string("text")]),
                ])
            ),
            Tool(
                name: "delete_note",
                description: "Move a note to the Recently Deleted folder.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "noteID": .object(["type": "string", "description": "Note identifier"]),
                    ]),
                    "required": .array([.string("noteID")]),
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

private func handleToolCall(params: CallTool.Parameters, service: NotesService) async throws -> String {
    let args = params.arguments ?? [:]

    switch params.name {
    case "list_folders":
        let folders = try await service.listFolders()
        return toJSON(folders)

    case "list_notes":
        let folder = args["folderName"]?.stringValue
        let limit = args["limit"]?.intValue.map(Int.init) ?? 50
        let notes = try await service.listNotes(folderName: folder, limit: limit)
        return toJSON(notes)

    case "search_notes":
        guard let query = args["query"]?.stringValue else {
            throw ToolError.invalidArguments("query is required")
        }
        let limit = args["limit"]?.intValue.map(Int.init) ?? 30
        let notes = try await service.searchNotes(query: query, limit: limit)
        return toJSON(notes)

    case "get_note":
        guard let noteID = args["noteID"]?.stringValue else {
            throw ToolError.invalidArguments("noteID is required")
        }
        if let note = try await service.getNote(noteID: noteID) {
            return toJSON(note)
        }
        return toJSON(["error": "Note not found"])

    case "create_note":
        guard let title = args["title"]?.stringValue,
              let body = args["body"]?.stringValue
        else {
            throw ToolError.invalidArguments("title and body are required")
        }
        let result = try await service.createNote(
            title: title,
            body: body,
            folderName: args["folderName"]?.stringValue
        )
        return toJSON(result)

    case "update_note":
        guard let noteID = args["noteID"]?.stringValue,
              let body = args["body"]?.stringValue
        else {
            throw ToolError.invalidArguments("noteID and body are required")
        }
        let success = try await service.updateNote(noteID: noteID, body: body)
        return toJSON(["success": success])

    case "append_to_note":
        guard let noteID = args["noteID"]?.stringValue,
              let text = args["text"]?.stringValue
        else {
            throw ToolError.invalidArguments("noteID and text are required")
        }
        let success = try await service.appendToNote(noteID: noteID, text: text)
        return toJSON(["success": success])

    case "delete_note":
        guard let noteID = args["noteID"]?.stringValue else {
            throw ToolError.invalidArguments("noteID is required")
        }
        let deleted = try await service.deleteNote(noteID: noteID)
        return toJSON(["deleted": deleted])

    default:
        throw ToolError.unknownTool(params.name)
    }
}

// MARK: - Helpers

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
    var intValue: Int64? {
        if case .int(let i) = self { return i }
        return nil
    }
}
