// PredictiveLifeEngine.swift
// Thea V2 - AI-Powered Predictive Life Intelligence
//
// Uses LLMs and ML to predict user needs, behaviors, and proactively
// suggest optimizations BEFORE the user asks. This is the brain
// behind Thea's anticipatory intelligence.

import Combine
import Foundation
import os.log

// MARK: - Prediction Types

/// Types of predictions Thea can make
public enum LifePredictionType: String, CaseIterable, Codable, Sendable {
    // Time-based predictions
    case nextActivity = "next_activity"           // What will they do next
    case optimalTime = "optimal_time"             // Best time for an activity
    case interruptionRisk = "interruption_risk"   // Risk of interruption

    // Need predictions
    case informationNeed = "information_need"     // Will need certain info
    case reminderNeed = "reminder_need"           // Will forget something
    case assistanceNeed = "assistance_need"       // Will need help with task

    // Behavioral predictions
    case fatigueOnset = "fatigue_onset"           // Getting tired
    case focusBreak = "focus_break"               // Need a break
    case stressBuildup = "stress_buildup"         // Stress increasing
    case motivationDip = "motivation_dip"         // Motivation decreasing

    // Social predictions
    case communicationOpportunity = "comm_opportunity" // Good time to reach out
    case conflictRisk = "conflict_risk"           // Potential for conflict
    case relationshipMaintenance = "relationship" // Relationship needs attention

    // Health predictions
    case sleepImpact = "sleep_impact"             // Current activity affects sleep
    case activityDeficit = "activity_deficit"     // Need more movement
    case nutritionReminder = "nutrition"          // Time to eat/drink

    // Productivity predictions
    case taskCompletion = "task_completion"       // When task will be done
    case bottleneck = "bottleneck"                // Upcoming bottleneck
    case contextSwitch = "context_switch"         // Optimal time to switch

    // Environmental predictions
    case weatherImpact = "weather_impact"         // Weather will affect plans
    case trafficPrediction = "traffic"            // Traffic conditions
    case schedulingConflict = "scheduling"        // Upcoming conflict
}

/// A prediction made by Thea
public struct LifePrediction: Identifiable, Codable, Sendable {
    public let id: UUID
    public let type: LifePredictionType
    public let title: String
    public let description: String
    public let confidence: Double                 // 0-1
    public let timeframe: PredictionTimeframe
    public let relevance: Double                  // 0-1 how relevant right now
    public let actionability: Actionability
    public let suggestedActions: [PredictedAction]
    public let basedOn: [String]                  // What data this is based on
    public let createdAt: Date
    public let expiresAt: Date?
    public let outcome: PredictionOutcome?        // Filled in after validation

    public init(
        id: UUID = UUID(),
        type: LifePredictionType,
        title: String,
        description: String,
        confidence: Double,
        timeframe: PredictionTimeframe,
        relevance: Double = 1.0,
        actionability: Actionability = .recommended,
        suggestedActions: [PredictedAction] = [],
        basedOn: [String] = [],
        createdAt: Date = Date(),
        expiresAt: Date? = nil,
        outcome: PredictionOutcome? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.description = description
        self.confidence = confidence
        self.timeframe = timeframe
        self.relevance = relevance
        self.actionability = actionability
        self.suggestedActions = suggestedActions
        self.basedOn = basedOn
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.outcome = outcome
    }
}

public struct PredictionTimeframe: Codable, Sendable {
    public let horizon: TimeInterval           // How far in the future
    public let window: TimeInterval?           // Duration of relevance
    public let specificTime: Date?             // If applicable

    public init(horizon: TimeInterval, window: TimeInterval? = nil, specificTime: Date? = nil) {
        self.horizon = horizon
        self.window = window
        self.specificTime = specificTime
    }

    public static let immediate = PredictionTimeframe(horizon: 300)       // 5 min
    public static let shortTerm = PredictionTimeframe(horizon: 3600)      // 1 hour
    public static let mediumTerm = PredictionTimeframe(horizon: 14400)    // 4 hours
    public static let endOfDay = PredictionTimeframe(horizon: 43200)      // 12 hours
    public static let tomorrow = PredictionTimeframe(horizon: 86400)      // 24 hours
    public static let thisWeek = PredictionTimeframe(horizon: 604800)     // 7 days
}

public enum Actionability: String, Codable, Sendable {
    case informational      // Just FYI
    case recommended        // Suggested action
    case urgent             // Should act soon
    case automatic          // Thea can handle automatically
}

