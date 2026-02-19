// HealthCoachingPipeline.swift
// Thea — AI-Driven Health Coaching
//
// Bridges HealthKit data → AI analysis → personalized coaching insights.
// Runs periodically to analyze trends and generate actionable suggestions.
// Uses BehavioralFingerprint for optimal coaching delivery timing.

import Foundation
import OSLog

// MARK: - Health Coaching Pipeline

@MainActor
@Observable
final class HealthCoachingPipeline {
    static let shared = HealthCoachingPipeline()

    private let logger = Logger(subsystem: "com.thea.app", category: "HealthCoaching")

    // MARK: - State

    private(set) var lastAnalysis: HealthAnalysisReport?
    private(set) var activeInsights: [CoachingInsight] = []
    private(set) var isAnalyzing = false
    private(set) var lastAnalysisDate: Date?

    // MARK: - Configuration

    /// Whether coaching is enabled
    var isEnabled = true

    /// Minimum hours between analyses (avoid excessive API calls)
    var analysisCooldownHours = 6

    /// Maximum number of active insights shown to user
    var maxActiveInsights = 5

    /// Whether to use smart notification scheduling for insight delivery
    var useSmartScheduling = true

    /// Optional messaging gateway channel for daily health summaries (P6).
    /// When set, delivers coaching insights to this channel via TheaMessagingGateway.
    /// Format: "platform:chatId" e.g. "telegram:123456789"
    var gatewayDeliveryChannel: String?

    /// Whether to also deliver insights via the messaging gateway (in addition to local notifications).
    var useGatewayDelivery = false

    private init() {}

    // MARK: - Analysis Pipeline

    /// Run the full coaching pipeline: fetch data → analyze → generate insights → notify
    func runAnalysis() async {
        guard isEnabled else { return }
        guard !isAnalyzing else { return }

        // Respect cooldown
        if let lastDate = lastAnalysisDate {
            let hoursSince = Date().timeIntervalSince(lastDate) / 3600
            guard hoursSince >= Double(analysisCooldownHours) else {
                logger.debug("Analysis cooldown active (\(String(format: "%.1f", hoursSince))h < \(self.analysisCooldownHours)h)")
                return
            }
        }

        isAnalyzing = true
        defer {
            isAnalyzing = false
            lastAnalysisDate = Date()
        }

        logger.info("Starting health coaching analysis...")

        // Step 1: Gather health data
        let healthData = await gatherHealthData()
        guard !healthData.isEmpty else {
            logger.info("No health data available for analysis")
            return
        }

        // Step 2: Analyze with rule-based engine
        let insights = analyzeHealthData(healthData)

        // Step 3: Build report
        let report = HealthAnalysisReport(
            date: Date(),
            dataPoints: healthData,
            insights: insights,
            overallScore: calculateOverallScore(from: healthData)
        )

        lastAnalysis = report
        activeInsights = Array(insights.prefix(maxActiveInsights))

        // Step 4: Deliver top insight via smart notification
        if let topInsight = insights.first {
            await deliverInsight(topInsight)
        }

        logger.info("Health analysis complete: \(insights.count) insight(s) generated")
    }

    // MARK: - Data Gathering

