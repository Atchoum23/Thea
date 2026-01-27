// TaskDecomposition.swift
import Foundation

/// Advanced task decomposition for complex multi-step reasoning.
/// Builds dependency graphs and determines optimal execution order.
@MainActor
@Observable
public final class TaskDecomposition {
    public static let shared = TaskDecomposition()

    private let config = OrchestratorConfiguration.load()
    private let classifier = TaskClassifier.shared

    private init() {}

    // MARK: - Public API

    /// Decompose a task into steps with dependencies
    public func decompose(
        _ task: String,
        context: [String: Any] = [:]
    ) async throws -> OrchestrationTaskBreakdown {
        // 1. Classify task type
        let classification = try await classifier.classify(task)

        // 2. Assess decomposition depth needed
        let depth = assessDecompositionDepth(task, classification: classification)

        // 3. Perform decomposition
        let steps = try await decomposeIntoSteps(
            task,
            classification: classification,
            depth: depth,
            context: context
        )

        // 4. Build dependency graph
        let graph = buildDependencyGraph(steps)

        // 5. Determine execution order
        let executionOrder = topologicalSort(graph)

        return OrchestrationTaskBreakdown(
            originalTask: task,
            taskType: classification.primaryType,
            steps: steps,
            dependencyGraph: graph,
            executionOrder: executionOrder,
            estimatedComplexity: depth
        )
    }

    // MARK: - Decomposition Logic

    private func assessDecompositionDepth(
        _ task: String,
        classification: TaskClassification
    ) -> Int {
        let wordCount = task.split(separator: " ").count

        // Determine decomposition depth based on task type and length
        switch classification.primaryType {
        case .simpleQA, .factual:
            return 1 // No decomposition needed

        case .summarization:
            return wordCount > 200 ? 2 : 1

        case .codeGeneration:
            return wordCount > 50 ? 3 : 2

        case .complexReasoning, .analysis, .planning:
            return wordCount > 100 ? 4 : 3

        case .debugging:
            return 3

        case .creativeWriting:
            return wordCount > 150 ? 3 : 2

        case .mathLogic:
            return 2

        default:
            return wordCount > 100 ? 3 : 2
        }
    }

    private func decomposeIntoSteps(
        _ task: String,
        classification: TaskClassification,
        depth: Int,
        context _: [String: Any]
    ) async throws -> [TaskStep] {
        // For simple tasks, return single step
        if depth == 1 {
            return [
                TaskStep(
                    id: UUID(),
                    description: task,
                    taskType: classification.primaryType,
                    dependencies: [],
                    estimatedDuration: 5.0
                )
            ]
        }

        // For complex tasks, decompose based on type
        return try await decomposeByType(
            task,
            classification: classification,
            depth: depth
        )
    }

    private func decomposeByType(
        _ task: String,
        classification: TaskClassification,
        depth: Int
    ) async throws -> [TaskStep] {
        switch classification.primaryType {
        case .codeGeneration:
            decomposeCodeTask(task)

        case .complexReasoning:
            decomposeReasoningTask(task)

        case .analysis:
            decomposeAnalysisTask(task)

        case .planning:
            decomposePlanningTask(task)

        case .debugging:
            decomposeDebuggingTask(task)

        default:
            // Generic decomposition
            decomposeGenericTask(task, depth: depth)
        }
    }

    // MARK: - Type-Specific Decomposition

    private func decomposeCodeTask(_ task: String) -> [TaskStep] {
        var steps: [TaskStep] = []

        // Step 1: Understand requirements
        let step1 = TaskStep(
            id: UUID(),
            description: "Analyze requirements: \(task)",
            taskType: .analysis,
            dependencies: [],
            estimatedDuration: 2.0
        )
        steps.append(step1)

        // Step 2: Design solution
        let step2 = TaskStep(
            id: UUID(),
            description: "Design solution approach",
            taskType: .planning,
            dependencies: [step1.id],
            estimatedDuration: 3.0
        )
        steps.append(step2)

        // Step 3: Implement code
        let step3 = TaskStep(
            id: UUID(),
            description: "Implement code solution",
            taskType: .codeGeneration,
            dependencies: [step2.id],
            estimatedDuration: 10.0
        )
        steps.append(step3)

        // Step 4: Review and test
        let step4 = TaskStep(
            id: UUID(),
            description: "Review code and test functionality",
            taskType: .debugging,
            dependencies: [step3.id],
            estimatedDuration: 5.0
        )
        steps.append(step4)

        return steps
    }

