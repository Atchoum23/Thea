// AgentRegistry.swift
import Foundation

/// Central registry for managing agent lifecycles, health monitoring, and capabilities.
/// Provides agent pool management and dynamic agent registration.
@MainActor
@Observable
public final class AgentRegistry {
    public static let shared = AgentRegistry()

    // MARK: - State

    private(set) var registeredAgents: [UUID: AgentInfo] = [:]
    private(set) var agentPool: [AgentType: [UUID]] = [:]
    private(set) var healthMonitor: AgentHealthMonitor

    private init() {
        self.healthMonitor = AgentHealthMonitor()
        setupDefaultAgents()
    }

    // MARK: - Agent Registration

    /// Register a new agent in the registry
    public func register(
        type: AgentType,
        capabilities: [AgentCapability],
        metadata: [String: String] = [:]
    ) -> UUID {
        let agentID = UUID()

        let info = AgentInfo(
            id: agentID,
            type: type,
            capabilities: capabilities,
            status: .idle,
            metadata: metadata,
            createdAt: Date()
        )

        registeredAgents[agentID] = info

        // Add to agent pool for this type
        if agentPool[type] == nil {
            agentPool[type] = []
        }
        agentPool[type]?.append(agentID)

        print("[AgentRegistry] Registered agent \(agentID) of type \(type.rawValue)")

        return agentID
    }

    /// Unregister an agent from the registry
    public func unregister(_ agentID: UUID) {
        guard let info = registeredAgents[agentID] else { return }

        // Remove from pool
        agentPool[info.type]?.removeAll { $0 == agentID }

        // Remove from registry
        registeredAgents.removeValue(forKey: agentID)

        print("[AgentRegistry] Unregistered agent \(agentID)")
    }

    // MARK: - Agent Lookup

    /// Get agent information
    public func getAgent(_ agentID: UUID) -> AgentInfo? {
        registeredAgents[agentID]
    }

    /// Find available agent of specific type
    public func findAvailableAgent(ofType type: AgentType) -> UUID? {
        guard let pool = agentPool[type] else { return nil }

        // Find first idle or available agent
        for agentID in pool {
            if let info = registeredAgents[agentID],
               info.status == .idle || info.status == .available {
                return agentID
            }
        }

        return nil
    }

    /// Find agents with specific capability
    public func findAgentsWithCapability(_ capability: AgentCapability) -> [UUID] {
        registeredAgents.values
            .filter { $0.capabilities.contains(capability) }
            .map { $0.id }
    }

    /// Get all agents of a specific type
    public func getAgents(ofType type: AgentType) -> [UUID] {
        agentPool[type] ?? []
    }

    // MARK: - Agent Status Management

    /// Update agent status
    public func updateStatus(_ agentID: UUID, status: AgentStatus) {
        registeredAgents[agentID]?.status = status
        registeredAgents[agentID]?.lastUpdated = Date()
    }

    /// Mark agent as busy
    public func markBusy(_ agentID: UUID) {
        updateStatus(agentID, status: .busy)
    }

    /// Mark agent as idle
    public func markIdle(_ agentID: UUID) {
        updateStatus(agentID, status: .idle)
    }

    /// Mark agent as failed
    public func markFailed(_ agentID: UUID, reason: String) {
        updateStatus(agentID, status: .failed(reason: reason))
        healthMonitor.recordFailure(agentID, reason: reason)
    }

    // MARK: - Health Monitoring

    /// Check if agent is healthy
    public func isHealthy(_ agentID: UUID) -> Bool {
        guard let info = registeredAgents[agentID] else { return false }

        // Check status
        if case .failed = info.status {
            return false
        }

        // Check with health monitor
        return healthMonitor.isHealthy(agentID)
    }

    /// Get health statistics for an agent
    public func getHealthStats(_ agentID: UUID) -> AgentHealthStats? {
        healthMonitor.getStats(agentID)
    }

    /// Get all unhealthy agents
    public func getUnhealthyAgents() -> [UUID] {
        registeredAgents.values
            .filter { !isHealthy($0.id) }
            .map { $0.id }
    }

    // MARK: - Capability Management

    /// Add capability to an agent
    public func addCapability(_ agentID: UUID, capability: AgentCapability) {
        registeredAgents[agentID]?.capabilities.append(capability)
    }

    /// Remove capability from an agent
    public func removeCapability(_ agentID: UUID, capability: AgentCapability) {
        registeredAgents[agentID]?.capabilities.removeAll { $0 == capability }
    }

    /// Check if agent has capability
    public func hasCapability(_ agentID: UUID, capability: AgentCapability) -> Bool {
        registeredAgents[agentID]?.capabilities.contains(capability) ?? false
    }

    // MARK: - Pool Management

