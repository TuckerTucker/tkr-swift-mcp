import Foundation

/// Errors raised during MCP tool dispatch.
enum ToolError: LocalizedError {
    case invalidArguments(String)
    case unknownTool(String)
    case notFound(String)

    var errorDescription: String? {
        switch self {
        case .invalidArguments(let msg): return "Invalid arguments: \(msg)"
        case .unknownTool(let name): return "Unknown tool: \(name)"
        case .notFound(let msg): return "Not found: \(msg)"
        }
    }
}
