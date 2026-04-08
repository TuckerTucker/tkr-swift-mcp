import MCP

/// Aggregates tool definitions from all service modules.
enum ToolRegistry {
    static var allTools: [Tool] {
        ContactsToolHandler.tools + EventKitToolHandler.tools
    }
}
