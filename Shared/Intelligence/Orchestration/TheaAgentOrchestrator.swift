//
//  TheaAgentOrchestrator.swift
//  Thea
//
//  Supervisor that delegates tasks to specialized sub-agents.
//  Each sub-agent runs in parallel with its own isolated context.
//  Thea (lead AI) decomposes, delegates, monitors, and synthesizes.
//

import Foundation
import os.log

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

// MARK: - TheaAgentOrchestrator

/// Main supervisor for the sub-agent delegation system.
/// Manages session lifecycle, delegates tasks, monitors context, synthesizes results.
@MainActor
@Observable
public final class TheaAgentOrchestrator {
    public static let shared = TheaAgentOrchestrator()

    private let logger = Logger(subsystem: "app.thea", category: "AgentOrchestrator")

    // MARK: - Published State

    public var sessions: [TheaAgentSession] = []
    public var activityLog: [TheaAgentActivity] = []

    // MARK: - Context Pool

    private let totalTokenPool: Int = 500_000
    private var allocatedTokens: Int {
        sessions.map(\.tokenBudget).reduce(0, +)
    }

    private var freeTokens: Int {
        totalTokenPool - allocatedTokens
    }

    // MARK: - Runner

    private let runner = TheaAgentRunner()

    // MARK: - Init

    private init() {}

    // MARK: - Delegate Task

    /// Create and spawn a single agent session for a task.
    @discardableResult
    public func delegateTask(
        description: String,
        from conversationID: UUID,
        agentType: SpecializedAgentType? = nil
    ) async -> TheaAgentSession {
        let selectedType: SpecializedAgentType
        if let explicit = agentType {
            selectedType = explicit
        } else {
            selectedType = await EnhancedSubagentSystem.shared.selectAgentType(for: description)
        }

        let session = TheaAgentSession(
            agentType: selectedType,
            name: "\(selectedType.rawValue.capitalized) Agent #\(sessions.count + 1)",
            taskDescription: description,
            parentConversationID: conversationID,
            tokenBudget: defaultBudget(for: selectedType)
        )

        sessions.append(session)
        logActivity(sessionID: session.id, event: "delegated", detail: "Type: \(selectedType.rawValue), task: \(description.prefix(80))")

        // Spawn execution
        Task {
            await executeSession(session)
        }

        return session
    }

    /// Spawn multiple agents in parallel for independent tasks.
    @discardableResult
    public func delegateParallelTasks(
        descriptions: [String],
        from conversationID: UUID
    ) async -> [TheaAgentSession] {
        var createdSessions: [TheaAgentSession] = []

        for desc in descriptions {
            let selectedType = await EnhancedSubagentSystem.shared.selectAgentType(for: desc)
            let session = TheaAgentSession(
                agentType: selectedType,
                name: "\(selectedType.rawValue.capitalized) Agent #\(sessions.count + 1)",
                taskDescription: desc,
                parentConversationID: conversationID,
                tokenBudget: defaultBudget(for: selectedType)
            )
            sessions.append(session)
            createdSessions.append(session)
            logActivity(sessionID: session.id, event: "delegated-parallel", detail: desc.prefix(80).description)
        }

        // Spawn all in parallel
        for session in createdSessions {
            Task {
                await executeSession(session)
            }
        }

        return createdSessions
    }

    // MARK: - Session Control

    public func cancelSession(_ session: TheaAgentSession) {
        session.transition(to: .cancelled)
        logActivity(sessionID: session.id, event: "cancelled", detail: "User cancelled")
    }

    public func pauseSession(_ session: TheaAgentSession) {
        session.transition(to: .paused)
        logActivity(sessionID: session.id, event: "paused", detail: "User paused")
    }

    public func resumeSession(_ session: TheaAgentSession) async {
        session.transition(to: .working)
        logActivity(sessionID: session.id, event: "resumed", detail: "User resumed")
        Task {
            await executeSession(session)
        }
    }

    public func redirectSession(_ session: TheaAgentSession, newTask: String) async {
        session.taskDescription = newTask
        session.messages.removeAll()
        session.artifacts.removeAll()
        session.tokensUsed = 0
        session.summarizationCount = 0
        session.transition(to: .planning)
        logActivity(sessionID: session.id, event: "redirected", detail: newTask.prefix(80).description)
        Task {
            await executeSession(session)
        }
    }

