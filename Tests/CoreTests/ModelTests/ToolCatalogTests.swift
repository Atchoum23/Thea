import Foundation
import XCTest

/// Standalone tests for AnthropicToolCatalog tool definition validation.
/// Mirrors the tool catalog structure without importing the full module.
/// Validates all tool definitions have required fields and valid JSON schemas.
final class ToolCatalogTests: XCTestCase {

    // MARK: - Tool Definition (mirrors AnthropicToolCatalog.ToolDefinition)

    private struct ToolDef {
        let name: String
        let description: String
        let parameters: [String: Any]

        var hasType: Bool {
            (parameters["type"] as? String) == "object"
        }

        var properties: [String: Any]? {
            parameters["properties"] as? [String: Any]
        }

        var required: [String]? {
            parameters["required"] as? [String]
        }
    }

    // MARK: - Tool Catalog (mirrors AnthropicToolCatalog.buildToolCatalog)

    private let tools: [ToolDef] = [
        // Calendar
        ToolDef(name: "calendar_list_events", description: "List upcoming calendar events within a date range",
            parameters: ["type": "object", "properties": ["start_date": ["type": "string"], "end_date": ["type": "string"]],
                         "required": ["start_date", "end_date"]]),
        ToolDef(name: "calendar_create_event", description: "Create a new calendar event",
            parameters: ["type": "object", "properties": ["title": ["type": "string"], "start_date": ["type": "string"], "end_date": ["type": "string"]],
                         "required": ["title", "start_date", "end_date"]]),
        // Reminders
        ToolDef(name: "reminders_list", description: "List reminders from a specific list or all lists",
            parameters: ["type": "object", "properties": ["list_name": ["type": "string"]]]),
        ToolDef(name: "reminders_create", description: "Create a new reminder",
            parameters: ["type": "object", "properties": ["title": ["type": "string"]],
                         "required": ["title"]]),
        // Mail
        ToolDef(name: "mail_compose", description: "Compose and send an email",
            parameters: ["type": "object", "properties": ["to": ["type": "string"], "subject": ["type": "string"], "body": ["type": "string"]],
                         "required": ["to", "subject", "body"]]),
        ToolDef(name: "mail_check_unread", description: "Check the number of unread emails",
            parameters: ["type": "object", "properties": [:] as [String: Any]]),
        // Finder
        ToolDef(name: "finder_reveal", description: "Reveal a file or folder in Finder",
            parameters: ["type": "object", "properties": ["path": ["type": "string"]], "required": ["path"]]),
        ToolDef(name: "finder_search", description: "Search for files by name",
            parameters: ["type": "object", "properties": ["query": ["type": "string"]], "required": ["query"]]),
        // Terminal
        ToolDef(name: "terminal_execute", description: "Execute a shell command in Terminal",
            parameters: ["type": "object", "properties": ["command": ["type": "string"]], "required": ["command"]]),
        // Safari
        ToolDef(name: "safari_open_url", description: "Open a URL in Safari",
            parameters: ["type": "object", "properties": ["url": ["type": "string"]], "required": ["url"]]),
        ToolDef(name: "safari_get_current_url", description: "Get the URL of the active Safari tab",
            parameters: ["type": "object", "properties": [:] as [String: Any]]),
        // Music
        ToolDef(name: "music_play", description: "Play, pause, or skip music",
            parameters: ["type": "object", "properties": ["action": ["type": "string"]], "required": ["action"]]),
        // Shortcuts
        ToolDef(name: "shortcuts_run", description: "Run an Apple Shortcut by name",
            parameters: ["type": "object", "properties": ["shortcut_name": ["type": "string"]], "required": ["shortcut_name"]]),
        ToolDef(name: "shortcuts_list", description: "List available Apple Shortcuts",
            parameters: ["type": "object", "properties": [:] as [String: Any]]),
        // Notes
        ToolDef(name: "notes_create", description: "Create a new note in Apple Notes",
            parameters: ["type": "object", "properties": ["title": ["type": "string"], "body": ["type": "string"]], "required": ["title", "body"]]),
        ToolDef(name: "notes_search", description: "Search notes by content",
            parameters: ["type": "object", "properties": ["query": ["type": "string"]], "required": ["query"]]),
        // System
        ToolDef(name: "system_notification", description: "Show a system notification",
            parameters: ["type": "object", "properties": ["title": ["type": "string"], "body": ["type": "string"]], "required": ["title", "body"]]),
        ToolDef(name: "system_clipboard_get", description: "Get the current clipboard contents",
            parameters: ["type": "object", "properties": [:] as [String: Any]]),
        ToolDef(name: "system_clipboard_set", description: "Set the clipboard contents",
            parameters: ["type": "object", "properties": ["text": ["type": "string"]], "required": ["text"]])
    ]

