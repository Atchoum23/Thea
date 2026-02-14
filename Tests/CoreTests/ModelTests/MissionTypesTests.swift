// MissionTypesTests.swift
// Tests for MissionOrchestrator types: Mission, Phase, Step, Report, Analysis

import Testing
import Foundation

// MARK: - Test Doubles: MissionPriority

private enum TestMissionPriority: String, Codable, Sendable {
    case low, normal, high, critical
}

// MARK: - Test Doubles: MissionStatus

private enum TestMissionStatus: String, Codable, Sendable, CaseIterable {
    case planned, running, paused, completed, failed, cancelled

    var isTerminal: Bool {
        switch self {
        case .completed, .failed, .cancelled: return true
        default: return false
        }
    }
}

// MARK: - Test Doubles: PhaseStatus

private enum TestPhaseStatus: String, Codable, Sendable, CaseIterable {
    case pending, running, completed, failed, skipped

    var isTerminal: Bool {
        switch self {
        case .completed, .failed, .skipped: return true
        default: return false
        }
    }
}

// MARK: - Test Doubles: StepStatus

private enum TestStepStatus: String, Codable, Sendable, CaseIterable {
    case pending, running, completed, failed, skipped
}

// MARK: - Test Doubles: StepType

private enum TestStepType: String, Codable, Sendable, CaseIterable {
    case validation, resourceGathering, checkpoint, planning
    case codeGeneration, codeModification, fileOperation
    case dataCollection, processing, aiAnalysis
    case building, testing, deployment, reporting, cleanup, execution
}

// MARK: - Test Doubles: MissionComplexity

private enum TestMissionComplexity: String, Codable, Sendable, CaseIterable {
    case simple, moderate, complex, epic

    var estimatedPhases: Int {
        switch self {
        case .simple: return 1
        case .moderate: return 3
        case .complex: return 5
        case .epic: return 10
        }
    }
}

// MARK: - Test Doubles: LogLevel

private enum TestLogLevel: String, Codable, Sendable, CaseIterable {
    case info, success, warning, error
}

// MARK: - Test Doubles: MissionContext

private struct TestMissionContext: Codable, Sendable {
    var priority: TestMissionPriority = .normal
    var deadline: Date?
    var constraints: [String] = []
    var preferences: [String: String] = [:]
}

// MARK: - Test Doubles: GoalComponent

private struct TestGoalComponent: Identifiable, Codable, Sendable {
    let id: UUID
    let action: String
    let target: String
    let details: String?

    init(id: UUID = UUID(), action: String, target: String, details: String? = nil) {
        self.id = id
        self.action = action
        self.target = target
        self.details = details
    }
}

// MARK: - Test Doubles: RequiredCapability

private struct TestRequiredCapability: Codable, Sendable {
    let name: String
    let importance: Importance

    enum Importance: String, Codable, Sendable {
        case critical, normal, optional
    }
}

// MARK: - Test Doubles: DependencyType

private enum TestDependencyType: String, Codable, Sendable {
    case sequential, parallel, conditional
}

// MARK: - Test Doubles: ComponentDependency

private struct TestComponentDependency: Codable, Sendable {
    let from: UUID
    let to: UUID
    let type: TestDependencyType
}

// MARK: - Test Doubles: FeasibilityAssessment

private struct TestFeasibilityAssessment: Codable, Sendable {
    var feasible: Bool
    var confidence: Double
    var blockers: [String]
    var recommendations: [String]
}

// MARK: - Test Doubles: MissionAnalysis

private struct TestMissionAnalysis: Codable, Sendable {
    var components: [TestGoalComponent]
    var capabilities: [TestRequiredCapability]
    var complexity: TestMissionComplexity
    var dependencies: [TestComponentDependency]
    var feasibility: TestFeasibilityAssessment
    var estimatedDuration: TimeInterval
}

// MARK: - Test Doubles: MissionLog

private struct TestMissionLog: Identifiable, Codable, Sendable {
    let id: UUID
    let timestamp: Date
    let level: TestLogLevel
    let message: String
    let phase: String?
    let step: String?

    init(id: UUID = UUID(), timestamp: Date = Date(), level: TestLogLevel, message: String, phase: String? = nil, step: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.message = message
        self.phase = phase
        self.step = step
    }
}

// MARK: - Test Doubles: MissionReport

private struct TestMissionReport: Codable, Sendable {
    let missionId: UUID
    let goal: String
    let status: TestMissionStatus
    let phasesCompleted: Int
    let totalPhases: Int
    let duration: TimeInterval?
    let logs: [TestMissionLog]
    let generatedAt: Date

