//
//  MCPServerGeneratorTypes.swift
//  Thea
//
//  Supporting types for MCPServerGenerator
//

import Foundation

// MARK: - MCP Server Spec

public struct MCPServerSpec: Codable, Sendable {
    public let name: String
    public let version: String
    public let description: String
    public var tools: [MCPToolSpec]
    public var resources: [MCPResourceSpec]
    public var prompts: [MCPPromptSpec]

    public init(
        name: String,
        version: String = "1.0.0",
        description: String = "",
        tools: [MCPToolSpec] = [],
        resources: [MCPResourceSpec] = [],
        prompts: [MCPPromptSpec] = []
    ) {
        self.name = name
        self.version = version
        self.description = description
        self.tools = tools
        self.resources = resources
        self.prompts = prompts
    }
}

// MARK: - MCP Tool Spec

public struct MCPToolSpec: Codable, Sendable, Identifiable {
    public var id: String { name }
    public let name: String
    public let description: String
    public let parameters: [MCPParameterSpec]

    public init(name: String, description: String, parameters: [MCPParameterSpec] = []) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}

// MARK: - MCP Parameter Spec

public struct MCPParameterSpec: Codable, Sendable {
    public let name: String
    public let type: MCPParameterType
    public let description: String
    public let isRequired: Bool

    public init(name: String, type: MCPParameterType, description: String, isRequired: Bool = true) {
        self.name = name
        self.type = type
        self.description = description
        self.isRequired = isRequired
    }

    public var swiftType: String {
        let baseType = switch type {
        case .string: "String"
        case .number: "Double"
        case .integer: "Int"
        case .boolean: "Bool"
        case .array: "[Any]"
        case .object: "[String: Any]"
        }
        return isRequired ? baseType : "\(baseType)?"
    }

    public var jsonType: String {
        switch type {
        case .string: "string"
        case .number: "number"
        case .integer: "integer"
        case .boolean: "boolean"
        case .array: "array"
        case .object: "object"
        }
    }
}

// MARK: - MCP Parameter Type

public enum MCPParameterType: String, Codable, Sendable {
    case string
    case number
    case integer
    case boolean
    case array
    case object
}

// MARK: - MCP Resource Spec

public struct MCPResourceSpec: Codable, Sendable, Identifiable {
    public var id: String { name }
    public let name: String
    public let description: String
    public let uriTemplate: String
    public let mimeType: String

    public init(name: String, description: String, uriTemplate: String, mimeType: String = "text/plain") {
        self.name = name
        self.description = description
        self.uriTemplate = uriTemplate
        self.mimeType = mimeType
    }
}

// MARK: - MCP Prompt Spec

public struct MCPPromptSpec: Codable, Sendable, Identifiable {
    public var id: String { name }
    public let name: String
    public let description: String
    public let arguments: [MCPArgumentSpec]

    public init(name: String, description: String, arguments: [MCPArgumentSpec] = []) {
        self.name = name
        self.description = description
        self.arguments = arguments
    }
}

// MARK: - MCP Argument Spec

public struct MCPArgumentSpec: Codable, Sendable {
    public let name: String
    public let description: String
    public let isRequired: Bool

    public init(name: String, description: String, isRequired: Bool = true) {
        self.name = name
        self.description = description
        self.isRequired = isRequired
    }
}

// MARK: - Generated MCP Server

public struct GeneratedMCPServer: Sendable, Identifiable {
    public let id: String
    public let name: String
    public let spec: MCPServerSpec
    public let generatedCode: String
    public let generatedAt: Date
}

// MARK: - MCP Template

public struct MCPTemplate: Sendable {
    public let name: String
    public let description: String
    public let defaultTools: [MCPToolSpec]
    public var defaultResources: [MCPResourceSpec] = []
    public var defaultPrompts: [MCPPromptSpec] = []

    public func createSpec(with config: MCPTemplateConfig) -> MCPServerSpec {
        MCPServerSpec(
            name: config.serverName,
            version: config.version,
            description: config.description ?? description,
            tools: config.includeDefaultTools ? defaultTools : [],
            resources: config.includeDefaultResources ? defaultResources : [],
            prompts: config.includeDefaultPrompts ? defaultPrompts : []
        )
    }
}

// MARK: - MCP Template Config

public struct MCPTemplateConfig: Sendable {
    public let serverName: String
    public var version: String = "1.0.0"
    public var description: String?
    public var includeDefaultTools: Bool = true
    public var includeDefaultResources: Bool = true
    public var includeDefaultPrompts: Bool = true

    public init(serverName: String) {
        self.serverName = serverName
    }
}

// MARK: - MCP Generator Error

public enum MCPGeneratorError: Error, LocalizedError, Sendable {
    case templateNotFound(String)
    case serverNotFound(String)
    case invalidSpec(String)
    case generationFailed(String)

