// SubagentTypesTests.swift
// Tests for SubagentTask, EnhancedSubagentResult, SubagentAggregatedResult,
// IntelligenceTaskResult, OrchestratorError, and supporting types

import Foundation
import XCTest

// MARK: - Mirrored: TaskPriority

private enum TestTaskPriority: Int, Comparable, CaseIterable {
    case low = 0
    case normal = 50
    case high = 75
    case critical = 100

    static func < (lhs: TestTaskPriority, rhs: TestTaskPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Mirrored: OutputRequirement

private enum TestOutputRequirement: String, CaseIterable {
    case text, json, code, markdown, structured
}

// MARK: - Mirrored: EnhancedResultStatus

private enum TestResultStatus: String, CaseIterable {
    case success, partialSuccess, failed, timeout, cancelled

    var isSuccess: Bool {
        self == .success || self == .partialSuccess
    }
}

// MARK: - Mirrored: AggregationStrategy

private enum TestAggregationStrategy: String, CaseIterable {
    case merge, consensus, bestConfidence, sequential, custom
}

// MARK: - Mirrored: IntelligenceTaskResultStatus

private enum TestIntelligenceResultStatus: String, CaseIterable {
    case completed, failed, cancelled, inProgress

    var isTerminal: Bool {
        self == .completed || self == .failed || self == .cancelled
    }
}

// MARK: - Mirrored: ToolUsage

private struct TestToolUsage {
    let name: String
    let input: String
    let output: String
    let success: Bool
}

// MARK: - Mirrored: OrchestratorError

private enum TestOrchestratorError: Error, LocalizedError {
    case contextPreparationFailed(String)
    case skillLoadingFailed(String)
    case knowledgeLoadingFailed(String)
    case taskCompletionFailed(String)

    var errorDescription: String? {
        switch self {
        case .contextPreparationFailed(let msg): "Context preparation failed: \(msg)"
        case .skillLoadingFailed(let msg): "Skill loading failed: \(msg)"
        case .knowledgeLoadingFailed(let msg): "Knowledge loading failed: \(msg)"
        case .taskCompletionFailed(let msg): "Task completion failed: \(msg)"
        }
    }
}

// MARK: - Mirrored: SubagentTask

private struct TestSubagentTask: Identifiable {
    let id: UUID
    let parentTaskId: UUID?
    let agentType: String
    let description: String
    let input: String
    let priority: TestTaskPriority
    let timeout: TimeInterval
    let maxTokens: Int
    let requiredOutput: TestOutputRequirement
    let dependsOn: [UUID]

    init(
        id: UUID = UUID(),
        parentTaskId: UUID? = nil,
        agentType: String = "generalPurpose",
        description: String,
        input: String,
        priority: TestTaskPriority = .normal,
        timeout: TimeInterval = 60,
        maxTokens: Int = 4096,
        requiredOutput: TestOutputRequirement = .text,
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
}

// MARK: - Mirrored: EnhancedSubagentResult

private struct TestSubagentResult: Identifiable {
    let id: UUID
    let taskId: UUID
    let agentType: String
    let status: TestResultStatus
    let output: String
    let structuredOutput: [String: String]?
    let confidence: Float
    let tokensUsed: Int
    let executionTime: TimeInterval
    let error: String?
    let metadata: [String: String]

    init(
        id: UUID = UUID(),
        taskId: UUID,
        agentType: String,
        status: TestResultStatus,
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
}

// MARK: - Mirrored: IntelligenceTaskResult

private struct TestIntelligenceResult {
    let status: TestIntelligenceResultStatus
    let modelUsed: String?
    let toolsUsed: [TestToolUsage]
    let discoveredKnowledgeTitle: String?

    init(
        status: TestIntelligenceResultStatus,
        modelUsed: String? = nil,
        toolsUsed: [TestToolUsage] = [],
        discoveredKnowledgeTitle: String? = nil
    ) {
        self.status = status
        self.modelUsed = modelUsed
        self.toolsUsed = toolsUsed
        self.discoveredKnowledgeTitle = discoveredKnowledgeTitle
    }
}

// MARK: - TaskPriority Tests

final class SubagentTaskPriorityTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(TestTaskPriority.allCases.count, 4)
    }

    func testRawValues() {
        XCTAssertEqual(TestTaskPriority.low.rawValue, 0)
        XCTAssertEqual(TestTaskPriority.normal.rawValue, 50)
        XCTAssertEqual(TestTaskPriority.high.rawValue, 75)
        XCTAssertEqual(TestTaskPriority.critical.rawValue, 100)
    }

    func testComparableOrdering() {
        XCTAssertTrue(TestTaskPriority.low < .normal)
        XCTAssertTrue(TestTaskPriority.normal < .high)
        XCTAssertTrue(TestTaskPriority.high < .critical)
    }

    func testLowIsLowest() {
        for priority in TestTaskPriority.allCases where priority != .low {
            XCTAssertTrue(.low < priority)
        }
    }

    func testCriticalIsHighest() {
        for priority in TestTaskPriority.allCases where priority != .critical {
            XCTAssertTrue(priority < .critical)
        }
    }

    func testSortingByPriority() {
        let unsorted: [TestTaskPriority] = [.normal, .critical, .low, .high]
        let sorted = unsorted.sorted()
        XCTAssertEqual(sorted, [.low, .normal, .high, .critical])
    }

    func testEqualityReflexive() {
        for priority in TestTaskPriority.allCases {
            let copy = priority
            XCTAssertFalse(copy < priority, "\(priority) should not be less than itself")
        }
    }
}

// MARK: - OutputRequirement Tests

final class SubagentOutputRequirementTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(TestOutputRequirement.allCases.count, 5)
    }