    var completionPercentage: Double {
        guard totalPhases > 0 else { return 0 }
        return Double(phasesCompleted) / Double(totalPhases) * 100
    }
}

// MARK: - Test Doubles: MissionError

private enum TestMissionError: Error, LocalizedError, Sendable {
    case missionAlreadyActive
    case validationFailed(String)
    case phaseExecutionFailed(String)
    case stepExecutionFailed(String)
    case checkpointRestoreFailed

    var errorDescription: String? {
        switch self {
        case .missionAlreadyActive: return "A mission is already active"
        case .validationFailed(let msg): return "Validation failed: \(msg)"
        case .phaseExecutionFailed(let msg): return "Phase execution failed: \(msg)"
        case .stepExecutionFailed(let msg): return "Step execution failed: \(msg)"
        case .checkpointRestoreFailed: return "Failed to restore from checkpoint"
        }
    }
}

// MARK: - Tests: MissionStatus

@Suite("Mission Status")
struct MissionStatusTests {
    @Test("All cases exist")
    func allCases() {
        #expect(TestMissionStatus.allCases.count == 6)
    }

    @Test("Terminal states")
    func terminalStates() {
        #expect(TestMissionStatus.completed.isTerminal)
        #expect(TestMissionStatus.failed.isTerminal)
        #expect(TestMissionStatus.cancelled.isTerminal)
    }

    @Test("Non-terminal states")
    func nonTerminalStates() {
        #expect(!TestMissionStatus.planned.isTerminal)
        #expect(!TestMissionStatus.running.isTerminal)
        #expect(!TestMissionStatus.paused.isTerminal)
    }

    @Test("Codable roundtrip")
    func codable() throws {
        for status in TestMissionStatus.allCases {
            let data = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(TestMissionStatus.self, from: data)
            #expect(decoded == status)
        }
    }
}

// MARK: - Tests: PhaseStatus

@Suite("Phase Status")
struct PhaseStatusTests {
    @Test("All cases exist")
    func allCases() {
        #expect(TestPhaseStatus.allCases.count == 5)
    }

    @Test("Terminal states")
    func terminalStates() {
        #expect(TestPhaseStatus.completed.isTerminal)
        #expect(TestPhaseStatus.failed.isTerminal)
        #expect(TestPhaseStatus.skipped.isTerminal)
    }

    @Test("Non-terminal states")
    func nonTerminalStates() {
        #expect(!TestPhaseStatus.pending.isTerminal)
        #expect(!TestPhaseStatus.running.isTerminal)
    }
}

// MARK: - Tests: StepType

@Suite("Step Type")
struct StepTypeTests {
    @Test("All step types exist")
    func allCases() {
        #expect(TestStepType.allCases.count == 16)
    }

    @Test("Raw values are unique")
    func uniqueRawValues() {
        let rawValues = Set(TestStepType.allCases.map(\.rawValue))
        #expect(rawValues.count == TestStepType.allCases.count)
    }

    @Test("Codable roundtrip")
    func codable() throws {
        for stepType in TestStepType.allCases {
            let data = try JSONEncoder().encode(stepType)
            let decoded = try JSONDecoder().decode(TestStepType.self, from: data)
            #expect(decoded == stepType)
        }
    }
}

// MARK: - Tests: MissionComplexity

@Suite("Mission Complexity")
struct MissionComplexityTests {
    @Test("Estimated phases increase with complexity")
    func phasesIncrease() {
        #expect(TestMissionComplexity.simple.estimatedPhases < TestMissionComplexity.moderate.estimatedPhases)
        #expect(TestMissionComplexity.moderate.estimatedPhases < TestMissionComplexity.complex.estimatedPhases)
        #expect(TestMissionComplexity.complex.estimatedPhases < TestMissionComplexity.epic.estimatedPhases)
    }

    @Test("Simple has 1 phase")
    func simplePhases() {
        #expect(TestMissionComplexity.simple.estimatedPhases == 1)
    }

    @Test("Epic has many phases")
    func epicPhases() {
        #expect(TestMissionComplexity.epic.estimatedPhases >= 10)
    }
}

// MARK: - Tests: LogLevel

@Suite("Log Level")
struct LogLevelTests {
    @Test("All cases exist")
    func allCases() {
        #expect(TestLogLevel.allCases.count == 4)
    }

    @Test("Raw values are unique")
    func uniqueRawValues() {
        let rawValues = Set(TestLogLevel.allCases.map(\.rawValue))
        #expect(rawValues.count == TestLogLevel.allCases.count)
    }
}

// MARK: - Tests: MissionContext

