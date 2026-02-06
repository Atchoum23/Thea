import Foundation
import Observation

/// Errors that can occur in sub-agent orchestration
enum SubAgentOrchestratorError: Error, LocalizedError {
    case noProviderAvailable
    case taskFailed(String)
    case agentNotFound

    var errorDescription: String? {
        switch self {
        case .noProviderAvailable:
            "No AI provider available for orchestration"
        case let .taskFailed(reason):
            "Task failed: \(reason)"
        case .agentNotFound:
            "Sub-agent not found"
        }
    }
}

/// The core orchestration system for managing multiple AI sub-agents
@MainActor
@Observable
final class SubAgentOrchestrator {
    static let shared = SubAgentOrchestrator()

    private(set) var activeAgents: [SubAgent] = []
    private(set) var completedTasks: [AgentTask] = []
    private(set) var isOrchestrating: Bool = false

    private var taskQueue: [AgentTask] = []
    private var agentPool: [AgentType: [SubAgent]] = [:]

    // Configuration accessor
    private var config: MetaAIConfiguration {
        AppConfiguration.shared.metaAIConfig
    }

    private init() {
        initializeAgentPool()
    }

    // MARK: - Agent Types

    enum AgentType: String, CaseIterable, Codable {
        case researcher = "Researcher"
        case coder = "Coder"
        case analyst = "Analyst"
        case writer = "Writer"
        case planner = "Planner"
        case critic = "Critic"
        case executor = "Executor"
        case integrator = "Integrator"
        case validator = "Validator"
        case optimizer = "Optimizer"

        var systemPrompt: String {
            switch self {
            case .researcher:
                return "You are a research specialist. Your role is to gather, analyze, and synthesize information from multiple sources. You provide comprehensive, well-sourced insights."
            case .coder:
                let bestPractices = SwiftBestPracticesLibrary.shared.getPracticesForContext("")
                let bestPracticesText = SwiftBestPracticesLibrary.shared.formatForPrompt(Array(bestPractices.prefix(10)))

                return """
                You are an expert Swift 6.0 software engineer specializing in modern, production-ready code.

                CORE COMPETENCIES:
                - Swift 6.0 strict concurrency (@Sendable, @MainActor, actors)
                - SwiftUI with @Observable macro (iOS 17+, macOS 14+)
                - SwiftData for persistence
                - Protocol-oriented programming
                - Comprehensive error handling
                - Modern async/await patterns

                MANDATORY REQUIREMENTS:
                1. All code MUST compile without errors on first attempt
                2. Zero compiler warnings
                3. Zero SwiftLint violations
                4. Follow Swift API Design Guidelines
                5. Use descriptive, self-documenting names
                6. Handle all error cases gracefully
                7. Respect memory management (no retain cycles)
                8. Use @MainActor for all UI code

                \(bestPracticesText)

                QUALITY STANDARDS:
                - Production-ready code only
                - Self-documenting design
                - Minimal comments (only for complex logic)
                - Performance-conscious implementations
                - Security-first mindset

                VALIDATION PROCESS:
                Your code will be validated using swiftc -typecheck before delivery.
                Any compilation errors will be fed back for correction.
                """
            case .analyst:
                return "You are a data analyst. You examine data, identify patterns, and provide actionable insights. You excel at breaking down complex information."
            case .writer:
                return "You are a professional writer. You create clear, engaging, and well-structured content tailored to the audience and purpose."
            case .planner:
                return "You are a strategic planner. You break down complex goals into actionable steps, identify dependencies, and create efficient execution plans."
            case .critic:
                return "You are a constructive critic. You identify flaws, gaps, and areas for improvement in ideas, plans, and implementations."
            case .executor:
                return "You are an executor. You take plans and implement them step-by-step, ensuring each action is completed correctly."
            case .integrator:
                return "You are an integrator. You combine outputs from multiple agents into cohesive, unified results."
            case .validator:
                return "You are a validator. You verify that outputs meet requirements, are accurate, and align with objectives."
            case .optimizer:
                return "You are an optimizer. You improve existing solutions for efficiency, performance, and quality."
            }
        }

