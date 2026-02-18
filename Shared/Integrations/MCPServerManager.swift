//
//  MCPServerManager.swift
//  Thea
//
//  Created by Claude Code on 2026-01-22
//  Copyright © 2026. All rights reserved.
//

import Combine
import Foundation
import OSLog

// MARK: - MCP Server Manager

#if os(macOS)
    /// Comprehensive MCP server discovery, management, and execution
    @MainActor
    public class MCPServerManager: ObservableObject {
        public static let shared = MCPServerManager()

        private let logger = Logger(subsystem: "com.thea.app", category: "MCPServerManager")

        // MARK: - Published State

        @Published public private(set) var installedServers: [MCPInstalledServer] = []
        @Published public private(set) var runningServers: [String: MCPRunningServer] = [:]
        @Published public private(set) var availableTools: [MCPTool] = []
        @Published public private(set) var registryServers: [MCPRegistryServer] = []
        @Published public private(set) var isDiscovering = false

        // MARK: - Configuration Paths

        private let claudeConfigPath: URL
        private let theaConfigPath: URL
        private let serverCachePath: URL

        // MARK: - Process Management

        private var serverProcesses: [String: Process] = [:]
        private var serverPipes: [String: (input: Pipe, output: Pipe, error: Pipe)] = [:]

        // MARK: - Initialization

        private init() {
            let home = FileManager.default.homeDirectoryForCurrentUser
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory

            claudeConfigPath = home.appendingPathComponent("Library/Application Support/Claude/claude_desktop_config.json")
            theaConfigPath = appSupport.appendingPathComponent("Thea/mcp_servers.json")
            serverCachePath = appSupport.appendingPathComponent("Thea/mcp_registry_cache.json")

            // Create directories
            do {
                try FileManager.default.createDirectory(at: theaConfigPath.deletingLastPathComponent(), withIntermediateDirectories: true)
            } catch {
                logger.debug("Could not create Thea config directory: \(error.localizedDescription)")
            }

            // Load servers
            Task {
                await loadServers()
                await discoverFromRegistry()
            }
        }

        // MARK: - Load Servers

        private func loadServers() async {
            // Load from Claude config
            if let claudeServers = loadClaudeServers() {
                for (name, config) in claudeServers {
                    let server = MCPInstalledServer(
                        id: "claude-\(name)",
                        name: name,
                        command: config.command,
                        args: config.args ?? [],
                        env: config.env ?? [:],
                        source: .claude,
                        isEnabled: true
                    )
                    installedServers.append(server)
                }
            }

            // Load from Thea config
            if let theaServers = loadTheaServers() {
                installedServers.append(contentsOf: theaServers)
            }

            // Discover tools from installed servers
            await discoverToolsFromInstalledServers()
        }

        private func loadClaudeServers() -> [String: MCPServerConfig]? {
            guard FileManager.default.fileExists(atPath: claudeConfigPath.path) else { return nil }
            do {
                let data = try Data(contentsOf: claudeConfigPath)
                let config = try JSONDecoder().decode(ClaudeDesktopConfig.self, from: data)
                return config.mcpServers
            } catch {
                logger.debug("Could not load Claude servers: \(error.localizedDescription)")
                return nil
            }
        }

        private func loadTheaServers() -> [MCPInstalledServer]? {
            guard FileManager.default.fileExists(atPath: theaConfigPath.path) else { return nil }
            do {
                let data = try Data(contentsOf: theaConfigPath)
                let servers = try JSONDecoder().decode([MCPInstalledServer].self, from: data)
                return servers
            } catch {
                logger.debug("Could not load Thea servers: \(error.localizedDescription)")
                return nil
            }
        }

        // MARK: - Registry Discovery

        /// Discover servers from MCP registry
        public func discoverFromRegistry() async {
            isDiscovering = true
            defer { isDiscovering = false }

            // Check cache first
            if let cached = loadRegistryCache() {
                registryServers = cached
            }

            // Fetch from registry (using official MCP registry API)
            do {
                let registryURL = URL(string: "https://api.mcp.run/servers")!
                let (data, _) = try await URLSession.shared.data(from: registryURL)

                let response = try JSONDecoder().decode(MCPRegistryResponse.self, from: data)
                registryServers = response.servers

                // Cache results
                saveRegistryCache(registryServers)
            } catch {
                // Use cached data if fetch fails
            }
        }

        private func loadRegistryCache() -> [MCPRegistryServer]? {
            guard FileManager.default.fileExists(atPath: serverCachePath.path) else { return nil }
            do {
                let data = try Data(contentsOf: serverCachePath)
                let cache = try JSONDecoder().decode(MCPRegistryCache.self, from: data)
                guard Date().timeIntervalSince(cache.timestamp) < 86400 else { return nil } // 24 hour cache
                return cache.servers
            } catch {
                logger.debug("Could not load registry cache: \(error.localizedDescription)")
                return nil
            }
        }

        private func saveRegistryCache(_ servers: [MCPRegistryServer]) {
            let cache = MCPRegistryCache(servers: servers, timestamp: Date())
            do {
                let data = try JSONEncoder().encode(cache)
                try data.write(to: serverCachePath)
            } catch {
                logger.debug("Could not save registry cache: \(error.localizedDescription)")
            }
        }

        // MARK: - Install Server

        /// Install a server from the registry
        public func install(_ registryServer: MCPRegistryServer) async throws {
            // Determine installation method
            let server: MCPInstalledServer = switch registryServer.installMethod {
            case .npm:
                try await installNpmServer(registryServer)
            case .pip:
                try await installPipServer(registryServer)
            case .binary:
                try await installBinaryServer(registryServer)
            case .docker:
                try await installDockerServer(registryServer)
            }

            installedServers.append(server)
            saveTheaServers()
        }

        private func installNpmServer(_ registry: MCPRegistryServer) async throws -> MCPInstalledServer {
            // Install via npm/npx
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["npm", "install", "-g", registry.packageName]

            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                throw MCPServerError.installationFailed("npm install failed")
            }

            return MCPInstalledServer(
                id: UUID().uuidString,
                name: registry.name,
                command: "npx",
                args: [registry.packageName],
                env: [:],
                source: .registry,
                isEnabled: true
            )
        }

        private func installPipServer(_ registry: MCPRegistryServer) async throws -> MCPInstalledServer {
            // Install via pip/uvx
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["pip", "install", registry.packageName]

            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                throw MCPServerError.installationFailed("pip install failed")
            }

            return MCPInstalledServer(
                id: UUID().uuidString,
                name: registry.name,
                command: registry.packageName,
                args: [],
                env: [:],
                source: .registry,
                isEnabled: true
            )
        }

        private func installBinaryServer(_ registry: MCPRegistryServer) async throws -> MCPInstalledServer {
            // Download and install binary
            guard let downloadURL = registry.downloadURL else {
                throw MCPServerError.installationFailed("No download URL")
            }

            let (data, _) = try await URLSession.shared.data(from: downloadURL)

            let binPath = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".local/bin/\(registry.packageName)")

            do {
                try FileManager.default.createDirectory(at: binPath.deletingLastPathComponent(), withIntermediateDirectories: true)
            } catch {
                logger.debug("Could not create bin directory: \(error.localizedDescription)")
            }
            try data.write(to: binPath)

            // Make executable
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: binPath.path)

            return MCPInstalledServer(
                id: UUID().uuidString,
                name: registry.name,
                command: binPath.path,
                args: [],
                env: [:],
                source: .registry,
                isEnabled: true
            )
        }

        private func installDockerServer(_ registry: MCPRegistryServer) async throws -> MCPInstalledServer {
            // Pull Docker image
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/local/bin/docker")
            process.arguments = ["pull", registry.dockerImage ?? registry.packageName]

            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                throw MCPServerError.installationFailed("docker pull failed")
            }

            return MCPInstalledServer(
                id: UUID().uuidString,
                name: registry.name,
                command: "docker",
                args: ["run", "-i", registry.dockerImage ?? registry.packageName],
                env: [:],
                source: .registry,
                isEnabled: true
            )
        }

        // MARK: - Start/Stop Servers

        /// Start an MCP server
        public func start(_ server: MCPInstalledServer) async throws {
            guard runningServers[server.id] == nil else { return }

            let process = Process()

            // Find executable
            if server.command.hasPrefix("/") {
                process.executableURL = URL(fileURLWithPath: server.command)
            } else {
                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = [server.command] + server.args
            }

            // Set environment
            var env = ProcessInfo.processInfo.environment
            for (key, value) in server.env {
                env[key] = value
            }
            process.environment = env

            // Setup pipes for JSON-RPC communication
            let inputPipe = Pipe()
            let outputPipe = Pipe()
            let errorPipe = Pipe()

            process.standardInput = inputPipe
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            try process.run()

            serverProcesses[server.id] = process
            serverPipes[server.id] = (inputPipe, outputPipe, errorPipe)

            // Initialize connection
            let runningServer = MCPRunningServer(
                server: server,
                processId: process.processIdentifier,
                startedAt: Date()
            )
            runningServers[server.id] = runningServer

            // Discover tools
            await discoverTools(from: server.id)
        }

        /// Stop an MCP server
        public func stop(_ serverId: String) {
            guard let process = serverProcesses[serverId] else { return }

            process.terminate()
            serverProcesses.removeValue(forKey: serverId)
            serverPipes.removeValue(forKey: serverId)
            runningServers.removeValue(forKey: serverId)

            // Remove tools from this server
            availableTools.removeAll { $0.serverId == serverId }
        }

        /// Stop all servers
        public func stopAll() {
            for serverId in serverProcesses.keys {
                stop(serverId)
            }
        }

        // MARK: - Tool Discovery

        private func discoverToolsFromInstalledServers() async {
            for server in installedServers where server.isEnabled {
                // For now, add mock tools based on server type
                let tools = getDefaultTools(for: server)
                availableTools.append(contentsOf: tools)
            }
        }

        private func discoverTools(from serverId: String) async {
            guard let pipes = serverPipes[serverId] else { return }

            // Send tools/list request via JSON-RPC
            let request = MCPServerRequest(
                jsonrpc: "2.0",
                id: UUID().uuidString,
                method: "tools/list",
                params: nil
            )

            do {
                let requestData = try JSONEncoder().encode(request)
                pipes.input.fileHandleForWriting.write(requestData)
                pipes.input.fileHandleForWriting.write(Data("\n".utf8))

                // Read response (simplified - real implementation would use async reading)
                let responseData = pipes.output.fileHandleForReading.availableData
                do {
                    let response = try JSONDecoder().decode(MCPToolsListResponse.self, from: responseData)
                    for tool in response.result.tools {
                        let mcpTool = MCPTool(
                            id: "\(serverId):\(tool.name)",
                            serverId: serverId,
                            name: tool.name,
                            description: tool.description,
                            inputSchema: tool.inputSchema
                        )
                        availableTools.append(mcpTool)
                    }
                } catch {
                    logger.debug("Could not decode tools list response: \(error.localizedDescription)")
                }
            } catch {
                // Tool discovery failed - use defaults
            }
        }

        private func getDefaultTools(for server: MCPInstalledServer) -> [MCPTool] {
            // Return common tools based on server name patterns
            var tools: [MCPTool] = []

            let name = server.name.lowercased()

            if name.contains("filesystem") || name.contains("file") {
                tools.append(contentsOf: [
                    MCPTool(id: "\(server.id):read_file", serverId: server.id, name: "read_file",
                            description: "Read contents of a file", inputSchema: ["path": "string"]),
                    MCPTool(id: "\(server.id):write_file", serverId: server.id, name: "write_file",
                            description: "Write contents to a file", inputSchema: ["path": "string", "content": "string"]),
                    MCPTool(id: "\(server.id):list_directory", serverId: server.id, name: "list_directory",
                            description: "List directory contents", inputSchema: ["path": "string"])
                ])
            }

            if name.contains("git") {
                tools.append(contentsOf: [
                    MCPTool(id: "\(server.id):git_status", serverId: server.id, name: "git_status",
                            description: "Get git repository status", inputSchema: ["repo_path": "string"]),
                    MCPTool(id: "\(server.id):git_commit", serverId: server.id, name: "git_commit",
                            description: "Create a git commit", inputSchema: ["message": "string"]),
                    MCPTool(id: "\(server.id):git_push", serverId: server.id, name: "git_push",
                            description: "Push commits to remote", inputSchema: [:])
                ])
            }

            if name.contains("browser") || name.contains("puppeteer") {
                tools.append(contentsOf: [
                    MCPTool(id: "\(server.id):navigate", serverId: server.id, name: "navigate",
                            description: "Navigate to a URL", inputSchema: ["url": "string"]),
                    MCPTool(id: "\(server.id):screenshot", serverId: server.id, name: "screenshot",
                            description: "Take a screenshot", inputSchema: [:]),
                    MCPTool(id: "\(server.id):click", serverId: server.id, name: "click",
                            description: "Click an element", inputSchema: ["selector": "string"])
                ])
            }

            return tools
        }

        // MARK: - Execute Tool

        /// Execute a tool on an MCP server
        public func executeTool(
            toolId: String,
            arguments: [String: Any]
        ) async throws -> MCPServerToolResult {
            guard let tool = availableTools.first(where: { $0.id == toolId }),
                  let pipes = serverPipes[tool.serverId]
            else {
                throw MCPServerError.toolNotFound
            }

            // Create JSON-RPC request
            let request = MCPToolCallRequest(
                jsonrpc: "2.0",
                id: UUID().uuidString,
                method: "tools/call",
                params: MCPToolCallParams(name: tool.name, arguments: arguments)
            )

            let requestData = try JSONEncoder().encode(request)
            pipes.input.fileHandleForWriting.write(requestData)
            pipes.input.fileHandleForWriting.write(Data("\n".utf8))

            // Read response
            let responseData = pipes.output.fileHandleForReading.availableData
            let response = try JSONDecoder().decode(MCPToolCallResponse.self, from: responseData)

            return MCPServerToolResult(
                toolId: toolId,
                content: response.result.content,
                isError: response.result.isError ?? false
            )
        }

        // MARK: - Save Configuration

        private func saveTheaServers() {
            let theaServers = installedServers.filter { $0.source == .thea || $0.source == .registry }
            do {
                let data = try JSONEncoder().encode(theaServers)
                try data.write(to: theaConfigPath)
            } catch {
                logger.error("Failed to save Thea servers: \(error.localizedDescription)")
            }
        }

        /// Export server to Claude configuration
        public func exportToClaude(_ server: MCPInstalledServer) throws {
            var config: ClaudeDesktopConfig
            if FileManager.default.fileExists(atPath: claudeConfigPath.path) {
                do {
                    let data = try Data(contentsOf: claudeConfigPath)
                    config = try JSONDecoder().decode(ClaudeDesktopConfig.self, from: data)
                } catch {
                    logger.debug("Could not load existing Claude config, using empty: \(error.localizedDescription)")
                    config = ClaudeDesktopConfig(mcpServers: [:])
                }
            } else {
                config = ClaudeDesktopConfig(mcpServers: [:])
            }

            config.mcpServers[server.name] = MCPServerConfig(
                command: server.command,
                args: server.args,
                env: server.env
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)

            try FileManager.default.createDirectory(at: claudeConfigPath.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: claudeConfigPath)
        }
    }

