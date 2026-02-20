// GenericMCPClient.swift
// Thea — Generic MCP Client
//
// Connects to any MCP-compatible server (local or remote) via HTTP/JSON-RPC 2.0.
// Discovers tools and resources, and makes them available for dynamic registration
// into AnthropicToolCatalog.
//
// MCP Protocol: https://spec.modelcontextprotocol.io/specification/2024-11-05/

import Foundation
import OSLog

// MARK: - MCP Client Info Types

struct MCPClientServerInfo: Sendable {
    let name: String
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    let version: String
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    let protocolVersion: String
    var capabilities: MCPClientCapabilities
}

struct MCPClientCapabilities: Sendable {
    var supportsTools: Bool
    var supportsResources: Bool
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    var supportsPrompts: Bool

    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    static let empty = MCPClientCapabilities(
        supportsTools: false,
        supportsResources: false,
        supportsPrompts: false
    )
}

// MARK: - Generic MCP Client

/// Actor-based MCP client. Connects to one MCP server, discovers its capabilities,
/// and provides a typesafe interface for calling tools and reading resources.
actor GenericMCPClient {
    private let logger = Logger(subsystem: "ai.thea.app", category: "GenericMCPClient")

    let serverURL: URL
    let serverName: String

    private(set) var isConnected = false
    private(set) var serverInfo: MCPClientServerInfo?
    private(set) var availableTools: [MCPToolSpec] = []
    private(set) var availableResources: [MCPResourceSpec] = []

    private var requestCounter = 0
    private let session: URLSession

    init(serverURL: URL, serverName: String? = nil) {
        self.serverURL = serverURL
        self.serverName = serverName ?? serverURL.host ?? "MCP Server"

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    // MARK: - Connection

    /// Initialize connection with MCP server and discover capabilities.
    func connect() async throws {
        logger.info("Connecting to MCP server at \(self.serverURL.absoluteString)")

        let initResponse = try await sendRequest(
            method: "initialize",
            params: [
                "protocolVersion": "2024-11-05",
                "clientInfo": [
                    "name": "Thea",
                    "version": "1.5.0"
                ] as [String: String],
                "capabilities": [
                    "tools": [String: String](),
                    "resources": [String: String]()
                ] as [String: Any]
            ] as [String: Any]
        )

        if let serverInfoDict = initResponse["serverInfo"] as? [String: Any] {
            let name = serverInfoDict["name"] as? String ?? self.serverName
            let version = serverInfoDict["version"] as? String ?? "unknown"
            let protoVersion = initResponse["protocolVersion"] as? String ?? "2024-11-05"

            let caps = initResponse["capabilities"] as? [String: Any] ?? [:]
            serverInfo = MCPClientServerInfo(
                name: name,
                version: version,
                protocolVersion: protoVersion,
                capabilities: MCPClientCapabilities(
                    supportsTools: caps["tools"] != nil,
                    supportsResources: caps["resources"] != nil,
                    supportsPrompts: caps["prompts"] != nil
                )
            )
        }

        isConnected = true

        // Send initialized notification
        try? await sendNotification(method: "notifications/initialized")

        // Discover capabilities
        if serverInfo?.capabilities.supportsTools ?? true {
            availableTools = (try? await listTools()) ?? []
        }
        if serverInfo?.capabilities.supportsResources ?? false {
            availableResources = (try? await listResources()) ?? []
        }

        logger.info("Connected to \(self.serverInfo?.name ?? self.serverName): \(self.availableTools.count) tools, \(self.availableResources.count) resources")
    }

    func disconnect() {
        isConnected = false
        serverInfo = nil
        availableTools = []
        availableResources = []
        logger.info("Disconnected from \(self.serverName)")
    }

    // MARK: - Tool Operations

    /// List all tools available on the server.
    func listTools() async throws -> [MCPToolSpec] {
        let response = try await sendRequest(method: "tools/list", params: nil)
        guard let toolsArray = response["tools"] as? [[String: Any]] else { return [] }

        return toolsArray.compactMap { dict -> MCPToolSpec? in
            guard let name = dict["name"] as? String else { return nil }
            let description = dict["description"] as? String ?? ""
            return MCPToolSpec(name: name, description: description)
        }
    }

    /// Call a tool on the server with the given arguments.
    func callTool(_ name: String, arguments: sending [String: Any] = [:]) async throws -> MCPToolResult {
        var params: [String: Any] = ["name": name]
        if !arguments.isEmpty {
            params["arguments"] = arguments
        }

        let response = try await sendRequest(method: "tools/call", params: params)

        let contentArray = response["content"] as? [[String: Any]] ?? []
        let contents = contentArray.map { dict -> MCPContent in
            MCPContent(type: dict["type"] as? String ?? "text", text: dict["text"] as? String)
        }
        let isError = response["isError"] as? Bool ?? false

        return MCPToolResult(content: contents, isError: isError)
    }

    // MARK: - Resource Operations

    /// List all resources available on the server.
    func listResources() async throws -> [MCPResourceSpec] {
        let response = try await sendRequest(method: "resources/list", params: nil)
        guard let resourcesArray = response["resources"] as? [[String: Any]] else { return [] }

        return resourcesArray.compactMap { dict -> MCPResourceSpec? in
            guard let uri = dict["uri"] as? String,
                  let name = dict["name"] as? String else { return nil }
            let description = dict["description"] as? String ?? ""
            let mimeType = dict["mimeType"] as? String
            return MCPResourceSpec(name: name, description: description, uriTemplate: uri, mimeType: mimeType ?? "text/plain")
        }
    }

    /// Read the content of a resource by URI.
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    func readResource(_ uri: String) async throws -> String {
        let response = try await sendRequest(method: "resources/read", params: ["uri": uri])

        if let contentsArray = response["contents"] as? [[String: Any]],
           let first = contentsArray.first,
           let text = first["text"] as? String {
            return text
        }
        return ""
    }

    // MARK: - JSON-RPC Transport

    private func nextRequestID() -> String {
        requestCounter += 1
        return "\(requestCounter)"
    }

    private func sendNotification(method: String, params: [String: Any]? = nil) async throws {
        var body: [String: Any] = ["jsonrpc": "2.0", "method": method]
        if let params { body["params"] = params }
        _ = try? await rawRequest(body: body)
    }

    private func sendRequest(method: String, params: [String: Any]?) async throws -> [String: Any] {
        var body: [String: Any] = [
            "jsonrpc": "2.0",
            "id": nextRequestID(),
            "method": method
        ]
        if let params { body["params"] = params }

        let data = try await rawRequest(body: body)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MCPError.internalError("Could not parse JSON-RPC response")
        }

        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            throw MCPError.internalError("MCP error: \(message)")
        }

        return json["result"] as? [String: Any] ?? [:]
    }

    private func rawRequest(body: [String: Any]) async throws -> Data {
        var request = URLRequest(url: serverURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw MCPError.internalError("HTTP \(httpResponse.statusCode)")
        }

        return data
    }
}
