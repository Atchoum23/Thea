// AmbientIntelligenceSystem.swift
// Thea V2 - Ambient Intelligence System
//
// Monitors environmental context and user state for proactive assistance
// Implements 2026 best practices for ambient computing

import Foundation
import OSLog
import Combine

// MARK: - Ambient Intelligence System

/// Monitors environmental context and user activity for intelligent assistance
@MainActor
@Observable
public final class AmbientIntelligenceSystem {
    private let logger = Logger(subsystem: "app.thea.ambient", category: "AmbientIntelligence")

    // MARK: - State

    /// Whether the ambient system is actively monitoring
    public private(set) var isActive: Bool = false

    /// Current ambient context
    public private(set) var currentContext = AmbientContext()

    /// Detected user activities
    public private(set) var detectedActivities: [DetectedActivity] = []

    // MARK: - Inferred States

    /// Whether user appears to be in a meeting
    public private(set) var isInMeeting: Bool = false

    /// Whether user appears to be driving
    public private(set) var isDriving: Bool = false

    /// Whether user appears to be working
    public private(set) var isWorking: Bool = false

    /// Whether user appears to be sleeping/resting
    public private(set) var isResting: Bool = false

    // MARK: - Callbacks

    /// Called when context changes significantly
    public var onContextChange: ((AmbientContext) -> Void)?

    /// Called when a new activity is detected
    public var onActivityDetected: ((DetectedActivity) -> Void)?

    // MARK: - Private State

    private var monitoringTask: Task<Void, Never>?
    private var activityBuffer: [UserAction] = []
    private let maxBufferSize = 100

    // MARK: - Public API

    /// Start ambient monitoring
    public func start() {
        guard !isActive else { return }

        logger.info("Starting Ambient Intelligence System")
        isActive = true
        startMonitoringLoop()
    }

    /// Stop ambient monitoring
    public func stop() {
        guard isActive else { return }

        logger.info("Stopping Ambient Intelligence System")
        isActive = false
        monitoringTask?.cancel()
        monitoringTask = nil
    }

    /// Record user activity for context inference
    public func recordActivity(_ action: UserAction) {
        activityBuffer.append(action)

        // Keep buffer size manageable
        if activityBuffer.count > maxBufferSize {
            activityBuffer.removeFirst(activityBuffer.count - maxBufferSize)
        }

        // Update inferred states
        updateInferredStates(from: action)
    }

    /// Get current context summary
    public func getContextSummary() -> String {
        currentContext.summary
    }

    // MARK: - Private Methods