#else

    // MARK: - iOS/watchOS/tvOS Stub Implementation

    /// Stub implementation for non-macOS platforms
    /// MCP servers require local process execution which is not available on iOS
    @MainActor
    public class MCPServerManager: ObservableObject {
        public static let shared = MCPServerManager()

        @Published public private(set) var installedServers: [MCPInstalledServer] = []
        @Published public private(set) var runningServers: [String: MCPRunningServer] = [:]
        @Published public private(set) var availableTools: [MCPTool] = []
        @Published public private(set) var registryServers: [MCPRegistryServer] = []
        @Published public private(set) var isDiscovering = false

        private init() {}

        public func discoverFromRegistry() async {
            // Not supported on iOS
        }

        public func install(_: MCPRegistryServer) async throws {
            throw MCPServerError.executionFailed("MCP servers are not supported on this platform")
        }

        public func start(_: MCPInstalledServer) async throws {
            throw MCPServerError.executionFailed("MCP servers are not supported on this platform")
        }

        public func stop(_: String) {
            // No-op on iOS
        }

        public func stopAll() {
            // No-op on iOS
        }

        public func executeTool(toolId _: String, arguments _: [String: Any]) async throws -> MCPServerToolResult {
            throw MCPServerError.executionFailed("MCP servers are not supported on this platform")
        }

        public func exportToClaude(_: MCPInstalledServer) throws {
            throw MCPServerError.executionFailed("MCP servers are not supported on this platform")
        }
    }

