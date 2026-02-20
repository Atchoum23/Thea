// AgentTeamOrchestrator.swift
// Thea — Claude Agent Teams Integration
//
// P16: Thea as Team Lead. Decomposes complex tasks via TaskPlanDAG,
// then dispatches independent sub-tasks to parallel Claude API calls (teammates).
// Each teammate has a clean, isolated context window. Results are synthesized
// back to the Team Lead for final response.
//
// Wire: AgentMode 'auto' mode calls AgentTeamOrchestrator.orchestrate() for complex tasks.

import Foundation
import OSLog

// MARK: - Agent Team Orchestrator

/// Orchestrates a team of AI agents for parallel task decomposition and execution.
/// Thea acts as Team Lead — decomposes the task, dispatches teammates, synthesizes results.
@MainActor
final class AgentTeamOrchestrator: ObservableObject {
    static let shared = AgentTeamOrchestrator()

    private let logger = Logger(subsystem: "ai.thea.app", category: "AgentTeamOrchestrator")

    @Published private(set) var activeTeams: [AgentTeam] = []
    @Published private(set) var isOrchestrating = false

    private init() {}

    // MARK: - Team Orchestration

    /// Orchestrate a complex task as a team. Returns the synthesized result.
    /// - Parameters:
    ///   - goal: The user's high-level goal (Team Lead receives this)
    ///   - conversationID: Source conversation for context injection
    ///   - maxParallel: Max simultaneous teammate calls (default: 3)
    func orchestrate(
        goal: String,
        conversationID: UUID,
        maxParallel: Int = 3
    ) async throws -> AgentTeamResult {
        isOrchestrating = true
        defer { isOrchestrating = false }

        logger.info("Team orchestration starting for: \(goal.prefix(80))")

        // 1. Decompose via TaskPlanDAG
        let plan = try await TaskPlanDAG.shared.createPlan(goal: goal)

        // G3-3: User Approval Gate — check plan risk before executing
        let planRisk = estimatePlanRisk(plan: plan, goal: goal)
        if planRisk >= AutonomyController.shared.autonomyLevel.maxAutoRisk {
            let approval = await AutonomyController.shared.requestAction(
                AutonomousAction(
                    id: UUID(),
                    type: .other,
                    description: "Execute multi-step plan: \(goal.prefix(100))",
                    riskLevel: planRisk,
                    isReversible: false,
                    requiresExternalAccess: false,
                    metadata: ["subtasks": "\(plan.nodes.count)", "goal": goal]
                )
            )
            if approval == .rejected {
                throw AgentTeamError.planRejectedByUser
            }
        }
        let subTasks = plan.nodes.filter { $0.dependsOn.isEmpty || $0.status == .pending }
            .prefix(maxParallel)
            .map { AgentSubTask(id: $0.id, description: $0.action, node: $0) }

        let team = AgentTeam(
            id: UUID(),
            goal: goal,
            conversationID: conversationID,
            subTasks: Array(subTasks),
            status: .running,
            startedAt: Date()
        )
        activeTeams.append(team)
        let teamIndex = activeTeams.count - 1

        logger.info("Team \(team.id): dispatching \(subTasks.count) teammates")

        // 2. Execute sub-tasks in parallel (each with isolated context)
        let subTaskResults: [AgentSubTaskResult] = await withTaskGroup(
            of: AgentSubTaskResult.self
        ) { group in
            for subTask in subTasks {
                group.addTask { [weak self] in
                    guard let self else {
                        return AgentSubTaskResult(
                            subTaskID: subTask.id,
                            success: false,
                            result: "",
                            error: "Orchestrator deallocated"
                        )
                    }
                    return await self.executeSubTask(subTask, teamID: team.id)
                }
            }

            var results: [AgentSubTaskResult] = []
            for await result in group {
                results.append(result)
                await MainActor.run {
                    self.logger.debug("Teammate completed: \(result.subTaskID) success=\(result.success)")
                }
            }
            return results
        }

        // 3. Cache: deduplicate results with identical descriptions
        let uniqueResults = deduplicateResults(subTaskResults)

        // 4. Synthesize results via Team Lead
        let synthesized = try await synthesize(
            goal: goal,
            subTaskResults: uniqueResults,
            teamID: team.id
        )

        // Update team status
        if teamIndex < activeTeams.count {
            activeTeams[teamIndex].status = .completed
            activeTeams[teamIndex].completedAt = Date()
            activeTeams[teamIndex].synthesizedResult = synthesized
        }

        logger.info("Team \(team.id) complete. \(uniqueResults.count) subtasks synthesized.")

        return AgentTeamResult(
            team: team,
            subTaskResults: uniqueResults,
            synthesizedResponse: synthesized,
            totalSubTasks: subTasks.count,
            successCount: uniqueResults.filter(\.success).count
        )
    }

