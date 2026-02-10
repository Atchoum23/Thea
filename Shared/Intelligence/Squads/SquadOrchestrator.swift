// SquadOrchestrator.swift
// Thea V2
//
// High-level orchestration for specialized agent squads
// Implements true parallel execution with coordination

import Foundation
import OSLog

// MARK: - Squad Task

/// A task to be executed by a squad
public struct SquadTask: Identifiable, Sendable {
    public let id: UUID
    public let description: String
    public let context: [String: String]
    public let requiredCapabilities: Set<String>
    public let priority: SquadTaskPriority
    public let deadline: Date?
    public let parentTaskId: UUID?

    public init(
        id: UUID = UUID(),
        description: String,
        context: [String: String] = [:],
        requiredCapabilities: Set<String> = [],
        priority: SquadTaskPriority = .normal,
        deadline: Date? = nil,
        parentTaskId: UUID? = nil
    ) {
        self.id = id
        self.description = description
        self.context = context
        self.requiredCapabilities = requiredCapabilities
        self.priority = priority
        self.deadline = deadline
        self.parentTaskId = parentTaskId
    }
}

public enum SquadTaskPriority: Int, Comparable, Sendable {
    case low = 0
    case normal = 50
    case high = 75
    case critical = 100

    public static func < (lhs: SquadTaskPriority, rhs: SquadTaskPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Squad Task Result

/// Result from squad task execution
public struct SquadTaskResult: Identifiable, Sendable {
    public let id: UUID
    public let taskId: UUID
    public let squadId: String
    public let memberId: String
    public let output: String
    public let success: Bool
    public let executionTime: TimeInterval
    public let handoffs: [HandoffResult]
    public let subResults: [SquadTaskResult]
    public let metadata: [String: String]

    public init(
        id: UUID = UUID(),
        taskId: UUID,
        squadId: String,
        memberId: String,
        output: String,
        success: Bool,
        executionTime: TimeInterval,
        handoffs: [HandoffResult] = [],
        subResults: [SquadTaskResult] = [],
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.taskId = taskId
        self.squadId = squadId
        self.memberId = memberId
        self.output = output
        self.success = success
        self.executionTime = executionTime
        self.handoffs = handoffs
        self.subResults = subResults
        self.metadata = metadata
    }
}

// MARK: - Squad Execution Plan

/// Plan for executing tasks across squad members
public struct SquadExecutionPlan: Sendable {
    public let squadId: String
    public let taskId: UUID
    public let phases: [ExecutionPhase]
    public let estimatedDuration: TimeInterval
    public let requiredResources: [PoolResourceType]

    public struct ExecutionPhase: Sendable {
        public let name: String
        public let memberIds: [String]
        public let parallelizable: Bool
        public let estimatedDuration: TimeInterval
        public let dependencies: [String]  // Phase names this depends on
    }
}

// MARK: - Squad Orchestrator

/// Orchestrates specialized agent squads for complex workflows
/// Supports true parallel execution with up to 8 concurrent agents
@MainActor
@Observable
public final class SquadOrchestrator {
    public static let shared = SquadOrchestrator()

    private let logger = Logger(subsystem: "com.thea.squads", category: "SquadOrchestrator")

    // MARK: - Configuration

    /// Maximum concurrent agents across all squads
    public var maxConcurrentAgents: Int = 8

    /// Timeout for individual squad member tasks
    public var memberTaskTimeout: TimeInterval = 120

    /// Enable inter-agent communication
    public var enableCommunication: Bool = true

    /// Use resource pool for rate limiting
    public var useResourcePool: Bool = true

    // MARK: - State

    private(set) var isExecuting = false
    private(set) var activeSquads: [String: SquadExecutionState] = [:]
    private(set) var executionHistory: [SquadTaskResult] = []

    // Dependencies
    private let registry: SquadRegistry
    private let communicationBus: AgentCommunicationBus
    private let resourcePool: AgentResourcePool
    private let providerRegistry: ProviderRegistry

    private init() {
        self.registry = SquadRegistry.shared
        self.communicationBus = AgentCommunicationBus.shared
        self.resourcePool = AgentResourcePool.shared
        self.providerRegistry = ProviderRegistry.shared
    }

    // MARK: - Squad Selection

    /// Find the best squad for a task
    public func selectSquad(for task: SquadTask) -> SquadDefinition? {
        let squads = registry.sortedSquads.filter { $0.isEnabled }

        // Check for required capabilities
        if !task.requiredCapabilities.isEmpty {
            for squad in squads {
                let squadCapabilities = Set(squad.members.flatMap(\.tools))
                if task.requiredCapabilities.isSubset(of: squadCapabilities) {
                    return squad
                }
            }
        }

        // Fall back to keyword matching
        let taskLower = task.description.lowercased()

        if taskLower.contains("code") || taskLower.contains("implement") ||
           taskLower.contains("develop") || taskLower.contains("build") {
            return registry.squad(id: "code-development")
        }

        if taskLower.contains("research") || taskLower.contains("find") ||
           taskLower.contains("analyze") || taskLower.contains("investigate") {
            return registry.squad(id: "research")
        }

        // Default to code development
        return registry.squad(id: "code-development")
    }

    // MARK: - Squad Execution

    /// Execute a task with a squad
    public func execute(
        task: SquadTask,
        squad: SquadDefinition? = nil,
        progressHandler: (@Sendable (SquadExecutionProgress) -> Void)? = nil
    ) async throws -> SquadTaskResult {
        let startTime = Date()
        isExecuting = true

        defer {
            isExecuting = false
        }

        // Select squad
        let selectedSquad = squad ?? selectSquad(for: task)
        guard let selectedSquad else {
            throw SquadOrchestratorError.noSuitableSquad
        }

        logger.info("Executing task with squad: \(selectedSquad.name)")

        // Create execution state
        let executionState = SquadExecutionState()
        executionState.start(squad: selectedSquad)
        activeSquads[selectedSquad.id] = executionState

        defer {
            activeSquads.removeValue(forKey: selectedSquad.id)
        }

        // Report initial progress
        progressHandler?(SquadExecutionProgress(
            phase: .planning,
            squadId: selectedSquad.id,
            activeMember: executionState.activeMember?.name,
            progress: 0.1,
            message: "Planning execution with \(selectedSquad.name)"
        ))

        // Create execution plan
        let plan = createExecutionPlan(squad: selectedSquad, task: task)

        // Set up communication if enabled
        var memberStreams: [String: AsyncStream<BusAgentMessage>] = [:]
        if enableCommunication {
            for member in selectedSquad.members {
                let memberId = UUID()  // Unique ID for this execution
                memberStreams[member.id] = await communicationBus.register(
                    agentId: memberId,
                    filter: .all
                )
            }
        }

        // Execute phases
        var allResults: [SquadTaskResult] = []
        var handoffs: [HandoffResult] = []

        for (phaseIndex, phase) in plan.phases.enumerated() {
            let phaseProgress = 0.1 + (0.8 * Double(phaseIndex) / Double(plan.phases.count))

            progressHandler?(SquadExecutionProgress(
                phase: .executing,
                squadId: selectedSquad.id,
                activeMember: phase.memberIds.first,
                progress: phaseProgress,
                message: "Executing phase: \(phase.name)"
            ))

            // Execute phase members
            let phaseResults: [SquadTaskResult]

            if phase.parallelizable && phase.memberIds.count > 1 {
                // Parallel execution
                phaseResults = try await executeParallelPhase(
                    phase: phase,
                    squad: selectedSquad,
                    task: task,
                    executionState: executionState
                )
            } else {
                // Sequential execution
                phaseResults = try await executeSequentialPhase(
                    phase: phase,
                    squad: selectedSquad,
                    task: task,
                    executionState: executionState
                )
            }

            allResults.append(contentsOf: phaseResults)

            // Check for handoffs
            for _ in phaseResults {
                if let handoff = executionState.handoffHistory.last,
                   !handoffs.contains(where: { $0.toMember.id == handoff.toMember.id }) {
                    handoffs.append(handoff)
                }
            }
        }

        // Clean up communication
        if enableCommunication {
            for _ in selectedSquad.members {
                let memberId = UUID()
                await communicationBus.unregister(agentId: memberId)
            }
        }

        // Aggregate results
        progressHandler?(SquadExecutionProgress(
            phase: .aggregating,
            squadId: selectedSquad.id,
            activeMember: nil,
            progress: 0.95,
            message: "Aggregating results"
        ))

        let aggregatedOutput = aggregateResults(allResults)
        let success = allResults.allSatisfy(\.success)

        let finalResult = SquadTaskResult(
            taskId: task.id,
            squadId: selectedSquad.id,
            memberId: "aggregated",
            output: aggregatedOutput,
            success: success,
            executionTime: Date().timeIntervalSince(startTime),
            handoffs: handoffs,
            subResults: allResults
        )

        executionHistory.append(finalResult)

        progressHandler?(SquadExecutionProgress(
            phase: .complete,
            squadId: selectedSquad.id,
            activeMember: nil,
            progress: 1.0,
            message: "Squad execution complete"
        ))

        logger.info("Squad execution complete: \(success ? "success" : "failure") in \(String(format: "%.2f", finalResult.executionTime))s")

        return finalResult
    }

    // MARK: - Parallel Phase Execution

    /// Execute a phase with parallel members
    private func executeParallelPhase(
        phase: SquadExecutionPlan.ExecutionPhase,
        squad: SquadDefinition,
        task: SquadTask,
        executionState: SquadExecutionState
    ) async throws -> [SquadTaskResult] {
        logger.info("Executing parallel phase: \(phase.name) with \(phase.memberIds.count) members")

        // Limit concurrency
        let memberIds = Array(phase.memberIds.prefix(maxConcurrentAgents))

        // Create operations for each member
        let operations: [@Sendable () async throws -> SquadTaskResult] = memberIds.compactMap { memberId in
            guard let member = squad.member(id: memberId) else { return nil }

            return { [self] in
                try await self.executeMemberTask(
                    member: member,
                    squad: squad,
                    task: task
                )
            }
        }

        // Execute in parallel with task group
        var results: [SquadTaskResult] = []
        results = try await withThrowingTaskGroup(of: SquadTaskResult.self) { group in
            for operation in operations {
                group.addTask { try await operation() }
            }
            var collected: [SquadTaskResult] = []
            while let result = try? await group.next() {
                collected.append(result)
            }
            return collected
        }

        return results
    }

    // MARK: - Sequential Phase Execution

    /// Execute a phase with sequential members
    private func executeSequentialPhase(
        phase: SquadExecutionPlan.ExecutionPhase,
        squad: SquadDefinition,
        task: SquadTask,
        executionState: SquadExecutionState
    ) async throws -> [SquadTaskResult] {
        logger.info("Executing sequential phase: \(phase.name)")

        var results: [SquadTaskResult] = []

        for memberId in phase.memberIds {
            guard let member = squad.member(id: memberId) else { continue }

            let result = try await executeMemberTask(
                member: member,
                squad: squad,
                task: task
            )
            results.append(result)

            // Check for handoff based on result
            if let nextMember = executionState.checkHandoffRules(
                message: result.output,
                taskType: determineTaskType(from: result.output)
            ) {
                _ = executionState.handoff(to: nextMember.id)
            }
        }

        return results
    }

    // MARK: - Member Task Execution

    /// Execute a task with a specific squad member
    private func executeMemberTask(
        member: SquadMember,
        squad: SquadDefinition,
        task: SquadTask
    ) async throws -> SquadTaskResult {
        let startTime = Date()

        // Acquire resources if pool is enabled
        var allocation: PoolResourceAllocation?
        if useResourcePool {
            allocation = try await resourcePool.acquire(
                resourceType: .apiSlot,
                agentId: UUID(),
                timeout: 30
            )
        }

        defer {
            if let allocation {
                Task {
                    await resourcePool.release(allocation)
                }
            }
        }

        // Get provider
        guard let provider = providerRegistry.getDefaultProvider() else {
            throw SquadOrchestratorError.noProviderAvailable
        }

        // Build prompt
        let prompt = buildMemberPrompt(
            member: member,
            task: task,
            context: task.context
        )

        // Execute with the provider
        let model = member.model ?? "claude-sonnet-4-5-20250929"
        let message = AIMessage(
            id: UUID(),
            conversationID: UUID(),
            role: .user,
            content: .text(prompt),
            timestamp: Date(),
            model: model
        )
        let stream = try await provider.chat(messages: [message], model: model, stream: false)
        var response = ""
        for try await chunk in stream {
            switch chunk.type {
            case .delta(let text): response += text
            case .complete(let msg): response = msg.content.textValue
            case .error(let error): throw error
            }
        }

        // Broadcast result if communication enabled
        if enableCommunication {
            await communicationBus.broadcastResult(
                from: UUID(),
                taskId: task.id,
                output: String(response.prefix(500)),
                success: true
            )
        }

        return SquadTaskResult(
            taskId: task.id,
            squadId: squad.id,
            memberId: member.id,
            output: response,
            success: true,
            executionTime: Date().timeIntervalSince(startTime),
            metadata: ["model": model, "provider": provider.metadata.name]
        )
    }

    // MARK: - Execution Planning

    /// Create an execution plan for a squad and task
    private func createExecutionPlan(squad: SquadDefinition, task: SquadTask) -> SquadExecutionPlan {
        var phases: [SquadExecutionPlan.ExecutionPhase] = []

        // Phase 1: Initial analysis (entry point)
        if let firstMember = squad.firstMember {
            phases.append(SquadExecutionPlan.ExecutionPhase(
                name: "analysis",
                memberIds: [firstMember.id],
                parallelizable: false,
                estimatedDuration: 30,
                dependencies: []
            ))
        }

        // Phase 2: Parallel work (all workers that can run in parallel)
        let workerIds = squad.members
            .filter { $0.id != squad.firstMemberId }
            .filter { !$0.role.lowercased().contains("review") }
            .map(\.id)

        if !workerIds.isEmpty {
            phases.append(SquadExecutionPlan.ExecutionPhase(
                name: "parallel-work",
                memberIds: workerIds,
                parallelizable: true,
                estimatedDuration: 60,
                dependencies: ["analysis"]
            ))
        }

        // Phase 3: Review (sequential)
        let reviewerIds = squad.members
            .filter { $0.role.lowercased().contains("review") }
            .map(\.id)

        if !reviewerIds.isEmpty {
            phases.append(SquadExecutionPlan.ExecutionPhase(
                name: "review",
                memberIds: reviewerIds,
                parallelizable: false,
                estimatedDuration: 30,
                dependencies: ["parallel-work"]
            ))
        }

        let totalDuration = phases.reduce(0) { $0 + $1.estimatedDuration }

        return SquadExecutionPlan(
            squadId: squad.id,
            taskId: task.id,
            phases: phases,
            estimatedDuration: totalDuration,
            requiredResources: [PoolResourceType.apiSlot, PoolResourceType.computeSlot]
        )
    }

    // MARK: - Helper Methods

    /// Build prompt for a squad member
    private func buildMemberPrompt(
        member: SquadMember,
        task: SquadTask,
        context: [String: String]
    ) -> String {
        var prompt = member.systemPrompt + "\n\n"
        prompt += "## Task\n\(task.description)\n\n"

        if !context.isEmpty {
            prompt += "## Context\n"
            for (key, value) in context {
                prompt += "- \(key): \(value)\n"
            }
            prompt += "\n"
        }

        if !member.tools.isEmpty {
            prompt += "## Available Tools\n"
            prompt += member.tools.joined(separator: ", ")
            prompt += "\n\n"
        }

        prompt += "Please execute this task according to your role as \(member.role)."

        return prompt
    }

    /// Aggregate results from multiple squad members
    private func aggregateResults(_ results: [SquadTaskResult]) -> String {
        guard !results.isEmpty else { return "No results" }

        if results.count == 1 {
            return results[0].output
        }

        var aggregated = "## Squad Results\n\n"

        for result in results {
            aggregated += "### \(result.memberId)\n"
            aggregated += result.output.prefix(1000)
            if result.output.count > 1000 {
                aggregated += "\n...[truncated]"
            }
            aggregated += "\n\n"
        }

        return aggregated
    }

    /// Determine task type from output
    private func determineTaskType(from output: String) -> String? {
        let lower = output.lowercased()

        if lower.contains("implement") || lower.contains("code") {
            return "code"
        }
        if lower.contains("api") || lower.contains("endpoint") {
            return "api"
        }
        if lower.contains("ui") || lower.contains("component") || lower.contains("view") {
            return "ui"
        }
        if lower.contains("test") {
            return "test"
        }

        return nil
    }

    // MARK: - Query Methods

    /// Get execution history
    public func getHistory(limit: Int = 50) -> [SquadTaskResult] {
        Array(executionHistory.suffix(limit))
    }

    /// Get active squad count
    public var activeSquadCount: Int {
        activeSquads.count
    }

    /// Clear execution history
    public func clearHistory() {
        executionHistory.removeAll()
    }
}

// MARK: - Execution Progress

/// Progress update for squad execution
public struct SquadExecutionProgress: Sendable {
    public let phase: Phase
    public let squadId: String
    public let activeMember: String?
    public let progress: Double
    public let message: String

    public enum Phase: String, Sendable {
        case planning
        case executing
        case handingOff
        case aggregating
        case complete
    }
}

// MARK: - Errors

public enum SquadOrchestratorError: LocalizedError {
    case noSuitableSquad
    case noProviderAvailable
    case executionTimeout
    case memberNotFound(String)
    case handoffFailed(from: String, to: String)

    public var errorDescription: String? {
        switch self {
        case .noSuitableSquad:
            "No suitable squad found for the task"
        case .noProviderAvailable:
            "No AI provider available"
        case .executionTimeout:
            "Squad execution timed out"
        case let .memberNotFound(id):
            "Squad member not found: \(id)"
        case let .handoffFailed(from, to):
            "Handoff failed from \(from) to \(to)"
        }
    }
}
