// MCPGateway.swift
// Thea V2
//
// Centralized MCP Gateway with rate limiting, connection pooling,
// health monitoring, and enterprise-grade security

import Foundation
import OSLog

// MARK: - MCP Connection

/// Represents an MCP server connection
public struct MCPGatewayConnection: Identifiable, Sendable {
    public let id: UUID
    public let serverId: String
    public let serverName: String
    public let endpoint: URL
    public let status: ConnectionStatus
    public let authenticationType: AuthenticationType
    public let lastHealthCheck: Date?
    public let healthScore: Float  // 0.0 - 1.0
    public let metadata: [String: String]

    public init(
        id: UUID = UUID(),
        serverId: String,
        serverName: String,
        endpoint: URL,
        status: ConnectionStatus = .disconnected,
        authenticationType: AuthenticationType = .none,
        lastHealthCheck: Date? = nil,
        healthScore: Float = 1.0,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.serverId = serverId
        self.serverName = serverName
        self.endpoint = endpoint
        self.status = status
        self.authenticationType = authenticationType
        self.lastHealthCheck = lastHealthCheck
        self.healthScore = healthScore
        self.metadata = metadata
    }

    public enum ConnectionStatus: String, Sendable {
        case connected
        case connecting
        case disconnected
        case authRequired
        case error
        case degraded
    }

    public enum AuthenticationType: String, Sendable {
        case none
        case apiKey
        case oauth
        case serviceToken
        case certificate
    }
}

// MARK: - Rate Limit

/// Rate limiting configuration
public struct MCPRateLimitConfig: Sendable {
    public let requestsPerMinute: Int
    public let requestsPerHour: Int
    public let requestsPerDay: Int
    public let concurrentRequests: Int
    public let burstAllowance: Int

    public init(
        requestsPerMinute: Int = 60,
        requestsPerHour: Int = 1000,
        requestsPerDay: Int = 10000,
        concurrentRequests: Int = 10,
        burstAllowance: Int = 20
    ) {
        self.requestsPerMinute = requestsPerMinute
        self.requestsPerHour = requestsPerHour
        self.requestsPerDay = requestsPerDay
        self.concurrentRequests = concurrentRequests
        self.burstAllowance = burstAllowance
    }
}

/// Rate limit state for a connection
public struct RateLimitState: Sendable {
    public var minuteRequests: Int
    public var hourRequests: Int
    public var dayRequests: Int
    public var activeRequests: Int
    public var lastMinuteReset: Date
    public var lastHourReset: Date
    public var lastDayReset: Date

    public init() {
        self.minuteRequests = 0
        self.hourRequests = 0
        self.dayRequests = 0
        self.activeRequests = 0
        self.lastMinuteReset = Date()
        self.lastHourReset = Date()
        self.lastDayReset = Date()
    }

    public mutating func resetIfNeeded() {
        let now = Date()

        if now.timeIntervalSince(lastMinuteReset) >= 60 {
            minuteRequests = 0
            lastMinuteReset = now
        }

        if now.timeIntervalSince(lastHourReset) >= 3600 {
            hourRequests = 0
            lastHourReset = now
        }

        if now.timeIntervalSince(lastDayReset) >= 86400 {
            dayRequests = 0
            lastDayReset = now
        }
    }

    public func canMakeRequest(config: MCPRateLimitConfig) -> Bool {
        minuteRequests < config.requestsPerMinute + config.burstAllowance &&
        hourRequests < config.requestsPerHour &&
        dayRequests < config.requestsPerDay &&
        activeRequests < config.concurrentRequests
    }
}

// MARK: - Connection Pool