    // MARK: - Sub-Task Execution

    // periphery:ignore - Reserved: teamID parameter — kept for API compatibility
    /// Execute a single sub-task with an isolated context window.
    private func executeSubTask(_ subTask: AgentSubTask, teamID: UUID) async -> AgentSubTaskResult {
        logger.debug("Teammate executing: \(subTask.description.prefix(60))")

        do {
            // Build isolated system prompt (each teammate is unaware of other teammates)
            let systemPrompt = """
            You are a specialized AI sub-agent in a team led by Thea.
            Your sole task is: \(subTask.description)
            Respond with the result only — concise, focused, no preamble.
            The Team Lead will synthesize all sub-agent results.
            """

            let provider = try getProvider()
            let model = getTeammateModel()

// periphery:ignore - Reserved: teamID parameter kept for API compatibility

            let messages: [AIMessage] = [
                AIMessage(
                    id: UUID(),
                    conversationID: subTask.id,
                    role: .system,
                    content: .text(systemPrompt),
                    timestamp: Date.distantPast,
                    model: model
                ),
                AIMessage(
                    id: UUID(),
                    conversationID: subTask.id,
                    role: .user,
                    content: .text(subTask.description),
                    timestamp: Date(),
                    model: model
                )
            ]

            var responseText = ""
            let stream = try await provider.chat(messages: messages, model: model, stream: true)
            for try await chunk in stream {
                switch chunk.type {
                case let .delta(text): responseText += text
                case let .complete(msg): responseText = msg.content.textValue
                case .error: break
                }
            }

            return AgentSubTaskResult(
                subTaskID: subTask.id,
                success: !responseText.isEmpty,
                result: responseText,
                error: responseText.isEmpty ? "Empty response from teammate" : nil
            )
        } catch {
            logger.error("Teammate failed for \(subTask.description.prefix(40)): \(error.localizedDescription)")
            return AgentSubTaskResult(
                subTaskID: subTask.id,
                success: false,
                result: "",
                error: error.localizedDescription
            )
        }
    }

    // MARK: - Synthesis (Team Lead)

    /// Synthesize multiple sub-task results into a coherent final response.
    private func synthesize(
        goal: String,
        subTaskResults: [AgentSubTaskResult],
        teamID: UUID
    ) async throws -> String {
        let successfulResults = subTaskResults.filter(\.success)
        guard !successfulResults.isEmpty else {
            return "The agent team could not complete the task. All sub-tasks failed."
        }

        let subTaskSummaries = successfulResults
            .enumerated()
            .map { idx, result in "Sub-task \(idx + 1): \(result.result)" }
            .joined(separator: "\n\n")

        let synthesisPrompt = """
        You are the Team Lead AI. Your team of specialized sub-agents has completed their tasks.

        Original goal: \(goal)

        Sub-agent results:
        \(subTaskSummaries)

        Synthesize these results into a single, coherent, complete response to the original goal.
        Remove redundancy. Resolve any conflicts. Present the unified result clearly.
        """

        let provider = try getProvider()
        let model = getTeamLeadModel()

        let messages: [AIMessage] = [
            AIMessage(
                id: UUID(),
                conversationID: teamID,
                role: .user,
                content: .text(synthesisPrompt),
                timestamp: Date(),
                model: model
            )
        ]

        var synthesized = ""
        let stream = try await provider.chat(messages: messages, model: model, stream: true)
        for try await chunk in stream {
            switch chunk.type {
            case let .delta(text): synthesized += text
            case let .complete(msg): synthesized = msg.content.textValue
            case .error: break
            }
        }

        return synthesized.isEmpty
            ? subTaskSummaries // Fallback: return raw results if synthesis fails
            : synthesized
    }

    // MARK: - Result Deduplication (Cache)

    /// Deduplicate results with identical sub-task IDs (prevents redundant re-runs).
    private func deduplicateResults(_ results: [AgentSubTaskResult]) -> [AgentSubTaskResult] {
        var seen: Set<UUID> = []
        return results.filter { seen.insert($0.subTaskID).inserted }
    }

    // MARK: - Provider Access

    private func getProvider() throws -> any AIProvider {
        guard let provider = ProviderRegistry.shared.getDefaultProvider() else {
            throw AgentTeamError.noProviderAvailable
        }
        return provider
    }

    /// Team Lead uses Opus 4.6 (best agent reasoning, highest injection resistance).
    private func getTeamLeadModel() -> String { "claude-opus-4-6" }

    /// Teammates use Sonnet 4.6 (near-flagship at lower cost for parallel calls).
    private func getTeammateModel() -> String { "claude-sonnet-4-6" }