    func testRawValues() {
        XCTAssertEqual(TestOutputRequirement.text.rawValue, "text")
        XCTAssertEqual(TestOutputRequirement.json.rawValue, "json")
        XCTAssertEqual(TestOutputRequirement.code.rawValue, "code")
        XCTAssertEqual(TestOutputRequirement.markdown.rawValue, "markdown")
        XCTAssertEqual(TestOutputRequirement.structured.rawValue, "structured")
    }

    func testAllRawValuesUnique() {
        let rawValues = TestOutputRequirement.allCases.map(\.rawValue)
        XCTAssertEqual(Set(rawValues).count, rawValues.count)
    }
}

// MARK: - ResultStatus Tests

final class SubagentResultStatusTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(TestResultStatus.allCases.count, 5)
    }

    func testRawValues() {
        XCTAssertEqual(TestResultStatus.success.rawValue, "success")
        XCTAssertEqual(TestResultStatus.partialSuccess.rawValue, "partialSuccess")
        XCTAssertEqual(TestResultStatus.failed.rawValue, "failed")
        XCTAssertEqual(TestResultStatus.timeout.rawValue, "timeout")
        XCTAssertEqual(TestResultStatus.cancelled.rawValue, "cancelled")
    }

    func testSuccessStatuses() {
        XCTAssertTrue(TestResultStatus.success.isSuccess)
        XCTAssertTrue(TestResultStatus.partialSuccess.isSuccess)
    }

    func testNonSuccessStatuses() {
        XCTAssertFalse(TestResultStatus.failed.isSuccess)
        XCTAssertFalse(TestResultStatus.timeout.isSuccess)
        XCTAssertFalse(TestResultStatus.cancelled.isSuccess)
    }
}

// MARK: - AggregationStrategy Tests

final class SubagentAggregationStrategyTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(TestAggregationStrategy.allCases.count, 5)
    }

    func testRawValues() {
        XCTAssertEqual(TestAggregationStrategy.merge.rawValue, "merge")
        XCTAssertEqual(TestAggregationStrategy.consensus.rawValue, "consensus")
        XCTAssertEqual(TestAggregationStrategy.bestConfidence.rawValue, "bestConfidence")
        XCTAssertEqual(TestAggregationStrategy.sequential.rawValue, "sequential")
        XCTAssertEqual(TestAggregationStrategy.custom.rawValue, "custom")
    }

    func testAllRawValuesUnique() {
        let rawValues = TestAggregationStrategy.allCases.map(\.rawValue)
        XCTAssertEqual(Set(rawValues).count, rawValues.count)
    }
}

// MARK: - SubagentTask Tests

final class SubagentTaskTests: XCTestCase {

    func testDefaultInit() {
        let task = TestSubagentTask(description: "Research topic", input: "Swift concurrency")
        XCTAssertFalse(task.id.uuidString.isEmpty)
        XCTAssertNil(task.parentTaskId)
        XCTAssertEqual(task.agentType, "generalPurpose")
        XCTAssertEqual(task.description, "Research topic")
        XCTAssertEqual(task.input, "Swift concurrency")
        XCTAssertEqual(task.priority, .normal)
        XCTAssertEqual(task.timeout, 60)
        XCTAssertEqual(task.maxTokens, 4096)
        XCTAssertEqual(task.requiredOutput, .text)
        XCTAssertTrue(task.dependsOn.isEmpty)
    }

    func testCustomInit() {
        let id = UUID()
        let parentId = UUID()
        let dep1 = UUID()
        let dep2 = UUID()
        let task = TestSubagentTask(
            id: id, parentTaskId: parentId,
            agentType: "research",
            description: "Find papers",
            input: "machine learning",
            priority: .critical,
            timeout: 120,
            maxTokens: 8192,
            requiredOutput: .json,
            dependsOn: [dep1, dep2]
        )
        XCTAssertEqual(task.id, id)
        XCTAssertEqual(task.parentTaskId, parentId)
        XCTAssertEqual(task.agentType, "research")
        XCTAssertEqual(task.priority, .critical)
        XCTAssertEqual(task.timeout, 120)
        XCTAssertEqual(task.maxTokens, 8192)
        XCTAssertEqual(task.requiredOutput, .json)
        XCTAssertEqual(task.dependsOn.count, 2)
    }

    func testIdentifiable() {
        let task1 = TestSubagentTask(description: "A", input: "B")
        let task2 = TestSubagentTask(description: "A", input: "B")
        XCTAssertNotEqual(task1.id, task2.id)
    }

    func testNoDependencies() {
        let task = TestSubagentTask(description: "X", input: "Y")
        XCTAssertTrue(task.dependsOn.isEmpty)
    }

    func testDependencyChain() {
        let task1 = TestSubagentTask(description: "Step 1", input: "A")
        let task2 = TestSubagentTask(description: "Step 2", input: "B", dependsOn: [task1.id])
        let task3 = TestSubagentTask(description: "Step 3", input: "C", dependsOn: [task1.id, task2.id])
        XCTAssertEqual(task2.dependsOn.count, 1)
        XCTAssertEqual(task3.dependsOn.count, 2)
        XCTAssertTrue(task3.dependsOn.contains(task1.id))
        XCTAssertTrue(task3.dependsOn.contains(task2.id))
    }

    func testDefaultTimeout() {
        let task = TestSubagentTask(description: "X", input: "Y")
        XCTAssertEqual(task.timeout, 60)
    }

    func testDefaultMaxTokens() {
        let task = TestSubagentTask(description: "X", input: "Y")
        XCTAssertEqual(task.maxTokens, 4096)
    }
}

// MARK: - EnhancedSubagentResult Tests

final class EnhancedSubagentResultTests: XCTestCase {

