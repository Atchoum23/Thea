// AgentResourcePool.swift
// Thea V2
//
// Resource pool for managing shared resources in parallel agent execution
// Handles API rate limits, model access, and computational resources

import Foundation
import OSLog

// MARK: - Resource Types

/// Types of resources that can be pooled
public enum PoolResourceType: String, Codable, Sendable, CaseIterable {
    case apiSlot           // API call slot (rate limiting)
    case modelAccess       // Access to a specific model
    case memoryBudget      // Memory allocation
    case computeSlot       // CPU/GPU compute slot
    case networkBandwidth  // Network bandwidth
    case fileHandle        // File system access
    case contextWindow     // Context window tokens
}

/// A pooled resource that can be acquired and released
public struct PooledResource: Identifiable, Sendable {
    public let id: UUID
    public let type: PoolResourceType
    public let name: String
    public let providerId: String?  // For API slots
    public var capacity: Int
    public var available: Int
    public var lastUsed: Date?
    public var cooldownUntil: Date?

    public init(
        id: UUID = UUID(),
        type: PoolResourceType,
        name: String,
        providerId: String? = nil,
        capacity: Int,
        available: Int? = nil,
        lastUsed: Date? = nil,
        cooldownUntil: Date? = nil
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.providerId = providerId
        self.capacity = capacity
        self.available = available ?? capacity
        self.lastUsed = lastUsed
        self.cooldownUntil = cooldownUntil
    }

    public var isAvailable: Bool {
        available > 0 && (cooldownUntil == nil || Date() >= cooldownUntil!)
    }

    public var utilizationPercent: Double {
        guard capacity > 0 else { return 0 }
        return Double(capacity - available) / Double(capacity) * 100
    }
}

/// Resource allocation result
public struct PoolResourceAllocation: Identifiable, Sendable {
    public let id: UUID
    public let resourceId: UUID
    public let agentId: UUID
    public let allocatedAt: Date
    public let quantity: Int
    public var releasedAt: Date?

    public init(
        id: UUID = UUID(),
        resourceId: UUID,
        agentId: UUID,
        allocatedAt: Date = Date(),
        quantity: Int = 1,
        releasedAt: Date? = nil
    ) {
        self.id = id
        self.resourceId = resourceId
        self.agentId = agentId
        self.allocatedAt = allocatedAt
        self.quantity = quantity
        self.releasedAt = releasedAt
    }

    public var isActive: Bool {
        releasedAt == nil
    }

    public var duration: TimeInterval {
        let endTime = releasedAt ?? Date()
        return endTime.timeIntervalSince(allocatedAt)
    }
}

// MARK: - Resource Pool

