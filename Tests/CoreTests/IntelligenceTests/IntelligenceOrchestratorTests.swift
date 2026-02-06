@testable import TheaCore
import XCTest

@MainActor
final class IntelligenceOrchestratorTests: XCTestCase {

    // MARK: - Orchestrator Instance Tests

    func testOrchestratorSharedInstance() {
        let orchestrator = IntelligenceOrchestrator.shared
        XCTAssertNotNil(orchestrator)
        XCTAssertTrue(orchestrator === IntelligenceOrchestrator.shared) // Same instance
    }

    func testOrchestratorInitialState() {
        let orchestrator = IntelligenceOrchestrator.shared
        XCTAssertNil(orchestrator.currentContext)
        XCTAssertFalse(orchestrator.isPreparingContext)
        XCTAssertNil(orchestrator.lastError)
    }

    // MARK: - Task Context Preparation Tests

    func testPrepareTaskContextCreatesContext() async {
        let orchestrator = IntelligenceOrchestrator.shared

        let context = await orchestrator.prepareTaskContext(
            task: "Review this Swift code for bugs",
            taskType: .codeGeneration,
            currentFile: "test.swift",
            projectPath: "/test/project"
        )

        XCTAssertNotNil(context)
        XCTAssertEqual(context.task, "Review this Swift code for bugs")
        XCTAssertEqual(context.taskType, .codeGeneration)
        XCTAssertNotNil(context.enhancedSystemPrompt)
        XCTAssertFalse(context.enhancedSystemPrompt.isEmpty)
    }

    func testPrepareTaskContextFindsMatchingSkills() async {
        let orchestrator = IntelligenceOrchestrator.shared

        let context = await orchestrator.prepareTaskContext(
            task: "/review please check this code",
            taskType: .codeRefactoring
        )

        // Should find skills matching /review and codeRefactoring
        XCTAssertFalse(context.matchingSkills.isEmpty)
    }

    func testPrepareTaskContextIncludesLearningContext() async {
        let orchestrator = IntelligenceOrchestrator.shared

        let context = await orchestrator.prepareTaskContext(
            task: "Help me understand this algorithm",
            taskType: .analysis
        )

        XCTAssertNotNil(context.learningContext)
        XCTAssertNotNil(context.responseStyle)
    }

    func testEnhancedSystemPromptContainsSkillInstructions() async {
        let orchestrator = IntelligenceOrchestrator.shared

        let context = await orchestrator.prepareTaskContext(
            task: "/review check for security vulnerabilities",
            taskType: .codeGeneration
        )

        // Should contain skill instructions in enhanced prompt
        if !context.matchingSkills.isEmpty {
            XCTAssertTrue(context.enhancedSystemPrompt.contains("Applicable Skills"))
        }
    }

    // MARK: - Task Completion Tests

    func testRecordTaskCompletionWithSuccess() async {
        let orchestrator = IntelligenceOrchestrator.shared

        // First prepare a context
        let context = await orchestrator.prepareTaskContext(
            task: "Write a test function",
            taskType: .codeGeneration
        )

        // Then record completion
        let result = TaskResult(
            status: .completed,
            modelUsed: "claude-3-5-sonnet",
            toolsUsed: []
        )

        await orchestrator.recordTaskCompletion(
            context: context,
            result: result,
            tokensUsed: 500,
            responseTime: 2.5
        )

        // Context should be cleared after completion
        XCTAssertNil(orchestrator.currentContext)
    }

    func testRecordTaskCompletionWithToolUsage() async {
        let orchestrator = IntelligenceOrchestrator.shared

        let context = await orchestrator.prepareTaskContext(
            task: "Search for files",
            taskType: .research
        )

        let result = TaskResult(
            status: .completed,
            modelUsed: "claude-3-5-sonnet",
            toolsUsed: [
                ToolUsage(name: "file_search", input: "*.swift", output: "Found 10 files", success: true),
                ToolUsage(name: "read_file", input: "test.swift", output: "File content...", success: true)
            ]
        )

        await orchestrator.recordTaskCompletion(
            context: context,
            result: result,
            tokensUsed: 1000,
            responseTime: 5.0
        )

        // Tools should have been recorded to activity tracker
        // (Activity tracker tests would verify the actual recording)
    }

