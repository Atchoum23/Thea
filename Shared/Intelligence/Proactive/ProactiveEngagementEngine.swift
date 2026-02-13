// ProactiveEngagementEngine.swift
// Thea — Autonomous Proactive Initiative System
//
// Decides when and how to proactively engage the user without being asked.
// Bridges: BehavioralFingerprint + HealthCoachingPipeline + Calendar +
// PersonalKnowledgeGraph + SmartNotificationScheduler
//
// Trigger sources:
//   - Time-based: morning briefing, evening review
//   - Health-based: coaching insights, anomalies
//   - Calendar-based: upcoming events, preparation reminders
//   - Pattern-based: detected routine deviations

import Foundation
import OSLog

// MARK: - Proactive Engagement Engine

@MainActor
@Observable
final class ProactiveEngagementEngine {
    static let shared = ProactiveEngagementEngine()

    private let logger = Logger(subsystem: "com.thea.app", category: "ProactiveEngine")

    // MARK: - Configuration

    /// Master switch for proactive engagement
    var isEnabled = true

    /// Maximum proactive messages per day
    var maxDailyEngagements = 5

    /// Minimum hours between engagements
    var minEngagementIntervalHours = 2.0

    /// Which engagement types are enabled
    var enabledTypes: Set<EngagementType> = Set(EngagementType.allCases)

    // MARK: - State

    private(set) var todayEngagementCount = 0
    private(set) var lastEngagementDate: Date?
    private(set) var pendingEngagements: [ProactiveEngagement] = []
    private(set) var deliveredEngagements: [ProactiveEngagement] = []
    private var lastResetDate: Date?

    private init() {}

    // MARK: - Main Evaluation Loop

    /// Evaluate all trigger sources and generate proactive engagements.
    /// Call this periodically (e.g., every 30 minutes from app lifecycle).
    func evaluate() async {
        guard isEnabled else { return }
        resetDailyCounterIfNeeded()

        guard todayEngagementCount < maxDailyEngagements else {
            logger.debug("Daily engagement limit reached (\(self.maxDailyEngagements))")
            return
        }

        // Check minimum interval
        if let lastDate = lastEngagementDate {
            let hoursSince = Date().timeIntervalSince(lastDate) / 3600
            guard hoursSince >= minEngagementIntervalHours else {
                return
            }
        }

        var engagements: [ProactiveEngagement] = []

        // Source 1: Time-based triggers
        if enabledTypes.contains(.morningBriefing) || enabledTypes.contains(.eveningReview) {
            engagements.append(contentsOf: evaluateTimeTriggers())
        }

        // Source 2: Health coaching insights
        if enabledTypes.contains(.healthInsight) {
            engagements.append(contentsOf: await evaluateHealthTriggers())
        }

        // Source 3: Calendar awareness
        if enabledTypes.contains(.calendarPrep) {
            engagements.append(contentsOf: await evaluateCalendarTriggers())
        }

        // Source 4: Pattern deviations
        if enabledTypes.contains(.patternDeviation) {
            engagements.append(contentsOf: evaluatePatternTriggers())
        }

        // Source 5: Goal check-ins
        if enabledTypes.contains(.goalCheckin) {
            engagements.append(contentsOf: evaluateGoalTriggers())
        }

        // Sort by priority and take the top engagement
        engagements.sort { $0.priority > $1.priority }
        pendingEngagements = engagements

        if let topEngagement = engagements.first {
            await deliverEngagement(topEngagement)
        }
    }

    // MARK: - Time-Based Triggers

    private func evaluateTimeTriggers() -> [ProactiveEngagement] {
        var engagements: [ProactiveEngagement] = []
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())

        // Morning briefing (7-9 AM)
        if enabledTypes.contains(.morningBriefing), hour >= 7, hour <= 9 {
            if !hasDeliveredToday(type: .morningBriefing) {
                engagements.append(ProactiveEngagement(
                    type: .morningBriefing,
                    title: "Good morning!",
                    message: "Ready for your daily briefing? I can summarize your schedule, health trends, and priorities.",
                    priority: 8,
                    actionSuggestion: "Would you like a morning briefing?"
                ))
            }
        }

        // Evening review (8-10 PM)
        if enabledTypes.contains(.eveningReview), hour >= 20, hour <= 22 {
            if !hasDeliveredToday(type: .eveningReview) {
                engagements.append(ProactiveEngagement(
                    type: .eveningReview,
                    title: "Evening check-in",
                    message: "How was your day? I can help you reflect on accomplishments and plan for tomorrow.",
                    priority: 6,
                    actionSuggestion: "Would you like an evening review?"
                ))
            }
        }