    // MARK: - Result Synthesis

    /// Aggregate completed agent outputs into a coherent summary for the main chat.
    public func synthesizeResults(from targetSessions: [TheaAgentSession]) -> String {
        let completed = targetSessions.filter { $0.state == .completed }
        guard !completed.isEmpty else {
            return "No agent results available yet."
        }

        var parts: [String] = []
        for session in completed {
            let output = session.messages
                .filter { $0.role == .agent }
                .map(\.content)
                .joined(separator: "\n")
            let artifactSummary = session.artifacts.map { "[\($0.type.rawValue): \($0.title)]" }.joined(separator: ", ")
            var sessionSummary = "**\(session.name)** (\(session.agentType.rawValue)):\n\(output.prefix(500))"
            if !artifactSummary.isEmpty {
                sessionSummary += "\nArtifacts: \(artifactSummary)"
            }
            parts.append(sessionSummary)
        }

        return parts.joined(separator: "\n\n---\n\n")
    }

    // MARK: - Context Budget Management

    /// Reclaim tokens from completed agents and redistribute to active ones under pressure.
    public func reallocateContextBudget() {
        let completed = sessions.filter { $0.state.isTerminal }
        let active = sessions.filter { $0.state.isActive && $0.contextPressure >= .elevated }

        // Reclaim from completed agents
        for session in completed {
            session.tokenBudget = session.tokensUsed
        }

        // Distribute freed tokens to active agents under pressure
        if !active.isEmpty, freeTokens > 0 {
            let perAgent = freeTokens / active.count
            for session in active {
                session.tokenBudget += perAgent
                session.updateContextPressure()
            }
            logActivity(sessionID: nil, event: "budget-realloc", detail: "Distributed \(freeTokens) tokens to \(active.count) agents")
        }
    }

    // MARK: - Cleanup

    /// Remove terminal sessions older than the given interval.
    public func pruneOldSessions(olderThan interval: TimeInterval = 3600) {
        let cutoff = Date().addingTimeInterval(-interval)
        sessions.removeAll { session in
            session.state.isTerminal && (session.completedAt ?? session.startedAt) < cutoff
        }
    }

    // MARK: - Convenience Queries

    public var activeSessions: [TheaAgentSession] {
        sessions.filter { $0.state.isActive }
    }

    public var completedSessions: [TheaAgentSession] {
        sessions.filter { $0.state == .completed }
    }

    // MARK: - Private Helpers

    private func executeSession(_ session: TheaAgentSession) async {
        guard !session.state.isTerminal else { return }

        do {
            // Get provider and model from ChatManager's routing
            let (provider, model, _) = try await ChatManager.shared.selectProviderAndModel(for: session.taskDescription)

            // Acquire API slot
            let allocation = try await AgentResourcePool.shared.acquire(
                resourceType: .apiSlot,
                agentId: session.id,
                providerId: provider.metadata.name
            )

            defer {
                if let alloc = allocation {
                    Task {
                        await AgentResourcePool.shared.release(alloc)
                    }
                }
            }

            await runner.execute(session: session, provider: provider, model: model)

            // Post-completion: distill and reallocate
            reallocateContextBudget()
            logActivity(sessionID: session.id, event: "completed", detail: "Tokens: \(session.tokensUsed), confidence: \(session.confidence)")

        } catch {
            session.error = error.localizedDescription
            session.transition(to: .failed)
            logActivity(sessionID: session.id, event: "failed", detail: error.localizedDescription)
        }
    }

    private func defaultBudget(for agentType: SpecializedAgentType) -> Int {
        switch agentType {
        case .research, .documentation: 16384
        case .plan, .review: 12288
        case .explore, .debug: 8192
        default: 8192
        }
    }

    private func logActivity(sessionID: UUID?, event: String, detail: String) {
        let activity = TheaAgentActivity(sessionID: sessionID, event: event, detail: detail)
        activityLog.append(activity)
        if activityLog.count > 500 {
            activityLog.removeFirst(activityLog.count - 500)
        }
        logger.info("Agent[\(sessionID?.uuidString.prefix(8) ?? "system")]: \(event) — \(detail)")
    }
}
