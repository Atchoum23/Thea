// ReActExecutorTests.swift
// Tests for the ReAct (Reasoning + Acting) Executor

@testable import TheaCore
import XCTest

// MARK: - ReActExecutor Tests

@MainActor
final class ReActExecutorTests: XCTestCase {
    // MARK: - Configuration Tests

    func testDefaultConfiguration() {
        let config = ReActConfig()

        XCTAssertEqual(config.maxSteps, 10)
        XCTAssertEqual(config.actionTimeout, 30.0, accuracy: 0.001)
        XCTAssertEqual(config.reasoningModel, "claude-sonnet-4-20250514")
        XCTAssertTrue(config.requireApprovalForActions.contains("write_file"))
        XCTAssertTrue(config.requireApprovalForActions.contains("execute_code"))
        XCTAssertTrue(config.requireApprovalForActions.contains("api_call"))
    }

    func testConfigurationIsSendable() {
        let config = ReActConfig()
        // This test passes if it compiles - ReActConfig must be Sendable
        let _: Sendable = config
    }

    func testCustomConfiguration() {
        var config = ReActConfig()
        config.maxSteps = 20
        config.actionTimeout = 60.0
        config.reasoningModel = "custom-model"

        XCTAssertEqual(config.maxSteps, 20)
        XCTAssertEqual(config.actionTimeout, 60.0, accuracy: 0.001)
        XCTAssertEqual(config.reasoningModel, "custom-model")
    }

    // MARK: - ReActPhase Tests

    func testReActPhaseValues() {
        XCTAssertNotNil(ReActPhase.thought)
        XCTAssertNotNil(ReActPhase.action)
        XCTAssertNotNil(ReActPhase.observation)
        XCTAssertNotNil(ReActPhase.finalAnswer)
    }

    // MARK: - ReActStep Tests

    func testReActStepCreation() {
        let step = ReActStep(
            stepNumber: 1,
            phase: .thought,
            content: "Analyzing the problem",
            action: nil,
            observation: nil
        )

        XCTAssertEqual(step.stepNumber, 1)
        XCTAssertEqual(step.phase, .thought)
        XCTAssertEqual(step.content, "Analyzing the problem")
        XCTAssertNil(step.action)
        XCTAssertNil(step.observation)
    }

    func testReActStepWithAction() {
        let action = ReActAction(
            tool: "web_search",
            input: "Swift concurrency best practices"
        )

        let step = ReActStep(
            stepNumber: 2,
            phase: .action,
            content: "Searching for information",
            action: action,
            observation: nil
        )

        XCTAssertEqual(step.phase, .action)
        XCTAssertNotNil(step.action)
        XCTAssertEqual(step.action?.tool, "web_search")
    }

    func testReActStepWithObservation() {
        let observation = ReActObservation(
            result: "Found 10 results",
            success: true,
            error: nil
        )

        let step = ReActStep(
            stepNumber: 3,
            phase: .observation,
            content: "Processing search results",
            action: nil,
            observation: observation
        )

        XCTAssertEqual(step.phase, .observation)
        XCTAssertNotNil(step.observation)
        XCTAssertTrue(step.observation?.success ?? false)
    }

    func testReActStepIsSendable() {
        let step = ReActStep(
            stepNumber: 1,
            phase: .thought,
            content: "Test",
            action: nil,
            observation: nil
        )
        // This test passes if it compiles - ReActStep must be Sendable
        let _: Sendable = step
    }

    // MARK: - ReActAction Tests

    func testReActActionCreation() {
        let action = ReActAction(
            tool: "code_execute",
            input: "print('Hello, World!')"
        )

        XCTAssertEqual(action.tool, "code_execute")
        XCTAssertEqual(action.input, "print('Hello, World!')")
    }

    func testReActActionIsSendable() {
        let action = ReActAction(tool: "test", input: "test")
        // This test passes if it compiles - ReActAction must be Sendable
        let _: Sendable = action
    }

