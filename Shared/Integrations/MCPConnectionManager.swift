//
//  MCPConnectionManager.swift
//  Thea
//
//  MCP Connection Manager with OAuth support inspired by Smithery
//  Handles managed connections, namespaces, and service tokens
//

import Foundation
import OSLog

// MARK: - MCP Connection Manager

/// Manages MCP server connections with OAuth and token management
/// Inspired by Smithery's Connect feature
@MainActor
public final class MCPConnectionManager: ObservableObject {
    public static let shared = MCPConnectionManager()

    private let logger = Logger(subsystem: "app.thea", category: "MCPConnection")

    // MARK: - Published State

    @Published public private(set) var connections: [MCPConnection] = []
    @Published public private(set) var namespaces: [MCPNamespace] = []
    @Published public private(set) var serviceTokens: [ServiceToken] = []
    @Published public private(set) var isConnecting = false

    // MARK: - Configuration

    private let configURL: URL
    private let tokenStorageKey = "thea.mcp.tokens"

    // MARK: - Initialization

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        configURL = appSupport.appendingPathComponent("Thea/mcp_connections.json")

        try? FileManager.default.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        Task {
            await loadConnections()
        }
    }

    // MARK: - Connection Management

    /// Create a new connection to an MCP server
    public func connect(
        serverId: String,
        serverName: String,
        serverURL: URL,
        authType: MCPAuthType,
        namespace: String? = nil
    ) async throws -> MCPConnection {
        isConnecting = true
        defer { isConnecting = false }

        logger.info("Connecting to MCP server: \(serverName)")

        // Handle authentication
        let credentials: MCPCredentials?
        switch authType {
        case .none:
            credentials = nil

        case .apiKey(let key):
            credentials = MCPCredentials(
                type: .apiKey,
                accessToken: key,
                refreshToken: nil,
                expiresAt: nil
            )

        case .oauth(let config):
            credentials = try await performOAuthFlow(config: config)
        }

        // Create connection
        let connection = MCPConnection(
            id: UUID().uuidString,
            serverId: serverId,
            serverName: serverName,
            serverURL: serverURL,
            namespace: namespace ?? "default",
            status: .connected,
            credentials: credentials,
            connectedAt: Date(),
            lastUsedAt: Date()
        )

        connections.append(connection)
        try await saveConnections()

        logger.info("Successfully connected to \(serverName)")
        return connection
    }

    /// Disconnect from an MCP server
    public func disconnect(connectionId: String) async throws {
        guard let index = connections.firstIndex(where: { $0.id == connectionId }) else {
            throw MCPConnectionError.connectionNotFound
        }

        var connection = connections[index]
        connection.status = .disconnected
        connections[index] = connection

        try await saveConnections()
        logger.info("Disconnected from \(connection.serverName)")
    }

    /// Check and refresh connection status
    public func refreshConnection(_ connectionId: String) async throws {
        guard let index = connections.firstIndex(where: { $0.id == connectionId }) else {
            throw MCPConnectionError.connectionNotFound
        }

        var connection = connections[index]

        // Check if token needs refresh
        if let credentials = connection.credentials,
           let expiresAt = credentials.expiresAt,
           Date() > expiresAt.addingTimeInterval(-300) { // 5 min buffer
            // Refresh token
            if let refreshToken = credentials.refreshToken {
                let newCredentials = try await refreshOAuthToken(refreshToken: refreshToken, serverURL: connection.serverURL)
                connection.credentials = newCredentials
            } else {
                connection.status = .authRequired
            }
        }

        connection.lastUsedAt = Date()
        connections[index] = connection
        try await saveConnections()
    }

    // MARK: - Namespace Management (Smithery Feature)

    /// Create a new namespace for grouping connections
    public func createNamespace(name: String, description: String? = nil) throws -> MCPNamespace {
        // Validate unique name
        guard !namespaces.contains(where: { $0.name == name }) else {
            throw MCPConnectionError.namespaceExists(name)
        }

        let namespace = MCPNamespace(
            id: UUID().uuidString,
            name: name,
            description: description,
            createdAt: Date()
        )

        namespaces.append(namespace)
        logger.info("Created namespace: \(name)")
        return namespace
    }

    /// Get connections in a namespace
    public func connectionsInNamespace(_ namespaceName: String) -> [MCPConnection] {
        connections.filter { $0.namespace == namespaceName }
    }

    // MARK: - Service Tokens (Smithery Feature)

    /// Create a service token with scoped permissions
    public func createServiceToken(
        name: String,
        namespace: String,
        permissions: ServiceTokenPermissions,
        expiresIn: TimeInterval? = nil
    ) throws -> ServiceToken {
        let token = ServiceToken(
            id: UUID().uuidString,
            name: name,
            namespace: namespace,
            token: generateSecureToken(),
            permissions: permissions,
            createdAt: Date(),
            expiresAt: expiresIn.map { Date().addingTimeInterval($0) },
            lastUsedAt: nil
        )

        serviceTokens.append(token)
        logger.info("Created service token: \(name) for namespace: \(namespace)")
        return token
    }

    /// Validate a service token
    public func validateServiceToken(_ tokenString: String) -> ServiceToken? {
        guard let token = serviceTokens.first(where: { $0.token == tokenString }) else {
            return nil
        }

        // Check expiration
        if let expiresAt = token.expiresAt, Date() > expiresAt {
            return nil
        }

        // Update last used
        if let index = serviceTokens.firstIndex(where: { $0.id == token.id }) {
            serviceTokens[index].lastUsedAt = Date()
        }

        return token
    }

    /// Revoke a service token
    public func revokeServiceToken(_ tokenId: String) {
        serviceTokens.removeAll { $0.id == tokenId }
        logger.info("Revoked service token: \(tokenId)")
    }

    // MARK: - OAuth Flow

    private func performOAuthFlow(config: OAuthConfig) async throws -> MCPCredentials {
        #if os(macOS)
        // In production, this would:
        // 1. Open authorization URL in browser
        // 2. Handle callback with auth code
        // 3. Exchange code for tokens

        // For now, simulate OAuth flow
        logger.info("Starting OAuth flow for \(config.authorizationURL)")

        // Simulate token exchange
        try await Task.sleep(for: .milliseconds(500))

        return MCPCredentials(
            type: .oauth,
            accessToken: "simulated_access_token_\(UUID().uuidString)",
            refreshToken: "simulated_refresh_token_\(UUID().uuidString)",
            expiresAt: Date().addingTimeInterval(3600)
        )
        #else
        throw MCPConnectionError.oauthNotSupported
        #endif
    }

    private func refreshOAuthToken(refreshToken: String, serverURL: URL) async throws -> MCPCredentials {
        // In production, this would call the token endpoint
        logger.info("Refreshing OAuth token")

        try await Task.sleep(for: .milliseconds(200))

        return MCPCredentials(
            type: .oauth,
            accessToken: "refreshed_access_token_\(UUID().uuidString)",
            refreshToken: refreshToken,
            expiresAt: Date().addingTimeInterval(3600)
        )
    }

    // MARK: - Persistence

    private func loadConnections() async {
        guard FileManager.default.fileExists(atPath: configURL.path),
              let data = try? Data(contentsOf: configURL),
              let stored = try? JSONDecoder().decode(MCPConnectionStorage.self, from: data) else {
            return
        }

        connections = stored.connections
        namespaces = stored.namespaces
        serviceTokens = stored.serviceTokens
    }

    private func saveConnections() async throws {
        let storage = MCPConnectionStorage(
            connections: connections,
            namespaces: namespaces,
            serviceTokens: serviceTokens
        )
        let data = try JSONEncoder().encode(storage)
        try data.write(to: configURL)
    }

    // MARK: - Helpers

    private func generateSecureToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Models

