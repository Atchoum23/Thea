// AgentModeTests.swift
// Tests for AgentMode, AgentPhase, AgentExecutionState, TaskGroup,
// AgentSubtask, AgentStep, AgentModeTask, AgentModeArtifact,
// AgentSettings, ArtifactReviewPolicy, TerminalExecutionPolicy
//
// AgentExecutionState is @MainActor + ObservableObject; all state tests
// are wrapped appropriately.

@testable import TheaCore
import XCTest

// MARK: - AgentMode Tests

final class AgentModeEnumTests: XCTestCase {

    func testAllCasesHaveDisplayNames() {
        for mode in AgentMode.allCases {
            XCTAssertFalse(mode.displayName.isEmpty, "Missing displayName for \(mode)")
        }
    }

    func testAllCasesHaveDescriptions() {
        for mode in AgentMode.allCases {
            XCTAssertFalse(mode.description.isEmpty, "Missing description for \(mode)")
        }
    }

    func testDisplayNamesAreDistinct() {
        let names = AgentMode.allCases.map { $0.displayName }
        XCTAssertEqual(names.count, Set(names).count)
    }

    func testRecommendedForCodeGenerationIsPlanning() {
        XCTAssertEqual(AgentMode.recommended(for: .codeGeneration), .planning)
    }

    func testRecommendedForDebuggingIsPlanning() {
        XCTAssertEqual(AgentMode.recommended(for: .debugging), .planning)
    }

    func testRecommendedForResearchIsPlanning() {
        XCTAssertEqual(AgentMode.recommended(for: .research), .planning)
    }

    func testRecommendedForAnalysisIsPlanning() {
        XCTAssertEqual(AgentMode.recommended(for: .analysis), .planning)
    }

    func testRecommendedForSimpleQAIsFast() {
        XCTAssertEqual(AgentMode.recommended(for: .simpleQA), .fast)
    }

    func testRecommendedForFactualIsFast() {
        XCTAssertEqual(AgentMode.recommended(for: .factual), .fast)
    }

    func testRecommendedForTranslationIsFast() {
        XCTAssertEqual(AgentMode.recommended(for: .translation), .fast)
    }

    func testRecommendedForConversationIsAuto() {
        // Conversation doesn't match planning or fast cases → auto
        XCTAssertEqual(AgentMode.recommended(for: .conversation), .auto)
    }

    func testCodableRoundTrip() throws {
        for mode in AgentMode.allCases {
            let data = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(AgentMode.self, from: data)
            XCTAssertEqual(decoded, mode)
        }
    }
}

// MARK: - AgentPhase Tests

final class AgentPhaseTests: XCTestCase {

    func testAllPhasesHaveDisplayNames() {
        let phases: [AgentPhase] = [.gatherContext, .takeAction, .verifyResults, .done, .userIntervention]
        for phase in phases {
            XCTAssertFalse(phase.displayName.isEmpty, "Missing displayName for \(phase)")
        }
    }

    func testDisplayNamesAreDistinct() {
        let phases: [AgentPhase] = [.gatherContext, .takeAction, .verifyResults, .done, .userIntervention]
        let names = phases.map { $0.displayName }
        XCTAssertEqual(names.count, Set(names).count)
    }

    func testCodableRoundTrip() throws {
        let phases: [AgentPhase] = [.gatherContext, .takeAction, .verifyResults, .done, .userIntervention]
        for phase in phases {
            let data = try JSONEncoder().encode(phase)
            let decoded = try JSONDecoder().decode(AgentPhase.self, from: data)
            XCTAssertEqual(decoded, phase)
        }
    }
}

// MARK: - AgentExecutionState Tests

@MainActor
final class AgentExecutionStateTests: XCTestCase {

    func testInitialValues() {
        let state = AgentExecutionState()
        XCTAssertEqual(state.mode, .auto)
        XCTAssertEqual(state.phase, .gatherContext)
        XCTAssertNil(state.currentTask)
        XCTAssertTrue(state.taskGroups.isEmpty)
        XCTAssertTrue(state.artifacts.isEmpty)
        XCTAssertEqual(state.progress, 0.0, accuracy: 0.001)
        XCTAssertTrue(state.statusMessage.isEmpty)
        XCTAssertTrue(state.canInterrupt)
    }