public struct PredictedAction: Identifiable, Codable, Sendable {
    public let id: UUID
    public let title: String
    public let description: String
    public let type: ActionType
    public let automatable: Bool
    public let impact: Double                    // Expected impact 0-1
    public let effort: String

    public init(
        id: UUID = UUID(),
        title: String,
        description: String,
        type: ActionType,
        automatable: Bool = false,
        impact: Double,
        effort: String
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.type = type
        self.automatable = automatable
        self.impact = impact
        self.effort = effort
    }

    public enum ActionType: String, Codable, Sendable {
        case doNow
        case schedule
        case delegate
        case automate
        case prepare
        case remind
        case adjust
        case avoid
    }
}

public struct PredictionOutcome: Codable, Sendable {
    public let wasAccurate: Bool
    public let userTookAction: Bool
    public let feedback: String?
    public let evaluatedAt: Date

    public init(wasAccurate: Bool, userTookAction: Bool, feedback: String? = nil, evaluatedAt: Date = Date()) {
        self.wasAccurate = wasAccurate
        self.userTookAction = userTookAction
        self.feedback = feedback
        self.evaluatedAt = evaluatedAt
    }
}

// MARK: - Predictive Life Engine

/// AI-powered engine for predictive life intelligence
@MainActor
public final class PredictiveLifeEngine: ObservableObject {
    public static let shared = PredictiveLifeEngine()

    private let logger = Logger(subsystem: "ai.thea.app", category: "PredictiveLifeEngine")

    // MARK: - Published State

    @Published public private(set) var activePredictions: [LifePrediction] = []
    @Published public private(set) var predictionAccuracy: Double = 0.7
    @Published public private(set) var lastPredictionRun: Date?
    @Published public private(set) var isProcessing = false

    // MARK: - Configuration

    public var configuration = PredictiveEngineConfiguration()

    // MARK: - Internal State

    private var predictionHistory: [LifePrediction] = []
    private var contextWindow: [LifeContextSnapshot] = []
    private var userPreferences = UserPredictionPreferences()

    // MARK: - Tasks

    private var predictionTask: Task<Void, Never>?