/// Manages shared resources for parallel agent execution
/// Implements fair resource allocation with rate limiting support
public actor AgentResourcePool {
    public static let shared = AgentResourcePool()

    private let logger = Logger(subsystem: "com.thea.agents", category: "ResourcePool")

    // MARK: - State

    /// All registered resources
    private var resources: [UUID: PooledResource] = [:]

    /// Active allocations
    private var allocations: [UUID: PoolResourceAllocation] = [:]

    /// Waiting queue for resources
    private var waitingQueue: [ResourceWaiter] = []

    /// Provider-specific rate limits
    private var providerRateLimits: [String: RateLimitConfig] = [:]

    /// Statistics
    private var stats = ResourcePoolStats()

    private init() {
        Task {
            await self.initializeDefaultResources()
        }
    }

    // MARK: - Initialization

    /// Initialize default resource pools
    private func initializeDefaultResources() {
        // API slots for major providers (based on typical rate limits)
        let providers: [(String, Int)] = [
            ("anthropic", 5),      // Anthropic: moderate concurrency
            ("openai", 10),        // OpenAI: higher limits
            ("google", 8),         // Google: moderate
            ("openrouter", 15),    // OpenRouter: aggregated
            ("groq", 6),           // Groq: moderate
            ("perplexity", 4),     // Perplexity: lower limits
            ("local", 4)           // Local: CPU/GPU bound
        ]

        for (provider, slots) in providers {
            let resource = PooledResource(
                type: .apiSlot,
                name: "\(provider)-api",
                providerId: provider,
                capacity: slots
            )
            resources[resource.id] = resource

            // Set default rate limits
            providerRateLimits[provider] = RateLimitConfig(
                requestsPerMinute: slots * 10,
                tokensPerMinute: 100_000,
                cooldownSeconds: 1.0
            )
        }

        // Compute slots (based on M3 Ultra capabilities)
        let computeResource = PooledResource(
            type: .computeSlot,
            name: "compute-pool",
            capacity: 8  // 8 parallel agents max
        )
        resources[computeResource.id] = computeResource

        // Memory budget (allocate 100GB for model operations)
        let memoryResource = PooledResource(
            type: .memoryBudget,
            name: "memory-pool",
            capacity: 100  // GB
        )
        resources[memoryResource.id] = memoryResource

        // Context window pool (total tokens across all agents)
        let contextResource = PooledResource(
            type: .contextWindow,
            name: "context-pool",
            capacity: 500_000  // Total tokens available
        )
        resources[contextResource.id] = contextResource

        logger.info("Initialized \(self.resources.count) resource pools")
    }

    // MARK: - Resource Acquisition

    /// Acquire a resource for an agent
    /// Returns nil if unavailable and non-blocking
    public func acquire(
        resourceType: PoolResourceType,
        agentId: UUID,
        quantity: Int = 1,
        providerId: String? = nil,
        timeout: TimeInterval? = nil
    ) async throws -> PoolResourceAllocation? {
        // Find appropriate resource
        guard let resource = findResource(type: resourceType, providerId: providerId) else {
            logger.warning("No resource found for type: \(resourceType.rawValue), provider: \(providerId ?? "none")")
            return nil
        }

        // Check availability
        guard var mutableResource = resources[resource.id] else { return nil }

        // Check cooldown
        if let cooldownUntil = mutableResource.cooldownUntil, Date() < cooldownUntil {
            if let timeout = timeout {
                // Wait for cooldown
                let waitTime = cooldownUntil.timeIntervalSinceNow
                if waitTime < timeout {
                    try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
                } else {
                    return nil
                }
            } else {
                return nil
            }
        }

        // Check if resource is available
        if mutableResource.available >= quantity {
            // Allocate
            mutableResource.available -= quantity
            mutableResource.lastUsed = Date()
            resources[resource.id] = mutableResource

            let allocation = PoolResourceAllocation(
                resourceId: resource.id,
                agentId: agentId,
                quantity: quantity
            )
            allocations[allocation.id] = allocation

            stats.totalAllocations += 1
            stats.currentActive += 1

            logger.debug("Allocated \(quantity) of \(resource.name) to agent \(agentId.uuidString.prefix(8))")
            return allocation
        }

        // Resource not available
        if let timeout = timeout {
            // Add to waiting queue
            return try await waitForResource(
                resourceId: resource.id,
                agentId: agentId,
                quantity: quantity,
                timeout: timeout
            )
        }

        stats.rejectedRequests += 1
        return nil
    }

    /// Wait for a resource to become available
    private func waitForResource(
        resourceId: UUID,
        agentId: UUID,
        quantity: Int,
        timeout: TimeInterval
    ) async throws -> PoolResourceAllocation? {
        let waiter = ResourceWaiter(
            resourceId: resourceId,
            agentId: agentId,
            quantity: quantity,
            requestedAt: Date(),
            deadline: Date().addingTimeInterval(timeout)
        )
        waitingQueue.append(waiter)
        stats.queuedRequests += 1

        // Wait with polling
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < timeout {
            try await Task.sleep(nanoseconds: 100_000_000)  // 100ms

            // Check if we can allocate now
            if let resource = resources[resourceId], resource.available >= quantity {
                // Remove from queue
                waitingQueue.removeAll { $0.agentId == agentId && $0.resourceId == resourceId }

                // Try to allocate
                return try await acquire(
                    resourceType: resource.type,
                    agentId: agentId,
                    quantity: quantity,
                    providerId: resource.providerId,
                    timeout: nil
                )
            }
        }

        // Timeout
        waitingQueue.removeAll { $0.agentId == agentId && $0.resourceId == resourceId }
        stats.timeoutRequests += 1
        return nil
    }

    // MARK: - Resource Release

    /// Release a resource allocation
    public func release(_ allocation: PoolResourceAllocation) {
        guard var storedAllocation = allocations[allocation.id] else {
            logger.warning("Allocation not found: \(allocation.id)")
            return
        }

        // Mark as released
        storedAllocation.releasedAt = Date()
        allocations[allocation.id] = storedAllocation

        // Return capacity to pool
        if var resource = resources[allocation.resourceId] {
            resource.available = min(resource.capacity, resource.available + allocation.quantity)
            resources[allocation.resourceId] = resource

            logger.debug("Released \(allocation.quantity) of \(resource.name)")
        }

        stats.currentActive = max(0, stats.currentActive - 1)

        // Process waiting queue
        Task {
            await processWaitingQueue()
        }
    }

    /// Release all allocations for an agent
    public func releaseAll(for agentId: UUID) {
        let agentAllocations = allocations.values.filter {
            $0.agentId == agentId && $0.isActive
        }

        for allocation in agentAllocations {
            release(allocation)
        }

        logger.info("Released \(agentAllocations.count) allocations for agent \(agentId.uuidString.prefix(8))")
    }

    // MARK: - Rate Limiting

    /// Apply cooldown to a provider resource after rate limit hit
    public func applyCooldown(providerId: String, seconds: TimeInterval) {
        for (id, var resource) in resources where resource.providerId == providerId {
            resource.cooldownUntil = Date().addingTimeInterval(seconds)
            resources[id] = resource
        }

        stats.rateLimitHits += 1
        logger.warning("Applied \(seconds)s cooldown to provider: \(providerId)")
    }

    /// Update rate limit configuration for a provider
    public func updateRateLimit(providerId: String, config: RateLimitConfig) {
        providerRateLimits[providerId] = config

        // Update resource capacity
        for (id, var resource) in resources where resource.providerId == providerId {
            let newCapacity = config.requestsPerMinute / 10  // Convert to concurrent slots
            resource.available += (newCapacity - resource.capacity)
            resource.capacity = newCapacity
            resources[id] = resource
        }

        logger.info("Updated rate limit for \(providerId): \(config.requestsPerMinute) req/min")
    }

    // MARK: - Queue Processing

    /// Process waiting queue and allocate resources
    private func processWaitingQueue() async {
        let now = Date()

        // Remove expired waiters
        waitingQueue.removeAll { $0.deadline < now }

        // Sort by wait time (FIFO)
        waitingQueue.sort { $0.requestedAt < $1.requestedAt }

        // Try to satisfy waiters
        var satisfied: [UUID] = []

        for waiter in waitingQueue {
            if let resource = resources[waiter.resourceId], resource.available >= waiter.quantity {
                // This waiter will be satisfied in their next poll cycle
                satisfied.append(waiter.agentId)
            }
        }
    }

    // MARK: - Query Methods

    /// Find a resource by type and optional provider
    private func findResource(type: PoolResourceType, providerId: String?) -> PooledResource? {
        if let providerId = providerId {
            return resources.values.first { $0.type == type && $0.providerId == providerId }
        }
        return resources.values.first { $0.type == type }
    }

    /// Get all resources
    public var allResources: [PooledResource] {
        Array(resources.values)
    }

    /// Get resource by ID
    public func getResource(_ id: UUID) -> PooledResource? {
        resources[id]
    }

    /// Get active allocations for an agent
    public func allocations(for agentId: UUID) -> [PoolResourceAllocation] {
        allocations.values.filter { $0.agentId == agentId && $0.isActive }
    }

    /// Get API slot availability for a provider
    public func apiSlotAvailability(for providerId: String) -> (available: Int, total: Int)? {
        guard let resource = findResource(type: .apiSlot, providerId: providerId) else {
            return nil
        }
        return (resource.available, resource.capacity)
    }

    /// Get pool statistics
    public func getStats() -> ResourcePoolStats {
        stats
    }

    /// Get utilization summary
    public func utilizationSummary() -> [String: Double] {
        var summary: [String: Double] = [:]
        for resource in resources.values {
            summary[resource.name] = resource.utilizationPercent
        }
        return summary
    }

    // MARK: - Resource Management

    /// Register a custom resource
    public func registerResource(_ resource: PooledResource) {
        resources[resource.id] = resource
        logger.info("Registered resource: \(resource.name)")
    }

    /// Update resource capacity
    public func updateCapacity(resourceId: UUID, newCapacity: Int) {
        guard var resource = resources[resourceId] else { return }

        let delta = newCapacity - resource.capacity
        resource.capacity = newCapacity
        resource.available = max(0, resource.available + delta)
        resources[resourceId] = resource

        logger.info("Updated capacity for \(resource.name): \(newCapacity)")
    }

    /// Reset all resources (for testing)
    public func reset() {
        resources.removeAll()
        allocations.removeAll()
        waitingQueue.removeAll()
        stats = ResourcePoolStats()
        initializeDefaultResources()
    }
}

// MARK: - Supporting Types

/// Configuration for provider rate limits
public struct RateLimitConfig: Sendable {
    public var requestsPerMinute: Int
    public var tokensPerMinute: Int
    public var cooldownSeconds: Double

    public init(
        requestsPerMinute: Int = 60,
        tokensPerMinute: Int = 100_000,
        cooldownSeconds: Double = 1.0
    ) {
        self.requestsPerMinute = requestsPerMinute
        self.tokensPerMinute = tokensPerMinute
        self.cooldownSeconds = cooldownSeconds
    }
}

/// Represents an agent waiting for a resource
struct ResourceWaiter: Sendable {
    let resourceId: UUID
    let agentId: UUID
    let quantity: Int
    let requestedAt: Date
    let deadline: Date
}

/// Statistics for the resource pool
public struct ResourcePoolStats: Sendable {
    public var totalAllocations: Int = 0
    public var currentActive: Int = 0
    public var rejectedRequests: Int = 0
    public var queuedRequests: Int = 0
    public var timeoutRequests: Int = 0
    public var rateLimitHits: Int = 0

    public var successRate: Double {
        guard totalAllocations > 0 else { return 1.0 }
        return Double(totalAllocations) / Double(totalAllocations + rejectedRequests)
    }
}
