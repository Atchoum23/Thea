//
//  MCPServerLifecycleManager.swift
//  Thea
//
//  Autonomous MCP Server lifecycle management.
//  Automatically discovers, installs, updates, and removes MCP servers
//  based on usage patterns and capability requirements.
//
//  Copyright 2026. All rights reserved.
//

import Combine
import Foundation
import os.log

// MARK: - MCP Server Metadata

/// Metadata for an MCP server from registry
public struct MCPServerMetadata: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let author: String
    public let version: String
    public let capabilities: [MCPCapability]
    public let installCommand: String?
    public let configTemplate: [String: String]?
    public let sourceUrl: String?
    public let registryUrl: String?
    public let trustScore: Double  // 0-10
    public let downloadCount: Int
    public let lastUpdated: Date

    enum CodingKeys: String, CodingKey {
        case id, name, description, author, version, capabilities
        case installCommand, configTemplate, sourceUrl, registryUrl, trustScore
        case downloadCount, lastUpdated
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        author = try container.decode(String.self, forKey: .author)
        version = try container.decode(String.self, forKey: .version)
        capabilities = try container.decode([MCPCapability].self, forKey: .capabilities)
        installCommand = try container.decodeIfPresent(String.self, forKey: .installCommand)
        configTemplate = try container.decodeIfPresent([String: String].self, forKey: .configTemplate)
        sourceUrl = try container.decodeIfPresent(String.self, forKey: .sourceUrl)
        registryUrl = try container.decodeIfPresent(String.self, forKey: .registryUrl)
        trustScore = try container.decode(Double.self, forKey: .trustScore)
        downloadCount = try container.decode(Int.self, forKey: .downloadCount)
        lastUpdated = try container.decode(Date.self, forKey: .lastUpdated)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(author, forKey: .author)
        try container.encode(version, forKey: .version)
        try container.encode(capabilities, forKey: .capabilities)
        try container.encodeIfPresent(installCommand, forKey: .installCommand)
        try container.encodeIfPresent(configTemplate, forKey: .configTemplate)
        try container.encodeIfPresent(sourceUrl, forKey: .sourceUrl)
        try container.encodeIfPresent(registryUrl, forKey: .registryUrl)
        try container.encode(trustScore, forKey: .trustScore)
        try container.encode(downloadCount, forKey: .downloadCount)
        try container.encode(lastUpdated, forKey: .lastUpdated)
    }

    public init(
        id: String,
        name: String,
        description: String,
        author: String,
        version: String,
        capabilities: [MCPCapability],
        installCommand: String?,
        configTemplate: [String: String]?,
        sourceUrl: String?,
        registryUrl: String?,
        trustScore: Double,
        downloadCount: Int,
        lastUpdated: Date
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.author = author
        self.version = version
        self.capabilities = capabilities
        self.installCommand = installCommand
        self.configTemplate = configTemplate
        self.sourceUrl = sourceUrl
        self.registryUrl = registryUrl
        self.trustScore = trustScore
        self.downloadCount = downloadCount
        self.lastUpdated = lastUpdated
    }
}

/// Capability provided by an MCP server
public struct MCPCapability: Codable, Hashable, Sendable {
    public let name: String
    public let category: CapabilityCategory
    public let description: String

    public enum CapabilityCategory: String, Codable, Sendable, CaseIterable {
        case filesystem       // File operations
        case browser          // Web browsing/automation
        case database         // Database access
        case api              // API integrations
        case code             // Code execution/analysis
        case search           // Search capabilities
        case communication    // Email, messaging, etc.
        case productivity     // Calendar, notes, tasks
        case media            // Image, audio, video
        case system           // System control
        case ai               // AI/ML capabilities
        case documentation    // Documentation lookup
        case custom           // Custom capabilities
    }
}

/// Installation status of an MCP server
public enum MCPInstallationStatus: String, Codable, Sendable {
    case notInstalled
    case installing
    case installed
    case updateAvailable
    case updating
    case failed
    case removing
}

/// Usage statistics for an installed server
public struct MCPServerUsageStats: Codable, Sendable {
    public var callCount: Int = 0
    public var lastUsed: Date?
    public var successRate: Double = 1.0
    public var averageLatency: TimeInterval = 0
    public var errorCount: Int = 0
    public var capabilitiesUsed: Set<String> = []

    public var daysSinceLastUse: Int {
        guard let last = lastUsed else { return Int.max }
        return Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? Int.max
    }
}

// MARK: - Installed Server

/// Represents an installed MCP server
public struct InstalledMCPServer: Codable, Identifiable, Sendable {
    public let id: String
    public let metadata: MCPServerMetadata
    public var status: MCPInstallationStatus
    public var installedAt: Date
    public var lastUpdated: Date
    public var configPath: String?
    public var usageStats: MCPServerUsageStats
    public var isEnabled: Bool

