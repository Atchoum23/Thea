// EnhancedSubagentSystem.swift
// Thea V2
//
// Enhanced subagent system with context isolation, parallel spawning,
// specialized agents, and result aggregation

import Foundation
import OSLog

// MARK: - Subagent Context

/// Isolated context for a subagent
public struct SubagentContext: Identifiable, Sendable {
    public let id: UUID
    public let parentContextId: UUID?
    public let agentType: SpecializedAgentType
    public let isolationLevel: ContextIsolationLevel
    public let inheritedContext: [String: String]
    public let contextWindow: Int
    public let createdAt: Date
    public var tokenBudget: Int
    public var tokensUsed: Int

    public init(
        id: UUID = UUID(),
        parentContextId: UUID? = nil,
        agentType: SpecializedAgentType,
        isolationLevel: ContextIsolationLevel = .partial,
        inheritedContext: [String: String] = [:],
        contextWindow: Int = 8192,
        tokenBudget: Int = 4096
    ) {
        self.id = id
        self.parentContextId = parentContextId
        self.agentType = agentType
        self.isolationLevel = isolationLevel
        self.inheritedContext = inheritedContext
        self.contextWindow = contextWindow
        self.createdAt = Date()
        self.tokenBudget = tokenBudget
        self.tokensUsed = 0
    }

    public var remainingTokens: Int {
        tokenBudget - tokensUsed
    }
}

public enum ContextIsolationLevel: String, Sendable {
    case full        // Completely isolated, no inherited context
    case partial     // Inherits summary of parent context
    case shared      // Full access to parent context
    case sandbox     // Isolated with read-only parent access
}

// MARK: - Specialized Agent Types

/// Types of specialized agents
public enum SpecializedAgentType: String, Codable, Sendable, CaseIterable {
    // Existing agents
    case explore         // Fast, read-only code search
    case plan            // Reasoning model for architecture
    case generalPurpose  // Versatile, all tools
    case bash            // Command execution specialist
    case research        // Web research focused

    // New specialized agents
    case database        // Database schema, queries, migrations
    case security        // Security analysis, vulnerability scanning
    case performance     // Performance profiling, optimization
    case api             // API design, integration
    case testing         // Test generation, coverage analysis
    case documentation   // Documentation generation
    case refactoring     // Code refactoring specialist
    case review          // Code review and feedback
    case debug           // Debugging and error analysis
    case deployment      // CI/CD, deployment configuration

    public var displayName: String {
        switch self {
        case .explore: return "Explorer"
        case .plan: return "Planner"
        case .generalPurpose: return "General Purpose"
        case .bash: return "Command Executor"
        case .research: return "Researcher"
        case .database: return "Database Expert"
        case .security: return "Security Analyst"
        case .performance: return "Performance Engineer"
        case .api: return "API Specialist"
        case .testing: return "Test Engineer"
        case .documentation: return "Documentation Writer"
        case .refactoring: return "Refactoring Expert"
        case .review: return "Code Reviewer"
        case .debug: return "Debug Specialist"
        case .deployment: return "DevOps Engineer"
        }
    }

    public var systemPrompt: String {
        switch self {
        case .explore:
            return "You are a fast, read-only code exploration agent. Search and analyze code without making changes."
        case .plan:
            return "You are a software architect. Design systems, plan implementations, and create technical specifications."
        case .generalPurpose:
            return "You are a versatile AI assistant with access to all tools. Handle any task efficiently."
        case .bash:
            return "You are a command-line specialist. Execute shell commands, manage files, and automate tasks."
        case .research:
            return "You are a thorough researcher. Search the web, gather information, and synthesize findings."
        case .database:
            return "You are a database expert. Design schemas, optimize queries, plan migrations, and ensure data integrity."
        case .security:
            return "You are a security analyst. Identify vulnerabilities, review code for security issues, and recommend fixes."
        case .performance:
            return "You are a performance engineer. Profile code, identify bottlenecks, and optimize for speed and efficiency."
        case .api:
            return "You are an API specialist. Design RESTful and GraphQL APIs, document endpoints, and handle integrations."
        case .testing:
            return "You are a test engineer. Generate comprehensive tests, analyze coverage, and ensure code reliability."
        case .documentation:
            return "You are a technical writer. Create clear documentation, API docs, and user guides."
        case .refactoring:
            return "You are a refactoring expert. Improve code structure while preserving functionality."
        case .review:
            return "You are a code reviewer. Analyze code for quality, patterns, and potential issues."
        case .debug:
            return "You are a debugging specialist. Analyze errors, trace issues, and identify root causes."
        case .deployment:
            return "You are a DevOps engineer. Configure CI/CD, manage deployments, and automate infrastructure."
        }
    }

    public var suggestedTools: [String] {
        switch self {
        case .explore: return ["read", "search", "grep", "glob"]
        case .plan: return ["read", "write", "search"]
        case .generalPurpose: return ["*"]
        case .bash: return ["bash", "read", "write"]
        case .research: return ["web_search", "web_fetch", "read"]
        case .database: return ["read", "write", "bash"]
        case .security: return ["read", "search", "grep", "bash"]
        case .performance: return ["read", "bash", "search"]
        case .api: return ["read", "write", "web_fetch"]
        case .testing: return ["read", "write", "bash"]
        case .documentation: return ["read", "write"]
        case .refactoring: return ["read", "write", "search"]
        case .review: return ["read", "search", "grep"]
        case .debug: return ["read", "bash", "search", "grep"]
        case .deployment: return ["bash", "read", "write"]
        }
    }

