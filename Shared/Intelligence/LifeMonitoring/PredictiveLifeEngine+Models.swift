// PredictiveLifeEngine+Models.swift
// Thea V2 - Predictive Life Engine Model Types
//
// Data models, enums, and supporting types used by the PredictiveLifeEngine.
// Split from PredictiveLifeEngine.swift for single-responsibility clarity.

import Foundation

// MARK: - Prediction Types

/// All categories of predictions that Thea's predictive engine can generate.
///
/// Organized into six domains: time-based, need-based, behavioral,
/// social, health, productivity, and environmental predictions.
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

// MARK: - Life Prediction

/// A single prediction made by Thea's predictive engine.
///
/// Each prediction includes its type, confidence level, timeframe,
/// suggested actions, and — once evaluated — an outcome record.
public struct LifePrediction: Identifiable, Codable, Sendable {
    /// Unique identifier for this prediction.
    public let id: UUID
    /// The category of prediction.
    public let type: LifePredictionType
    /// Short, human-readable title.
    public let title: String
    /// Detailed explanation of the prediction.
    public let description: String
    /// Confidence score in the range [0, 1].
    public let confidence: Double
    /// When this prediction is expected to materialize.
    public let timeframe: PredictionTimeframe
    /// How relevant the prediction is right now, in the range [0, 1].
    public let relevance: Double
    /// How actionable this prediction is.
    public let actionability: Actionability
    /// Concrete actions the user (or Thea) can take.
    public let suggestedActions: [PredictedAction]
    /// Human-readable list of data sources this prediction is based on.
    public let basedOn: [String]
    /// When this prediction was generated.
    public let createdAt: Date
    /// When this prediction expires and should be cleaned up.
    public let expiresAt: Date?
    /// Filled in after validation to track prediction accuracy.
    public let outcome: PredictionOutcome?

    /// Creates a new life prediction.
    ///
    /// - Parameters:
    ///   - id: Unique identifier. Defaults to a new UUID.
    ///   - type: The prediction category.
    ///   - title: Short human-readable title.
    ///   - description: Detailed explanation.
    ///   - confidence: Confidence score [0, 1].
    ///   - timeframe: When the prediction is expected to materialize.
    ///   - relevance: Current relevance score [0, 1]. Defaults to 1.0.
    ///   - actionability: How actionable this prediction is. Defaults to `.recommended`.
    ///   - suggestedActions: Concrete actions. Defaults to empty.
    ///   - basedOn: Data sources. Defaults to empty.
    ///   - createdAt: Creation timestamp. Defaults to now.
    ///   - expiresAt: Expiration timestamp. Defaults to nil.
    ///   - outcome: Post-evaluation outcome. Defaults to nil.
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

// MARK: - Prediction Timeframe

/// Describes when a prediction is expected to materialize.
///
/// Includes the time horizon, an optional relevance window, and
/// an optional specific timestamp.
public struct PredictionTimeframe: Codable, Sendable {
    /// How far in the future (seconds) the prediction applies.
    public let horizon: TimeInterval
    /// Optional duration (seconds) during which the prediction remains relevant.
    public let window: TimeInterval?
    /// A specific timestamp, if applicable.
    public let specificTime: Date?

    /// Creates a prediction timeframe.
    ///
    /// - Parameters:
    ///   - horizon: Seconds into the future.
    ///   - window: Optional relevance duration in seconds.
    ///   - specificTime: Optional exact timestamp.
    public init(horizon: TimeInterval, window: TimeInterval? = nil, specificTime: Date? = nil) {
        self.horizon = horizon
        self.window = window
        self.specificTime = specificTime
    }

    /// Immediate: within the next 5 minutes.
    public static let immediate = PredictionTimeframe(horizon: 300)
    /// Short-term: within the next hour.
    public static let shortTerm = PredictionTimeframe(horizon: 3600)
    /// Medium-term: within the next 4 hours.
    public static let mediumTerm = PredictionTimeframe(horizon: 14400)
    /// End of day: within the next 12 hours.
    public static let endOfDay = PredictionTimeframe(horizon: 43200)
    /// Tomorrow: within the next 24 hours.
    public static let tomorrow = PredictionTimeframe(horizon: 86400)
    /// This week: within the next 7 days.
    public static let thisWeek = PredictionTimeframe(horizon: 604800)
}

// MARK: - Actionability

/// How actionable a prediction is.
public enum Actionability: String, Codable, Sendable {
    /// Informational only — no action needed.
    case informational
    /// A suggested action the user should consider.
    case recommended
    /// The user should act soon.
    case urgent
    /// Thea can handle this automatically.
    case automatic
}

// MARK: - Predicted Action

/// A concrete action suggested by a prediction.
public struct PredictedAction: Identifiable, Codable, Sendable {
    /// Unique identifier for this action.
    public let id: UUID
    /// Short human-readable title.
    public let title: String
    /// Detailed explanation of the action.
    public let description: String
    /// Category of action.
    public let type: ActionType
    /// Whether Thea can perform this action automatically.
    public let automatable: Bool
    /// Expected impact of taking this action, in the range [0, 1].
    public let impact: Double
    /// Human-readable effort estimate (e.g. "minimal", "Low").
    public let effort: String

