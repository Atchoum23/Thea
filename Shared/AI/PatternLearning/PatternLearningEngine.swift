//
//  PatternLearningEngine.swift
//  Thea
//
//  Created by Thea
//  Learn user patterns for proactive assistance
//

import Foundation
import os.log

// MARK: - Pattern Learning Engine

/// Learns user patterns for proactive and predictive assistance
@MainActor
public final class PatternLearningEngine: ObservableObject {
    public static let shared = PatternLearningEngine()

    private let logger = Logger(subsystem: "app.thea.patterns", category: "PatternLearningEngine")

    // MARK: - State

    @Published public private(set) var detectedPatterns: [BehavioralPattern] = []
    @Published public private(set) var userProfile: UserBehaviorProfile = .init()
    @Published public private(set) var predictions: [PatternPrediction] = []
    @Published public private(set) var isLearning = true

    // MARK: - Activity Log

    private var activityLog: [UserActivity] = []
    private let maxActivityLogSize = 10000

    // MARK: - Configuration

    public var minPatternOccurrences = 3
    public var patternConfidenceThreshold = 0.7
    public var learningEnabled = true

    private init() {
        loadState()
    }

    // MARK: - Activity Logging

    /// Log a user activity
    public func logActivity(_ activity: UserActivity) {
        guard learningEnabled else { return }

        activityLog.append(activity)

        // Trim log if too large
        if activityLog.count > maxActivityLogSize {
            activityLog = Array(activityLog.suffix(maxActivityLogSize))
        }

        // Update real-time analysis
        updatePatterns(with: activity)

        logger.debug("Logged activity: \(activity.type.rawValue)")
    }

    /// Log app usage
    public func logAppUsage(bundleId: String, duration: TimeInterval) {
        let activity = UserActivity(
            type: .appUsage,
            data: [
                "bundleId": .string(bundleId),
                "duration": .double(duration)
            ]
        )
        logActivity(activity)
    }

    /// Log a query
    public func logQuery(text: String, category: String?) {
        let activity = UserActivity(
            type: .query,
            data: [
                "text": .string(text),
                "category": .string(category ?? "general")
            ]
        )
        logActivity(activity)
    }

    /// Log a location visit
    public func logLocationVisit(name: String, latitude: Double, longitude: Double) {
        let activity = UserActivity(
            type: .locationVisit,
            data: [
                "name": .string(name),
                "latitude": .double(latitude),
                "longitude": .double(longitude)
            ]
        )
        logActivity(activity)
    }

    /// Log a workflow execution
    public func logWorkflow(name: String, success: Bool) {
        let activity = UserActivity(
            type: .workflow,
            data: [
                "name": .string(name),
                "success": .bool(success)
            ]
        )
        logActivity(activity)
    }

    // MARK: - Pattern Detection

    private func updatePatterns(with activity: UserActivity) {
        // Update time-based patterns
        updateTimePatterns(activity)

        // Update app usage patterns
        if activity.type == .appUsage {
            updateAppPatterns(activity)
        }

        // Update query patterns
        if activity.type == .query {
            updateQueryPatterns(activity)
        }

        // Update behavior profile
        updateBehaviorProfile(activity)
    }

    private func updateTimePatterns(_ activity: UserActivity) {
        let hour = Calendar.current.component(.hour, from: activity.timestamp)
        let weekday = Calendar.current.component(.weekday, from: activity.timestamp)

        // Track activity by time
        userProfile.activityByHour[hour, default: 0] += 1
        userProfile.activityByWeekday[weekday, default: 0] += 1

        // Detect time-based patterns
        detectTimePattern(type: activity.type, hour: hour, weekday: weekday)
    }

    private func updateAppPatterns(_ activity: UserActivity) {
        guard case let .string(bundleId) = activity.data["bundleId"],
              case let .double(duration) = activity.data["duration"] else { return }

        // Update app usage stats
        userProfile.appUsageTime[bundleId, default: 0] += duration
        userProfile.appLaunchCount[bundleId, default: 0] += 1

        // Detect app sequences
        if let lastApp = userProfile.lastUsedApp {
            let sequenceKey = "\(lastApp)->\(bundleId)"
            userProfile.appSequences[sequenceKey, default: 0] += 1
        }
        userProfile.lastUsedApp = bundleId
    }

