//
//  MultiAgentOrchestrator.swift
//  Thea
//
//  Autonomous multi-agent orchestration with live monitoring,
//  conflict detection/resolution, and parallel execution.
//
//  The Meta-AI's brain for managing multiple autonomous agents.
//
//  Copyright 2026. All rights reserved.
//

import Combine
import Foundation
import os.log

// MARK: - Agent Definition

/// An autonomous agent that can perform tasks
public actor Agent: Identifiable {
    public let id: UUID
    public let name: String
    public let type: AgentType
    public private(set) var status: AgentStatus = .idle
    public private(set) var currentTask: OrchestrationTask?
    public private(set) var progress: Double = 0
    public private(set) var lastError: String?

    private let logger = Logger(subsystem: "ai.thea.app", category: "Agent")

    public enum AgentType: String, Codable, Sendable {
        case researcher       // Gathers information
        case coder            // Writes/modifies code
        case analyst          // Analyzes data
        case communicator     // Handles communication
        case automator        // Executes automations
        case organizer        // Manages files/data
        case creative         // Creative tasks
        case general          // General purpose
    }

    public enum AgentStatus: String, Sendable {
        case idle
        case preparing
        case running
        case blocked
        case waiting
        case completed
        case failed
        case cancelled
    }

    public init(name: String, type: AgentType) {
        self.id = UUID()
        self.name = name
        self.type = type
    }

    func setStatus(_ status: AgentStatus) {
        self.status = status
    }

    func setTask(_ task: OrchestrationTask?) {
        self.currentTask = task
    }

    func setProgress(_ progress: Double) {
        self.progress = progress
    }

    func setError(_ error: String?) {
        self.lastError = error
    }

    /// Execute a task
    func execute(_ task: OrchestrationTask, context: ExecutionContext) async throws -> MultiAgentResult {
        self.currentTask = task
        self.status = .running
        self.progress = 0

        defer {
            self.status = .completed
            self.progress = 1.0
        }

        logger.info("Agent \(self.name) starting task: \(task.description)")

        // Simulate task execution with progress updates
        // In reality, this would call actual AI providers, execute tools, etc.
        for i in 1...10 {
            try Task.checkCancellation()

            self.progress = Double(i) / 10.0

            // Check for resource conflicts
            if let conflict = await context.checkConflicts(for: task) {
                self.status = .blocked
                logger.warning("Agent \(self.name) blocked by conflict: \(conflict.description)")

                // Wait for conflict resolution
                try await context.waitForResolution(conflict)
                self.status = .running
            }

            try await Task.sleep(nanoseconds: 100_000_000) // 100ms per step
        }

        return MultiAgentResult(
            taskId: task.id,
            agentId: self.id,
            success: true,
            output: "Task completed: \(task.description)",
            artifacts: []
        )
    }
}

// MARK: - Task Definition

/// A task that can be executed by an agent
public struct OrchestrationTask: Identifiable, Sendable {
    public let id: UUID
    public let description: String
    public let type: TaskType
    public let priority: TaskPriority
    public let requiredCapabilities: Set<String>
    public let resourceRequirements: ResourceRequirements
    public let dependencies: [UUID]
    public let deadline: Date?
    public let metadata: [String: String]

    public enum TaskType: String, Codable, Sendable {
        case research
        case analysis
        case generation
        case transformation
        case communication
        case automation
        case verification
    }

    public enum TaskPriority: Int, Codable, Sendable, Comparable {
        case low = 0
        case normal = 1
        case high = 2
        case critical = 3

        public static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    public struct ResourceRequirements: Sendable {
        public let files: Set<String>
        public let apis: Set<String>
        public let memory: Int? // MB
        public let estimatedDuration: TimeInterval?

        public init(
            files: Set<String> = [],
            apis: Set<String> = [],
            memory: Int? = nil,
            estimatedDuration: TimeInterval? = nil
        ) {
            self.files = files
            self.apis = apis
            self.memory = memory
            self.estimatedDuration = estimatedDuration
        }
    }

