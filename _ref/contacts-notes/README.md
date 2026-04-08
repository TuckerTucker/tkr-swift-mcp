# Contacts MCP Server

A native Swift MCP server exposing Apple Contacts (CNContactStore) as tools for AI agents.

## Build

```bash
swift build -c release
```

## Permissions

macOS will prompt for Contacts access on first run. If denied, enable in **System Settings → Privacy & Security → Contacts**.

## Claude Desktop Config

```json
{
  "mcpServers": {
    "contacts": {
      "command": "/absolute/path/to/.build/release/ContactsMCPServer"
    }
  }
}
```

## Tools

| Tool | Description |
|------|-------------|
| `search_contacts` | Search by name |
| `get_contact` | Get full contact by ID |
| `list_contacts` | List all contacts |
| `list_groups` | List contact groups |
| `list_contacts_in_group` | List contacts in a group |
| `create_contact` | Create with name, email, phone, org, etc. |
| `update_contact` | Update fields on existing contact |
| `delete_contact` | Permanently delete a contact |

## Example Interactions

- "What's Bob Smith's phone number?"
- "Add a new contact: Jane Doe, jane@example.com, works at Acme"
- "Update John's job title to Senior Engineer"
- "List all contacts in my Work group"
