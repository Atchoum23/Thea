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

// MARK: - Messaging Test Doubles

/// Mirrors @agent command parsing from ChatManager
private func parseAgentCommand(_ text: String) -> (isAgentCommand: Bool, taskDescription: String?) {
    guard text.hasPrefix("@agent ") else {
        return (false, nil)
    }
    let task = String(text.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
    return (true, task.isEmpty ? nil : task)
}

/// Mirrors device origin annotation for cross-device messages
private func annotateForCrossDevice(
    content: String,
    senderDevice: String?,
    currentDevice: String
) -> String {
    guard let sender = senderDevice, sender != currentDevice else {
        return content
    }
    return "[Sent from \(sender)] \(content)"
}

/// Mirrors message role-based system prompt injection
private struct TestSystemPromptBuilder {
    let deviceName: String
    let capabilities: [String]

    func buildDeviceContext() -> String {
        var parts: [String] = []
        parts.append("You are running on \(deviceName).")
        if !capabilities.isEmpty {
            parts.append("Capabilities: \(capabilities.joined(separator: ", ")).")
        }
        return parts.joined(separator: " ")
    }
}

/// Mirrors file size validation for uploads
private let maxFileSizeBytes: Int = 500 * 1024 * 1024 // 500 MB

private func validateFileSize(_ bytes: Int) -> Bool {
    bytes <= maxFileSizeBytes
}

// MARK: - Tool Catalog Tests

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

// MARK: - Messaging Pattern Tests

@Suite("@agent Command Parsing")
struct AgentCommandParsingTests {
    @Test("Valid @agent command")
    func validCommand() {
        let result = parseAgentCommand("@agent research Swift concurrency")
        #expect(result.isAgentCommand)
        #expect(result.taskDescription == "research Swift concurrency")
    }

    @Test("Non-command text")
    func nonCommand() {
        let result = parseAgentCommand("Hello world")
        #expect(!result.isAgentCommand)
        #expect(result.taskDescription == nil)
    }

    @Test("@agent prefix only (no task)")
    func prefixOnly() {
        let result = parseAgentCommand("@agent ")
        #expect(result.isAgentCommand)
        #expect(result.taskDescription == nil)
    }

    @Test("@agent with extra spaces")
    func extraSpaces() {
        let result = parseAgentCommand("@agent   do something   ")
        #expect(result.isAgentCommand)
        #expect(result.taskDescription == "do something")
    }

    @Test("@agent in middle is not a command")
    func middleNotCommand() {
        let result = parseAgentCommand("Please @agent do this")
        #expect(!result.isAgentCommand)
    }

    @Test("Case sensitive — @Agent not matched")
    func caseSensitive() {
        let result = parseAgentCommand("@Agent do this")
        #expect(!result.isAgentCommand)
    }

    @Test("@agent without space is not matched")
    func noSpace() {
        let result = parseAgentCommand("@agentdo this")
        #expect(!result.isAgentCommand)
    }
}

@Suite("Cross-Device Message Annotation")
struct CrossDeviceAnnotationTests {
    @Test("Same device — no annotation")
    func sameDevice() {
        let result = annotateForCrossDevice(content: "Hello", senderDevice: "msm3u", currentDevice: "msm3u")
        #expect(result == "Hello")
    }

    @Test("Different device — annotated")
    func differentDevice() {
        let result = annotateForCrossDevice(content: "Hello", senderDevice: "mbam2", currentDevice: "msm3u")
        #expect(result == "[Sent from mbam2] Hello")
    }

    @Test("No sender device — no annotation")
    func noSender() {
        let result = annotateForCrossDevice(content: "Hello", senderDevice: nil, currentDevice: "msm3u")
        #expect(result == "Hello")
    }

    @Test("Annotation preserves original content")
    func preservesContent() {
        let content = "Multi\nline\nmessage"
        let result = annotateForCrossDevice(content: content, senderDevice: "mbam2", currentDevice: "msm3u")
        #expect(result.contains(content))
    }
}

@Suite("Device Context System Prompt")
struct DeviceContextTests {
    @Test("Basic device context")
    func basicContext() {
        let builder = TestSystemPromptBuilder(deviceName: "Mac Studio M3 Ultra", capabilities: ["ML inference", "on-device models"])
        let prompt = builder.buildDeviceContext()
        #expect(prompt.contains("Mac Studio M3 Ultra"))
        #expect(prompt.contains("ML inference"))
    }

    @Test("No capabilities")
    func noCapabilities() {
        let builder = TestSystemPromptBuilder(deviceName: "MacBook Air M2", capabilities: [])
        let prompt = builder.buildDeviceContext()
        #expect(prompt.contains("MacBook Air M2"))
        #expect(!prompt.contains("Capabilities"))
    }
}

@Suite("File Size Validation")
struct FileSizeValidationTests {
    @Test("Under 500MB is valid")
    func underLimit() {
        #expect(validateFileSize(100 * 1024 * 1024))
    }

    @Test("Exactly 500MB is valid")
    func exactLimit() {
        #expect(validateFileSize(500 * 1024 * 1024))
    }

    @Test("Over 500MB is invalid")
    func overLimit() {
        #expect(!validateFileSize(500 * 1024 * 1024 + 1))
    }

    @Test("Zero bytes is valid")
    func zeroBytes() {
        #expect(validateFileSize(0))
    }

    @Test("1 byte is valid")
    func oneByte() {
        #expect(validateFileSize(1))
    }
}