    /// Creates a predicted action.
    ///
    /// - Parameters:
    ///   - id: Unique identifier. Defaults to a new UUID.
    ///   - title: Short title.
    ///   - description: Detailed explanation.
    ///   - type: The action category.
    ///   - automatable: Whether Thea can auto-execute. Defaults to false.
    ///   - impact: Expected impact [0, 1].
    ///   - effort: Human-readable effort estimate.
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

    /// Categories of predicted actions.
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

// MARK: - Prediction Outcome

/// Records whether a prediction was accurate and what the user did.
///
/// Used for accuracy tracking and self-improvement of the prediction engine.
public struct PredictionOutcome: Codable, Sendable {
    /// Whether the prediction turned out to be correct.
    public let wasAccurate: Bool
    /// Whether the user acted on the prediction.
    public let userTookAction: Bool
    /// Optional free-text feedback from the user.
    public let feedback: String?
    /// When the outcome was evaluated.
    public let evaluatedAt: Date

    /// Creates a prediction outcome record.
    ///
    /// - Parameters:
    ///   - wasAccurate: Whether the prediction was correct.
    ///   - userTookAction: Whether the user acted on it.
    ///   - feedback: Optional user feedback text.
    ///   - evaluatedAt: When evaluated. Defaults to now.
    public init(wasAccurate: Bool, userTookAction: Bool, feedback: String? = nil, evaluatedAt: Date = Date()) {
        self.wasAccurate = wasAccurate
        self.userTookAction = userTookAction
        self.feedback = feedback
        self.evaluatedAt = evaluatedAt
    }
}

// MARK: - Life Context Snapshot

/// A snapshot of a single life event used as context for predictions.
///
/// Kept lightweight for efficient storage in the sliding context window.
struct LifeContextSnapshot: Codable, Sendable {
    /// When the event occurred.
    let timestamp: Date
    /// The raw event type string (e.g. "app_switch", "input_activity").
    let eventType: String
    /// The data source that produced this event.
    let dataSource: String
    /// Human-readable summary of the event.
    let summary: String
    /// Numeric significance level of the event.
    let significance: Int
}

// MARK: - Configuration

/// Configuration for the predictive life engine.
///
/// Controls prediction intervals, context window size, and feature toggles.
public struct PredictiveEngineConfiguration: Codable, Sendable {
    /// Whether the predictive engine is enabled.
    public var enabled: Bool = true
    /// Interval in seconds between automatic prediction cycles.
    public var predictionInterval: TimeInterval = 300 // 5 minutes
    /// Maximum number of context snapshots to keep in the sliding window.
    public var maxContextWindow: Int = 100
    /// Maximum number of active predictions to display.
    public var maxActivePredictions: Int = 20
    /// Maximum prediction horizon in seconds (default: 1 week).
    public var maxPredictionHorizon: TimeInterval = 604800
    /// Whether to use an AI provider for complex multi-signal predictions.
    public var useAIForComplexPredictions: Bool = true
    /// Minimum confidence threshold to show a prediction to the user.
    public var minimumConfidenceToShow: Double = 0.5

    public init() {}
}

// MARK: - User Preferences

// periphery:ignore - Reserved: UserPredictionPreferences type reserved for future feature activation
/// Per-user prediction preferences.
///
/// Controls which prediction types are enabled, quiet hours, and
/// minimum relevance thresholds.
struct UserPredictionPreferences: Codable {
    /// The set of prediction types the user wants to receive.
    var enabledTypes: Set<LifePredictionType> = Set(LifePredictionType.allCases)
    /// Hour (0-23) when quiet hours begin, or nil if disabled.
    var quietHoursStart: Int?
    /// Hour (0-23) when quiet hours end, or nil if disabled.
    var quietHoursEnd: Int?
    /// Minimum relevance score [0, 1] for a prediction to be shown.
    var minimumRelevance: Double = 0.3
}
