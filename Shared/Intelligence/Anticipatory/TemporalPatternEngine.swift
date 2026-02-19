// TemporalPatternEngine.swift
// Thea V2 - Temporal Pattern Learning
//
// Learns time-based user behavior patterns
// Predicts future actions based on historical patterns

import Foundation
import OSLog

// MARK: - Temporal Pattern Engine

/// Engine for learning and predicting time-based user behavior patterns
@MainActor
@Observable
public final class TemporalPatternEngine {

    private let logger = Logger(subsystem: "app.thea.anticipatory", category: "TemporalPatterns")

    // MARK: - State

    /// Learned temporal patterns
    public private(set) var patterns: [TemporalPattern] = []

    /// Currently active/relevant patterns
    public private(set) var activePatterns: [TemporalPattern] = []

    /// Action history for pattern learning
    private var actionHistory: [TimestampedAction] = []

    /// Current action rate (actions per minute)
    public private(set) var currentActionRate: Double = 0

    // MARK: - Configuration

    /// Minimum occurrences to form a pattern
    public var minimumPatternOccurrences: Int = 3

    /// Pattern confidence decay rate per day
    public var confidenceDecayRate: Double = 0.1

    // MARK: - Callbacks

    public var onPatternDetected: ((TemporalPattern) -> Void)?

    // MARK: - Initialization

    public init() {
        loadPatterns()
    }

    // MARK: - Public API

    /// Record a user action for pattern learning
    public func recordAction(_ action: UserAction) {
        let timestamped = TimestampedAction(
            action: action,
            hourOfDay: Calendar.current.component(.hour, from: action.timestamp),
            dayOfWeek: Calendar.current.component(.weekday, from: action.timestamp),
            minuteOfHour: Calendar.current.component(.minute, from: action.timestamp)
        )

        actionHistory.append(timestamped)
        updateActionRate()

        // Limit history size
        if actionHistory.count > 10000 {
            actionHistory.removeFirst(1000)
        }

        // Analyze for new patterns
        analyzePatterns()
    }

    /// Get predictions for the current time
    public func getPredictions() -> [TemporalPrediction] {
        let now = Date()
        let hour = Calendar.current.component(.hour, from: now)
        let dayOfWeek = Calendar.current.component(.weekday, from: now)

        return activePatterns.compactMap { pattern in
            guard pattern.matches(hour: hour, dayOfWeek: dayOfWeek) else { return nil }
            return TemporalPrediction(
                pattern: pattern,
                predictedAction: pattern.actionType,
                confidence: pattern.confidence,
                expectedIn: pattern.expectedTimeOffset
            )
        }
    }

    /// Update active patterns based on current time
    public func updateActivePatterns() {
        let now = Date()
        let hour = Calendar.current.component(.hour, from: now)
        let dayOfWeek = Calendar.current.component(.weekday, from: now)

        activePatterns = patterns.filter { pattern in
            pattern.matches(hour: hour, dayOfWeek: dayOfWeek) && pattern.confidence > 0.5
        }
    }

    // MARK: - Private Methods

    private func updateActionRate() {
        let oneMinuteAgo = Date().addingTimeInterval(-60)
        let recentActions = actionHistory.filter { $0.action.timestamp > oneMinuteAgo }
        currentActionRate = Double(recentActions.count)
    }

    private func analyzePatterns() {
        // Group actions by type and time
        let grouped = Dictionary(grouping: actionHistory) { action -> String in
            "\(action.action.type)_\(action.hourOfDay)_\(action.dayOfWeek)"
        }

        for (key, actions) in grouped where actions.count >= minimumPatternOccurrences {
            let components = key.split(separator: "_")
            guard components.count == 3,
                  let hour = Int(components[1]),
                  let dayOfWeek = Int(components[2]) else { continue }

            let actionType = String(components[0])
            let confidence = min(1.0, Double(actions.count) / 10.0)

            // Check if pattern already exists
            if let existingIndex = patterns.firstIndex(where: { $0.actionType == actionType && $0.hourOfDay == hour && $0.dayOfWeek == dayOfWeek }) {
                // Reinforce existing pattern
                patterns[existingIndex].reinforce()
            } else {
                // Create new pattern
                let pattern = TemporalPattern(
                    id: UUID(),
                    actionType: actionType,
                    hourOfDay: hour,
                    dayOfWeek: dayOfWeek,
                    confidence: confidence,
                    occurrences: actions.count
                )
                patterns.append(pattern)
                onPatternDetected?(pattern)
                logger.info("New pattern detected: \(actionType) at hour \(hour)")
            }
        }

        updateActivePatterns()
        savePatterns()
    }

    private func loadPatterns() {
        // Load from UserDefaults or persistent storage
        if let data = UserDefaults.standard.data(forKey: "TemporalPatterns") {
            do {
                patterns = try JSONDecoder().decode([TemporalPattern].self, from: data)
                updateActivePatterns()
            } catch {
                logger.error("Failed to decode temporal patterns: \(error.localizedDescription)")
            }
        }
    }

    private func savePatterns() {
        do {
            let encoded = try JSONEncoder().encode(patterns)
            UserDefaults.standard.set(encoded, forKey: "TemporalPatterns")
        } catch {
            logger.error("Failed to encode temporal patterns: \(error.localizedDescription)")
        }
    }
}

// MARK: - Supporting Types

public struct TemporalPattern: Identifiable, Codable, Sendable {
    public let id: UUID
    public let actionType: String
    public let hourOfDay: Int
    public let dayOfWeek: Int?
    public var confidence: Double
    public var occurrences: Int
    public var lastTriggered: Date?
    public var suggestedAction: String?
    public var suggestsProactiveHelp: Bool = false
    public var expectedTimeOffset: TimeInterval = 0

    public var description: String {
        let day = dayOfWeek.map { "\(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][$0 - 1])" } ?? "Any day"
        return "\(actionType) at \(hourOfDay):00 on \(day)"
    }

    public func matches(hour: Int, dayOfWeek: Int) -> Bool {
        let hourMatch = self.hourOfDay == hour
        let dayMatch = self.dayOfWeek == nil || self.dayOfWeek == dayOfWeek
        return hourMatch && dayMatch
    }

    public mutating func reinforce() {
        occurrences += 1
        confidence = min(1.0, confidence + 0.1)
        lastTriggered = Date()
    }
}

public struct TemporalPrediction: Sendable {
    public let pattern: TemporalPattern
    public let predictedAction: String
    public let confidence: Double
    public let expectedIn: TimeInterval
}

struct TimestampedAction: Sendable {
    let action: UserAction
    let hourOfDay: Int
    let dayOfWeek: Int
    // periphery:ignore - Reserved: minuteOfHour property reserved for future feature activation
    let minuteOfHour: Int
}
