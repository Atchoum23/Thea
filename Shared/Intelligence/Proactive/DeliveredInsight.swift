// DeliveredInsight.swift
// Thea — Proactive Intelligence Insight Repository
//
// Persists coaching insights and notifications delivered to the user.
// Stores user feedback to improve insight calibration over time.
// Phase Q3: Proactive Intelligence Complete

import Foundation
import SwiftData

// MARK: - Supporting Enums

enum DeliveredInsightCategory: String, Codable, CaseIterable, Sendable {
    case health = "Health"
    case productivity = "Productivity"
    case habits = "Habits"
    case recommendations = "Recommendations"
    case focus = "Focus"
    case communication = "Communication"
    case summary = "Summary"

    var symbolName: String {
        switch self {
        case .health: "heart.fill"
        case .productivity: "checkmark.circle.fill"
        case .habits: "repeat.circle.fill"
        case .recommendations: "lightbulb.fill"
        case .focus: "target"
        case .communication: "message.fill"
        case .summary: "doc.text.fill"
        }
    }
}

enum InsightFeedback: String, Codable, Sendable {
    case helpful = "Helpful"
    case notRelevant = "Not Relevant"
    case dismissed = "Dismissed"
}

enum InsightSource: String, Codable, Sendable {
    case healthCoaching = "Health Coaching"
    case behavioralFingerprint = "Behavioral Analysis"
    case metaAI = "Meta-AI"
    case weeklyDigest = "Weekly Digest"
    case smartScheduler = "Smart Scheduler"

    var symbolName: String {
        switch self {
        case .healthCoaching: "heart.text.square"
        case .behavioralFingerprint: "brain.head.profile"
        case .metaAI: "sparkles"
        case .weeklyDigest: "calendar.badge.clock"
        case .smartScheduler: "bell.badge"
        }
    }
}

// MARK: - DeliveredInsight Model

@Model
final class DeliveredInsight {
    var id: UUID
    var title: String
    var body: String
    var insightCategory: String    // DeliveredInsightCategory.rawValue
    var deliveredAt: Date
    var feedbackRaw: String?       // InsightFeedback.rawValue (nil = no feedback)
    var actionTaken: Bool
    var sourceRaw: String          // InsightSource.rawValue
    var relatedEntityID: String?   // Optional: links to KG entity

    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    init(
        title: String,
        body: String,
        category: DeliveredInsightCategory,
        source: InsightSource,
        relatedEntityID: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.body = body
        self.insightCategory = category.rawValue
        self.deliveredAt = Date()
        self.feedbackRaw = nil
        self.actionTaken = false
        self.sourceRaw = source.rawValue
        self.relatedEntityID = relatedEntityID
    }

    var category: DeliveredInsightCategory {
        DeliveredInsightCategory(rawValue: insightCategory) ?? .recommendations
    }

    var userFeedback: InsightFeedback? {
        get { feedbackRaw.flatMap(InsightFeedback.init(rawValue:)) }
        set { feedbackRaw = newValue?.rawValue }
    }

    var source: InsightSource {
        InsightSource(rawValue: sourceRaw) ?? .metaAI
    }
}

// MARK: - InsightRepository

/// Service for creating and querying DeliveredInsight records.
@MainActor
// periphery:ignore - Reserved: AD3 audit — wired in future integration
final class InsightRepository {
    static let shared = InsightRepository()
    private init() {}

    /// Record a new delivered insight into SwiftData.
    func record(
        title: String,
        body: String,
        category: DeliveredInsightCategory,
        source: InsightSource,
        in context: ModelContext
    ) -> DeliveredInsight {
        let insight = DeliveredInsight(
            title: title,
            body: body,
            category: category,
            source: source
        )
        context.insert(insight)
        return insight
    }

    /// Record an insight from a CoachingInsight (bridges HealthCoachingPipeline → repository).
    func record(
        coachingInsight: CoachingInsight,
        in context: ModelContext
    ) -> DeliveredInsight {
        let category: DeliveredInsightCategory
        switch coachingInsight.category {
        case .sleep, .heartRate, .bloodPressure: category = .health
        case .activity, .nutrition: category = .habits
        case .stress: category = .recommendations
        }

        return record(
            title: coachingInsight.title,
            body: coachingInsight.message,
            category: category,
            source: .healthCoaching,
            in: context
        )
    }
}
