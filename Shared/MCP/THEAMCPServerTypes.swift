// THEAMCPServerTypes.swift
// Thea V2
//
// MCP Protocol types extracted from THEAMCPServer.swift
// JSON-RPC 2.0 types, MCP capabilities, tool/resource definitions

import Foundation
import OSLog

private let logger = Logger(subsystem: "ai.thea.app", category: "THEAMCPServerTypes")

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
        var intDecodeError: Error?
        do {
            self = .int(try container.decode(Int.self))
            return
        } catch {
            intDecodeError = error
        }
        do {
            self = .string(try container.decode(String.self))
            return
        } catch {
            logger.debug("THEAJSONRPCId: not int (\(String(describing: intDecodeError))), not string (\(error.localizedDescription))")
        }
        throw DecodingError.typeMismatch(
            THEAJSONRPCId.self,
            .init(codingPath: decoder.codingPath, debugDescription: "Expected string or int")
        )
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
            return
        }
        do { self = .bool(try container.decode(Bool.self)); return } catch {}
        do { self = .int(try container.decode(Int.self)); return } catch {}
        do { self = .double(try container.decode(Double.self)); return } catch {}
        do { self = .string(try container.decode(String.self)); return } catch {}
        do { self = .array(try container.decode([THEAMCPValue].self)); return } catch {}
        do { self = .object(try container.decode([String: THEAMCPValue].self)); return } catch {}
        throw DecodingError.typeMismatch(
            THEAMCPValue.self,
            .init(codingPath: decoder.codingPath, debugDescription: "Unsupported THEAMCPValue type")
        )
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

#endif