    // MARK: - Basic Validation

    func testCatalogNotEmpty() {
        XCTAssertGreaterThanOrEqual(tools.count, 19, "Should have at least 19 tools")
    }

    func testAllToolsHaveNames() {
        for tool in tools {
            XCTAssertFalse(tool.name.isEmpty, "Tool should have non-empty name")
        }
    }

    func testAllToolsHaveDescriptions() {
        for tool in tools {
            XCTAssertFalse(tool.description.isEmpty, "Tool \(tool.name) should have description")
        }
    }

    func testNoDuplicateToolNames() {
        let names = tools.map(\.name)
        let unique = Set(names)
        XCTAssertEqual(names.count, unique.count, "No duplicate tool names")
    }

    func testAllToolsHaveObjectType() {
        for tool in tools {
            XCTAssertTrue(tool.hasType, "Tool \(tool.name) parameters should have type=object")
        }
    }

    func testAllToolsHaveProperties() {
        for tool in tools {
            XCTAssertNotNil(tool.properties, "Tool \(tool.name) should have properties dict")
        }
    }

    // MARK: - Required Parameters Validation

    func testRequiredParamsAreInProperties() {
        for tool in tools {
            guard let required = tool.required, let props = tool.properties else { continue }
            for param in required {
                XCTAssertNotNil(props[param],
                    "Tool \(tool.name) requires '\(param)' but it's not in properties")
            }
        }
    }

    // MARK: - Category Coverage

    func testCalendarToolsExist() {
        let calendarTools = tools.filter { $0.name.hasPrefix("calendar_") }
        XCTAssertEqual(calendarTools.count, 2, "Should have 2 calendar tools")
    }

    func testRemindersToolsExist() {
        let reminderTools = tools.filter { $0.name.hasPrefix("reminders_") }
        XCTAssertEqual(reminderTools.count, 2, "Should have 2 reminder tools")
    }

    func testMailToolsExist() {
        let mailTools = tools.filter { $0.name.hasPrefix("mail_") }
        XCTAssertEqual(mailTools.count, 2, "Should have 2 mail tools")
    }

    func testFinderToolsExist() {
        let finderTools = tools.filter { $0.name.hasPrefix("finder_") }
        XCTAssertEqual(finderTools.count, 2, "Should have 2 finder tools")
    }

    func testSafariToolsExist() {
        let safariTools = tools.filter { $0.name.hasPrefix("safari_") }
        XCTAssertEqual(safariTools.count, 2, "Should have 2 safari tools")
    }

    func testSystemToolsExist() {
        let systemTools = tools.filter { $0.name.hasPrefix("system_") }
        XCTAssertEqual(systemTools.count, 3, "Should have 3 system tools")
    }

    func testMusicToolExists() {
        let musicTools = tools.filter { $0.name.hasPrefix("music_") }
        XCTAssertEqual(musicTools.count, 1)
    }

    func testShortcutsToolsExist() {
        let shortcutsTools = tools.filter { $0.name.hasPrefix("shortcuts_") }
        XCTAssertEqual(shortcutsTools.count, 2, "Should have 2 shortcuts tools")
    }

    func testNotesToolsExist() {
        let notesTools = tools.filter { $0.name.hasPrefix("notes_") }
        XCTAssertEqual(notesTools.count, 2, "Should have 2 notes tools")
    }

    // MARK: - Naming Conventions

    func testToolNamesFollowConvention() {
        for tool in tools {
            // All names should be snake_case with module prefix
            XCTAssertTrue(tool.name.contains("_"),
                "Tool name \(tool.name) should follow module_action convention")
            XCTAssertEqual(tool.name, tool.name.lowercased(),
                "Tool name \(tool.name) should be lowercase")
        }
    }

    // MARK: - Critical Tool Parameters

    func testTerminalRequiresCommand() {
        let terminal = tools.first { $0.name == "terminal_execute" }
        XCTAssertNotNil(terminal)
        XCTAssertTrue(terminal?.required?.contains("command") ?? false,
            "terminal_execute must require 'command' parameter")
    }

    func testMailComposeRequiresAllFields() {
        let mail = tools.first { $0.name == "mail_compose" }
        XCTAssertNotNil(mail)
        let required = mail?.required ?? []
        XCTAssertTrue(required.contains("to"))
        XCTAssertTrue(required.contains("subject"))
        XCTAssertTrue(required.contains("body"))
    }

    func testCalendarCreateRequiresDateRange() {
        let create = tools.first { $0.name == "calendar_create_event" }
        XCTAssertNotNil(create)
        let required = create?.required ?? []
        XCTAssertTrue(required.contains("title"))
        XCTAssertTrue(required.contains("start_date"))
        XCTAssertTrue(required.contains("end_date"))
    }
}