public struct MCPConnection: Identifiable, Codable, Sendable {
    public let id: String
    public let serverId: String
    public let serverName: String
    public let serverURL: URL
    public var namespace: String
    public var status: MCPConnectionStatus
    public var credentials: MCPCredentials?
    public let connectedAt: Date
    public var lastUsedAt: Date

    public var isActive: Bool {
        status == .connected
    }
}

public enum MCPConnectionStatus: String, Codable, Sendable {
    case connected
    case disconnected
    case authRequired
    case error
}

public struct MCPCredentials: Codable, Sendable {
    public let type: CredentialType
    public let accessToken: String
    public let refreshToken: String?
    public let expiresAt: Date?

    public enum CredentialType: String, Codable, Sendable {
        case apiKey
        case oauth
    }
}

public enum MCPAuthType: Sendable {
    case none
    case apiKey(String)
    case oauth(OAuthConfig)
}

public struct OAuthConfig: Sendable {
    public let authorizationURL: URL
    public let tokenURL: URL
    public let clientId: String
    public let scopes: [String]
    public let redirectURI: URL?

    public init(
        authorizationURL: URL,
        tokenURL: URL,
        clientId: String,
        scopes: [String] = [],
        redirectURI: URL? = nil
    ) {
        self.authorizationURL = authorizationURL
        self.tokenURL = tokenURL
        self.clientId = clientId
        self.scopes = scopes
        self.redirectURI = redirectURI
    }
}

