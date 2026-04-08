import MCP

/// Aggregates tool definitions from all service modules.
enum ToolRegistry {
    static let allTools: [Tool] =
        ContactsToolHandler.tools + EventKitToolHandler.tools
}
