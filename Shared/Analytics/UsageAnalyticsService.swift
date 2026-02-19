// UsageAnalyticsService.swift
// Thea V2 - Usage Analytics & Insights
//
// Privacy-preserving usage analytics for improving user experience
// All data stays on-device unless explicitly shared

import Foundation
import OSLog

// MARK: - Usage Analytics Service

/// Tracks usage patterns and provides insights
@MainActor
@Observable
public final class UsageAnalyticsService {
    public static let shared = UsageAnalyticsService()

    private let logger = Logger(subsystem: "app.thea.analytics", category: "UsageAnalytics")

    // MARK: - State

    /// Daily usage metrics
    public private(set) var dailyMetrics: [Date: DailyMetrics] = [:]

    /// Feature usage counts
    public private(set) var featureUsage: [String: Int] = [:]

    /// Model usage statistics
    public private(set) var modelUsage: [String: ModelUsageStats] = [:]

    /// Session statistics
    public private(set) var sessionStats = AnalyticsSessionStats()

    /// Current session start time
    private var sessionStartTime: Date?

    // MARK: - Configuration

    public var isEnabled: Bool = true {
        didSet {
            if !isEnabled {
                logger.info("Analytics disabled")
            }
        }
    }

    // MARK: - Initialization

    private init() {
        loadAnalytics()
        startSession()
    }

    // MARK: - Session Tracking

    private func startSession() {
        sessionStartTime = Date()
        sessionStats.totalSessions += 1
        logger.info("Session started")
    }

    public func endSession() {
        guard let startTime = sessionStartTime else { return }

        let duration = Date().timeIntervalSince(startTime)
        sessionStats.totalSessionTime += duration
        sessionStats.averageSessionDuration = sessionStats.totalSessionTime / Double(sessionStats.totalSessions)

        sessionStartTime = nil
        saveAnalytics()
        logger.info("Session ended. Duration: \(duration)s")
    }

    // MARK: - Event Tracking

    /// Track a feature usage
    public func trackFeature(_ feature: String) {
        guard isEnabled else { return }

        featureUsage[feature, default: 0] += 1
        updateDailyMetrics { metrics in
            metrics.featureUsage[feature, default: 0] += 1
        }
    }

    /// Track a chat interaction
    public func trackChat(
        model: String,
        provider: String,
        tokensIn: Int,
        tokensOut: Int,
        // periphery:ignore - Reserved: provider parameter kept for API compatibility
        latencyMs: Int,
        success: Bool
    ) {
        guard isEnabled else { return }

        // Update model stats
        var stats = modelUsage[model] ?? ModelUsageStats(model: model)
        stats.totalRequests += 1
        stats.totalTokensIn += tokensIn
        stats.totalTokensOut += tokensOut
        stats.totalLatencyMs += latencyMs
        if success {
            stats.successfulRequests += 1
        }
        modelUsage[model] = stats

        // Update daily metrics
        updateDailyMetrics { metrics in
            metrics.chatCount += 1
            metrics.tokensUsed += tokensIn + tokensOut
            if success {
                metrics.successfulChats += 1
            }
        }
    }

    /// Track a task completion
    public func trackTask(
        type: String,
        durationMs: Int,
        success: Bool
    // periphery:ignore - Reserved: durationMs parameter kept for API compatibility
    ) {
        guard isEnabled else { return }

        updateDailyMetrics { metrics in
            metrics.tasksCompleted += success ? 1 : 0
            metrics.tasksByType[type, default: 0] += 1
        }
    }

    /// Track a search
    // periphery:ignore - Reserved: query parameter — kept for API compatibility
    public func trackSearch(query: String, resultsCount: Int) {
        // periphery:ignore - Reserved: query parameter kept for API compatibility
        guard isEnabled else { return }

        updateDailyMetrics { metrics in
            metrics.searchCount += 1
        }
    }

    /// Track autonomous action
    // periphery:ignore - Reserved: type parameter kept for API compatibility
    public func trackAutonomousAction(type: String, approved: Bool) {
        guard isEnabled else { return }

        updateDailyMetrics { metrics in
            metrics.autonomousActions += 1
            if approved {
                metrics.approvedActions += 1
            }
        }
    }

    // MARK: - Insights

