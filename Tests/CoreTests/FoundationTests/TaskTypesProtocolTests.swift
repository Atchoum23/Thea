import XCTest
@testable import TheaInterfaces

final class TaskTypesProtocolTests: XCTestCase {

    // MARK: - TaskTypeSnapshot Tests

    func testTaskTypeSnapshotCaseIterable() {
        XCTAssertEqual(TaskTypeSnapshot.allCases.count, 17)
    }

    func testTaskTypeSnapshotRawValues() {
        XCTAssertEqual(TaskTypeSnapshot.simpleQA.rawValue, "simpleQA")
        XCTAssertEqual(TaskTypeSnapshot.codeGeneration.rawValue, "codeGeneration")
        XCTAssertEqual(TaskTypeSnapshot.complexReasoning.rawValue, "complexReasoning")
        XCTAssertEqual(TaskTypeSnapshot.creativeWriting.rawValue, "creativeWriting")
        XCTAssertEqual(TaskTypeSnapshot.mathLogic.rawValue, "mathLogic")
    }

    func testTaskTypeSnapshotDisplayNames() {
        XCTAssertEqual(TaskTypeSnapshot.simpleQA.displayName, "Simple Q&A")
        XCTAssertEqual(TaskTypeSnapshot.codeGeneration.displayName, "Code Generation")
        XCTAssertEqual(TaskTypeSnapshot.complexReasoning.displayName, "Complex Reasoning")
        XCTAssertEqual(TaskTypeSnapshot.creativeWriting.displayName, "Creative Writing")
        XCTAssertEqual(TaskTypeSnapshot.mathLogic.displayName, "Math & Logic")
        XCTAssertEqual(TaskTypeSnapshot.summarization.displayName, "Summarization")
    }

    func testTaskTypeSnapshotIcons() {
        for taskType in TaskTypeSnapshot.allCases {
            XCTAssertFalse(taskType.icon.isEmpty, "\(taskType) should have an icon")
        }
    }

    func testTaskTypeSnapshotDisplayNamesNotEmpty() {
        for taskType in TaskTypeSnapshot.allCases {
            XCTAssertFalse(taskType.displayName.isEmpty, "\(taskType) should have a display name")
        }
    }

    func testTaskTypeSnapshotCodable() throws {
        let original = TaskTypeSnapshot.codeGeneration
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TaskTypeSnapshot.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testAllTaskTypeSnapshotsCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for taskType in TaskTypeSnapshot.allCases {
            let data = try encoder.encode(taskType)
            let decoded = try decoder.decode(TaskTypeSnapshot.self, from: data)
            XCTAssertEqual(decoded, taskType, "Round-trip encoding failed for \(taskType)")
        }
    }

    // MARK: - TaskContextSnapshot Tests

    func testTaskContextSnapshotDefaults() {
        let context = TaskContextSnapshot()
        XCTAssertEqual(context.instruction, "")
        XCTAssertTrue(context.metadata.isEmpty)
        XCTAssertEqual(context.retryCount, 0)
        XCTAssertNil(context.previousError)
        XCTAssertTrue(context.previousAttempts.isEmpty)
        XCTAssertTrue(context.verificationIssues.isEmpty)
        XCTAssertTrue(context.userPreferences.isEmpty)
    }

    func testTaskContextSnapshotCustomInit() {
        let context = TaskContextSnapshot(
            instruction: "Write unit tests",
            metadata: ["lang": "swift"],
            retryCount: 2,
            previousError: "Compilation failed",
            previousAttempts: [],
            verificationIssues: ["Missing test cases"],
            userPreferences: ["style": "tdd"]
        )
        XCTAssertEqual(context.instruction, "Write unit tests")
        XCTAssertEqual(context.metadata["lang"], "swift")
        XCTAssertEqual(context.retryCount, 2)
        XCTAssertEqual(context.previousError, "Compilation failed")
        XCTAssertEqual(context.verificationIssues.count, 1)
        XCTAssertEqual(context.userPreferences["style"], "tdd")
    }

    func testTaskContextSnapshotCodable() throws {
        let original = TaskContextSnapshot(
            instruction: "Analyze code",
            metadata: ["file": "test.swift"],
            retryCount: 1
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TaskContextSnapshot.self, from: data)
        XCTAssertEqual(decoded.instruction, original.instruction)
        XCTAssertEqual(decoded.retryCount, original.retryCount)
        XCTAssertEqual(decoded.metadata["file"], "test.swift")
    }

    func testTaskContextSnapshotMutability() {
        var context = TaskContextSnapshot()
        context.retryCount = 3
        context.previousError = "Timeout"
        context.metadata["key"] = "value"
        XCTAssertEqual(context.retryCount, 3)
        XCTAssertEqual(context.previousError, "Timeout")
        XCTAssertEqual(context.metadata["key"], "value")
    }

    // MARK: - SubtaskResultSnapshot Tests

    func testSubtaskResultSnapshotCreation() {
        let result = SubtaskResultSnapshot(
            step: 1,
            output: "Test output",
            success: true,
            executionTime: 2.5
        )
        XCTAssertEqual(result.step, 1)
        XCTAssertEqual(result.output, "Test output")
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.executionTime, 2.5)
    }

    func testSubtaskResultSnapshotCodable() throws {
        let original = SubtaskResultSnapshot(
            step: 3,
            output: "Compiled successfully",
            success: true,
            executionTime: 5.0
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SubtaskResultSnapshot.self, from: data)
        XCTAssertEqual(decoded.step, original.step)
        XCTAssertEqual(decoded.output, original.output)
        XCTAssertEqual(decoded.success, original.success)
        XCTAssertEqual(decoded.executionTime, original.executionTime)
    }

    func testSubtaskResultSnapshotFailure() {
        let result = SubtaskResultSnapshot(
            step: 2,
            output: "Error: type mismatch",
            success: false,
            executionTime: 0.1
        )
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.step, 2)
    }

    func testTaskContextWithPreviousAttempts() throws {
        let attempt1 = SubtaskResultSnapshot(step: 1, output: "Failed", success: false, executionTime: 1.0)
        let attempt2 = SubtaskResultSnapshot(step: 2, output: "Success", success: true, executionTime: 0.5)

        let context = TaskContextSnapshot(
            instruction: "Fix the bug",
            retryCount: 2,
            previousAttempts: [attempt1, attempt2]
        )
        XCTAssertEqual(context.previousAttempts.count, 2)
        XCTAssertFalse(context.previousAttempts[0].success)
        XCTAssertTrue(context.previousAttempts[1].success)

        // Verify full round-trip encoding
        let data = try JSONEncoder().encode(context)
        let decoded = try JSONDecoder().decode(TaskContextSnapshot.self, from: data)
        XCTAssertEqual(decoded.previousAttempts.count, 2)
    }
}
