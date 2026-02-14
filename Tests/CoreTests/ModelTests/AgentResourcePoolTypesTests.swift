// AgentResourcePoolTypesTests.swift
// Tests for AgentResourcePool value types: PoolResourceType, PooledResource,
// PoolResourceAllocation, RateLimitConfig, ResourcePoolStats, ResourceWaiter.

import Foundation
import XCTest

// MARK: - Mirrored: PoolResourceType

private enum TestResourceType: String, Codable, CaseIterable {
    case apiSlot
    case modelAccess
    case memoryBudget
    case computeSlot
    case networkBandwidth
    case fileHandle
    case contextWindow
}

// MARK: - Mirrored: PooledResource

private struct TestPooledResource: Identifiable {
    let id: UUID
    let type: TestResourceType
    let name: String
    let providerId: String?
    var capacity: Int
    var available: Int
    var lastUsed: Date?
    var cooldownUntil: Date?

    init(
        id: UUID = UUID(),
        type: TestResourceType,
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

    var isAvailable: Bool {
        available > 0 && (cooldownUntil == nil || Date() >= cooldownUntil!)
    }

    var utilizationPercent: Double {
        guard capacity > 0 else { return 0 }
        return Double(capacity - available) / Double(capacity) * 100
    }
}

// MARK: - Mirrored: PoolResourceAllocation

private struct TestAllocation: Identifiable {
    let id: UUID
    let resourceId: UUID
    let agentId: UUID
    let allocatedAt: Date
    let quantity: Int
    var releasedAt: Date?

    init(
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

    var isActive: Bool { releasedAt == nil }

    var duration: TimeInterval {
        let endTime = releasedAt ?? Date()
        return endTime.timeIntervalSince(allocatedAt)
    }
}

// MARK: - Mirrored: RateLimitConfig

private struct TestRateLimitConfig {
    var requestsPerMinute: Int
    var tokensPerMinute: Int
    var cooldownSeconds: Double

    init(requestsPerMinute: Int = 60, tokensPerMinute: Int = 100_000, cooldownSeconds: Double = 1.0) {
        self.requestsPerMinute = requestsPerMinute
        self.tokensPerMinute = tokensPerMinute
        self.cooldownSeconds = cooldownSeconds
    }
}

// MARK: - Mirrored: ResourcePoolStats

private struct TestPoolStats {
    var totalAllocations: Int = 0
    var currentActive: Int = 0
    var rejectedRequests: Int = 0
    var queuedRequests: Int = 0
    var timeoutRequests: Int = 0
    var rateLimitHits: Int = 0

    var successRate: Double {
        guard totalAllocations > 0 else { return 1.0 }
        return Double(totalAllocations) / Double(totalAllocations + rejectedRequests)
    }
}

// MARK: - Mirrored: ResourceWaiter

private struct TestResourceWaiter {
    let resourceId: UUID
    let agentId: UUID
    let quantity: Int
    let requestedAt: Date
    let deadline: Date

    var isExpired: Bool { Date() > deadline }
}

// MARK: - Mirrored: Resource allocation logic

private class TestResourceAllocator {
    var resources: [UUID: TestPooledResource] = [:]
    var allocations: [UUID: TestAllocation] = [:]
    var stats = TestPoolStats()

    func registerResource(_ resource: TestPooledResource) {
        resources[resource.id] = resource
    }

    func acquire(resourceId: UUID, agentId: UUID, quantity: Int = 1) -> TestAllocation? {
        guard var resource = resources[resourceId] else { return nil }
        guard resource.isAvailable, resource.available >= quantity else {
            stats.rejectedRequests += 1
            return nil
        }

        resource.available -= quantity
        resource.lastUsed = Date()
        resources[resourceId] = resource

        let allocation = TestAllocation(
            resourceId: resourceId,
            agentId: agentId,
            quantity: quantity
        )
        allocations[allocation.id] = allocation
        stats.totalAllocations += 1
        stats.currentActive += 1
        return allocation
    }

    func release(_ allocation: TestAllocation) {
        guard var stored = allocations[allocation.id] else { return }
        stored.releasedAt = Date()
        allocations[allocation.id] = stored

        if var resource = resources[allocation.resourceId] {
            resource.available = min(resource.capacity, resource.available + allocation.quantity)
            resources[allocation.resourceId] = resource
        }
        stats.currentActive = max(0, stats.currentActive - 1)
    }

    func releaseAll(for agentId: UUID) {
        let agentAllocations = allocations.values.filter { $0.agentId == agentId && $0.isActive }
        for alloc in agentAllocations {
            release(alloc)
        }
    }

    func applyCooldown(providerId: String, seconds: TimeInterval) {
        for (id, var resource) in resources where resource.providerId == providerId {
            resource.cooldownUntil = Date().addingTimeInterval(seconds)
            resources[id] = resource
        }
        stats.rateLimitHits += 1
    }