        return engagements
    }

    // MARK: - Health Triggers

    private func evaluateHealthTriggers() async -> [ProactiveEngagement] {
        let pipeline = HealthCoachingPipeline.shared

        // Run analysis if stale
        if pipeline.lastAnalysisDate == nil || Date().timeIntervalSince(pipeline.lastAnalysisDate!) > 6 * 3600 {
            await pipeline.runAnalysis()
        }

        return pipeline.activeInsights.prefix(2).map { insight in
            ProactiveEngagement(
                type: .healthInsight,
                title: insight.title,
                message: "\(insight.message)\n\nSuggestion: \(insight.suggestion)",
                priority: insight.severity == .critical ? 9 : 5,
                actionSuggestion: nil
            )
        }
    }

    // MARK: - Calendar Triggers

    private func evaluateCalendarTriggers() async -> [ProactiveEngagement] {
        #if os(macOS)
        let integration = CalendarIntegration.shared
        guard let events = try? await integration.getTodayEvents() else {
            return []
        }

        let now = Date()
        let upcoming = events.filter { event in
            let timeUntil = event.startDate.timeIntervalSince(now)
            return timeUntil > 0 && timeUntil < 3600 // Within next hour
        }

        return upcoming.prefix(1).map { event in
            let minutes = Int(event.startDate.timeIntervalSince(now) / 60)
            return ProactiveEngagement(
                type: .calendarPrep,
                title: "Upcoming: \(event.title)",
                message: "\(event.title) starts in \(minutes) minutes. Would you like me to help prepare?",
                priority: 7,
                actionSuggestion: "Prepare for \(event.title)"
            )
        }
        #else
        return []
        #endif
    }

    // MARK: - Pattern Deviation Triggers

    private func evaluatePatternTriggers() -> [ProactiveEngagement] {
        let fingerprint = BehavioralFingerprint.shared
        let context = fingerprint.currentContext()

        // If user is typically active now but receptivity is unusually low
        if context.isAwake, context.receptivity < 0.2 {
            return [ProactiveEngagement(
                type: .patternDeviation,
                title: "Unusual quiet period",
                message: "You're usually more active at this time. Everything okay?",
                priority: 3,
                actionSuggestion: nil
            )]
        }

        return []
    }

    // MARK: - Goal Triggers

    private func evaluateGoalTriggers() -> [ProactiveEngagement] {
        // Check behavioral fingerprint for activity patterns
        let fingerprint = BehavioralFingerprint.shared
        let calendar = Calendar.current
        let weekday = (calendar.component(.weekday, from: Date()) + 5) % 7

        guard let day = dayOfWeek(from: weekday) else { return [] }

        let exerciseTime = fingerprint.bestTimeFor(.exercise, on: day)
        let currentHour = calendar.component(.hour, from: Date())

        // Nudge if it's the user's typical exercise time
        if currentHour == exerciseTime, !hasDeliveredToday(type: .goalCheckin) {
            return [ProactiveEngagement(
                type: .goalCheckin,
                title: "Activity reminder",
                message: "This is usually when you exercise. Ready to get moving?",
                priority: 4,
                actionSuggestion: "Start an exercise session"
            )]
        }

        return []
    }

    // MARK: - Delivery

    private func deliverEngagement(_ engagement: ProactiveEngagement) async {
        logger.info("Delivering proactive engagement: \(engagement.title)")

        await SmartNotificationScheduler.shared.scheduleOptimally(
            title: engagement.title,
            body: engagement.message,
            priority: engagement.priority >= 8 ? .high : .normal
        )

        todayEngagementCount += 1
        lastEngagementDate = Date()
        deliveredEngagements.append(engagement)
    }

    // MARK: - Helpers

    private func hasDeliveredToday(type: EngagementType) -> Bool {
        let calendar = Calendar.current
        return deliveredEngagements.contains { engagement in
            engagement.type == type && calendar.isDateInToday(engagement.timestamp)
        }
    }

    private func resetDailyCounterIfNeeded() {
        let calendar = Calendar.current
        if let lastReset = lastResetDate, calendar.isDateInToday(lastReset) {
            return
        }
        todayEngagementCount = 0
        deliveredEngagements.removeAll()
        lastResetDate = Date()
    }

    private func dayOfWeek(from index: Int) -> DayOfWeek? {
        switch index {
        case 0: .monday
        case 1: .tuesday
        case 2: .wednesday
        case 3: .thursday
        case 4: .friday
        case 5: .saturday
        case 6: .sunday
        default: nil
        }
    }
}

// MARK: - Types

enum EngagementType: String, CaseIterable, Sendable {
    case morningBriefing
    case eveningReview
    case healthInsight
    case calendarPrep
    case patternDeviation
    case goalCheckin
}

struct ProactiveEngagement: Identifiable, Sendable {
    let id = UUID()
    let type: EngagementType
    let title: String
    let message: String
    let priority: Int  // 1-10
    let actionSuggestion: String?
    let timestamp = Date()
}
