// AnticipatoryIntelligenceCore.swift
// Thea V2 - Core Anticipatory Intelligence System
//
// Central coordination for all proactive/anticipatory behaviors
// Implements cutting-edge 2026 patterns for predictive AI assistance

import Foundation
import OSLog
import Combine

// MARK: - Anticipatory Intelligence Core

/// Central coordinator for all anticipatory and proactive behaviors
@MainActor
@Observable
public final class AnticipatoryIntelligenceCore {
    public static let shared = AnticipatoryIntelligenceCore()

    private let logger = Logger(subsystem: "app.thea.anticipatory", category: "Core")

    // MARK: - Configuration

    public var configuration = AnticipatoryConfiguration()

    // MARK: - State

    /// Whether the anticipatory system is active
    public private(set) var isActive: Bool = false

    /// Current predicted user intents
    public private(set) var predictedIntents: [PredictedUserIntent] = []

    /// Pending proactive interventions
    public private(set) var pendingInterventions: [ProactiveIntervention] = []

    /// Current user mental model
    public private(set) var mentalModel = MentalWorldModel()

    // MARK: - Subsystems

    public let temporalEngine = TemporalPatternEngine()
    public let contextPredictor = ContextPredictor()
    public let intentAnticipator = IntentAnticipator()
    public let interventionScheduler = InterventionScheduler()
    public let ambientSystem = AmbientIntelligenceSystem()
    public let notificationIntelligence = ProactiveNotificationIntelligence()

    // MARK: - Callbacks

    /// Called when a proactive suggestion is ready
    public var onProactiveSuggestion: ((ProactiveSuggestion) -> Void)?

    /// Called when intervention is triggered
    public var onInterventionTriggered: ((ProactiveIntervention) -> Void)?

    // MARK: - Private State

    private var anticipationTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        setupSubsystems()
    }

    // MARK: - Public API

    /// Start the anticipatory intelligence system
    public func start() {
        guard !isActive else { return }

        logger.info("Starting Anticipatory Intelligence Core")

        isActive = true
        startAnticipationCycle()
        ambientSystem.start()
    }

    /// Stop the anticipatory intelligence system
    public func stop() {
        guard isActive else { return }

        logger.info("Stopping Anticipatory Intelligence Core")

        isActive = false
        anticipationTask?.cancel()
        anticipationTask = nil
        ambientSystem.stop()
    }

    /// Record a user action for learning
    public func recordUserAction(_ action: AnticipatedUserAction) {
        let userAction = UserAction(type: action.type, metadata: ["details": action.details])
        temporalEngine.recordAction(userAction)
        intentAnticipator.recordAction(userAction)
        ambientSystem.recordActivity(userAction)

        // Update mental model based on action
        updateMentalModel(from: action)

        // Trigger prediction update
        Task {
            await updatePredictions()
        }
    }

    /// Provide feedback on a prediction/suggestion
    public func provideFeedback(_ feedback: AnticipationFeedback) {
        intentAnticipator.learnFromFeedback(feedback)
        interventionScheduler.learnFromFeedback(feedback)
        notificationIntelligence.learnFromInteraction(feedback)

        logger.info("Recorded anticipation feedback: \(feedback.wasAccepted ? "accepted" : "rejected")")
    }

    // MARK: - Private Methods

    private func setupSubsystems() {
        // Connect subsystems
        temporalEngine.onPatternDetected = { [weak self] pattern in
            self?.handlePatternDetected(pattern)
        }

        ambientSystem.onContextChange = { [weak self] context in
            self?.handleContextChange(context)
        }

        interventionScheduler.onInterventionReady = { [weak self] intervention in
            self?.handleInterventionReady(intervention)
        }
    }

    private func startAnticipationCycle() {
        anticipationTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.runAnticipationCycle()
                do {
                    try await Task.sleep(for: .seconds(5))
                } catch {
                    break
                }
            }
        }
    }

    private func runAnticipationCycle() async {
        guard isActive else { return }

        // Update context predictions
        await contextPredictor.updatePredictions()

        // Predict user intents
        let intents = await intentAnticipator.predictIntents(
            context: ambientSystem.currentContext,
            patterns: temporalEngine.activePatterns
        )
        predictedIntents = intents

        // Check for intervention opportunities
        await interventionScheduler.checkScheduledInterventions(
            context: ambientSystem.currentContext,
            mentalModel: mentalModel
        )

        // Generate proactive suggestions if appropriate
        if mentalModel.isInterruptionAppropriate() {
            await generateProactiveSuggestions()
        }
    }

    private func updatePredictions() async {
        let intents = await intentAnticipator.predictIntents(
            context: ambientSystem.currentContext,
            patterns: temporalEngine.activePatterns
        )
        predictedIntents = intents
    }

    private func updateMentalModel(from action: AnticipatedUserAction) {
        // periphery:ignore - Reserved: action parameter kept for API compatibility
        // Update focus level based on action frequency
        let actionRate = temporalEngine.currentActionRate
        let focusLevel = min(1.0, Double(actionRate) / 10.0)

        mentalModel = MentalWorldModel(
            focusLevel: focusLevel,
            stressLevel: mentalModel.stressLevel,
            isInMeeting: ambientSystem.isInMeeting,
            isDriving: ambientSystem.isDriving,
            isWorking: ambientSystem.isWorking,
            lastInteraction: Date()
        )
    }

    private func handlePatternDetected(_ pattern: TemporalPattern) {
        logger.debug("Pattern detected: \(pattern.description)")

        // Schedule intervention if pattern suggests proactive help
        if pattern.suggestsProactiveHelp {
            let intervention = ProactiveIntervention(
                id: UUID(),
                type: .suggestion,
                message: pattern.suggestedAction ?? "Would you like help with your usual task?",
                confidence: pattern.confidence,
                triggerCondition: .patternMatch(pattern.id),
                expiresAt: Date().addingTimeInterval(300)
            )
            interventionScheduler.schedule(intervention)
        }
    }

    // periphery:ignore - Reserved: _context parameter kept for API compatibility
    private func handleContextChange(_ _context: AmbientContext) {
        // Update predictions based on new context
        Task {
            await updatePredictions()
        }
    }

    private func handleInterventionReady(_ intervention: ProactiveIntervention) {
        // Check if intervention is still relevant
        guard intervention.expiresAt > Date() else { return }

        // Check mental model for appropriateness
        guard mentalModel.isInterruptionAppropriate() || intervention.type == .critical else {
            // Reschedule for later
            interventionScheduler.postpone(intervention, by: 60)
            return
        }

        pendingInterventions.append(intervention)
        onInterventionTriggered?(intervention)
    }

    private func generateProactiveSuggestions() async {
        guard let topIntent = predictedIntents.first, topIntent.confidence > 0.7 else { return }

        let suggestion = ProactiveSuggestion(
            id: UUID(),
            title: "Suggested Action",
            description: topIntent.description,
            actionType: topIntent.actionType,
            confidence: topIntent.confidence,
            context: ambientSystem.currentContext.summary
        )

        onProactiveSuggestion?(suggestion)
    }
}