    public init(
        id: UUID = UUID(),
        description: String,
        type: TaskType,
        priority: TaskPriority = .normal,
        requiredCapabilities: Set<String> = [],
        resourceRequirements: ResourceRequirements = ResourceRequirements(),
        dependencies: [UUID] = [],
        deadline: Date? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.description = description
        self.type = type
        self.priority = priority
        self.requiredCapabilities = requiredCapabilities
        self.resourceRequirements = resourceRequirements
        self.dependencies = dependencies
        self.deadline = deadline
        self.metadata = metadata
    }
}

// MARK: - Agent Result

/// Result of an agent's task execution
public struct MultiAgentResult: Sendable {
    public let taskId: UUID
    public let agentId: UUID
    public let success: Bool
    public let output: String
    public let artifacts: [Artifact]
    public let error: String?

    public struct Artifact: Sendable {
        public let type: ArtifactType
        public let path: String?
        public let content: String?

        public enum ArtifactType: String, Sendable {
            case file
            case code
            case data
            case report
        }
    }

    public init(
        taskId: UUID,
        agentId: UUID,
        success: Bool,
        output: String,
        artifacts: [Artifact] = [],
        error: String? = nil
    ) {
        self.taskId = taskId
        self.agentId = agentId
        self.success = success
        self.output = output
        self.artifacts = artifacts
        self.error = error
    }
}

// MARK: - Conflict Types

/// A conflict between agents or resources
public struct AgentConflict: Identifiable, Sendable {
    public let id: UUID
    public let type: ConflictType
    public let description: String
    public let involvedAgents: [UUID]
    public let resource: String?
    public let severity: Severity
    public let detectedAt: Date

    public enum ConflictType: String, Sendable {
        case resourceContention   // Multiple agents need same resource
        case fileAccess           // Concurrent file access
        case apiRateLimit         // API rate limiting
        case dependencyDeadlock   // Circular dependencies
        case memoryPressure       // Memory constraints
        case outputCollision      // Same output target
    }

    public enum Severity: Int, Sendable {
        case low = 0
        case medium = 1
        case high = 2
        case critical = 3
    }

