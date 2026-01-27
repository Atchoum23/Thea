// MissionOrchestrator.swift
// Autonomous multi-phase mission execution engine

import Combine
import Foundation
import OSLog

// MARK: - Mission Orchestrator

/// Orchestrates complex, multi-phase autonomous missions
@MainActor
public final class MissionOrchestrator: ObservableObject {
    public static let shared = MissionOrchestrator()

    private let logger = Logger(subsystem: "com.thea.app", category: "Mission")
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Published State

    @Published public private(set) var activeMission: Mission?
    @Published public private(set) var missionHistory: [Mission] = []
    @Published public private(set) var currentPhase: MissionPhase?
    @Published public private(set) var currentStep: MissionStep?
    @Published public private(set) var overallProgress: Double = 0
    @Published public private(set) var isPaused = false
    @Published public private(set) var logs: [MissionLog] = []

    // MARK: - Execution State

    private var executionTask: Task<Void, Error>?
    private var checkpointData: [String: Any] = [:]
    private var retryCount: [String: Int] = [:]
    private let maxRetries = 3

    // MARK: - Initialization

    private init() {
        loadMissionHistory()
    }

    // MARK: - Mission Creation

    /// Create a mission from a high-level goal
    public func createMission(goal: String, context: MissionContext? = nil) async throws -> Mission {
        log(.info, "Creating mission: \(goal)")

        // Analyze the goal
        let analysis = try await analyzeGoal(goal)

        // Plan phases
        let phases = try await planPhases(for: analysis)

        // Create mission
        let mission = Mission(
            id: UUID(),
            goal: goal,
            context: context ?? MissionContext(),
            analysis: analysis,
            phases: phases,
            status: .planned,
            createdAt: Date()
        )

        log(.success, "Mission planned with \(phases.count) phases")

        return mission
    }

    // MARK: - Goal Analysis

    private func analyzeGoal(_ goal: String) async throws -> MissionAnalysis {
        log(.info, "Analyzing goal...")

        // Break down the goal into components
        let components = extractComponents(from: goal)

        // Identify required capabilities
        let capabilities = identifyCapabilities(for: components)

        // Estimate complexity
        let complexity = estimateComplexity(components: components, capabilities: capabilities)

        // Identify dependencies
        let dependencies = identifyDependencies(components)

        // Assess feasibility
        let feasibility = assessFeasibility(capabilities: capabilities)

        return MissionAnalysis(
            components: components,
            capabilities: capabilities,
            complexity: complexity,
            dependencies: dependencies,
            feasibility: feasibility,
            estimatedDuration: estimateDuration(complexity: complexity, phases: components.count)
        )
    }

    private func extractComponents(from goal: String) -> [GoalComponent] {
        // Use NLP to extract key components
        var components: [GoalComponent] = []

        // Action keywords
        let actionKeywords = ["create", "build", "implement", "design", "analyze", "fix", "update", "deploy", "test", "optimize"]
        let targetKeywords = ["feature", "system", "api", "ui", "database", "service", "module", "integration"]

        let words = goal.lowercased().split(separator: " ").map { String($0) }

        var currentAction: String?
        var currentTarget: String?

        for word in words {
            if actionKeywords.contains(word) {
                if let action = currentAction, let target = currentTarget {
                    components.append(GoalComponent(action: action, target: target, details: nil))
                }
                currentAction = word
                currentTarget = nil
            } else if targetKeywords.contains(word) {
                currentTarget = word
            }
        }

        if let action = currentAction, let target = currentTarget {
            components.append(GoalComponent(action: action, target: target, details: nil))
        }

        // Default component if none found
        if components.isEmpty {
            components.append(GoalComponent(action: "execute", target: "task", details: goal))
        }

        return components
    }

