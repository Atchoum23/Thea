// THEAMCPServer.swift
// Thea V2
//
// MCP Server implementation that exposes Thea's capabilities
// Allows Claude Desktop and other MCP clients to use Thea's tools

import Foundation
import OSLog

#if os(macOS)

// MARK: - MCP Protocol Types (THEA-prefixed to avoid conflicts)

/// JSON-RPC 2.0 Request
public struct THEAMCPRequest: Codable, Sendable {
    public let jsonrpc: String
    public let id: THEAJSONRPCId
    public let method: String
    public let params: THEAMCPParams?

    public init(id: THEAJSONRPCId, method: String, params: THEAMCPParams? = nil) {
        self.jsonrpc = "2.0"
        self.id = id
        self.method = method
        self.params = params
    }
}

/// JSON-RPC 2.0 Response
public struct THEAMCPResponse: Codable, Sendable {
    public let jsonrpc: String
    public let id: THEAJSONRPCId
    public let result: THEAMCPResult?
    public let error: THEAMCPError?

    public init(id: THEAJSONRPCId, result: THEAMCPResult) {
        self.jsonrpc = "2.0"
        self.id = id
        self.result = result
        self.error = nil
    }

    public init(id: THEAJSONRPCId, error: THEAMCPError) {
        self.jsonrpc = "2.0"
        self.id = id
        self.result = nil
        self.error = error
    }
}

/// JSON-RPC ID (can be string or int)
public enum THEAJSONRPCId: Codable, Sendable, Equatable {
    case string(String)
    case int(Int)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else {
            throw DecodingError.typeMismatch(
                THEAJSONRPCId.self,
                .init(codingPath: decoder.codingPath, debugDescription: "Expected string or int")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        }
    }
}

/// MCP Parameters (flexible)
public struct THEAMCPParams: Codable, Sendable {
    public var name: String?
    public var arguments: [String: THEAMCPValue]?
    public var uri: String?
    public var content: String?

    public init(name: String? = nil, arguments: [String: THEAMCPValue]? = nil, uri: String? = nil, content: String? = nil) {
        self.name = name
        self.arguments = arguments
        self.uri = uri
        self.content = content
    }
}

/// MCP Value (flexible JSON value)
public enum THEAMCPValue: Codable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([THEAMCPValue])
    case object([String: THEAMCPValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
        } else if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let arrayValue = try? container.decode([THEAMCPValue].self) {
            self = .array(arrayValue)
        } else if let objectValue = try? container.decode([String: THEAMCPValue].self) {
            self = .object(objectValue)
        } else {
            throw DecodingError.typeMismatch(
                THEAMCPValue.self,
                .init(codingPath: decoder.codingPath, debugDescription: "Unsupported type")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    public var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    public var intValue: Int? {
        if case .int(let value) = self { return value }
        return nil
    }

    public var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }
}

/// MCP Result
public struct THEAMCPResult: Codable, Sendable {
    public var protocolVersion: String?
    public var capabilities: THEAMCPCapabilities?
    public var serverInfo: THEAMCPProtocolInfo?
    public var tools: [THEAMCPToolDefinition]?
    public var resources: [THEAMCPResourceDefinition]?
    public var content: [THEAMCPContent]?
    public var isError: Bool?

    public init() {}
}

/// MCP Error
public struct THEAMCPError: Codable, Sendable {
    public let code: Int
    public let message: String
    public let data: THEAMCPValue?

    public init(code: Int, message: String, data: THEAMCPValue? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }

    public static let parseError = THEAMCPError(code: -32700, message: "Parse error")
    public static let invalidRequest = THEAMCPError(code: -32600, message: "Invalid Request")
    public static let methodNotFound = THEAMCPError(code: -32601, message: "Method not found")
    public static let invalidParams = THEAMCPError(code: -32602, message: "Invalid params")
    public static let internalError = THEAMCPError(code: -32603, message: "Internal error")
}

/// MCP Capabilities
public struct THEAMCPCapabilities: Codable, Sendable {
    public var tools: THEAMCPToolCapability?
    public var resources: THEAMCPResourceCapability?
    public var prompts: THEAMCPPromptCapability?
    public var sampling: THEAMCPSamplingCapability?

    public init(
        tools: THEAMCPToolCapability? = nil,
        resources: THEAMCPResourceCapability? = nil,
        prompts: THEAMCPPromptCapability? = nil,
        sampling: THEAMCPSamplingCapability? = nil
    ) {
        self.tools = tools
        self.resources = resources
        self.prompts = prompts
        self.sampling = sampling
    }
}

public struct THEAMCPToolCapability: Codable, Sendable {
    public var listChanged: Bool?
    public init(listChanged: Bool? = nil) {
        self.listChanged = listChanged
    }
}

public struct THEAMCPResourceCapability: Codable, Sendable {
    public var subscribe: Bool?
    public var listChanged: Bool?
    public init(subscribe: Bool? = nil, listChanged: Bool? = nil) {
        self.subscribe = subscribe
        self.listChanged = listChanged
    }
}

public struct THEAMCPPromptCapability: Codable, Sendable {
    public var listChanged: Bool?
    public init(listChanged: Bool? = nil) {
        self.listChanged = listChanged
    }
}

public struct THEAMCPSamplingCapability: Codable, Sendable {
    public init() {}
}

/// MCP Protocol Server Info (for protocol handshake)
public struct THEAMCPProtocolInfo: Codable, Sendable {
    public var name: String
    public var version: String

    public init(name: String, version: String) {
        self.name = name
        self.version = version
    }
}

/// MCP Tool Definition
public struct THEAMCPToolDefinition: Codable, Sendable {
    public var name: String
    public var description: String
    public var inputSchema: THEAMCPToolInputSchema

    public init(name: String, description: String, inputSchema: THEAMCPToolInputSchema) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }
}

