// PredictiveJourneyMapper.swift
// Thea V2 - Predictive User Journey Mapping
//
// Maps and predicts user journeys through tasks
// Enables proactive assistance at each step

import Foundation
import OSLog

// MARK: - Predictive Journey Mapper

/// Maps user journeys and predicts next steps for proactive assistance
@MainActor
@Observable
public final class PredictiveJourneyMapper {

    private let logger = Logger(subsystem: "app.thea.anticipatory", category: "JourneyMapper")

    // MARK: - State

    /// Known journey templates
    public private(set) var journeyTemplates: [JourneyTemplate] = []

    /// Current active journeys being tracked
    public private(set) var activeJourneys: [ActiveJourney] = []

    /// Predicted next steps
    public private(set) var predictedNextSteps: [PredictedStep] = []

    // MARK: - Configuration

    public var configuration = JourneyConfiguration()

    // MARK: - Callbacks

    /// Called when a journey step is predicted
    public var onStepPredicted: ((PredictedStep) -> Void)?

    /// Called when journey is likely to fail
    public var onJourneyRiskDetected: ((JourneyRisk) -> Void)?

    // MARK: - Private State

    private var actionSequence: [JourneyAction] = []
    private var journeyAnalysisTask: Task<Void, Never>?

    // MARK: - Initialization

    public init() {
        loadJourneyTemplates()
        loadDefaultTemplates()
    }

    // MARK: - Public API

    /// Record a user action
    public func recordAction(_ action: UserAction) {
        let journeyAction = JourneyAction(
            type: action.type,
            details: action.metadata["details"] ?? "",
            timestamp: action.timestamp
        )

        actionSequence.append(journeyAction)

        // Keep last 100 actions
        if actionSequence.count > 100 {
            actionSequence.removeFirst()
        }

        // Analyze for journey patterns
        analyzeCurrentSequence()
    }

    /// Get predicted next steps for current context
    public func getPredictedSteps() -> [PredictedStep] {
        predictedNextSteps.sorted { $0.confidence > $1.confidence }
    }

    /// Start tracking a specific journey
    public func startJourney(template: JourneyTemplate) {
        let journey = ActiveJourney(
            id: UUID(),
            template: template,
            currentStepIndex: 0,
            startedAt: Date(),
            actions: []
        )
        activeJourneys.append(journey)
        logger.info("Started journey: \(template.name)")
    }

    /// Manually advance a journey
    public func advanceJourney(_ journeyId: UUID) {
        guard let index = activeJourneys.firstIndex(where: { $0.id == journeyId }) else { return }
        var journey = activeJourneys[index]

        if journey.currentStepIndex < journey.template.steps.count - 1 {
            journey.currentStepIndex += 1
            activeJourneys[index] = journey
            predictNextSteps(for: journey)
        } else {
            // Journey completed
            completeJourney(journeyId)
        }
    }

    /// Complete a journey
    public func completeJourney(_ journeyId: UUID) {
        guard let index = activeJourneys.firstIndex(where: { $0.id == journeyId }) else { return }
        let journey = activeJourneys[index]

        // Learn from completed journey
        learnFromJourney(journey)

        activeJourneys.remove(at: index)
        logger.info("Completed journey: \(journey.template.name)")
    }

    // MARK: - Private Methods

    private func analyzeCurrentSequence() {
        // Check if current sequence matches start of any template
        for template in journeyTemplates {
            if matchesJourneyStart(template) && !isAlreadyTracking(template) {
                startJourney(template: template)
            }
        }

        // Update predictions for active journeys
        for journey in activeJourneys {
            predictNextSteps(for: journey)
            checkForRisks(journey)
        }
    }

    private func matchesJourneyStart(_ template: JourneyTemplate) -> Bool {
        guard let firstStep = template.steps.first,
              let lastAction = actionSequence.last else { return false }

        return firstStep.triggerActions.contains(lastAction.type)
    }

    private func isAlreadyTracking(_ template: JourneyTemplate) -> Bool {
        activeJourneys.contains { $0.template.id == template.id }
    }

    private func predictNextSteps(for journey: ActiveJourney) {
        guard journey.currentStepIndex < journey.template.steps.count else { return }

        let currentStep = journey.template.steps[journey.currentStepIndex]

        // Predict based on template
        let predictions = currentStep.expectedActions.enumerated().map { index, action in
            PredictedStep(
                id: UUID(),
                journeyId: journey.id,
                stepIndex: journey.currentStepIndex,
                actionType: action,
                description: "Next: \(action)",
                confidence: 1.0 - (Double(index) * 0.1),
                suggestedPrompt: currentStep.suggestedPrompts.first,
                estimatedDuration: currentStep.estimatedDuration
            )
        }

        // Update predictions (remove old ones for this journey)
        predictedNextSteps.removeAll { $0.journeyId == journey.id }
        predictedNextSteps.append(contentsOf: predictions)

        // Notify
        if let topPrediction = predictions.first {
            onStepPredicted?(topPrediction)
        }
    }

