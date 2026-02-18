// MissionOrchestratorExtendedTests.swift
// Tests for MissionOrchestrator types — mission context, analysis, phases, steps, reports

import Testing
import Foundation

// MARK: - Mission Test Doubles

private struct TestMissionContext: Codable, Sendable {
    var priority: TestMissionPriority = .normal
    var deadline: Date?
    var constraints: [String] = []
    var preferences: [String: String] = [:]
}

private enum TestMissionPriority: String, Codable, Sendable, CaseIterable {
    case low, normal, high, critical
}

private enum TestMissionStatus: String, Codable, Sendable, CaseIterable {
    case planned, running, paused, completed, failed, cancelled

    var isTerminal: Bool {
        switch self {
        case .completed, .failed, .cancelled: true
        default: false
        }
    }

    var isActive: Bool {
        switch self {
        case .running, .paused: true
        default: false
        }
    }
}

private enum TestMissionComplexity: String, Codable, Sendable, CaseIterable {
    case simple, moderate, complex, epic
}

private struct TestGoalComponent: Identifiable, Codable, Sendable {
    var id = UUID()
    let action: String
    let target: String
    let details: String?
}

private struct TestRequiredCapability: Codable, Sendable {
    let name: String
    let importance: CapabilityImportance

    enum CapabilityImportance: String, Codable, Sendable, CaseIterable {
        case critical, normal, optional
    }
}

private struct TestComponentDependency: Codable, Sendable {
    let from: UUID
    let to: UUID
    let type: DependencyType

    enum DependencyType: String, Codable, Sendable, CaseIterable {
        case sequential, parallel, conditional
    }
}

private struct TestFeasibilityAssessment: Codable, Sendable {
    let feasible: Bool
    let confidence: Double
    let blockers: [String]
    let recommendations: [String]
}

private enum TestPhaseStatus: String, Codable, Sendable, CaseIterable {
    case pending, running, completed, failed, skipped
}

private enum TestStepType: String, Codable, Sendable, CaseIterable {
    case validation, resourceGathering, checkpoint, planning
    case codeGeneration, codeModification, fileOperation
    case dataCollection, processing, aiAnalysis
    case building, testing, deployment
    case reporting, cleanup, execution
}

private enum TestStepStatus: String, Codable, Sendable, CaseIterable {
    case pending, running, completed, failed, skipped
}

private struct TestMissionLog: Identifiable, Codable, Sendable {
    var id = UUID()
    let timestamp: Date
    let level: TestLogLevel
    let message: String
    let phase: String?
    let step: String?
}

private enum TestLogLevel: String, Codable, Sendable, CaseIterable {
    case info, success, warning, error
}

private struct TestMissionReport: Codable, Sendable {
    let missionId: UUID
    let goal: String
    let status: TestMissionStatus
    let phasesCompleted: Int
    let totalPhases: Int
    let duration: TimeInterval?
    let logs: [TestMissionLog]
    let generatedAt: Date
}

private enum TestMissionError: Error, LocalizedError {
    case missionAlreadyActive
    case validationFailed(String)
    case phaseExecutionFailed(String)
    case stepExecutionFailed(String)
    case checkpointRestoreFailed

    var errorDescription: String? {
        switch self {
        case .missionAlreadyActive: "A mission is already active"
        case let .validationFailed(reason): "Validation failed: \(reason)"
        case let .phaseExecutionFailed(reason): "Phase execution failed: \(reason)"
        case let .stepExecutionFailed(reason): "Step execution failed: \(reason)"
        case .checkpointRestoreFailed: "Failed to restore from checkpoint"
        }
    }
}

// MARK: - Mission Priority Tests

@Suite("Mission Priority — Cases")
struct MissionPriorityExtendedTests {
    @Test("All 4 priorities exist")
    func allCases() {
        #expect(TestMissionPriority.allCases.count == 4)
    }

    @Test("Priority Codable roundtrip")
    func codableRoundtrip() throws {
        for priority in TestMissionPriority.allCases {
            let data = try JSONEncoder().encode(priority)
            let decoded = try JSONDecoder().decode(TestMissionPriority.self, from: data)
            #expect(decoded == priority)
        }
    }