    private func gatherHealthData() async -> [HealthDataPoint] {
        var dataPoints: [HealthDataPoint] = []
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let dayRange = DateInterval(start: calendar.startOfDay(for: now), end: now)
        let weekRange = DateInterval(start: weekAgo, end: now)

        #if canImport(HealthKit)
        let service = HealthKitService()
        do {
            _ = try await service.requestAuthorization()
        } catch {
            logger.debug("HealthKit authorization failed: \(error.localizedDescription)")
            return dataPoints
        }

        // Sleep data (last 7 days)
        do {
            let sleepRecords = try await service.fetchSleepData(for: weekRange)
            for record in sleepRecords {
                dataPoints.append(.sleep(
                    totalMinutes: record.totalMinutes,
                    deepMinutes: record.deepMinutes,
                    remMinutes: record.remMinutes,
                    quality: record.quality,
                    date: record.startDate
                ))
            }
        } catch {
            logger.warning("Failed to fetch sleep data: \(error.localizedDescription)")
        }

        // Activity data (today)
        do {
            let activity = try await service.fetchActivityData(for: now)
            dataPoints.append(.activity(
                steps: activity.steps,
                activeCalories: Int(activity.activeCalories),
                exerciseMinutes: activity.activeMinutes,
                date: now
            ))
        } catch {
            logger.warning("Failed to fetch activity data: \(error.localizedDescription)")
        }

        // Heart rate data (last 24 hours)
        do {
            let heartRates = try await service.fetchHeartRateData(for: dayRange)
            let hrSum = heartRates.reduce(into: 0) { $0 += $1.beatsPerMinute }
            let avgHR = heartRates.isEmpty ? 0 : hrSum / heartRates.count
            let restingRecords = heartRates.filter { $0.context == .resting }
            let restingSum = restingRecords.reduce(into: 0) { $0 += $1.beatsPerMinute }
            let restingHR = restingRecords.isEmpty ? 0 : restingSum / restingRecords.count
            dataPoints.append(.heartRate(
                averageBPM: avgHR,
                restingBPM: restingHR,
                date: now
            ))
        } catch {
            logger.warning("Failed to fetch heart rate data: \(error.localizedDescription)")
        }

        // Blood pressure (last 7 days)
        do {
            let bpReadings = try await service.fetchBloodPressureData(for: weekRange)
            if let latest = bpReadings.last {
                dataPoints.append(.bloodPressure(
                    systolic: latest.systolic,
                    diastolic: latest.diastolic,
                    date: latest.timestamp
                ))
            }
        } catch {
            logger.warning("Failed to fetch blood pressure data: \(error.localizedDescription)")
        }
        #endif

        return dataPoints
    }

    // MARK: - Analysis Engine

    private func analyzeHealthData(_ data: [HealthDataPoint]) -> [CoachingInsight] {
        var insights: [CoachingInsight] = []

        insights.append(contentsOf: analyzeSleepData(from: data))
        insights.append(contentsOf: analyzeActivityData(from: data))
        insights.append(contentsOf: analyzeHeartRateData(from: data))
        insights.append(contentsOf: analyzeBloodPressureData(from: data))

        // Sort by severity
        insights.sort { $0.severity.rank > $1.severity.rank }
        return insights
    }

    private func analyzeSleepData(from data: [HealthDataPoint]) -> [CoachingInsight] {
        var insights: [CoachingInsight] = []

        let sleepData = data.compactMap { point -> (Int, Int, Int, SleepQuality, Date)? in
            if case let .sleep(total, deep, rem, quality, date) = point {
                return (total, deep, rem, quality, date)
            }
            return nil
        }

        guard !sleepData.isEmpty else { return insights }

        let totalSleepMinutes: Int = sleepData.reduce(into: 0) { $0 += $1.0 }
        let avgSleepMinutes: Int = totalSleepMinutes / sleepData.count
        var deepPercentSum: Double = 0
        for entry in sleepData {
            deepPercentSum += Double(entry.1) / Double(max(entry.0, 1))
        }
        let avgDeepPercent: Double = deepPercentSum / Double(sleepData.count) * 100

        if avgSleepMinutes < 360 {
            insights.append(CoachingInsight(
                category: .sleep,
                severity: .warning,
                title: "Sleep duration below target",
                message: "You averaged \(avgSleepMinutes / 60)h \(avgSleepMinutes % 60)m of sleep this week. Adults need 7-9 hours for optimal health.",
                suggestion: "Try setting a consistent bedtime alarm 8 hours before your wake time.",
                dataValue: Double(avgSleepMinutes)
            ))
        }

        if avgDeepPercent < 15 {
            insights.append(CoachingInsight(
                category: .sleep,
                severity: .info,
                title: "Deep sleep could improve",
                message: "Deep sleep averaged \(String(format: "%.0f%%", avgDeepPercent)) this week. Target is 15-25%.",
                suggestion: "Avoid screens 1 hour before bed and keep the room cool (65-68\u{00B0}F).",
                dataValue: avgDeepPercent
            ))
        }

        let poorNights = sleepData.filter { $0.3 == .poor }.count
        if poorNights >= 3 {
            insights.append(CoachingInsight(
                category: .sleep,
                severity: .warning,
                title: "Multiple poor sleep nights",
                message: "\(poorNights) out of \(sleepData.count) nights rated as poor quality.",
                suggestion: "Consider evaluating your sleep environment: temperature, noise, light, and mattress quality.",
                dataValue: Double(poorNights)
            ))
        }

        return insights
    }