    private func updateQueryPatterns(_ activity: UserActivity) {
        guard case let .string(text) = activity.data["text"],
              case let .string(category) = activity.data["category"] else { return }

        // Track query categories
        userProfile.queryCategoryCount[category, default: 0] += 1

        // Extract keywords
        let keywords = extractKeywords(from: text)
        for keyword in keywords {
            userProfile.queryKeywords[keyword, default: 0] += 1
        }
    }

    private func extractKeywords(from text: String) -> [String] {
        let stopWords = Set(["the", "a", "an", "is", "are", "was", "were", "be", "been",
                             "to", "of", "in", "for", "on", "with", "at", "by", "from",
                             "and", "or", "but", "i", "you", "he", "she", "it", "we", "they",
                             "what", "how", "when", "where", "why", "can", "could", "would",
                             "me", "my", "your", "this", "that", "these", "those"])

        return text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 3 && !stopWords.contains($0) }
    }

    private func detectTimePattern(type: UserActivity.ActivityType, hour: Int, weekday: Int) {
        // Check if we've seen this pattern before
        let patternKey = "time_\(type.rawValue)_\(weekday)_\(hour)"

        // Count occurrences
        let existingPattern = detectedPatterns.first { $0.id == patternKey }

        if var pattern = existingPattern {
            pattern.occurrences += 1
            pattern.confidence = min(1.0, Double(pattern.occurrences) / 10.0)
            pattern.lastOccurred = Date()

            if let index = detectedPatterns.firstIndex(where: { $0.id == patternKey }) {
                detectedPatterns[index] = pattern
            }
        } else if userProfile.activityByHour[hour, default: 0] >= minPatternOccurrences {
            // Create new pattern
            let pattern = BehavioralPattern(
                id: patternKey,
                type: .timeBased,
                name: "Activity at \(hour):00 on day \(weekday)",
                trigger: .timeOfDay(hour: hour, weekday: weekday),
                action: type,
                occurrences: 1,
                confidence: 0.1
            )
            detectedPatterns.append(pattern)
            logger.info("New time pattern detected: \(pattern.name)")
        }
    }

    private func updateBehaviorProfile(_ activity: UserActivity) {
        // Update overall activity count
        userProfile.totalActivities += 1
        userProfile.lastActivity = activity.timestamp

        // Calculate peak hours
        if let maxHour = userProfile.activityByHour.max(by: { $0.value < $1.value }) {
            userProfile.peakActivityHour = maxHour.key
        }
    }

    // MARK: - Predictions

    /// Generate predictions based on current context
    public func generatePredictions(context: PredictionContext) -> [PatternPrediction] {
        var newPredictions: [PatternPrediction] = []

        let hour = Calendar.current.component(.hour, from: Date())
        let weekday = Calendar.current.component(.weekday, from: Date())

        // Time-based predictions
        for pattern in detectedPatterns where pattern.confidence >= patternConfidenceThreshold {
            if case let .timeOfDay(patternHour, patternWeekday) = pattern.trigger {
                // Predict within 1 hour window
                if abs(patternHour - hour) <= 1, patternWeekday == weekday {
                    let prediction = PatternPrediction(
                        type: .action,
                        content: "Based on your patterns, you usually \(pattern.name.lowercased()) around now",
                        confidence: pattern.confidence,
                        relatedPattern: pattern
                    )
                    newPredictions.append(prediction)
                }
            }
        }

        // App sequence predictions
        if let lastApp = userProfile.lastUsedApp {
            let sequencePredictions = predictNextApp(after: lastApp)
            newPredictions.append(contentsOf: sequencePredictions)
        }

        // Query suggestions
        let querySuggestions = suggestQueries(context: context)
        newPredictions.append(contentsOf: querySuggestions)

        predictions = newPredictions
        return newPredictions
    }

    private func predictNextApp(after bundleId: String) -> [PatternPrediction] {
        var predictions: [PatternPrediction] = []

        // Find most common next apps
        let relevantSequences = userProfile.appSequences
            .filter { $0.key.hasPrefix("\(bundleId)->") }
            .sorted { $0.value > $1.value }
            .prefix(3)

        for (sequence, count) in relevantSequences {
            let nextApp = String(sequence.split(separator: ">").last ?? "")
            let confidence = min(1.0, Double(count) / 20.0)

            if confidence >= patternConfidenceThreshold {
                let prediction = PatternPrediction(
                    type: .appLaunch,
                    content: "You often open \(nextApp) after this",
                    confidence: confidence,
                    metadata: ["bundleId": nextApp]
                )
                predictions.append(prediction)
            }
        }

        return predictions
    }

    private func suggestQueries(context _: PredictionContext) -> [PatternPrediction] {
        var predictions: [PatternPrediction] = []

        // Suggest based on time of day
        let hour = Calendar.current.component(.hour, from: Date())

        if hour >= 6, hour <= 9 {
            predictions.append(PatternPrediction(
                type: .query,
                content: "Would you like your morning briefing?",
                confidence: 0.8
            ))
        } else if hour >= 17, hour <= 19 {
            predictions.append(PatternPrediction(
                type: .query,
                content: "Want to see your day summary?",
                confidence: 0.7
            ))
        }

        // Suggest based on common queries
        let topKeywords = userProfile.queryKeywords
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map(\.key)

        if !topKeywords.isEmpty {
            predictions.append(PatternPrediction(
                type: .query,
                content: "You often ask about: \(topKeywords.joined(separator: ", "))",
                confidence: 0.6
            ))
        }

        return predictions
    }

    // MARK: - Insights

    /// Get insights about user behavior
    public func getInsights() -> [BehaviorInsight] {
        var insights: [BehaviorInsight] = []

        // Peak activity insight
        if let peakHour = userProfile.peakActivityHour {
            insights.append(BehaviorInsight(
                type: .peakActivity,
                title: "Peak Activity Time",
                description: "You're most active around \(peakHour):00",
                data: ["hour": String(peakHour)]
            ))
        }

        // Most used apps
        if let topApp = userProfile.appUsageTime.max(by: { $0.value < $1.value }) {
            let hours = Int(topApp.value / 3600)
            insights.append(BehaviorInsight(
                type: .appUsage,
                title: "Most Used App",
                description: "\(topApp.key) - \(hours) hours total",
                data: ["bundleId": topApp.key, "hours": String(hours)]
            ))
        }

        // Query patterns
        if let topCategory = userProfile.queryCategoryCount.max(by: { $0.value < $1.value }) {
            insights.append(BehaviorInsight(
                type: .queryPattern,
                title: "Most Common Questions",
                description: "You often ask about \(topCategory.key)",
                data: ["category": topCategory.key]
            ))
        }

        // Patterns count
        let strongPatterns = detectedPatterns.filter { $0.confidence >= patternConfidenceThreshold }
        if !strongPatterns.isEmpty {
            insights.append(BehaviorInsight(
                type: .patternCount,
                title: "Learned Patterns",
                description: "\(strongPatterns.count) strong patterns detected",
                data: ["count": String(strongPatterns.count)]
            ))
        }

        return insights
    }

    // MARK: - Persistence

    private func loadState() {
        // Load user profile
        if let data = UserDefaults.standard.data(forKey: "thea.patterns.profile"),
           let profile = try? JSONDecoder().decode(UserBehaviorProfile.self, from: data)
        {
            userProfile = profile
        }

        // Load patterns
        if let data = UserDefaults.standard.data(forKey: "thea.patterns.learned"),
           let patterns = try? JSONDecoder().decode([BehavioralPattern].self, from: data)
        {
            detectedPatterns = patterns
        }
    }

    public func saveState() {
        // Save profile
        if let data = try? JSONEncoder().encode(userProfile) {
            UserDefaults.standard.set(data, forKey: "thea.patterns.profile")
        }

        // Save patterns
        if let data = try? JSONEncoder().encode(detectedPatterns) {
            UserDefaults.standard.set(data, forKey: "thea.patterns.learned")
        }
    }

    /// Clear all learned data
    public func clearAllData() {
        activityLog = []
        detectedPatterns = []
        userProfile = UserBehaviorProfile()
        predictions = []

        UserDefaults.standard.removeObject(forKey: "thea.patterns.profile")
        UserDefaults.standard.removeObject(forKey: "thea.patterns.learned")

        logger.info("All pattern learning data cleared")
    }
}

