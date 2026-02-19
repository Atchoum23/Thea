import Foundation
import os.log

// MARK: - Pattern Detector

/// Detects behavioral patterns from context history
public actor PatternDetector {
    public static let shared = PatternDetector()

    private let logger = Logger(subsystem: "app.thea", category: "PatternDetector")

    // Pattern storage
    private var dailyPatterns: [DailyPattern] = []
    private var locationPatterns: [LocationPattern] = []
    private var appUsagePatterns: [AppUsagePattern] = []
    private var communicationPatterns: [CommunicationPattern] = []

    // Configuration
    // periphery:ignore - Reserved: logger property reserved for future feature activation
    private let minimumOccurrencesForPattern = 3
    private let patternExpirationDays = 30

    private init() {}

    // periphery:ignore - Reserved: communicationPatterns property reserved for future feature activation
    // MARK: - Public API

    /// Analyze context history and detect patterns
    // periphery:ignore - Reserved: patternExpirationDays property reserved for future feature activation
    public func analyzePatterns(from history: [ContextSnapshot]) async -> [DetectedPattern] {
        var patterns: [DetectedPattern] = []

        // Analyze different pattern types
        await patterns.append(contentsOf: detectTimeBasedPatterns(from: history))
        await patterns.append(contentsOf: detectLocationPatterns(from: history))
        await patterns.append(contentsOf: detectAppPatterns(from: history))
        await patterns.append(contentsOf: detectHealthPatterns(from: history))

        return patterns
    }

    /// Predict likely activities based on current context and patterns
    public func predictActivities(currentContext: ContextSnapshot) async -> [PredictedActivity] {
        var predictions: [PredictedActivity] = []

        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let weekday = calendar.component(.weekday, from: now)

        // Check daily patterns
        for pattern in dailyPatterns {
            if pattern.matchesTime(hour: hour, weekday: weekday) {
                predictions.append(PredictedActivity(
                    activity: pattern.activity,
                    confidence: pattern.confidence,
                    reason: "You usually \(pattern.activity) around this time"
                ))
            }
        }

        // Check location patterns
        if let location = currentContext.location {
            for pattern in locationPatterns {
                if pattern.matchesLocation(latitude: location.latitude, longitude: location.longitude) {
                    predictions.append(PredictedActivity(
                        activity: pattern.activity,
                        confidence: pattern.confidence,
                        reason: "When you're here, you usually \(pattern.activity)"
                    ))
                }
            }
        }

        // Sort by confidence
        return predictions.sorted { $0.confidence > $1.confidence }
    }

    /// Learn from a new context snapshot
    public func learn(from snapshot: ContextSnapshot) async {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: snapshot.timestamp)
        let weekday = calendar.component(.weekday, from: snapshot.timestamp)

        // Learn app usage patterns
        if let appActivity = snapshot.appActivity,
           let bundleID = appActivity.activeAppBundleID,
           let appName = appActivity.activeAppName
        {
            await learnAppPattern(bundleID: bundleID, appName: appName, hour: hour, weekday: weekday)
        }

        // Learn location patterns
        if let location = snapshot.location {
            await learnLocationPattern(location: location, hour: hour, weekday: weekday)
        }
    }

    // MARK: - Private Methods

    private func detectTimeBasedPatterns(from history: [ContextSnapshot]) async -> [DetectedPattern] {
        var patterns: [DetectedPattern] = []

        // Group by hour
        var hourlyActivities: [Int: [String]] = [:]

        for snapshot in history {
            let hour = Calendar.current.component(.hour, from: snapshot.timestamp)
            var activities: [String] = []

            if let app = snapshot.appActivity?.activeAppName {
                activities.append("using \(app)")
            }
            if snapshot.focus?.isActive == true {
                activities.append("in focus mode")
            }
            if let media = snapshot.media, media.isPlaying {
                activities.append("listening to music")
            }

            hourlyActivities[hour, default: []].append(contentsOf: activities)
        }

        // Find patterns with high frequency
        for (hour, activities) in hourlyActivities {
            let frequency = Dictionary(grouping: activities) { $0 }
                .mapValues { $0.count }

            for (activity, count) in frequency {
                if count >= minimumOccurrencesForPattern {
                    let confidence = min(Double(count) / Double(history.count) * 2, 1.0)
                    patterns.append(DetectedPattern(
                        type: .timeBased,
                        description: "You often \(activity) around \(hour):00",
                        confidence: confidence,
                        occurrences: count,
                        timeRange: "\(hour):00 - \(hour + 1):00"
                    ))
                }
            }
        }

        return patterns
    }

    private func detectLocationPatterns(from history: [ContextSnapshot]) async -> [DetectedPattern] {
        var patterns: [DetectedPattern] = []

        // Group activities by location
        var locationActivities: [String: [String]] = [:]

        for snapshot in history {
            guard let location = snapshot.location,
                  let placeName = location.placeName ?? location.locality else { continue }

            var activities: [String] = []

            if let app = snapshot.appActivity?.activeAppName {
                activities.append("using \(app)")
            }

            locationActivities[placeName, default: []].append(contentsOf: activities)
        }

        // Find location-based patterns
        for (location, activities) in locationActivities {
            let frequency = Dictionary(grouping: activities) { $0 }
                .mapValues { $0.count }

            for (activity, count) in frequency {
                if count >= minimumOccurrencesForPattern {
                    let confidence = min(Double(count) / 10.0, 1.0)
                    patterns.append(DetectedPattern(
                        type: .locationBased,
                        description: "When at \(location), you often \(activity)",
                        confidence: confidence,
                        occurrences: count,
                        location: location
                    ))
                }
            }
        }

        return patterns
    }

    private func detectAppPatterns(from history: [ContextSnapshot]) async -> [DetectedPattern] {
        var patterns: [DetectedPattern] = []

        // Analyze app usage sequences
        var appSequences: [[String]] = []
        var currentSequence: [String] = []
        var lastApp: String?

        for snapshot in history.sorted(by: { $0.timestamp < $1.timestamp }) {
            guard let app = snapshot.appActivity?.activeAppBundleID else { continue }

            if app != lastApp {
                if let last = lastApp {
                    currentSequence.append(last)
                }
                if currentSequence.count >= 3 {
                    appSequences.append(currentSequence)
                    currentSequence = []
                }
                lastApp = app
            }
        }

        // Find common sequences
        let sequenceStrings = appSequences.map { $0.joined(separator: " -> ") }
        let sequenceCounts = Dictionary(grouping: sequenceStrings) { $0 }.mapValues { $0.count }

        for (sequence, count) in sequenceCounts {
            if count >= minimumOccurrencesForPattern {
                patterns.append(DetectedPattern(
                    type: .appSequence,
                    description: "You often follow this app sequence: \(sequence)",
                    confidence: min(Double(count) / 5.0, 1.0),
                    occurrences: count
                ))
            }
        }

        return patterns
    }

    private func detectHealthPatterns(from history: [ContextSnapshot]) async -> [DetectedPattern] {
        var patterns: [DetectedPattern] = []

        // Analyze health-activity correlations
        var activeWhenExercising = 0
        var totalHealthSnapshots = 0

        for snapshot in history {
            guard let health = snapshot.health else { continue }
            totalHealthSnapshots += 1

            if health.activityLevel == .moderate || health.activityLevel == .vigorous {
                activeWhenExercising += 1
            }
        }

        if totalHealthSnapshots > 10 {
            let activeRatio = Double(activeWhenExercising) / Double(totalHealthSnapshots)
            if activeRatio > 0.3 {
                patterns.append(DetectedPattern(
                    type: .health,
                    description: "You maintain good activity levels (\(Int(activeRatio * 100))% of time)",
                    confidence: activeRatio,
                    occurrences: activeWhenExercising
                ))
            }
        }

        return patterns
    }

    private func learnAppPattern(bundleID: String, appName: String, hour: Int, weekday: Int) async {
        // Update or create app usage pattern
        if let index = appUsagePatterns.firstIndex(where: { $0.bundleID == bundleID && $0.hour == hour }) {
            appUsagePatterns[index].occurrences += 1
            appUsagePatterns[index].lastSeen = Date()
        } else {
            appUsagePatterns.append(AppUsagePattern(
                bundleID: bundleID,
                appName: appName,
                hour: hour,
                weekday: weekday,
                occurrences: 1,
                lastSeen: Date()
            ))
        }

        // Update daily pattern
        let activity = "use \(appName)"
        if let index = dailyPatterns.firstIndex(where: { $0.activity == activity && $0.hour == hour }) {
            dailyPatterns[index].occurrences += 1
            dailyPatterns[index].confidence = min(Double(dailyPatterns[index].occurrences) / 10.0, 1.0)
        } else {
            dailyPatterns.append(DailyPattern(
                activity: activity,
                hour: hour,
                weekday: weekday,
                occurrences: 1,
                confidence: 0.1
            ))
        }
    }

    private func learnLocationPattern(location: LocationContext, hour _: Int, weekday _: Int) async {
        guard let placeName = location.placeName ?? location.locality else { return }

        if let index = locationPatterns.firstIndex(where: {
            abs($0.latitude - location.latitude) < 0.001 &&
                abs($0.longitude - location.longitude) < 0.001
        }) {
            locationPatterns[index].occurrences += 1
            locationPatterns[index].lastSeen = Date()
        } else {
            locationPatterns.append(LocationPattern(
                placeName: placeName,
                latitude: location.latitude,
                longitude: location.longitude,
                activity: "visit \(placeName)",
                occurrences: 1,
                confidence: 0.1,
                lastSeen: Date()
            ))
        }
    }
}