    private func identifyCapabilities(for components: [GoalComponent]) -> [RequiredCapability] {
        var capabilities: [RequiredCapability] = []

        for component in components {
            switch component.action {
            case "create", "build", "implement":
                capabilities.append(RequiredCapability(name: "code_generation", importance: .critical))
                capabilities.append(RequiredCapability(name: "file_system", importance: .critical))
            case "analyze":
                capabilities.append(RequiredCapability(name: "ai_analysis", importance: .critical))
            case "deploy":
                capabilities.append(RequiredCapability(name: "build_system", importance: .critical))
                capabilities.append(RequiredCapability(name: "file_system", importance: .critical))
            case "test":
                capabilities.append(RequiredCapability(name: "test_runner", importance: .critical))
            case "fix", "update":
                capabilities.append(RequiredCapability(name: "code_modification", importance: .critical))
            default:
                capabilities.append(RequiredCapability(name: "general_execution", importance: .normal))
            }
        }

        return capabilities
    }

    private func estimateComplexity(components: [GoalComponent], capabilities: [RequiredCapability]) -> MissionComplexity {
        let componentScore = components.count * 10
        let capabilityScore = capabilities.count { $0.importance == .critical }* 15

        let totalScore = componentScore + capabilityScore

        if totalScore < 30 {
            return .simple
        } else if totalScore < 60 {
            return .moderate
        } else if totalScore < 100 {
            return .complex
        } else {
            return .epic
        }
    }

    private func identifyDependencies(_ components: [GoalComponent]) -> [ComponentDependency] {
        var dependencies: [ComponentDependency] = []

        for (index, component) in components.enumerated() {
            if index > 0 {
                // Later components may depend on earlier ones
                dependencies.append(ComponentDependency(
                    from: components[index - 1].id,
                    to: component.id,
                    type: .sequential
                ))
            }
        }

        return dependencies
    }

    private func assessFeasibility(capabilities: [RequiredCapability]) -> FeasibilityAssessment {
        // Check if all required capabilities are available
        let criticalCapabilities = capabilities.filter { $0.importance == .critical }
        let availableCapabilities = getAvailableCapabilities()

        let missingCritical = criticalCapabilities.filter { cap in
            !availableCapabilities.contains(cap.name)
        }

        if missingCritical.isEmpty {
            return FeasibilityAssessment(
                feasible: true,
                confidence: 0.9,
                blockers: [],
                recommendations: []
            )
        } else {
            return FeasibilityAssessment(
                feasible: false,
                confidence: 0.3,
                blockers: missingCritical.map { "Missing capability: \($0.name)" },
                recommendations: ["Ensure required capabilities are available"]
            )
        }
    }

    private func getAvailableCapabilities() -> Set<String> {
        [
            "code_generation",
            "file_system",
            "ai_analysis",
            "build_system",
            "test_runner",
            "code_modification",
            "general_execution",
            "network",
            "data_storage"
        ]
    }

    private func estimateDuration(complexity: MissionComplexity, phases: Int) -> TimeInterval {
        let baseTime: TimeInterval = switch complexity {
        case .simple: 60
        case .moderate: 300
        case .complex: 900
        case .epic: 3600
        }

        return baseTime * Double(max(phases, 1))
    }

    // MARK: - Phase Planning

    private func planPhases(for analysis: MissionAnalysis) async throws -> [MissionPhase] {
        var phases: [MissionPhase] = []

        // Phase 1: Preparation
        phases.append(MissionPhase(
            id: UUID(),
            name: "Preparation",
            description: "Setup and resource gathering",
            order: 1,
            steps: [
                MissionStep(id: UUID(), name: "Validate requirements", type: .validation, order: 1),
                MissionStep(id: UUID(), name: "Gather resources", type: .resourceGathering, order: 2),
                MissionStep(id: UUID(), name: "Create checkpoint", type: .checkpoint, order: 3)
            ],
            status: .pending
        ))

        // Phase 2+: Execution phases based on components
        for (index, component) in analysis.components.enumerated() {
            let steps = createStepsForComponent(component)

            phases.append(MissionPhase(
                id: UUID(),
                name: "Execute: \(component.action) \(component.target)",
                description: "Implementation phase \(index + 1)",
                order: index + 2,
                steps: steps,
                status: .pending
            ))
        }

        // Final Phase: Verification
        phases.append(MissionPhase(
            id: UUID(),
            name: "Verification",
            description: "Validate results and cleanup",
            order: phases.count + 1,
            steps: [
                MissionStep(id: UUID(), name: "Verify outputs", type: .validation, order: 1),
                MissionStep(id: UUID(), name: "Run tests", type: .testing, order: 2),
                MissionStep(id: UUID(), name: "Generate report", type: .reporting, order: 3),
                MissionStep(id: UUID(), name: "Cleanup", type: .cleanup, order: 4)
            ],
            status: .pending
        ))

        return phases
    }