// MARK: - Models

public struct UserActivity: Codable, Sendable {
    public let id: String
    public let type: ActivityType
    public let data: [String: SendableValue]
    public let timestamp: Date

    public enum ActivityType: String, Codable, Sendable {
        case appUsage
        case query
        case locationVisit
        case workflow
        case focus
        case communication
        case calendar
        case health
        case custom
    }

    public init(
        id: String = UUID().uuidString,
        type: ActivityType,
        data: [String: SendableValue] = [:],
        timestamp: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.data = data
        self.timestamp = timestamp
    }
}

public struct UserBehaviorProfile: Codable, Sendable {
    public var totalActivities: Int = 0
    public var lastActivity: Date?
    public var peakActivityHour: Int?

    // Time-based stats
    public var activityByHour: [Int: Int] = [:]
    public var activityByWeekday: [Int: Int] = [:]

    // App usage
    public var appUsageTime: [String: TimeInterval] = [:]
    public var appLaunchCount: [String: Int] = [:]
    public var appSequences: [String: Int] = [:]
    public var lastUsedApp: String?

    // Query patterns
    public var queryCategoryCount: [String: Int] = [:]
    public var queryKeywords: [String: Int] = [:]

    // Location patterns
    public var frequentLocations: [String: Int] = [:]
}

