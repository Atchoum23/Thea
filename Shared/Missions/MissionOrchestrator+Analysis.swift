// MissionOrchestrator+Analysis.swift
// Goal analysis, capability assessment, and phase planning

import Foundation

// MARK: - Goal Analysis & Phase Planning

extension MissionOrchestrator {

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

    func analyzeGoal(_ goal: String) async throws -> MissionAnalysis {
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

    func extractComponents(from goal: String) -> [GoalComponent] {
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

    func identifyCapabilities(for components: [GoalComponent]) -> [RequiredCapability] {
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

    func estimateComplexity(components: [GoalComponent], capabilities: [RequiredCapability]) -> MissionComplexity {
        let componentScore = components.count * 10
        let capabilityScore = capabilities.count { $0.importance == .critical } * 15

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

    func identifyDependencies(_ components: [GoalComponent]) -> [ComponentDependency] {
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

    func assessFeasibility(capabilities: [RequiredCapability]) -> FeasibilityAssessment {
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

    func getAvailableCapabilities() -> Set<String> {
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

    func estimateDuration(complexity: MissionComplexity, phases: Int) -> TimeInterval {
        let baseTime: TimeInterval = switch complexity {
        case .simple: 60
        case .moderate: 300
        case .complex: 900
        case .epic: 3600
        }

        return baseTime * Double(max(phases, 1))
    }

    // MARK: - Phase Planning

    func planPhases(for analysis: MissionAnalysis) async throws -> [MissionPhase] {
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

    func createStepsForComponent(_ component: GoalComponent) -> [MissionStep] {
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
}