    public init(
        type: ConflictType,
        description: String,
        involvedAgents: [UUID],
        resource: String? = nil,
        severity: Severity = .medium
    ) {
        self.id = UUID()
        self.type = type
        self.description = description
        self.involvedAgents = involvedAgents
        self.resource = resource
        self.severity = severity
        self.detectedAt = Date()
    }
}

/// Strategy for resolving conflicts
public enum OrchestrationConflictStrategy: String, Sendable {
    case priorityBased    // Higher priority agent wins
    case firstComeFirst   // First to request wins
    case roundRobin       // Take turns
    case merge            // Merge outputs if possible
    case retry            // Retry with backoff
    case escalate         // Escalate to user
    case cleanest         // Choose cleanest solution (architect's choice)
}

// MARK: - Execution Context

/// Shared context for coordinating agent execution
public actor ExecutionContext {
    private var lockedResources: [String: UUID] = [:] // resource -> agent holding lock
    private var pendingConflicts: [AgentConflict] = []
    private var resolvedConflicts: Set<UUID> = []
    private var resourceWaiters: [String: [CheckedContinuation<Void, Error>]] = [:]

    private let logger = Logger(subsystem: "ai.thea.app", category: "ExecutionContext")

    /// Try to acquire a resource lock
    func acquireResource(_ resource: String, for agentId: UUID) async throws -> Bool {
        if let holder = lockedResources[resource] {
            if holder == agentId {
                return true // Already holds the lock
            }
            return false // Someone else has it
        }

        lockedResources[resource] = agentId
        logger.debug("Agent \(agentId) acquired resource: \(resource)")
        return true
    }

    /// Release a resource lock
    func releaseResource(_ resource: String, by agentId: UUID) {
        if lockedResources[resource] == agentId {
            lockedResources.removeValue(forKey: resource)
            logger.debug("Agent \(agentId) released resource: \(resource)")

            // Wake up any waiters
            if let waiters = resourceWaiters.removeValue(forKey: resource) {
                for waiter in waiters {
                    waiter.resume()
                }
            }
        }
    }

    /// Check for conflicts with a task
    func checkConflicts(for task: OrchestrationTask) -> AgentConflict? {
        // Check resource contention
        for file in task.resourceRequirements.files {
            if let holder = lockedResources[file] {
                return AgentConflict(
                    type: .resourceContention,
                    description: "File \(file) is locked",
                    involvedAgents: [holder],
                    resource: file,
                    severity: .medium
                )
            }
        }

        for api in task.resourceRequirements.apis {
            if let holder = lockedResources[api] {
                return AgentConflict(
                    type: .apiRateLimit,
                    description: "API \(api) is in use",
                    involvedAgents: [holder],
                    resource: api,
                    severity: .low
                )
            }
        }

        return nil
    }

    /// Wait for a conflict to be resolved
    func waitForResolution(_ conflict: AgentConflict) async throws {
        guard let resource = conflict.resource else {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second default
            return
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            if resourceWaiters[resource] == nil {
                resourceWaiters[resource] = []
            }
            resourceWaiters[resource]?.append(continuation)
        }
    }

    /// Add a conflict to be resolved
    func addConflict(_ conflict: AgentConflict) {
        pendingConflicts.append(conflict)
    }

    /// Mark a conflict as resolved
    func resolveConflict(_ conflictId: UUID) {
        pendingConflicts.removeAll { $0.id == conflictId }
        resolvedConflicts.insert(conflictId)
    }
}

// MARK: - Multi-Agent Orchestrator

/// Orchestrates multiple agents working in parallel
@MainActor
public final class MultiAgentOrchestrator: ObservableObject {
    public static let shared = MultiAgentOrchestrator()

    private let logger = Logger(subsystem: "ai.thea.app", category: "MultiAgentOrchestrator")

    // MARK: - Published State

    /// Active agents
    @Published public private(set) var agents: [Agent] = []

    /// Pending tasks
    @Published public private(set) var pendingTasks: [OrchestrationTask] = []

    /// Running tasks
    @Published public private(set) var runningTasks: [UUID: (agent: Agent, task: OrchestrationTask)] = [:]

    /// Completed results
    @Published public private(set) var completedResults: [MultiAgentResult] = []

    /// Active conflicts
    @Published public private(set) var activeConflicts: [AgentConflict] = []

    /// Overall progress (0-1)
    @Published public private(set) var overallProgress: Double = 0

    /// Whether orchestration is active
    @Published public private(set) var isOrchestrating: Bool = false

    // MARK: - Configuration

    /// Maximum concurrent agents
    public var maxConcurrentAgents: Int = 5

    /// Default conflict resolution strategy
    public var defaultResolutionStrategy: OrchestrationConflictStrategy = .cleanest

    /// Whether to auto-resolve conflicts
    public var autoResolveConflicts: Bool = true

    // MARK: - Private State

    private let executionContext = ExecutionContext()
    private var orchestrationTask: Task<Void, Never>?
    private var monitoringTasks: [UUID: Task<Void, Never>] = [:]
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        createDefaultAgents()
    }

    private func createDefaultAgents() {
        let defaultAgents = [
            Agent(name: "Researcher", type: .researcher),
            Agent(name: "Coder", type: .coder),
            Agent(name: "Analyst", type: .analyst),
            Agent(name: "Automator", type: .automator),
            Agent(name: "Organizer", type: .organizer)
        ]
        agents = defaultAgents
    }

    // MARK: - Public API