@Suite("Mission Context")
struct MissionContextTests {
    @Test("Default context")
    func defaults() {
        let ctx = TestMissionContext()
        #expect(ctx.priority == .normal)
        #expect(ctx.deadline == nil)
        #expect(ctx.constraints.isEmpty)
        #expect(ctx.preferences.isEmpty)
    }

    @Test("Custom context")
    func custom() {
        let deadline = Date().addingTimeInterval(3600)
        let ctx = TestMissionContext(priority: .critical, deadline: deadline, constraints: ["no_network"], preferences: ["lang": "swift"])
        #expect(ctx.priority == .critical)
        #expect(ctx.deadline != nil)
        #expect(ctx.constraints.count == 1)
        #expect(ctx.preferences["lang"] == "swift")
    }

    @Test("Codable roundtrip")
    func codable() throws {
        let ctx = TestMissionContext(priority: .high, constraints: ["fast"])
        let data = try JSONEncoder().encode(ctx)
        let decoded = try JSONDecoder().decode(TestMissionContext.self, from: data)
        #expect(decoded.priority == .high)
        #expect(decoded.constraints == ["fast"])
    }
}

// MARK: - Tests: GoalComponent

@Suite("Goal Component")
struct GoalComponentTests {
    @Test("Creation")
    func creation() {
        let gc = TestGoalComponent(action: "create", target: "file", details: "at path /tmp/test")
        #expect(gc.action == "create")
        #expect(gc.target == "file")
        #expect(gc.details == "at path /tmp/test")
    }

    @Test("Identifiable")
    func identifiable() {
        let gc1 = TestGoalComponent(action: "a", target: "t1")
        let gc2 = TestGoalComponent(action: "a", target: "t2")
        #expect(gc1.id != gc2.id)
    }

    @Test("Codable roundtrip")
    func codable() throws {
        let gc = TestGoalComponent(action: "build", target: "project")
        let data = try JSONEncoder().encode(gc)
        let decoded = try JSONDecoder().decode(TestGoalComponent.self, from: data)
        #expect(decoded.action == "build")
    }
}

// MARK: - Tests: RequiredCapability

@Suite("Required Capability")
struct RequiredCapabilityTests {
    @Test("Importance levels")
    func importanceLevels() {
        let cap = TestRequiredCapability(name: "code_gen", importance: .critical)
        #expect(cap.importance == .critical)
    }

    @Test("Codable roundtrip")
    func codable() throws {
        let cap = TestRequiredCapability(name: "search", importance: .normal)
        let data = try JSONEncoder().encode(cap)
        let decoded = try JSONDecoder().decode(TestRequiredCapability.self, from: data)
        #expect(decoded.name == "search")
        #expect(decoded.importance == .normal)
    }
}

// MARK: - Tests: FeasibilityAssessment

@Suite("Feasibility Assessment")
struct FeasibilityAssessmentTests {
    @Test("Feasible with high confidence")
    func feasibleHighConf() {
        let assessment = TestFeasibilityAssessment(feasible: true, confidence: 0.95, blockers: [], recommendations: [])
        #expect(assessment.feasible)
        #expect(assessment.confidence > 0.9)
        #expect(assessment.blockers.isEmpty)
    }

    @Test("Not feasible with blockers")
    func notFeasible() {
        let assessment = TestFeasibilityAssessment(feasible: false, confidence: 0.3, blockers: ["no API key", "rate limited"], recommendations: ["add API key"])
        #expect(!assessment.feasible)
        #expect(assessment.blockers.count == 2)
        #expect(!assessment.recommendations.isEmpty)
    }

    @Test("Codable roundtrip")
    func codable() throws {
        let assessment = TestFeasibilityAssessment(feasible: true, confidence: 0.8, blockers: [], recommendations: ["use cache"])
        let data = try JSONEncoder().encode(assessment)
        let decoded = try JSONDecoder().decode(TestFeasibilityAssessment.self, from: data)
        #expect(decoded.feasible)
        #expect(decoded.confidence == 0.8)
    }
}

// MARK: - Tests: MissionLog

@Suite("Mission Log")
struct MissionLogTests {
    @Test("Creation with defaults")
    func defaults() {
        let log = TestMissionLog(level: .info, message: "Starting mission")
        #expect(log.level == .info)
        #expect(log.message == "Starting mission")
        #expect(log.phase == nil)
        #expect(log.step == nil)
    }

    @Test("Creation with phase and step")
    func withContext() {
        let log = TestMissionLog(level: .error, message: "Build failed", phase: "build", step: "compile")
        #expect(log.phase == "build")
        #expect(log.step == "compile")
    }