public struct MCPNamespace: Identifiable, Codable, Sendable {
    public let id: String
    public let name: String
    public let description: String?
    public let createdAt: Date
}

public struct ServiceToken: Identifiable, Codable, Sendable {
    public let id: String
    public let name: String
    public let namespace: String
    public let token: String
    public let permissions: ServiceTokenPermissions
    public let createdAt: Date
    public let expiresAt: Date?
    public var lastUsedAt: Date?
}

public struct ServiceTokenPermissions: Codable, Sendable {
    public let allowedTools: [String]? // nil = all tools
    public let deniedTools: [String]?
    public let readOnly: Bool
    public let maxRequestsPerMinute: Int?

    public init(
        allowedTools: [String]? = nil,
        deniedTools: [String]? = nil,
        readOnly: Bool = false,
        maxRequestsPerMinute: Int? = nil
    ) {
        self.allowedTools = allowedTools
        self.deniedTools = deniedTools
        self.readOnly = readOnly
        self.maxRequestsPerMinute = maxRequestsPerMinute
    }

    /// Check if a tool is permitted
    public func isToolPermitted(_ toolName: String) -> Bool {
        // Check denied first
        if let denied = deniedTools, denied.contains(toolName) {
            return false
        }

        // Check allowed
        if let allowed = allowedTools {
            return allowed.contains(toolName)
        }

        // Default: allow all
        return true
    }
}

// MARK: - Storage

struct MCPConnectionStorage: Codable {
    let connections: [MCPConnection]
    let namespaces: [MCPNamespace]
    let serviceTokens: [ServiceToken]
}

// MARK: - Errors

public enum MCPConnectionError: Error, LocalizedError {
    case connectionNotFound
    case authenticationFailed(String)
    case tokenExpired
    case namespaceExists(String)
    case oauthNotSupported
    case invalidToken
    case unauthorized  // Smithery SmitheryAuthorizationError equivalent
    case rateLimited
    case serverError(Int, String)

    public var errorDescription: String? {
        switch self {
        case .connectionNotFound:
            return "Connection not found"
        case .authenticationFailed(let reason):
            return "Authentication failed: \(reason)"
        case .tokenExpired:
            return "Token has expired"
        case .namespaceExists(let name):
            return "Namespace '\(name)' already exists"
        case .oauthNotSupported:
            return "OAuth is not supported on this platform"
        case .invalidToken:
            return "Invalid or expired token"
        case .unauthorized:
            return "Unauthorized - OAuth flow required"
        case .rateLimited:
            return "Rate limited - please try again later"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        }
    }
}

// MARK: - Smithery Agents API Support (from Smithery docs)

/// Agent response model based on Smithery's Agents API
public struct MCPAgentResponse: Codable, Sendable {
    public let id: String
    public let status: AgentResponseStatus
    public let output: String?
    public let error: String?
    public let metadata: [String: String]?
    public let createdAt: Date?
    public let completedAt: Date?