    private func checkForRisks(_ journey: ActiveJourney) {
        // Check for stalled journey
        let timeSinceStart = Date().timeIntervalSince(journey.startedAt)
        let expectedDuration = journey.template.steps.reduce(0.0) { $0 + $1.estimatedDuration }

        if timeSinceStart > expectedDuration * 2 {
            let risk = JourneyRisk(
                journeyId: journey.id,
                type: .stalled,
                description: "Journey taking longer than expected",
                suggestedAction: "Would you like help completing \(journey.template.name)?"
            )
            onJourneyRiskDetected?(risk)
        }

        // Check for repeated errors
        let recentErrors = actionSequence.suffix(5).filter { $0.type.contains("error") }.count
        if recentErrors >= 3 {
            let risk = JourneyRisk(
                journeyId: journey.id,
                type: .repeatedErrors,
                description: "Multiple errors detected",
                suggestedAction: "I notice you're encountering issues. Can I help?"
            )
            onJourneyRiskDetected?(risk)
        }
    }

    private func learnFromJourney(_ journey: ActiveJourney) {
        // Update template with actual timing data
        let actualDuration = Date().timeIntervalSince(journey.startedAt)

        if let index = journeyTemplates.firstIndex(where: { $0.id == journey.template.id }) {
            var template = journeyTemplates[index]
            template.completionCount += 1
            template.averageDuration = (template.averageDuration * Double(template.completionCount - 1) + actualDuration) / Double(template.completionCount)
            journeyTemplates[index] = template
            saveJourneyTemplates()
        }
    }

    private func loadJourneyTemplates() {
        if let data = UserDefaults.standard.data(forKey: "JourneyTemplates"),
           let decoded = try? JSONDecoder().decode([JourneyTemplate].self, from: data) {
            journeyTemplates = decoded
        }
    }

    private func saveJourneyTemplates() {
        if let encoded = try? JSONEncoder().encode(journeyTemplates) {
            UserDefaults.standard.set(encoded, forKey: "JourneyTemplates")
        }
    }

    private func loadDefaultTemplates() {
        // Add default journey templates if none exist
        guard journeyTemplates.isEmpty else { return }

        let codeReviewJourney = JourneyTemplate(
            id: UUID(),
            name: "Code Review",
            description: "Review and provide feedback on code",
            steps: [
                JourneyStep(
                    name: "Open Code",
                    triggerActions: ["paste_code", "upload_file"],
                    expectedActions: ["analyze_code", "ask_question"],
                    suggestedPrompts: ["Would you like me to review this code?"],
                    estimatedDuration: 30
                ),
                JourneyStep(
                    name: "Analyze",
                    triggerActions: ["analyze_code"],
                    expectedActions: ["identify_issues", "suggest_improvements"],
                    suggestedPrompts: ["I found some potential improvements..."],
                    estimatedDuration: 60
                ),
                JourneyStep(
                    name: "Apply Fixes",
                    triggerActions: ["apply_suggestion", "modify_code"],
                    expectedActions: ["verify_changes", "complete"],
                    suggestedPrompts: ["Shall I apply these changes?"],
                    estimatedDuration: 120
                )
            ],
            category: .development
        )

        let researchJourney = JourneyTemplate(
            id: UUID(),
            name: "Research Task",
            description: "Research a topic and synthesize findings",
            steps: [
                JourneyStep(
                    name: "Define Topic",
                    triggerActions: ["search", "ask_about"],
                    expectedActions: ["clarify_scope", "search_web"],
                    suggestedPrompts: ["What specific aspects are you interested in?"],
                    estimatedDuration: 30
                ),
                JourneyStep(
                    name: "Gather Information",
                    triggerActions: ["search_web", "read_document"],
                    expectedActions: ["summarize", "ask_followup"],
                    suggestedPrompts: ["I found several relevant sources..."],
                    estimatedDuration: 180
                ),
                JourneyStep(
                    name: "Synthesize",
                    triggerActions: ["summarize", "compare"],
                    expectedActions: ["create_report", "export"],
                    suggestedPrompts: ["Would you like me to create a summary?"],
                    estimatedDuration: 120
                )
            ],
            category: .research
        )

        journeyTemplates = [codeReviewJourney, researchJourney]
        saveJourneyTemplates()
    }
}

// MARK: - Supporting Types

public struct JourneyConfiguration: Sendable {
    public var enableAutoDetection: Bool = true
    public var enableRiskAlerts: Bool = true
    public var maxActiveJourneys: Int = 3

    public init() {}
}

public struct JourneyTemplate: Identifiable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var description: String
    public var steps: [JourneyStep]
    public var category: JourneyCategory
    public var completionCount: Int = 0
    public var averageDuration: TimeInterval = 0

    public enum JourneyCategory: String, Codable, Sendable {
        case development
        case research
        case writing
        case analysis
        case communication
        case custom
    }
}

public struct JourneyStep: Codable, Sendable {
    public let name: String
    public let triggerActions: [String]
    public let expectedActions: [String]
    public let suggestedPrompts: [String]
    public let estimatedDuration: TimeInterval
}

public struct ActiveJourney: Identifiable, Sendable {
    public let id: UUID
    public let template: JourneyTemplate
    public var currentStepIndex: Int
    public let startedAt: Date
    public var actions: [JourneyAction]
}

public struct JourneyAction: Sendable {
    public let type: String
    public let details: String
    public let timestamp: Date
}

public struct PredictedStep: Identifiable, Sendable {
    public let id: UUID
    public let journeyId: UUID
    public let stepIndex: Int
    public let actionType: String
    public let description: String
    public let confidence: Double
    public let suggestedPrompt: String?
    public let estimatedDuration: TimeInterval
}

public struct JourneyRisk: Sendable {
    public let journeyId: UUID
    public let type: RiskType
    public let description: String
    public let suggestedAction: String

    public enum RiskType: String, Sendable {
        case stalled
        case repeatedErrors
        case offTrack
        case timeout
    }
}
