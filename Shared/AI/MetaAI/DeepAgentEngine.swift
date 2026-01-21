import Foundation

// MARK: - Deep Agent Engine
// Advanced agentic AI with multi-step reasoning, verification, and self-correction
// Inspired by Abacus.ai Deep Agent capabilities

@MainActor
@Observable
final class DeepAgentEngine {
    static let shared = DeepAgentEngine()

    private(set) var activeTasks: [DeepTask] = []
    private(set) var taskHistory: [CompletedTask] = []
    private(set) var isProcessing = false

    private let subAgentOrchestrator = SubAgentOrchestrator.shared
    private let reasoningEngine = ReasoningEngine.shared
    private let toolRegistry = ToolRegistry.shared

    // Configuration accessor
    private var config: AgentConfiguration {
        AppConfiguration.shared.agentConfig
    }

    private init() {}

    // MARK: - Task Execution

    func executeTask(_ instruction: String, context: TaskContext = TaskContext()) async throws -> TaskResult {
        isProcessing = true
        defer { isProcessing = false }

        // Create task
        let task = DeepTask(
            id: UUID(),
            instruction: instruction,
            context: context,
            startTime: Date()
        )
        activeTasks.append(task)

        do {
            // 1. Plan: Break down into subtasks
            let plan = try await planTask(instruction, context: context)

            // 2. Execute with verification
            let results = try await executeWithVerification(plan: plan, context: context)

            // 3. Synthesize final result
            let finalResult = try await synthesizeResults(results, originalInstruction: instruction)

            // 4. Record success
            let completedTask = CompletedTask(
                task: task,
                result: finalResult,
                endTime: Date(),
                success: true
            )
            taskHistory.append(completedTask)
            activeTasks.removeAll { $0.id == task.id }

            return finalResult
        } catch {
            // Self-correction attempt
            if context.retryCount < config.maxRetryCount {
                var newContext = context
                newContext.retryCount += 1
                newContext.previousError = error.localizedDescription

                return try await executeTask(instruction, context: newContext)
            }

            // Record failure
            let completedTask = CompletedTask(
                task: task,
                result: TaskResult(
                    output: "",
                    success: false,
                    error: error.localizedDescription
                ),
                endTime: Date(),
                success: false
            )
            taskHistory.append(completedTask)
            activeTasks.removeAll { $0.id == task.id }

            throw error
        }
    }

    // MARK: - Task Planning

    private func planTask(_ instruction: String, context: TaskContext) async throws -> DeepTaskPlan {
        // Use reasoning engine to break down task
        _ = try await reasoningEngine.analyzeTask(instruction, context: context)

        // Determine task type and select appropriate strategy
        let taskType = classifyTask(instruction)
        let subtasks = try await decomposeTask(instruction, type: taskType, context: context)

        // Select tools for each subtask
        let subtasksWithTools = try await assignTools(to: subtasks)

        return DeepTaskPlan(
            originalInstruction: instruction,
            taskType: taskType,
            subtasks: subtasksWithTools,
            estimatedDuration: estimateDuration(for: subtasksWithTools),
            dependencies: extractDependencies(from: subtasksWithTools)
        )
    }

    private func classifyTask(_ instruction: String) -> TaskType {
        let lower = instruction.lowercased()

        if lower.contains("create") || lower.contains("build") || lower.contains("develop") {
            if lower.contains("app") || lower.contains("website") {
                return .appDevelopment
            } else if lower.contains("report") || lower.contains("presentation") {
                return .contentCreation
            } else if lower.contains("workflow") || lower.contains("automate") {
                return .workflowAutomation
            }
            return .creation
        }

        if lower.contains("analyze") || lower.contains("research") || lower.contains("study") {
            return .research
        }

        if lower.contains("search") || lower.contains("find") || lower.contains("lookup") {
            return .informationRetrieval
        }

        if lower.contains("code") || lower.contains("debug") || lower.contains("fix") {
            return .codeGeneration
        }

        if lower.contains("write") || lower.contains("compose") || lower.contains("draft") {
            return .contentCreation
        }

        return .general
    }