// MARK: - Pattern Types

public struct DetectedPattern: Identifiable, Sendable {
    public let id = UUID()
    public let type: PatternType
    public let description: String
    public let confidence: Double
    public let occurrences: Int
    public var timeRange: String?
    public var location: String?

    public enum PatternType: String, Sendable {
        case timeBased
        case locationBased
        case appSequence
        case health
        case communication
    }
}

public struct PredictedActivity: Identifiable, Sendable {
    public let id = UUID()
    public let activity: String
    public let confidence: Double
    public let reason: String
}

// MARK: - Internal Pattern Storage

private struct DailyPattern {
    var activity: String
    var hour: Int
    var weekday: Int
    var occurrences: Int
    var confidence: Double

    func matchesTime(hour: Int, weekday _: Int) -> Bool {
        abs(self.hour - hour) <= 1
    // periphery:ignore - Reserved: weekday property reserved for future feature activation
    }
}

private struct LocationPattern {
    var placeName: String
    var latitude: Double
    var longitude: Double
    var activity: String
    var occurrences: Int
    // periphery:ignore - Reserved: placeName property reserved for future feature activation
    var confidence: Double
    var lastSeen: Date

    func matchesLocation(latitude: Double, longitude: Double) -> Bool {
        let distance = sqrt(pow(self.latitude - latitude, 2) + pow(self.longitude - longitude, 2))
        // periphery:ignore - Reserved: lastSeen property reserved for future feature activation
        return distance < 0.01 // ~1km
    }
}

private struct AppUsagePattern {
    var bundleID: String
    var appName: String
    var hour: Int
    var weekday: Int
    // periphery:ignore - Reserved: appName property reserved for future feature activation
    var occurrences: Int
    // periphery:ignore - Reserved: weekday property reserved for future feature activation
    var lastSeen: Date
// periphery:ignore - Reserved: lastSeen property reserved for future feature activation
}

// periphery:ignore - Reserved: CommunicationPattern type reserved for future feature activation
private struct CommunicationPattern {
    var contactName: String
    var preferredTime: Int
    var preferredDay: Int
    var occurrences: Int
}