        var capabilities: [String] {
            switch self {
            case .researcher:
                ["web_search", "document_analysis", "source_verification"]
            case .coder:
                ["code_generation", "code_review", "debugging", "testing"]
            case .analyst:
                ["data_analysis", "pattern_recognition", "reporting"]
            case .writer:
                ["content_creation", "editing", "summarization"]
            case .planner:
                ["task_breakdown", "dependency_mapping", "timeline_creation"]
            case .critic:
                ["review", "evaluation", "feedback"]
            case .executor:
                ["task_execution", "tool_use", "file_operations"]
            case .validator:
                ["verification", "testing", "quality_assurance"]
            case .integrator:
                ["synthesis", "merging", "coordination"]
            case .optimizer:
                ["improvement", "refactoring", "performance_tuning"]
            }
        }
    }

    // MARK: - Initialize Agent Pool

    private func initializeAgentPool() {
        for agentType in AgentType.allCases {
            agentPool[agentType] = []
            // Pre-create 2 agents of each type
            for i in 0 ..< 2 {
                let agent = SubAgent(
                    id: UUID(),
                    type: agentType,
                    index: i
                )
                agentPool[agentType]?.append(agent)
            }
        }
    }

    // MARK: - Orchestration

    /// Execute a complex task by orchestrating multiple agents
    /// Uses timeout enforcement and graceful degradation patterns
    func orchestrate(
        task: String,
        context: [String: Any] = [:],
        timeout: TimeInterval = 300, // 5 minute default timeout
        progressHandler: @escaping @Sendable (OrchestrationProgress) -> Void
    ) async throws -> OrchestrationResult {
        let startTime = Date()
        isOrchestrating = true
        defer { isOrchestrating = false }

        // Create deadline executor for timeout enforcement
        let deadline = DeadlineExecutor(timeout: timeout)

        // Step 1: Analyze task with Planner agent
        progressHandler(OrchestrationProgress(
            phase: .planning,
            message: "Analyzing task requirements",
            progress: 0.1
        ))

        try deadline.checkDeadline()
        let plan = try await planTask(task, context: context)

        // Step 2: Decompose into sub-tasks
        progressHandler(OrchestrationProgress(
            phase: .decomposition,
            message: "Breaking down into sub-tasks",
            progress: 0.2
        ))

        try deadline.checkDeadline()
        let subTasks = try await decomposePlan(plan)

        // Step 3: Assign agents to sub-tasks
        progressHandler(OrchestrationProgress(
            phase: .assignment,
            message: "Assigning agents to tasks",
            progress: 0.3
        ))

        let assignments = assignAgents(to: subTasks)

        // Step 4: Execute sub-tasks in parallel where possible
        progressHandler(OrchestrationProgress(
            phase: .execution,
            message: "Executing tasks with agent swarm",
            progress: 0.4
        ))

        try deadline.checkDeadline()
        let results = try await executeSwarm(assignments, progressHandler: progressHandler)

        // Step 5: Integrate results
        progressHandler(OrchestrationProgress(
            phase: .integration,
            message: "Integrating results from agents",
            progress: 0.8
        ))

        try deadline.checkDeadline()
        let integrated = try await integrateResults(results)

        // Step 6: Validate and criticize
        progressHandler(OrchestrationProgress(
            phase: .validation,
            message: "Validating final output",
            progress: 0.9
        ))

        try deadline.checkDeadline()
        let validated = try await validateResult(integrated)

        // Step 7: Optimize if needed
        try deadline.checkDeadline()
        let optimized = try await optimizeResult(validated)

        progressHandler(OrchestrationProgress(
            phase: .complete,
            message: "Orchestration complete",
            progress: 1.0
        ))

        return OrchestrationResult(
            task: task,
            plan: plan,
            subTaskResults: results,
            finalResult: optimized,
            agentsUsed: assignments.map(\.agent.type),
            executionTime: Date().timeIntervalSince(startTime)
        )
    }