    @Test("Priorities have expected raw values")
    func rawValues() {
        #expect(TestMissionPriority.low.rawValue == "low")
        #expect(TestMissionPriority.critical.rawValue == "critical")
    }
}

// MARK: - Mission Status Tests

@Suite("Mission Status — Lifecycle")
struct MissionStatusExtTests {
    @Test("All 6 statuses exist")
    func allCases() {
        #expect(TestMissionStatus.allCases.count == 6)
    }

    @Test("Terminal statuses: completed, failed, cancelled")
    func terminalStatuses() {
        #expect(TestMissionStatus.completed.isTerminal)
        #expect(TestMissionStatus.failed.isTerminal)
        #expect(TestMissionStatus.cancelled.isTerminal)
    }

    @Test("Non-terminal statuses: planned, running, paused")
    func nonTerminalStatuses() {
        #expect(!TestMissionStatus.planned.isTerminal)
        #expect(!TestMissionStatus.running.isTerminal)
        #expect(!TestMissionStatus.paused.isTerminal)
    }

    @Test("Active statuses: running, paused")
    func activeStatuses() {
        #expect(TestMissionStatus.running.isActive)
        #expect(TestMissionStatus.paused.isActive)
    }

    @Test("Inactive statuses: planned, completed, failed, cancelled")
    func inactiveStatuses() {
        #expect(!TestMissionStatus.planned.isActive)
        #expect(!TestMissionStatus.completed.isActive)
        #expect(!TestMissionStatus.failed.isActive)
        #expect(!TestMissionStatus.cancelled.isActive)
    }

    @Test("Status Codable roundtrip")
    func codableRoundtrip() throws {
        for status in TestMissionStatus.allCases {
            let data = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(TestMissionStatus.self, from: data)
            #expect(decoded == status)
        }
    }
}

// MARK: - Mission Complexity Tests

@Suite("Mission Complexity — Cases")
struct MissionComplexityExtTests {
    @Test("All 4 complexity levels exist")
    func allCases() {
        #expect(TestMissionComplexity.allCases.count == 4)
    }

    @Test("Complexity Codable roundtrip")
    func codableRoundtrip() throws {
        for complexity in TestMissionComplexity.allCases {
            let data = try JSONEncoder().encode(complexity)
            let decoded = try JSONDecoder().decode(TestMissionComplexity.self, from: data)
            #expect(decoded == complexity)
        }
    }
}

// MARK: - Mission Context Tests

@Suite("Mission Context — Defaults")
struct MissionContextExtTests {
    @Test("Default context has normal priority")
    func defaultPriority() {
        let ctx = TestMissionContext()
        #expect(ctx.priority == .normal)
    }

    @Test("Default context has no deadline")
    func noDeadline() {
        let ctx = TestMissionContext()
        #expect(ctx.deadline == nil)
    }

    @Test("Default context has empty constraints")
    func emptyConstraints() {
        let ctx = TestMissionContext()
        #expect(ctx.constraints.isEmpty)
    }

    @Test("Context with constraints and preferences")
    func withConstraints() {
        var ctx = TestMissionContext()
        ctx.priority = .critical
        ctx.constraints = ["No network", "Read-only"]
        ctx.preferences = ["language": "Swift"]
        #expect(ctx.priority == .critical)
        #expect(ctx.constraints.count == 2)
        #expect(ctx.preferences["language"] == "Swift")
    }

    @Test("Context Codable roundtrip")
    func codableRoundtrip() throws {
        var ctx = TestMissionContext()
        ctx.priority = .high
        ctx.constraints = ["Constraint A"]
        let data = try JSONEncoder().encode(ctx)
        let decoded = try JSONDecoder().decode(TestMissionContext.self, from: data)
        #expect(decoded.priority == .high)
        #expect(decoded.constraints == ["Constraint A"])
    }
}

// MARK: - Goal Component Tests

@Suite("Goal Component — Construction")
struct GoalComponentExtTests {
    @Test("Component has unique ID")
    func uniqueID() {
        let a = TestGoalComponent(action: "refactor", target: "auth module", details: nil)
        let b = TestGoalComponent(action: "refactor", target: "auth module", details: nil)
        #expect(a.id != b.id)
    }

