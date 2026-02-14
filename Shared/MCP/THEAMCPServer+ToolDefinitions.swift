// THEAMCPServer+ToolDefinitions.swift
// Thea V2
//
// Tool definitions for the MCP server
// Extracted from THEAMCPServer.swift

import Foundation

#if os(macOS)

// MARK: - Tool Definitions

extension THEAMCPServer {
    func getAvailableTools() -> [THEAMCPToolDefinition] {
        systemTools() + appleIntegrationTools() + automationTools()
    }

    private func systemTools() -> [THEAMCPToolDefinition] {
        [
            THEAMCPToolDefinition(
                name: "thea_execute_command",
                description: "Execute a shell command on the system",
                inputSchema: THEAMCPToolInputSchema(
                    properties: [
                        "command": THEAMCPSchemaProperty(type: "string", description: "The command to execute")
                    ],
                    required: ["command"]
                )
            ),
            THEAMCPToolDefinition(
                name: "thea_read_file",
                description: "Read the contents of a file",
                inputSchema: THEAMCPToolInputSchema(
                    properties: [
                        "path": THEAMCPSchemaProperty(type: "string", description: "Path to the file")
                    ],
                    required: ["path"]
                )
            ),
            THEAMCPToolDefinition(
                name: "thea_write_file",
                description: "Write content to a file",
                inputSchema: THEAMCPToolInputSchema(
                    properties: [
                        "path": THEAMCPSchemaProperty(type: "string", description: "Path to the file"),
                        "content": THEAMCPSchemaProperty(type: "string", description: "Content to write")
                    ],
                    required: ["path", "content"]
                )
            ),
            THEAMCPToolDefinition(
                name: "thea_list_directory",
                description: "List contents of a directory",
                inputSchema: THEAMCPToolInputSchema(
                    properties: [
                        "path": THEAMCPSchemaProperty(type: "string", description: "Path to the directory")
                    ],
                    required: ["path"]
                )
            )
        ]
    }

    private func appleIntegrationTools() -> [THEAMCPToolDefinition] {
        contactAndReminderTools() + notesAndLocationTools()
    }

    private func contactAndReminderTools() -> [THEAMCPToolDefinition] {
        [
            THEAMCPToolDefinition(
                name: "thea_search_contacts",
                description: "Search for contacts by name, email, or phone",
                inputSchema: THEAMCPToolInputSchema(
                    properties: [
                        "query": THEAMCPSchemaProperty(type: "string", description: "Search query")
                    ],
                    required: ["query"]
                )
            ),
            THEAMCPToolDefinition(
                name: "thea_get_reminders",
                description: "Get reminders, optionally filtered by list or completion status",
                inputSchema: THEAMCPToolInputSchema(
                    properties: [
                        "list": THEAMCPSchemaProperty(type: "string", description: "Filter by list name"),
                        "completed": THEAMCPSchemaProperty(type: "boolean", description: "Filter by completion status")
                    ]
                )
            ),
            THEAMCPToolDefinition(
                name: "thea_create_reminder",
                description: "Create a new reminder",
                inputSchema: THEAMCPToolInputSchema(
                    properties: [
                        "title": THEAMCPSchemaProperty(type: "string", description: "Reminder title"),
                        "notes": THEAMCPSchemaProperty(type: "string", description: "Additional notes"),
                        "list": THEAMCPSchemaProperty(type: "string", description: "List name"),
                        "due_date": THEAMCPSchemaProperty(type: "string", description: "Due date (ISO 8601)")
                    ],
                    required: ["title"]
                )
            )
        ]
    }

    private func notesAndLocationTools() -> [THEAMCPToolDefinition] {
        [
            THEAMCPToolDefinition(
                name: "thea_search_notes",
                description: "Search notes by content",
                inputSchema: THEAMCPToolInputSchema(
                    properties: [
                        "query": THEAMCPSchemaProperty(type: "string", description: "Search query")
                    ],
                    required: ["query"]
                )
            ),
            THEAMCPToolDefinition(
                name: "thea_create_note",
                description: "Create a new note",
                inputSchema: THEAMCPToolInputSchema(
                    properties: [
                        "title": THEAMCPSchemaProperty(type: "string", description: "Note title"),
                        "body": THEAMCPSchemaProperty(type: "string", description: "Note content"),
                        "folder": THEAMCPSchemaProperty(type: "string", description: "Folder name")
                    ],
                    required: ["title", "body"]
                )
            ),
            THEAMCPToolDefinition(
                name: "thea_search_location",
                description: "Search for a location or place",
                inputSchema: THEAMCPToolInputSchema(
                    properties: [
                        "query": THEAMCPSchemaProperty(type: "string", description: "Location search query")
                    ],
                    required: ["query"]
                )
            ),
            THEAMCPToolDefinition(
                name: "thea_get_directions",
                description: "Get directions between two locations",
                inputSchema: THEAMCPToolInputSchema(
                    properties: [
                        "from": THEAMCPSchemaProperty(type: "string", description: "Starting location"),
                        "to": THEAMCPSchemaProperty(type: "string", description: "Destination"),
                        "mode": THEAMCPSchemaProperty(
                            type: "string",
                            description: "Transport mode",
                            enum: ["driving", "walking", "transit"]
                        )
                    ],
                    required: ["from", "to"]
                )
            )
        ]
    }

    private func automationTools() -> [THEAMCPToolDefinition] {
        [
            THEAMCPToolDefinition(
                name: "thea_run_shortcut",
                description: "Run a Shortcuts automation",
                inputSchema: THEAMCPToolInputSchema(
                    properties: [
                        "name": THEAMCPSchemaProperty(type: "string", description: "Shortcut name"),
                        "input": THEAMCPSchemaProperty(type: "string", description: "Input to pass to shortcut")
                    ],
                    required: ["name"]
                )
            ),
            THEAMCPToolDefinition(
                name: "thea_speak",
                description: "Speak text using text-to-speech",
                inputSchema: THEAMCPToolInputSchema(
                    properties: [
                        "text": THEAMCPSchemaProperty(type: "string", description: "Text to speak")
                    ],
                    required: ["text"]
                )
            )
        ]
    }
}

#endif
