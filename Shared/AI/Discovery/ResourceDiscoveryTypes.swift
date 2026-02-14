//
//  ResourceDiscoveryTypes.swift
//  Thea
//
//  Resource type definitions, stats, and API response types extracted
//  from ResourceDiscoveryEngine.swift for file_length compliance.
//
//  Copyright 2026. All rights reserved.
//

import Foundation

// MARK: - Resource Types

/// Represents a discovered resource from any registry
public struct DiscoveredResource: Identifiable, Codable, Sendable {
    public let id: UUID
    public let sourceRegistry: ResourceRegistry
    public let qualifiedName: String
    public let displayName: String
    public let description: String
    public var capabilities: [ResourceCapability]
    public var tools: [DiscoveredTool]
    public var trustScore: Double
    public var popularity: Int
    public var lastUpdated: Date
    public var connectionConfig: ResourceConnectionConfig?
    public var tags: Set<String>
    public var isVerified: Bool
    public var isHosted: Bool

    public init(
        id: UUID = UUID(),
        sourceRegistry: ResourceRegistry,
        qualifiedName: String,
        displayName: String,
        description: String,
        capabilities: [ResourceCapability] = [],
        tools: [DiscoveredTool] = [],
        trustScore: Double = 0.5,
        popularity: Int = 0,
        lastUpdated: Date = Date(),
        connectionConfig: ResourceConnectionConfig? = nil,
        tags: Set<String> = [],
        isVerified: Bool = false,
        isHosted: Bool = false
    ) {
        self.id = id
        self.sourceRegistry = sourceRegistry
        self.qualifiedName = qualifiedName
        self.displayName = displayName
        self.description = description
        self.capabilities = capabilities
        self.tools = tools
        self.trustScore = trustScore
        self.popularity = popularity
        self.lastUpdated = lastUpdated
        self.connectionConfig = connectionConfig
        self.tags = tags
        self.isVerified = isVerified
        self.isHosted = isHosted
    }
}

/// Source registry for a resource
public enum ResourceRegistry: String, Codable, Sendable, CaseIterable {
    case smithery
    case context7
    case mcpHub
    case officialMCP
    case local
    case custom

    public var displayName: String {
        switch self {
        case .smithery: "Smithery"
        case .context7: "Context7"
        case .mcpHub: "MCP Hub"
        case .officialMCP: "Official MCP"
        case .local: "Local"
        case .custom: "Custom"
        }
    }

    public var baseURL: URL? {
        switch self {
        case .smithery: URL(string: "https://registry.smithery.ai")
        case .context7: URL(string: "https://mcp.context7.com")
        case .mcpHub: URL(string: "https://mcphub.io/api")
        case .officialMCP: URL(string: "https://modelcontextprotocol.io/servers")
        case .local: nil
        case .custom: nil
        }
    }
}

/// A capability that a resource provides
public struct ResourceCapability: Codable, Sendable, Hashable {
    public let name: String
    public let category: CapabilityCategory
    public let description: String

    public enum CapabilityCategory: String, Codable, Sendable {
        case tools
        case prompts
        case resources
        case sampling
        case documentation
        case fileSystem
        case database
        case api
        case web
        case ai
        case custom
    }

    public init(name: String, category: CapabilityCategory, description: String) {
        self.name = name
        self.category = category
        self.description = description
    }
}

/// A tool discovered within a resource
public struct DiscoveredTool: Identifiable, Codable, Sendable {
    public let id: UUID
    public let name: String
    public let description: String
    public var inputSchema: [String: DiscoveredToolParameter]
    public var outputType: String?
    public var examples: [DiscoveredToolExample]

    public init(
        id: UUID = UUID(),
        name: String,
        description: String,
        inputSchema: [String: DiscoveredToolParameter] = [:],
        outputType: String? = nil,
        examples: [DiscoveredToolExample] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
        self.outputType = outputType
        self.examples = examples
    }
}

/// Parameter definition for a tool
public struct DiscoveredToolParameter: Codable, Sendable {
    public let type: String
    public let description: String
    public let isRequired: Bool
    public var defaultValue: String?
    public var enumValues: [String]?

    public init(
        type: String,
        description: String,
        isRequired: Bool = false,
        defaultValue: String? = nil,
        enumValues: [String]? = nil
    ) {
        self.type = type
        self.description = description
        self.isRequired = isRequired
        self.defaultValue = defaultValue
        self.enumValues = enumValues
    }
}

/// Example usage of a tool
public struct DiscoveredToolExample: Codable, Sendable {
    public let input: [String: String]
    public let output: String?
    public let description: String?

    public init(input: [String: String], output: String? = nil, description: String? = nil) {
        self.input = input
        self.output = output
        self.description = description
    }
}

/// Configuration for connecting to a resource
public struct ResourceConnectionConfig: Codable, Sendable {
    public let transportType: TransportType
    public let endpoint: String?
    public let headers: [String: String]
    public var authType: AuthenticationType
    public var config: [String: String]

    public enum TransportType: String, Codable, Sendable {
        case stdio
        case http
        case websocket
        case sse
    }

    public enum AuthenticationType: String, Codable, Sendable {
        case none
        case apiKey
        case bearer
        case oauth
        case custom
    }

    public init(
        transportType: TransportType,
        endpoint: String? = nil,
        headers: [String: String] = [:],
        authType: AuthenticationType = .none,
        config: [String: String] = [:]
    ) {
        self.transportType = transportType
        self.endpoint = endpoint
        self.headers = headers
        self.authType = authType
        self.config = config
    }
}

// MARK: - Discovery Stats

public struct DiscoveryStats: Codable, Sendable {
    public var totalResources: Int = 0
    public var lastDiscoveryDate: Date?
    public var lastDiscoveryDuration: TimeInterval = 0
    public var discoveryCount: Int = 0

    public init() {}
}

// MARK: - Smithery API Response Types

struct SmitheryServerListResponse: Codable {
    let servers: [SmitheryServer]
    let total: Int?
    let page: Int?
    let pageSize: Int?
}

struct SmitheryServer: Codable {
    let qualifiedName: String
    let displayName: String
    let description: String
    let isHosted: Bool
    let tools: [SmitheryTool]
    let trustScore: Int?
    let useCount: Int?
    let updatedAt: Date?
    let tags: [String]?
    let isVerified: Bool?

    enum CodingKeys: String, CodingKey {
        case qualifiedName
        case displayName
        case description
        case isHosted
        case tools
        case trustScore
        case useCount
        case updatedAt
        case tags
        case isVerified
    }
}

struct SmitheryTool: Codable {
    let name: String
    let description: String
}

// MARK: - Local MCP Config Types

struct LocalMCPConfig: Codable {
    let servers: [String: LocalMCPServer]

    struct LocalMCPServer: Codable {
        let command: String
        let args: [String]?
        let description: String?
        let env: [String: String]?
    }
}