    // MARK: - Planning

    private func planTask(_ task: String, context: [String: Any]) async throws -> TaskPlan {
        let planner = getAgent(type: .planner)
        activeAgents.append(planner)

        let prompt = """
        Analyze this task and create a detailed execution plan:

        Task: \(task)
        Context: \(context)

        Provide:
        1. Task complexity (simple/moderate/complex)
        2. Required agent types
        3. Estimated steps
        4. Dependencies
        5. Success criteria

        Format as JSON.
        """

        // Use orchestrator-aware provider selection (respects local model preference)
        guard let provider = ProviderRegistry.shared.getProviderForTask(complexity: .moderate) ??
            ProviderRegistry.shared.getDefaultProvider()
        else {
            throw SubAgentOrchestratorError.noProviderAvailable
        }

        // Use provider's own model name for local models
        let modelToUse = provider.metadata.name == "local" ? provider.metadata.name : config.plannerModel
        let planText = try await streamProviderResponse(provider: provider, prompt: prompt, model: modelToUse)

        // Parse plan (simplified - should use proper JSON parsing)
        return TaskPlan(
            originalTask: task,
            complexity: .complex,
            requiredAgents: [.researcher, .coder, .analyst, .integrator, .validator],
            steps: extractSteps(from: planText),
            dependencies: [:],
            successCriteria: extractCriteria(from: planText)
        )
    }

    private func decomposePlan(_ plan: TaskPlan) async throws -> [SubTask] {
        plan.steps.enumerated().map { index, step in
            SubTask(
                id: UUID(),
                description: step,
                assignedAgentType: plan.requiredAgents[min(index, plan.requiredAgents.count - 1)],
                dependencies: [],
                priority: calculatePriority(step: index, total: plan.steps.count)
            )
        }
    }

    // MARK: - Agent Assignment

    private func assignAgents(to subTasks: [SubTask]) -> [AgentAssignment] {
        subTasks.map { subTask in
            let agent = getAgent(type: subTask.assignedAgentType)
            return AgentAssignment(
                subTask: subTask,
                agent: agent
            )
        }
    }

    private func getAgent(type: AgentType) -> SubAgent {
        if let availableAgent = agentPool[type]?.first(where: { !activeAgents.contains($0) }) {
            return availableAgent
        }

        // Create new agent if pool is exhausted
        let newAgent = SubAgent(
            id: UUID(),
            type: type,
            index: agentPool[type]?.count ?? 0
        )
        agentPool[type]?.append(newAgent)
        return newAgent
    }

    // MARK: - Swarm Execution

    private func executeSwarm(
        _ assignments: [AgentAssignment],
        progressHandler: @escaping @Sendable (OrchestrationProgress) -> Void
    ) async throws -> [SubTaskResult] {
        var results: [SubTaskResult] = []

        // Execute tasks in parallel batches based on dependencies
        let batches = createExecutionBatches(assignments)

        for (batchIndex, batch) in batches.enumerated() {
            let batchProgress = 0.4 + (0.4 * Double(batchIndex) / Double(batches.count))

            progressHandler(OrchestrationProgress(
                phase: .execution,
                message: "Executing batch \(batchIndex + 1) of \(batches.count)",
                progress: batchProgress
            ))

            // Execute batch tasks in TRUE PARALLEL with error tolerance
            // Based on 2025 best practices: "serve partial results rather than no results"
            let batchResults = try await executeParallelBatch(batch, continueOnError: true)
            results.append(contentsOf: batchResults)
        }

        return results
    }