    public init(
        metadata: MCPServerMetadata,
        status: MCPInstallationStatus = .installed,
        installedAt: Date = Date(),
        configPath: String? = nil
    ) {
        self.id = metadata.id
        self.metadata = metadata
        self.status = status
        self.installedAt = installedAt
        self.lastUpdated = installedAt
        self.configPath = configPath
        self.usageStats = MCPServerUsageStats()
        self.isEnabled = true
    }
}

// MARK: - MCP Server Lifecycle Manager

/// Manages the complete lifecycle of MCP servers
@MainActor
public final class MCPServerLifecycleManager: ObservableObject {
    public static let shared = MCPServerLifecycleManager()

    private let logger = Logger(subsystem: "ai.thea.app", category: "MCPLifecycle")

    // MARK: - Published State

    /// All installed MCP servers
    @Published public private(set) var installedServers: [InstalledMCPServer] = []

    /// Available servers from registries
    @Published public private(set) var availableServers: [MCPServerMetadata] = []

    /// Whether discovery is in progress
    @Published public private(set) var isDiscovering: Bool = false

    /// Currently installing/updating servers
    @Published public private(set) var pendingOperations: Set<String> = []

    // MARK: - Configuration

    /// Maximum days of inactivity before suggesting removal
    public var inactivityThresholdDays: Int = 30

    /// Minimum trust score for auto-installation
    public var minTrustScoreForAutoInstall: Double = 7.0

    /// Whether to auto-update servers
    public var autoUpdateEnabled: Bool = true

    /// Whether to auto-remove unused servers
    public var autoRemoveUnused: Bool = false

    // MARK: - Native Capability Implementations

    /// Capabilities that Thea implements natively (no MCP needed)
    public let nativeCapabilities: Set<String> = [
        "filesystem.read",
        "filesystem.write",
        "filesystem.search",
        "process.execute",
        "clipboard.read",
        "clipboard.write",
        "notifications.send"
    ]

    // MARK: - Private State

    private let defaults = UserDefaults.standard
    private let storageKey = "thea.mcp.installedServers"
    private var cancellables = Set<AnyCancellable>()

    // Registry sources
    private let registrySources: [RegistrySource] = [
        RegistrySource(name: "Smithery", baseUrl: "https://smithery.ai/api"),
        RegistrySource(name: "MCP Hub", baseUrl: "https://mcphub.io/api"),
        RegistrySource(name: "Official", baseUrl: "https://mcp.anthropic.com/api")
    ]

    private struct RegistrySource {
        let name: String
        let baseUrl: String
    }

    // MARK: - Initialization

    private init() {
        loadInstalledServers()
        startPeriodicTasks()
    }

    // MARK: - Discovery

    /// Discover available MCP servers from all registries
    public func discoverServers() async {
        isDiscovering = true
        defer { isDiscovering = false }

        var allServers: [MCPServerMetadata] = []

        for source in registrySources {
            do {
                let servers = try await fetchServersFromRegistry(source)
                allServers.append(contentsOf: servers)
                logger.info("Discovered \(servers.count) servers from \(source.name)")
            } catch {
                logger.warning("Failed to fetch from \(source.name): \(error.localizedDescription)")
            }
        }

        // Deduplicate by ID, preferring higher trust scores
        var serverMap: [String: MCPServerMetadata] = [:]
        for server in allServers {
            if let existing = serverMap[server.id] {
                if server.trustScore > existing.trustScore {
                    serverMap[server.id] = server
                }
            } else {
                serverMap[server.id] = server
            }
        }

        availableServers = Array(serverMap.values)
            .sorted { $0.trustScore > $1.trustScore }

        logger.info("Total available servers: \(self.availableServers.count)")
    }

    /// Search for servers that provide specific capabilities
    public func searchServers(for capabilities: [MCPCapability.CapabilityCategory]) async -> [MCPServerMetadata] {
        if availableServers.isEmpty {
            await discoverServers()
        }

        return availableServers.filter { server in
            server.capabilities.contains { cap in
                capabilities.contains(cap.category)
            }
        }
    }

    /// Find best server for a specific capability
    public func findBestServer(for capability: MCPCapability.CapabilityCategory) async -> MCPServerMetadata? {
        // First check if we have native implementation
        // (would need mapping from category to native capability names)

        // Then check installed servers
        let installed = installedServers.first { server in
            server.isEnabled && server.metadata.capabilities.contains { $0.category == capability }
        }

        if let installed = installed {
            return installed.metadata
        }

        // Search available servers
        let candidates = await searchServers(for: [capability])
        return candidates.first { $0.trustScore >= minTrustScoreForAutoInstall }
    }

    // MARK: - Installation

