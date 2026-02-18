//
//  ResourceDiscoveryEngine.swift
//  Thea
//
//  Autonomous resource discovery engine that proactively finds and indexes
//  resources, tools, and capabilities from multiple registries including
//  Smithery, Context7, and local MCP servers.
//
//  Resource types, stats, and API response types are in ResourceDiscoveryTypes.swift
//
//  Copyright 2026. All rights reserved.
//

import Combine
import Foundation
import os.log

// MARK: - Discovery Engine

/// Autonomous engine that discovers and indexes resources from multiple registries
@MainActor
public final class ResourceDiscoveryEngine: ObservableObject {
    public static let shared = ResourceDiscoveryEngine()

    private let logger = Logger(subsystem: "ai.thea.app", category: "ResourceDiscovery")

    // MARK: - Published State

    /// All discovered resources indexed by ID
    @Published public private(set) var resources: [UUID: DiscoveredResource] = [:]

    /// Resources grouped by registry
    @Published public private(set) var resourcesByRegistry: [ResourceRegistry: [DiscoveredResource]] = [:]

    /// Resources grouped by capability category
    @Published public private(set) var resourcesByCapability: [ResourceCapability.CapabilityCategory: [DiscoveredResource]] = [:]

    /// Discovery in progress
    @Published public private(set) var isDiscovering: Bool = false

    /// Last discovery error
    @Published public private(set) var lastError: String?

    /// Discovery statistics
    @Published public private(set) var stats = DiscoveryStats()

    // MARK: - Configuration

    /// How often to run background discovery (default: 1 hour)
    @Published public var discoveryInterval: TimeInterval = 3600

    /// Maximum resources to fetch per registry per discovery cycle
    @Published public var maxResourcesPerRegistry: Int = 100

    /// Minimum trust score to include a resource
    @Published public var minimumTrustScore: Double = 0.3

    /// Whether to discover automatically in background
    @Published public var autoDiscoveryEnabled: Bool = true

    // MARK: - API Keys (stored securely in Keychain in production)

    private var smitheryAPIKey: String?
    private var context7APIKey: String?

    // MARK: - Private State

    private var discoveryTask: Task<Void, Never>?
    private var backgroundDiscoveryTask: Task<Void, Never>?
    private let urlSession: URLSession
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.waitsForConnectivity = true
        urlSession = URLSession(configuration: config)

        loadCachedResources()
        startBackgroundDiscovery()

