# Notes MCP Server

A Swift MCP server exposing Apple Notes as tools for AI agents. Uses AppleScript via `osascript` since Notes has no public framework.

## Build

```bash
swift build -c release
```

## Permissions

On first use, macOS will ask to allow the binary (or Terminal) to control Notes.app. Grant access in **System Settings → Privacy & Security → Automation**.

## Claude Desktop Config

```json
{
  "mcpServers": {
    "notes": {
      "command": "/absolute/path/to/.build/release/NotesMCPServer"
    }
  }
}
```

## Tools

| Tool | Description |
|------|-------------|
| `list_folders` | List all Notes folders |
| `list_notes` | List notes, optionally by folder |
| `search_notes` | Search by keyword in title and body |
| `get_note` | Get full note content by ID |
| `create_note` | Create a new note |
| `update_note` | Replace note body content |
| `append_to_note` | Append text to an existing note |
| `delete_note` | Move note to Recently Deleted |

## Caveats

- **AppleScript bridge**: Slower than a native framework. Search iterates all notes.
- **Notes.app must be running**: osascript will launch it if needed, which takes a moment.
- **HTML internally**: Notes stores content as HTML. The server converts plain text ↔ HTML transparently.
- **Large note bodies**: The `||` delimiter in AppleScript output could theoretically appear in note content. For production use, consider a JSON-based AppleScript output format.

## Example Interactions

- "What notes do I have about project ideas?"
- "Create a note called 'Meeting Notes' with today's discussion points"
- "Append the action items to my existing meeting note"
- "Show me all notes in my Work folder"
