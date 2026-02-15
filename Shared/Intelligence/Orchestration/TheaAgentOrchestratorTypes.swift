//
//  TheaAgentOrchestratorTypes.swift
//  Thea
//
//  Value types used by TheaAgentOrchestrator:
//  - TheaAgentActivity (audit trail)
//  - DelegationDecision (request-approve gate result)
//  - CachedTaskResult (task result cache entry)
//

import Foundation

// MARK: - Activity Log

/// Audit trail entry for agent orchestration events
public struct TheaAgentActivity: Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let sessionID: UUID?
    public let event: String
    public let detail: String

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        sessionID: UUID? = nil,
        event: String,
        detail: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.sessionID = sessionID
        self.event = event
        self.detail = detail
    }
}

// MARK: - Delegation Decision

/// Result of a delegation request through the request-approve gate
public enum DelegationDecision: Sendable {
    case approve(UUID)                // New worker spawned, returns session ID
    case reuseExisting(UUID)          // Point to in-progress worker doing same task
    case returnCached(String)         // Result already available from cache
    case deny(reason: String)         // Too many workers, budget exhausted, etc.
}

// MARK: - Cached Task Result

/// Cached result from a completed worker, with TTL for freshness
public struct CachedTaskResult: Sendable {
    public let result: String
    public let completedAt: Date
    public let agentType: SpecializedAgentType
    public let tokensUsed: Int

    public init(result: String, completedAt: Date = Date(), agentType: SpecializedAgentType, tokensUsed: Int) {
        self.result = result
        self.completedAt = completedAt
        self.agentType = agentType
        self.tokensUsed = tokensUsed
    }
}

// MARK: - Agent Feedback Statistics

/// Tracks user feedback statistics for an agent type to improve future selection.
public struct AgentTypeFeedbackStats: Sendable {
    public var positiveCount: Int = 0
    public var negativeCount: Int = 0

    public var totalCount: Int { positiveCount + negativeCount }

    /// Success rate based on user feedback (nil if no feedback yet)
    public var successRate: Double? {
        guard totalCount > 0 else { return nil }
        return Double(positiveCount) / Double(totalCount)
    }

    public mutating func record(positive: Bool) {
        if positive {
            positiveCount += 1
        } else {
            negativeCount += 1
        }
    }
}
