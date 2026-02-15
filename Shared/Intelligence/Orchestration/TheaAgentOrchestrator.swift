//
//  TheaAgentOrchestrator.swift
//  Thea
//
//  Supervisor that delegates tasks to specialized sub-agents.
//  Each sub-agent runs in parallel with its own isolated context.
//  Thea (lead AI) decomposes, delegates, monitors, and synthesizes.
//  Types: TheaAgentOrchestratorTypes.swift
//

import Foundation
import os.log

// MARK: - TheaAgentOrchestrator

/// Main supervisor for the sub-agent delegation system.
/// Manages session lifecycle, delegates tasks, monitors context, synthesizes results.
/// Supports 2-layer delegation (sub-agents can spawn workers, workers cannot delegate).
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

    // MARK: - Task Registry & Cache

    /// Registry of delegated tasks, keyed by content hash for deduplication
    private var taskRegistry: [String: UUID] = [:]  // taskHash -> sessionID

    /// Subscribers waiting for a shared task result
    private var taskSubscribers: [String: [UUID]] = [:]  // taskHash -> [sessionIDs wanting result]

    /// Cached results from completed workers with TTL
    private var resultCache: [String: CachedTaskResult] = [:]
    private let cacheTTL: TimeInterval = 300  // 5 minutes

    // MARK: - Cost Tracking

    /// Cumulative cost across all sessions in this app lifecycle
    public var cumulativeCost: Double = 0

    /// Daily cost budget cap in USD (0 = no limit)
    public var dailyCostBudget: Double = 0

    /// Whether the daily budget has been exceeded
    public var isBudgetExceeded: Bool {
        dailyCostBudget > 0 && cumulativeCost >= dailyCostBudget
    }

    // MARK: - Feedback Stats

    /// Tracks feedback statistics per agent type for improving selection
    private var agentTypeFeedback: [SpecializedAgentType: AgentTypeFeedbackStats] = [:]

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
            tokenBudget: defaultBudget(for: selectedType, depth: 1)
        )

        sessions.append(session)
        taskRegistry[computeTaskHash(description)] = session.id
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
                tokenBudget: defaultBudget(for: selectedType, depth: 1)
            )
            sessions.append(session)
            createdSessions.append(session)
            taskRegistry[computeTaskHash(desc)] = session.id
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

    // MARK: - Multi-Layer Delegation (B-MLT2)

    /// Request-approve gate: sub-agents must request delegation through the orchestrator.
    /// Prevents duplicate work, enforces depth limits, manages resource budgets.
    public func requestDelegation(
        from parent: TheaAgentSession,
        task: String,
        agentType: SpecializedAgentType
    ) async -> DelegationDecision {
        // 1. Check depth cap (max 2 layers below Meta-AI)
        guard parent.canDelegate else {
            logActivity(sessionID: parent.id, event: "delegation-denied", detail: "Max depth reached (depth=\(parent.delegationDepth))")
            return .deny(reason: "Maximum delegation depth reached")
        }

        // 2. Check task registry for dedup
        let taskHash = computeTaskHash(task)
        if let cached = getCachedResult(taskHash: taskHash) {
            logActivity(sessionID: parent.id, event: "delegation-cached", detail: task.prefix(60).description)
            return .returnCached(cached.result)
        }

        if let existingSessionID = taskRegistry[taskHash],
           let existingSession = sessions.first(where: { $0.id == existingSessionID }) {
            if existingSession.state.isActive {
                subscribeToTask(taskHash: taskHash, subscriberID: parent.id)
                logActivity(sessionID: parent.id, event: "delegation-reuse", detail: "Reusing \(existingSessionID.uuidString.prefix(8))")
                return .reuseExisting(existingSessionID)
            } else if existingSession.state == .completed {
                let result = existingSession.messages.filter { $0.role == .agent }.map(\.content).joined(separator: "\n")
                cacheResult(taskHash: taskHash, result: CachedTaskResult(result: result, agentType: agentType, tokensUsed: existingSession.tokensUsed))
                return .returnCached(result)
            }
        }

        // 3. Check resource budget
        let workerCount = sessions.filter { $0.parentSessionID == parent.id && $0.state.isActive }.count
        let maxWorkers = maxConcurrentWorkers(for: parent)
        guard workerCount < maxWorkers else {
            logActivity(sessionID: parent.id, event: "delegation-denied", detail: "Worker limit reached (\(workerCount)/\(maxWorkers))")
            return .deny(reason: "Maximum concurrent workers reached (\(maxWorkers))")
        }

        // 4. Approve — spawn worker
        let workerBudget = defaultBudget(for: agentType, depth: parent.delegationDepth + 1)
        let worker = TheaAgentSession(
            agentType: agentType,
            name: "\(agentType.rawValue.capitalized) Worker #\(sessions.count + 1)",
            taskDescription: task,
            parentConversationID: parent.parentConversationID,
            tokenBudget: workerBudget,
            delegationDepth: parent.delegationDepth + 1,
            parentSessionID: parent.id
        )

        taskRegistry[taskHash] = worker.id
        sessions.append(worker)
        logActivity(sessionID: worker.id, event: "worker-spawned", detail: "Parent: \(parent.id.uuidString.prefix(8)), depth: \(worker.delegationDepth)")

        Task {
            await executeSession(worker)
            publishTaskResult(taskHash: taskHash, session: worker)
        }

        return .approve(worker.id)
    }

    // MARK: - Task Deduplication (B-MLT3)

    /// Subscribe to be notified when a shared task completes
    private func subscribeToTask(taskHash: String, subscriberID: UUID) {
        taskSubscribers[taskHash, default: []].append(subscriberID)
    }

    /// Deliver completed task result to all subscribers via AgentCommunicationBus
    private func publishTaskResult(taskHash: String, session: TheaAgentSession) {
        guard let subscribers = taskSubscribers[taskHash], !subscribers.isEmpty else {
            // Still cache even without subscribers
            let agentOutput = session.messages.filter { $0.role == .agent }.map(\.content).joined(separator: "\n")
            if !agentOutput.isEmpty {
                cacheResult(taskHash: taskHash, result: CachedTaskResult(
                    result: agentOutput, agentType: session.agentType, tokensUsed: session.tokensUsed
                ))
            }
            return
        }

        let result = session.messages.filter { $0.role == .agent }.map(\.content).joined(separator: "\n")
        for subscriberID in subscribers {
            Task {
                await AgentCommunicationBus.shared.broadcastResult(
                    from: session.id, taskId: session.id,
                    output: String(result.prefix(500)), success: session.state == .completed,
                    metadata: ["taskHash": taskHash, "tokensUsed": "\(session.tokensUsed)"]
                )
                // Also send a direct message to each subscriber
                await AgentCommunicationBus.shared.send(BusAgentMessage(
                    id: UUID(), timestamp: Date(), senderAgentId: session.id,
                    recipientAgentId: subscriberID, messageType: .completionSignal,
                    payload: .text(result),
                    priority: .normal, correlationId: session.parentConversationID
                ))
            }
        }
        taskSubscribers.removeValue(forKey: taskHash)

        // Cache the result for future dedup
        cacheResult(taskHash: taskHash, result: CachedTaskResult(
            result: result, agentType: session.agentType, tokensUsed: session.tokensUsed
        ))
    }

    // MARK: - Result Cache (B-MLT4)

    /// Cache a task result with TTL for future dedup
    private func cacheResult(taskHash: String, result: CachedTaskResult) {
        resultCache[taskHash] = result
    }

    /// Look up a cached result, returning nil if expired
    private func getCachedResult(taskHash: String) -> CachedTaskResult? {
        guard let cached = resultCache[taskHash] else { return nil }
        guard Date().timeIntervalSince(cached.completedAt) < cacheTTL else {
            resultCache.removeValue(forKey: taskHash)
            return nil
        }
        return cached
    }

    /// Purge expired cache entries
    public func purgeExpiredCache() {
        let now = Date()
        resultCache = resultCache.filter { now.timeIntervalSince($0.value.completedAt) < cacheTTL }
    }

    // MARK: - Resource Budgets Per Layer (B-MLT5)

    /// Maximum concurrent workers a session can spawn, based on its delegation depth
    public func maxConcurrentWorkers(for session: TheaAgentSession) -> Int {
        switch session.delegationDepth {
        case 0: return 5   // Meta-AI can run 5 sub-agents
        case 1: return 3   // Sub-agent can run 3 workers
        default: return 0  // Workers cannot delegate
        }
    }

    // MARK: - Convenience Queries

    public var activeSessions: [TheaAgentSession] {
        sessions.filter { $0.state.isActive }
    }

    public var completedSessions: [TheaAgentSession] {
        sessions.filter { $0.state == .completed }
    }

    /// Find all children of a given session
    public func childSessions(of parentID: UUID) -> [TheaAgentSession] {
        sessions.filter { $0.parentSessionID == parentID }
    }

    // MARK: - Private Helpers

    private func executeSession(_ session: TheaAgentSession) async {
        guard !session.state.isTerminal else { return }

        // Check budget before executing
        if isBudgetExceeded {
            session.error = "Daily cost budget exceeded (\(String(format: "$%.2f", dailyCostBudget)))"
            session.transition(to: .failed)
            logActivity(sessionID: session.id, event: "budget-exceeded", detail: session.error ?? "")
            return
        }

        do {
            // Get provider and model from ChatManager's routing
            let (provider, model, _) = try await ChatManager.shared.selectProviderAndModel(for: session.taskDescription)

            // Track provider/model for cost estimation
            session.modelId = model
            session.providerId = provider.metadata.name

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

            // Persist session summary to knowledge graph for future agent context
            await persistSessionToKnowledgeGraph(session)

            // Track cumulative cost
            cumulativeCost += session.estimatedCost

            logActivity(
                sessionID: session.id,
                event: "completed",
                detail: "Tokens: \(session.tokensUsed), confidence: \(session.confidence), cost: \(session.formattedCost)"
            )

        } catch {
            session.error = error.localizedDescription
            session.transition(to: .failed)
            logActivity(sessionID: session.id, event: "failed", detail: error.localizedDescription)
        }
    }

    // MARK: - Agent Memory (Knowledge Graph Persistence)

    /// Persist a completed session's summary to PersonalKnowledgeGraph
    /// so future agents can learn from past results.
    private func persistSessionToKnowledgeGraph(_ session: TheaAgentSession) async {
        guard session.state == .completed else { return }

        let agentOutput = session.messages
            .filter { $0.role == .agent }
            .map(\.content)
            .joined(separator: "\n")

        let summaryText = String(agentOutput.prefix(500))
        guard !summaryText.isEmpty else { return }

        let entityName = "Agent: \(session.agentType.rawValue) — \(session.taskDescription.prefix(60))"
        let entity = KGEntity(name: entityName, type: .project, attributes: [
            "agentType": session.agentType.rawValue,
            "taskDescription": session.taskDescription,
            "resultSummary": summaryText,
            "tokensUsed": "\(session.tokensUsed)",
            "confidence": String(format: "%.2f", session.confidence),
            "model": session.modelId ?? "unknown",
            "completedAt": ISO8601DateFormatter().string(from: session.completedAt ?? Date()),
            "cost": session.formattedCost
        ])
        await PersonalKnowledgeGraph.shared.addEntity(entity)
        await PersonalKnowledgeGraph.shared.save()
        logger.info("Persisted agent session \(session.id.uuidString.prefix(8)) to knowledge graph")
    }

    // MARK: - User Feedback

    /// Record user feedback for a completed session.
    /// Also records to UserFeedbackLearner for cross-system learning.
    public func submitFeedback(
        for session: TheaAgentSession,
        rating: AgentFeedbackRating,
        comment: String? = nil
    ) {
        session.userRating = rating
        session.userFeedbackComment = comment

        logActivity(
            sessionID: session.id,
            event: "feedback-\(rating.rawValue)",
            detail: comment ?? "No comment"
        )

        agentTypeFeedback[session.agentType, default: AgentTypeFeedbackStats()]
            .record(positive: rating == .positive)

        // Wire to UserFeedbackLearner for cross-system confidence learning
        Task {
            await UserFeedbackLearner().recordFeedback(
                responseId: session.id,
                wasCorrect: rating == .positive,
                userCorrection: comment,
                taskType: .planning
            )
        }

        logger.info("Agent feedback: \(rating.rawValue) for \(session.agentType.rawValue)")
    }

    /// Get the success rate for a given agent type based on user feedback.
    public func feedbackSuccessRate(for agentType: SpecializedAgentType) -> Double? {
        agentTypeFeedback[agentType]?.successRate
    }

    // MARK: - Cost Queries

    /// Total cost across all completed sessions.
    public var totalSessionCost: Double {
        sessions.reduce(0) { $0 + $1.estimatedCost }
    }

    /// Cost breakdown by provider.
    public var costByProvider: [(provider: String, cost: Double)] {
        var providerCosts: [String: Double] = [:]
        for session in sessions where session.state == .completed {
            let provider = session.providerId ?? "unknown"
            providerCosts[provider, default: 0] += session.estimatedCost
        }
        return providerCosts.map { (provider: $0.key, cost: $0.value) }
            .sorted { $0.cost > $1.cost }
    }

    /// Token budget based on agent type, adjusted for delegation depth.
    /// Deeper agents get smaller budgets to prevent worker sprawl.
    private func defaultBudget(for agentType: SpecializedAgentType, depth: Int = 1) -> Int {
        let baseBudget: Int
        switch agentType {
        case .research, .documentation: baseBudget = 16384
        case .plan, .review: baseBudget = 12288
        case .explore, .debug: baseBudget = 8192
        default: baseBudget = 8192
        }
        // Layer 2 workers get half the base budget
        return depth >= 2 ? baseBudget / 2 : baseBudget
    }

    /// Compute a content hash for task deduplication
    nonisolated private func computeTaskHash(_ task: String) -> String {
        let normalized = task.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        // Simple hash using hashValue — sufficient for in-memory dedup
        return String(normalized.hashValue, radix: 16)
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