    private func createStepsForComponent(_ component: GoalComponent) -> [MissionStep] {
        var steps: [MissionStep] = []
        var order = 1

        switch component.action {
        case "create", "build", "implement":
            steps.append(MissionStep(id: UUID(), name: "Design structure", type: .planning, order: order))
            order += 1
            steps.append(MissionStep(id: UUID(), name: "Generate code", type: .codeGeneration, order: order))
            order += 1
            steps.append(MissionStep(id: UUID(), name: "Create files", type: .fileOperation, order: order))
            order += 1
            steps.append(MissionStep(id: UUID(), name: "Verify implementation", type: .validation, order: order))

        case "analyze":
            steps.append(MissionStep(id: UUID(), name: "Gather data", type: .dataCollection, order: order))
            order += 1
            steps.append(MissionStep(id: UUID(), name: "Process data", type: .processing, order: order))
            order += 1
            steps.append(MissionStep(id: UUID(), name: "Generate insights", type: .aiAnalysis, order: order))

        case "fix", "update":
            steps.append(MissionStep(id: UUID(), name: "Identify issues", type: .aiAnalysis, order: order))
            order += 1
            steps.append(MissionStep(id: UUID(), name: "Plan fixes", type: .planning, order: order))
            order += 1
            steps.append(MissionStep(id: UUID(), name: "Apply changes", type: .codeModification, order: order))
            order += 1
            steps.append(MissionStep(id: UUID(), name: "Verify fixes", type: .testing, order: order))

        case "deploy":
            steps.append(MissionStep(id: UUID(), name: "Build project", type: .building, order: order))
            order += 1
            steps.append(MissionStep(id: UUID(), name: "Run tests", type: .testing, order: order))
            order += 1
            steps.append(MissionStep(id: UUID(), name: "Deploy artifacts", type: .deployment, order: order))

        default:
            steps.append(MissionStep(id: UUID(), name: "Execute task", type: .execution, order: order))
        }

        // Add checkpoint at end
        steps.append(MissionStep(id: UUID(), name: "Checkpoint", type: .checkpoint, order: steps.count + 1))

        return steps
    }

    // MARK: - Mission Execution

    /// Start executing a mission
    public func startMission(_ mission: Mission) async throws {
        guard activeMission == nil else {
            throw MissionError.missionAlreadyActive
        }

        activeMission = mission
        mission.status = .running
        mission.startedAt = Date()
        isPaused = false

        log(.info, "Starting mission: \(mission.goal)")

        executionTask = Task {
            do {
                try await executeMission(mission)
            } catch {
                await handleMissionError(mission, error: error)
            }
        }
    }