    /// Get pool statistics
    public func getPoolStats() -> PoolStatistics {
        var stats = PoolStatistics()

        for info in registeredAgents.values {
            stats.totalAgents += 1

            switch info.status {
            case .idle, .available:
                stats.availableAgents += 1
            case .busy:
                stats.busyAgents += 1
            case .failed:
                stats.failedAgents += 1
            }

            stats.agentsByType[info.type, default: 0] += 1
        }

        return stats
    }

    /// Clean up failed agents
    public func cleanupFailedAgents() {
        let failedAgents = registeredAgents.values
            .filter { if case .failed = $0.status { return true }; return false }
            .map { $0.id }

        for agentID in failedAgents {
            unregister(agentID)
        }

        print("[AgentRegistry] Cleaned up \(failedAgents.count) failed agents")
    }

    // MARK: - Setup

    private func setupDefaultAgents() {
        // Register default agent types with capabilities

        // Code agent
        _ = register(
            type: .code,
            capabilities: [.codeGeneration, .codeReview, .refactoring, .debugging]
        )

        // Reasoning agent
        _ = register(
            type: .reasoning,
            capabilities: [.analysis, .planning, .problemSolving]
        )

        // Research agent
        _ = register(
            type: .research,
            capabilities: [.webSearch, .dataGathering, .factChecking]
        )

        // Writing agent
        _ = register(
            type: .writing,
            capabilities: [.contentCreation, .editing, .summarization]
        )

        // Validation agent
        _ = register(
            type: .validation,
            capabilities: [.codeValidation, .testing, .qualityAssurance]
        )
    }
}

// MARK: - Supporting Types

/// Information about a registered agent
public struct AgentInfo {
    public let id: UUID
    public let type: AgentType
    public var capabilities: [AgentCapability]
    public var status: AgentStatus
    public let metadata: [String: String]
    public let createdAt: Date
    public var lastUpdated: Date

    init(
        id: UUID,
        type: AgentType,
        capabilities: [AgentCapability],
        status: AgentStatus,
        metadata: [String: String],
        createdAt: Date
    ) {
        self.id = id
        self.type = type
        self.capabilities = capabilities
        self.status = status
        self.metadata = metadata
        self.createdAt = createdAt
        self.lastUpdated = createdAt
    }
}

/// Agent types
public enum AgentType: String, Codable, CaseIterable {
    case code
    case reasoning
    case research
    case writing
    case validation
    case orchestrator
    case specialized

    public var displayName: String {
        rawValue.capitalized
    }
}

/// Agent capabilities
public enum AgentCapability: String, Codable, CaseIterable {
    case codeGeneration
    case codeReview
    case refactoring
    case debugging
    case analysis
    case planning
    case problemSolving
    case webSearch
    case dataGathering
    case factChecking
    case contentCreation
    case editing
    case summarization
    case codeValidation
    case testing
    case qualityAssurance
}

/// Agent status
public enum AgentStatus: Equatable {
    case idle
    case available
    case busy
    case failed(reason: String)

    public var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .available: return "Available"
        case .busy: return "Busy"
        case .failed(let reason): return "Failed: \(reason)"
        }
    }
}

/// Pool statistics
public struct PoolStatistics {
    public var totalAgents: Int = 0
    public var availableAgents: Int = 0
    public var busyAgents: Int = 0
    public var failedAgents: Int = 0
    public var agentsByType: [AgentType: Int] = [:]
}

// MARK: - Health Monitor

/// Monitors agent health and tracks failures
public class AgentHealthMonitor {
    private var healthRecords: [UUID: HealthRecord] = [:]

    struct HealthRecord {
        var failureCount: Int = 0
        var lastFailure: Date?
        var failureReasons: [String] = []
    }

    func recordFailure(_ agentID: UUID, reason: String) {
        var record = healthRecords[agentID] ?? HealthRecord()
        record.failureCount += 1
        record.lastFailure = Date()
        record.failureReasons.append(reason)

        // Keep only last 10 failure reasons
        if record.failureReasons.count > 10 {
            record.failureReasons.removeFirst()
        }

        healthRecords[agentID] = record
    }

    func isHealthy(_ agentID: UUID) -> Bool {
        guard let record = healthRecords[agentID] else { return true }

        // Agent is unhealthy if:
        // 1. More than 3 failures total
        // 2. Last failure was less than 5 minutes ago
        if record.failureCount > 3 {
            return false
        }

        if let lastFailure = record.lastFailure,
           Date().timeIntervalSince(lastFailure) < 300 { // 5 minutes
            return false
        }

        return true
    }

    func getStats(_ agentID: UUID) -> AgentHealthStats? {
        guard let record = healthRecords[agentID] else { return nil }

        return AgentHealthStats(
            failureCount: record.failureCount,
            lastFailure: record.lastFailure,
            recentFailureReasons: Array(record.failureReasons.suffix(5))
        )
    }

    func reset(_ agentID: UUID) {
        healthRecords.removeValue(forKey: agentID)
    }
}

/// Agent health statistics
public struct AgentHealthStats {
    public let failureCount: Int
    public let lastFailure: Date?
    public let recentFailureReasons: [String]
}