    @Test("Component with details")
    func withDetails() {
        let comp = TestGoalComponent(action: "add", target: "validation", details: "Input sanitization")
        #expect(comp.details == "Input sanitization")
    }

    @Test("Component Codable roundtrip")
    func codableRoundtrip() throws {
        let comp = TestGoalComponent(action: "test", target: "login", details: "Unit tests")
        let data = try JSONEncoder().encode(comp)
        let decoded = try JSONDecoder().decode(TestGoalComponent.self, from: data)
        #expect(decoded.action == "test")
        #expect(decoded.target == "login")
    }
}

// MARK: - Required Capability Tests

@Suite("Required Capability — Importance")
struct RequiredCapabilityExtTests {
    @Test("All 3 importance levels exist")
    func allImportances() {
        #expect(TestRequiredCapability.CapabilityImportance.allCases.count == 3)
    }

    @Test("Capability with critical importance")
    func criticalCapability() {
        let cap = TestRequiredCapability(name: "Network access", importance: .critical)
        #expect(cap.importance == .critical)
    }

    @Test("Capability Codable roundtrip")
    func codableRoundtrip() throws {
        let cap = TestRequiredCapability(name: "GPU", importance: .optional)
        let data = try JSONEncoder().encode(cap)
        let decoded = try JSONDecoder().decode(TestRequiredCapability.self, from: data)
        #expect(decoded.name == "GPU")
        #expect(decoded.importance == .optional)
    }
}

// MARK: - Component Dependency Tests

@Suite("Component Dependency — Types")
struct ComponentDependencyExtTests {
    @Test("All 3 dependency types exist")
    func allTypes() {
        #expect(TestComponentDependency.DependencyType.allCases.count == 3)
    }

    @Test("Sequential dependency")
    func sequential() {
        let a = UUID(), b = UUID()
        let dep = TestComponentDependency(from: a, to: b, type: .sequential)
        #expect(dep.from == a)
        #expect(dep.to == b)
        #expect(dep.type == .sequential)
    }
}

// MARK: - Feasibility Assessment Tests

@Suite("Feasibility Assessment — Evaluation")
struct FeasibilityAssessmentExtTests {
    @Test("Feasible assessment with high confidence")
    func feasibleHighConfidence() {
        let assessment = TestFeasibilityAssessment(feasible: true, confidence: 0.95, blockers: [], recommendations: [])
        #expect(assessment.feasible)
        #expect(assessment.confidence > 0.9)
        #expect(assessment.blockers.isEmpty)
    }

    @Test("Infeasible assessment with blockers")
    func infeasibleWithBlockers() {
        let assessment = TestFeasibilityAssessment(
            feasible: false, confidence: 0.3,
            blockers: ["Missing API key", "Network unavailable"],
            recommendations: ["Configure API key in settings"]
        )
        #expect(!assessment.feasible)
        #expect(assessment.blockers.count == 2)
        #expect(assessment.recommendations.count == 1)
    }
}

// MARK: - Phase & Step Status Tests

@Suite("Phase Status — Cases")
struct PhaseStatusExtTests {
    @Test("All 5 phase statuses exist")
    func allCases() { #expect(TestPhaseStatus.allCases.count == 5) }

    @Test("Phase status Codable")
    func codable() throws {
        for status in TestPhaseStatus.allCases {
            let data = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(TestPhaseStatus.self, from: data)
            #expect(decoded == status)
        }
    }
}

@Suite("Step Type — Completeness")
struct StepTypeExtTests {
    @Test("All 16 step types exist")
    func allCases() { #expect(TestStepType.allCases.count == 16) }

    @Test("All step types have unique raw values")
    func uniqueRawValues() {
        let rawValues = Set(TestStepType.allCases.map(\.rawValue))
        #expect(rawValues.count == 16)
    }
}

@Suite("Step Status — Cases")
struct StepStatusExtTests {
    @Test("All 5 step statuses exist")
    func allCases() { #expect(TestStepStatus.allCases.count == 5) }
}

// MARK: - Log Level Tests

@Suite("Log Level — Cases")
struct LogLevelExtTests {
    @Test("All 4 log levels exist")
    func allCases() { #expect(TestLogLevel.allCases.count == 4) }

    @Test("Log level Codable roundtrip")
    func codable() throws {
        for level in TestLogLevel.allCases {
            let data = try JSONEncoder().encode(level)
            let decoded = try JSONDecoder().decode(TestLogLevel.self, from: data)
            #expect(decoded == level)
        }
    }
}

// MARK: - Mission Log Tests

@Suite("Mission Log — Construction")
struct MissionLogExtTests {
    @Test("Log with phase and step")
    func fullLog() {
        let log = TestMissionLog(timestamp: Date(), level: .error, message: "Build failed",
                                 phase: "Build Phase", step: "Compile")
        #expect(log.level == .error)
        #expect(log.phase == "Build Phase")
        #expect(log.step == "Compile")
    }

