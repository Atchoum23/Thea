//
//  TheaAgentSession.swift
//  Thea
//
//  Observable model representing a single sub-agent's execution session.
//  Part of the Supervisor/Worker delegation architecture.
//

import Foundation

// MARK: - Agent State

/// Lifecycle states for a sub-agent session
public enum TheaAgentState: String, CaseIterable, Codable, Sendable {
    case idle
    case planning
    case working
    case awaitingApproval
    case paused
    case completed
    case failed
    case cancelled

    public var isTerminal: Bool {
        switch self {
        case .completed, .failed, .cancelled: true
        default: false
        }
    }

    public var isActive: Bool {
        switch self {
        case .planning, .working, .awaitingApproval: true
        default: false
        }
    }

    public var displayName: String {
        switch self {
        case .idle: "Idle"
        case .planning: "Planning"
        case .working: "Working"
        case .awaitingApproval: "Awaiting Approval"
        case .paused: "Paused"
        case .completed: "Completed"
        case .failed: "Failed"
        case .cancelled: "Cancelled"
        }
    }

    public var sfSymbol: String {
        switch self {
        case .idle: "circle"
        case .planning: "brain"
        case .working: "gearshape.2.fill"
        case .awaitingApproval: "hand.raised.fill"
        case .paused: "pause.circle.fill"
        case .completed: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        case .cancelled: "stop.circle.fill"
        }
    }
}

// MARK: - Agent Message

/// A single message in a sub-agent's conversation
public struct TheaAgentMessage: Identifiable, Sendable {
    public let id: UUID
    public let role: Role
    public let content: String
    public let timestamp: Date

    public enum Role: String, Sendable {
        case system
        case user
        case agent
    }

    public init(
        id: UUID = UUID(),
        role: Role,
        content: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

// MARK: - Agent Artifact

/// An output artifact produced by a sub-agent
public struct TheaAgentArtifact: Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let type: ArtifactType
    public let content: String
    public let createdAt: Date

    public enum ArtifactType: String, Sendable {
        case code
        case text
        case markdown
        case json
        case plan
        case summary
    }

    public init(
        id: UUID = UUID(),
        title: String,
        type: ArtifactType,
        content: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.content = content
        self.createdAt = createdAt
    }
}

// MARK: - Context Pressure

/// Context window pressure levels for proactive management
public enum TheaContextPressure: String, Comparable, Sendable {
    case nominal   // <60%
    case elevated  // 60-80%
    case critical  // 80-95%
    case exceeded  // >95%

    public static func < (lhs: TheaContextPressure, rhs: TheaContextPressure) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }

    private var sortOrder: Int {
        switch self {
        case .nominal: 0
        case .elevated: 1
        case .critical: 2
        case .exceeded: 3
        }
    }

    public static func from(usage: Double) -> TheaContextPressure {
        switch usage {
        case ..<0.6: .nominal
        case ..<0.8: .elevated
        case ..<0.95: .critical
        default: .exceeded
        }
    }
}

// MARK: - Agent Feedback

/// User quality rating for a completed agent session
public enum AgentFeedbackRating: String, Codable, Sendable {
    case positive   // thumbs up
    case negative   // thumbs down

    public var sfSymbol: String {
        switch self {
        case .positive: "hand.thumbsup.fill"
        case .negative: "hand.thumbsdown.fill"
        }
    }
}

// MARK: - Agent Cost Estimation

/// Estimated cost per 1M tokens for known models (input, output)
public enum AgentCostEstimator {
    /// Returns (inputCostPer1M, outputCostPer1M) in USD for a model ID.
    public static func costPerMillionTokens(modelId: String) -> (input: Double, output: Double) {
        let lower = modelId.lowercased()
        // Anthropic
        if lower.contains("opus") { return (15.0, 75.0) }
        if lower.contains("sonnet") { return (3.0, 15.0) }
        if lower.contains("haiku") { return (0.25, 1.25) }
        // OpenAI
        if lower.contains("gpt-4o-mini") { return (0.15, 0.60) }
        if lower.contains("gpt-4o") { return (2.50, 10.0) }
        if lower.contains("o1") || lower.contains("o3") { return (15.0, 60.0) }
        // Google
        if lower.contains("gemini") { return (0.50, 1.50) }
        // DeepSeek
        if lower.contains("deepseek") { return (0.27, 1.10) }
        // Local models (free)
        if lower.contains("local") || lower.contains("mlx") { return (0.0, 0.0) }
        // Default (assume mid-range)
        return (1.0, 3.0)
    }

