import Foundation
import MCP

/// Creates and configures the MCP server with all tool handlers registered.
func createServer(
    contactsService: ContactsService,
    eventKitService: EventKitService
) async -> Server {
    let server = Server(
        name: "tkr-mcp-server",
        version: "1.0.0",
        capabilities: .init(tools: .init(listChanged: false))
    )

    await server.withMethodHandler(ListTools.self) { _ in
        .init(tools: ToolRegistry.allTools)
    }

    await server.withMethodHandler(CallTool.self) { params in
        do {
            let result: String

            // Route to the appropriate handler based on tool name
            if ContactsToolHandler.tools.contains(where: { $0.name == params.name }) {
                result = try await ContactsToolHandler.handle(params, service: contactsService)
            } else if EventKitToolHandler.tools.contains(where: { $0.name == params.name }) {
                result = try await EventKitToolHandler.handle(params, service: eventKitService)
            } else {
                throw ToolError.unknownTool(params.name)
            }

            return .init(content: [.text(text: result, annotations: nil, _meta: nil)], isError: false)
        } catch {
            return .init(content: [.text(text: "Error: \(error.localizedDescription)", annotations: nil, _meta: nil)], isError: true)
        }
    }

    return server
}