    @Test("Identifiable — unique IDs")
    func identifiable() {
        let log1 = TestMissionLog(level: .info, message: "a")
        let log2 = TestMissionLog(level: .info, message: "b")
        #expect(log1.id != log2.id)
    }

    @Test("Codable roundtrip")
    func codable() throws {
        let log = TestMissionLog(level: .warning, message: "Slow response", phase: "analysis")
        let data = try JSONEncoder().encode(log)
        let decoded = try JSONDecoder().decode(TestMissionLog.self, from: data)
        #expect(decoded.level == .warning)
        #expect(decoded.message == "Slow response")
    }
}

// MARK: - Tests: MissionReport

@Suite("Mission Report")
struct MissionReportTests {
    @Test("Completion percentage: zero phases")
    func zeroPhasesPercentage() {
        let report = TestMissionReport(missionId: UUID(), goal: "test", status: .planned, phasesCompleted: 0, totalPhases: 0, duration: nil, logs: [], generatedAt: Date())
        #expect(report.completionPercentage == 0)
    }

    @Test("Completion percentage: partial")
    func partialPercentage() {
        let report = TestMissionReport(missionId: UUID(), goal: "build app", status: .running, phasesCompleted: 3, totalPhases: 10, duration: nil, logs: [], generatedAt: Date())
        #expect(report.completionPercentage == 30)
    }

    @Test("Completion percentage: complete")
    func completePercentage() {
        let report = TestMissionReport(missionId: UUID(), goal: "deploy", status: .completed, phasesCompleted: 5, totalPhases: 5, duration: 120.0, logs: [], generatedAt: Date())
        #expect(report.completionPercentage == 100)
    }

    @Test("Report with logs")
    func withLogs() {
        let logs = [
            TestMissionLog(level: .info, message: "Started"),
            TestMissionLog(level: .success, message: "Phase 1 done"),
            TestMissionLog(level: .error, message: "Phase 2 failed")
        ]
        let report = TestMissionReport(missionId: UUID(), goal: "test", status: .failed, phasesCompleted: 1, totalPhases: 3, duration: 60.0, logs: logs, generatedAt: Date())
        #expect(report.logs.count == 3)
        #expect(report.status == .failed)
    }
}

// MARK: - Tests: MissionError

@Suite("Mission Error")
struct MissionErrorTests {
    @Test("All errors have descriptions")
    func descriptions() {
        let errors: [TestMissionError] = [
            .missionAlreadyActive,
            .validationFailed("invalid goal"),
            .phaseExecutionFailed("timeout"),
            .stepExecutionFailed("permission denied"),
            .checkpointRestoreFailed
        ]
        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }

    @Test("Validation failed includes message")
    func validationMsg() {
        let error = TestMissionError.validationFailed("empty goal")
        #expect(error.errorDescription!.contains("empty goal"))
    }

    @Test("Phase execution failed includes message")
    func phaseMsg() {
        let error = TestMissionError.phaseExecutionFailed("resource exhausted")
        #expect(error.errorDescription!.contains("resource exhausted"))
    }

    @Test("Descriptions are unique")
    func uniqueDescriptions() {
        let errors: [TestMissionError] = [.missionAlreadyActive, .validationFailed("x"), .phaseExecutionFailed("y"), .stepExecutionFailed("z"), .checkpointRestoreFailed]
        let descs = Set(errors.compactMap(\.errorDescription))
        #expect(descs.count == errors.count)
    }
}

// MARK: - Tests: ComponentDependency

@Suite("Component Dependency")
struct ComponentDependencyTests {
    @Test("Sequential dependency")
    func sequential() {
        let a = UUID()
        let b = UUID()
        let dep = TestComponentDependency(from: a, to: b, type: .sequential)
        #expect(dep.type == .sequential)
        #expect(dep.from == a)
        #expect(dep.to == b)
    }

    @Test("Parallel dependency")
    func parallel() {
        let dep = TestComponentDependency(from: UUID(), to: UUID(), type: .parallel)
        #expect(dep.type == .parallel)
    }

    @Test("Conditional dependency")
    func conditional() {
        let dep = TestComponentDependency(from: UUID(), to: UUID(), type: .conditional)
        #expect(dep.type == .conditional)
    }

    @Test("Codable roundtrip")
    func codable() throws {
        let dep = TestComponentDependency(from: UUID(), to: UUID(), type: .sequential)
        let data = try JSONEncoder().encode(dep)
        let decoded = try JSONDecoder().decode(TestComponentDependency.self, from: data)
        #expect(decoded.type == .sequential)
    }
}
