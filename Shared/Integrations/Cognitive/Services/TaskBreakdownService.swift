import Foundation

/// Service for AI-powered task breakdown
public actor TaskBreakdownService: TaskBreakdownServiceProtocol {
    private var breakdownHistory: [TaskBreakdown] = []

    public init() {}

    // MARK: - Task Breakdown

    public func breakdownTask(_ task: String) async throws -> TaskBreakdown {
        // In production, this would call an AI service (like PromptOptimizer)
        // For now, we'll create a structured breakdown based on task complexity

        let complexity = analyzeComplexity(task)
        let subtasks = generateSubtasks(for: task, complexity: complexity)
        let totalMinutes = subtasks.reduce(0) { $0 + $1.estimatedMinutes }

        let breakdown = TaskBreakdown(
            originalTask: task,
            subtasks: subtasks,
            estimatedTotalMinutes: totalMinutes,
            difficulty: complexity
        )

        breakdownHistory.insert(breakdown, at: 0)

        return breakdown
    }

    public func getBreakdownHistory(limit: Int = 20) async -> [TaskBreakdown] {
        Array(breakdownHistory.prefix(limit))
    }

    public func completeSubtask(breakdownId: UUID, subtaskId: UUID) async throws {
        guard let index = breakdownHistory.firstIndex(where: { $0.id == breakdownId }) else {
            throw CognitiveError.taskBreakdownFailed("Breakdown not found")
        }

        var breakdown = breakdownHistory[index]
        guard let subtaskIndex = breakdown.subtasks.firstIndex(where: { $0.id == subtaskId }) else {
            throw CognitiveError.taskBreakdownFailed("Subtask not found")
        }

        var updatedSubtasks = breakdown.subtasks
        updatedSubtasks[subtaskIndex] = CognitiveSubtask(
            id: updatedSubtasks[subtaskIndex].id,
            title: updatedSubtasks[subtaskIndex].title,
            description: updatedSubtasks[subtaskIndex].description,
            estimatedMinutes: updatedSubtasks[subtaskIndex].estimatedMinutes,
            order: updatedSubtasks[subtaskIndex].order,
            completed: true
        )

        breakdown = TaskBreakdown(
            id: breakdown.id,
            originalTask: breakdown.originalTask,
            subtasks: updatedSubtasks,
            estimatedTotalMinutes: breakdown.estimatedTotalMinutes,
            difficulty: breakdown.difficulty,
            createdAt: breakdown.createdAt
        )

        breakdownHistory[index] = breakdown
    }

    // MARK: - Private Helpers

    private func analyzeComplexity(_ task: String) -> TaskBreakdown.Difficulty {
        let wordCount = task.split(separator: " ").count

        // Simple heuristic based on task description length and keywords
        let complexityKeywords = ["implement", "design", "architecture", "system", "integrate"]
        let hasComplexKeywords = complexityKeywords.contains { task.lowercased().contains($0) }

        if wordCount > 20 || hasComplexKeywords {
            return .expert
        } else if wordCount > 15 {
            return .challenging
        } else if wordCount > 10 {
            return .moderate
        } else {
            return .easy
        }
    }

    private func generateSubtasks(for _: String, complexity: TaskBreakdown.Difficulty) -> [CognitiveSubtask] {
        // In production, this would use AI to generate context-aware subtasks
        // For now, we'll create a generic breakdown structure

        let baseSubtasks: [(String, String, Int)] = switch complexity {
        case .easy:
            [
                ("Research and Planning", "Gather information and plan approach", 10),
                ("Implementation", "Complete the main task", 20),
                ("Review and Testing", "Verify work is complete and correct", 10)
            ]
        case .moderate:
            [
                ("Requirements Analysis", "Clarify requirements and constraints", 15),
                ("Design Phase", "Plan the approach and design", 20),
                ("Implementation", "Execute the main work", 45),
                ("Testing", "Test and verify functionality", 20),
                ("Documentation", "Document the work done", 15)
            ]
        case .challenging:
            [
                ("Research", "Deep dive into requirements and context", 30),
                ("Architecture Design", "Design the overall structure", 45),
                ("Component 1 Implementation", "Build first major component", 60),
                ("Component 2 Implementation", "Build second major component", 60),
                ("Integration", "Integrate all components", 40),
                ("Testing & QA", "Comprehensive testing", 45),
                ("Documentation", "Write complete documentation", 30)
            ]
        case .expert:
            [
                ("Discovery & Research", "Comprehensive research phase", 60),
                ("Requirements Specification", "Document detailed requirements", 40),
                ("Architecture Design", "Design system architecture", 90),
                ("Proof of Concept", "Build and validate POC", 120),
                ("Core Implementation", "Implement core functionality", 180),
                ("Advanced Features", "Implement advanced features", 120),
                ("Integration Testing", "Test all integrations", 60),
                ("Performance Optimization", "Optimize performance", 60),
                ("Security Review", "Security audit and fixes", 45),
                ("Documentation", "Complete technical documentation", 60)
            ]
        }

        return baseSubtasks.enumerated().map { index, item in
            CognitiveSubtask(
                title: item.0,
                description: item.1,
                estimatedMinutes: item.2,
                order: index
            )
        }
    }
}