    private func decomposeTask(_ instruction: String, type: TaskType, context: TaskContext) async throws -> [Subtask] {
        switch type {
        case .appDevelopment:
            return [
                Subtask(step: 1, description: "Design application architecture and data models", dependencies: []),
                Subtask(step: 2, description: "Implement backend logic and APIs", dependencies: [1]),
                Subtask(step: 3, description: "Create user interface and styling", dependencies: [2]),
                Subtask(step: 4, description: "Add authentication and security", dependencies: [2]),
                Subtask(step: 5, description: "Test and debug application", dependencies: [3, 4]),
                Subtask(step: 6, description: "Deploy to production", dependencies: [5])
            ]

        case .research:
            return [
                Subtask(step: 1, description: "Define research scope and questions", dependencies: []),
                Subtask(step: 2, description: "Gather information from multiple sources", dependencies: [1]),
                Subtask(step: 3, description: "Analyze and synthesize findings", dependencies: [2]),
                Subtask(step: 4, description: "Generate structured report with citations", dependencies: [3])
            ]

        case .contentCreation:
            return [
                Subtask(step: 1, description: "Research topic and gather information", dependencies: []),
                Subtask(step: 2, description: "Create outline and structure", dependencies: [1]),
                Subtask(step: 3, description: "Write content sections", dependencies: [2]),
                Subtask(step: 4, description: "Add visuals and formatting", dependencies: [3]),
                Subtask(step: 5, description: "Review and refine", dependencies: [4])
            ]

        case .workflowAutomation:
            return [
                Subtask(step: 1, description: "Understand workflow requirements", dependencies: []),
                Subtask(step: 2, description: "Identify tools and integrations needed", dependencies: [1]),
                Subtask(step: 3, description: "Configure connections and permissions", dependencies: [2]),
                Subtask(step: 4, description: "Create automation logic", dependencies: [3]),
                Subtask(step: 5, description: "Test workflow execution", dependencies: [4])
            ]

        case .codeGeneration:
            return [
                Subtask(step: 1, description: "Understand requirements and constraints", dependencies: []),
                Subtask(step: 2, description: "Design solution architecture", dependencies: [1]),
                Subtask(step: 3, description: "Implement code", dependencies: [2]),
                Subtask(step: 4, description: "Add tests and documentation", dependencies: [3]),
                Subtask(step: 5, description: "Verify and optimize", dependencies: [4])
            ]

        case .informationRetrieval:
            return [
                Subtask(step: 1, description: "Parse query and identify key terms", dependencies: []),
                Subtask(step: 2, description: "Search relevant sources", dependencies: [1]),
                Subtask(step: 3, description: "Filter and rank results", dependencies: [2]),
                Subtask(step: 4, description: "Synthesize answer", dependencies: [3])
            ]

        case .creation, .general:
            // Use AI to dynamically decompose
            return try await dynamicDecomposition(instruction, context: context)

        case .simpleQA, .factual:
            return [
                Subtask(step: 1, description: "Parse question and identify key information needs", dependencies: []),
                Subtask(step: 2, description: "Retrieve relevant information", dependencies: [1]),
                Subtask(step: 3, description: "Formulate clear and accurate answer", dependencies: [2])
            ]

        case .complexReasoning, .analysis:
            return [
                Subtask(step: 1, description: "Break down problem into components", dependencies: []),
                Subtask(step: 2, description: "Analyze each component systematically", dependencies: [1]),
                Subtask(step: 3, description: "Synthesize findings and draw conclusions", dependencies: [2]),
                Subtask(step: 4, description: "Verify reasoning and validate conclusions", dependencies: [3])
            ]

        case .creativeWriting:
            return [
                Subtask(step: 1, description: "Understand creative brief and requirements", dependencies: []),
                Subtask(step: 2, description: "Brainstorm ideas and themes", dependencies: [1]),
                Subtask(step: 3, description: "Create initial draft", dependencies: [2]),
                Subtask(step: 4, description: "Refine style, voice, and tone", dependencies: [3]),
                Subtask(step: 5, description: "Polish and finalize", dependencies: [4])
            ]

        case .mathLogic:
            return [
                Subtask(step: 1, description: "Parse problem and identify mathematical concepts", dependencies: []),
                Subtask(step: 2, description: "Plan solution approach", dependencies: [1]),
                Subtask(step: 3, description: "Execute calculations step by step", dependencies: [2]),
                Subtask(step: 4, description: "Verify solution and check work", dependencies: [3])
            ]

        case .summarization:
            return [
                Subtask(step: 1, description: "Read and understand source material", dependencies: []),
                Subtask(step: 2, description: "Identify key points and themes", dependencies: [1]),
                Subtask(step: 3, description: "Condense into coherent summary", dependencies: [2]),
                Subtask(step: 4, description: "Ensure accuracy and completeness", dependencies: [3])
            ]

        case .planning:
            return [
                Subtask(step: 1, description: "Define goals and constraints", dependencies: []),
                Subtask(step: 2, description: "Research options and approaches", dependencies: [1]),
                Subtask(step: 3, description: "Create structured plan with milestones", dependencies: [2]),
                Subtask(step: 4, description: "Identify risks and mitigation strategies", dependencies: [3]),
                Subtask(step: 5, description: "Finalize timeline and deliverables", dependencies: [4])
            ]

        case .debugging:
            return [
                Subtask(step: 1, description: "Reproduce and understand the issue", dependencies: []),
                Subtask(step: 2, description: "Identify potential root causes", dependencies: [1]),
                Subtask(step: 3, description: "Test hypotheses systematically", dependencies: [2]),
                Subtask(step: 4, description: "Implement and verify fix", dependencies: [3]),
                Subtask(step: 5, description: "Document solution and prevention", dependencies: [4])
            ]
        }
    }