    private func decomposeReasoningTask(_ task: String) -> [TaskStep] {
        var steps: [TaskStep] = []

        let step1 = TaskStep(
            id: UUID(),
            description: "Gather relevant information",
            taskType: .factual,
            dependencies: [],
            estimatedDuration: 3.0
        )
        steps.append(step1)

        let step2 = TaskStep(
            id: UUID(),
            description: "Analyze and reason about: \(task)",
            taskType: .complexReasoning,
            dependencies: [step1.id],
            estimatedDuration: 8.0
        )
        steps.append(step2)

        let step3 = TaskStep(
            id: UUID(),
            description: "Validate reasoning and conclusions",
            taskType: .analysis,
            dependencies: [step2.id],
            estimatedDuration: 3.0
        )
        steps.append(step3)

        return steps
    }

    private func decomposeAnalysisTask(_ task: String) -> [TaskStep] {
        var steps: [TaskStep] = []

        let step1 = TaskStep(
            id: UUID(),
            description: "Collect data for analysis",
            taskType: .factual,
            dependencies: [],
            estimatedDuration: 3.0
        )
        steps.append(step1)

        let step2 = TaskStep(
            id: UUID(),
            description: "Perform analysis: \(task)",
            taskType: .analysis,
            dependencies: [step1.id],
            estimatedDuration: 7.0
        )
        steps.append(step2)

        let step3 = TaskStep(
            id: UUID(),
            description: "Generate insights and recommendations",
            taskType: .planning,
            dependencies: [step2.id],
            estimatedDuration: 4.0
        )
        steps.append(step3)

        return steps
    }

    private func decomposePlanningTask(_ task: String) -> [TaskStep] {
        var steps: [TaskStep] = []

        let step1 = TaskStep(
            id: UUID(),
            description: "Define goals and constraints",
            taskType: .analysis,
            dependencies: [],
            estimatedDuration: 2.0
        )
        steps.append(step1)

        let step2 = TaskStep(
            id: UUID(),
            description: "Identify possible approaches",
            taskType: .complexReasoning,
            dependencies: [step1.id],
            estimatedDuration: 5.0
        )
        steps.append(step2)

        let step3 = TaskStep(
            id: UUID(),
            description: "Create detailed plan for: \(task)",
            taskType: .planning,
            dependencies: [step2.id],
            estimatedDuration: 6.0
        )
        steps.append(step3)

        return steps
    }

    private func decomposeDebuggingTask(_ task: String) -> [TaskStep] {
        var steps: [TaskStep] = []

        let step1 = TaskStep(
            id: UUID(),
            description: "Reproduce and understand the issue",
            taskType: .analysis,
            dependencies: [],
            estimatedDuration: 3.0
        )
        steps.append(step1)

        let step2 = TaskStep(
            id: UUID(),
            description: "Identify root cause",
            taskType: .debugging,
            dependencies: [step1.id],
            estimatedDuration: 7.0
        )
        steps.append(step2)

        let step3 = TaskStep(
            id: UUID(),
            description: "Implement fix for: \(task)",
            taskType: .codeGeneration,
            dependencies: [step2.id],
            estimatedDuration: 5.0
        )
        steps.append(step3)

        let step4 = TaskStep(
            id: UUID(),
            description: "Verify fix and test",
            taskType: .debugging,
            dependencies: [step3.id],
            estimatedDuration: 3.0
        )
        steps.append(step4)

        return steps
    }

