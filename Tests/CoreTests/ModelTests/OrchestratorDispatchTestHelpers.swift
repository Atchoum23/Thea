// OrchestratorDispatchTestHelpers.swift
// Mirrored types and pure functions for OrchestratorDispatchTests

import Foundation

// MARK: - Mirrored Types

enum DispatchAgentType: String, CaseIterable, Codable, Sendable {
    case generalPurpose
    case research
    case codeGeneration
    case codeReview
    case debugging
    case documentation
    case planning
    case testing
    case explore
    case refactor
    case security
    case performance
    case design
    case data
    case devops

    var displayName: String {
        switch self {
        case .generalPurpose: "General Purpose"
        case .research: "Research"
        case .codeGeneration: "Code Generation"
        case .codeReview: "Code Review"
        case .debugging: "Debugging"
        case .documentation: "Documentation"
        case .planning: "Planning"
        case .testing: "Testing"
        case .explore: "Explore"
        case .refactor: "Refactor"
        case .security: "Security"
        case .performance: "Performance"
        case .design: "Design"
        case .data: "Data"
        case .devops: "DevOps"
        }
    }

    var defaultBudget: Int {
        switch self {
        case .research, .documentation: 16384
        case .planning, .codeReview: 12288
        default: 8192
        }
    }
}

enum DispatchAgentState: String, CaseIterable, Codable, Sendable {
    case idle
    case planning
    case working
    case awaitingApproval
    case paused
    case completed
    case failed
    case cancelled

    var isTerminal: Bool {
        switch self {
        case .completed, .failed, .cancelled: true
        default: false
        }
    }

    var isActive: Bool {
        switch self {
        case .planning, .working, .awaitingApproval: true
        default: false
        }
    }
}

struct DispatchAgentSession: Identifiable, Sendable {
    let id: UUID
    let agentType: DispatchAgentType
    var state: DispatchAgentState
    var tokenBudget: Int
    var tokensUsed: Int
    var startedAt: Date
    var completedAt: Date?
    var output: String
    var artifacts: [String]

    init(
        id: UUID = UUID(),
        agentType: DispatchAgentType,
        state: DispatchAgentState = .idle,
        tokenBudget: Int? = nil,
        tokensUsed: Int = 0,
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        output: String = "",
        artifacts: [String] = []
    ) {
        self.id = id
        self.agentType = agentType
        self.state = state
        self.tokenBudget = tokenBudget ?? agentType.defaultBudget
        self.tokensUsed = tokensUsed
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.output = output
        self.artifacts = artifacts
    }

    var tokenUsageRatio: Double {
        guard tokenBudget > 0 else { return 0 }
        return Double(tokensUsed) / Double(tokenBudget)
    }
}

struct DispatchActivity: Identifiable, Sendable {
    let id: UUID
    let sessionID: UUID?
    let event: String
    let detail: String
    let timestamp: Date

    init(
        id: UUID = UUID(),
        sessionID: UUID? = nil,
        event: String,
        detail: String = "",
        timestamp: Date = Date()
    ) {
        self.id = id
        self.sessionID = sessionID
        self.event = event
        self.detail = detail
        self.timestamp = timestamp
    }
}

// MARK: - Pure Functions (mirrors TheaAgentOrchestrator)

func selectDispatchAgentType(for taskDescription: String) -> DispatchAgentType {
    let lowered = taskDescription.lowercased()
    if lowered.contains("research") || lowered.contains("find") || lowered.contains("search") {
        return .research
    } else if lowered.contains("write code") || lowered.contains("implement") || lowered.contains("create") {
        return .codeGeneration
    } else if lowered.contains("review") || lowered.contains("check") {
        return .codeReview
    } else if lowered.contains("debug") || lowered.contains("fix") || lowered.contains("bug") {
        return .debugging
    } else if lowered.contains("document") || lowered.contains("docs") {
        return .documentation
    } else if lowered.contains("plan") || lowered.contains("design") {
        return .planning
    } else if lowered.contains("test") {
        return .testing
    } else if lowered.contains("explore") || lowered.contains("investigate") {
        return .explore
    } else if lowered.contains("refactor") || lowered.contains("clean") {
        return .refactor
    } else if lowered.contains("security") || lowered.contains("vulnerability") {
        return .security
    } else if lowered.contains("performance") || lowered.contains("optimize") {
        return .performance
    }
    return .generalPurpose
}

func synthesizeDispatchResults(from sessions: [DispatchAgentSession]) -> String {
    let completed = sessions.filter { $0.state == .completed }
    guard !completed.isEmpty else { return "No completed agent results to synthesize." }

    var parts: [String] = []
    for session in completed {
        var section = "## \(session.agentType.displayName)\n"
        let outputPreview = session.output.prefix(500)
        section += String(outputPreview)
        if !session.artifacts.isEmpty {
            section += "\n\n### Artifacts\n"
            for artifact in session.artifacts {
                section += "- \(artifact)\n"
            }
        }
        parts.append(section)
    }
    return parts.joined(separator: "\n\n---\n\n")
}

func reallocateDispatchContextBudget(
    sessions: inout [DispatchAgentSession],
    totalTokenPool: Int = 500_000
) {
    let completed = sessions.filter { $0.state.isTerminal }
    let active = sessions.filter { $0.state == .working && $0.tokenUsageRatio >= 0.6 }

    for i in sessions.indices where sessions[i].state.isTerminal {
        sessions[i].tokenBudget = sessions[i].tokensUsed
    }

    let allocatedTokens = sessions.map(\.tokenBudget).reduce(0, +)
    let freeTokens = totalTokenPool - allocatedTokens

    guard !active.isEmpty, freeTokens > 0, !completed.isEmpty else { return }

    let perAgent = freeTokens / active.count
    for i in sessions.indices where sessions[i].state == .working && sessions[i].tokenUsageRatio >= 0.6 {
        sessions[i].tokenBudget += perAgent
    }
}

func pruneOldDispatchSessions(
    sessions: inout [DispatchAgentSession],
    olderThan interval: TimeInterval = 3600
) {
    let cutoff = Date().addingTimeInterval(-interval)
    sessions.removeAll { session in
        session.state.isTerminal
            && (session.completedAt ?? session.startedAt) < cutoff
    }
}
