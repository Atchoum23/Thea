import Foundation

// MARK: - Anthropic Tool Catalog
// Builds a dynamic tool catalog from Thea's active integration modules
// Used with Claude's Tool Search for efficient tool discovery without context consumption

// periphery:ignore - Reserved: AnthropicToolCatalog type reserved for future feature activation
final class AnthropicToolCatalog: @unchecked Sendable {
    static let shared = AnthropicToolCatalog()

    // MARK: - Dynamic Tool Registry (O3)
    // Thread-safe storage for tools registered at runtime from MCP servers.

    private let lock = NSLock()
    private var dynamicTools: [ToolDefinition] = []
    // Handler closure: [String: Any] → MCPToolResult
    private var dynamicHandlers: [String: @Sendable ([String: Any]) async throws -> MCPToolResult] = [:]

    private init() {}

    /// Register a tool dynamically (e.g. from a connected MCP server).
    func registerDynamicTool(
        name: String,
        description: String,
        handler: @escaping @Sendable ([String: Any]) async throws -> MCPToolResult
    ) {
        let tool = ToolDefinition(
            name: name,
            description: description,
            parameters: ["type": "object", "properties": [:] as [String: Any]]
        )
        lock.withLock {
            dynamicTools.removeAll { $0.name == name }
            dynamicTools.append(tool)
            dynamicHandlers[name] = handler
        }
    }

    /// Remove a dynamically-registered tool.
    func unregisterDynamicTool(name: String) {
        lock.withLock {
            dynamicTools.removeAll { $0.name == name }
            dynamicHandlers.removeValue(forKey: name)
        }
    }

    /// Execute a dynamic tool by name.
    func executeDynamicTool(name: String, input: [String: Any]) async throws -> MCPToolResult {
        let handler = lock.withLock { dynamicHandlers[name] }
        guard let handler else {
            return MCPToolResult(
                content: [MCPContent(type: "text", text: "Unknown dynamic tool: \(name)")],
                isError: true
            )
        }
        return try await handler(input)
    }

    /// Returns true if a tool is dynamically registered.
    func isDynamicTool(_ name: String) -> Bool {
        lock.withLock { dynamicHandlers[name] != nil }
    }