    /// Install an MCP server
    public func installServer(_ server: MCPServerMetadata) async throws {
        guard !installedServers.contains(where: { $0.id == server.id }) else {
            logger.warning("Server \(server.id) is already installed")
            return
        }

        pendingOperations.insert(server.id)
        defer { pendingOperations.remove(server.id) }

        logger.info("Installing MCP server: \(server.name)")

        // Execute install command if provided
        if let command = server.installCommand {
            try await executeInstallCommand(command, for: server)
        }

        // Create configuration file
        let configPath = try await createConfiguration(for: server)

        // Add to installed list
        var installed = InstalledMCPServer(
            metadata: server,
            status: .installed,
            configPath: configPath
        )
        installed.status = .installed

        installedServers.append(installed)
        saveInstalledServers()

        logger.info("Successfully installed: \(server.name)")

        // Notify system
        NotificationCenter.default.post(
            name: .mcpServerInstalled,
            object: nil,
            userInfo: ["serverId": server.id]
        )
    }

    /// Uninstall an MCP server
    public func uninstallServer(_ serverId: String) async throws {
        guard let index = installedServers.firstIndex(where: { $0.id == serverId }) else {
            throw MCPLifecycleError.serverNotFound
        }

        let server = installedServers[index]
        pendingOperations.insert(serverId)
        defer { pendingOperations.remove(serverId) }

        installedServers[index].status = .removing

        // Remove configuration file
        if let configPath = server.configPath {
            try? FileManager.default.removeItem(atPath: configPath)
        }

        // Remove from list
        installedServers.remove(at: index)
        saveInstalledServers()

        logger.info("Uninstalled MCP server: \(server.metadata.name)")

        NotificationCenter.default.post(
            name: .mcpServerUninstalled,
            object: nil,
            userInfo: ["serverId": serverId]
        )
    }

    /// Update an installed server
    public func updateServer(_ serverId: String) async throws {
        guard let index = installedServers.firstIndex(where: { $0.id == serverId }) else {
            throw MCPLifecycleError.serverNotFound
        }

        // Find latest version in available servers
        guard let latest = availableServers.first(where: { $0.id == serverId }) else {
            throw MCPLifecycleError.updateNotFound
        }

        pendingOperations.insert(serverId)
        defer { pendingOperations.remove(serverId) }

        installedServers[index].status = .updating

        // Re-run install command
        if let command = latest.installCommand {
            try await executeInstallCommand(command, for: latest)
        }

        // Update metadata
        installedServers[index] = InstalledMCPServer(
            metadata: latest,
            status: .installed,
            installedAt: installedServers[index].installedAt,
            configPath: installedServers[index].configPath
        )
        installedServers[index].lastUpdated = Date()
        installedServers[index].usageStats = installedServers[index].usageStats

        saveInstalledServers()

        logger.info("Updated MCP server: \(latest.name) to v\(latest.version)")
    }

    // MARK: - Usage Tracking

    /// Record usage of a server capability
    public func recordUsage(
        serverId: String,
        capability: String,
        success: Bool,
        latency: TimeInterval
    ) {
        guard let index = installedServers.firstIndex(where: { $0.id == serverId }) else {
            return
        }

        var stats = installedServers[index].usageStats
        stats.callCount += 1
        stats.lastUsed = Date()
        stats.capabilitiesUsed.insert(capability)

        if !success {
            stats.errorCount += 1
        }

        // Update average latency (exponential moving average)
        let alpha = 0.2
        stats.averageLatency = stats.averageLatency * (1 - alpha) + latency * alpha

        // Update success rate
        stats.successRate = Double(stats.callCount - stats.errorCount) / Double(stats.callCount)

        installedServers[index].usageStats = stats

        // Debounced save
        saveInstalledServersDebounced()
    }

    // MARK: - Optimization

    /// Analyze and optimize the server portfolio
    public func optimizePortfolio() async -> PortfolioOptimizationResult {
        var result = PortfolioOptimizationResult()

        // Find unused servers
        for server in installedServers {
            if server.usageStats.daysSinceLastUse > inactivityThresholdDays {
                result.unusedServers.append(server.id)
            }
        }

        // Find servers with low success rates
        for server in installedServers {
            if server.usageStats.successRate < 0.8 && server.usageStats.callCount > 10 {
                result.problematicServers.append(server.id)
            }
        }

        // Find better alternatives for problematic servers
        for serverId in result.problematicServers {
            if let server = installedServers.first(where: { $0.id == serverId }) {
                for capability in server.metadata.capabilities {
                    if let better = await findBetterAlternative(for: capability.category, than: serverId) {
                        result.suggestedReplacements[serverId] = better.id
                        break
                    }
                }
            }
        }

        // Find capabilities that could be handled natively
        for server in installedServers {
            let nativeReplaceable = server.metadata.capabilities.filter { cap in
                nativeCapabilities.contains(cap.name)
            }
            if !nativeReplaceable.isEmpty {
                result.nativeReplaceable[server.id] = nativeReplaceable.map(\.name)
            }
        }

        // Auto-remove if enabled
        if autoRemoveUnused {
            for serverId in result.unusedServers {
                do {
                    try await uninstallServer(serverId)
                    result.actionsPerformed.append("Removed unused: \(serverId)")
                } catch {
                    logger.warning("Failed to auto-remove \(serverId): \(error.localizedDescription)")
                }
            }
        }

        return result
    }