    /// Execute a complex task by decomposing and parallelizing
    public func executeComplexTask(_ description: String) async -> [MultiAgentResult] {
        isOrchestrating = true
        defer { isOrchestrating = false }

        logger.info("Starting complex task: \(description)")

        // Decompose the task
        let subtasks = await decomposeTask(description)
        pendingTasks = subtasks

        // Execute with orchestration
        let results = await orchestrate(subtasks)

        completedResults.append(contentsOf: results)
        pendingTasks.removeAll()

        logger.info("Complex task completed with \(results.count) results")
        return results
    }

    /// Add a task to the queue
    public func enqueueTask(_ task: OrchestrationTask) {
        pendingTasks.append(task)
        pendingTasks.sort { $0.priority > $1.priority }
    }

    /// Cancel all running tasks
    public func cancelAll() {
        orchestrationTask?.cancel()
        for (_, task) in monitoringTasks {
            task.cancel()
        }
        monitoringTasks.removeAll()

        Task {
            for agent in agents {
                await agent.setStatus(.cancelled)
            }
        }
    }

    /// Resolve a conflict manually
    public func resolveConflict(_ conflictId: UUID, with strategy: OrchestrationConflictStrategy) async {
        guard let conflict = activeConflicts.first(where: { $0.id == conflictId }) else {
            return
        }

        await applyResolutionStrategy(strategy, to: conflict)
        await executionContext.resolveConflict(conflictId)
        activeConflicts.removeAll { $0.id == conflictId }

        logger.info("Resolved conflict \(conflictId) with strategy: \(strategy.rawValue)")
    }

    // MARK: - Task Decomposition

    private func decomposeTask(_ description: String) async -> [OrchestrationTask] {
        // Use AI to decompose the task into subtasks
        // For now, create a simple decomposition

        // This would call the TaskClassifier and QueryDecomposer
        let subtasks: [OrchestrationTask] = [
            OrchestrationTask(
                description: "Research: \(description)",
                type: .research,
                priority: .high
            ),
            OrchestrationTask(
                description: "Analyze findings for: \(description)",
                type: .analysis,
                priority: .normal,
                dependencies: [] // Would include research task ID
            ),
            OrchestrationTask(
                description: "Generate solution for: \(description)",
                type: .generation,
                priority: .normal,
                dependencies: [] // Would include analysis task ID
            ),
            OrchestrationTask(
                description: "Verify solution for: \(description)",
                type: .verification,
                priority: .high,
                dependencies: [] // Would include generation task ID
            )
        ]

        return subtasks
    }

    // MARK: - Orchestration