    /// Estimate total cost for a session based on token usage and model.
    /// Assumes ~30% of tokens are output tokens (conservative estimate).
    public static func estimateCost(tokensUsed: Int, modelId: String?) -> Double {
        guard let modelId, tokensUsed > 0 else { return 0 }
        let (inputCost, outputCost) = costPerMillionTokens(modelId: modelId)
        let outputTokens = Double(tokensUsed) * 0.3
        let inputTokens = Double(tokensUsed) * 0.7
        return (inputTokens * inputCost + outputTokens * outputCost) / 1_000_000
    }
}

// MARK: - TheaAgentSession

/// Observable model for a sub-agent execution session.
/// Each session represents one delegated task running in parallel.
@MainActor
@Observable
public final class TheaAgentSession: Identifiable {
    // MARK: - Identity

    public let id: UUID
    public let agentType: SpecializedAgentType
    public var name: String
    public var taskDescription: String
    public let parentConversationID: UUID

    // MARK: - Lifecycle

    public var state: TheaAgentState = .idle
    public var progress: Double?
    public var statusMessage: String = ""
    public var error: String?
    public let startedAt: Date
    public var completedAt: Date?

    // MARK: - Output

    public var messages: [TheaAgentMessage] = []
    public var artifacts: [TheaAgentArtifact] = []

    // MARK: - Metrics

    public var confidence: Float = 0
    public var tokensUsed: Int = 0

    // MARK: - Context Management

    public var tokenBudget: Int = 8192
    public var contextPressure: TheaContextPressure = .nominal
    public var summarizationCount: Int = 0
    public var lastSummarizedAt: Date?

    // MARK: - Delegation Hierarchy

    /// Depth in the delegation tree: 0 = Meta-AI, 1 = sub-agent, 2 = worker
    public let delegationDepth: Int
    /// ID of the parent session that spawned this agent (nil for top-level)
    public let parentSessionID: UUID?
    /// Whether this session can delegate sub-tasks (depth < 2)
    public var canDelegate: Bool { delegationDepth < 2 }

    // MARK: - Autonomy

    public var autonomyLevel: THEAAutonomyLevel = .balanced

    // MARK: - User Feedback

    /// User's quality rating for this session (nil = not yet rated)
    public var userRating: AgentFeedbackRating?
    /// Optional user comment about the agent's performance
    public var userFeedbackComment: String?

    // MARK: - Cost Tracking

    /// Model ID used for this session (for cost calculation)
    public var modelId: String?
    /// Provider ID used for this session
    public var providerId: String?

    // MARK: - Computed

    public var elapsed: TimeInterval {
        let end = completedAt ?? Date()
        return end.timeIntervalSince(startedAt)
    }

    public var tokenUsageRatio: Double {
        guard tokenBudget > 0 else { return 0 }
        return Double(tokensUsed) / Double(tokenBudget)
    }

    /// Estimated USD cost based on tokens used and model pricing
    public var estimatedCost: Double {
        AgentCostEstimator.estimateCost(tokensUsed: tokensUsed, modelId: modelId)
    }

    /// Formatted cost string for display
    public var formattedCost: String {
        let cost = estimatedCost
        if cost == 0 { return "Free" }
        if cost < 0.01 { return "<$0.01" }
        return String(format: "$%.2f", cost)
    }

    // MARK: - Init

    public init(
        id: UUID = UUID(),
        agentType: SpecializedAgentType,
        name: String,
        taskDescription: String,
        parentConversationID: UUID,
        tokenBudget: Int = 8192,
        autonomyLevel: THEAAutonomyLevel = .balanced,
        delegationDepth: Int = 1,
        parentSessionID: UUID? = nil
    ) {
        self.id = id
        self.agentType = agentType
        self.name = name
        self.taskDescription = taskDescription
        self.parentConversationID = parentConversationID
        self.tokenBudget = tokenBudget
        self.autonomyLevel = autonomyLevel
        self.delegationDepth = delegationDepth
        self.parentSessionID = parentSessionID
        self.startedAt = Date()
    }

    // MARK: - State Transitions

    public func transition(to newState: TheaAgentState) {
        state = newState
        if newState.isTerminal {
            completedAt = Date()
        }
    }

    public func appendMessage(_ message: TheaAgentMessage) {
        messages.append(message)
    }

    public func addArtifact(_ artifact: TheaAgentArtifact) {
        artifacts.append(artifact)
    }

    public func updateContextPressure() {
        contextPressure = TheaContextPressure.from(usage: tokenUsageRatio)
    }
}