    private func executeMission(_ mission: Mission) async throws {
        for (phaseIndex, phase) in mission.phases.enumerated() {
            // Check for pause/cancel
            try Task.checkCancellation()
            while isPaused {
                try await Task.sleep(nanoseconds: 100_000_000)
            }

            currentPhase = phase
            phase.status = .running
            phase.startedAt = Date()

            log(.info, "Starting phase \(phase.order): \(phase.name)")

            for step in phase.steps {
                try Task.checkCancellation()
                while isPaused {
                    try await Task.sleep(nanoseconds: 100_000_000)
                }

                currentStep = step

                do {
                    try await executeStep(step, in: phase, mission: mission)
                    step.status = .completed
                } catch {
                    step.status = .failed
                    step.error = error.localizedDescription

                    // Retry logic
                    let retryKey = "\(phase.id)-\(step.id)"
                    let currentRetries = retryCount[retryKey, default: 0]

                    if currentRetries < maxRetries, step.type != .checkpoint {
                        retryCount[retryKey] = currentRetries + 1
                        log(.warning, "Retrying step (attempt \(currentRetries + 1)/\(maxRetries))")
                        try await executeStep(step, in: phase, mission: mission)
                        step.status = .completed
                    } else {
                        throw error
                    }
                }

                updateProgress(mission: mission, phaseIndex: phaseIndex)
            }

            phase.status = .completed
            phase.completedAt = Date()

            log(.success, "Completed phase \(phase.order): \(phase.name)")
        }

        // Mission complete
        mission.status = .completed
        mission.completedAt = Date()
        activeMission = nil
        currentPhase = nil
        currentStep = nil

        log(.success, "Mission completed successfully!")

        // Save to history
        missionHistory.insert(mission, at: 0)
        saveMissionHistory()

        // Notify
        NotificationCenter.default.post(name: .missionCompleted, object: mission)
    }

    private func executeStep(_ step: MissionStep, in _: MissionPhase, mission: Mission) async throws {
        step.status = .running
        step.startedAt = Date()

        log(.info, "Executing step: \(step.name)")

        switch step.type {
        case .validation:
            try await performValidation(step, mission: mission)
        case .resourceGathering:
            try await gatherResources(step, mission: mission)
        case .checkpoint:
            try await saveCheckpoint(step, mission: mission)
        case .planning:
            try await performPlanning(step, mission: mission)
        case .codeGeneration:
            try await generateCode(step, mission: mission)
        case .codeModification:
            try await modifyCode(step, mission: mission)
        case .fileOperation:
            try await performFileOperation(step, mission: mission)
        case .dataCollection:
            try await collectData(step, mission: mission)
        case .processing:
            try await processData(step, mission: mission)
        case .aiAnalysis:
            try await performAIAnalysis(step, mission: mission)
        case .building:
            try await performBuild(step, mission: mission)
        case .testing:
            try await runTests(step, mission: mission)
        case .deployment:
            try await deploy(step, mission: mission)
        case .reporting:
            try await generateReport(step, mission: mission)
        case .cleanup:
            try await cleanup(step, mission: mission)
        case .execution:
            try await executeGeneric(step, mission: mission)
        }

        step.completedAt = Date()
    }

    // MARK: - Step Implementations

    private func performValidation(_: MissionStep, mission: Mission) async throws {
        // Validate mission requirements
        log(.info, "Validating requirements...")

        guard mission.analysis.feasibility.feasible else {
            throw MissionError.validationFailed(mission.analysis.feasibility.blockers.joined(separator: ", "))
        }
    }

    private func gatherResources(_: MissionStep, mission _: Mission) async throws {
        log(.info, "Gathering resources...")
        // Gather any required resources
    }

    private func saveCheckpoint(_ step: MissionStep, mission: Mission) async throws {
        log(.info, "Saving checkpoint...")

        checkpointData["mission_id"] = mission.id.uuidString
        checkpointData["phase"] = currentPhase?.order
        checkpointData["step"] = step.order
        checkpointData["timestamp"] = Date()

        // Save to persistent storage
        if let data = try? JSONSerialization.data(withJSONObject: checkpointData) {
            UserDefaults.standard.set(data, forKey: "mission.checkpoint.\(mission.id)")
        }
    }

    private func performPlanning(_: MissionStep, mission _: Mission) async throws {
        log(.info, "Planning execution...")
        // AI-assisted planning
    }

    private func generateCode(_: MissionStep, mission _: Mission) async throws {
        log(.info, "Generating code...")
        // Use AI to generate code
    }

    private func modifyCode(_: MissionStep, mission _: Mission) async throws {
        log(.info, "Modifying code...")
        // Use AI to modify existing code
    }

    private func performFileOperation(_: MissionStep, mission _: Mission) async throws {
        log(.info, "Performing file operations...")
        // Create/modify/delete files
    }