    func testTransitionToNewPhase() {
        let state = AgentExecutionState()
        state.transition(to: .takeAction)
        XCTAssertEqual(state.phase, .takeAction)
    }

    func testTransitionToDone() {
        let state = AgentExecutionState()
        state.transition(to: .done)
        XCTAssertEqual(state.phase, .done)
    }

    func testAddTaskGroup() {
        let state = AgentExecutionState()
        let group = TaskGroup(title: "Test Group", description: "A test group")
        state.addTaskGroup(group)
        XCTAssertEqual(state.taskGroups.count, 1)
        XCTAssertEqual(state.taskGroups.first?.title, "Test Group")
    }

    func testAddMultipleTaskGroups() {
        let state = AgentExecutionState()
        state.addTaskGroup(TaskGroup(title: "Group A", description: ""))
        state.addTaskGroup(TaskGroup(title: "Group B", description: ""))
        XCTAssertEqual(state.taskGroups.count, 2)
    }

    func testAddArtifact() {
        let state = AgentExecutionState()
        let artifact = AgentModeArtifact(type: .codeSnippet, title: "My snippet", content: "let x = 1")
        state.addArtifact(artifact)
        XCTAssertEqual(state.artifacts.count, 1)
        XCTAssertEqual(state.artifacts.first?.title, "My snippet")
    }

    func testUpdateProgressClamps() {
        let state = AgentExecutionState()

        state.updateProgress(1.5)
        XCTAssertEqual(state.progress, 1.0, accuracy: 0.001)

        state.updateProgress(-0.5)
        XCTAssertEqual(state.progress, 0.0, accuracy: 0.001)

        state.updateProgress(0.5)
        XCTAssertEqual(state.progress, 0.5, accuracy: 0.001)
    }

    func testUpdateProgressSetsMessage() {
        let state = AgentExecutionState()
        state.updateProgress(0.3, message: "Working…")
        XCTAssertEqual(state.statusMessage, "Working…")
        XCTAssertEqual(state.progress, 0.3, accuracy: 0.001)
    }

    func testUpdateProgressNilMessageKeepsOldMessage() {
        let state = AgentExecutionState()
        state.updateProgress(0.2, message: "Step 1")
        state.updateProgress(0.4, message: nil)
        XCTAssertEqual(state.statusMessage, "Step 1") // unchanged
    }

    func testReset() {
        let state = AgentExecutionState()
        state.transition(to: .verifyResults)
        state.addTaskGroup(TaskGroup(title: "G", description: ""))
        state.addArtifact(AgentModeArtifact(type: .analysis, title: "A", content: "content"))
        state.updateProgress(0.8, message: "Processing")
        state.canInterrupt = false

        state.reset()

        XCTAssertEqual(state.phase, .gatherContext)
        XCTAssertNil(state.currentTask)
        XCTAssertTrue(state.taskGroups.isEmpty)
        XCTAssertTrue(state.artifacts.isEmpty)
        XCTAssertEqual(state.progress, 0.0, accuracy: 0.001)
        XCTAssertTrue(state.statusMessage.isEmpty)
        XCTAssertTrue(state.canInterrupt)
    }
}

// MARK: - TaskGroup Tests

final class TaskGroupTests: XCTestCase {

    func testDefaultInitValues() {
        let group = TaskGroup(title: "My Group", description: "Does stuff")
        XCTAssertEqual(group.title, "My Group")
        XCTAssertEqual(group.description, "Does stuff")
        XCTAssertTrue(group.subtasks.isEmpty)
        XCTAssertEqual(group.status, .pending)
        XCTAssertNil(group.completedAt)
        XCTAssertTrue(group.editedFiles.isEmpty)
    }

    func testProgressZeroWithNoSubtasks() {
        let group = TaskGroup(title: "Empty", description: "")
        XCTAssertEqual(group.progress, 0.0, accuracy: 0.001)
    }

    func testProgressWithAllCompletedSubtasks() {
        let s1 = AgentSubtask(title: "S1", status: .completed)
        let s2 = AgentSubtask(title: "S2", status: .completed)
        let group = TaskGroup(title: "G", description: "", subtasks: [s1, s2])
        XCTAssertEqual(group.progress, 1.0, accuracy: 0.001)
    }