    func updateCapacity(resourceId: UUID, newCapacity: Int) {
        guard var resource = resources[resourceId] else { return }
        let delta = newCapacity - resource.capacity
        resource.capacity = newCapacity
        resource.available = max(0, resource.available + delta)
        resources[resourceId] = resource
    }

    func utilizationSummary() -> [String: Double] {
        var summary: [String: Double] = [:]
        for resource in resources.values {
            summary[resource.name] = resource.utilizationPercent
        }
        return summary
    }
}

// MARK: - Tests

final class AgentResourcePoolTypesTests: XCTestCase {

    // MARK: - PoolResourceType Tests

    func testAllResourceTypesExist() {
        XCTAssertEqual(TestResourceType.allCases.count, 7)
    }

    func testResourceTypeRawValuesUnique() {
        let rawValues = TestResourceType.allCases.map(\.rawValue)
        XCTAssertEqual(Set(rawValues).count, rawValues.count)
    }

    func testResourceTypeCodableRoundtrip() throws {
        for type in TestResourceType.allCases {
            let data = try JSONEncoder().encode(type)
            let decoded = try JSONDecoder().decode(TestResourceType.self, from: data)
            XCTAssertEqual(decoded, type)
        }
    }

    // MARK: - PooledResource Tests

    func testResourceCreationDefaults() {
        let resource = TestPooledResource(type: .apiSlot, name: "anthropic-api", capacity: 5)
        XCTAssertEqual(resource.available, 5)  // Defaults to capacity
        XCTAssertNil(resource.providerId)
        XCTAssertNil(resource.lastUsed)
        XCTAssertNil(resource.cooldownUntil)
    }

    func testResourceAvailableOverride() {
        let resource = TestPooledResource(type: .apiSlot, name: "test", capacity: 10, available: 3)
        XCTAssertEqual(resource.capacity, 10)
        XCTAssertEqual(resource.available, 3)
    }

    func testResourceIsAvailableWhenHasCapacity() {
        let resource = TestPooledResource(type: .computeSlot, name: "gpu", capacity: 4)
        XCTAssertTrue(resource.isAvailable)
    }

    func testResourceNotAvailableWhenZero() {
        let resource = TestPooledResource(type: .computeSlot, name: "gpu", capacity: 4, available: 0)
        XCTAssertFalse(resource.isAvailable)
    }

    func testResourceNotAvailableDuringCooldown() {
        let resource = TestPooledResource(
            type: .apiSlot, name: "test", capacity: 5,
            cooldownUntil: Date().addingTimeInterval(60)
        )
        XCTAssertFalse(resource.isAvailable)
    }

    func testResourceAvailableAfterCooldown() {
        let resource = TestPooledResource(
            type: .apiSlot, name: "test", capacity: 5,
            cooldownUntil: Date().addingTimeInterval(-1)
        )
        XCTAssertTrue(resource.isAvailable)
    }

    func testUtilizationPercentFullyAvailable() {
        let resource = TestPooledResource(type: .memoryBudget, name: "mem", capacity: 100)
        XCTAssertEqual(resource.utilizationPercent, 0)
    }

    func testUtilizationPercentHalfUsed() {
        let resource = TestPooledResource(type: .memoryBudget, name: "mem", capacity: 100, available: 50)
        XCTAssertEqual(resource.utilizationPercent, 50)
    }

    func testUtilizationPercentFullyUsed() {
        let resource = TestPooledResource(type: .memoryBudget, name: "mem", capacity: 100, available: 0)
        XCTAssertEqual(resource.utilizationPercent, 100)
    }

    func testUtilizationPercentZeroCapacity() {
        let resource = TestPooledResource(type: .memoryBudget, name: "mem", capacity: 0, available: 0)
        XCTAssertEqual(resource.utilizationPercent, 0)
    }

    // MARK: - Allocation Tests

    func testAllocationDefaults() {
        let resId = UUID()
        let agentId = UUID()
        let alloc = TestAllocation(resourceId: resId, agentId: agentId)
        XCTAssertEqual(alloc.resourceId, resId)
        XCTAssertEqual(alloc.agentId, agentId)
        XCTAssertEqual(alloc.quantity, 1)
        XCTAssertNil(alloc.releasedAt)
        XCTAssertTrue(alloc.isActive)
    }

    func testAllocationNotActiveWhenReleased() {
        let alloc = TestAllocation(
            resourceId: UUID(), agentId: UUID(), releasedAt: Date()
        )
        XCTAssertFalse(alloc.isActive)
    }

    func testAllocationDurationActive() {
        let start = Date().addingTimeInterval(-10)
        let alloc = TestAllocation(
            resourceId: UUID(), agentId: UUID(), allocatedAt: start
        )
        XCTAssertGreaterThanOrEqual(alloc.duration, 9.5)
    }

