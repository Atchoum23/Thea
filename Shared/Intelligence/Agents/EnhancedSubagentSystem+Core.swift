// EnhancedSubagentSystem+Core.swift
// Thea V2
//
// Enhanced subagent system actor with context isolation, parallel spawning,
// specialized agents, and result aggregation

import Foundation
import OSLog

// MARK: - Enhanced Subagent System

/// Enhanced system for managing specialized subagents
public actor EnhancedSubagentSystem {
    public static let shared = EnhancedSubagentSystem()

    private let logger = Logger(subsystem: "com.thea.agents", category: "EnhancedSubagent")

    // MARK: - State

    private var activeContexts: [UUID: SubagentContext] = [:]
    private var runningTasks: [UUID: SubagentTask] = [:]
    private var completedResults: [UUID: EnhancedSubagentResult] = [:]
    private var maxConcurrentAgents: Int = 8

    // Statistics
    private var totalTasksExecuted: Int = 0
    private var totalTokensUsed: Int = 0
    private var successfulTasks: Int = 0

    // MARK: - Context Management

    /// Create an isolated context for a subagent
    public func createContext(
        parentContextId: UUID? = nil,
        agentType: SpecializedAgentType,
        isolationLevel: ContextIsolationLevel = .partial,
        tokenBudget: Int = 4096
    ) -> SubagentContext {
        var inheritedContext: [String: String] = [:]

        // Inherit context based on isolation level
        if let parentId = parentContextId, let parent = activeContexts[parentId] {
            switch isolationLevel {
            case .full:
                inheritedContext = [:]
            case .partial:
                inheritedContext = ["parent_summary": "Context from parent task"]
            case .shared:
                inheritedContext = parent.inheritedContext
            case .sandbox:
                inheritedContext = parent.inheritedContext  // Read-only access handled elsewhere
            }
        }

        let context = SubagentContext(
            parentContextId: parentContextId,
            agentType: agentType,
            isolationLevel: isolationLevel,
            inheritedContext: inheritedContext,
            tokenBudget: tokenBudget
        )

        activeContexts[context.id] = context
        logger.debug("Created context \(context.id) for \(agentType.rawValue)")

        return context
    }

    /// Release a context when done
    public func releaseContext(_ contextId: UUID) {
        activeContexts.removeValue(forKey: contextId)
        logger.debug("Released context \(contextId)")
    }

    // MARK: - Task Execution

    /// Spawn a single subagent to execute a task
    public func spawn(task: SubagentTask) async -> EnhancedSubagentResult {
        // Create context
        let context = createContext(
            agentType: task.agentType,
            tokenBudget: task.maxTokens
        )

        runningTasks[task.id] = task

        let startTime = Date()
        var result: EnhancedSubagentResult

        do {
            // Execute task with timeout
            result = try await withTimeout(seconds: task.timeout) {
                await self.executeTask(task, context: context)
            }
        } catch {
            result = EnhancedSubagentResult(
                taskId: task.id,
                agentType: task.agentType,
                status: .timeout,
                output: "",
                error: "Task timed out after \(task.timeout) seconds"
            )
        }

        let executionTime = Date().timeIntervalSince(startTime)

        // Update result with execution time
        result = EnhancedSubagentResult(
            id: result.id,
            taskId: result.taskId,
            agentType: result.agentType,
            status: result.status,
            output: result.output,
            structuredOutput: result.structuredOutput,
            confidence: result.confidence,
            tokensUsed: result.tokensUsed,
            executionTime: executionTime,
            error: result.error,
            metadata: result.metadata
        )

        // Store result and update stats
        completedResults[task.id] = result
        runningTasks.removeValue(forKey: task.id)
        releaseContext(context.id)

        totalTasksExecuted += 1
        totalTokensUsed += result.tokensUsed
        if result.status == .success {
            successfulTasks += 1
        }

        logger.info("Completed task \(task.id) with status \(result.status.rawValue)")

        return result
    }

    /// Spawn multiple subagents in parallel
    public func spawnParallel(tasks: [SubagentTask]) async -> [EnhancedSubagentResult] {
        // Limit concurrent agents
        let batches = tasks.chunked(into: maxConcurrentAgents)
        var allResults: [EnhancedSubagentResult] = []

        for batch in batches {
            let results = await withTaskGroup(of: EnhancedSubagentResult.self) { group in
                for task in batch {
                    group.addTask {
                        await self.spawn(task: task)
                    }
                }

                var batchResults: [EnhancedSubagentResult] = []
                for await result in group {
                    batchResults.append(result)
                }
                return batchResults
            }
            allResults.append(contentsOf: results)
        }

        return allResults
    }

    /// Spawn subagents with dependencies (DAG execution)
    public func spawnWithDependencies(tasks: [SubagentTask]) async -> [EnhancedSubagentResult] {
        var completed: [UUID: EnhancedSubagentResult] = [:]
        var pending = tasks
        var results: [EnhancedSubagentResult] = []

        while !pending.isEmpty {
            // Find tasks with satisfied dependencies
            let ready = pending.filter { task in
                task.dependsOn.allSatisfy { completed[$0] != nil }
            }

            guard !ready.isEmpty else {
                logger.error("Deadlock detected: no tasks can proceed")
                break
            }

            // Execute ready tasks in parallel
            let batchResults = await spawnParallel(tasks: ready)

            for result in batchResults {
                completed[result.taskId] = result
                results.append(result)
            }

            // Remove completed from pending
            pending.removeAll { task in ready.contains { $0.id == task.id } }
        }

        return results
    }

    // MARK: - Result Aggregation

    /// Aggregate results from multiple subagents
    public func aggregate(
        results: [EnhancedSubagentResult],
        strategy: SubagentAggregatedResult.AggregationStrategy
    ) -> SubagentAggregatedResult {
        guard !results.isEmpty else {
            return SubagentAggregatedResult(
                taskId: UUID(),
                results: [],
                mergedOutput: "",
                consensusConfidence: 0,
                totalTokensUsed: 0,
                totalExecutionTime: 0,
                aggregationStrategy: strategy
            )
        }

        let totalTokens = results.map { $0.tokensUsed }.reduce(0, +)
        let totalTime = results.map { $0.executionTime }.max() ?? 0  // Parallel = max time

        let mergedOutput: String
        let confidence: Float

        switch strategy {
        case .merge:
            mergedOutput = results.map { $0.output }.joined(separator: "\n\n---\n\n")
            confidence = results.map { $0.confidence }.reduce(0, +) / Float(results.count)

        case .consensus:
            // Find most common output patterns
            let outputs = results.map { $0.output }
            mergedOutput = findConsensus(outputs)
            confidence = Float(outputs.filter { $0 == mergedOutput }.count) / Float(outputs.count)

        case .bestConfidence:
            let best = results.max { $0.confidence < $1.confidence }!
            mergedOutput = best.output
            confidence = best.confidence

        case .sequential:
            mergedOutput = results.sorted { $0.executionTime < $1.executionTime }
                .map { $0.output }
                .joined(separator: "\n")
            confidence = results.map { $0.confidence }.min() ?? 0

        case .custom:
            // Default to merge for custom
            mergedOutput = results.map { $0.output }.joined(separator: "\n\n")
            confidence = results.map { $0.confidence }.reduce(0, +) / Float(results.count)
        }

        return SubagentAggregatedResult(
            taskId: results.first!.taskId,
            results: results,
            mergedOutput: mergedOutput,
            consensusConfidence: confidence,
            totalTokensUsed: totalTokens,
            totalExecutionTime: totalTime,
            aggregationStrategy: strategy
        )
    }

    // MARK: - Specialized Agent Selection

    /// Select the best agent type for a task
    public func selectAgentType(for task: String) -> SpecializedAgentType {
        let lowercased = task.lowercased()

        if lowercased.contains("database") || lowercased.contains("sql") || lowercased.contains("schema") {
            return .database
        }
        if lowercased.contains("security") || lowercased.contains("vulnerability") || lowercased.contains("auth") {
            return .security
        }
        if lowercased.contains("performance") || lowercased.contains("optimize") || lowercased.contains("profile") {
            return .performance
        }
        if lowercased.contains("api") || lowercased.contains("endpoint") || lowercased.contains("rest") {
            return .api
        }
        if lowercased.contains("test") || lowercased.contains("coverage") || lowercased.contains("spec") {
            return .testing
        }
        if lowercased.contains("document") || lowercased.contains("readme") || lowercased.contains("guide") {
            return .documentation
        }
        if lowercased.contains("refactor") || lowercased.contains("restructure") {
            return .refactoring
        }
        if lowercased.contains("review") || lowercased.contains("feedback") || lowercased.contains("critique") {
            return .review
        }
        if lowercased.contains("debug") || lowercased.contains("error") || lowercased.contains("fix") {
            return .debug
        }
        if lowercased.contains("deploy") || lowercased.contains("ci/cd") || lowercased.contains("pipeline") {
            return .deployment
        }
        if lowercased.contains("search") || lowercased.contains("find") || lowercased.contains("explore") {
            return .explore
        }
        if lowercased.contains("plan") || lowercased.contains("architect") || lowercased.contains("design") {
            return .plan
        }
        if lowercased.contains("research") || lowercased.contains("investigate") {
            return .research
        }
        if lowercased.contains("command") || lowercased.contains("terminal") || lowercased.contains("shell") {
            return .bash
        }

        return .generalPurpose
    }

    // MARK: - Statistics

    public func statistics() -> SubagentStatistics {
        SubagentStatistics(
            totalTasksExecuted: totalTasksExecuted,
            successfulTasks: successfulTasks,
            totalTokensUsed: totalTokensUsed,
            activeContexts: activeContexts.count,
            runningTasks: runningTasks.count
        )
    }

    // MARK: - Private Helpers

    // periphery:ignore - Reserved: context parameter kept for API compatibility
    private func executeTask(_ task: SubagentTask, context: SubagentContext) async -> EnhancedSubagentResult {
        // Get a real AI provider for execution (must access @MainActor singletons)
        let provider = await MainActor.run {
            ProviderRegistry.shared.getProvider(id: SettingsManager.shared.defaultProvider)
                ?? ProviderRegistry.shared.getProvider(id: "anthropic")
                ?? ProviderRegistry.shared.getProvider(id: "openrouter")
        }

        guard let provider else {
            return EnhancedSubagentResult(
                taskId: task.id,
                agentType: task.agentType,
                status: .failed,
                output: "No AI provider available for task execution",
                confidence: 0.0,
                tokensUsed: 0
            )
        }

        // Build messages with system prompt from agent type
        let systemMessage = AIMessage(
            id: UUID(),
            conversationID: UUID(),
            role: .system,
            content: .text(task.agentType.systemPrompt),
            timestamp: Date(),
            model: ""
        )

        let userMessage = AIMessage(
            id: UUID(),
            conversationID: UUID(),
            role: .user,
            content: .text(task.input),
            timestamp: Date(),
            model: ""
        )

        // Select a model appropriate for the task
        let preferred = task.agentType.preferredModel
        let modelId: String
        if preferred.contains("opus") || preferred.contains("sonnet") {
            modelId = "anthropic/claude-sonnet-4-5-20250929"
        } else if preferred.contains("haiku") {
            modelId = "openai/gpt-4o-mini"
        } else {
            modelId = "openai/gpt-4o-mini"
        }

        do {
            var responseText = ""
            var tokensUsed = 0

            let stream = try await provider.chat(
                messages: [systemMessage, userMessage],
                model: modelId,
                stream: false
            )

            for try await chunk in stream {
                if case .delta(let text) = chunk.type {
                    responseText += text
                } else if case .complete(let msg) = chunk.type {
                    responseText = msg.content.textValue
                    tokensUsed = (msg.tokenCount ?? 0)
                }
            }

            if tokensUsed == 0 {
                tokensUsed = (task.input.count + responseText.count) / 4
            }

            // Estimate confidence based on response quality
            let confidence = estimateResponseConfidence(responseText)

            return EnhancedSubagentResult(
                taskId: task.id,
                agentType: task.agentType,
                status: .success,
                output: responseText,
                confidence: confidence,
                tokensUsed: tokensUsed
            )
        } catch {
            return EnhancedSubagentResult(
                taskId: task.id,
                agentType: task.agentType,
                status: .failed,
                output: "Task execution failed: \(error.localizedDescription)",
                confidence: 0.0,
                tokensUsed: 0
            )
        }
    }

    private func estimateResponseConfidence(_ response: String) -> Float {
        var confidence: Float = 0.5
        if response.count > 100 { confidence += 0.1 }
        if response.count > 500 { confidence += 0.1 }
        if response.contains("```") { confidence += 0.1 }
        if response.contains("##") || response.contains("**") { confidence += 0.05 }
        return min(confidence, 0.95)
    }

    private func findConsensus(_ outputs: [String]) -> String {
        // Find most common output
        let counts = Dictionary(grouping: outputs) { $0 }.mapValues { $0.count }
        return counts.max { $0.value < $1.value }?.key ?? outputs.first ?? ""
    }

    private func withTimeout<T: Sendable>(seconds: TimeInterval, operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw CancellationError()
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}

// MARK: - Supporting Types

public struct SubagentStatistics: Sendable {
    public let totalTasksExecuted: Int
    public let successfulTasks: Int
    public let totalTokensUsed: Int
    public let activeContexts: Int
    public let runningTasks: Int

    public var successRate: Float {
        guard totalTasksExecuted > 0 else { return 0 }
        return Float(successfulTasks) / Float(totalTasksExecuted)
    }
}

// MARK: - Array Extension

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