    func testProgressPartialCompletion() {
        let s1 = AgentSubtask(title: "S1", status: .completed)
        let s2 = AgentSubtask(title: "S2", status: .pending)
        let s3 = AgentSubtask(title: "S3", status: .pending)
        let group = TaskGroup(title: "G", description: "", subtasks: [s1, s2, s3])
        XCTAssertEqual(group.progress, 1.0 / 3.0, accuracy: 0.001)
    }

    func testProgressNoneCompleted() {
        let s1 = AgentSubtask(title: "S1", status: .pending)
        let s2 = AgentSubtask(title: "S2", status: .inProgress)
        let group = TaskGroup(title: "G", description: "", subtasks: [s1, s2])
        XCTAssertEqual(group.progress, 0.0, accuracy: 0.001)
    }

    func testCodableRoundTrip() throws {
        let subtask = AgentSubtask(title: "Sub", description: "desc")
        let group = TaskGroup(
            title: "Round Trip",
            description: "Test",
            subtasks: [subtask],
            status: .inProgress,
            editedFiles: ["foo.swift"]
        )
        let data = try JSONEncoder().encode(group)
        let decoded = try JSONDecoder().decode(TaskGroup.self, from: data)
        XCTAssertEqual(decoded.title, "Round Trip")
        XCTAssertEqual(decoded.status, .inProgress)
        XCTAssertEqual(decoded.editedFiles, ["foo.swift"])
        XCTAssertEqual(decoded.subtasks.count, 1)
    }
}

// MARK: - TaskGroupStatus Tests

final class TaskGroupStatusTests: XCTestCase {

    func testAllStatusValuesHaveRawValues() {
        let statuses: [TaskGroupStatus] = [.pending, .inProgress, .completed, .failed, .cancelled]
        for status in statuses {
            XCTAssertFalse(status.rawValue.isEmpty)
        }
    }

    func testCodable() throws {
        let statuses: [TaskGroupStatus] = [.pending, .inProgress, .completed, .failed, .cancelled]
        for status in statuses {
            let data = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(TaskGroupStatus.self, from: data)
            XCTAssertEqual(decoded, status)
        }
    }
}

// MARK: - AgentSubtask Tests

final class AgentSubtaskTests: XCTestCase {

    func testDefaultInitValues() {
        let subtask = AgentSubtask(title: "My Subtask")
        XCTAssertEqual(subtask.title, "My Subtask")
        XCTAssertTrue(subtask.description.isEmpty)
        XCTAssertEqual(subtask.status, .pending)
        XCTAssertTrue(subtask.steps.isEmpty)
        XCTAssertNil(subtask.completedAt)
    }

    func testCodableRoundTrip() throws {
        let step = AgentStep(action: "Do thing", details: "details", status: .running)
        let subtask = AgentSubtask(title: "ST", description: "desc", status: .inProgress, steps: [step])
        let data = try JSONEncoder().encode(subtask)
        let decoded = try JSONDecoder().decode(AgentSubtask.self, from: data)
        XCTAssertEqual(decoded.title, "ST")
        XCTAssertEqual(decoded.status, .inProgress)
        XCTAssertEqual(decoded.steps.count, 1)
        XCTAssertEqual(decoded.steps.first?.action, "Do thing")
    }
}

// MARK: - AgentStep Tests

final class AgentStepTests: XCTestCase {

    func testDefaultInitValues() {
        let step = AgentStep(action: "Read file")
        XCTAssertEqual(step.action, "Read file")
        XCTAssertNil(step.details)
        XCTAssertEqual(step.status, .pending)
    }

    func testInitWithDetails() {
        let step = AgentStep(action: "Write file", details: "foo.swift", status: .completed)
        XCTAssertEqual(step.details, "foo.swift")
        XCTAssertEqual(step.status, .completed)
    }

    func testCodableRoundTrip() throws {
        let step = AgentStep(action: "Compile", details: nil, status: .running)
        let data = try JSONEncoder().encode(step)
        let decoded = try JSONDecoder().decode(AgentStep.self, from: data)
        XCTAssertEqual(decoded.action, "Compile")
        XCTAssertEqual(decoded.status, .running)
    }
}