    // MARK: - G3: Plan Risk Estimation

    /// Estimate the risk level of a plan based on its nodes and goal.
    /// Used to determine if the approval gate should be triggered.
    private func estimatePlanRisk(plan: TaskPlan, goal: String) -> THEARiskLevel {
        let lower = goal.lowercased()
        let nodeCount = plan.nodes.count
        let hasIntegrationNodes = plan.nodes.contains { $0.actionType == .integration }

        // High-risk: many nodes + integration actions + sensitive keywords
        if nodeCount > 5 && hasIntegrationNodes {
            return .high
        }
        // Medium-risk: integration actions or many steps
        if hasIntegrationNodes || nodeCount > 3 {
            return .medium
        }
        // Low-risk keywords (send, delete, post, publish)
        let sensitiveKeywords = ["send", "delete", "publish", "post", "submit", "deploy", "remove"]
        if sensitiveKeywords.contains(where: { lower.contains($0) }) {
            return .medium
        }
        return .low
    }

    // MARK: - Team Management

    // periphery:ignore - Reserved: removeCompletedTeams() instance method — reserved for future feature activation
    func removeCompletedTeams() {
        activeTeams.removeAll { $0.status == .completed }
    }

    // periphery:ignore - Reserved: hasActiveTeams property — reserved for future feature activation
    var hasActiveTeams: Bool { activeTeams.contains { $0.status == .running } }
}

// MARK: - Types

struct AgentTeam: Identifiable, Sendable {
    let id: UUID
    // periphery:ignore - Reserved: goal property — reserved for future feature activation
    let goal: String
    // periphery:ignore - Reserved: conversationID property — reserved for future feature activation
    let conversationID: UUID
    // periphery:ignore - Reserved: removeCompletedTeams() instance method reserved for future feature activation
    let subTasks: [AgentSubTask]
    var status: AgentTeamStatus
    // periphery:ignore - Reserved: startedAt property — reserved for future feature activation
    let startedAt: Date
    // periphery:ignore - Reserved: hasActiveTeams property reserved for future feature activation
    var completedAt: Date?
    // periphery:ignore - Reserved: synthesizedResult property — reserved for future feature activation
    var synthesizedResult: String?
}

enum AgentTeamStatus: String, Sendable {
    case running, completed, failed
// periphery:ignore - Reserved: goal property reserved for future feature activation
// periphery:ignore - Reserved: conversationID property reserved for future feature activation
// periphery:ignore - Reserved: subTasks property reserved for future feature activation
}

// periphery:ignore - Reserved: startedAt property reserved for future feature activation

// periphery:ignore - Reserved: completedAt property reserved for future feature activation

// periphery:ignore - Reserved: synthesizedResult property reserved for future feature activation

struct AgentSubTask: Identifiable, Sendable {
    let id: UUID
    let description: String
    let node: TaskPlanNode  // Reference to TaskPlanDAG node
}

struct AgentSubTaskResult: Sendable {
    let subTaskID: UUID
    // periphery:ignore - Reserved: node property reserved for future feature activation
    let success: Bool
    let result: String
    // periphery:ignore - Reserved: error property — reserved for future feature activation
    let error: String?
}

struct AgentTeamResult: Sendable {
    // periphery:ignore - Reserved: error property reserved for future feature activation
    let team: AgentTeam
    // periphery:ignore - Reserved: subTaskResults property — reserved for future feature activation
    let subTaskResults: [AgentSubTaskResult]
    let synthesizedResponse: String
    // periphery:ignore - Reserved: team property reserved for future feature activation
    // periphery:ignore - Reserved: subTaskResults property reserved for future feature activation
    let totalSubTasks: Int
    let successCount: Int

    // periphery:ignore - Reserved: allSucceeded property — reserved for future feature activation
    var allSucceeded: Bool { successCount == totalSubTasks }
    // periphery:ignore - Reserved: allSucceeded property reserved for future feature activation
    // periphery:ignore - Reserved: partialSuccess property reserved for future feature activation
    var partialSuccess: Bool { successCount > 0 && successCount < totalSubTasks }
}

enum AgentTeamError: LocalizedError {
    case noProviderAvailable
    case planCreationFailed
    case synthesisTimeout
    case planRejectedByUser  // G3-3: user declined the approval gate

    var errorDescription: String? {
        switch self {
        case .noProviderAvailable: "No AI provider configured for agent team"
        case .planCreationFailed: "Failed to decompose task into sub-tasks"
        case .synthesisTimeout: "Team synthesis timed out"
        case .planRejectedByUser: "Plan execution was declined in the approval gate"
        }
    }
}