    // MARK: - ReActObservation Tests

    func testReActObservationSuccess() {
        let observation = ReActObservation(
            result: "Operation completed successfully",
            success: true,
            error: nil
        )

        XCTAssertTrue(observation.success)
        XCTAssertNil(observation.error)
        XCTAssertEqual(observation.result, "Operation completed successfully")
    }

    func testReActObservationFailure() {
        let observation = ReActObservation(
            result: "",
            success: false,
            error: "Network timeout"
        )

        XCTAssertFalse(observation.success)
        XCTAssertEqual(observation.error, "Network timeout")
    }

    func testReActObservationIsSendable() {
        let observation = ReActObservation(result: "test", success: true, error: nil)
        // This test passes if it compiles - ReActObservation must be Sendable
        let _: Sendable = observation
    }

    // MARK: - ReActResult Tests

    func testReActResultSuccess() {
        let result = ReActResult(
            query: "Test query",
            finalAnswer: "The answer is 42",
            steps: [],
            totalSteps: 3,
            success: true,
            executionTime: 1.5
        )

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.query, "Test query")
        XCTAssertEqual(result.finalAnswer, "The answer is 42")
        XCTAssertEqual(result.totalSteps, 3)
        XCTAssertEqual(result.executionTime, 1.5, accuracy: 0.001)
    }

    func testReActResultWithSteps() {
        let steps = [
            ReActStep(stepNumber: 1, phase: .thought, content: "Thinking", action: nil, observation: nil),
            ReActStep(stepNumber: 2, phase: .action, content: "Acting", action: nil, observation: nil),
            ReActStep(stepNumber: 3, phase: .finalAnswer, content: "Done", action: nil, observation: nil)
        ]

        let result = ReActResult(
            query: "Complex query",
            finalAnswer: "Final answer",
            steps: steps,
            totalSteps: 3,
            success: true,
            executionTime: 5.0
        )

        XCTAssertEqual(result.steps.count, 3)
        XCTAssertEqual(result.totalSteps, 3)
    }

    func testReActResultIsSendable() {
        let result = ReActResult(
            query: "test",
            finalAnswer: "test",
            steps: [],
            totalSteps: 0,
            success: true,
            executionTime: 0
        )
        // This test passes if it compiles - ReActResult must be Sendable
        let _: Sendable = result
    }

    // MARK: - ReActError Tests

    func testReActErrorMaxStepsExceeded() {
        let error = ReActError.maxStepsExceeded(10)
        XCTAssertTrue(error.errorDescription?.contains("10") ?? false)
    }

    func testReActErrorActionFailed() {
        let error = ReActError.actionFailed("web_search", "Network error")
        XCTAssertTrue(error.errorDescription?.contains("web_search") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("Network error") ?? false)
    }

    func testReActErrorNoProvider() {
        let error = ReActError.noProviderAvailable
        XCTAssertNotNil(error.errorDescription)
    }

    func testReActErrorApprovalRequired() {
        let error = ReActError.approvalRequired("delete_file")
        XCTAssertTrue(error.errorDescription?.contains("delete_file") ?? false)
    }

    func testReActErrorParsingFailure() {
        let error = ReActError.parsingFailure("Invalid JSON")
        XCTAssertTrue(error.errorDescription?.contains("Invalid JSON") ?? false)
    }
}

// MARK: - ReActExecutor Integration Tests

@MainActor
final class ReActExecutorIntegrationTests: XCTestCase {
    func testExecutorInitialization() {
        let config = ReActConfig()
        let executor = ReActExecutor(config: config)

        XCTAssertNotNil(executor)
    }

    func testExecutorWithDefaultConfig() {
        let executor = ReActExecutor()
        XCTAssertNotNil(executor)
    }

    func testExecutorConfigAccessible() {
        var config = ReActConfig()
        config.maxSteps = 15
        let executor = ReActExecutor(config: config)

        XCTAssertEqual(executor.config.maxSteps, 15)
    }
}