    /// Find a better alternative for a capability
    private func findBetterAlternative(
        for capability: MCPCapability.CapabilityCategory,
        than currentServerId: String
    ) async -> MCPServerMetadata? {
        let candidates = await searchServers(for: [capability])

        guard let current = installedServers.first(where: { $0.id == currentServerId }) else {
            return candidates.first
        }

        return candidates.first { candidate in
            candidate.id != currentServerId &&
            candidate.trustScore > current.metadata.trustScore
        }
    }

    // MARK: - Native Capability Internalization

    /// Check if a capability can be handled natively
    public func canHandleNatively(_ capability: String) -> Bool {
        nativeCapabilities.contains(capability)
    }

    /// Suggest capabilities that should be internalized
    public func suggestInternalization() -> [MCPCapability] {
        var suggestions: [MCPCapability] = []

        for server in installedServers {
            for capability in server.metadata.capabilities {
                // High usage capabilities are good candidates for internalization
                if server.usageStats.capabilitiesUsed.contains(capability.name),
                   server.usageStats.callCount > 100 {
                    suggestions.append(capability)
                }
            }
        }

        return suggestions
    }

    // MARK: - Private Methods

    private func fetchServersFromRegistry(_ source: RegistrySource) async throws -> [MCPServerMetadata] {
        // This would make actual API calls to the registry
        // For now, return empty as we'll implement the actual API integration
        []
    }

    private func executeInstallCommand(_ command: String, for server: MCPServerMetadata) async throws {
        #if os(macOS)
        // Execute npm/pip/etc. install command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
            throw MCPLifecycleError.installFailed(output ?? "Unknown error")
        }
        #else
        // iOS doesn't support running local processes
        throw MCPLifecycleError.installFailed("Local MCP installation not supported on iOS")
        #endif
    }

    private func createConfiguration(for server: MCPServerMetadata) async throws -> String {
        let configDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Thea/mcp-configs", isDirectory: true)

        try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)

        let configPath = configDir.appendingPathComponent("\(server.id).json")

        // Create default config
        let config: [String: Any] = [
            "serverId": server.id,
            "version": server.version,
            "enabled": true
        ]

        let data = try JSONSerialization.data(withJSONObject: config, options: .prettyPrinted)
        try data.write(to: configPath)

        return configPath.path
    }

    private func loadInstalledServers() {
        guard let data = defaults.data(forKey: storageKey) else { return }

        do {
            installedServers = try JSONDecoder().decode([InstalledMCPServer].self, from: data)
            logger.info("Loaded \(self.installedServers.count) installed MCP servers")
        } catch {
            logger.error("Failed to load installed servers: \(error.localizedDescription)")
        }
    }

    private func saveInstalledServers() {
        do {
            let data = try JSONEncoder().encode(installedServers)
            defaults.set(data, forKey: storageKey)
        } catch {
            logger.error("Failed to save installed servers: \(error.localizedDescription)")
        }
    }

    private var saveDebounceTask: Task<Void, Never>?

    private func saveInstalledServersDebounced() {
        saveDebounceTask?.cancel()
        saveDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            if !Task.isCancelled {
                saveInstalledServers()
            }
        }
    }

    private func startPeriodicTasks() {
        // Daily optimization check
        Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                _ = await self?.optimizePortfolio()
            }
        }

        // Hourly discovery refresh
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.discoverServers()
            }
        }
    }
}

// MARK: - Supporting Types

public struct PortfolioOptimizationResult {
    public var unusedServers: [String] = []
    public var problematicServers: [String] = []
    public var suggestedReplacements: [String: String] = [:]
    public var nativeReplaceable: [String: [String]] = [:]
    public var actionsPerformed: [String] = []
}

public enum MCPLifecycleError: Error {
    case serverNotFound
    case installFailed(String)
    case updateNotFound
    case configurationError(String)
}

// MARK: - Notifications

public extension Notification.Name {
    static let mcpServerInstalled = Notification.Name("thea.mcp.serverInstalled")
    static let mcpServerUninstalled = Notification.Name("thea.mcp.serverUninstalled")
    static let mcpServerUpdated = Notification.Name("thea.mcp.serverUpdated")
}