    private func analyzeActivityData(from data: [HealthDataPoint]) -> [CoachingInsight] {
        var insights: [CoachingInsight] = []

        let activityData = data.compactMap { point -> (Int, Int, Int, Date)? in
            if case let .activity(steps, calories, minutes, date) = point {
                return (steps, calories, minutes, date)
            }
            return nil
        }

        guard let today = activityData.last else { return insights }

        if today.0 < 5000 {
            insights.append(CoachingInsight(
                category: .activity,
                severity: .info,
                title: "Step count below target",
                message: "\(today.0) steps today. The recommended target is 7,000-10,000 steps.",
                suggestion: "A 30-minute walk adds roughly 3,000-4,000 steps.",
                dataValue: Double(today.0)
            ))
        }

        if today.2 < 30 {
            insights.append(CoachingInsight(
                category: .activity,
                severity: .info,
                title: "Exercise minutes running low",
                message: "\(today.2) minutes of exercise today. WHO recommends 150 minutes per week (about 22/day).",
                suggestion: "Even 10 minutes of brisk walking counts toward your daily goal.",
                dataValue: Double(today.2)
            ))
        }

        return insights
    }

    private func analyzeHeartRateData(from data: [HealthDataPoint]) -> [CoachingInsight] {
        var insights: [CoachingInsight] = []

        let hrData = data.compactMap { point -> (Int, Int, Date)? in
            if case let .heartRate(avg, resting, date) = point {
                return (avg, resting, date)
            }
            return nil
        }

        if let latestHR = hrData.last, latestHR.1 > 0, latestHR.1 > 100 {
            insights.append(CoachingInsight(
                category: .heartRate,
                severity: .warning,
                title: "Elevated resting heart rate",
                message: "Resting heart rate is \(latestHR.1) BPM. Normal range is 60-100 BPM, but consistently high readings may warrant attention.",
                suggestion: "Factors: stress, caffeine, dehydration, lack of sleep. If persistent, consult your doctor.",
                dataValue: Double(latestHR.1)
            ))
        }

        return insights
    }

    private func analyzeBloodPressureData(from data: [HealthDataPoint]) -> [CoachingInsight] {
        var insights: [CoachingInsight] = []

        let bpData = data.compactMap { point -> (Int, Int, Date)? in
            if case let .bloodPressure(sys, dia, date) = point {
                return (sys, dia, date)
            }
            return nil
        }

        guard let latestBP = bpData.last else { return insights }

        if latestBP.0 >= 140 || latestBP.1 >= 90 {
            insights.append(CoachingInsight(
                category: .bloodPressure,
                severity: .critical,
                title: "High blood pressure reading",
                message: "Latest reading: \(latestBP.0)/\(latestBP.1) mmHg. Stage 2 hypertension threshold is 140/90.",
                suggestion: "Monitor regularly. If readings stay elevated, consult your healthcare provider.",
                dataValue: Double(latestBP.0)
            ))
        } else if latestBP.0 >= 130 || latestBP.1 >= 80 {
            insights.append(CoachingInsight(
                category: .bloodPressure,
                severity: .warning,
                title: "Elevated blood pressure",
                message: "Latest reading: \(latestBP.0)/\(latestBP.1) mmHg. Stage 1 hypertension threshold is 130/80.",
                suggestion: "Reduce sodium, increase physical activity, manage stress. Track readings over the next week.",
                dataValue: Double(latestBP.0)
            ))
        }

        return insights
    }

    // MARK: - Scoring

    private func calculateOverallScore(from data: [HealthDataPoint]) -> Double {
        var scores: [Double] = []

        for point in data {
            switch point {
            case let .sleep(total, _, _, quality, _):
                let durationScore = min(Double(total) / 480.0, 1.0) // 8h = perfect
                let qualityScore = Double(quality.score) / 100.0
                scores.append((durationScore + qualityScore) / 2.0)

            case let .activity(steps, _, minutes, _):
                let stepScore = min(Double(steps) / 10000.0, 1.0)
                let exerciseScore = min(Double(minutes) / 30.0, 1.0)
                scores.append((stepScore + exerciseScore) / 2.0)

            case let .heartRate(_, resting, _):
                if resting > 0 {
                    let hrScore = resting <= 70 ? 1.0 : max(0, 1.0 - Double(resting - 70) / 50.0)
                    scores.append(hrScore)
                }

            case let .bloodPressure(systolic, _, _):
                let bpScore = systolic <= 120 ? 1.0 : max(0, 1.0 - Double(systolic - 120) / 40.0)
                scores.append(bpScore)
            }
        }

        return scores.isEmpty ? 0.5 : scores.reduce(0, +) / Double(scores.count)
    }