// MARK: - AgentModeTask Tests

final class AgentModeTaskTests: XCTestCase {

    func testDefaultInitValues() {
        let task = AgentModeTask(title: "Build feature", userQuery: "Make X", taskType: .codeGeneration)
        XCTAssertEqual(task.title, "Build feature")
        XCTAssertEqual(task.userQuery, "Make X")
        XCTAssertEqual(task.taskType, .codeGeneration)
        XCTAssertEqual(task.mode, .auto)
        XCTAssertEqual(task.status, .running)
        XCTAssertNil(task.completedAt)
    }

    func testCustomInitValues() {
        let task = AgentModeTask(
            title: "Debug",
            userQuery: "Fix crash",
            taskType: .debugging,
            mode: .planning,
            status: .awaitingReview
        )
        XCTAssertEqual(task.mode, .planning)
        XCTAssertEqual(task.status, .awaitingReview)
    }

    func testCodableRoundTrip() throws {
        let task = AgentModeTask(
            title: "Refactor",
            userQuery: "Clean up",
            taskType: .codeRefactoring,
            mode: .fast,
            status: .completed
        )
        let data = try JSONEncoder().encode(task)
        let decoded = try JSONDecoder().decode(AgentModeTask.self, from: data)
        XCTAssertEqual(decoded.title, "Refactor")
        XCTAssertEqual(decoded.mode, .fast)
        XCTAssertEqual(decoded.status, .completed)
    }
}

// MARK: - AgentModeTaskStatus Tests

final class AgentModeTaskStatusTests: XCTestCase {

    func testAllStatusesHaveRawValues() {
        let statuses: [AgentModeTaskStatus] = [.pending, .running, .awaitingReview, .completed, .failed, .cancelled]
        for s in statuses {
            XCTAssertFalse(s.rawValue.isEmpty)
        }
    }
}

// MARK: - AgentModeArtifact Tests

final class AgentModeArtifactTests: XCTestCase {

    func testDefaultInitValues() {
        let artifact = AgentModeArtifact(type: .implementationPlan, title: "Plan", content: "Do X then Y")
        XCTAssertEqual(artifact.type, .implementationPlan)
        XCTAssertEqual(artifact.title, "Plan")
        XCTAssertEqual(artifact.content, "Do X then Y")
        XCTAssertNil(artifact.filePath)
    }

    func testInitWithFilePath() {
        let artifact = AgentModeArtifact(type: .codeSnippet, title: "Snippet", content: "let x = 1", filePath: "/tmp/foo.swift")
        XCTAssertEqual(artifact.filePath, "/tmp/foo.swift")
    }

    func testCodableRoundTrip() throws {
        let artifact = AgentModeArtifact(
            type: .documentation,
            title: "Docs",
            content: "# Title",
            filePath: "/docs/README.md"
        )
        let data = try JSONEncoder().encode(artifact)
        let decoded = try JSONDecoder().decode(AgentModeArtifact.self, from: data)
        XCTAssertEqual(decoded.type, .documentation)
        XCTAssertEqual(decoded.title, "Docs")
        XCTAssertEqual(decoded.filePath, "/docs/README.md")
    }
}

// MARK: - AgentArtifactType Tests

final class AgentArtifactTypeTests: XCTestCase {

    func testAllTypesHaveDisplayNames() {
        for type_ in AgentArtifactType.allCases {
            XCTAssertFalse(type_.displayName.isEmpty, "Missing displayName for \(type_)")
        }
    }

    func testDisplayNamesAreDistinct() {
        let names = AgentArtifactType.allCases.map { $0.displayName }
        XCTAssertEqual(names.count, Set(names).count)
    }

    func testCodable() throws {
        for type_ in AgentArtifactType.allCases {
            let data = try JSONEncoder().encode(type_)
            let decoded = try JSONDecoder().decode(AgentArtifactType.self, from: data)
            XCTAssertEqual(decoded, type_)
        }
    }
}

// MARK: - ArtifactReviewPolicy Tests