    /// Execute a batch of tasks in parallel with graceful degradation
    private func executeParallelBatch(
        _ batch: [AgentAssignment],
        continueOnError: Bool
    ) async throws -> [SubTaskResult] {
        // Use withParallelTimeout for robust parallel execution
        let operations: [@Sendable () async throws -> SubTaskResult] = batch.map { assignment in
            { [self] in
                try await self.executeSubTask(assignment)
            }
        }

        // Execute with 60 second timeout per batch, continue on individual errors
        let parallelResults = try await withParallelTimeout(
            operations: operations,
            timeout: 60.0,
            continueOnError: continueOnError
        )

        // Collect successful results, log failures
        var results: [SubTaskResult] = []
        for parallelResult in parallelResults {
            if let value = parallelResult.value {
                results.append(value)
            } else if let error = parallelResult.error {
                // Create failure result for tracking
                let assignment = batch[parallelResult.index]
                let failureResult = SubTaskResult(
                    subTask: assignment.subTask,
                    agent: assignment.agent,
                    output: "Task failed: \(error.localizedDescription)",
                    success: false,
                    executionTime: 0
                )
                results.append(failureResult)
            }
        }

        return results
    }

    private func executeSubTask(_ assignment: AgentAssignment) async throws -> SubTaskResult {
        // Use code validation for Coder agents
        if assignment.agent.type == .coder {
            return try await executeCoderTaskWithValidation(assignment)
        }

        let agent = assignment.agent
        let subTask = assignment.subTask

        // Use orchestrator-aware provider selection (respects local model preference)
        guard let provider = ProviderRegistry.shared.getProviderForTask(complexity: .simple) ??
            ProviderRegistry.shared.getDefaultProvider()
        else {
            throw SubAgentOrchestratorError.noProviderAvailable
        }

        let prompt = """
        \(agent.type.systemPrompt)

        Your specific task: \(subTask.description)

        Execute this task and provide a detailed result.
        """

        // Use provider's own model name for local models, otherwise use config
        let modelToUse = provider.metadata.name == "local" ? provider.metadata.name : config.executorModel
        let output = try await streamProviderResponse(provider: provider, prompt: prompt, model: modelToUse)

        return SubTaskResult(
            subTask: subTask,
            agent: agent,
            output: output,
            success: true,
            executionTime: 1.0
        )
    }

    private func executeCoderTaskWithValidation(_ assignment: AgentAssignment) async throws -> SubTaskResult {
        let startTime = Date()

        #if os(macOS)
        let swiftValidator = SwiftValidator.shared
        var attempts = 0
        let maxAttempts = 3
        var lastErrors: [SwiftError] = []

        while attempts < maxAttempts {
            attempts += 1

            // 1. Enhance prompt with error context if we have previous failures
            var enhancedTask = assignment.subTask.description
            if attempts > 1, !lastErrors.isEmpty {
                let errorContext = lastErrors.map {
                    "Line \($0.line ?? 0): \($0.message)"
                }.joined(separator: "\n")

                enhancedTask = """
                PREVIOUS ATTEMPT FAILED with compilation errors:
                \(errorContext)

                ORIGINAL TASK:
                \(assignment.subTask.description)

                Please fix ALL errors and provide corrected code that compiles without errors.
                """
            }

            // 2. Generate code
            guard let provider = ProviderRegistry.shared.getProviderForTask(complexity: .moderate) ??
                ProviderRegistry.shared.getDefaultProvider()
            else {
                throw SubAgentOrchestratorError.noProviderAvailable
            }

            let prompt = """
            \(assignment.agent.type.systemPrompt)

            Your specific task: \(enhancedTask)

            Execute this task and provide a detailed result.
            """

            let coderModel = provider.metadata.name == "local" ? provider.metadata.name : config.coderModel
            let output = try await streamProviderResponse(provider: provider, prompt: prompt, model: coderModel)

            // 3. Check if output contains Swift code
            guard let swiftCode = swiftValidator.extractSwiftCode(from: output) else {
                // Not Swift code, return as-is
                return SubTaskResult(
                    subTask: assignment.subTask,
                    agent: assignment.agent,
                    output: output,
                    success: true,
                    executionTime: Date().timeIntervalSince(startTime)
                )
            }

            // 4. Validate Swift syntax using swiftc -typecheck
            do {
                let validation = try await swiftValidator.validateSwiftSyntax(swiftCode)

                switch validation {
                case .success:
                    // Code compiles! Return it
                    return SubTaskResult(
                        subTask: assignment.subTask,
                        agent: assignment.agent,
                        output: output,
                        success: true,
                        executionTime: Date().timeIntervalSince(startTime)
                    )

                case let .failure(errors):
                    lastErrors = errors

                    if attempts >= maxAttempts {
                        // Return failure result with error details
                        let errorSummary = errors.map(\.displayMessage).joined(separator: "\n")
                        return SubTaskResult(
                            subTask: assignment.subTask,
                            agent: assignment.agent,
                            output: "❌ Code validation failed after \(maxAttempts) attempts:\n\n\(errorSummary)\n\nLast generated code:\n```swift\n\(swiftCode)\n```",
                            success: false,
                            executionTime: Date().timeIntervalSince(startTime)
                        )
                    }
                    // Continue to next attempt
                    continue
                }
            } catch {
                // Validation error (not compilation error)
                if attempts >= maxAttempts {
                    throw error
                }
                continue
            }
        }

        // Max attempts exceeded
        return SubTaskResult(
            subTask: assignment.subTask,
            agent: assignment.agent,
            output: "Max attempts exceeded",
            success: false,
            executionTime: Date().timeIntervalSince(startTime)
        )

        #else
        // On non-macOS platforms, skip validation and just generate code
        guard let provider = ProviderRegistry.shared.getProviderForTask(complexity: .moderate) ??
            ProviderRegistry.shared.getDefaultProvider()
        else {
            throw SubAgentOrchestratorError.noProviderAvailable
        }

        let prompt = """
        \(assignment.agent.type.systemPrompt)

        Your specific task: \(assignment.subTask.description)

        Execute this task and provide a detailed result.
        """

        let coderModel = provider.metadata.name == "local" ? provider.metadata.name : config.coderModel
        let output = try await streamProviderResponse(provider: provider, prompt: prompt, model: coderModel)

        return SubTaskResult(
            subTask: assignment.subTask,
            agent: assignment.agent,
            output: output,
            success: true,
            executionTime: Date().timeIntervalSince(startTime)
        )
        #endif
    }