public struct BehavioralPattern: Identifiable, Codable, Sendable {
    public let id: String
    public let type: PatternType
    public let name: String
    public let trigger: BehavioralPatternTrigger
    public let action: UserActivity.ActivityType
    public var occurrences: Int
    public var confidence: Double
    public var lastOccurred: Date

    public enum PatternType: String, Codable, Sendable {
        case timeBased
        case locationBased
        case appSequence
        case queryTopic
        case workflow
    }

    public init(
        id: String,
        type: PatternType,
        name: String,
        trigger: BehavioralPatternTrigger,
        action: UserActivity.ActivityType,
        occurrences: Int,
        confidence: Double
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.trigger = trigger
        self.action = action
        self.occurrences = occurrences
        self.confidence = confidence
        lastOccurred = Date()
    }
}

public enum BehavioralPatternTrigger: Codable, Sendable {
    case timeOfDay(hour: Int, weekday: Int)
    case location(name: String)
    case afterApp(bundleId: String)
    case keyword(word: String)
    case custom(identifier: String)
}

public struct PatternPrediction: Identifiable, Sendable {
    public let id: String
    public let type: PredictionType
    public let content: String
    public let confidence: Double
    public let relatedPattern: BehavioralPattern?
    public let metadata: [String: String]
    public let createdAt: Date

    public enum PredictionType: String, Sendable {
        case action
        case query
        case appLaunch
        case reminder
        case suggestion
    }

    public init(
        id: String = UUID().uuidString,
        type: PredictionType,
        content: String,
        confidence: Double,
        relatedPattern: BehavioralPattern? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.type = type
        self.content = content
        self.confidence = confidence
        self.relatedPattern = relatedPattern
        self.metadata = metadata
        createdAt = Date()
    }
}

public struct PredictionContext: Sendable {
    public let currentTime: Date
    public let location: String?
    public let currentApp: String?
    public let recentQueries: [String]

    public init(
        currentTime: Date = Date(),
        location: String? = nil,
        currentApp: String? = nil,
        recentQueries: [String] = []
    ) {
        self.currentTime = currentTime
        self.location = location
        self.currentApp = currentApp
        self.recentQueries = recentQueries
    }
}

public struct BehaviorInsight: Identifiable, Sendable {
    public let id: String
    public let type: InsightType
    public let title: String
    public let description: String
    public let data: [String: String]

    public enum InsightType: String, Sendable {
        case peakActivity
        case appUsage
        case queryPattern
        case locationPattern
        case patternCount
    }

    public init(
        id: String = UUID().uuidString,
        type: InsightType,
        title: String,
        description: String,
        data: [String: String] = [:]
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.description = description
        self.data = data
    }
}
