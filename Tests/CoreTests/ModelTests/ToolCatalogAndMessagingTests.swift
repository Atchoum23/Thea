// ToolCatalogAndMessagingTests.swift
// Tests for Anthropic tool catalog structure and ChatManager messaging patterns
// Standalone test doubles — no dependency on actual implementations

import Testing
import Foundation

// MARK: - Tool Catalog Test Doubles

/// Mirrors a single tool definition
private struct TestToolDefinition {
    let name: String
    let description: String
    let parameters: [String: Any]

    var hasRequiredFields: Bool {
        !name.isEmpty && !description.isEmpty
    }

    var parameterType: String? {
        parameters["type"] as? String
    }

    var properties: [String: Any]? {
        parameters["properties"] as? [String: Any]
    }

    var requiredParams: [String]? {
        parameters["required"] as? [String]
    }
}

/// Mirrors the tool catalog categories
nonisolated(unsafe) private let toolCatalog: [TestToolDefinition] = [
    TestToolDefinition(
        name: "calendar_list_events",
        description: "List calendar events for a date range",
        parameters: [
            "type": "object",
            "properties": [
                "start_date": ["type": "string", "description": "Start date (ISO 8601)"],
                "end_date": ["type": "string", "description": "End date (ISO 8601)"],
                "calendar_name": ["type": "string", "description": "Optional calendar name filter"]
            ] as [String: Any],
            "required": ["start_date", "end_date"]
        ] as [String: Any]
    ),
    TestToolDefinition(
        name: "calendar_create_event",
        description: "Create a new calendar event",
        parameters: [
            "type": "object",
            "properties": [
                "title": ["type": "string"],
                "start_date": ["type": "string"],
                "end_date": ["type": "string"],
                "location": ["type": "string"],
                "notes": ["type": "string"]
            ] as [String: Any],
            "required": ["title", "start_date", "end_date"]
        ] as [String: Any]
    ),
    TestToolDefinition(
        name: "reminders_list",
        description: "List reminders from a specific list",
        parameters: [
            "type": "object",
            "properties": [
                "list_name": ["type": "string"],
                "show_completed": ["type": "boolean"]
            ] as [String: Any]
        ] as [String: Any]
    ),
    TestToolDefinition(
        name: "reminders_create",
        description: "Create a new reminder",
        parameters: [
            "type": "object",
            "properties": [
                "title": ["type": "string"],
                "due_date": ["type": "string"],
                "priority": ["type": "integer"],
                "list_name": ["type": "string"]
            ] as [String: Any],
            "required": ["title"]
        ] as [String: Any]
    ),
    TestToolDefinition(
        name: "mail_compose",
        description: "Compose and send an email",
        parameters: [
            "type": "object",
            "properties": [
                "to": ["type": "string"],
                "subject": ["type": "string"],
                "body": ["type": "string"],
                "cc": ["type": "string"],
                "bcc": ["type": "string"]
            ] as [String: Any],
            "required": ["to", "subject", "body"]
        ] as [String: Any]
    ),
    TestToolDefinition(
        name: "mail_check_unread",
        description: "Check for unread emails",
        parameters: [
            "type": "object",
            "properties": [
                "mailbox": ["type": "string"],
                "limit": ["type": "integer"]
            ] as [String: Any]
        ] as [String: Any]
    ),
    TestToolDefinition(
        name: "finder_reveal",
        description: "Reveal a file or folder in Finder",
        parameters: [
            "type": "object",
            "properties": [
                "path": ["type": "string"]
            ] as [String: Any],
            "required": ["path"]
        ] as [String: Any]
    ),
    TestToolDefinition(
        name: "finder_search",
        description: "Search for files matching a query",
        parameters: [
            "type": "object",
            "properties": [
                "query": ["type": "string"],
                "directory": ["type": "string"]
            ] as [String: Any],
            "required": ["query"]
        ] as [String: Any]
    ),
    TestToolDefinition(
        name: "terminal_execute",
        description: "Execute a terminal command",
        parameters: [
            "type": "object",
            "properties": [
                "command": ["type": "string"],
                "working_directory": ["type": "string"],
                "timeout": ["type": "integer"]
            ] as [String: Any],
            "required": ["command"]
        ] as [String: Any]
    ),
    TestToolDefinition(
        name: "safari_open_url",
        description: "Open a URL in Safari",
        parameters: [
            "type": "object",
            "properties": [
                "url": ["type": "string"]
            ] as [String: Any],
            "required": ["url"]
        ] as [String: Any]
    ),
    TestToolDefinition(
        name: "safari_get_current_url",
        description: "Get the current URL from Safari",
        parameters: [
            "type": "object",
            "properties": [:] as [String: Any]
        ] as [String: Any]
    ),
    TestToolDefinition(
        name: "music_play",
        description: "Play music in Apple Music",
        parameters: [
            "type": "object",
            "properties": [
                "query": ["type": "string"],
                "shuffle": ["type": "boolean"]
            ] as [String: Any]
        ] as [String: Any]
    ),
    TestToolDefinition(
        name: "shortcuts_run",
        description: "Run a Shortcuts automation",
        parameters: [
            "type": "object",
            "properties": [
                "name": ["type": "string"],
                "input": ["type": "string"]
            ] as [String: Any],
            "required": ["name"]
        ] as [String: Any]
    ),
    TestToolDefinition(
        name: "shortcuts_list",
        description: "List available shortcuts",
        parameters: [
            "type": "object",
            "properties": [:] as [String: Any]
        ] as [String: Any]
    ),
    TestToolDefinition(
        name: "notes_create",
        description: "Create a new note in Apple Notes",
        parameters: [
            "type": "object",
            "properties": [
                "title": ["type": "string"],
                "body": ["type": "string"],
                "folder": ["type": "string"]
            ] as [String: Any],
            "required": ["title", "body"]
        ] as [String: Any]
    ),
    TestToolDefinition(
        name: "notes_search",
        description: "Search for notes by keyword",
        parameters: [
            "type": "object",
            "properties": [
                "query": ["type": "string"],
                "folder": ["type": "string"]
            ] as [String: Any],
            "required": ["query"]
        ] as [String: Any]
    ),
    TestToolDefinition(
        name: "system_notification",
        description: "Show a system notification",
        parameters: [
            "type": "object",
            "properties": [
                "title": ["type": "string"],
                "message": ["type": "string"],
                "sound": ["type": "boolean"]
            ] as [String: Any],
            "required": ["title", "message"]
        ] as [String: Any]
    ),
    TestToolDefinition(
        name: "system_clipboard_get",
        description: "Get the current clipboard contents",
        parameters: [
            "type": "object",
            "properties": [:] as [String: Any]
        ] as [String: Any]
    ),
    TestToolDefinition(
        name: "system_clipboard_set",
        description: "Set the clipboard contents",
        parameters: [
            "type": "object",
            "properties": [
                "content": ["type": "string"]
            ] as [String: Any],
            "required": ["content"]
        ] as [String: Any]
    )
]