    func testRecordTaskCompletionWithDiscoveredKnowledge() async {
        let orchestrator = IntelligenceOrchestrator.shared

        let context = await orchestrator.prepareTaskContext(
            task: "Analyze this API documentation",
            taskType: .research
        )

        let discoveredKnowledge = DiscoveredKnowledge(
            title: "New API Pattern",
            content: "This API uses a unique pagination approach...",
            category: .integrations,
            tags: ["api", "pagination"]
        )

        let result = TaskResult(
            status: .completed,
            modelUsed: "claude-3-5-sonnet",
            discoveredKnowledge: discoveredKnowledge
        )

        await orchestrator.recordTaskCompletion(
            context: context,
            result: result,
            tokensUsed: 2000,
            responseTime: 10.0
        )

        // Knowledge should have been added to knowledge manager
        // (Knowledge manager tests would verify the actual addition)
    }

    // MARK: - Task Result Tests

    func testTaskResultStatusTypes() {
        let completedResult = TaskResult(status: .completed)
        XCTAssertEqual(completedResult.status, .completed)

        let failedResult = TaskResult(status: .failed)
        XCTAssertEqual(failedResult.status, .failed)

        let cancelledResult = TaskResult(status: .cancelled)
        XCTAssertEqual(cancelledResult.status, .cancelled)

        let inProgressResult = TaskResult(status: .inProgress)
        XCTAssertEqual(inProgressResult.status, .inProgress)
    }

    // MARK: - Tool Usage Tests

    func testToolUsageCreation() {
        let toolUsage = ToolUsage(
            name: "bash",
            input: "ls -la",
            output: "total 0\ndrwxr-xr-x...",
            success: true
        )

        XCTAssertEqual(toolUsage.name, "bash")
        XCTAssertEqual(toolUsage.input, "ls -la")
        XCTAssertFalse(toolUsage.output.isEmpty)
        XCTAssertTrue(toolUsage.success)
    }

    func testToolUsageFailure() {
        let failedToolUsage = ToolUsage(
            name: "file_write",
            input: "/protected/file.txt",
            output: "Permission denied",
            success: false
        )

        XCTAssertFalse(failedToolUsage.success)
    }

    // MARK: - Discovered Knowledge Tests

    func testDiscoveredKnowledgeCreation() {
        let knowledge = DiscoveredKnowledge(
            title: "Test Discovery",
            content: "Important finding about the codebase",
            category: .coding,
            tags: ["discovery", "important"]
        )

        XCTAssertEqual(knowledge.title, "Test Discovery")
        XCTAssertEqual(knowledge.content, "Important finding about the codebase")
        XCTAssertEqual(knowledge.category, .coding)
        XCTAssertEqual(knowledge.tags.count, 2)
    }

    // MARK: - Learning Context Tests

    func testLearningContextIncludesUserProfile() async {
        let orchestrator = IntelligenceOrchestrator.shared

        let context = await orchestrator.prepareTaskContext(
            task: "Help me learn Swift concurrency",
            taskType: .analysis
        )

        // Learning context should be populated
        XCTAssertNotNil(context.learningContext.experienceLevel)
        XCTAssertNotNil(context.learningContext.preferredStyle)
    }

    // MARK: - Response Style Tests

    func testResponseStyleIncludedInContext() async {
        let orchestrator = IntelligenceOrchestrator.shared

        let context = await orchestrator.prepareTaskContext(
            task: "Explain async/await",
            taskType: .analysis
        )

        XCTAssertNotNil(context.responseStyle)
        // Response style should have a valid verbosity setting
        XCTAssertTrue([ResponseStyle.Verbosity.concise, .moderate, .detailed]
            .contains(context.responseStyle.verbosity))
    }

    // MARK: - Protocol Conformance Tests

    func testSkillEnhanceableProtocol() {
        // Verify the protocol exists and can be used
        struct MockSkillEnhanceable: SkillEnhanceable {
            var appliedSkills: [SkillDefinition] = []

            mutating func applySkills(_ skills: [SkillDefinition]) async {
                appliedSkills = skills
            }
        }

        var mock = MockSkillEnhanceable()
        XCTAssertTrue(mock.appliedSkills.isEmpty)
    }
}