/// MCP Tool Input Schema (JSON Schema)
public struct THEAMCPToolInputSchema: Codable, Sendable {
    public var type: String
    public var properties: [String: THEAMCPSchemaProperty]?
    public var required: [String]?

    public init(
        type: String = "object",
        properties: [String: THEAMCPSchemaProperty]? = nil,
        required: [String]? = nil
    ) {
        self.type = type
        self.properties = properties
        self.required = required
    }
}

/// MCP Schema Property
public struct THEAMCPSchemaProperty: Codable, Sendable {
    public var type: String
    public var description: String?
    public var items: THEAMCPSchemaItems?
    public var `enum`: [String]?

    public init(type: String, description: String? = nil, items: THEAMCPSchemaItems? = nil, `enum`: [String]? = nil) {
        self.type = type
        self.description = description
        self.items = items
        self.enum = `enum`
    }
}

/// MCP Schema Items (for arrays)
public struct THEAMCPSchemaItems: Codable, Sendable {
    public var type: String
    public init(type: String) {
        self.type = type
    }
}

/// MCP Resource Definition
public struct THEAMCPResourceDefinition: Codable, Sendable {
    public var uri: String
    public var name: String
    public var description: String?
    public var mimeType: String?

    public init(uri: String, name: String, description: String? = nil, mimeType: String? = nil) {
        self.uri = uri
        self.name = name
        self.description = description
        self.mimeType = mimeType
    }
}

/// MCP Content
public struct THEAMCPContent: Codable, Sendable {
    public var type: String
    public var text: String?
    public var data: String?
    public var mimeType: String?

    public init(type: String, text: String? = nil, data: String? = nil, mimeType: String? = nil) {
        self.type = type
        self.text = text
        self.data = data
        self.mimeType = mimeType
    }

    public static func text(_ content: String) -> THEAMCPContent {
        THEAMCPContent(type: "text", text: content)
    }

    public static func image(data: String, mimeType: String) -> THEAMCPContent {
        THEAMCPContent(type: "image", data: data, mimeType: mimeType)
    }
}

/// MCP Tool Error
public enum THEAMCPToolError: Error, LocalizedError {
    case unknownTool(String)
    case missingArgument(String)
    case executionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unknownTool(let name):
            return "Unknown tool: \(name)"
        case .missingArgument(let arg):
            return "Missing argument: \(arg)"
        case .executionFailed(let reason):
            return "Execution failed: \(reason)"
        }
    }
}