    private func orchestrate(_ tasks: [OrchestrationTask]) async -> [MultiAgentResult] {
        var results: [MultiAgentResult] = []
        var completedTaskIds: Set<UUID> = []

        while !tasks.allSatisfy({ completedTaskIds.contains($0.id) }) {
            // Find tasks ready to run (dependencies met)
            let readyTasks = tasks.filter { task in
                !completedTaskIds.contains(task.id) &&
                task.dependencies.allSatisfy { completedTaskIds.contains($0) }
            }

            // Run tasks in parallel up to max concurrency
            let tasksToRun = Array(readyTasks.prefix(maxConcurrentAgents - runningTasks.count))

            await withTaskGroup(of: MultiAgentResult?.self) { group in
                for task in tasksToRun {
                    // Find available agent
                    guard let agent = await findAvailableAgent(for: task) else {
                        continue
                    }

                    runningTasks[task.id] = (agent, task)

                    group.addTask {
                        do {
                            let result = try await agent.execute(task, context: self.executionContext)
                            return result
                        } catch {
                            return MultiAgentResult(
                                taskId: task.id,
                                agentId: agent.id,
                                success: false,
                                output: "",
                                error: error.localizedDescription
                            )
                        }
                    }

                    // Start monitoring
                    startMonitoring(agent: agent, task: task)
                }

                for await result in group {
                    if let result = result {
                        results.append(result)
                        completedTaskIds.insert(result.taskId)
                        runningTasks.removeValue(forKey: result.taskId)
                        stopMonitoring(taskId: result.taskId)
                    }
                }
            }

            // Update progress
            overallProgress = Double(completedTaskIds.count) / Double(tasks.count)

            // Small delay to prevent busy loop
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        return results
    }

    private func findAvailableAgent(for task: OrchestrationTask) async -> Agent? {
        for agent in agents {
            let status = await agent.status
            if status == .idle || status == .completed {
                return agent
            }
        }
        return nil
    }

    // MARK: - Monitoring

    private func startMonitoring(agent: Agent, task: OrchestrationTask) {
        let monitorTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000) // 500ms

                let status = await agent.status
                let progress = await agent.progress

                // Check for potential conflicts
                if let conflict = await executionContext.checkConflicts(for: task) {
                    await MainActor.run {
                        if !self.activeConflicts.contains(where: { $0.id == conflict.id }) {
                            self.activeConflicts.append(conflict)
                            self.logger.warning("Conflict detected: \(conflict.description)")

                            if self.autoResolveConflicts {
                                Task {
                                    await self.autoResolveConflict(conflict)
                                }
                            }
                        }
                    }
                }

                // Emit progress update
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: .agentProgressUpdated,
                        object: nil,
                        userInfo: [
                            "agentId": agent.id,
                            "taskId": task.id,
                            "status": status.rawValue,
                            "progress": progress
                        ]
                    )
                }

                if status == .completed || status == .failed || status == .cancelled {
                    break
                }
            }
        }

        monitoringTasks[task.id] = monitorTask
    }

    private func stopMonitoring(taskId: UUID) {
        monitoringTasks[taskId]?.cancel()
        monitoringTasks.removeValue(forKey: taskId)
    }

    // MARK: - Conflict Resolution

    private func autoResolveConflict(_ conflict: AgentConflict) async {
        let strategy = determineResolutionStrategy(for: conflict)
        await applyResolutionStrategy(strategy, to: conflict)
        await executionContext.resolveConflict(conflict.id)

        await MainActor.run {
            activeConflicts.removeAll { $0.id == conflict.id }
        }

        logger.info("Auto-resolved conflict with strategy: \(strategy.rawValue)")
    }

    private func determineResolutionStrategy(for conflict: AgentConflict) -> OrchestrationConflictStrategy {
        switch conflict.type {
        case .resourceContention:
            return .priorityBased
        case .fileAccess:
            return .firstComeFirst
        case .apiRateLimit:
            return .retry
        case .dependencyDeadlock:
            return .escalate
        case .memoryPressure:
            return .priorityBased
        case .outputCollision:
            return .merge
        }
    }

    private func applyResolutionStrategy(_ strategy: OrchestrationConflictStrategy, to conflict: AgentConflict) async {
        switch strategy {
        case .priorityBased:
            // Find highest priority task among involved agents
            // Let it proceed, others wait
            break

        case .firstComeFirst:
            // Already handled by lock acquisition order
            break

        case .roundRobin:
            // Implement time-slicing
            break

        case .merge:
            // Attempt to merge outputs
            break

        case .retry:
            // Add exponential backoff
            break

        case .escalate:
            // Notify user
            NotificationCenter.default.post(
                name: .conflictNeedsUserResolution,
                object: nil,
                userInfo: ["conflict": conflict]
            )

        case .cleanest:
            // Analyze and choose best approach
            // This is the "architect's choice" - pick the solution that
            // maintains code quality and system integrity
            break
        }
    }
}

// MARK: - Notifications

public extension Notification.Name {
    static let agentProgressUpdated = Notification.Name("thea.agent.progressUpdated")
    static let conflictNeedsUserResolution = Notification.Name("thea.agent.conflictNeedsResolution")
    static let orchestrationCompleted = Notification.Name("thea.agent.orchestrationCompleted")
}