#endif

// MARK: - Models

public struct MCPInstalledServer: Identifiable, Codable, Sendable {
    public let id: String
    public var name: String
    public var command: String
    public var args: [String]
    public var env: [String: String]
    public var source: MCPServerSource
    public var isEnabled: Bool
}

public enum MCPServerSource: String, Codable, Sendable {
    case claude // From Claude.app config
    case thea // Manually added in Thea
    case registry // Installed from registry
}

public struct MCPRunningServer: Identifiable, Sendable {
    public var id: String { server.id }
    public let server: MCPInstalledServer
    public let processId: Int32
    public let startedAt: Date
}

public struct MCPTool: Identifiable, Sendable {
    public let id: String
    public let serverId: String
    public let name: String
    public let description: String
    public let inputSchema: [String: String]
}

public struct MCPServerToolResult: Sendable {
    public let toolId: String
    public let content: [MCPServerContent]
    public let isError: Bool
}

public struct MCPServerContent: Codable, Sendable {
    public let type: String
    public let text: String?
}

// MARK: - Registry Models

public struct MCPRegistryServer: Identifiable, Codable, Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let packageName: String
    public let version: String
    public let author: String
    public let installMethod: MCPInstallMethod
    public let dockerImage: String?
    public let downloadURL: URL?
    public let category: String
    public let stars: Int
}