final class ArtifactReviewPolicyTests: XCTestCase {

    func testAllPoliciesHaveDisplayNames() {
        for policy in [ArtifactReviewPolicy.alwaysProceed, .requestReview, .reviewPlansOnly] {
            XCTAssertFalse(policy.displayName.isEmpty)
        }
    }

    func testAllPoliciesHaveDescriptions() {
        for policy in [ArtifactReviewPolicy.alwaysProceed, .requestReview, .reviewPlansOnly] {
            XCTAssertFalse(policy.description.isEmpty)
        }
    }

    func testCodable() throws {
        for policy in [ArtifactReviewPolicy.alwaysProceed, .requestReview, .reviewPlansOnly] {
            let data = try JSONEncoder().encode(policy)
            let decoded = try JSONDecoder().decode(ArtifactReviewPolicy.self, from: data)
            XCTAssertEqual(decoded, policy)
        }
    }
}

// MARK: - TerminalExecutionPolicy Tests

final class TerminalExecutionPolicyTests: XCTestCase {

    func testAllPoliciesHaveDisplayNames() {
        for policy in [TerminalExecutionPolicy.requestReview, .alwaysProceed] {
            XCTAssertFalse(policy.displayName.isEmpty)
        }
    }

    func testCodable() throws {
        for policy in [TerminalExecutionPolicy.requestReview, .alwaysProceed] {
            let data = try JSONEncoder().encode(policy)
            let decoded = try JSONDecoder().decode(TerminalExecutionPolicy.self, from: data)
            XCTAssertEqual(decoded, policy)
        }
    }
}

// MARK: - AgentSettings Tests

final class AgentSettingsTests: XCTestCase {

    func testDefaultSettings() {
        let settings = AgentSettings()
        XCTAssertEqual(settings.defaultMode, .auto)
        XCTAssertEqual(settings.artifactReviewPolicy, .reviewPlansOnly)
        XCTAssertEqual(settings.terminalExecutionPolicy, .requestReview)
        XCTAssertFalse(settings.allowedCommands.isEmpty)
        XCTAssertFalse(settings.deniedCommands.isEmpty)
        XCTAssertFalse(settings.nonWorkspaceFileAccess)
    }

    func testDefaultStaticPropertyMatchesInit() {
        let a = AgentSettings.default
        let b = AgentSettings()
        XCTAssertEqual(a.defaultMode, b.defaultMode)
        XCTAssertEqual(a.artifactReviewPolicy, b.artifactReviewPolicy)
        XCTAssertEqual(a.terminalExecutionPolicy, b.terminalExecutionPolicy)
        XCTAssertEqual(a.allowedCommands, b.allowedCommands)
        XCTAssertEqual(a.deniedCommands, b.deniedCommands)
        XCTAssertEqual(a.nonWorkspaceFileAccess, b.nonWorkspaceFileAccess)
    }

    func testCustomSettings() {
        let settings = AgentSettings(
            defaultMode: .planning,
            artifactReviewPolicy: .alwaysProceed,
            terminalExecutionPolicy: .alwaysProceed,
            allowedCommands: ["echo"],
            deniedCommands: ["sudo"],
            nonWorkspaceFileAccess: true
        )
        XCTAssertEqual(settings.defaultMode, .planning)
        XCTAssertEqual(settings.artifactReviewPolicy, .alwaysProceed)
        XCTAssertTrue(settings.nonWorkspaceFileAccess)
        XCTAssertEqual(settings.allowedCommands, ["echo"])
        XCTAssertEqual(settings.deniedCommands, ["sudo"])
    }

    func testCodableRoundTrip() throws {
        let settings = AgentSettings(
            defaultMode: .fast,
            artifactReviewPolicy: .requestReview,
            terminalExecutionPolicy: .requestReview,
            allowedCommands: ["ls", "pwd"],
            deniedCommands: ["rm -rf"],
            nonWorkspaceFileAccess: false
        )
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AgentSettings.self, from: data)
        XCTAssertEqual(decoded.defaultMode, .fast)
        XCTAssertEqual(decoded.artifactReviewPolicy, .requestReview)
        XCTAssertEqual(decoded.allowedCommands, ["ls", "pwd"])
    }
}