/// A pool of reusable connections
public actor MCPGatewayConnectionPool {
    private let logger = Logger(subsystem: "com.thea.mcp", category: "Pool")

    private var connections: [String: [PooledConnection]] = [:]
    private let maxConnectionsPerServer: Int
    private let connectionTimeout: TimeInterval
    private let idleTimeout: TimeInterval

    public struct PooledConnection: Sendable {
        public let connection: MCPGatewayConnection
        public var inUse: Bool
        public var lastUsed: Date
        public var useCount: Int

        public init(connection: MCPGatewayConnection) {
            self.connection = connection
            self.inUse = false
            self.lastUsed = Date()
            self.useCount = 0
        }
    }

    public init(
        maxConnectionsPerServer: Int = 5,
        connectionTimeout: TimeInterval = 30,
        idleTimeout: TimeInterval = 300
    ) {
        self.maxConnectionsPerServer = maxConnectionsPerServer
        self.connectionTimeout = connectionTimeout
        self.idleTimeout = idleTimeout
    }

    /// Acquire a connection from the pool
    public func acquire(serverId: String) async -> MCPGatewayConnection? {
        cleanupIdleConnections()

        var serverConnections = connections[serverId] ?? []

        // Find available connection
        for index in serverConnections.indices {
            if !serverConnections[index].inUse &&
               serverConnections[index].connection.status == .connected {
                serverConnections[index].inUse = true
                serverConnections[index].lastUsed = Date()
                serverConnections[index].useCount += 1
                connections[serverId] = serverConnections
                logger.debug("Acquired existing connection for \(serverId)")
                return serverConnections[index].connection
            }
        }

        // Check if we can create new connection
        if serverConnections.count < maxConnectionsPerServer {
            logger.debug("Would create new connection for \(serverId)")
            return nil  // Caller should create new connection
        }

        logger.warning("Connection pool exhausted for \(serverId)")
        return nil
    }

    /// Release a connection back to the pool
    public func release(connection: MCPGatewayConnection) {
        let serverId = connection.serverId
        guard var serverConnections = connections[serverId] else { return }

        if let index = serverConnections.firstIndex(where: { $0.connection.id == connection.id }) {
            serverConnections[index].inUse = false
            serverConnections[index].lastUsed = Date()
            connections[serverId] = serverConnections
            logger.debug("Released connection for \(serverId)")
        }
    }

    /// Add a new connection to the pool
    public func add(connection: MCPGatewayConnection) {
        var serverConnections = connections[connection.serverId] ?? []

        guard serverConnections.count < maxConnectionsPerServer else {
            logger.warning("Cannot add connection - pool full for \(connection.serverId)")
            return
        }

        serverConnections.append(PooledConnection(connection: connection))
        connections[connection.serverId] = serverConnections
        logger.info("Added connection to pool for \(connection.serverId)")
    }

    /// Remove a connection from the pool
    public func remove(connectionId: UUID) {
        for (serverId, var serverConnections) in connections {
            if let index = serverConnections.firstIndex(where: { $0.connection.id == connectionId }) {
                serverConnections.remove(at: index)
                connections[serverId] = serverConnections
                logger.info("Removed connection from pool")
                return
            }
        }
    }

    /// Get pool statistics
    public func statistics() -> PoolStatistics {
        var totalConnections = 0
        var activeConnections = 0
        var idleConnections = 0

        for serverConnections in connections.values {
            totalConnections += serverConnections.count
            activeConnections += serverConnections.filter { $0.inUse }.count
            idleConnections += serverConnections.filter { !$0.inUse }.count
        }

        return PoolStatistics(
            totalConnections: totalConnections,
            activeConnections: activeConnections,
            idleConnections: idleConnections,
            serverCount: connections.count
        )
    }

    private func cleanupIdleConnections() {
        let now = Date()

        for (serverId, var serverConnections) in connections {
            serverConnections.removeAll { pooled in
                !pooled.inUse && now.timeIntervalSince(pooled.lastUsed) > idleTimeout
            }
            connections[serverId] = serverConnections
        }
    }

    public struct PoolStatistics: Sendable {
        public let totalConnections: Int
        public let activeConnections: Int
        public let idleConnections: Int
        public let serverCount: Int
    }
}

// MARK: - Health Monitor

