@testable import TheaInterfaces
import XCTest

final class SnapshotEdgeCaseTests: XCTestCase {

    // MARK: - ConversationSnapshot

    func testConversationSnapshotDefaults() {
        let snapshot = ConversationSnapshot(
            id: UUID(),
            title: "Test",
            createdAt: Date(),
            updatedAt: Date()
        )
        XCTAssertFalse(snapshot.isPinned)
        XCTAssertEqual(snapshot.messageCount, 0)
    }

    func testConversationSnapshotCodableRoundtrip() throws {
        let snapshot = ConversationSnapshot(
            id: UUID(),
            title: "My Chat",
            createdAt: Date(),
            updatedAt: Date(),
            isPinned: true,
            messageCount: 42
        )
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(ConversationSnapshot.self, from: data)

        XCTAssertEqual(decoded.id, snapshot.id)
        XCTAssertEqual(decoded.title, "My Chat")
        XCTAssertTrue(decoded.isPinned)
        XCTAssertEqual(decoded.messageCount, 42)
    }

    func testConversationSnapshotEmptyTitle() throws {
        let snapshot = ConversationSnapshot(
            id: UUID(),
            title: "",
            createdAt: Date(),
            updatedAt: Date()
        )
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(ConversationSnapshot.self, from: data)
        XCTAssertEqual(decoded.title, "")
    }

    // MARK: - MessageSnapshot

    func testMessageSnapshotNilTokenCount() {
        let snapshot = MessageSnapshot(
            id: UUID(),
            conversationID: UUID(),
            role: .user,
            content: "Hello",
            timestamp: Date()
        )
        XCTAssertNil(snapshot.tokenCount)
    }

    func testMessageSnapshotWithTokenCount() {
        let snapshot = MessageSnapshot(
            id: UUID(),
            conversationID: UUID(),
            role: .assistant,
            content: "Response text",
            timestamp: Date(),
            tokenCount: 150
        )
        XCTAssertEqual(snapshot.tokenCount, 150)
    }

    func testMessageSnapshotAllRoles() throws {
        for role in [MessageRoleSnapshot.user, .assistant, .system] {
            let snapshot = MessageSnapshot(
                id: UUID(),
                conversationID: UUID(),
                role: role,
                content: "Test",
                timestamp: Date()
            )
            let data = try JSONEncoder().encode(snapshot)
            let decoded = try JSONDecoder().decode(MessageSnapshot.self, from: data)
            XCTAssertEqual(decoded.role, role)
        }
    }

    // MARK: - ProjectSnapshot

    func testProjectSnapshotDefaults() {
        let snapshot = ProjectSnapshot(
            id: UUID(),
            title: "Project",
            createdAt: Date(),
            updatedAt: Date()
        )
        XCTAssertNil(snapshot.description)
        XCTAssertEqual(snapshot.conversationCount, 0)
        XCTAssertNil(snapshot.rootPath)
    }

    func testProjectSnapshotCodableRoundtrip() throws {
        let snapshot = ProjectSnapshot(
            id: UUID(),
            title: "My Project",
            description: "A cool project",
            createdAt: Date(),
            updatedAt: Date(),
            conversationCount: 5,
            rootPath: "/Users/test/project"
        )
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(ProjectSnapshot.self, from: data)

        XCTAssertEqual(decoded.title, "My Project")
        XCTAssertEqual(decoded.description, "A cool project")
        XCTAssertEqual(decoded.conversationCount, 5)
        XCTAssertEqual(decoded.rootPath, "/Users/test/project")
    }

    // MARK: - TaskContextSnapshot

    func testTaskContextSnapshotDefaults() {
        let context = TaskContextSnapshot(instruction: "Do something")
        XCTAssertTrue(context.metadata.isEmpty)
        XCTAssertEqual(context.retryCount, 0)
        XCTAssertNil(context.previousError)
        XCTAssertTrue(context.previousAttempts.isEmpty)
        XCTAssertTrue(context.verificationIssues.isEmpty)
        XCTAssertTrue(context.userPreferences.isEmpty)
    }

    func testTaskContextSnapshotCodableRoundtrip() throws {
        let context = TaskContextSnapshot(
            instruction: "Generate code",
            metadata: ["lang": "swift"],
            retryCount: 2,
            previousError: "Syntax error",
            previousAttempts: [
                SubtaskResultSnapshot(step: 1, output: "failed output", success: false, executionTime: 1.5)
            ],
            verificationIssues: ["Missing semicolon"],
            userPreferences: ["style": "concise"]
        )
        let data = try JSONEncoder().encode(context)
        let decoded = try JSONDecoder().decode(TaskContextSnapshot.self, from: data)

        XCTAssertEqual(decoded.instruction, "Generate code")
        XCTAssertEqual(decoded.metadata["lang"], "swift")
        XCTAssertEqual(decoded.retryCount, 2)
        XCTAssertEqual(decoded.previousError, "Syntax error")
        XCTAssertEqual(decoded.previousAttempts.count, 1)
        XCTAssertEqual(decoded.previousAttempts[0].step, 1)
        XCTAssertFalse(decoded.previousAttempts[0].success)
    }

    // MARK: - SubtaskResultSnapshot

    func testSubtaskResultSnapshot() {
        let result = SubtaskResultSnapshot(step: 3, output: "Done", success: true, executionTime: 2.5)
        XCTAssertEqual(result.step, 3)
        XCTAssertEqual(result.output, "Done")
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.executionTime, 2.5, accuracy: 0.001)
    }

    // MARK: - TaskTypeSnapshot Exhaustive

    func testTaskTypeSnapshotAllCasesHaveDisplayName() {
        for taskType in TaskTypeSnapshot.allCases {
            XCTAssertFalse(taskType.displayName.isEmpty, "\(taskType) should have a non-empty displayName")
        }
    }

    func testTaskTypeSnapshotAllCasesHaveIcon() {
        for taskType in TaskTypeSnapshot.allCases {
            XCTAssertFalse(taskType.icon.isEmpty, "\(taskType) should have a non-empty icon")
        }
    }

    func testTaskTypeSnapshotCaseCount() {
        XCTAssertEqual(TaskTypeSnapshot.allCases.count, 17)
    }

    func testTaskTypeSnapshotSpecificDisplayNames() {
        XCTAssertEqual(TaskTypeSnapshot.simpleQA.displayName, "Simple Q&A")
        XCTAssertEqual(TaskTypeSnapshot.codeGeneration.displayName, "Code Generation")
        XCTAssertEqual(TaskTypeSnapshot.complexReasoning.displayName, "Complex Reasoning")
        XCTAssertEqual(TaskTypeSnapshot.debugging.displayName, "Debugging")
    }
}