    public var errorDescription: String? {
        switch self {
        case let .templateNotFound(name):
            "Template not found: \(name)"
        case let .serverNotFound(id):
            "Generated server not found: \(id)"
        case let .invalidSpec(reason):
            "Invalid specification: \(reason)"
        case let .generationFailed(reason):
            "Code generation failed: \(reason)"
        }
    }
}

// MARK: - MCP Protocol Types

/// An actor that implements the Model Context Protocol server interface for tool-based AI interactions.
public protocol MCPServer: Actor {
    var serverMetadata: MCPGeneratedServerMetadata { get }
    func start() async throws
    func stop() async
    func handleRequest(_ request: MCPRequest) async throws -> MCPResponse
}

/// Metadata for a generated MCP server (distinct from MCPServerMetadata in MCPServerLifecycleManager)
public struct MCPGeneratedServerMetadata: Sendable {
    public let name: String
    public let version: String
    public let capabilities: MCPCapabilities

    public init(name: String, version: String, capabilities: MCPCapabilities) {
        self.name = name
        self.version = version
        self.capabilities = capabilities
    }
}

public struct MCPCapabilities: Sendable {
    public let tools: MCPToolsCapability?
    public let resources: MCPResourcesCapability?
    public let prompts: MCPPromptsCapability?

    public var dictionary: [String: Any] {
        var dict: [String: Any] = [:]
        if tools != nil { dict["tools"] = [:] }
        if resources != nil { dict["resources"] = [:] }
        if prompts != nil { dict["prompts"] = [:] }
        return dict
    }

    public init(tools: MCPToolsCapability? = nil, resources: MCPResourcesCapability? = nil, prompts: MCPPromptsCapability? = nil) {
        self.tools = tools
        self.resources = resources
        self.prompts = prompts
    }
}

public struct MCPToolsCapability: Sendable {}
public struct MCPResourcesCapability: Sendable {}
public struct MCPPromptsCapability: Sendable {}

public struct MCPConnection: Sendable, Identifiable {
    public let id: String
    public let connectedAt: Date

    public init(id: String = UUID().uuidString, connectedAt: Date = Date()) {
        self.id = id
        self.connectedAt = connectedAt
    }
}

// MARK: - Sendable justification: [String: Any] params for MCP protocol flexibility
public struct MCPRequest: @unchecked Sendable {
    public let id: String
    public let method: String
    public let params: [String: Any]?

    public init(id: String, method: String, params: [String: Any]? = nil) {
        self.id = id
        self.method = method
        self.params = params
    }
}

// MARK: - Sendable justification: [String: Any] result for MCP protocol flexibility
public struct MCPResponse: @unchecked Sendable {
    public let id: String
    public let result: [String: Any]?
    public let error: MCPError?

    public init(id: String, result: [String: Any]? = nil, error: MCPError? = nil) {
        self.id = id
        self.result = result
        self.error = error
    }
}

public struct MCPToolResult: Sendable {
    public let content: [MCPContent]
    public let isError: Bool

    public var dictionary: [String: Any] {
        [
            "content": content.map { ["type": $0.type, "text": $0.text ?? ""] },
            "isError": isError
        ]
    }

    public init(content: [MCPContent], isError: Bool = false) {
        self.content = content
        self.isError = isError
    }
}

public struct MCPContent: Sendable {
    public let type: String
    public let text: String?

    public init(type: String, text: String? = nil) {
        self.type = type
        self.text = text
    }
}

public struct MCPResourceContent: Sendable {
    public let uri: String
    public let mimeType: String
    public let text: String?

    public init(uri: String, mimeType: String, text: String? = nil) {
        self.uri = uri
        self.mimeType = mimeType
        self.text = text
    }
}

public struct MCPPromptResult: Sendable {
    public let description: String
    public let messages: [MCPPromptMessage]

    public init(description: String, messages: [MCPPromptMessage]) {
        self.description = description
        self.messages = messages
    }
}

public struct MCPPromptMessage: Sendable {
    public let role: String
    public let content: MCPContent

    public init(role: String, content: MCPContent) {
        self.role = role
        self.content = content
    }
}

public enum MCPError: Error, LocalizedError, Sendable {
    case methodNotFound(String)
    case invalidParams(String)
    case toolNotFound(String)
    case resourceNotFound(String)
    case promptNotFound(String)
    case internalError(String)

    public var errorDescription: String? {
        switch self {
        case let .methodNotFound(method):
            "Method not found: \(method)"
        case let .invalidParams(reason):
            "Invalid parameters: \(reason)"
        case let .toolNotFound(name):
            "Tool not found: \(name)"
        case let .resourceNotFound(uri):
            "Resource not found: \(uri)"
        case let .promptNotFound(name):
            "Prompt not found: \(name)"
        case let .internalError(reason):
            "Internal error: \(reason)"
        }
    }
}
