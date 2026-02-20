// MCPClientManager.swift
// Thea — MCP Client Manager
//
// Manages multiple concurrent MCP server connections.
// Auto-discovers local MCP servers and registers their tools with AnthropicToolCatalog.

import Foundation
import OSLog

// Swift 6: [String: Any] (JSON-compatible dict) is effectively Sendable
// because Dictionary is a value type and JSON primitives are all value types.
extension Dictionary: @retroactive @unchecked Sendable where Key == String, Value == Any {}

// MARK: - Connected MCP Server

@MainActor
@Observable
final class ConnectedMCPServer: Identifiable, Hashable {

    nonisolated static func == (lhs: ConnectedMCPServer, rhs: ConnectedMCPServer) -> Bool { lhs.id == rhs.id }
    nonisolated func hash(into hasher: inout Hasher) { hasher.combine(id) }

    let id: UUID
    let url: URL
    var name: String
    var isConnecting: Bool = false
    var isConnected: Bool = false
    var toolCount: Int = 0
    var resourceCount: Int = 0
    var lastError: String?
    var connectedAt: Date?
    let client: GenericMCPClient

    init(url: URL, name: String? = nil) {
        self.id = UUID()
        self.url = url
        self.name = name ?? url.host ?? "MCP Server"
        self.client = GenericMCPClient(serverURL: url, serverName: name)
    }
}

// MARK: - MCP Client Manager

@MainActor
@Observable
final class MCPClientManager {
    static let shared = MCPClientManager()

    private let logger = Logger(subsystem: "ai.thea.app", category: "MCPClientManager")

    // MARK: - State

    var connectedServers: [ConnectedMCPServer] = []
    var discoveredServers: [MCPDiscoveredServer] = []
    var isDiscovering: Bool = false

    private init() {
        Task { await loadSavedServers() }
        Task { await discoverLocalServers() }
    }

    // MARK: - Connection Management

    func connect(to url: URL, name: String? = nil) async {
        guard !connectedServers.contains(where: { $0.url == url }) else {
            logger.info("Already connected to \(url.absoluteString)")
            return
        }

        let server = ConnectedMCPServer(url: url, name: name)
        server.isConnecting = true
        connectedServers.append(server)

        do {
            try await server.client.connect()

            let tools = await server.client.availableTools
            let resources = await server.client.availableResources
            server.isConnected = true
            server.isConnecting = false
            server.toolCount = tools.count
            server.resourceCount = resources.count
            server.connectedAt = Date()
            server.lastError = nil

            // Register dynamic tools in AnthropicToolCatalog
            registerDynamicTools(from: server)
            saveServers()

            logger.info("Connected to \(server.name): \(tools.count) tools, \(resources.count) resources")
        } catch {
            server.isConnecting = false
            server.isConnected = false
            server.lastError = error.localizedDescription
            logger.error("Failed to connect to \(url.absoluteString): \(error.localizedDescription)")
        }
    }

    func disconnect(server: ConnectedMCPServer) async {
        await server.client.disconnect()
        server.isConnected = false
        connectedServers.removeAll { $0.id == server.id }
        saveServers()

        logger.info("Disconnected from \(server.name)")
    }

    func reconnect(server: ConnectedMCPServer) async {
        server.isConnecting = true
        server.lastError = nil

        do {
            try await server.client.connect()

            let tools = await server.client.availableTools
            let resources = await server.client.availableResources
            server.isConnected = true
            server.isConnecting = false
            server.toolCount = tools.count
            server.resourceCount = resources.count
            server.connectedAt = Date()
        } catch {
            server.isConnecting = false
            server.isConnected = false
            server.lastError = error.localizedDescription
        }
    }

    // MARK: - Dynamic Tool Registration

    /// Register all tools from a connected MCP server into AnthropicToolCatalog
    private func registerDynamicTools(from server: ConnectedMCPServer) {
        Task {
            let tools = await server.client.availableTools
            let catalog = AnthropicToolCatalog.shared
            for tool in tools {
                let toolName = "\(server.name.lowercased().replacingOccurrences(of: " ", with: "_"))__\(tool.name)"
                catalog.registerDynamicTool(
                    name: toolName,
                    description: "[\(server.name)] \(tool.description)"
                ) { [weak server] input in
                        guard let client = server?.client else {
                            return MCPToolResult(content: [MCPContent(type: "text", text: "Server disconnected")], isError: true)
                        }
                        // JSON roundtrip creates a fresh locally-owned [String: Any],
                        // satisfying Swift 6 sending ownership for the actor call.
                        let argsData = (try? JSONSerialization.data(withJSONObject: input)) ?? Data()
                        let args = (try? JSONSerialization.jsonObject(with: argsData) as? [String: Any]) ?? [:]
                        return try await client.callTool(tool.name, arguments: args)
                }
            }
            logger.info("Registered \(tools.count) dynamic tools from \(server.name)")
        }
    }

    // MARK: - Discovery

    func discoverLocalServers() async {
        isDiscovering = true
        defer { isDiscovering = false }

        // Well-known local MCP server ports
        let candidatePorts = [3000, 3001, 8080, 8081, 18789, 9000, 7777]
        var discovered: [MCPDiscoveredServer] = []

        await withTaskGroup(of: MCPDiscoveredServer?.self) { group in
            for port in candidatePorts {
                group.addTask {
                    guard let url = URL(string: "http://localhost:\(port)") else { return nil }
                    let client = GenericMCPClient(serverURL: url)
                    do {
                        try await client.connect()
                        let info = await client.serverInfo
                        await client.disconnect()
                        return MCPDiscoveredServer(
                            url: url,
                            name: info?.name ?? "Server on :\(port)",
                            port: port
                        )
                    } catch {
                        return nil
                    }
                }
            }

            for await result in group {
                if let server = result {
                    discovered.append(server)
                }
            }
        }

        discoveredServers = discovered.filter { d in
            !connectedServers.contains { $0.url == d.url }
        }

        logger.info("Discovered \(discovered.count) local MCP servers")
    }

    // MARK: - Persistence

    private let savedServersKey = "thea.mcp.savedServers"

    private func saveServers() {
        let urls = connectedServers.map { [$0.url.absoluteString: $0.name] }
        UserDefaults.standard.set(urls, forKey: savedServersKey)
    }

    private func loadSavedServers() async {
        guard let saved = UserDefaults.standard.array(forKey: savedServersKey) as? [[String: String]] else { return }

        for entry in saved {
            if let urlString = entry.keys.first,
               let name = entry.values.first,
               let url = URL(string: urlString) {
                await connect(to: url, name: name)
            }
        }
    }
}

// MARK: - Discovered Server

struct MCPDiscoveredServer: Identifiable, Sendable {
    let id = UUID()
    let url: URL
    let name: String
    let port: Int
}