// MARK: - Thea MCP Server

/// MCP Server that exposes Thea's capabilities
public actor THEAMCPServer {
    public static let shared = THEAMCPServer()

    private let logger = Logger(subsystem: "com.thea.mcp", category: "Server")

    private var isRunning = false
    private var inputHandle: FileHandle?
    private var outputHandle: FileHandle?

    private let serverInfo = THEAMCPProtocolInfo(name: "thea", version: "2.0.0")

    private init() {}

    // MARK: - Server Lifecycle

    /// Start the MCP server (stdio mode)
    public func start() async {
        guard !isRunning else {
            logger.warning("Server already running")
            return
        }

        isRunning = true
        inputHandle = FileHandle.standardInput
        outputHandle = FileHandle.standardOutput

        logger.info("THEA MCP Server started")

        // Process incoming messages
        await processMessages()
    }

    /// Stop the MCP server
    public func stop() {
        isRunning = false
        inputHandle = nil
        outputHandle = nil
        logger.info("THEA MCP Server stopped")
    }

    // MARK: - Message Processing

    private func processMessages() async {
        guard let inputHandle = inputHandle else { return }

        while isRunning {
            do {
                // Read line-delimited JSON
                if let data = try await readMessage(from: inputHandle),
                   !data.isEmpty {
                    let request = try JSONDecoder().decode(THEAMCPRequest.self, from: data)
                    let response = await handleRequest(request)

                    try await sendResponse(response)
                }
            } catch {
                logger.error("Message processing error: \(error.localizedDescription)")
            }
        }
    }

    private func readMessage(from handle: FileHandle) async throws -> Data? {
        // Read until newline
        var buffer = Data()
        while isRunning {
            let byte = handle.readData(ofLength: 1)
            if byte.isEmpty {
                try await Task.sleep(nanoseconds: 10_000_000)  // 10ms
                continue
            }
            if byte[0] == 0x0A {  // newline
                break
            }
            buffer.append(byte)
        }
        return buffer.isEmpty ? nil : buffer
    }

    private func sendResponse(_ response: THEAMCPResponse) async throws {
        guard let outputHandle = outputHandle else { return }

        let data = try JSONEncoder().encode(response)
        outputHandle.write(data)
        outputHandle.write(Data([0x0A]))  // newline
    }

    // MARK: - Request Handling

    private func handleRequest(_ request: THEAMCPRequest) async -> THEAMCPResponse {
        logger.debug("Handling request: \(request.method)")

        switch request.method {
        case "initialize":
            return handleInitialize(request)
        case "tools/list":
            return handleToolsList(request)
        case "tools/call":
            return await handleToolsCall(request)
        case "resources/list":
            return handleResourcesList(request)
        case "resources/read":
            return await handleResourcesRead(request)
        case "ping":
            return handlePing(request)
        default:
            return THEAMCPResponse(id: request.id, error: .methodNotFound)
        }
    }

    private func handleInitialize(_ request: THEAMCPRequest) -> THEAMCPResponse {
        var result = THEAMCPResult()
        result.protocolVersion = "2024-11-05"
        result.capabilities = THEAMCPCapabilities(
            tools: THEAMCPToolCapability(listChanged: true),
            resources: THEAMCPResourceCapability(subscribe: false, listChanged: true)
        )
        result.serverInfo = serverInfo
        return THEAMCPResponse(id: request.id, result: result)
    }

    private func handleToolsList(_ request: THEAMCPRequest) -> THEAMCPResponse {
        var result = THEAMCPResult()
        result.tools = getAvailableTools()
        return THEAMCPResponse(id: request.id, result: result)
    }

    private func handleToolsCall(_ request: THEAMCPRequest) async -> THEAMCPResponse {
        guard let params = request.params,
              let toolName = params.name else {
            return THEAMCPResponse(id: request.id, error: .invalidParams)
        }

        do {
            let content = try await executeTool(name: toolName, arguments: params.arguments ?? [:])
            var result = THEAMCPResult()
            result.content = content
            return THEAMCPResponse(id: request.id, result: result)
        } catch {
            var result = THEAMCPResult()
            result.content = [.text("Error: \(error.localizedDescription)")]
            result.isError = true
            return THEAMCPResponse(id: request.id, result: result)
        }
    }

    private func handleResourcesList(_ request: THEAMCPRequest) -> THEAMCPResponse {
        var result = THEAMCPResult()
        result.resources = getAvailableResources()
        return THEAMCPResponse(id: request.id, result: result)
    }

    private func handleResourcesRead(_ request: THEAMCPRequest) async -> THEAMCPResponse {
        guard let params = request.params,
              let uri = params.uri else {
            return THEAMCPResponse(id: request.id, error: .invalidParams)
        }

        do {
            let content = try await readResource(uri: uri)
            var result = THEAMCPResult()
            result.content = content
            return THEAMCPResponse(id: request.id, result: result)
        } catch {
            return THEAMCPResponse(id: request.id, error: THEAMCPError(code: -32000, message: error.localizedDescription))
        }
    }

    private func handlePing(_ request: THEAMCPRequest) -> THEAMCPResponse {
        let result = THEAMCPResult()
        return THEAMCPResponse(id: request.id, result: result)
    }

    // MARK: - Tool Definitions

    private func getAvailableTools() -> [THEAMCPToolDefinition] {
        [
            // System Tools
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
            ),

            // Apple Integration Tools
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
            ),
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
            ),

            // Automation Tools
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

    // MARK: - Tool Execution

    private func executeTool(name: String, arguments: [String: THEAMCPValue]) async throws -> [THEAMCPContent] {
        switch name {
        case "thea_execute_command":
            return try await executeCommand(arguments)
        case "thea_read_file":
            return try await readFile(arguments)
        case "thea_write_file":
            return try await writeFile(arguments)
        case "thea_list_directory":
            return try await listDirectory(arguments)
        case "thea_search_contacts":
            return try await searchContacts(arguments)
        case "thea_get_reminders":
            return try await getReminders(arguments)
        case "thea_create_reminder":
            return try await createReminder(arguments)
        case "thea_search_notes":
            return try await searchNotes(arguments)
        case "thea_create_note":
            return try await createNote(arguments)
        case "thea_search_location":
            return try await searchLocation(arguments)
        case "thea_get_directions":
            return try await getDirections(arguments)
        case "thea_run_shortcut":
            return try await runShortcut(arguments)
        case "thea_speak":
            return try await speak(arguments)
        default:
            throw THEAMCPToolError.unknownTool(name)
        }
    }

    // MARK: - Tool Implementations

    private func executeCommand(_ args: [String: THEAMCPValue]) async throws -> [THEAMCPContent] {
        guard let command = args["command"]?.stringValue else {
            throw THEAMCPToolError.missingArgument("command")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        let output = String(data: outputData, encoding: .utf8) ?? ""
        let error = String(data: errorData, encoding: .utf8) ?? ""

        var result = output
        if !error.isEmpty {
            result += "\nStderr: \(error)"
        }
        result += "\nExit code: \(process.terminationStatus)"

        return [.text(result)]
    }

    private func readFile(_ args: [String: THEAMCPValue]) async throws -> [THEAMCPContent] {
        guard let path = args["path"]?.stringValue else {
            throw THEAMCPToolError.missingArgument("path")
        }

        let url = URL(fileURLWithPath: path)
        let content = try String(contentsOf: url, encoding: .utf8)
        return [.text(content)]
    }

    private func writeFile(_ args: [String: THEAMCPValue]) async throws -> [THEAMCPContent] {
        guard let path = args["path"]?.stringValue else {
            throw THEAMCPToolError.missingArgument("path")
        }
        guard let content = args["content"]?.stringValue else {
            throw THEAMCPToolError.missingArgument("content")
        }

        let url = URL(fileURLWithPath: path)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return [.text("Successfully wrote \(content.count) characters to \(path)")]
    }

    private func listDirectory(_ args: [String: THEAMCPValue]) async throws -> [THEAMCPContent] {
        guard let path = args["path"]?.stringValue else {
            throw THEAMCPToolError.missingArgument("path")
        }

        let url = URL(fileURLWithPath: path)
        let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey])

        var listing = ""
        for item in contents.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            listing += "\(isDir ? "📁" : "📄") \(item.lastPathComponent)\n"
        }

        return [.text(listing)]
    }

    private func searchContacts(_ args: [String: THEAMCPValue]) async throws -> [THEAMCPContent] {
        guard let query = args["query"]?.stringValue else {
            throw THEAMCPToolError.missingArgument("query")
        }

        // Use ContactsIntegration
        let criteria = ContactSearchCriteria(nameQuery: query)
        let contacts = try await ContactsIntegration.shared.searchContacts(criteria: criteria)
        var result = "Found \(contacts.count) contacts:\n"
        for contact in contacts.prefix(10) {
            result += "- \(contact.fullName)"
            if let email = contact.emailAddresses.first {
                result += " (\(email.value))"
            }
            result += "\n"
        }
        return [.text(result)]
    }

    private func getReminders(_ args: [String: THEAMCPValue]) async throws -> [THEAMCPContent] {
        let includeCompleted = args["completed"]?.boolValue ?? false

        // Build criteria - if includeCompleted is false, filter for incomplete only
        let criteria = ReminderSearchCriteria(
            isCompleted: includeCompleted ? nil : false
        )
        let reminders = try await RemindersIntegration.shared.fetchReminders(criteria: criteria)

        var result = "Found \(reminders.count) reminders:\n"
        for reminder in reminders.prefix(20) {
            let status = reminder.isCompleted ? "✅" : "⬜️"
            result += "\(status) \(reminder.title)"
            if let dueDate = reminder.dueDate {
                result += " (due: \(dueDate.formatted()))"
            }
            result += "\n"
        }
        return [.text(result)]
    }

    private func createReminder(_ args: [String: THEAMCPValue]) async throws -> [THEAMCPContent] {
        guard let title = args["title"]?.stringValue else {
            throw THEAMCPToolError.missingArgument("title")
        }

        let notes = args["notes"]?.stringValue
        let listName = args["list"]?.stringValue
        let dueDateString = args["due_date"]?.stringValue

        var dueDate: Date?
        if let dateStr = dueDateString {
            dueDate = ISO8601DateFormatter().date(from: dateStr)
        }

        let reminder = TheaReminder(
            title: title,
            notes: notes,
            dueDate: dueDate,
            listName: listName
        )
        _ = try await RemindersIntegration.shared.createReminder(reminder)

        return [.text("Created reminder: \(title)")]
    }

    private func searchNotes(_ args: [String: THEAMCPValue]) async throws -> [THEAMCPContent] {
        guard let query = args["query"]?.stringValue else {
            throw THEAMCPToolError.missingArgument("query")
        }

        let notes = try await NotesIntegration.shared.searchNotes(text: query)
        var result = "Found \(notes.count) notes:\n"
        for note in notes.prefix(10) {
            result += "- \(note.title)"
            if let folder = note.folderName {
                result += " (in \(folder))"
            }
            result += "\n"
        }
        return [.text(result)]
    }

    private func createNote(_ args: [String: THEAMCPValue]) async throws -> [THEAMCPContent] {
        guard let title = args["title"]?.stringValue else {
            throw THEAMCPToolError.missingArgument("title")
        }
        guard let body = args["body"]?.stringValue else {
            throw THEAMCPToolError.missingArgument("body")
        }

        let folder = args["folder"]?.stringValue

        try await NotesIntegration.shared.createNote(title: title, body: body, folderName: folder)
        return [.text("Created note: \(title)")]
    }

    private func searchLocation(_ args: [String: THEAMCPValue]) async throws -> [THEAMCPContent] {
        guard let query = args["query"]?.stringValue else {
            throw THEAMCPToolError.missingArgument("query")
        }

        let criteria = LocationSearchCriteria(query: query)
        let results = try await MapsIntegration.shared.searchLocations(criteria: criteria)
        var result = "Found \(results.count) locations:\n"
        for location in results.prefix(5) {
            result += "- \(location.name)"
            if !location.address.isEmpty {
                result += ", \(location.address)"
            }
            result += "\n"
        }
        return [.text(result)]
    }

    private func getDirections(_ args: [String: THEAMCPValue]) async throws -> [THEAMCPContent] {
        guard let from = args["from"]?.stringValue else {
            throw THEAMCPToolError.missingArgument("from")
        }
        guard let to = args["to"]?.stringValue else {
            throw THEAMCPToolError.missingArgument("to")
        }

        let modeString = args["mode"]?.stringValue ?? "driving"
        let transportType: TransportType = switch modeString {
        case "walking": .walking
        case "transit": .transit
        default: .automobile
        }

        let routes = try await MapsIntegration.shared.getDirections(
            from: from,
            to: to,
            transportType: transportType
        )

        guard let route = routes.first else {
            return [.text("No routes found from \(from) to \(to)")]
        }

        var result = "Route from \(from) to \(to):\n"
        result += "Distance: \(route.distanceFormatted)\n"
        result += "Expected time: \(route.travelTimeFormatted)\n"
        result += "\nSteps:\n"
        for (index, step) in route.steps.enumerated() {
            if !step.instructions.isEmpty {
                result += "\(index + 1). \(step.instructions)\n"
            }
        }
        return [.text(result)]
    }

    private func runShortcut(_ args: [String: THEAMCPValue]) async throws -> [THEAMCPContent] {
        guard let name = args["name"]?.stringValue else {
            throw THEAMCPToolError.missingArgument("name")
        }

        let input = args["input"]?.stringValue ?? ""

        // Run shortcut via shell
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["run", name, "--input-path", "-"]

        let inputPipe = Pipe()
        let outputPipe = Pipe()
        process.standardInput = inputPipe
        process.standardOutput = outputPipe

        try process.run()
        inputPipe.fileHandleForWriting.write(input.data(using: .utf8) ?? Data())
        inputPipe.fileHandleForWriting.closeFile()
        process.waitUntilExit()

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return [.text("Shortcut '\(name)' completed.\n\(output)")]
    }

    private func speak(_ args: [String: THEAMCPValue]) async throws -> [THEAMCPContent] {
        guard let text = args["text"]?.stringValue else {
            throw THEAMCPToolError.missingArgument("text")
        }

        try await VoiceIntegration.shared.speak(text: text)
        return [.text("Speaking: \(text)")]
    }

    // MARK: - Resource Definitions

    private func getAvailableResources() -> [THEAMCPResourceDefinition] {
        [
            THEAMCPResourceDefinition(
                uri: "thea://system/info",
                name: "System Information",
                description: "Current system status and capabilities",
                mimeType: "application/json"
            ),
            THEAMCPResourceDefinition(
                uri: "thea://models/local",
                name: "Local Models",
                description: "Available local ML models",
                mimeType: "application/json"
            ),
            THEAMCPResourceDefinition(
                uri: "thea://context/current",
                name: "Current Context",
                description: "Current user context including calendar, location, etc.",
                mimeType: "application/json"
            )
        ]
    }

    private func readResource(uri: String) async throws -> [THEAMCPContent] {
        switch uri {
        case "thea://system/info":
            let info = """
            {
                "name": "Thea",
                "version": "2.0.0",
                "platform": "macOS",
                "capabilities": ["contacts", "reminders", "notes", "maps", "voice", "automation"]
            }
            """
            return [.text(info)]

        case "thea://models/local":
            let models = await MLXModelManager.shared.scannedModels
            let modelList = models.map { "- \($0.name) (\($0.format))" }.joined(separator: "\n")
            return [.text("Local models:\n\(modelList)")]

        case "thea://context/current":
            let context = """
            {
                "timestamp": "\(ISO8601DateFormatter().string(from: Date()))",
                "platform": "macOS"
            }
            """
            return [.text(context)]

        default:
            throw THEAMCPToolError.executionFailed("Unknown resource: \(uri)")
        }
    }
}

#endif