/// Monitors health of MCP connections
public actor MCPHealthMonitor {
    private let logger = Logger(subsystem: "com.thea.mcp", category: "Health")

    private var healthScores: [String: Float] = [:]
    private var failureHistory: [String: [Date]] = [:]
    private var lastChecks: [String: Date] = [:]

    private let healthCheckInterval: TimeInterval = 60  // 1 minute
    private let failureWindow: TimeInterval = 300       // 5 minutes
    private let maxFailuresBeforeUnhealthy: Int = 3

    /// Update health based on request result
    public func recordResult(serverId: String, success: Bool, latency: TimeInterval) {
        if success {
            // Successful request improves health
            let currentScore = healthScores[serverId] ?? 1.0
            healthScores[serverId] = min(1.0, currentScore + 0.05)

            // Clear old failures
            cleanupFailures(serverId: serverId)
        } else {
            // Failed request decreases health
            var failures = failureHistory[serverId] ?? []
            failures.append(Date())
            failureHistory[serverId] = failures

            let currentScore = healthScores[serverId] ?? 1.0
            healthScores[serverId] = max(0.0, currentScore - 0.2)
        }

        lastChecks[serverId] = Date()
    }

    /// Get health score for a server
    public func healthScore(for serverId: String) -> Float {
        healthScores[serverId] ?? 1.0
    }

    /// Check if server is healthy
    public func isHealthy(serverId: String) -> Bool {
        let score = healthScores[serverId] ?? 1.0
        let recentFailures = countRecentFailures(serverId: serverId)

        return score >= 0.5 && recentFailures < maxFailuresBeforeUnhealthy
    }

    /// Get all unhealthy servers
    public func unhealthyServers() -> [String] {
        healthScores.compactMap { serverId, score in
            score < 0.5 || countRecentFailures(serverId: serverId) >= maxFailuresBeforeUnhealthy
                ? serverId : nil
        }
    }

    /// Needs health check
    public func needsHealthCheck(serverId: String) -> Bool {
        guard let lastCheck = lastChecks[serverId] else { return true }
        return Date().timeIntervalSince(lastCheck) >= healthCheckInterval
    }

    private func countRecentFailures(serverId: String) -> Int {
        guard let failures = failureHistory[serverId] else { return 0 }
        let cutoff = Date().addingTimeInterval(-failureWindow)
        return failures.filter { $0 > cutoff }.count
    }

    private func cleanupFailures(serverId: String) {
        guard var failures = failureHistory[serverId] else { return }
        let cutoff = Date().addingTimeInterval(-failureWindow)
        failures = failures.filter { $0 > cutoff }
        failureHistory[serverId] = failures
    }
}

// MARK: - MCP Request

