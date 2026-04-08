# EventKit MCP Server

A native Swift MCP server that exposes Apple EventKit (Calendars & Reminders) as tools for AI agents.

Built on the [official MCP Swift SDK](https://github.com/modelcontextprotocol/swift-sdk).

## Requirements

- macOS 13+
- Swift 6.0+ (Xcode 16+)
- Calendar & Reminders permissions granted

## Build

```bash
cd eventkit-mcp-server
swift build -c release
```

The binary will be at `.build/release/EventKitMCPServer`.

## Permissions

On first run, macOS will prompt you to grant Calendar and Reminders access.
If you deny, go to **System Settings → Privacy & Security → Calendars / Reminders** and enable access for the binary.

> **Tip:** If running unsigned from the terminal, you may need to grant access to Terminal.app itself.

## Claude Desktop Configuration

Add to `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "eventkit": {
      "command": "/absolute/path/to/eventkit-mcp-server/.build/release/EventKitMCPServer"
    }
  }
}
```

## Claude Code Configuration

```bash
claude mcp add eventkit /absolute/path/to/.build/release/EventKitMCPServer
```

## Available Tools

| Tool | Description |
|------|-------------|
| `list_calendars` | List event or reminder calendars |
| `list_events` | Query events in a date range |
| `create_event` | Create a calendar event |
| `delete_event` | Delete an event by ID |
| `list_reminders` | List reminders (filter by completed/incomplete) |
| `create_reminder` | Create a reminder with optional due date & priority |
| `complete_reminder` | Mark a reminder completed or incomplete |
| `delete_reminder` | Delete a reminder by ID |

## Architecture

```
main.swift              → MCP server setup, tool definitions, dispatch
EventKitService.swift   → Actor wrapping EventKit with async/await
```

The server communicates over **stdio** (stdin/stdout) using the MCP JSON-RPC protocol. Logging goes to stderr to avoid corrupting the protocol stream.

## Example Interactions

Once connected, an AI agent can:

- "What's on my calendar this week?"
- "Create a meeting with Bob tomorrow at 2pm"
- "Show me my incomplete reminders"
- "Add a reminder to buy groceries, due Friday"
- "Mark the groceries reminder as done"