public enum MCPInstallMethod: String, Codable, Sendable {
    case npm
    case pip
    case binary
    case docker
}

public struct MCPRegistryResponse: Codable {
    public let servers: [MCPRegistryServer]
}

public struct MCPRegistryCache: Codable {
    public let servers: [MCPRegistryServer]
    public let timestamp: Date
}

// MARK: - JSON-RPC Models

struct MCPServerRequest: Codable {
    let jsonrpc: String
    let id: String
    let method: String
    let params: [String: String]?
}

struct MCPToolsListResponse: Codable {
    let jsonrpc: String
    let id: String
    let result: MCPToolsListResult
}

struct MCPToolsListResult: Codable {
    let tools: [MCPToolDefinition]
}

struct MCPToolDefinition: Codable {
    let name: String
    let description: String
    let inputSchema: [String: String]
}

struct MCPToolCallRequest: Codable {
    let jsonrpc: String
    let id: String
    let method: String
    let params: MCPToolCallParams
}

struct MCPToolCallParams: Codable, Sendable {
    let name: String
    let arguments: [String: MCPAnyCodable]

    enum CodingKeys: String, CodingKey {
        case name, arguments
    }

    init(name: String, arguments: [String: Any]) {
        self.name = name
        self.arguments = arguments.mapValues { MCPAnyCodable($0) }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        arguments = try container.decodeIfPresent([String: MCPAnyCodable].self, forKey: .arguments) ?? [:]
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(arguments, forKey: .arguments)
    }
}