    // MARK: - Integration

    private func integrateResults(_ results: [SubTaskResult]) async throws -> String {
        let integrator = getAgent(type: .integrator)

        let allOutputs = results.map { "[\($0.agent.type.rawValue)]: \($0.output)" }.joined(separator: "\n\n")

        // Use orchestrator-aware provider selection
        guard let provider = ProviderRegistry.shared.getProviderForTask(complexity: .moderate) ??
            ProviderRegistry.shared.getDefaultProvider()
        else {
            throw SubAgentOrchestratorError.noProviderAvailable
        }

        let prompt = """
        \(integrator.type.systemPrompt)

        Integrate these outputs from multiple agents into a cohesive final result:

        \(allOutputs)

        Provide a unified, coherent response.
        """

        // Use provider's own model name for local models, otherwise use config
        let integrationModel = provider.metadata.name == "local" ? provider.metadata.name : config.integratorModel
        return try await streamProviderResponse(provider: provider, prompt: prompt, model: integrationModel)
    }

    // MARK: - Validation

    private func validateResult(_ result: String) async throws -> String {
        let validator = getAgent(type: .validator)

        // Use orchestrator-aware provider selection
        guard let provider = ProviderRegistry.shared.getProviderForTask(complexity: .simple) ??
            ProviderRegistry.shared.getDefaultProvider()
        else {
            throw SubAgentOrchestratorError.noProviderAvailable
        }

        let prompt = """
        \(validator.type.systemPrompt)

        Validate this output for correctness, completeness, and quality:

        \(result)

        If valid, return it as-is. If issues found, provide corrected version.
        """

        // Use provider's own model name for local models, otherwise use config
        let validatorModel = provider.metadata.name == "local" ? provider.metadata.name : config.validatorModel
        return try await streamProviderResponse(provider: provider, prompt: prompt, model: validatorModel)
    }

    // MARK: - Optimization