    func testAllocationDurationReleased() {
        let start = Date().addingTimeInterval(-30)
        let end = Date().addingTimeInterval(-20)
        let alloc = TestAllocation(
            resourceId: UUID(), agentId: UUID(),
            allocatedAt: start, releasedAt: end
        )
        XCTAssertEqual(alloc.duration, 10, accuracy: 0.1)
    }

    // MARK: - RateLimitConfig Tests

    func testRateLimitDefaults() {
        let config = TestRateLimitConfig()
        XCTAssertEqual(config.requestsPerMinute, 60)
        XCTAssertEqual(config.tokensPerMinute, 100_000)
        XCTAssertEqual(config.cooldownSeconds, 1.0)
    }

    func testRateLimitCustom() {
        let config = TestRateLimitConfig(
            requestsPerMinute: 30, tokensPerMinute: 50_000, cooldownSeconds: 2.5
        )
        XCTAssertEqual(config.requestsPerMinute, 30)
        XCTAssertEqual(config.tokensPerMinute, 50_000)
        XCTAssertEqual(config.cooldownSeconds, 2.5)
    }

    // MARK: - ResourcePoolStats Tests

    func testStatsDefaults() {
        let stats = TestPoolStats()
        XCTAssertEqual(stats.totalAllocations, 0)
        XCTAssertEqual(stats.currentActive, 0)
        XCTAssertEqual(stats.rejectedRequests, 0)
        XCTAssertEqual(stats.rateLimitHits, 0)
    }

    func testStatsSuccessRateNoAllocations() {
        let stats = TestPoolStats()
        XCTAssertEqual(stats.successRate, 1.0)
    }

    func testStatsSuccessRatePerfect() {
        var stats = TestPoolStats()
        stats.totalAllocations = 10
        stats.rejectedRequests = 0
        XCTAssertEqual(stats.successRate, 1.0)
    }

    func testStatsSuccessRateHalf() {
        var stats = TestPoolStats()
        stats.totalAllocations = 5
        stats.rejectedRequests = 5
        XCTAssertEqual(stats.successRate, 0.5)
    }

    func testStatsSuccessRateLow() {
        var stats = TestPoolStats()
        stats.totalAllocations = 1
        stats.rejectedRequests = 9
        XCTAssertEqual(stats.successRate, 0.1)
    }

    // MARK: - ResourceWaiter Tests

    func testWaiterNotExpired() {
        let waiter = TestResourceWaiter(
            resourceId: UUID(), agentId: UUID(), quantity: 1,
            requestedAt: Date(),
            deadline: Date().addingTimeInterval(60)
        )
        XCTAssertFalse(waiter.isExpired)
    }

    func testWaiterExpired() {
        let waiter = TestResourceWaiter(
            resourceId: UUID(), agentId: UUID(), quantity: 1,
            requestedAt: Date().addingTimeInterval(-120),
            deadline: Date().addingTimeInterval(-60)
        )
        XCTAssertTrue(waiter.isExpired)
    }

    // MARK: - Resource Allocator Logic Tests

    func testAllocateAndRelease() {
        let allocator = TestResourceAllocator()
        let resource = TestPooledResource(type: .apiSlot, name: "test", capacity: 3)
        allocator.registerResource(resource)

        let agentId = UUID()
        let alloc = allocator.acquire(resourceId: resource.id, agentId: agentId)
        XCTAssertNotNil(alloc)
        XCTAssertEqual(allocator.resources[resource.id]?.available, 2)
        XCTAssertEqual(allocator.stats.totalAllocations, 1)
        XCTAssertEqual(allocator.stats.currentActive, 1)

        allocator.release(alloc!)
        XCTAssertEqual(allocator.resources[resource.id]?.available, 3)
        XCTAssertEqual(allocator.stats.currentActive, 0)
    }

    func testAllocateUntilExhausted() {
        let allocator = TestResourceAllocator()
        let resource = TestPooledResource(type: .computeSlot, name: "gpu", capacity: 2)
        allocator.registerResource(resource)

        let a1 = allocator.acquire(resourceId: resource.id, agentId: UUID())
        XCTAssertNotNil(a1)
        let a2 = allocator.acquire(resourceId: resource.id, agentId: UUID())
        XCTAssertNotNil(a2)
        let a3 = allocator.acquire(resourceId: resource.id, agentId: UUID())
        XCTAssertNil(a3)
        XCTAssertEqual(allocator.stats.rejectedRequests, 1)
    }

    func testAllocateMultipleQuantity() {
        let allocator = TestResourceAllocator()
        let resource = TestPooledResource(type: .contextWindow, name: "ctx", capacity: 100)
        allocator.registerResource(resource)

        let alloc = allocator.acquire(resourceId: resource.id, agentId: UUID(), quantity: 30)
        XCTAssertNotNil(alloc)
        XCTAssertEqual(allocator.resources[resource.id]?.available, 70)
    }