/// An MCP request
public struct MCPRequest: Identifiable, Sendable {
    public let id: UUID
    public let serverId: String
    public let method: String
    public let parameters: [String: String]
    public let priority: RequestPriority
    public let timeout: TimeInterval
    public let retryPolicy: MCPRetryPolicy
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        serverId: String,
        method: String,
        parameters: [String: String] = [:],
        priority: RequestPriority = .normal,
        timeout: TimeInterval = 30,
        retryPolicy: MCPRetryPolicy = .default,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.serverId = serverId
        self.method = method
        self.parameters = parameters
        self.priority = priority
        self.timeout = timeout
        self.retryPolicy = retryPolicy
        self.createdAt = createdAt
    }

    public enum RequestPriority: Int, Comparable, Sendable {
        case low = 0
        case normal = 50
        case high = 75
        case critical = 100

        public static func < (lhs: RequestPriority, rhs: RequestPriority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    public struct MCPRetryPolicy: Sendable {
        public let maxRetries: Int
        public let initialDelay: TimeInterval
        public let maxDelay: TimeInterval
        public let backoffMultiplier: Double

        public static let `default` = MCPRetryPolicy(
            maxRetries: 3,
            initialDelay: 1.0,
            maxDelay: 30.0,
            backoffMultiplier: 2.0
        )

        public static let aggressive = MCPRetryPolicy(
            maxRetries: 5,
            initialDelay: 0.5,
            maxDelay: 60.0,
            backoffMultiplier: 1.5
        )

        public static let none = MCPRetryPolicy(
            maxRetries: 0,
            initialDelay: 0,
            maxDelay: 0,
            backoffMultiplier: 1
        )

        public init(maxRetries: Int, initialDelay: TimeInterval, maxDelay: TimeInterval, backoffMultiplier: Double) {
            self.maxRetries = maxRetries
            self.initialDelay = initialDelay
            self.maxDelay = maxDelay
            self.backoffMultiplier = backoffMultiplier
        }

        public func delay(forAttempt attempt: Int) -> TimeInterval {
            let delay = initialDelay * pow(backoffMultiplier, Double(attempt))
            return min(delay, maxDelay)
        }
    }
}

/// An MCP response
public struct MCPResponse: Sendable {
    public let requestId: UUID
    public let success: Bool
    public let data: [String: String]?
    public let error: MCPError?
    public let latency: TimeInterval
    public let retryCount: Int

    public init(
        requestId: UUID,
        success: Bool,
        data: [String: String]? = nil,
        error: MCPError? = nil,
        latency: TimeInterval,
        retryCount: Int = 0
    ) {
        self.requestId = requestId
        self.success = success
        self.data = data
        self.error = error
        self.latency = latency
        self.retryCount = retryCount
    }
}

public struct MCPError: Error, Sendable {
    public let code: String
    public let message: String
    public let isRetryable: Bool

    public init(code: String, message: String, isRetryable: Bool = true) {
        self.code = code
        self.message = message
        self.isRetryable = isRetryable
    }
}

// MARK: - MCP Gateway

/// Central gateway for all MCP operations
@MainActor
public final class MCPGateway: ObservableObject {
    public static let shared = MCPGateway()

    private let logger = Logger(subsystem: "com.thea.mcp", category: "Gateway")

    @Published public private(set) var connections: [MCPGatewayConnection] = []
    @Published public private(set) var isInitialized: Bool = false

    private let connectionPool: MCPGatewayConnectionPool
    private let healthMonitor: MCPHealthMonitor
    private var rateLimitStates: [String: RateLimitState] = [:]
    private var rateLimitConfigs: [String: MCPRateLimitConfig] = [:]
    private var requestQueue: [MCPRequest] = []

    // Default rate limit
    private let defaultRateLimit = MCPRateLimitConfig()

    private init() {
        self.connectionPool = MCPGatewayConnectionPool()
        self.healthMonitor = MCPHealthMonitor()
    }

    // MARK: - Connection Management

    /// Register an MCP server
    public func registerServer(
        serverId: String,
        serverName: String,
        endpoint: URL,
        authenticationType: MCPGatewayConnection.AuthenticationType = .none,
        rateLimit: MCPRateLimitConfig? = nil
    ) {
        let connection = MCPGatewayConnection(
            serverId: serverId,
            serverName: serverName,
            endpoint: endpoint,
            status: .disconnected,
            authenticationType: authenticationType
        )

        connections.append(connection)
        rateLimitStates[serverId] = RateLimitState()
        rateLimitConfigs[serverId] = rateLimit ?? defaultRateLimit

        logger.info("Registered MCP server: \(serverName) (\(serverId))")
    }

    /// Connect to a server
    public func connect(serverId: String) async throws {
        guard let index = connections.firstIndex(where: { $0.serverId == serverId }) else {
            throw MCPError(code: "NOT_FOUND", message: "Server not found", isRetryable: false)
        }

        // Update status to connecting
        updateConnectionStatus(at: index, status: .connecting)

        // Simulate connection (in production, actual connection logic)
        try await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds

        // Update status to connected
        updateConnectionStatus(at: index, status: .connected)

        // Add to pool
        await connectionPool.add(connection: connections[index])

        logger.info("Connected to MCP server: \(serverId)")
    }

    /// Disconnect from a server
    public func disconnect(serverId: String) async {
        guard let index = connections.firstIndex(where: { $0.serverId == serverId }) else { return }

        updateConnectionStatus(at: index, status: .disconnected)

        // Remove from pool
        await connectionPool.remove(connectionId: connections[index].id)

        logger.info("Disconnected from MCP server: \(serverId)")
    }

    // MARK: - Request Handling

    /// Send a request through the gateway
    public func send(_ request: MCPRequest) async -> MCPResponse {
        let startTime = Date()

        // Check rate limit
        guard checkRateLimit(serverId: request.serverId) else {
            return MCPResponse(
                requestId: request.id,
                success: false,
                error: MCPError(code: "RATE_LIMITED", message: "Rate limit exceeded", isRetryable: true),
                latency: 0
            )
        }

        // Check health
        let isHealthy = await healthMonitor.isHealthy(serverId: request.serverId)
        if !isHealthy {
            logger.warning("Server \(request.serverId) is unhealthy, proceeding with caution")
        }

        // Increment counters
        incrementRateLimitCounters(serverId: request.serverId)

        // Execute with retry
        var lastError: MCPError?
        var retryCount = 0

        while retryCount <= request.retryPolicy.maxRetries {
            do {
                let response = try await executeRequest(request)
                let latency = Date().timeIntervalSince(startTime)

                // Record success
                await healthMonitor.recordResult(
                    serverId: request.serverId,
                    success: true,
                    latency: latency
                )
                decrementActiveRequests(serverId: request.serverId)

                return MCPResponse(
                    requestId: request.id,
                    success: true,
                    data: response,
                    latency: latency,
                    retryCount: retryCount
                )
            } catch let error as MCPError {
                lastError = error

                if !error.isRetryable || retryCount >= request.retryPolicy.maxRetries {
                    break
                }

                // Wait before retry
                let delay = request.retryPolicy.delay(forAttempt: retryCount)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                retryCount += 1

                logger.debug("Retrying request \(request.id) (attempt \(retryCount))")
            } catch {
                lastError = MCPError(code: "UNKNOWN", message: error.localizedDescription)
                break
            }
        }

        let latency = Date().timeIntervalSince(startTime)

        // Record failure
        await healthMonitor.recordResult(
            serverId: request.serverId,
            success: false,
            latency: latency
        )
        decrementActiveRequests(serverId: request.serverId)

        return MCPResponse(
            requestId: request.id,
            success: false,
            error: lastError,
            latency: latency,
            retryCount: retryCount
        )
    }

    /// Send multiple requests in parallel
    public func sendBatch(_ requests: [MCPRequest]) async -> [MCPResponse] {
        await withTaskGroup(of: MCPResponse.self) { group in
            for request in requests {
                group.addTask {
                    await self.send(request)
                }
            }

            var responses: [MCPResponse] = []
            for await response in group {
                responses.append(response)
            }
            return responses
        }
    }

    // MARK: - Rate Limiting

    private func checkRateLimit(serverId: String) -> Bool {
        var state = rateLimitStates[serverId] ?? RateLimitState()
        state.resetIfNeeded()
        rateLimitStates[serverId] = state

        let config = rateLimitConfigs[serverId] ?? defaultRateLimit
        return state.canMakeRequest(config: config)
    }

    private func incrementRateLimitCounters(serverId: String) {
        var state = rateLimitStates[serverId] ?? RateLimitState()
        state.minuteRequests += 1
        state.hourRequests += 1
        state.dayRequests += 1
        state.activeRequests += 1
        rateLimitStates[serverId] = state
    }

    private func decrementActiveRequests(serverId: String) {
        var state = rateLimitStates[serverId] ?? RateLimitState()
        state.activeRequests = max(0, state.activeRequests - 1)
        rateLimitStates[serverId] = state
    }

    // MARK: - Health Checks

    /// Run health checks on all servers
    public func runHealthChecks() async {
        for connection in connections where connection.status == .connected {
            if await healthMonitor.needsHealthCheck(serverId: connection.serverId) {
                await performHealthCheck(serverId: connection.serverId)
            }
        }
    }

    private func performHealthCheck(serverId: String) async {
        let request = MCPRequest(
            serverId: serverId,
            method: "ping",
            priority: .low,
            timeout: 5,
            retryPolicy: .none
        )

        let response = await send(request)

        if let index = connections.firstIndex(where: { $0.serverId == serverId }) {
            let score = await healthMonitor.healthScore(for: serverId)
            let newStatus: MCPGatewayConnection.ConnectionStatus = score >= 0.5 ? .connected : .degraded

            connections[index] = MCPGatewayConnection(
                id: connections[index].id,
                serverId: connections[index].serverId,
                serverName: connections[index].serverName,
                endpoint: connections[index].endpoint,
                status: newStatus,
                authenticationType: connections[index].authenticationType,
                lastHealthCheck: Date(),
                healthScore: score,
                metadata: connections[index].metadata
            )
        }

        logger.debug("Health check for \(serverId): \(response.success ? "OK" : "FAILED")")
    }

    // MARK: - Statistics

    public func statistics() async -> GatewayStatistics {
        let poolStats = await connectionPool.statistics()
        let unhealthy = await healthMonitor.unhealthyServers()

        var totalRequests = 0
        var totalActive = 0
        for state in rateLimitStates.values {
            totalRequests += state.dayRequests
            totalActive += state.activeRequests
        }

        return GatewayStatistics(
            totalConnections: connections.count,
            connectedServers: connections.filter { $0.status == .connected }.count,
            unhealthyServers: unhealthy.count,
            pooledConnections: poolStats.totalConnections,
            activeRequests: totalActive,
            todayRequests: totalRequests
        )
    }

    // MARK: - Private Helpers

    private func updateConnectionStatus(at index: Int, status: MCPGatewayConnection.ConnectionStatus) {
        let old = connections[index]
        connections[index] = MCPGatewayConnection(
            id: old.id,
            serverId: old.serverId,
            serverName: old.serverName,
            endpoint: old.endpoint,
            status: status,
            authenticationType: old.authenticationType,
            lastHealthCheck: old.lastHealthCheck,
            healthScore: old.healthScore,
            metadata: old.metadata
        )
    }

    private func executeRequest(_ request: MCPRequest) async throws -> [String: String] {
        // Simulate request execution
        try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

        // In production, actual MCP protocol implementation
        return ["status": "ok", "method": request.method]
    }
}

// MARK: - Supporting Types

public struct GatewayStatistics: Sendable {
    public let totalConnections: Int
    public let connectedServers: Int
    public let unhealthyServers: Int
    public let pooledConnections: Int
    public let activeRequests: Int
    public let todayRequests: Int
}
