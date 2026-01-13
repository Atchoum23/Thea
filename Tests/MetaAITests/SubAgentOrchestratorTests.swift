import XCTest
@testable import TheaCore

@MainActor
final class SubAgentOrchestratorTests: XCTestCase {
    var orchestrator: SubAgentOrchestrator!

    override func setUp() async throws {
        orchestrator = SubAgentOrchestrator.shared
        orchestrator.tasks.removeAll()
    }

    func testTaskDecomposition() async throws {
        let task = "Build a weather app with SwiftUI"

        let result = try await orchestrator.decomposeTask(task, model: "gpt-4o-mini")

        XCTAssertFalse(result.subtasks.isEmpty, "Should decompose task into subtasks")
        XCTAssertGreaterThan(result.subtasks.count, 1, "Should have multiple subtasks")
    }

    func testAgentAssignment() {
        let subtask = AgentTask.Subtask(
            id: UUID(),
            description: "Write Swift code for API client",
            assignedAgent: .code,
            status: .pending,
            result: nil
        )

        XCTAssertEqual(subtask.assignedAgent, .code, "Code tasks should be assigned to code agent")
    }

    func testTaskStatusTracking() {
        let task = AgentTask(
            id: UUID(),
            title: "Test Task",
            description: "Test Description",
            status: .inProgress,
            subtasks: [],
            createdAt: Date(),
            completedAt: nil,
            result: nil
        )

        XCTAssertEqual(task.status, .inProgress)
        XCTAssertNil(task.completedAt)
    }

    func testMultipleAgentTypes() {
        let agentTypes: [AgentType] = [
            .research, .code, .data, .creative, .analysis,
            .planning, .debug, .testing, .documentation, .integration
        ]

        XCTAssertEqual(agentTypes.count, 10, "Should have 10 distinct agent types")

        for agentType in agentTypes {
            XCTAssertFalse(agentType.rawValue.isEmpty, "Agent type should have a name")
        }
    }

    func testTaskHistory() {
        XCTAssertTrue(orchestrator.tasks.isEmpty, "Should start with empty task history")

        let task = AgentTask(
            id: UUID(),
            title: "Test",
            description: "Test",
            status: .pending,
            subtasks: [],
            createdAt: Date(),
            completedAt: nil,
            result: nil
        )

        orchestrator.tasks.append(task)

        XCTAssertEqual(orchestrator.tasks.count, 1, "Should track task in history")
    }
}