    private func optimizeResult(_ result: String) async throws -> String {
        let optimizer = getAgent(type: .optimizer)

        // Use orchestrator-aware provider selection
        guard let provider = ProviderRegistry.shared.getProviderForTask(complexity: .simple) ??
            ProviderRegistry.shared.getDefaultProvider()
        else {
            throw SubAgentOrchestratorError.noProviderAvailable
        }

        let prompt = """
        \(optimizer.type.systemPrompt)

        Optimize this output for clarity, conciseness, and impact:

        \(result)
        """

        // Use provider's own model name for local models, otherwise use config
        let optimizerModel = provider.metadata.name == "local" ? provider.metadata.name : config.optimizerModel
        return try await streamProviderResponse(provider: provider, prompt: prompt, model: optimizerModel)
    }

    // MARK: - Helper Methods

    private func createExecutionBatches(_ assignments: [AgentAssignment]) -> [[AgentAssignment]] {
        // Simple batching - in production would respect dependencies
        let batchSize = 3
        return stride(from: 0, to: assignments.count, by: batchSize).map {
            Array(assignments[$0 ..< min($0 + batchSize, assignments.count)])
        }
    }

    private func extractSteps(from planText: String) -> [String] {
        // Simplified extraction - should use proper parsing
        planText.split(separator: "\n")
            .filter { $0.contains("Step") || $0.contains(".") }
            .map { String($0) }
    }

    private func extractCriteria(from _: String) -> [String] {
        ["Output is complete", "Output is accurate", "Output meets requirements"]
    }

    private func calculatePriority(step: Int, total: Int) -> Int {
        total - step
    }

    // Helper to stream provider response into a single string
    private func streamProviderResponse(provider: AIProvider, prompt: String, model: String) async throws -> String {
        let message = AIMessage(
            id: UUID(),
            conversationID: UUID(),
            role: .user,
            content: .text(prompt),
            timestamp: Date(),
            model: model
        )

        var result = ""
        let stream = try await provider.chat(messages: [message], model: model, stream: true)

        for try await chunk in stream {
            switch chunk.type {
            case let .delta(text):
                result += text
            case .complete:
                break
            case let .error(error):
                throw error
            }
        }

        return result
    }
}

// MARK: - Data Structures

struct SubAgent: Identifiable, Equatable {
    let id: UUID
    let type: SubAgentOrchestrator.AgentType
    let index: Int
    var isActive: Bool = false

    static func == (lhs: SubAgent, rhs: SubAgent) -> Bool {
        lhs.id == rhs.id
    }
}

struct TaskPlan {
    let originalTask: String
    let complexity: TaskComplexity
    let requiredAgents: [SubAgentOrchestrator.AgentType]
    let steps: [String]
    let dependencies: [Int: [Int]]
    let successCriteria: [String]

    enum TaskComplexity {
        case simple, moderate, complex, extreme
    }
}

struct SubTask: Identifiable {
    let id: UUID
    let description: String
    let assignedAgentType: SubAgentOrchestrator.AgentType
    let dependencies: [UUID]
    let priority: Int
}

struct AgentAssignment {
    let subTask: SubTask
    let agent: SubAgent
}

struct SubTaskResult {
    let subTask: SubTask
    let agent: SubAgent
    let output: String
    let success: Bool
    let executionTime: TimeInterval
}

struct OrchestrationResult {
    let task: String
    let plan: TaskPlan
    let subTaskResults: [SubTaskResult]
    let finalResult: String
    let agentsUsed: [SubAgentOrchestrator.AgentType]
    let executionTime: TimeInterval
}

struct OrchestrationProgress: Sendable {
    let phase: Phase
    let message: String
    let progress: Double

    enum Phase: Sendable {
        case planning
        case decomposition
        case assignment
        case execution
        case integration
        case validation
        case complete
    }
}

// MARK: - Agent Task

struct AgentTask: Identifiable, Codable {
    let id: UUID
    let title: String
    let description: String
    let status: TaskStatus
    let createdAt: Date
    let completedAt: Date?
    let result: String?

    enum TaskStatus: String, Codable {
        case pending, inProgress, completed, failed
    }
}