    private func collectData(_: MissionStep, mission _: Mission) async throws {
        log(.info, "Collecting data...")
        // Gather required data
    }

    private func processData(_: MissionStep, mission _: Mission) async throws {
        log(.info, "Processing data...")
        // Process collected data
    }

    private func performAIAnalysis(_: MissionStep, mission _: Mission) async throws {
        log(.info, "Performing AI analysis...")
        // AI-powered analysis
    }

    private func performBuild(_: MissionStep, mission _: Mission) async throws {
        log(.info, "Building project...")
        // Trigger build system
    }

    private func runTests(_: MissionStep, mission _: Mission) async throws {
        log(.info, "Running tests...")
        // Execute test suite
    }

    private func deploy(_: MissionStep, mission _: Mission) async throws {
        log(.info, "Deploying...")
        // Deploy artifacts
    }

    private func generateReport(_: MissionStep, mission: Mission) async throws {
        log(.info, "Generating report...")

        let report = MissionReport(
            missionId: mission.id,
            goal: mission.goal,
            status: mission.status,
            phasesCompleted: mission.phases.count { $0.status == .completed },
            totalPhases: mission.phases.count,
            duration: mission.startedAt.map { Date().timeIntervalSince($0) },
            logs: logs,
            generatedAt: Date()
        )

        mission.report = report
    }

    private func cleanup(_: MissionStep, mission _: Mission) async throws {
        log(.info, "Cleaning up...")
        // Clean up temporary resources
        checkpointData.removeAll()
        retryCount.removeAll()
    }

    private func executeGeneric(_: MissionStep, mission _: Mission) async throws {
        log(.info, "Executing generic task...")
        // Generic execution
    }

    // MARK: - Mission Control

    /// Pause the current mission
    public func pauseMission() {
        isPaused = true
        activeMission?.status = .paused
        log(.warning, "Mission paused")
    }

    /// Resume a paused mission
    public func resumeMission() {
        isPaused = false
        activeMission?.status = .running
        log(.info, "Mission resumed")
    }

    /// Cancel the current mission
    public func cancelMission() {
        executionTask?.cancel()
        activeMission?.status = .cancelled
        activeMission = nil
        currentPhase = nil
        currentStep = nil
        isPaused = false
        log(.error, "Mission cancelled")
    }

    /// Restore from checkpoint
    public func restoreFromCheckpoint(missionId: UUID) async throws -> Mission? {
        guard let data = UserDefaults.standard.data(forKey: "mission.checkpoint.\(missionId)"),
              let checkpoint = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        log(.info, "Restoring from checkpoint...")

        // Find mission in history
        guard let mission = missionHistory.first(where: { $0.id == missionId }) else {
            return nil
        }

        // Restore state
        if let phaseOrder = checkpoint["phase"] as? Int {
            for phase in mission.phases where phase.order < phaseOrder {
                phase.status = .completed
            }
        }

        return mission
    }

    // MARK: - Error Handling

    private func handleMissionError(_ mission: Mission, error: Error) async {
        mission.status = .failed
        mission.error = error.localizedDescription

        log(.error, "Mission failed: \(error.localizedDescription)")

        activeMission = nil
        currentPhase = nil
        currentStep = nil

        // Save to history
        missionHistory.insert(mission, at: 0)
        saveMissionHistory()

        // Notify
        NotificationCenter.default.post(name: .missionFailed, object: mission)
    }

    // MARK: - Progress

    private func updateProgress(mission: Mission, phaseIndex: Int) {
        let totalSteps = mission.phases.reduce(0) { $0 + $1.steps.count }
        let completedSteps = mission.phases.prefix(phaseIndex).reduce(0) { $0 + $1.steps.count { $0.status == .completed }}
        let currentPhaseCompleted = currentPhase?.steps.count { $0.status == .completed }?? 0

        overallProgress = Double(completedSteps + currentPhaseCompleted) / Double(totalSteps)
    }

    // MARK: - Logging

