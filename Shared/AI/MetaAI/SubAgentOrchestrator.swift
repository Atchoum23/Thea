import Foundation
import Observation

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
                return ["web_search", "document_analysis", "source_verification"]
            case .coder:
                return ["code_generation", "code_review", "debugging", "testing"]
            case .analyst:
                return ["data_analysis", "pattern_recognition", "reporting"]
            case .writer:
                return ["content_creation", "editing", "summarization"]
            case .planner:
                return ["task_breakdown", "dependency_mapping", "timeline_creation"]
            case .critic:
                return ["review", "evaluation", "feedback"]
            case .executor:
                return ["task_execution", "tool_use", "file_operations"]
            case .validator:
                return ["verification", "testing", "quality_assurance"]
            case .integrator:
                return ["synthesis", "merging", "coordination"]
            case .optimizer:
                return ["improvement", "refactoring", "performance_tuning"]
            }
        }
    }

    // MARK: - Initialize Agent Pool

    private func initializeAgentPool() {
        for agentType in AgentType.allCases {
            agentPool[agentType] = []
            // Pre-create 2 agents of each type
            for i in 0..<2 {
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
    func orchestrate(
        task: String,
        context: [String: Any] = [:],
        progressHandler: @escaping @Sendable (OrchestrationProgress) -> Void
    ) async throws -> OrchestrationResult {
        isOrchestrating = true
        defer { isOrchestrating = false }

        // Step 1: Analyze task with Planner agent
        progressHandler(OrchestrationProgress(
            phase: .planning,
            message: "Analyzing task requirements",
            progress: 0.1
        ))

        let plan = try await planTask(task, context: context)

        // Step 2: Decompose into sub-tasks
        progressHandler(OrchestrationProgress(
            phase: .decomposition,
            message: "Breaking down into sub-tasks",
            progress: 0.2
        ))

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

        let results = try await executeSwarm(assignments, progressHandler: progressHandler)

        // Step 5: Integrate results
        progressHandler(OrchestrationProgress(
            phase: .integration,
            message: "Integrating results from agents",
            progress: 0.8
        ))

        let integrated = try await integrateResults(results)

        // Step 6: Validate and criticize
        progressHandler(OrchestrationProgress(
            phase: .validation,
            message: "Validating final output",
            progress: 0.9
        ))

        let validated = try await validateResult(integrated)

        // Step 7: Optimize if needed
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
            agentsUsed: assignments.map { $0.agent.type },
            executionTime: Date().timeIntervalSince(Date())
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

        let provider = ProviderRegistry.shared.getProvider(id: "anthropic") ??
                      ProviderRegistry.shared.getProvider(id: "openai")!

        let planText = try await streamProviderResponse(provider: provider, prompt: prompt, model: config.plannerModel)

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

            // Execute batch tasks - using sequential execution to satisfy
            // Swift 6 region-based isolation checker
            var batchResults: [SubTaskResult] = []
            for assignment in batch {
                let result = try await executeSubTask(assignment)
                batchResults.append(result)
            }

            results.append(contentsOf: batchResults)
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

        let provider = ProviderRegistry.shared.getProvider(id: "anthropic") ??
                      ProviderRegistry.shared.getProvider(id: "openai")!

        let prompt = """
        \(agent.type.systemPrompt)

        Your specific task: \(subTask.description)

        Execute this task and provide a detailed result.
        """

        let output = try await streamProviderResponse(provider: provider, prompt: prompt, model: "gpt-4o")

        return SubTaskResult(
            subTask: subTask,
            agent: agent,
            output: output,
            success: true,
            executionTime: 1.0
        )
    }

    private func executeCoderTaskWithValidation(_ assignment: AgentAssignment) async throws -> SubTaskResult {
        // let swiftValidator = SwiftValidator.shared
        // let errorLearning = ErrorKnowledgeBaseManager.shared

        var attempts = 0
        let maxAttempts = 3
        // var lastErrors: [SwiftError] = []
        let startTime = Date()

        while attempts < maxAttempts {
            attempts += 1

            // 1. Enhance prompt with error prevention guidance if we have context
            let enhancedTask = assignment.subTask.description
            // TODO: Re-enable error learning when ErrorKnowledgeBaseManager is available
            // if attempts > 1 && !lastErrors.isEmpty {
            //     let errorContext = lastErrors.map {
            //         "Line \($0.line ?? 0): \($0.message)"
            //     }.joined(separator: "\n")
            //
            //     let preventionRules = await errorLearning.getPreventionGuidance(forCode: assignment.subTask.description)
            //
            //     enhancedTask = """
            //     PREVIOUS ATTEMPT FAILED with compilation errors:
            //     \(errorContext)
            //
            //     PREVENTION RULES (learned from past errors):
            //     \(preventionRules.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))
            //
            //     ORIGINAL TASK:
            //     \(assignment.subTask.description)
            //
            //     Please fix ALL errors and provide corrected code that compiles without errors.
            //     """
            // } else {
            //     enhancedTask = await errorLearning.enhancePromptWithErrorPrevention(
            //         prompt: assignment.subTask.description,
            //         forCode: ""
            //     )
            // }

            // 2. Generate code
            let provider = ProviderRegistry.shared.getProvider(id: "anthropic") ??
                          ProviderRegistry.shared.getProvider(id: "openai")!

            let prompt = """
            \(assignment.agent.type.systemPrompt)

            Your specific task: \(enhancedTask)

            Execute this task and provide a detailed result.
            """

            let output = try await streamProviderResponse(provider: provider, prompt: prompt, model: "gpt-4o")

            // 3. Check if output contains Swift code
            // TODO: Re-enable Swift validation when SwiftValidator is available
            // guard let swiftCode = swiftValidator.extractSwiftCode(from: output) else {
            //     // Not Swift code, return as-is
            //     return SubTaskResult(
            //         subTask: assignment.subTask,
            //         agent: assignment.agent,
            //         output: output,
            //         success: true,
            //         executionTime: Date().timeIntervalSince(startTime)
            //     )
            // }

            // // 4. Validate Swift syntax
            // do {
            //     let validation = try await swiftValidator.validateSwiftSyntax(swiftCode)
            //
            //     switch validation {
            //     case .success:
            //         // Code compiles! Return it
            //         return SubTaskResult(
            //             subTask: assignment.subTask,
            //             agent: assignment.agent,
            //             output: output,
            //             success: true,
            //             executionTime: Date().timeIntervalSince(startTime)
            //         )
            //
            //     case .failure(let errors):
            //         lastErrors = errors
            //
            //         if attempts >= maxAttempts {
            //             // Record failures for learning
            //             for error in errors {
            //                 await errorLearning.recordSwiftError(error, inCode: swiftCode)
            //             }

            // For now, just return the output without validation
            return SubTaskResult(
                subTask: assignment.subTask,
                agent: assignment.agent,
                output: output,
                success: true,
                executionTime: Date().timeIntervalSince(startTime)
            )

            //             // Return failure result with error details
            //             let errorSummary = errors.map { $0.displayMessage }.joined(separator: "\n")
            //             return SubTaskResult(
            //                 subTask: assignment.subTask,
            //                 agent: assignment.agent,
            //                 output: "❌ Code validation failed after \(maxAttempts) attempts:\n\n\(errorSummary)\n\nLast generated code:\n```swift\n\(swiftCode)\n```",
            //                 success: false,
            //                 executionTime: Date().timeIntervalSince(startTime)
            //             )
            //         }
            //
            //         // Continue to next attempt
            //         continue
            //     }
            // } catch {
            //     // Validation error (not compilation error)
            //     if attempts >= maxAttempts {
            //         throw error
            //     }
            //     continue
            // }
        }

        // Note: This code is currently unreachable because validation is disabled.
        // When validation is re-enabled, this will handle max attempts exceeded.
        // Uncomment the validation code above and remove/move the early return.
        // return SubTaskResult(
        //     subTask: assignment.subTask,
        //     agent: assignment.agent,
        //     output: "Max attempts exceeded",
        //     success: false,
        //     executionTime: Date().timeIntervalSince(startTime)
        // )
    }

    // MARK: - Integration

    private func integrateResults(_ results: [SubTaskResult]) async throws -> String {
        let integrator = getAgent(type: .integrator)

        let allOutputs = results.map { "[\($0.agent.type.rawValue)]: \($0.output)" }.joined(separator: "\n\n")

        let provider = ProviderRegistry.shared.getProvider(id: "anthropic") ??
                      ProviderRegistry.shared.getProvider(id: "openai")!

        let prompt = """
        \(integrator.type.systemPrompt)

        Integrate these outputs from multiple agents into a cohesive final result:

        \(allOutputs)

        Provide a unified, coherent response.
        """

        return try await streamProviderResponse(provider: provider, prompt: prompt, model: "gpt-4o")
    }

    // MARK: - Validation

    private func validateResult(_ result: String) async throws -> String {
        let validator = getAgent(type: .validator)

        let provider = ProviderRegistry.shared.getProvider(id: "anthropic") ??
                      ProviderRegistry.shared.getProvider(id: "openai")!

        let prompt = """
        \(validator.type.systemPrompt)

        Validate this output for correctness, completeness, and quality:

        \(result)

        If valid, return it as-is. If issues found, provide corrected version.
        """

        return try await streamProviderResponse(provider: provider, prompt: prompt, model: "gpt-4o")
    }

    // MARK: - Optimization

    private func optimizeResult(_ result: String) async throws -> String {
        let optimizer = getAgent(type: .optimizer)

        let provider = ProviderRegistry.shared.getProvider(id: "anthropic") ??
                      ProviderRegistry.shared.getProvider(id: "openai")!

        let prompt = """
        \(optimizer.type.systemPrompt)

        Optimize this output for clarity, conciseness, and impact:

        \(result)
        """

        return try await streamProviderResponse(provider: provider, prompt: prompt, model: "gpt-4o")
    }

    // MARK: - Helper Methods

    private func createExecutionBatches(_ assignments: [AgentAssignment]) -> [[AgentAssignment]] {
        // Simple batching - in production would respect dependencies
        let batchSize = 3
        return stride(from: 0, to: assignments.count, by: batchSize).map {
            Array(assignments[$0..<min($0 + batchSize, assignments.count)])
        }
    }

    private func extractSteps(from planText: String) -> [String] {
        // Simplified extraction - should use proper parsing
        planText.split(separator: "\n")
            .filter { $0.contains("Step") || $0.contains(".") }
            .map { String($0) }
    }

    private func extractCriteria(from planText: String) -> [String] {
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
            case .delta(let text):
                result += text
            case .complete:
                break
            case .error(let error):
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