    public var preferredModel: String {
        switch self {
        case .plan, .security, .review:
            return "claude-opus-4"  // Needs deep reasoning
        case .explore, .bash, .debug:
            return "claude-haiku-3.5"  // Fast, simple tasks
        default:
            return "claude-sonnet-4"  // Balanced
        }
    }
}

// MARK: - Subagent Task

/// A task to be executed by a subagent
public struct SubagentTask: Identifiable, Sendable {
    public let id: UUID
    public let parentTaskId: UUID?
    public let agentType: SpecializedAgentType
    public let description: String
    public let input: String
    public let priority: TaskPriority
    public let timeout: TimeInterval
    public let maxTokens: Int
    public let requiredOutput: OutputRequirement
    public let dependsOn: [UUID]

    public init(
        id: UUID = UUID(),
        parentTaskId: UUID? = nil,
        agentType: SpecializedAgentType,
        description: String,
        input: String,
        priority: TaskPriority = .normal,
        timeout: TimeInterval = 60,
        maxTokens: Int = 4096,
        requiredOutput: OutputRequirement = .text,
        dependsOn: [UUID] = []
    ) {
        self.id = id
        self.parentTaskId = parentTaskId
        self.agentType = agentType
        self.description = description
        self.input = input
        self.priority = priority
        self.timeout = timeout
        self.maxTokens = maxTokens
        self.requiredOutput = requiredOutput
        self.dependsOn = dependsOn
    }

    public enum TaskPriority: Int, Comparable, Sendable {
        case low = 0
        case normal = 50
        case high = 75
        case critical = 100

        public static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    public enum OutputRequirement: String, Sendable {
        case text
        case json
        case code
        case markdown
        case structured
    }
}

// MARK: - Enhanced Subagent Result

/// Result from an enhanced subagent execution
public struct EnhancedSubagentResult: Identifiable, Sendable {
    public let id: UUID
    public let taskId: UUID
    public let agentType: SpecializedAgentType
    public let status: EnhancedResultStatus
    public let output: String
    public let structuredOutput: [String: String]?
    public let confidence: Float
    public let tokensUsed: Int
    public let executionTime: TimeInterval
    public let error: String?
    public let metadata: [String: String]

    public init(
        id: UUID = UUID(),
        taskId: UUID,
        agentType: SpecializedAgentType,
        status: EnhancedResultStatus,
        output: String,
        structuredOutput: [String: String]? = nil,
        confidence: Float = 0.8,
        tokensUsed: Int = 0,
        executionTime: TimeInterval = 0,
        error: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.taskId = taskId
        self.agentType = agentType
        self.status = status
        self.output = output
        self.structuredOutput = structuredOutput
        self.confidence = confidence
        self.tokensUsed = tokensUsed
        self.executionTime = executionTime
        self.error = error
        self.metadata = metadata
    }

    public enum EnhancedResultStatus: String, Sendable {
        case success
        case partialSuccess
        case failed
        case timeout
        case cancelled
    }
}

// MARK: - Aggregated Result

/// Aggregated result from multiple subagents
public struct SubagentAggregatedResult: Sendable {
    public let taskId: UUID
    public let results: [EnhancedSubagentResult]
    public let mergedOutput: String
    public let consensusConfidence: Float
    public let totalTokensUsed: Int
    public let totalExecutionTime: TimeInterval
    public let aggregationStrategy: AggregationStrategy

    public init(
        taskId: UUID,
        results: [EnhancedSubagentResult],
        mergedOutput: String,
        consensusConfidence: Float,
        totalTokensUsed: Int,
        totalExecutionTime: TimeInterval,
        aggregationStrategy: AggregationStrategy
    ) {
        self.taskId = taskId
        self.results = results
        self.mergedOutput = mergedOutput
        self.consensusConfidence = consensusConfidence
        self.totalTokensUsed = totalTokensUsed
        self.totalExecutionTime = totalExecutionTime
        self.aggregationStrategy = aggregationStrategy
    }

    public enum AggregationStrategy: String, Sendable {
        case merge          // Combine all outputs
        case consensus      // Take majority agreement
        case bestConfidence // Take highest confidence
        case sequential     // Chain outputs in order
        case custom         // Custom aggregation logic
    }
}

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

    private func executeTask(_ task: SubagentTask, context: SubagentContext) async -> EnhancedSubagentResult {
        // Simulate task execution
        // In production, this would call the actual AI provider
        try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds

        let output = "Executed \(task.agentType.rawValue) task: \(task.description)"
        let tokensUsed = (task.input.count + output.count) / 4

        return EnhancedSubagentResult(
            taskId: task.id,
            agentType: task.agentType,
            status: .success,
            output: output,
            confidence: 0.85,
            tokensUsed: tokensUsed
        )
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