    private func startMonitoringLoop() {
        monitoringTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.updateAmbientContext()
                try? await Task.sleep(for: .seconds(10))
            }
        }
    }

    private func updateAmbientContext() async {
        let previousContext = currentContext

        // Build new context
        var newContext = AmbientContext()

        // Time-based context
        let hour = Calendar.current.component(.hour, from: Date())
        newContext.timeOfDay = classifyTimeOfDay(hour)
        newContext.dayOfWeek = Calendar.current.component(.weekday, from: Date())

        // Activity-based context
        newContext.recentActivityTypes = Set(activityBuffer.suffix(10).map { $0.type })
        newContext.activityLevel = calculateActivityLevel()

        // Inferred states
        newContext.isInMeeting = isInMeeting
        newContext.isDriving = isDriving
        newContext.isWorking = isWorking
        newContext.isResting = isResting

        // Update if changed significantly
        if hasContextChangedSignificantly(from: previousContext, to: newContext) {
            currentContext = newContext
            onContextChange?(newContext)
            logger.debug("Ambient context updated: \(newContext.summary)")
        }
    }

    private func classifyTimeOfDay(_ hour: Int) -> TimeOfDay {
        switch hour {
        case 5 ..< 9: return .earlyMorning
        case 9 ..< 12: return .morning
        case 12 ..< 14: return .midday
        case 14 ..< 17: return .afternoon
        case 17 ..< 21: return .evening
        default: return .night
        }
    }

    private func calculateActivityLevel() -> Double {
        guard !activityBuffer.isEmpty else { return 0.0 }

        let recentActions = activityBuffer.suffix(20)
        let timeSpan = recentActions.first.map { Date().timeIntervalSince($0.timestamp) } ?? 60
        let actionRate = Double(recentActions.count) / max(timeSpan / 60, 1)

        return min(1.0, actionRate / 5.0) // Normalize to 0-1
    }

    private func updateInferredStates(from action: UserAction) {
        // Infer meeting state
        if action.type.contains("calendar") || action.type.contains("zoom") || action.type.contains("meet") {
            isInMeeting = true
        }

        // Infer working state
        if action.type.contains("code") || action.type.contains("document") || action.type.contains("email") {
            isWorking = true
        }

        // Infer resting state based on low activity
        let recentCount = activityBuffer.suffix(10).count
        if recentCount < 2 {
            isResting = true
        } else {
            isResting = false
        }

        // Driving detection: inferred from navigation/maps activity
        if action.type.contains("navigation") || action.type.contains("maps") || action.type.contains("driving") {
            isDriving = true
        } else if isWorking || isInMeeting {
            isDriving = false
        }
    }

    private func hasContextChangedSignificantly(from old: AmbientContext, to new: AmbientContext) -> Bool {
        // Time of day change
        if old.timeOfDay != new.timeOfDay { return true }

        // Significant activity level change
        if abs(old.activityLevel - new.activityLevel) > 0.3 { return true }

        // State changes
        if old.isInMeeting != new.isInMeeting { return true }
        if old.isWorking != new.isWorking { return true }
        if old.isResting != new.isResting { return true }

        return false
    }
}

// MARK: - Supporting Types

public struct AmbientContext: Sendable {
    public var timeOfDay: TimeOfDay = .morning
    public var dayOfWeek: Int = 1 // 1 = Sunday
    public var recentActivityTypes: Set<String> = []
    public var activityLevel: Double = 0.0 // 0-1
    public var isInMeeting: Bool = false
    public var isDriving: Bool = false
    public var isWorking: Bool = false
    public var isResting: Bool = false

    public var summary: String {
        var parts: [String] = []
        parts.append(timeOfDay.rawValue)

        if isInMeeting { parts.append("in meeting") }
        if isWorking { parts.append("working") }
        if isResting { parts.append("resting") }

        let levelDescription = activityLevel > 0.7 ? "high activity" :
                              activityLevel > 0.3 ? "moderate activity" : "low activity"
        parts.append(levelDescription)

        return parts.joined(separator: ", ")
    }

    public init() {}
}

public enum TimeOfDay: String, Sendable {
    case earlyMorning = "early morning"
    case morning = "morning"
    case midday = "midday"
    case afternoon = "afternoon"
    case evening = "evening"
    case night = "night"
}

public struct DetectedActivity: Identifiable, Sendable {
    public let id: UUID
    public let type: ActivityType
    public let confidence: Double
    public let startedAt: Date
    public var endedAt: Date?

    public enum ActivityType: String, Sendable {
        case working
        case meeting
        case browsing
        case coding
        case writing
        case communicating
        case resting
        case commuting
        case exercising
    }

    public init(type: ActivityType, confidence: Double) {
        self.id = UUID()
        self.type = type
        self.confidence = confidence
        self.startedAt = Date()
        self.endedAt = nil
    }
}

// MARK: - User Action

/// Represents a user action that can be recorded and analyzed
public struct UserAction: Identifiable, Sendable {
    public let id: UUID
    public let type: String
    public let timestamp: Date
    public let metadata: [String: String]

    public init(type: String, metadata: [String: String] = [:]) {
        self.id = UUID()
        self.type = type
        self.timestamp = Date()
        self.metadata = metadata
    }
}