    private func log(_ level: LogLevel, _ message: String) {
        let entry = MissionLog(
            timestamp: Date(),
            level: level,
            message: message,
            phase: currentPhase?.name,
            step: currentStep?.name
        )

        logs.append(entry)

        switch level {
        case .info: logger.info("\(message)")
        case .success: logger.info("✓ \(message)")
        case .warning: logger.warning("⚠ \(message)")
        case .error: logger.error("✗ \(message)")
        }
    }

    // MARK: - Persistence

    private func loadMissionHistory() {
        if let data = UserDefaults.standard.data(forKey: "mission.history"),
           let history = try? JSONDecoder().decode([Mission].self, from: data)
        {
            missionHistory = history
        }
    }

    private func saveMissionHistory() {
        // Keep last 50 missions
        let toSave = Array(missionHistory.prefix(50))
        if let data = try? JSONEncoder().encode(toSave) {
            UserDefaults.standard.set(data, forKey: "mission.history")
        }
    }
}

// MARK: - Types

public class Mission: Identifiable, ObservableObject, Codable {
    public let id: UUID
    public let goal: String
    public let context: MissionContext
    public let analysis: MissionAnalysis
    public let phases: [MissionPhase]
    @Published public var status: MissionStatus
    public let createdAt: Date
    public var startedAt: Date?
    public var completedAt: Date?
    public var error: String?
    public var report: MissionReport?

    enum CodingKeys: String, CodingKey {
        case id, goal, context, analysis, phases, status, createdAt, startedAt, completedAt, error, report
    }

    init(id: UUID, goal: String, context: MissionContext, analysis: MissionAnalysis, phases: [MissionPhase], status: MissionStatus, createdAt: Date) {
        self.id = id
        self.goal = goal
        self.context = context
        self.analysis = analysis
        self.phases = phases
        self.status = status
        self.createdAt = createdAt
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        goal = try container.decode(String.self, forKey: .goal)
        context = try container.decode(MissionContext.self, forKey: .context)
        analysis = try container.decode(MissionAnalysis.self, forKey: .analysis)
        phases = try container.decode([MissionPhase].self, forKey: .phases)
        status = try container.decode(MissionStatus.self, forKey: .status)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        error = try container.decodeIfPresent(String.self, forKey: .error)
        report = try container.decodeIfPresent(MissionReport.self, forKey: .report)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(goal, forKey: .goal)
        try container.encode(context, forKey: .context)
        try container.encode(analysis, forKey: .analysis)
        try container.encode(phases, forKey: .phases)
        try container.encode(status, forKey: .status)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(startedAt, forKey: .startedAt)
        try container.encodeIfPresent(completedAt, forKey: .completedAt)
        try container.encodeIfPresent(error, forKey: .error)
        try container.encodeIfPresent(report, forKey: .report)
    }
}

public struct MissionContext: Codable {
    public var priority: MissionPriority = .normal
    public var deadline: Date?
    public var constraints: [String] = []
    public var preferences: [String: String] = [:]

    public init() {}
}

public enum MissionPriority: String, Codable {
    case low, normal, high, critical
}

public enum MissionStatus: String, Codable {
    case planned, running, paused, completed, failed, cancelled
}

public struct MissionAnalysis: Codable {
    public let components: [GoalComponent]
    public let capabilities: [RequiredCapability]
    public let complexity: MissionComplexity
    public let dependencies: [ComponentDependency]
    public let feasibility: FeasibilityAssessment
    public let estimatedDuration: TimeInterval
}

public struct GoalComponent: Identifiable, Codable {
    public var id = UUID()
    public let action: String
    public let target: String
    public let details: String?
}

public struct RequiredCapability: Codable {
    public let name: String
    public let importance: CapabilityImportance

    public enum CapabilityImportance: String, Codable {
        case critical, normal, optional
    }
}

public enum MissionComplexity: String, Codable {
    case simple, moderate, complex, epic
}

public struct ComponentDependency: Codable {
    public let from: UUID
    public let to: UUID
    public let type: DependencyType