    private func dynamicDecomposition(_ instruction: String, context: TaskContext) async throws -> [Subtask] {
        // Use reasoning engine for custom decomposition
        let taskType = classifyTask(instruction)
        let subtaskDescriptions = try await reasoningEngine.decomposeTask(instruction, taskType: taskType, maxSteps: 10)

        return subtaskDescriptions.enumerated().map { index, description in
            Subtask(
                step: index + 1,
                description: description,
                dependencies: index > 0 ? [index] : []
            )
        }
    }

    private func assignTools(to subtasks: [Subtask]) async throws -> [SubtaskWithTools] {
        try await withThrowingTaskGroup(of: SubtaskWithTools.self) { group in
            for subtask in subtasks {
                group.addTask { @MainActor in
                    let tools = await self.toolRegistry.selectTools(for: subtask.description)
                    return SubtaskWithTools(subtask: subtask, tools: tools)
                }
            }

            var result: [SubtaskWithTools] = []
            for try await item in group {
                result.append(item)
            }
            return result.sorted { $0.subtask.step < $1.subtask.step }
        }
    }

    private func estimateDuration(for subtasks: [SubtaskWithTools]) -> TimeInterval {
        // Estimate based on complexity using configurable base time
        Double(subtasks.count) * config.baseTaskDurationSeconds
    }

    private func extractDependencies(from subtasks: [SubtaskWithTools]) -> [Int: [Int]] {
        var deps: [Int: [Int]] = [:]
        for item in subtasks {
            deps[item.subtask.step] = item.subtask.dependencies
        }
        return deps
    }

    // MARK: - Execution with Verification

    private func executeWithVerification(plan: DeepTaskPlan, context: TaskContext) async throws -> [SubtaskResult] {
        var results: [SubtaskResult] = []
        var completedSteps: Set<Int> = []

        for subtaskWithTools in plan.subtasks {
            let subtask = subtaskWithTools.subtask

            // Wait for dependencies
            try await waitForDependencies(subtask.dependencies, completed: completedSteps)

            // Execute subtask
            let result = try await executeSubtask(subtaskWithTools, context: context, previousResults: results)

            // Verify result
            let verification = try await verifyResult(result, subtask: subtask)

            if verification.isValid {
                results.append(result)
                completedSteps.insert(subtask.step)
            } else {
                // Self-correction
                let corrected = try await selfCorrect(
                    subtask: subtaskWithTools,
                    failedResult: result,
                    verification: verification,
                    context: context
                )
                results.append(corrected)
                completedSteps.insert(subtask.step)
            }
        }

        return results
    }

    private func waitForDependencies(_ dependencies: [Int], completed: Set<Int>) async throws {
        // Simple wait - in production would use proper async coordination
        while !dependencies.allSatisfy({ completed.contains($0) }) {
            try await Task.sleep(nanoseconds: config.dependencyWaitIntervalMs)
        }
    }

    private func executeSubtask(_ subtaskWithTools: SubtaskWithTools, context: TaskContext, previousResults: [SubtaskResult]) async throws -> SubtaskResult {
        let startTime = Date()

        // Execute using selected tools
        var output = ""
        for tool in subtaskWithTools.tools {
            let toolResult = try await tool.execute(
                input: subtaskWithTools.subtask.description,
                context: context,
                previousResults: previousResults
            )
            output += toolResult + "\n"
        }

        return SubtaskResult(
            subtask: subtaskWithTools.subtask,
            output: output,
            success: true,
            executionTime: Date().timeIntervalSince(startTime),
            toolsUsed: subtaskWithTools.tools
        )
    }