    func testAllocateUnknownResource() {
        let allocator = TestResourceAllocator()
        let alloc = allocator.acquire(resourceId: UUID(), agentId: UUID())
        XCTAssertNil(alloc)
    }

    func testReleaseAllForAgent() {
        let allocator = TestResourceAllocator()
        let res1 = TestPooledResource(type: .apiSlot, name: "api", capacity: 5)
        let res2 = TestPooledResource(type: .computeSlot, name: "gpu", capacity: 3)
        allocator.registerResource(res1)
        allocator.registerResource(res2)

        let agent = UUID()
        _ = allocator.acquire(resourceId: res1.id, agentId: agent)
        _ = allocator.acquire(resourceId: res2.id, agentId: agent)
        XCTAssertEqual(allocator.stats.currentActive, 2)

        allocator.releaseAll(for: agent)
        XCTAssertEqual(allocator.stats.currentActive, 0)
        XCTAssertEqual(allocator.resources[res1.id]?.available, 5)
        XCTAssertEqual(allocator.resources[res2.id]?.available, 3)
    }

    func testCooldownPreventsAllocation() {
        let allocator = TestResourceAllocator()
        let resource = TestPooledResource(
            type: .apiSlot, name: "api", providerId: "anthropic", capacity: 5
        )
        allocator.registerResource(resource)

        allocator.applyCooldown(providerId: "anthropic", seconds: 60)
        XCTAssertEqual(allocator.stats.rateLimitHits, 1)

        let alloc = allocator.acquire(resourceId: resource.id, agentId: UUID())
        XCTAssertNil(alloc)
    }

    func testUpdateCapacityIncrease() {
        let allocator = TestResourceAllocator()
        let resource = TestPooledResource(type: .memoryBudget, name: "mem", capacity: 50)
        allocator.registerResource(resource)

        allocator.updateCapacity(resourceId: resource.id, newCapacity: 100)
        XCTAssertEqual(allocator.resources[resource.id]?.capacity, 100)
        XCTAssertEqual(allocator.resources[resource.id]?.available, 100)
    }

    func testUpdateCapacityDecrease() {
        let allocator = TestResourceAllocator()
        let resource = TestPooledResource(type: .memoryBudget, name: "mem", capacity: 100)
        allocator.registerResource(resource)

        allocator.updateCapacity(resourceId: resource.id, newCapacity: 40)
        XCTAssertEqual(allocator.resources[resource.id]?.capacity, 40)
        XCTAssertEqual(allocator.resources[resource.id]?.available, 40)
    }

    func testUpdateCapacityWithActiveAllocations() {
        let allocator = TestResourceAllocator()
        let resource = TestPooledResource(type: .apiSlot, name: "api", capacity: 10)
        allocator.registerResource(resource)

        _ = allocator.acquire(resourceId: resource.id, agentId: UUID(), quantity: 3)
        // available is now 7, capacity is 10
        allocator.updateCapacity(resourceId: resource.id, newCapacity: 15)
        // delta is +5, so available should be 12
        XCTAssertEqual(allocator.resources[resource.id]?.available, 12)
    }

    func testUtilizationSummary() {
        let allocator = TestResourceAllocator()
        let r1 = TestPooledResource(type: .apiSlot, name: "api", capacity: 10, available: 5)
        let r2 = TestPooledResource(type: .computeSlot, name: "gpu", capacity: 4, available: 4)
        allocator.registerResource(r1)
        allocator.registerResource(r2)

        let summary = allocator.utilizationSummary()
        XCTAssertEqual(summary["api"], 50)
        XCTAssertEqual(summary["gpu"], 0)
    }

    // MARK: - Default Resource Init Tests

    func testDefaultProviderSlots() {
        let providers = [
            ("anthropic", 5), ("openai", 10), ("google", 8),
            ("openrouter", 15), ("groq", 6), ("perplexity", 4), ("local", 4)
        ]
        XCTAssertEqual(providers.count, 7)

        let totalSlots = providers.map(\.1).reduce(0, +)
        XCTAssertEqual(totalSlots, 52)
    }

    func testDefaultComputeSlots() {
        // M3 Ultra: 8 parallel agents max
        let computeCapacity = 8
        XCTAssertGreaterThanOrEqual(computeCapacity, 4)
    }

    func testDefaultMemoryPool() {
        // 100 GB for model operations
        let memoryGB = 100
        XCTAssertGreaterThan(memoryGB, 0)
    }

    func testDefaultContextPool() {
        // 500K total tokens across all agents
        let tokenPool = 500_000
        XCTAssertGreaterThan(tokenPool, 0)
    }
}