    /// Build tool definitions from all active Thea integrations
    nonisolated func buildToolCatalog() -> [ToolDefinition] {
        var tools: [ToolDefinition] = []

        // MARK: - Calendar Tools
        tools.append(ToolDefinition(
            name: "calendar_list_events",
            description: "List upcoming calendar events within a date range",
            parameters: [
                "type": "object",
                "properties": [
                    "start_date": ["type": "string", "description": "ISO 8601 start date"],
                    "end_date": ["type": "string", "description": "ISO 8601 end date"],
                    "calendar_name": ["type": "string", "description": "Optional calendar name filter"]
                ],
                "required": ["start_date", "end_date"]
            ]
        ))
        tools.append(ToolDefinition(
            name: "calendar_create_event",
            description: "Create a new calendar event",
            parameters: [
                "type": "object",
                "properties": [
                    "title": ["type": "string"],
                    "start_date": ["type": "string", "description": "ISO 8601"],
                    "end_date": ["type": "string", "description": "ISO 8601"],
                    "location": ["type": "string"],
                    "notes": ["type": "string"]
                ],
                "required": ["title", "start_date", "end_date"]
            ]
        ))

        // MARK: - Reminders Tools
        tools.append(ToolDefinition(
            name: "reminders_list",
            description: "List reminders from a specific list or all lists",
            parameters: [
                "type": "object",
                "properties": [
                    "list_name": ["type": "string"],
                    "include_completed": ["type": "boolean"]
                ]
            ]
        ))
        tools.append(ToolDefinition(
            name: "reminders_create",
            description: "Create a new reminder",
            parameters: [
                "type": "object",
                "properties": [
                    "title": ["type": "string"],
                    "due_date": ["type": "string", "description": "ISO 8601"],
                    "list_name": ["type": "string"],
                    "priority": ["type": "integer", "description": "0-9, 0 = none"]
                ],
                "required": ["title"]
            ]
        ))

        // MARK: - Mail Tools
        tools.append(ToolDefinition(
            name: "mail_compose",
            description: "Compose and send an email",
            parameters: [
                "type": "object",
                "properties": [
                    "to": ["type": "string"],
                    "subject": ["type": "string"],
                    "body": ["type": "string"]
                ],
                "required": ["to", "subject", "body"]
            ]
        ))
        tools.append(ToolDefinition(
            name: "mail_check_unread",
            description: "Check the number of unread emails",
            parameters: ["type": "object", "properties": [:] as [String: Any]]
        ))

        // MARK: - Finder Tools
        tools.append(ToolDefinition(
            name: "finder_reveal",
            description: "Reveal a file or folder in Finder",
            parameters: [
                "type": "object",
                "properties": ["path": ["type": "string"]],
                "required": ["path"]
            ]
        ))
        tools.append(ToolDefinition(
            name: "finder_search",
            description: "Search for files by name",
            parameters: [
                "type": "object",
                "properties": [
                    "query": ["type": "string"],
                    "directory": ["type": "string"]
                ],
                "required": ["query"]
            ]
        ))

        // MARK: - Terminal Tools
        tools.append(ToolDefinition(
            name: "terminal_execute",
            description: "Execute a shell command in Terminal",
            parameters: [
                "type": "object",
                "properties": [
                    "command": ["type": "string"],
                    "working_directory": ["type": "string"]
                ],
                "required": ["command"]
            ]
        ))

        // MARK: - Safari Tools
        tools.append(ToolDefinition(
            name: "safari_open_url",
            description: "Open a URL in Safari",
            parameters: [
                "type": "object",
                "properties": ["url": ["type": "string"]],
                "required": ["url"]
            ]
        ))
        tools.append(ToolDefinition(
            name: "safari_get_current_url",
            description: "Get the URL of the active Safari tab",
            parameters: ["type": "object", "properties": [:] as [String: Any]]
        ))

        // MARK: - Music Tools
        tools.append(ToolDefinition(
            name: "music_play",
            description: "Play, pause, or skip music",
            parameters: [
                "type": "object",
                "properties": [
                    "action": ["type": "string", "enum": ["play", "pause", "next", "previous"]],
                    "search": ["type": "string", "description": "Search and play specific song/artist"]
                ],
                "required": ["action"]
            ]
        ))

        // MARK: - Shortcuts Tools
        tools.append(ToolDefinition(
            name: "shortcuts_run",
            description: "Run an Apple Shortcut by name",
            parameters: [
                "type": "object",
                "properties": [
                    "shortcut_name": ["type": "string"],
                    "input": ["type": "string"]
                ],
                "required": ["shortcut_name"]
            ]
        ))
        tools.append(ToolDefinition(
            name: "shortcuts_list",
            description: "List available Apple Shortcuts",
            parameters: ["type": "object", "properties": [:] as [String: Any]]
        ))

        // MARK: - Notes Tools
        tools.append(ToolDefinition(
            name: "notes_create",
            description: "Create a new note in Apple Notes",
            parameters: [
                "type": "object",
                "properties": [
                    "title": ["type": "string"],
                    "body": ["type": "string"],
                    "folder": ["type": "string"]
                ],
                "required": ["title", "body"]
            ]
        ))
        tools.append(ToolDefinition(
            name: "notes_search",
            description: "Search notes by content",
            parameters: [
                "type": "object",
                "properties": ["query": ["type": "string"]],
                "required": ["query"]
            ]
        ))

        // MARK: - System Tools
        tools.append(ToolDefinition(
            name: "system_notification",
            description: "Show a system notification",
            parameters: [
                "type": "object",
                "properties": [
                    "title": ["type": "string"],
                    "body": ["type": "string"]
                ],
                "required": ["title", "body"]
            ]
        ))
        tools.append(ToolDefinition(
            name: "system_clipboard_get",
            description: "Get the current clipboard contents",
            parameters: ["type": "object", "properties": [:] as [String: Any]]
        ))
        tools.append(ToolDefinition(
            name: "system_clipboard_set",
            description: "Set the clipboard contents",
            parameters: [
                "type": "object",
                "properties": ["text": ["type": "string"]],
                "required": ["text"]
            ]
        ))

        // MARK: - L3: Computer Use (macOS only — requires explicit user permission)
        #if os(macOS)
        if UserDefaults.standard.bool(forKey: "thea.computerUseEnabled") {
            tools.append(ToolDefinition(
                name: "computer_use",
                description: "Interact with the macOS GUI: take screenshots, click, type text, scroll, or press keyboard keys. Requires Computer Use permission in Thea settings.",
                parameters: [
                    "type": "object",
                    "properties": [
                        "action": [
                            "type": "string",
                            "enum": ["screenshot", "click", "type", "scroll", "key"],
                            "description": "The GUI action to perform"
                        ],
                        "coordinate": [
                            "type": "array",
                            "items": ["type": "integer"],
                            "description": "[x, y] screen coordinates for click/scroll actions"
                        ],
                        "text": [
                            "type": "string",
                            "description": "Text to type (for 'type' action)"
                        ],
                        "key": [
                            "type": "string",
                            "description": "Key combination to press (e.g. 'cmd+c', 'return', 'escape')"
                        ],
                        "delta": [
                            "type": "integer",
                            "description": "Scroll amount in lines (for 'scroll' action, negative = up)"
                        ]
                    ],
                    "required": ["action"]
                ]
            ))
        }
        #endif

        // Append dynamically registered tools (from MCP servers, etc.)
        let dynamic = lock.withLock { dynamicTools }
        tools.append(contentsOf: dynamic)

        return tools
    }

    /// Build a ToolSearchConfig with the full catalog
    nonisolated func buildToolSearchConfig(maxResults: Int = 20) -> ToolSearchConfig {
        ToolSearchConfig(tools: buildToolCatalog(), maxResults: maxResults)
    }
}