    // MARK: - Subscriptions

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        logger.info("PredictiveLifeEngine initialized")
        setupSubscriptions()
        loadState()
    }

    // MARK: - Setup

    private func setupSubscriptions() {
        // Subscribe to pattern changes
        HolisticPatternIntelligence.shared.$detectedPatterns
            .receive(on: DispatchQueue.main)
            .sink { [weak self] patterns in
                Task { @MainActor in
                    self?.onPatternsUpdated(patterns)
                }
            }
            .store(in: &cancellables)

        // Subscribe to life events for context
        LifeMonitoringCoordinator.shared.eventStream
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                Task { @MainActor in
                    self?.updateContext(with: event)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Lifecycle

    public func start() {
        logger.info("Starting predictive engine")

        predictionTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(configuration.predictionInterval) * 1_000_000_000)
                guard !Task.isCancelled else { break }
                await runPredictionCycle()
            }
        }
    }

    public func stop() {
        logger.info("Stopping predictive engine")
        predictionTask?.cancel()
        saveState()
    }

    // MARK: - Context Management

    private func updateContext(with event: LifeEvent) {
        let snapshot = LifeContextSnapshot(
            timestamp: event.timestamp,
            eventType: event.type.rawValue,
            dataSource: event.source.rawValue,
            summary: event.summary,
            significance: event.significance.rawValue
        )

        contextWindow.append(snapshot)

        // Keep context window bounded
        if contextWindow.count > configuration.maxContextWindow {
            contextWindow.removeFirst()
        }

        // Check for immediate predictions needed
        checkImmediatePredictions(for: event)
    }

    private func checkImmediatePredictions(for event: LifeEvent) {
        // Check for patterns that need immediate response
        switch event.type {
        case .appSwitch:
            // Predict context switch cost
            predictContextSwitchImpact()

        case .inputActivity:
            // Check for fatigue patterns
            predictFatigueOnset()

        case .calendarEventCreated, .eventStart:
            // Predict scheduling conflicts
            predictSchedulingConflicts()

        case .messageReceived, .emailReceived:
            // Predict response need
            predictCommunicationNeed(for: event)

        default:
            break
        }
    }

    // MARK: - Pattern-Based Predictions

    private func onPatternsUpdated(_ patterns: [DetectedLifePattern]) {
        // Use patterns to make predictions
        for pattern in patterns where pattern.predictedNext != nil {
            createPatternBasedPrediction(pattern)
        }
    }

    private func createPatternBasedPrediction(_ pattern: DetectedLifePattern) {
        guard let predictedTime = pattern.predictedNext else { return }

        let horizon = predictedTime.timeIntervalSince(Date())
        guard horizon > 0 && horizon < configuration.maxPredictionHorizon else { return }

        let prediction = LifePrediction(
            type: mapPatternToPredictionType(pattern.category),
            title: "Upcoming: \(pattern.name)",
            description: "Based on your patterns, \(pattern.description.lowercased()) is expected \(formatTimeUntil(predictedTime))",
            confidence: pattern.confidence * 0.8, // Slightly reduce confidence for predictions
            timeframe: PredictionTimeframe(horizon: horizon, specificTime: predictedTime),
            relevance: calculateRelevance(for: horizon),
            suggestedActions: pattern.suggestions.map { suggestion in
                PredictedAction(
                    title: suggestion.title,
                    description: suggestion.description,
                    type: mapSuggestionToActionType(suggestion.type),
                    automatable: suggestion.automatable,
                    impact: suggestion.expectedImpact,
                    effort: suggestion.effort.rawValue
                )
            },
            basedOn: ["Pattern: \(pattern.name)", "\(pattern.dataPoints) observations"],
            expiresAt: predictedTime.addingTimeInterval(3600) // Expire 1 hour after predicted time
        )

        addOrUpdatePrediction(prediction)
    }

    private func mapPatternToPredictionType(_ category: LifePatternCategory) -> LifePredictionType {
        switch category {
        case .focusPeriods, .taskSwitching:
            return .optimalTime
        case .breakPatterns:
            return .focusBreak
        case .communicationPeaks:
            return .communicationOpportunity
        case .sleepQuality:
            return .sleepImpact
        case .stressIndicators:
            return .stressBuildup
        case .meetingPatterns:
            return .schedulingConflict
        case .activityLevels:
            return .activityDeficit
        default:
            return .nextActivity
        }
    }

    private func mapSuggestionToActionType(_ type: PatternSuggestion.SuggestionType) -> PredictedAction.ActionType {
        switch type {
        case .schedule:
            return .schedule
        case .automate:
            return .automate
        case .break_pattern:
            return .avoid
        case .health:
            return .adjust
        default:
            return .doNow
        }
    }

    // MARK: - Immediate Predictions

    private func predictContextSwitchImpact() {
        // Count recent app switches
        let recentSwitches = contextWindow.suffix(20).filter { $0.eventType == "app_switch" }

        if recentSwitches.count > 10 {
            let prediction = LifePrediction(
                type: .contextSwitch,
                title: "High Context Switching",
                description: "You've switched apps \(recentSwitches.count) times recently. This may be affecting your focus.",
                confidence: 0.8,
                timeframe: .immediate,
                relevance: 0.9,
                actionability: .recommended,
                suggestedActions: [
                    PredictedAction(
                        title: "Focus Mode",
                        description: "Consider enabling focus mode to reduce distractions",
                        type: .doNow,
                        automatable: true,
                        impact: 0.3,
                        effort: "minimal"
                    )
                ],
                basedOn: ["Recent activity: \(recentSwitches.count) app switches"]
            )

            addOrUpdatePrediction(prediction)
        }
    }

    private func predictFatigueOnset() {
        // Look for patterns indicating fatigue
        let recentActivity = contextWindow.suffix(30)
        let typingEvents = recentActivity.filter { $0.eventType == "input_activity" }

        // Simple heuristic: continuous activity without breaks
        if typingEvents.count > 20, let first = typingEvents.first, let last = typingEvents.last {
            let duration = last.timestamp.timeIntervalSince(first.timestamp)

            if duration > 3600 { // Over 1 hour of continuous activity
                let prediction = LifePrediction(
                    type: .fatigueOnset,
                    title: "Break Recommended",
                    description: "You've been working continuously for \(Int(duration / 60)) minutes. A short break can improve focus.",
                    confidence: 0.75,
                    timeframe: PredictionTimeframe(horizon: 300, window: 900), // Next 5-15 min
                    relevance: 0.95,
                    actionability: .recommended,
                    suggestedActions: [
                        PredictedAction(
                            title: "Take a 5-minute break",
                            description: "Step away, stretch, or look at something far away",
                            type: .doNow,
                            automatable: false,
                            impact: 0.4,
                            effort: "minimal"
                        ),
                        PredictedAction(
                            title: "Schedule break reminder",
                            description: "Set a reminder for regular breaks",
                            type: .automate,
                            automatable: true,
                            impact: 0.3,
                            effort: "minimal"
                        )
                    ],
                    basedOn: ["Continuous activity: \(Int(duration / 60)) minutes"]
                )

                addOrUpdatePrediction(prediction)
            }
        }
    }

    private func predictSchedulingConflicts() {
        // Check calendar for potential conflicts
        // This would integrate with CalendarMonitor
        // Placeholder for now
    }

    private func predictCommunicationNeed(for event: LifeEvent) {
        // Predict if this message needs urgent response
        if event.significance >= .significant {
            let prediction = LifePrediction(
                type: .communicationOpportunity,
                title: "Important Message",
                description: event.summary,
                confidence: 0.7,
                timeframe: .shortTerm,
                relevance: 0.8,
                actionability: .recommended,
                basedOn: ["Message significance: \(event.significance.rawValue)"]
            )

            addOrUpdatePrediction(prediction)
        }
    }

    // MARK: - Prediction Cycle

    private func runPredictionCycle() async {
        guard !isProcessing else { return }
        isProcessing = true

        logger.debug("Running prediction cycle")

        // Remove expired predictions
        cleanupExpiredPredictions()

        // Generate time-based predictions
        await generateTimeBasedPredictions()

        // Generate context-based predictions
        await generateContextBasedPredictions()

        // Use AI for complex predictions if configured
        if configuration.useAIForComplexPredictions {
            await generateAIPredictions()
        }

        // Sort predictions by relevance
        activePredictions.sort { $0.relevance * $0.confidence > $1.relevance * $1.confidence }

        // Keep only top predictions
        if activePredictions.count > configuration.maxActivePredictions {
            activePredictions = Array(activePredictions.prefix(configuration.maxActivePredictions))
        }

        lastPredictionRun = Date()
        isProcessing = false
    }

    private func generateTimeBasedPredictions() async {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)

        // Morning predictions
        if hour >= 6 && hour <= 9 {
            if !hasPrediction(ofType: .optimalTime, within: 3600) {
                let prediction = LifePrediction(
                    type: .optimalTime,
                    title: "Peak Focus Time Approaching",
                    description: "Based on your patterns, the next 2-3 hours are typically your most productive. Plan important work now.",
                    confidence: 0.65,
                    timeframe: .shortTerm,
                    relevance: 0.7,
                    basedOn: ["Time of day: Morning", "Historical productivity patterns"]
                )
                addOrUpdatePrediction(prediction)
            }
        }

        // Lunch time
        if hour >= 11 && hour <= 13 {
            if !hasPrediction(ofType: .nutritionReminder, within: 7200) {
                let prediction = LifePrediction(
                    type: .nutritionReminder,
                    title: "Lunch Time",
                    description: "It's around your typical lunch time. Taking a proper break can improve afternoon productivity.",
                    confidence: 0.6,
                    timeframe: .shortTerm,
                    relevance: 0.5,
                    basedOn: ["Time of day: Midday"]
                )
                addOrUpdatePrediction(prediction)
            }
        }

        // Evening wind-down
        if hour >= 20 && hour <= 22 {
            if !hasPrediction(ofType: .sleepImpact, within: 7200) {
                let prediction = LifePrediction(
                    type: .sleepImpact,
                    title: "Evening Wind-Down",
                    description: "Consider reducing screen brightness and avoiding intense work to prepare for sleep.",
                    confidence: 0.7,
                    timeframe: .mediumTerm,
                    relevance: 0.6,
                    suggestedActions: [
                        PredictedAction(
                            title: "Enable Night Shift",
                            description: "Reduce blue light to improve sleep quality",
                            type: .automate,
                            automatable: true,
                            impact: 0.2,
                            effort: "minimal"
                        )
                    ],
                    basedOn: ["Time of day: Evening", "Sleep hygiene best practices"]
                )
                addOrUpdatePrediction(prediction)
            }
        }
    }

    private func generateContextBasedPredictions() async {
        // Analyze recent context for patterns
        guard contextWindow.count >= 10 else { return }

        // Check for productivity patterns
        let productivityContext = analyzeProductivityContext()

        if productivityContext.focusLevel < 0.5 && !hasPrediction(ofType: .focusBreak, within: 1800) {
            let prediction = LifePrediction(
                type: .focusBreak,
                title: "Focus Declining",
                description: "Your recent activity suggests declining focus. A short break or change of task might help.",
                confidence: productivityContext.confidence,
                timeframe: .immediate,
                relevance: 0.85,
                suggestedActions: [
                    PredictedAction(
                        title: "Quick walk",
                        description: "Even a 2-minute walk can reset your focus",
                        type: .doNow,
                        impact: 0.3,
                        effort: "minimal"
                    )
                ],
                basedOn: productivityContext.factors
            )
            addOrUpdatePrediction(prediction)
        }
    }

    private func analyzeProductivityContext() -> (focusLevel: Double, confidence: Double, factors: [String]) {
        let recent = contextWindow.suffix(20)
        var factors: [String] = []

        // Calculate app switch rate
        let switches = recent.filter { $0.eventType == "app_switch" }.count
        let switchRate = Double(switches) / 20.0

        if switchRate > 0.3 {
            factors.append("High app switching rate: \(Int(switchRate * 100))%")
        }

        // Calculate activity variance
        let uniqueTypes = Set(recent.map { $0.eventType }).count
        if uniqueTypes > 8 {
            factors.append("High activity variance: \(uniqueTypes) different activities")
        }

        // Simple focus level calculation
        let focusLevel = max(0, 1.0 - switchRate - Double(uniqueTypes) / 20.0)
        let confidence = min(0.9, Double(recent.count) / 20.0)

        return (focusLevel, confidence, factors)
    }

    private func generateAIPredictions() async {
        // Use LLM to generate more complex predictions
        // This would integrate with the AI provider system

        // Build context summary for LLM
        let contextSummary = buildContextSummary()
        _ = buildPatternSummary()

        // For now, generate heuristic-based predictions
        // In full implementation, this would call the AI provider

        logger.debug("AI predictions would be generated from context: \(contextSummary.count) chars")
    }

    private func buildContextSummary() -> String {
        let recent = contextWindow.suffix(50)
        var summary = "Recent activity (\(recent.count) events):\n"

        var eventCounts: [String: Int] = [:]
        for event in recent {
            eventCounts[event.eventType, default: 0] += 1
        }

        for (type, count) in eventCounts.sorted(by: { $0.value > $1.value }).prefix(10) {
            summary += "- \(type): \(count) times\n"
        }

        return summary
    }

    private func buildPatternSummary() -> String {
        let patterns = HolisticPatternIntelligence.shared.detectedPatterns
        var summary = "Known patterns (\(patterns.count)):\n"

        for pattern in patterns.prefix(10) {
            summary += "- \(pattern.name) (confidence: \(String(format: "%.0f", pattern.confidence * 100))%)\n"
        }

        return summary
    }

    // MARK: - Prediction Management

    private func addOrUpdatePrediction(_ prediction: LifePrediction) {
        // Check if similar prediction exists
        if let existingIndex = activePredictions.firstIndex(where: {
            $0.type == prediction.type &&
            abs($0.createdAt.timeIntervalSince(prediction.createdAt)) < 1800 // Within 30 min
        }) {
            // Update existing prediction
            activePredictions[existingIndex] = prediction
        } else {
            // Add new prediction
            activePredictions.append(prediction)
            predictionHistory.append(prediction)

            // Trim history
            if predictionHistory.count > 1000 {
                predictionHistory.removeFirst(100)
            }
        }
    }

    private func hasPrediction(ofType type: LifePredictionType, within seconds: TimeInterval) -> Bool {
        activePredictions.contains {
            $0.type == type && Date().timeIntervalSince($0.createdAt) < seconds
        }
    }

    private func cleanupExpiredPredictions() {
        let now = Date()
        activePredictions.removeAll { prediction in
            if let expiresAt = prediction.expiresAt, expiresAt < now {
                return true
            }
            // Also remove old predictions that weren't explicitly given expiration
            return prediction.expiresAt == nil && now.timeIntervalSince(prediction.createdAt) > 86400 // 24 hours
        }
    }

    // MARK: - Helpers

    private func calculateRelevance(for horizon: TimeInterval) -> Double {
        // Closer = more relevant
        if horizon < 300 { return 1.0 }          // < 5 min
        if horizon < 1800 { return 0.9 }         // < 30 min
        if horizon < 3600 { return 0.8 }         // < 1 hour
        if horizon < 14400 { return 0.6 }        // < 4 hours
        if horizon < 86400 { return 0.4 }        // < 1 day
        return 0.2
    }

    private func formatTimeUntil(_ date: Date) -> String {
        let interval = date.timeIntervalSince(Date())
        if interval < 300 { return "in a few minutes" }
        if interval < 3600 { return "in about \(Int(interval / 60)) minutes" }
        if interval < 86400 { return "in about \(Int(interval / 3600)) hours" }
        return "in about \(Int(interval / 86400)) days"
    }

    // MARK: - Persistence

    private let predictionHistoryKey = "PredictiveLifeEngine.history"
    private let accuracyKey = "PredictiveLifeEngine.accuracy"

    private func saveState() {
        // Save recent prediction history for learning
        if let historyData = try? JSONEncoder().encode(Array(predictionHistory.suffix(500))) {
            UserDefaults.standard.set(historyData, forKey: predictionHistoryKey)
        }
        UserDefaults.standard.set(predictionAccuracy, forKey: accuracyKey)
    }

    private func loadState() {
        if let historyData = UserDefaults.standard.data(forKey: predictionHistoryKey),
           let history = try? JSONDecoder().decode([LifePrediction].self, from: historyData) {
            predictionHistory = history
        }
        predictionAccuracy = UserDefaults.standard.double(forKey: accuracyKey)
        if predictionAccuracy == 0 { predictionAccuracy = 0.7 } // Default
    }

    // MARK: - Public API

    /// Get predictions for a specific type
    public func predictions(ofType type: LifePredictionType) -> [LifePrediction] {
        activePredictions.filter { $0.type == type }
    }

    /// Get urgent predictions
    public func urgentPredictions() -> [LifePrediction] {
        activePredictions.filter { $0.actionability == .urgent }
    }

    /// Get automatable predictions
    public func automatablePredictions() -> [LifePrediction] {
        activePredictions.filter { $0.actionability == .automatic }
    }

    /// Record prediction outcome for learning
    public func recordOutcome(for predictionId: UUID, wasAccurate: Bool, userTookAction: Bool, feedback: String? = nil) {
        guard let index = predictionHistory.firstIndex(where: { $0.id == predictionId }) else { return }

        let prediction = predictionHistory[index]
        let outcome = PredictionOutcome(
            wasAccurate: wasAccurate,
            userTookAction: userTookAction,
            feedback: feedback
        )

        predictionHistory[index] = LifePrediction(
            id: prediction.id,
            type: prediction.type,
            title: prediction.title,
            description: prediction.description,
            confidence: prediction.confidence,
            timeframe: prediction.timeframe,
            relevance: prediction.relevance,
            actionability: prediction.actionability,
            suggestedActions: prediction.suggestedActions,
            basedOn: prediction.basedOn,
            createdAt: prediction.createdAt,
            expiresAt: prediction.expiresAt,
            outcome: outcome
        )

        // Update accuracy
        updateAccuracy()

        logger.info("Recorded outcome for prediction \(predictionId): accurate=\(wasAccurate)")
    }

    private func updateAccuracy() {
        let validatedPredictions = predictionHistory.filter { $0.outcome != nil }
        guard !validatedPredictions.isEmpty else { return }

        let accurateCount = validatedPredictions.filter { $0.outcome?.wasAccurate == true }.count
        predictionAccuracy = Double(accurateCount) / Double(validatedPredictions.count)
    }

    /// Manually trigger prediction cycle
    public func triggerPredictions() async {
        await runPredictionCycle()
    }
}

// MARK: - Life Context Snapshot

private struct LifeContextSnapshot: Codable, Sendable {
    let timestamp: Date
    let eventType: String
    let dataSource: String
    let summary: String
    let significance: Int
}

// MARK: - Configuration

public struct PredictiveEngineConfiguration: Codable, Sendable {
    public var enabled: Bool = true
    public var predictionInterval: TimeInterval = 300 // 5 minutes
    public var maxContextWindow: Int = 100
    public var maxActivePredictions: Int = 20
    public var maxPredictionHorizon: TimeInterval = 604800 // 1 week
    public var useAIForComplexPredictions: Bool = true
    public var minimumConfidenceToShow: Double = 0.5

    public init() {}
}

// MARK: - User Preferences

private struct UserPredictionPreferences: Codable {
    var enabledTypes: Set<LifePredictionType> = Set(LifePredictionType.allCases)
    var quietHoursStart: Int?
    var quietHoursEnd: Int?
    var minimumRelevance: Double = 0.3
}