        logger.info("ResourceDiscoveryEngine initialized")
    }

    // MARK: - Public API

    /// Configure API keys for registries
    public func configureAPIKeys(smithery: String? = nil, context7: String? = nil) {
        smitheryAPIKey = smithery
        context7APIKey = context7
        logger.info("API keys configured")
    }

    /// Trigger immediate discovery from all registries
    public func discoverNow() async {
        guard !isDiscovering else {
            logger.debug("Discovery already in progress")
            return
        }

        isDiscovering = true
        lastError = nil
        let startTime = Date()

        defer {
            isDiscovering = false
            stats.lastDiscoveryDuration = Date().timeIntervalSince(startTime)
            stats.lastDiscoveryDate = Date()
        }

        logger.info("Starting resource discovery")

        // Discover from all registries in parallel
        await withTaskGroup(of: [DiscoveredResource].self) { group in
            for registry in ResourceRegistry.allCases {
                group.addTask { [weak self] in
                    guard let self = self else { return [] }
                    return await self.discoverFromRegistry(registry)
                }
            }

            for await registryResources in group {
                for resource in registryResources {
                    self.indexResource(resource)
                }
            }
        }

        rebuildIndices()
        cacheResources()

        stats.totalResources = resources.count
        stats.discoveryCount += 1

        logger.info("Discovery complete: \(self.resources.count) resources indexed")
    }

    /// Search for resources matching a query
    public func search(
        query: String,
        registry: ResourceRegistry? = nil,
        capabilities: Set<ResourceCapability.CapabilityCategory>? = nil,
        minTrustScore: Double? = nil,
        limit: Int = 20
    ) -> [DiscoveredResource] {
        let queryLower = query.lowercased()
        let effectiveMinScore = minTrustScore ?? minimumTrustScore

        var results = resources.values.filter { resource in
            // Filter by registry if specified
            if let registry = registry, resource.sourceRegistry != registry {
                return false
            }

            // Filter by minimum trust score
            if resource.trustScore < effectiveMinScore {
                return false
            }

            // Filter by capabilities if specified
            if let capabilities = capabilities {
                let resourceCategories = Set(resource.capabilities.map(\.category))
                if resourceCategories.isDisjoint(with: capabilities) {
                    return false
                }
            }

            // Search in name, description, tags
            if resource.displayName.lowercased().contains(queryLower) {
                return true
            }
            if resource.description.lowercased().contains(queryLower) {
                return true
            }
            if resource.tags.contains(where: { $0.lowercased().contains(queryLower) }) {
                return true
            }

            // Search in tool names and descriptions
            for tool in resource.tools {
                if tool.name.lowercased().contains(queryLower) {
                    return true
                }
                if tool.description.lowercased().contains(queryLower) {
                    return true
                }
            }

            return false
        }

        // Sort by relevance (trust score * popularity)
        results.sort { a, b in
            let scoreA = a.trustScore * Double(max(1, a.popularity))
            let scoreB = b.trustScore * Double(max(1, b.popularity))
            return scoreA > scoreB
        }

        return Array(results.prefix(limit))
    }

    /// Find resources that provide a specific capability
    public func findByCapability(_ capability: ResourceCapability.CapabilityCategory) -> [DiscoveredResource] {
        resourcesByCapability[capability] ?? []
    }

    /// Get resource by qualified name
    public func getResource(qualifiedName: String, registry: ResourceRegistry) -> DiscoveredResource? {
        resources.values.first { $0.qualifiedName == qualifiedName && $0.sourceRegistry == registry }
    }

    /// Refresh a specific resource
    public func refreshResource(_ resourceId: UUID) async {
        guard let resource = resources[resourceId] else { return }

        if let refreshed = await fetchResourceDetails(resource.qualifiedName, from: resource.sourceRegistry) {
            indexResource(refreshed)
            rebuildIndices()
            cacheResources()
        }
    }

    // MARK: - Registry-Specific Discovery

    private func discoverFromRegistry(_ registry: ResourceRegistry) async -> [DiscoveredResource] {
        switch registry {
        case .smithery:
            return await discoverFromSmithery()
        case .context7:
            return await discoverFromContext7()
        case .mcpHub:
            return await discoverFromMCPHub()
        case .officialMCP:
            return await discoverFromOfficialMCP()
        case .local:
            return discoverLocalResources()
        case .custom:
            return [] // Custom resources are added manually
        }
    }

    // MARK: - Smithery Discovery

    private func discoverFromSmithery() async -> [DiscoveredResource] {
        guard let baseURL = ResourceRegistry.smithery.baseURL else { return [] }

        var resources: [DiscoveredResource] = []

        do {
            // Search for popular and recent servers
            let queries = ["", "is:verified", "is:deployed"]

            for query in queries {
                var components = URLComponents(url: baseURL.appendingPathComponent("servers"), resolvingAgainstBaseURL: false)!
                components.queryItems = [
                    URLQueryItem(name: "q", value: query),
                    URLQueryItem(name: "pageSize", value: "\(maxResourcesPerRegistry / queries.count)")
                ]

                var request = URLRequest(url: components.url!)
                if let apiKey = smitheryAPIKey {
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                }

                let (data, response) = try await urlSession.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    continue
                }

                let decoded = try JSONDecoder().decode(SmitheryServerListResponse.self, from: data)

                for server in decoded.servers {
                    let resource = DiscoveredResource(
                        sourceRegistry: .smithery,
                        qualifiedName: server.qualifiedName,
                        displayName: server.displayName,
                        description: server.description,
                        capabilities: server.tools.map { tool in
                            ResourceCapability(
                                name: tool.name,
                                category: .tools,
                                description: tool.description
                            )
                        },
                        tools: server.tools.map { tool in
                            DiscoveredTool(
                                name: tool.name,
                                description: tool.description
                            )
                        },
                        trustScore: Double(server.trustScore ?? 5) / 10.0,
                        popularity: server.useCount ?? 0,
                        lastUpdated: server.updatedAt ?? Date(),
                        connectionConfig: ResourceConnectionConfig(
                            transportType: server.isHosted ? .websocket : .stdio,
                            endpoint: server.isHosted ? "https://server.smithery.ai/\(server.qualifiedName)/ws" : nil,
                            authType: smitheryAPIKey != nil ? .bearer : .none
                        ),
                        tags: Set(server.tags ?? []),
                        isVerified: server.isVerified ?? false,
                        isHosted: server.isHosted
                    )
                    resources.append(resource)
                }
            }

            logger.debug("Discovered \(resources.count) resources from Smithery")

        } catch {
            logger.error("Smithery discovery failed: \(error.localizedDescription)")
            lastError = "Smithery: \(error.localizedDescription)"
        }

        return resources
    }

    // MARK: - Context7 Discovery

    private func discoverFromContext7() async -> [DiscoveredResource] {
        guard context7APIKey != nil else {
            logger.debug("Context7 API key not configured, skipping")
            return []
        }

        // Context7 provides documentation for libraries, not a list of servers
        // Create a single resource representing the Context7 service
        let resource = DiscoveredResource(
            sourceRegistry: .context7,
            qualifiedName: "context7/documentation",
            displayName: "Context7 Documentation",
            description: "Up-to-date, version-specific documentation for any library. Eliminates hallucinated APIs.",
            capabilities: [
                ResourceCapability(name: "resolve-library-id", category: .documentation, description: "Convert library name to Context7 ID"),
                ResourceCapability(name: "get-library-docs", category: .documentation, description: "Fetch documentation for a library")
            ],
            tools: [
                DiscoveredTool(
                    name: "resolve-library-id",
                    description: "Converts general library names to Context7-compatible IDs",
                    inputSchema: [
                        "libraryName": DiscoveredToolParameter(type: "string", description: "Library name to search", isRequired: true)
                    ]
                ),
                DiscoveredTool(
                    name: "get-library-docs",
                    description: "Retrieves documentation using a Context7-compatible library ID",
                    inputSchema: [
                        "context7CompatibleLibraryID": DiscoveredToolParameter(type: "string", description: "Format /org/project", isRequired: true),
                        "topic": DiscoveredToolParameter(type: "string", description: "Filter by topic", isRequired: false),
                        "tokens": DiscoveredToolParameter(type: "number", description: "Token limit (default 5000)", isRequired: false)
                    ]
                )
            ],
            trustScore: 0.95,
            popularity: 10000,
            connectionConfig: ResourceConnectionConfig(
                transportType: .http,
                endpoint: "https://mcp.context7.com/mcp",
                headers: ["CONTEXT7_API_KEY": context7APIKey!],
                authType: .apiKey
            ),
            tags: ["documentation", "libraries", "api-reference"],
            isVerified: true,
            isHosted: true
        )

        return [resource]
    }

    // MARK: - MCP Hub Discovery

    private func discoverFromMCPHub() async -> [DiscoveredResource] {
        guard let baseURL = ResourceRegistry.mcpHub.baseURL else { return [] }

        var resources: [DiscoveredResource] = []

        do {
            // MCP Hub provides a REST API for server listing
            let url = baseURL.appendingPathComponent("servers")
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            components.queryItems = [
                URLQueryItem(name: "limit", value: "\(maxResourcesPerRegistry)")
            ]

            let request = URLRequest(url: components.url!)
            let (data, response) = try await urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                logger.debug("MCP Hub returned non-200, skipping")
                return []
            }

            // Parse generic JSON array of server entries
            guard let servers = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return []
            }

            for server in servers.prefix(maxResourcesPerRegistry) {
                guard let name = server["name"] as? String else { continue }
                let description = server["description"] as? String ?? "MCP Hub server"
                let qualifiedName = server["qualified_name"] as? String ?? "mcphub/\(name)"
                let isVerified = server["verified"] as? Bool ?? false

                // Parse tools if available
                var tools: [DiscoveredTool] = []
                if let toolList = server["tools"] as? [[String: Any]] {
                    for tool in toolList {
                        let toolName = tool["name"] as? String ?? ""
                        let toolDesc = tool["description"] as? String ?? ""
                        if !toolName.isEmpty {
                            tools.append(DiscoveredTool(name: toolName, description: toolDesc))
                        }
                    }
                }

                let resource = DiscoveredResource(
                    sourceRegistry: .mcpHub,
                    qualifiedName: qualifiedName,
                    displayName: name,
                    description: description,
                    capabilities: tools.map { tool in
                        ResourceCapability(name: tool.name, category: .tools, description: tool.description)
                    },
                    tools: tools,
                    trustScore: isVerified ? 0.8 : 0.5,
                    popularity: server["downloads"] as? Int ?? 0,
                    lastUpdated: Date(),
                    connectionConfig: ResourceConnectionConfig(
                        transportType: .stdio,
                        authType: .none
                    ),
                    tags: Set(server["tags"] as? [String] ?? []),
                    isVerified: isVerified
                )
                resources.append(resource)
            }

            logger.debug("Discovered \(resources.count) resources from MCP Hub")

        } catch {
            logger.error("MCP Hub discovery failed: \(error.localizedDescription)")
            lastError = "MCP Hub: \(error.localizedDescription)"
        }

        return resources
    }

    // MARK: - Official MCP Discovery

    private func discoverFromOfficialMCP() async -> [DiscoveredResource] {
        guard let baseURL = ResourceRegistry.officialMCP.baseURL else { return [] }

        var resources: [DiscoveredResource] = []

        do {
            // Fetch the official MCP servers page and parse JSON-LD or embedded data
            let request = URLRequest(url: baseURL)
            let (data, response) = try await urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let html = String(data: data, encoding: .utf8) else {
                logger.debug("Official MCP returned non-200 or invalid response")
                return []
            }

            // Extract server entries from the HTML page using regex
            // The official site lists servers with name, description, and npm package
            let serverPattern = #"\"name\"\s*:\s*\"([^\"]+)\"\s*,\s*\"description\"\s*:\s*\"([^\"]+)\""#
            let regex = try NSRegularExpression(pattern: serverPattern)
            let range = NSRange(html.startIndex..., in: html)
            let matches = regex.matches(in: html, range: range)

            for match in matches.prefix(maxResourcesPerRegistry) {
                guard match.numberOfRanges >= 3,
                      let nameRange = Range(match.range(at: 1), in: html),
                      let descRange = Range(match.range(at: 2), in: html) else { continue }

                let name = String(html[nameRange])
                let description = String(html[descRange])

                // Skip non-server entries (section headers, etc.)
                guard name.count > 2, name.count < 100, description.count > 5 else { continue }

                let resource = DiscoveredResource(
                    sourceRegistry: .officialMCP,
                    qualifiedName: "official/\(name.lowercased().replacingOccurrences(of: " ", with: "-"))",
                    displayName: name,
                    description: description,
                    trustScore: 0.9,
                    popularity: 0,
                    lastUpdated: Date(),
                    connectionConfig: ResourceConnectionConfig(
                        transportType: .stdio,
                        authType: .none
                    ),
                    tags: ["official", "mcp"],
                    isVerified: true
                )
                resources.append(resource)
            }

            logger.debug("Discovered \(resources.count) resources from Official MCP")

        } catch {
            logger.error("Official MCP discovery failed: \(error.localizedDescription)")
            lastError = "Official MCP: \(error.localizedDescription)"
        }

        return resources
    }

    // MARK: - Local Discovery

    private func discoverLocalResources() -> [DiscoveredResource] {
        #if os(macOS)
        // Discover local MCP servers
        var resources: [DiscoveredResource] = []

        // Check common locations for MCP server configs
        let configPaths = [
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/mcp/servers.json"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".mcp/config.json")
        ]

        for path in configPaths {
            do {
                let data = try Data(contentsOf: path)
                let config = try JSONDecoder().decode(LocalMCPConfig.self, from: data)
                for (name, server) in config.servers {
                    let resource = DiscoveredResource(
                        sourceRegistry: .local,
                        qualifiedName: "local/\(name)",
                        displayName: name,
                        description: server.description ?? "Local MCP server",
                        connectionConfig: ResourceConnectionConfig(
                            transportType: .stdio,
                            config: {
                                var config: [String: String] = ["command": server.command]
                                for (index, arg) in (server.args ?? []).enumerated() {
                                    config["arg\(index)"] = arg
                                }
                                return config
                            }()
                        ),
                        tags: ["local"]
                    )
                    resources.append(resource)
                }
            } catch {
                logger.debug("Could not load local MCP config at \(path.lastPathComponent): \(error.localizedDescription)")
            }
        }

        logger.debug("Discovered \(resources.count) local resources")
        return resources
        #else
        // iOS doesn't support local MCP servers
        return []
        #endif
    }

    // MARK: - Resource Details

    private func fetchResourceDetails(_ qualifiedName: String, from registry: ResourceRegistry) async -> DiscoveredResource? {
        switch registry {
        case .smithery:
            return await fetchSmitheryServerDetails(qualifiedName)
        default:
            return nil
        }
    }

    private func fetchSmitheryServerDetails(_ qualifiedName: String) async -> DiscoveredResource? {
        guard let baseURL = ResourceRegistry.smithery.baseURL else { return nil }

        do {
            let url = baseURL.appendingPathComponent("servers/\(qualifiedName)")
            var request = URLRequest(url: url)
            if let apiKey = smitheryAPIKey {
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            }

            let (data, response) = try await urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }

            let server = try JSONDecoder().decode(SmitheryServer.self, from: data)

            return DiscoveredResource(
                sourceRegistry: .smithery,
                qualifiedName: server.qualifiedName,
                displayName: server.displayName,
                description: server.description,
                tools: server.tools.map { tool in
                    DiscoveredTool(name: tool.name, description: tool.description)
                },
                trustScore: Double(server.trustScore ?? 5) / 10.0,
                popularity: server.useCount ?? 0,
                lastUpdated: server.updatedAt ?? Date(),
                tags: Set(server.tags ?? []),
                isVerified: server.isVerified ?? false,
                isHosted: server.isHosted
            )

        } catch {
            logger.error("Failed to fetch Smithery server details: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Indexing

    private func indexResource(_ resource: DiscoveredResource) {
        resources[resource.id] = resource
    }

    private func rebuildIndices() {
        // Group by registry
        resourcesByRegistry = Dictionary(grouping: resources.values, by: \.sourceRegistry)

        // Group by capability
        var capabilityIndex: [ResourceCapability.CapabilityCategory: [DiscoveredResource]] = [:]
        for resource in resources.values {
            for capability in resource.capabilities {
                capabilityIndex[capability.category, default: []].append(resource)
            }
        }
        resourcesByCapability = capabilityIndex
    }

    // MARK: - Caching

    private let cacheKey = "thea.resource_discovery.cache"

    private func cacheResources() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(Array(resources.values))
            UserDefaults.standard.set(data, forKey: cacheKey)
            logger.debug("Cached \(self.resources.count) resources")
        } catch {
            logger.error("Failed to cache resources: \(error.localizedDescription)")
        }
    }

    private func loadCachedResources() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let cached = try decoder.decode([DiscoveredResource].self, from: data)

            for resource in cached {
                resources[resource.id] = resource
            }

            rebuildIndices()
            stats.totalResources = resources.count

            logger.info("Loaded \(cached.count) cached resources")
        } catch {
            logger.error("Failed to load cached resources: \(error.localizedDescription)")
        }
    }

    // MARK: - Background Discovery

    private func startBackgroundDiscovery() {
        guard autoDiscoveryEnabled else { return }

        backgroundDiscoveryTask?.cancel()
        backgroundDiscoveryTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: UInt64((self?.discoveryInterval ?? 3600) * 1_000_000_000))
                } catch {
                    break
                }

                if !Task.isCancelled {
                    await self?.discoverNow()
                }
            }
        }
    }

    public func stopBackgroundDiscovery() {
        backgroundDiscoveryTask?.cancel()
        backgroundDiscoveryTask = nil
    }
}

// DiscoveryStats, Smithery API types, and LocalMCPConfig are in ResourceDiscoveryTypes.swift