    public enum AgentResponseStatus: String, Codable, Sendable {
        case queued
        case inProgress = "in_progress"
        case completed
        case failed
        case incomplete
    }
}

/// Agent request configuration (Smithery pattern)
public struct MCPAgentRequest: Sendable {
    public let namespace: String
    public let input: String
    public let model: String?
    public let previousResponseId: String?  // for multi-turn
    public let stream: Bool
    public let background: Bool  // for long-running tasks
    public let instructions: String?
    public let maxToolCalls: Int?
    public let metadata: [String: String]?

    public init(
        namespace: String,
        input: String,
        model: String? = nil,
        previousResponseId: String? = nil,
        stream: Bool = false,
        background: Bool = false,
        instructions: String? = nil,
        maxToolCalls: Int? = nil,
        metadata: [String: String]? = nil
    ) {
        self.namespace = namespace
        self.input = input
        self.model = model
        self.previousResponseId = previousResponseId
        self.stream = stream
        self.background = background
        self.instructions = instructions
        self.maxToolCalls = maxToolCalls
        self.metadata = metadata
    }
}

// MARK: - Token Constraint (Smithery Token Scoping)

/// Policy constraint for service tokens (from Smithery docs)
public struct TokenConstraint: Codable, Sendable {
    public let namespaces: String?  // namespace pattern
    public let resources: [TokenResource]?  // connections, servers, namespaces, skills
    public let operations: [TokenOperation]?  // read, write, execute
    public let metadata: [String: String]?
    public let ttl: String?  // e.g., "1h", "24h"

    public enum TokenResource: String, Codable, Sendable {
        case connections
        case servers
        case namespaces
        case skills
    }

    public enum TokenOperation: String, Codable, Sendable {
        case read
        case write
        case execute
    }

    public init(
        namespaces: String? = nil,
        resources: [TokenResource]? = nil,
        operations: [TokenOperation]? = nil,
        metadata: [String: String]? = nil,
        ttl: String? = nil
    ) {
        self.namespaces = namespaces
        self.resources = resources
        self.operations = operations
        self.metadata = metadata
        self.ttl = ttl
    }
}

// MARK: - Deep Linking Support (Smithery Feature)

/// Handles deep links for one-click MCP installation
public struct MCPDeepLinkHandler {
    public static let scheme = "thea-mcp"

    /// Parse a deep link URL
    public static func parse(url: URL) -> MCPDeepLinkAction? {
        guard url.scheme == scheme else { return nil }

        switch url.host {
        case "install":
            return parseInstallLink(url)
        case "connect":
            return parseConnectLink(url)
        default:
            return nil
        }
    }

    private static func parseInstallLink(_ url: URL) -> MCPDeepLinkAction? {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let queryItems = components?.queryItems else { return nil }

        var params: [String: String] = [:]
        for item in queryItems {
            if let value = item.value {
                params[item.name] = value
            }
        }

        guard let serverId = params["server"] else { return nil }

        return .install(
            serverId: serverId,
            serverName: params["name"],
            config: params["config"]
        )
    }

    private static func parseConnectLink(_ url: URL) -> MCPDeepLinkAction? {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let queryItems = components?.queryItems else { return nil }

        var params: [String: String] = [:]
        for item in queryItems {
            if let value = item.value {
                params[item.name] = value
            }
        }

        guard let serverURL = params["url"].flatMap({ URL(string: $0) }) else { return nil }

        return .connect(
            serverURL: serverURL,
            namespace: params["namespace"]
        )
    }

    /// Generate a deep link for an MCP server
    public static func generateInstallLink(
        serverId: String,
        serverName: String? = nil,
        config: String? = nil
    ) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "install"

        var queryItems = [URLQueryItem(name: "server", value: serverId)]
        if let name = serverName {
            queryItems.append(URLQueryItem(name: "name", value: name))
        }
        if let config = config {
            queryItems.append(URLQueryItem(name: "config", value: config))
        }
        components.queryItems = queryItems

        return components.url
    }
}

public enum MCPDeepLinkAction {
    case install(serverId: String, serverName: String?, config: String?)
    case connect(serverURL: URL, namespace: String?)
}
