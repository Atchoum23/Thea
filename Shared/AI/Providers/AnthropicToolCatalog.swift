import Foundation

// MARK: - Anthropic Tool Catalog
// Builds a dynamic tool catalog from Thea's active integration modules
// Used with Claude's Tool Search for efficient tool discovery without context consumption

final class AnthropicToolCatalog: Sendable {
    static let shared = AnthropicToolCatalog()

    private init() {}

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

        return tools
    }

    /// Build a ToolSearchConfig with the full catalog
    nonisolated func buildToolSearchConfig(maxResults: Int = 20) -> ToolSearchConfig {
        ToolSearchConfig(tools: buildToolCatalog(), maxResults: maxResults)
    }
}

// MARK: - Tool Result Cache

/// Caches tool call results to avoid redundant calls for identical inputs.
/// Entries expire after a configurable TTL (default 5 minutes).
actor AnthropicToolResultCache {
    static let shared = AnthropicToolResultCache()

    private struct CacheEntry: Sendable {
        let result: String
        let timestamp: Date
    }

    /// Cache keyed by tool name + serialized input hash
    private var cache: [String: CacheEntry] = [:]

    /// Time-to-live for cache entries (seconds)
    private let ttl: TimeInterval = 300 // 5 minutes

    /// Maximum cache entries before eviction
    private let maxEntries = 200

    /// Get a cached result for a tool call, or nil if not cached/expired
    func get(toolName: String, inputHash: String) -> String? {
        let key = "\(toolName):\(inputHash)"
        guard let entry = cache[key] else { return nil }
        if Date().timeIntervalSince(entry.timestamp) > ttl {
            cache.removeValue(forKey: key)
            return nil
        }
        return entry.result
    }

    /// Store a tool call result
    func set(toolName: String, inputHash: String, result: String) {
        let key = "\(toolName):\(inputHash)"
        cache[key] = CacheEntry(result: result, timestamp: Date())

        // Evict oldest entries if over limit
        if cache.count > maxEntries {
            let sorted = cache.sorted { $0.value.timestamp < $1.value.timestamp }
            let toRemove = cache.count - maxEntries
            for (key, _) in sorted.prefix(toRemove) {
                cache.removeValue(forKey: key)
            }
        }
    }

    /// Clear all cached results
    func clear() {
        cache.removeAll()
    }

    /// Number of cached entries
    var count: Int { cache.count }

    /// Build a hash for tool inputs (deterministic for same inputs)
    static func hashInputs(_ inputs: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: inputs, options: .sortedKeys) else {
            return UUID().uuidString
        }
        // Simple DJB2 hash for speed
        var hash: UInt64 = 5381
        for byte in data {
            hash = ((hash &<< 5) &+ hash) &+ UInt64(byte)
        }
        return String(hash, radix: 36)
    }
}