// MARK: - Configuration

public struct AnticipatoryConfiguration: Codable, Sendable {
    /// Enable anticipatory features
    public var enabled: Bool = true

    /// Minimum confidence threshold for predictions
    public var confidenceThreshold: Double = 0.7

    /// Enable proactive notifications
    public var proactiveNotificationsEnabled: Bool = true

    /// Enable learning from user behavior
    public var learningEnabled: Bool = true

    /// Privacy mode (reduces data collection)
    public var privacyMode: Bool = false

    public init() {}
}

// MARK: - Supporting Types

public struct PredictedUserIntent: Identifiable, Sendable {
    public let id: UUID
    public let actionType: String
    public let description: String
    public let confidence: Double
    public let predictedAt: Date

    public init(id: UUID = UUID(), actionType: String, description: String, confidence: Double) {
        self.id = id
        self.actionType = actionType
        self.description = description
        self.confidence = confidence
        self.predictedAt = Date()
    }
}

public struct ProactiveIntervention: Identifiable, Sendable {
    public let id: UUID
    public let type: InterventionType
    public let message: String
    public let confidence: Double
    public let triggerCondition: TriggerCondition
    public var expiresAt: Date

    public enum InterventionType: String, Sendable {
        case suggestion
        case reminder
        case warning
        case critical
    }

    public enum TriggerCondition: Sendable {
        case patternMatch(UUID)
        case timeOfDay(hour: Int)
        case userIdle(seconds: TimeInterval)
        case contextChange(String)
    }
}

public struct ProactiveSuggestion: Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let description: String
    public let actionType: String
    public let confidence: Double
    public let context: String
}

public struct AnticipatedUserAction: Sendable {
    public let type: String
    public let details: String
    public let timestamp: Date

    public init(type: String, details: String, timestamp: Date = Date()) {
        self.type = type
        self.details = details
        self.timestamp = timestamp
    }
}

// AnticipationFeedback is defined in AAnticipatoryCommonTypes.swift