// @unchecked Sendable: type-erased Any storage required for MCP protocol's heterogeneous JSON
// values; values are Codable primitives (String, Int, Double, Bool, Array, Dictionary) in practice
/// Type-erased Codable wrapper for heterogeneous dictionary values in MCP context
struct MCPAnyCodable: Codable, @unchecked Sendable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([MCPAnyCodable].self) {
            value = array.map(\.value)
        } else if let dict = try? container.decode([String: MCPAnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { MCPAnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { MCPAnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

struct MCPToolCallResponse: Codable {
    let jsonrpc: String
    let id: String
    let result: MCPToolCallResult
}

struct MCPToolCallResult: Codable {
    let content: [MCPServerContent]
    let isError: Bool?
}

// MARK: - Errors

public enum MCPServerError: Error, LocalizedError, Sendable {
    case serverNotFound
    case toolNotFound
    case executionFailed(String)
    case installationFailed(String)
    case connectionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .serverNotFound:
            "MCP server not found"
        case .toolNotFound:
            "MCP tool not found"
        case let .executionFailed(reason):
            "Tool execution failed: \(reason)"
        case let .installationFailed(reason):
            "Server installation failed: \(reason)"
        case let .connectionFailed(reason):
            "Server connection failed: \(reason)"
        }
    }
}