    /// Get usage insights for the user
    public func getInsights() -> [UsageInsight] {
        var insights: [UsageInsight] = []

        // Most used features
        let topFeatures = featureUsage.sorted { $0.value > $1.value }.prefix(5)
        if !topFeatures.isEmpty {
            insights.append(UsageInsight(
                type: .topFeatures,
                title: "Your Most Used Features",
                description: "You use \(topFeatures.first?.key ?? "") most often",
                data: Dictionary(uniqueKeysWithValues: topFeatures.map { ($0.key, $0.value) })
            ))
        }

        // Most efficient models
        let efficientModels = modelUsage.values
            .filter { $0.totalRequests > 5 }
            .sorted { $0.averageLatencyMs < $1.averageLatencyMs }
            .prefix(3)

        if !efficientModels.isEmpty {
            insights.append(UsageInsight(
                type: .modelPerformance,
                title: "Fastest AI Models",
                description: "\(efficientModels.first?.model ?? "") responds fastest",
                data: Dictionary(uniqueKeysWithValues: efficientModels.map { ($0.model, $0.averageLatencyMs) })
            ))
        }

        // Daily usage trend
        let recentDays = dailyMetrics
            .filter { Calendar.current.isDate($0.key, equalTo: Date(), toGranularity: .weekOfYear) }
            .sorted { $0.key < $1.key }

        if recentDays.count >= 3 {
            let avgChats = recentDays.map(\.value.chatCount).reduce(0, +) / recentDays.count
            insights.append(UsageInsight(
                type: .usageTrend,
                title: "Weekly Activity",
                description: "You average \(avgChats) chats per day",
                data: ["averageChats": avgChats]
            ))
        }

        // Autonomy approval rate
        let totalAutonomous = dailyMetrics.values.reduce(0) { $0 + $1.autonomousActions }
        let approvedAutonomous = dailyMetrics.values.reduce(0) { $0 + $1.approvedActions }
        if totalAutonomous > 10 {
            let approvalRate = Double(approvedAutonomous) / Double(totalAutonomous) * 100
            insights.append(UsageInsight(
                type: .autonomyStats,
                title: "Autonomy Trust Level",
                description: "You approve \(Int(approvalRate))% of autonomous actions",
                data: ["approvalRate": approvalRate]
            ))
        }

        // Session duration insight
        if sessionStats.totalSessions > 5 {
            let avgMinutes = Int(sessionStats.averageSessionDuration / 60)
            insights.append(UsageInsight(
                type: .sessionStats,
                title: "Session Duration",
                description: "Your average session is \(avgMinutes) minutes",
                data: ["averageMinutes": avgMinutes]
            ))
        }

        return insights
    }

    /// Get usage summary for a date range
    public func getSummary(from startDate: Date, to endDate: Date) -> UsageSummary {
        let relevantMetrics = dailyMetrics.filter { date, _ in
            date >= startDate && date <= endDate
        }

        return UsageSummary(
            dateRange: startDate...endDate,
            totalChats: relevantMetrics.values.reduce(0) { $0 + $1.chatCount },
            totalTokens: relevantMetrics.values.reduce(0) { $0 + $1.tokensUsed },
            totalTasks: relevantMetrics.values.reduce(0) { $0 + $1.tasksCompleted },
            totalSearches: relevantMetrics.values.reduce(0) { $0 + $1.searchCount },
            successRate: calculateSuccessRate(metrics: Array(relevantMetrics.values)),
            topFeatures: aggregateFeatureUsage(metrics: Array(relevantMetrics.values)),
            topModels: Array(modelUsage.keys.prefix(5))
        )
    }

    // MARK: - Private Helpers

    private func updateDailyMetrics(_ update: (inout DailyMetrics) -> Void) {
        let today = Calendar.current.startOfDay(for: Date())
        var metrics = dailyMetrics[today] ?? DailyMetrics(date: today)
        update(&metrics)
        dailyMetrics[today] = metrics
    }

    private func calculateSuccessRate(metrics: [DailyMetrics]) -> Double {
        let totalChats = metrics.reduce(0) { $0 + $1.chatCount }
        let successfulChats = metrics.reduce(0) { $0 + $1.successfulChats }
        guard totalChats > 0 else { return 1.0 }
        return Double(successfulChats) / Double(totalChats)
    }

    private func aggregateFeatureUsage(metrics: [DailyMetrics]) -> [String: Int] {
        var aggregated: [String: Int] = [:]
        for metric in metrics {
            for (feature, count) in metric.featureUsage {
                aggregated[feature, default: 0] += count
            }
        }
        return aggregated
    }

    // MARK: - Persistence