// MARK: - Tool Catalog Tests
// Messaging pattern tests split to MessagingPatternsTests.swift

@Suite("Tool Catalog Integrity")
struct ToolCatalogIntegrityTests {
    @Test("Catalog has tools defined")
    func catalogNotEmpty() {
        #expect(!toolCatalog.isEmpty)
        #expect(toolCatalog.count >= 19)
    }

    @Test("All tool names are unique")
    func uniqueNames() {
        let names = toolCatalog.map(\.name)
        #expect(Set(names).count == names.count)
    }

    @Test("All tools have non-empty names")
    func nonEmptyNames() {
        for tool in toolCatalog {
            #expect(!tool.name.isEmpty, "Tool should have a name")
        }
    }

    @Test("All tools have descriptions")
    func allHaveDescriptions() {
        for tool in toolCatalog {
            #expect(!tool.description.isEmpty, "\(tool.name) missing description")
        }
    }

    @Test("All tools have hasRequiredFields")
    func allValid() {
        for tool in toolCatalog {
            #expect(tool.hasRequiredFields, "\(tool.name) missing required fields")
        }
    }

    @Test("All parameter schemas are type 'object'")
    func allTypeObject() {
        for tool in toolCatalog {
            #expect(tool.parameterType == "object", "\(tool.name) parameters should be type 'object'")
        }
    }

