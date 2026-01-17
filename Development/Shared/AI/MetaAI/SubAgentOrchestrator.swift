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
                return "You are an expert software engineer. You write clean, efficient, well-documented code following best practices. You can work in any programming language."
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
        return plan.steps.enumerated().map { index, step in
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
        return subTasks.map { subTask in
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

            let batchResults = try await withThrowingTaskGroup(of: SubTaskResult.self) { group in
                for assignment in batch {
                    group.addTask {
                        try await self.executeSubTask(assignment)
                    }
                }

                var collected: [SubTaskResult] = []
                for try await result in group {
                    collected.append(result)
                }
                return collected
            }

            results.append(contentsOf: batchResults)
        }

        return results
    }

    private func executeSubTask(_ assignment: AgentAssignment) async throws -> SubTaskResult {
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
        return planText.split(separator: "\n")
            .filter { $0.contains("Step") || $0.contains(".") }
            .map { String($0) }
    }

    private func extractCriteria(from planText: String) -> [String] {
        return ["Output is complete", "Output is accurate", "Output meets requirements"]
    }

    private func calculatePriority(step: Int, total: Int) -> Int {
        return total - step
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