    func testDefaultInit() {
        let taskId = UUID()
        let result = TestSubagentResult(taskId: taskId, agentType: "research", status: .success, output: "Found data")
        XCTAssertFalse(result.id.uuidString.isEmpty)
        XCTAssertEqual(result.taskId, taskId)
        XCTAssertEqual(result.agentType, "research")
        XCTAssertEqual(result.status, .success)
        XCTAssertEqual(result.output, "Found data")
        XCTAssertNil(result.structuredOutput)
        XCTAssertEqual(result.confidence, 0.8, accuracy: 0.01)
        XCTAssertEqual(result.tokensUsed, 0)
        XCTAssertEqual(result.executionTime, 0)
        XCTAssertNil(result.error)
        XCTAssertTrue(result.metadata.isEmpty)
    }

    func testWithError() {
        let taskId = UUID()
        let result = TestSubagentResult(
            taskId: taskId, agentType: "plan", status: .failed,
            output: "", error: "Provider unavailable"
        )
        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.error, "Provider unavailable")
    }

    func testWithStructuredOutput() {
        let taskId = UUID()
        let structured = ["title": "Report", "summary": "All good"]
        let result = TestSubagentResult(
            taskId: taskId, agentType: "research", status: .success,
            output: "Full text", structuredOutput: structured
        )
        XCTAssertEqual(result.structuredOutput?["title"], "Report")
        XCTAssertEqual(result.structuredOutput?["summary"], "All good")
    }

    func testWithMetadata() {
        let taskId = UUID()
        let result = TestSubagentResult(
            taskId: taskId, agentType: "debug", status: .success,
            output: "Fixed", metadata: ["tokensUsed": "150", "model": "claude-haiku-3.5"]
        )
        XCTAssertEqual(result.metadata["tokensUsed"], "150")
        XCTAssertEqual(result.metadata["model"], "claude-haiku-3.5")
    }

    func testConfidenceRange() {
        let taskId = UUID()
        let lowConf = TestSubagentResult(taskId: taskId, agentType: "research", status: .partialSuccess, output: "Maybe", confidence: 0.3)
        let highConf = TestSubagentResult(taskId: taskId, agentType: "research", status: .success, output: "Yes", confidence: 0.95)
        XCTAssertLessThan(lowConf.confidence, highConf.confidence)
    }

    func testTokensAndExecutionTime() {
        let taskId = UUID()
        let result = TestSubagentResult(
            taskId: taskId, agentType: "research", status: .success,
            output: "Done", tokensUsed: 1500, executionTime: 3.5
        )
        XCTAssertEqual(result.tokensUsed, 1500)
        XCTAssertEqual(result.executionTime, 3.5, accuracy: 0.01)
    }

    func testIdentifiable() {
        let taskId = UUID()
        let r1 = TestSubagentResult(taskId: taskId, agentType: "plan", status: .success, output: "A")
        let r2 = TestSubagentResult(taskId: taskId, agentType: "plan", status: .success, output: "A")
        XCTAssertNotEqual(r1.id, r2.id)
    }
}

// MARK: - IntelligenceTaskResultStatus Tests

final class IntelligenceTaskResultStatusTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(TestIntelligenceResultStatus.allCases.count, 4)
    }

    func testRawValues() {
        XCTAssertEqual(TestIntelligenceResultStatus.completed.rawValue, "completed")
        XCTAssertEqual(TestIntelligenceResultStatus.failed.rawValue, "failed")
        XCTAssertEqual(TestIntelligenceResultStatus.cancelled.rawValue, "cancelled")
        XCTAssertEqual(TestIntelligenceResultStatus.inProgress.rawValue, "inProgress")
    }

    func testTerminalStatuses() {
        XCTAssertTrue(TestIntelligenceResultStatus.completed.isTerminal)
        XCTAssertTrue(TestIntelligenceResultStatus.failed.isTerminal)
        XCTAssertTrue(TestIntelligenceResultStatus.cancelled.isTerminal)
    }

    func testNonTerminalStatuses() {
        XCTAssertFalse(TestIntelligenceResultStatus.inProgress.isTerminal)
    }
}