    private func verifyResult(_ result: SubtaskResult, subtask: Subtask) async throws -> VerificationResult {
        // Use reasoning engine to verify
        let verification = try await reasoningEngine.verifyOutput(result.output, expectedCriteria: [subtask.description])

        return VerificationResult(
            isValid: verification.isValid,
            confidence: verification.confidence,
            issues: verification.issues
        )
    }

    private func selfCorrect(subtask: SubtaskWithTools, failedResult: SubtaskResult, verification: VerificationResult, context: TaskContext) async throws -> SubtaskResult {
        // Attempt correction with different tools or approach
        var newContext = context

        // Convert SubtaskResult to SubtaskResultSnapshot for tracking
        let snapshot = SubtaskResultSnapshot(
            step: failedResult.subtask.step,
            output: failedResult.output,
            success: failedResult.success,
            executionTime: failedResult.executionTime
        )
        newContext.previousAttempts.append(snapshot)
        newContext.verificationIssues = verification.issues

        // Retry with refined approach
        return try await executeSubtask(subtask, context: newContext, previousResults: [])
    }

    // MARK: - Result Synthesis

    private func synthesizeResults(_ results: [SubtaskResult], originalInstruction: String) async throws -> TaskResult {
        // Combine all outputs intelligently
        let outputs = results.map { $0.output }

        // Use reasoning to create coherent final result
        let synthesis = try await reasoningEngine.synthesize(outputs, instruction: originalInstruction)

        return TaskResult(
            output: synthesis,
            success: true,
            subtaskResults: results,
            totalDuration: results.reduce(0) { $0 + $1.executionTime }
        )
    }
}

// MARK: - Data Structures

struct DeepTask: Identifiable {
    let id: UUID
    let instruction: String
    let context: TaskContext
    let startTime: Date
}

private struct DeepAgentTaskContext: @unchecked Sendable {
    var retryCount: Int = 0
    var previousError: String?
    var previousAttempts: [SubtaskResult] = []
    var verificationIssues: [String] = []
    var userPreferences: [String: Any] = [:]
}

private enum DeepAgentTaskType {
    case appDevelopment
    case research
    case contentCreation
    case workflowAutomation
    case codeGeneration
    case informationRetrieval
    case creation
    case general
}

struct DeepTaskPlan {
    let originalInstruction: String
    let taskType: TaskType
    let subtasks: [SubtaskWithTools]
    let estimatedDuration: TimeInterval
    let dependencies: [Int: [Int]]
}

struct Subtask {
    let step: Int
    let description: String
    let dependencies: [Int]
}

struct SubtaskWithTools {
    let subtask: Subtask
    let tools: [DeepTool]
}

struct SubtaskResult {
    let subtask: Subtask
    let output: String
    let success: Bool
    let executionTime: TimeInterval
    let toolsUsed: [DeepTool]
}

struct VerificationResult {
    let isValid: Bool
    let confidence: Double
    let issues: [String]
}

struct TaskResult {
    let output: String
    let success: Bool
    var error: String?
    var subtaskResults: [SubtaskResult] = []
    var totalDuration: TimeInterval = 0
}

struct CompletedTask {
    let task: DeepTask
    let result: TaskResult
    let endTime: Date
    let success: Bool
}

// MARK: - Deep Tool Protocol

protocol DeepTool: Sendable {
    var name: String { get }
    var description: String { get }
    var capabilities: [String] { get }

    func execute(input: String, context: TaskContext, previousResults: [SubtaskResult]) async throws -> String
}

// Concrete empty tool for compatibility
struct EmptyDeepTool: DeepTool {
    let name = "empty"
    let description = "Placeholder tool"
    let capabilities: [String] = []

    func execute(input: String, context: TaskContext, previousResults: [SubtaskResult]) async throws -> String {
        ""
    }
}

// MARK: - Tool Registry

@MainActor
@Observable
final class ToolRegistry {
    static let shared = ToolRegistry()

    private var registeredTools: [DeepTool] = []

    private init() {
        registerDefaultTools()
    }

    private func registerDefaultTools() {
        // Register built-in tools
        // In production, this would include:
        // - File operations
        // - Web search
        // - Code execution
        // - Database operations
        // - API integrations
        // - etc.
        registeredTools.append(EmptyDeepTool())
    }

    func registerTool(_ tool: DeepTool) {
        registeredTools.append(tool)
    }

    func selectTools(for task: String) async -> [DeepTool] {
        // Use AI to select optimal tools
        // For now, return empty tool
        [EmptyDeepTool()]
    }

    func getAllTools() -> [DeepTool] {
        registeredTools
    }
}