    private func loadAnalytics() {
        // Load daily metrics
        if let data = UserDefaults.standard.data(forKey: "analytics.dailyMetrics") {
            do {
                dailyMetrics = try JSONDecoder().decode([Date: DailyMetrics].self, from: data)
            } catch {
                logger.debug("Could not decode daily metrics: \(error.localizedDescription)")
            }
        }

        // Load feature usage
        if let data = UserDefaults.standard.data(forKey: "analytics.featureUsage") {
            do {
                featureUsage = try JSONDecoder().decode([String: Int].self, from: data)
            } catch {
                logger.debug("Could not decode feature usage: \(error.localizedDescription)")
            }
        }

        // Load model usage
        if let data = UserDefaults.standard.data(forKey: "analytics.modelUsage") {
            do {
                modelUsage = try JSONDecoder().decode([String: ModelUsageStats].self, from: data)
            } catch {
                logger.debug("Could not decode model usage: \(error.localizedDescription)")
            }
        }

        // Load session stats
        if let data = UserDefaults.standard.data(forKey: "analytics.sessionStats") {
            do {
                sessionStats = try JSONDecoder().decode(AnalyticsSessionStats.self, from: data)
            } catch {
                logger.debug("Could not decode session stats: \(error.localizedDescription)")
            }
        }

        // Clean up old data (keep last 90 days)
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        dailyMetrics = dailyMetrics.filter { $0.key >= cutoffDate }

        logger.info("Loaded analytics data")
    }

    private func saveAnalytics() {
        do {
            let data = try JSONEncoder().encode(dailyMetrics)
            UserDefaults.standard.set(data, forKey: "analytics.dailyMetrics")
        } catch {
            logger.error("Failed to save daily metrics: \(error.localizedDescription)")
        }
        do {
            let data = try JSONEncoder().encode(featureUsage)
            UserDefaults.standard.set(data, forKey: "analytics.featureUsage")
        } catch {
            logger.error("Failed to save feature usage: \(error.localizedDescription)")
        }
        do {
            let data = try JSONEncoder().encode(modelUsage)
            UserDefaults.standard.set(data, forKey: "analytics.modelUsage")
        } catch {
            logger.error("Failed to save model usage: \(error.localizedDescription)")
        }
        do {
            let data = try JSONEncoder().encode(sessionStats)
            UserDefaults.standard.set(data, forKey: "analytics.sessionStats")
        } catch {
            logger.error("Failed to save session stats: \(error.localizedDescription)")
        }
    }

    /// Manually trigger save
    public func save() {
        saveAnalytics()
    }

    /// Clear all analytics data
    public func clearAllData() {
        dailyMetrics.removeAll()
        featureUsage.removeAll()
        modelUsage.removeAll()
        sessionStats = AnalyticsSessionStats()
        saveAnalytics()
        logger.info("Cleared all analytics data")
    }
}

// MARK: - Supporting Types

/// Daily usage metrics
public struct DailyMetrics: Codable, Sendable {
    public let date: Date
    public var chatCount: Int = 0
    public var successfulChats: Int = 0
    public var tokensUsed: Int = 0
    public var tasksCompleted: Int = 0
    public var searchCount: Int = 0
    public var autonomousActions: Int = 0
    public var approvedActions: Int = 0
    public var featureUsage: [String: Int] = [:]
    public var tasksByType: [String: Int] = [:]
}

/// Model usage statistics
public struct ModelUsageStats: Codable, Sendable {
    public let model: String
    public var totalRequests: Int = 0
    public var successfulRequests: Int = 0
    public var totalTokensIn: Int = 0
    public var totalTokensOut: Int = 0
    public var totalLatencyMs: Int = 0

    public var successRate: Double {
        guard totalRequests > 0 else { return 1.0 }
        return Double(successfulRequests) / Double(totalRequests)
    }

    public var averageLatencyMs: Int {
        guard totalRequests > 0 else { return 0 }
        return totalLatencyMs / totalRequests
    }

    public var averageTokens: Int {
        guard totalRequests > 0 else { return 0 }
        return (totalTokensIn + totalTokensOut) / totalRequests
    }
}

/// Session statistics
public struct AnalyticsSessionStats: Codable, Sendable {
    public var totalSessions: Int = 0
    public var totalSessionTime: TimeInterval = 0
    public var averageSessionDuration: TimeInterval = 0
}

/// A usage insight for the user
public struct UsageInsight: Identifiable, Sendable {
    public let id = UUID()
    public let type: InsightType
    public let title: String
    public let description: String
    public let dataString: [String: String]

    public enum InsightType: String, Sendable {
        case topFeatures
        case modelPerformance
        case usageTrend
        case autonomyStats
        case sessionStats
        case recommendation
    }

    public init(type: InsightType, title: String, description: String, data: [String: Any]) {
        self.type = type
        self.title = title
        self.description = description
        // Convert Any to String for Sendable conformance
        self.dataString = data.reduce(into: [:]) { result, pair in
            result[pair.key] = String(describing: pair.value)
        }
    }
}

/// Usage summary for a date range
public struct UsageSummary: Sendable {
    public let dateRange: ClosedRange<Date>
    public let totalChats: Int
    public let totalTokens: Int
    public let totalTasks: Int
    public let totalSearches: Int
    public let successRate: Double
    public let topFeatures: [String: Int]
    public let topModels: [String]
}