    @Test("Log without phase or step")
    func minimalLog() {
        let log = TestMissionLog(timestamp: Date(), level: .info, message: "Starting mission",
                                 phase: nil, step: nil)
        #expect(log.phase == nil)
        #expect(log.step == nil)
    }

    @Test("Log Codable roundtrip")
    func codable() throws {
        let log = TestMissionLog(timestamp: Date(), level: .success, message: "Done", phase: "P1", step: nil)
        let data = try JSONEncoder().encode(log)
        let decoded = try JSONDecoder().decode(TestMissionLog.self, from: data)
        #expect(decoded.level == .success)
        #expect(decoded.message == "Done")
    }
}

// MARK: - Mission Report Tests

@Suite("Mission Report — Summary")
struct MissionReportExtTests {
    @Test("Completed report with all phases done")
    func completedReport() {
        let report = TestMissionReport(
            missionId: UUID(), goal: "Refactor auth", status: .completed,
            phasesCompleted: 3, totalPhases: 3, duration: 120.0,
            logs: [], generatedAt: Date()
        )
        #expect(report.phasesCompleted == report.totalPhases)
        #expect(report.status == .completed)
        #expect(report.duration == 120.0)
    }

    @Test("Failed report with partial completion")
    func failedReport() {
        let report = TestMissionReport(
            missionId: UUID(), goal: "Deploy", status: .failed,
            phasesCompleted: 1, totalPhases: 4, duration: 30.0,
            logs: [TestMissionLog(timestamp: Date(), level: .error, message: "Deploy failed", phase: "Deploy", step: nil)],
            generatedAt: Date()
        )
        #expect(report.phasesCompleted < report.totalPhases)
        #expect(report.status.isTerminal)
        #expect(report.logs.count == 1)
    }
}

// MARK: - Mission Error Tests

@Suite("Mission Error — Descriptions")
struct MissionErrorExtTests {
    @Test("missionAlreadyActive description")
    func alreadyActive() {
        let error = TestMissionError.missionAlreadyActive
        #expect(error.errorDescription == "A mission is already active")
    }

    @Test("validationFailed includes reason")
    func validationFailed() {
        let error = TestMissionError.validationFailed("missing input")
        #expect(error.errorDescription?.contains("missing input") == true)
    }

    @Test("phaseExecutionFailed includes reason")
    func phaseFailed() {
        let error = TestMissionError.phaseExecutionFailed("timeout")
        #expect(error.errorDescription?.contains("timeout") == true)
    }

    @Test("stepExecutionFailed includes reason")
    func stepFailed() {
        let error = TestMissionError.stepExecutionFailed("build error")
        #expect(error.errorDescription?.contains("build error") == true)
    }

    @Test("checkpointRestoreFailed description")
    func checkpointFailed() {
        let error = TestMissionError.checkpointRestoreFailed
        #expect(error.errorDescription == "Failed to restore from checkpoint")
    }

    @Test("All errors have non-nil descriptions")
    func allDescriptions() {
        let errors: [TestMissionError] = [
            .missionAlreadyActive, .validationFailed("x"),
            .phaseExecutionFailed("y"), .stepExecutionFailed("z"),
            .checkpointRestoreFailed
        ]
        for error in errors {
            #expect(error.errorDescription != nil)
        }
    }
}