    private func decomposeGenericTask(_ task: String, depth: Int) -> [TaskStep] {
        // Simple sequential decomposition
        var steps: [TaskStep] = []

        for i in 0 ..< depth {
            let previousID = i > 0 ? steps[i - 1].id : nil

            let step = TaskStep(
                id: UUID(),
                description: "Step \(i + 1) of \(depth): \(task)",
                taskType: .simpleQA,
                dependencies: previousID.map { [$0] } ?? [],
                estimatedDuration: 5.0
            )
            steps.append(step)
        }

        return steps
    }

    // MARK: - Graph Operations

    private func buildDependencyGraph(_ steps: [TaskStep]) -> DependencyGraph {
        var graph = DependencyGraph()

        for step in steps {
            graph.addNode(step.id, data: step)

            for dependencyID in step.dependencies {
                graph.addEdge(from: dependencyID, to: step.id)
            }
        }

        return graph
    }

    private func topologicalSort(_ graph: DependencyGraph) -> [UUID] {
        var _: [UUID] = []
        var visited = Set<UUID>()
        var stack: [UUID] = []

        func visit(_ nodeID: UUID) {
            if visited.contains(nodeID) { return }
            visited.insert(nodeID)

            if let children = graph.adjacencyList[nodeID] {
                for childID in children {
                    visit(childID)
                }
            }

            stack.append(nodeID)
        }

        for nodeID in graph.nodes.keys {
            visit(nodeID)
        }

        return stack.reversed()
    }
}

// MARK: - Supporting Types

/// Task breakdown result
public struct OrchestrationTaskBreakdown {
    public let originalTask: String
    public let taskType: TaskType
    public let steps: [TaskStep]
    public let dependencyGraph: DependencyGraph
    public let executionOrder: [UUID]
    public let estimatedComplexity: Int

    /// Get total estimated duration
    public var estimatedDuration: TimeInterval {
        steps.reduce(0) { $0 + $1.estimatedDuration }
    }

    /// Get steps that can be executed in parallel
    public func getParallelSteps(completed: Set<UUID>) -> [TaskStep] {
        steps.filter { step in
            !completed.contains(step.id) &&
                step.dependencies.allSatisfy { completed.contains($0) }
        }
    }
}

/// Individual task step
public struct TaskStep: Identifiable {
    public let id: UUID
    public let description: String
    public let taskType: TaskType
    public let dependencies: [UUID]
    public let estimatedDuration: TimeInterval

    /// Check if step can be executed
    public func canExecute(completed: Set<UUID>) -> Bool {
        dependencies.allSatisfy { completed.contains($0) }
    }
}

/// Dependency graph
public struct DependencyGraph {
    public var nodes: [UUID: TaskStep] = [:]
    public var adjacencyList: [UUID: [UUID]] = [:] // nodeID -> [children]

    mutating func addNode(_ id: UUID, data: TaskStep) {
        nodes[id] = data
        if adjacencyList[id] == nil {
            adjacencyList[id] = []
        }
    }

    mutating func addEdge(from parentID: UUID, to childID: UUID) {
        if adjacencyList[parentID] == nil {
            adjacencyList[parentID] = []
        }
        adjacencyList[parentID]?.append(childID)
    }

    /// Get children of a node
    public func getChildren(_ nodeID: UUID) -> [UUID] {
        adjacencyList[nodeID] ?? []
    }

    /// Get parents of a node
    public func getParents(_ nodeID: UUID) -> [UUID] {
        adjacencyList.compactMap { parentID, children in
            children.contains(nodeID) ? parentID : nil
        }
    }

    /// Check if graph is acyclic (no circular dependencies)
    public func isAcyclic() -> Bool {
        var visited = Set<UUID>()
        var stack = Set<UUID>()

        func hasCycle(_ nodeID: UUID) -> Bool {
            if stack.contains(nodeID) { return true }
            if visited.contains(nodeID) { return false }

            visited.insert(nodeID)
            stack.insert(nodeID)

            for childID in getChildren(nodeID) {
                if hasCycle(childID) {
                    return true
                }
            }

            stack.remove(nodeID)
            return false
        }

        for nodeID in nodes.keys {
            if hasCycle(nodeID) {
                return false
            }
        }

        return true
    }
}
