import Foundation
import Logging
import MCP
import ServiceLifecycle

// Configure logging to stderr
LoggingSystem.bootstrap { label in
    var handler = StreamLogHandler.standardError(label: label)
    handler.logLevel = .info
    return handler
}
let logger = Logger(label: "com.tkr-mcp-server")

// Parse --port flag (default 4100)
var port = 4100
for (index, arg) in CommandLine.arguments.enumerated() {
    if arg == "--port", index + 1 < CommandLine.arguments.count,
       let p = Int(CommandLine.arguments[index + 1]) {
        port = p
    }
}

// Create production stores
let contactStore = ContactStore()
let eventStore = EventStore()

// Request permissions — log warnings but don't exit.
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

// Start HTTP MCP server
let app = HTTPServerApp(
    configuration: .init(host: "127.0.0.1", port: port, endpoint: "/mcp"),
    serverFactory: { _, _ in
        await createServer(contactsService: contactsService, eventKitService: eventKitService)
    },
    logger: logger
)

struct MCPHTTPService: Service {
    let app: HTTPServerApp
    func run() async throws {
        try await app.start()
    }
}

let serviceGroup = ServiceGroup(
    services: [MCPHTTPService(app: app)],
    gracefulShutdownSignals: [.sigterm, .sigint],
    logger: logger
)
try await serviceGroup.run()