    public enum DependencyType: String, Codable {
        case sequential, parallel, conditional
    }
}

public struct FeasibilityAssessment: Codable {
    public let feasible: Bool
    public let confidence: Double
    public let blockers: [String]
    public let recommendations: [String]
}

public class MissionPhase: Identifiable, ObservableObject, Codable {
    public let id: UUID
    public let name: String
    public let description: String
    public let order: Int
    public let steps: [MissionStep]
    @Published public var status: PhaseStatus
    public var startedAt: Date?
    public var completedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, description, order, steps, status, startedAt, completedAt
    }

    init(id: UUID, name: String, description: String, order: Int, steps: [MissionStep], status: PhaseStatus) {
        self.id = id
        self.name = name
        self.description = description
        self.order = order
        self.steps = steps
        self.status = status
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        order = try container.decode(Int.self, forKey: .order)
        steps = try container.decode([MissionStep].self, forKey: .steps)
        status = try container.decode(PhaseStatus.self, forKey: .status)
        startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(order, forKey: .order)
        try container.encode(steps, forKey: .steps)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(startedAt, forKey: .startedAt)
        try container.encodeIfPresent(completedAt, forKey: .completedAt)
    }
}

public enum PhaseStatus: String, Codable {
    case pending, running, completed, failed, skipped
}

public class MissionStep: Identifiable, ObservableObject, Codable {
    public let id: UUID
    public let name: String
    public let type: StepType
    public let order: Int
    @Published public var status: StepStatus = .pending
    public var startedAt: Date?
    public var completedAt: Date?
    public var error: String?

    enum CodingKeys: String, CodingKey {
        case id, name, type, order, status, startedAt, completedAt, error
    }

    init(id: UUID, name: String, type: StepType, order: Int) {
        self.id = id
        self.name = name
        self.type = type
        self.order = order
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(StepType.self, forKey: .type)
        order = try container.decode(Int.self, forKey: .order)
        status = try container.decode(StepStatus.self, forKey: .status)
        startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        error = try container.decodeIfPresent(String.self, forKey: .error)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(order, forKey: .order)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(startedAt, forKey: .startedAt)
        try container.encodeIfPresent(completedAt, forKey: .completedAt)
        try container.encodeIfPresent(error, forKey: .error)
    }

    public enum StepType: String, Codable {
        case validation, resourceGathering, checkpoint, planning
        case codeGeneration, codeModification, fileOperation
        case dataCollection, processing, aiAnalysis
        case building, testing, deployment
        case reporting, cleanup, execution
    }
}

public enum StepStatus: String, Codable {
    case pending, running, completed, failed, skipped
}

public struct MissionLog: Identifiable, Codable {
    public var id = UUID()
    public let timestamp: Date
    public let level: LogLevel
    public let message: String
    public let phase: String?
    public let step: String?
}

public enum LogLevel: String, Codable {
    case info, success, warning, error
}

public struct MissionReport: Codable {
    public let missionId: UUID
    public let goal: String
    public let status: MissionStatus
    public let phasesCompleted: Int
    public let totalPhases: Int
    public let duration: TimeInterval?
    public let logs: [MissionLog]
    public let generatedAt: Date
}

public enum MissionError: Error, LocalizedError {
    case missionAlreadyActive
    case validationFailed(String)
    case phaseExecutionFailed(String)
    case stepExecutionFailed(String)
    case checkpointRestoreFailed

    public var errorDescription: String? {
        switch self {
        case .missionAlreadyActive: "A mission is already active"
        case let .validationFailed(reason): "Validation failed: \(reason)"
        case let .phaseExecutionFailed(reason): "Phase execution failed: \(reason)"
        case let .stepExecutionFailed(reason): "Step execution failed: \(reason)"
        case .checkpointRestoreFailed: "Failed to restore from checkpoint"
        }
    }
}

// MARK: - Notifications

public extension Notification.Name {
    static let missionCompleted = Notification.Name("thea.mission.completed")
    static let missionFailed = Notification.Name("thea.mission.failed")
}