// MARK: - IntelligenceTaskResult Tests

final class IntelligenceTaskResultTests: XCTestCase {

    func testMinimalInit() {
        let result = TestIntelligenceResult(status: .completed)
        XCTAssertEqual(result.status, .completed)
        XCTAssertNil(result.modelUsed)
        XCTAssertTrue(result.toolsUsed.isEmpty)
        XCTAssertNil(result.discoveredKnowledgeTitle)
    }

    func testFullInit() {
        let tools = [
            TestToolUsage(name: "search", input: "query", output: "results", success: true),
            TestToolUsage(name: "read", input: "file.swift", output: "content", success: true)
        ]
        let result = TestIntelligenceResult(
            status: .completed,
            modelUsed: "claude-sonnet-4",
            toolsUsed: tools,
            discoveredKnowledgeTitle: "New pattern"
        )
        XCTAssertEqual(result.modelUsed, "claude-sonnet-4")
        XCTAssertEqual(result.toolsUsed.count, 2)
        XCTAssertEqual(result.discoveredKnowledgeTitle, "New pattern")
    }

    func testFailedResult() {
        let result = TestIntelligenceResult(status: .failed)
        XCTAssertEqual(result.status, .failed)
    }

    func testInProgressResult() {
        let result = TestIntelligenceResult(status: .inProgress, modelUsed: "claude-haiku-3.5")
        XCTAssertFalse(result.status.isTerminal)
    }
}

// MARK: - ToolUsage Tests

final class SubagentToolUsageTests: XCTestCase {

    func testCreation() {
        let tool = TestToolUsage(name: "bash", input: "ls -la", output: "file1 file2", success: true)
        XCTAssertEqual(tool.name, "bash")
        XCTAssertEqual(tool.input, "ls -la")
        XCTAssertEqual(tool.output, "file1 file2")
        XCTAssertTrue(tool.success)
    }

    func testFailedTool() {
        let tool = TestToolUsage(name: "web_search", input: "query", output: "error: timeout", success: false)
        XCTAssertFalse(tool.success)
    }

    func testEmptyOutput() {
        let tool = TestToolUsage(name: "read", input: "/empty.txt", output: "", success: true)
        XCTAssertTrue(tool.output.isEmpty)
    }
}

// MARK: - OrchestratorError Tests

final class OrchestratorErrorTests: XCTestCase {

    func testContextPreparationFailed() {
        let error = TestOrchestratorError.contextPreparationFailed("Missing data")
        XCTAssertEqual(error.localizedDescription, "Context preparation failed: Missing data")
    }

    func testSkillLoadingFailed() {
        let error = TestOrchestratorError.skillLoadingFailed("Skill not found")
        XCTAssertEqual(error.localizedDescription, "Skill loading failed: Skill not found")
    }

    func testKnowledgeLoadingFailed() {
        let error = TestOrchestratorError.knowledgeLoadingFailed("DB unavailable")
        XCTAssertEqual(error.localizedDescription, "Knowledge loading failed: DB unavailable")
    }

    func testTaskCompletionFailed() {
        let error = TestOrchestratorError.taskCompletionFailed("Timeout")
        XCTAssertEqual(error.localizedDescription, "Task completion failed: Timeout")
    }

    func testIsError() {
        let error: Error = TestOrchestratorError.contextPreparationFailed("test")
        XCTAssertNotNil(error as? TestOrchestratorError)
    }

    func testAllCasesAreDistinct() {
        let errors: [TestOrchestratorError] = [
            .contextPreparationFailed("x"),
            .skillLoadingFailed("x"),
            .knowledgeLoadingFailed("x"),
            .taskCompletionFailed("x")
        ]
        let descriptions = errors.map(\.localizedDescription)
        XCTAssertEqual(Set(descriptions).count, 4)
    }
}