    // MARK: - Notification Delivery

    private func deliverInsight(_ insight: CoachingInsight) async {
        let priority: NotificationPriority = switch insight.severity {
        case .critical: .high
        case .warning: .normal
        case .info: .low
        case .positive: .low
        }

        if useSmartScheduling {
            await SmartNotificationScheduler.shared.scheduleOptimally(
                title: insight.title,
                body: insight.message,
                priority: priority,
                category: .healthInsight
            )
        } else {
            let service = NotificationService.shared
            do {
                _ = try await service.scheduleReminder(
                    title: insight.title,
                    body: insight.message,
                    at: Date()
                )
            } catch {
                logger.warning("Failed to schedule health insight notification: \(error.localizedDescription)")
            }
        }

        // P6: Also deliver via TheaMessagingGateway if configured
        await deliverViaGatewayIfEnabled(insight)
    }

    /// Deliver a health coaching insight to the configured messaging gateway channel.
    /// Formats the message with emoji for readability in messaging apps.
    private func deliverViaGatewayIfEnabled(_ insight: CoachingInsight) async {
        guard useGatewayDelivery,
              let channelSpec = gatewayDeliveryChannel,
              !channelSpec.isEmpty else { return }

        let parts = channelSpec.split(separator: ":", maxSplits: 1)
        guard parts.count == 2 else {
            logger.warning("Invalid gatewayDeliveryChannel format — expected 'platform:chatId'")
            return
        }
        let platformRaw = String(parts[0])
        let chatId = String(parts[1])

        let emoji: String = switch insight.severity {
        case .critical: "🚨"
        case .warning: "⚠️"
        case .info: "ℹ️"
        case .positive: "✅"
        }
        let formattedMessage = "\(emoji) **Health Insight**: \(insight.title)\n\(insight.message)"

        guard let platform = MessagingPlatform(rawValue: platformRaw) else {
            logger.warning("Unknown platform '\(platformRaw)' for gateway health delivery")
            return
        }

        let outbound = OutboundMessagingMessage(chatId: chatId, content: formattedMessage, replyToId: nil)
        do {
            try await TheaMessagingGateway.shared.send(outbound, via: platform)
            logger.info("Health insight delivered via \(platformRaw)/\(chatId)")
        } catch {
            logger.warning("Failed to deliver health insight via gateway: \(error.localizedDescription)")
        }
    }

    // MARK: - Insight Management

    func dismissInsight(_ id: UUID) {
        activeInsights.removeAll { $0.id == id }
    }

    func clearAllInsights() {
        activeInsights.removeAll()
    }
}

// MARK: - Types

struct HealthAnalysisReport: Sendable {
    let date: Date
    let dataPoints: [HealthDataPoint]
    // periphery:ignore - Reserved: insights property — reserved for future feature activation
    let insights: [CoachingInsight]
    // periphery:ignore - Reserved: insights property reserved for future feature activation
    let overallScore: Double // 0.0-1.0
}

enum HealthDataPoint: Sendable {
    case sleep(totalMinutes: Int, deepMinutes: Int, remMinutes: Int, quality: SleepQuality, date: Date)
    case activity(steps: Int, activeCalories: Int, exerciseMinutes: Int, date: Date)
    case heartRate(averageBPM: Int, restingBPM: Int, date: Date)
    case bloodPressure(systolic: Int, diastolic: Int, date: Date)
}

struct CoachingInsight: Identifiable, Sendable {
    let id = UUID()
    let category: CoachingInsightCategory
    let severity: CoachingSeverity
    let title: String
    let message: String
    let suggestion: String
    // periphery:ignore - Reserved: dataValue property reserved for future feature activation
    let dataValue: Double
}

enum CoachingInsightCategory: String, Sendable {
    case sleep
    case activity
    case heartRate
    case bloodPressure
    case nutrition
    case stress
}

enum CoachingSeverity: String, Sendable {
    case critical   // Requires attention
    case warning    // Trend needs correction
    case info       // Room for improvement
    case positive   // Good job, keep going

    var rank: Int {
        switch self {
        case .critical: 3
        case .warning: 2
        case .info: 1
        case .positive: 0
        }
    }
}
