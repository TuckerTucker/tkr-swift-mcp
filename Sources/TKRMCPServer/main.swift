import Foundation
import Logging
import MCP
import ServiceLifecycle

// Configure logging to stderr (stdout is reserved for MCP protocol)
LoggingSystem.bootstrap { label in
    var handler = StreamLogHandler.standardError(label: label)
    handler.logLevel = .warning
    return handler
}
let logger = Logger(label: "com.tkr-mcp-server")

// Create production stores
let contactStore = ContactStore()
let eventStore = EventStore()

// Request permissions up front — log warnings but don't exit, so the MCP
// server stays alive and returns actionable errors at the tool level.
let contactsAccess = (try? await contactStore.requestAccess(for: .contacts)) ?? false
if !contactsAccess {
    logger.warning("Contacts access denied. Grant in System Settings > Privacy & Security > Contacts.")
}

let calendarAccess = (try? await eventStore.requestCalendarAccess()) ?? false
let reminderAccess = (try? await eventStore.requestReminderAccess()) ?? false
if !calendarAccess || !reminderAccess {
    logger.warning("EventKit access denied. Grant in System Settings > Privacy & Security > Calendars / Reminders.")
}

// Create services with production stores
let contactsService = ContactsService(store: contactStore)
let eventKitService = EventKitService(store: eventStore)

// Assemble MCP server
let server = await createServer(
    contactsService: contactsService,
    eventKitService: eventKitService
)

// Start via stdio transport
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
    gracefulShutdownSignals: [.sigterm, .sigint],
    logger: logger
)
try await serviceGroup.run()