    @Test("All tools have properties dict")
    func allHaveProperties() {
        for tool in toolCatalog {
            #expect(tool.properties != nil, "\(tool.name) missing properties")
        }
    }

    @Test("Tool names use snake_case")
    func snakeCaseNames() {
        for tool in toolCatalog {
            #expect(!tool.name.contains(" "), "\(tool.name) should not contain spaces")
            #expect(tool.name == tool.name.lowercased(), "\(tool.name) should be lowercase")
        }
    }
}

@Suite("Tool Categories")
struct ToolCategoryTests {
    @Test("Calendar tools exist")
    func calendarTools() {
        let calendar = toolCatalog.filter { $0.name.hasPrefix("calendar_") }
        #expect(calendar.count == 2)
    }

    @Test("Reminders tools exist")
    func remindersTools() {
        let reminders = toolCatalog.filter { $0.name.hasPrefix("reminders_") }
        #expect(reminders.count == 2)
    }

    @Test("Mail tools exist")
    func mailTools() {
        let mail = toolCatalog.filter { $0.name.hasPrefix("mail_") }
        #expect(mail.count == 2)
    }

    @Test("Finder tools exist")
    func finderTools() {
        let finder = toolCatalog.filter { $0.name.hasPrefix("finder_") }
        #expect(finder.count == 2)
    }

    @Test("Terminal tool exists")
    func terminalTool() {
        let terminal = toolCatalog.filter { $0.name.hasPrefix("terminal_") }
        #expect(terminal.count == 1)
    }

    @Test("Safari tools exist")
    func safariTools() {
        let safari = toolCatalog.filter { $0.name.hasPrefix("safari_") }
        #expect(safari.count == 2)
    }

    @Test("System tools exist")
    func systemTools() {
        let system = toolCatalog.filter { $0.name.hasPrefix("system_") }
        #expect(system.count == 3)
    }
}

@Suite("Tool Required Parameters")
struct ToolRequiredParamsTests {
    @Test("calendar_list_events requires start_date and end_date")
    func calendarListRequired() {
        let tool = toolCatalog.first { $0.name == "calendar_list_events" }!
        let required = tool.requiredParams ?? []
        #expect(required.contains("start_date"))
        #expect(required.contains("end_date"))
    }

    @Test("mail_compose requires to, subject, body")
    func mailComposeRequired() {
        let tool = toolCatalog.first { $0.name == "mail_compose" }!
        let required = tool.requiredParams ?? []
        #expect(required.contains("to"))
        #expect(required.contains("subject"))
        #expect(required.contains("body"))
    }

    @Test("terminal_execute requires command")
    func terminalRequired() {
        let tool = toolCatalog.first { $0.name == "terminal_execute" }!
        let required = tool.requiredParams ?? []
        #expect(required.contains("command"))
    }

    @Test("safari_open_url requires url")
    func safariRequired() {
        let tool = toolCatalog.first { $0.name == "safari_open_url" }!
        let required = tool.requiredParams ?? []
        #expect(required.contains("url"))
    }

    @Test("No-parameter tools have empty properties")
    func noParamTools() {
        let paramless = ["safari_get_current_url", "shortcuts_list", "system_clipboard_get"]
        for name in paramless {
            let tool = toolCatalog.first { $0.name == name }!
            let props = tool.properties ?? [:]
            #expect(props.isEmpty, "\(name) should have no properties")
        }
    }
}

// Messaging pattern tests moved to MessagingPatternsTests.swift
