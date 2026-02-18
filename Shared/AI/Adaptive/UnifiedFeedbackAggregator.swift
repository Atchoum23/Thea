// UnifiedFeedbackAggregator.swift
// Thea V2 - Unified Feedback Collection and Weighting
//
// Single source of truth for all feedback signals:
// - Explicit: user ratings, overrides, corrections
// - Implicit: regeneration, continuation, abandonment, edits
// - System: latency, success rate, resource utilization, errors
//
// Learns optimal weights for combining signals.
// "Absolutely Everything AI-Powered"

import Foundation
import os.log
import Combine

// MARK: - Feedback Sources

/// All possible sources of feedback for the adaptive system
public enum FeedbackSource: String, CaseIterable, Codable, Sendable {
    // Explicit feedback
    case explicitRating         // User clicked thumbs up/down or gave rating
    case userOverride           // User manually selected different model
    case userCorrection         // User edited/corrected the response
    case explicitPreference     // User stated preference

    // Implicit behavioral feedback
    case conversationContinued  // User continued the conversation (positive)
    case conversationAbandoned  // User left without responding (negative)
    case regenerationRequested  // User asked for new response (negative)
    case editBeforeSend         // User modified query before sending
    case copyToClipboard        // User copied response (positive)
    case shareAction            // User shared the response (positive)

    // System metrics
    case responseLatency        // How fast was the response
    case tokenEfficiency        // Tokens used vs quality
    case successfulCompletion   // Task completed without error
    case errorOccurred          // Error during processing
    case resourceUtilization    // Memory/CPU efficiency
    case memoryPressure         // System was under memory pressure
    case thermalThrottling      // System was thermally throttled

    /// Default weight for this source (learned over time)
    var defaultWeight: Double {
        switch self {
        case .explicitRating: return 1.0
        case .userOverride: return 0.9
        case .userCorrection: return 0.8
        case .explicitPreference: return 0.85
        case .conversationContinued: return 0.5
        case .conversationAbandoned: return 0.6
        case .regenerationRequested: return 0.7
        case .editBeforeSend: return 0.3
        case .copyToClipboard: return 0.4
        case .shareAction: return 0.5
        case .responseLatency: return 0.4
        case .tokenEfficiency: return 0.2
        case .successfulCompletion: return 0.5
        case .errorOccurred: return 0.95
        case .resourceUtilization: return 0.2
        case .memoryPressure: return 0.3
        case .thermalThrottling: return 0.25
        }
    }

    /// Whether higher values are better (vs lower being better)
    var higherIsBetter: Bool {
        switch self {
        case .explicitRating, .conversationContinued, .copyToClipboard,
             .shareAction, .tokenEfficiency, .successfulCompletion:
            return true
        case .userOverride, .userCorrection, .conversationAbandoned,
             .regenerationRequested, .editBeforeSend, .responseLatency,
             .errorOccurred, .resourceUtilization, .memoryPressure,
             .thermalThrottling, .explicitPreference:
            return false
        }
    }

    /// Category for grouping
    var category: FeedbackCategory {
        switch self {
        case .explicitRating, .userOverride, .userCorrection, .explicitPreference:
            return .explicit
        case .conversationContinued, .conversationAbandoned, .regenerationRequested,
             .editBeforeSend, .copyToClipboard, .shareAction:
            return .implicit
        case .responseLatency, .tokenEfficiency, .successfulCompletion,
             .errorOccurred, .resourceUtilization, .memoryPressure, .thermalThrottling:
            return .system
        }
    }
}

public enum FeedbackCategory: String, CaseIterable, Codable, Sendable {
    case explicit   // Direct user feedback
    case implicit   // Inferred from behavior
    case system     // System metrics
}

// MARK: - Feedback Event

/// A single feedback event
public struct FeedbackEvent: Codable, Sendable, Identifiable {
    public let id: UUID
    public let source: FeedbackSource
    public let rawValue: Double         // Original value in source's scale
    public let normalizedValue: Double  // Normalized to [0, 1] where 1 is best
    public let confidence: Double       // How reliable is this signal (0-1)
    public let timestamp: Date
    public let context: FeedbackContext

    public init(
        source: FeedbackSource,
        rawValue: Double,
        normalizedValue: Double,
        confidence: Double = 1.0,
        context: FeedbackContext
    ) {
        self.id = UUID()
        self.source = source
        self.rawValue = rawValue
        self.normalizedValue = normalizedValue.feedbackClamped(to: 0...1)
        self.confidence = confidence.feedbackClamped(to: 0...1)
        self.timestamp = Date()
        self.context = context
    }

    /// Time-decayed value
    public func decayedValue(halfLifeSeconds: TimeInterval = 604800) -> Double {  // 1 week default
        let age = Date().timeIntervalSince(timestamp)
        let decayFactor = pow(0.5, age / halfLifeSeconds)
        return normalizedValue * decayFactor
    }

    /// Weighted value combining normalization, confidence, and decay
    public func weightedValue(weight: Double, halfLifeSeconds: TimeInterval = 604800) -> Double {
        decayedValue(halfLifeSeconds: halfLifeSeconds) * confidence * weight
    }
}

/// Context for a feedback event
public struct FeedbackContext: Codable, Hashable, Sendable {
    public let modelId: String?
    public let taskType: String?
    public let conversationId: String?
    public let messageId: String?
    public let sessionId: String?

    public init(
        modelId: String? = nil,
        taskType: String? = nil,
        conversationId: String? = nil,
        messageId: String? = nil,
        sessionId: String? = nil
    ) {
        self.modelId = modelId
        self.taskType = taskType
        self.conversationId = conversationId
        self.messageId = messageId
        self.sessionId = sessionId
    }
}

// MARK: - Aggregated Feedback

/// Aggregated feedback score combining multiple sources
public struct AggregatedFeedback: Sendable {
    public let compositeScore: Double           // Final weighted score [0, 1]
    public let confidence: Double               // Overall confidence
    public let contributingEvents: Int          // Number of events
    public let breakdown: [FeedbackSource: Double]  // Per-source contributions
    public let categoryScores: [FeedbackCategory: Double]
    public let timestamp: Date

    public init(
        compositeScore: Double,
        confidence: Double,
        contributingEvents: Int,
        breakdown: [FeedbackSource: Double],
        categoryScores: [FeedbackCategory: Double]
    ) {
        self.compositeScore = compositeScore
        self.confidence = confidence
        self.contributingEvents = contributingEvents
        self.breakdown = breakdown
        self.categoryScores = categoryScores
        self.timestamp = Date()
    }
}

// MARK: - Unified Feedback Aggregator

/// Central aggregator for all feedback signals
@MainActor
public final class UnifiedFeedbackAggregator: ObservableObject {
    public static let shared = UnifiedFeedbackAggregator()

    private let logger = Logger(subsystem: "ai.thea.app", category: "FeedbackAggregator")

    // MARK: - State

    /// All collected feedback events
    private var feedbackEvents: [FeedbackEvent] = []

    /// Learned weights for each feedback source
    @Published public private(set) var sourceWeights: [FeedbackSource: Double]

    /// Events grouped by context (for efficient lookup)
    private var eventsByModel: [String: [FeedbackEvent]] = [:]
    private var eventsByConversation: [String: [FeedbackEvent]] = [:]

    /// Statistics
    @Published public private(set) var totalEventsProcessed: Int = 0
    @Published public private(set) var lastAggregation: Date?

    // MARK: - Configuration

    /// Maximum events to keep in memory
    private let maxEventsInMemory = 10000

    /// Decay half-life for temporal weighting
    public var decayHalfLifeSeconds: TimeInterval = 604800  // 1 week

    /// Minimum events needed for reliable aggregation
    public var minEventsForReliability: Int = 5

    /// Category weights for final score
    public var categoryWeights: [FeedbackCategory: Double] = [
        .explicit: 0.5,
        .implicit: 0.3,
        .system: 0.2
    ]

    // MARK: - Persistence

    private let persistenceKey = "UnifiedFeedbackAggregator.state"

    // MARK: - Initialization

    private init() {
        // Initialize with default weights
        var weights: [FeedbackSource: Double] = [:]
        for source in FeedbackSource.allCases {
            weights[source] = source.defaultWeight
        }
        self.sourceWeights = weights

        loadState()
        logger.info("UnifiedFeedbackAggregator initialized")
    }

    // MARK: - Recording Feedback

    /// Record a feedback event
    public func record(_ event: FeedbackEvent) {
        feedbackEvents.append(event)

        // Index by context
        if let modelId = event.context.modelId {
            eventsByModel[modelId, default: []].append(event)
        }
        if let conversationId = event.context.conversationId {
            eventsByConversation[conversationId, default: []].append(event)
        }

        totalEventsProcessed += 1

        // Trim if needed
        if feedbackEvents.count > maxEventsInMemory {
            trimOldEvents()
        }

        // Persist periodically
        if totalEventsProcessed % 100 == 0 {
            saveState()
        }

        logger.debug("Recorded \(event.source.rawValue): \(event.normalizedValue, format: .fixed(precision: 2))")
    }

    /// Record explicit rating (1-5 stars or thumbs up/down)
    public func recordRating(_ rating: Int, maxRating: Int = 5, context: FeedbackContext) {
        let normalized = Double(rating) / Double(maxRating)
        let event = FeedbackEvent(
            source: .explicitRating,
            rawValue: Double(rating),
            normalizedValue: normalized,
            confidence: 1.0,
            context: context
        )
        record(event)
    }

    /// Record thumbs up/down
    public func recordThumbsUpDown(isPositive: Bool, context: FeedbackContext) {
        let event = FeedbackEvent(
            source: .explicitRating,
            rawValue: isPositive ? 1.0 : 0.0,
            normalizedValue: isPositive ? 1.0 : 0.0,
            confidence: 0.9,
            context: context
        )
        record(event)
    }

    /// Record user override (selected different model)
    public func recordUserOverride(context: FeedbackContext) {
        let event = FeedbackEvent(
            source: .userOverride,
            rawValue: 1.0,
            normalizedValue: 0.0,  // Override is negative signal
            confidence: 0.9,
            context: context
        )
        record(event)
    }

    /// Record regeneration request
    public func recordRegeneration(context: FeedbackContext) {
        let event = FeedbackEvent(
            source: .regenerationRequested,
            rawValue: 1.0,
            normalizedValue: 0.2,  // Regeneration is mostly negative
            confidence: 0.8,
            context: context
        )
        record(event)
    }

    /// Record conversation continuation (implicit positive)
    public func recordConversationContinued(context: FeedbackContext) {
        let event = FeedbackEvent(
            source: .conversationContinued,
            rawValue: 1.0,
            normalizedValue: 0.7,
            confidence: 0.6,  // Lower confidence for implicit
            context: context
        )
        record(event)
    }

    /// Record conversation abandonment (implicit negative)
    public func recordConversationAbandoned(context: FeedbackContext) {
        let event = FeedbackEvent(
            source: .conversationAbandoned,
            rawValue: 1.0,
            normalizedValue: 0.3,
            confidence: 0.5,  // Even lower - could be external factor
            context: context
        )
        record(event)
    }

    /// Record response latency
    public func recordLatency(milliseconds: Int, context: FeedbackContext) {
        // Normalize: <1s = excellent, 1-3s = good, 3-10s = okay, >10s = poor
        let seconds = Double(milliseconds) / 1000.0
        let normalized: Double
        if seconds < 1 {
            normalized = 1.0
        } else if seconds < 3 {
            normalized = 0.9 - (seconds - 1) * 0.2
        } else if seconds < 10 {
            normalized = 0.5 - (seconds - 3) * 0.05
        } else {
            normalized = max(0.1, 0.15 - (seconds - 10) * 0.01)
        }

        let event = FeedbackEvent(
            source: .responseLatency,
            rawValue: seconds,
            normalizedValue: normalized,
            confidence: 1.0,
            context: context
        )
        record(event)
    }

    /// Record error occurrence
    public func recordError(context: FeedbackContext) {
        let event = FeedbackEvent(
            source: .errorOccurred,
            rawValue: 1.0,
            normalizedValue: 0.0,
            confidence: 1.0,
            context: context
        )
        record(event)
    }

    /// Record successful completion
    public func recordSuccess(context: FeedbackContext) {
        let event = FeedbackEvent(
            source: .successfulCompletion,
            rawValue: 1.0,
            normalizedValue: 1.0,
            confidence: 0.8,
            context: context
        )
        record(event)
    }

    // MARK: - Aggregation

    /// Get aggregated feedback for a model
    public func aggregateForModel(_ modelId: String) -> AggregatedFeedback {
        let events = eventsByModel[modelId] ?? []
        return aggregate(events: events)
    }

    /// Get aggregated feedback for a conversation
    public func aggregateForConversation(_ conversationId: String) -> AggregatedFeedback {
        let events = eventsByConversation[conversationId] ?? []
        return aggregate(events: events)
    }

    /// Get overall aggregated feedback
    public func aggregateAll() -> AggregatedFeedback {
        aggregate(events: feedbackEvents)
    }

    /// Core aggregation logic
    private func aggregate(events: [FeedbackEvent]) -> AggregatedFeedback {
        guard !events.isEmpty else {
            return AggregatedFeedback(
                compositeScore: 0.5,
                confidence: 0.0,
                contributingEvents: 0,
                breakdown: [:],
                categoryScores: [:]
            )
        }

        var breakdown: [FeedbackSource: Double] = [:]
        var categoryTotals: [FeedbackCategory: (score: Double, weight: Double)] = [:]
        var totalWeight: Double = 0

        for event in events {
            let weight = sourceWeights[event.source] ?? event.source.defaultWeight
            let weighted = event.weightedValue(weight: weight, halfLifeSeconds: decayHalfLifeSeconds)

            // Accumulate per-source
            breakdown[event.source, default: 0] += weighted

            // Accumulate per-category
            let category = event.source.category
            let current = categoryTotals[category] ?? (0, 0)
            categoryTotals[category] = (current.score + weighted, current.weight + weight * event.confidence)

            totalWeight += weight * event.confidence
        }

        // Normalize breakdown
        if totalWeight > 0 {
            for source in breakdown.keys {
                breakdown[source]! /= totalWeight
            }
        }

        // Calculate category scores
        var categoryScores: [FeedbackCategory: Double] = [:]
        for (category, totals) in categoryTotals {
            if totals.weight > 0 {
                categoryScores[category] = totals.score / totals.weight
            }
        }

        // Calculate composite score with category weighting
        var compositeScore: Double = 0
        var compositeWeight: Double = 0
        for (category, score) in categoryScores {
            let catWeight = categoryWeights[category] ?? 0.33
            compositeScore += score * catWeight
            compositeWeight += catWeight
        }
        if compositeWeight > 0 {
            compositeScore /= compositeWeight
        }

        // Calculate confidence based on event count and recency
        let eventConfidence = min(1.0, Double(events.count) / Double(minEventsForReliability * 5))
        let avgEventAge = events.map { Date().timeIntervalSince($0.timestamp) }.reduce(0, +) / Double(events.count)
        let recencyConfidence = max(0, 1.0 - avgEventAge / (decayHalfLifeSeconds * 2))
        let confidence = (eventConfidence * 0.6 + recencyConfidence * 0.4)

        lastAggregation = Date()

        return AggregatedFeedback(
            compositeScore: compositeScore,
            confidence: confidence,
            contributingEvents: events.count,
            breakdown: breakdown,
            categoryScores: categoryScores
        )
    }

    // MARK: - Weight Learning

    /// Update source weights based on observed correlation with ground truth
    public func updateWeights(groundTruthSatisfaction: Double, forEvents events: [FeedbackEvent]) {
        guard !events.isEmpty else { return }

        // Simple gradient-based weight update
        let learningRate = 0.01

        for event in events {
            let currentWeight = sourceWeights[event.source] ?? event.source.defaultWeight
            let prediction = event.normalizedValue
            let error = groundTruthSatisfaction - prediction

            // If event's direction matches ground truth, increase weight
            // If it diverges, decrease weight
            let gradient = error * event.confidence
            let newWeight = currentWeight + learningRate * gradient
            sourceWeights[event.source] = newWeight.feedbackClamped(to: 0.01...2.0)
        }

        logger.debug("Updated feedback source weights based on ground truth")
    }

    /// Get current weight for a source
    public func getWeight(_ source: FeedbackSource) -> Double {
        sourceWeights[source] ?? source.defaultWeight
    }

    // MARK: - Cleanup

    private func trimOldEvents() {
        // Keep most recent events
        let cutoff = maxEventsInMemory / 2
        feedbackEvents = Array(feedbackEvents.suffix(cutoff))

        // Rebuild indices
        eventsByModel.removeAll()
        eventsByConversation.removeAll()

        for event in feedbackEvents {
            if let modelId = event.context.modelId {
                eventsByModel[modelId, default: []].append(event)
            }
            if let conversationId = event.context.conversationId {
                eventsByConversation[conversationId, default: []].append(event)
            }
        }

        logger.debug("Trimmed feedback events to \(self.feedbackEvents.count)")
    }

    // MARK: - Persistence

    private func saveState() {
        let state = AggregatorState(
            sourceWeights: sourceWeights,
            recentEvents: Array(feedbackEvents.suffix(1000)),  // Keep last 1000
            totalEventsProcessed: totalEventsProcessed
        )

        do {
            let data = try JSONEncoder().encode(state)
            UserDefaults.standard.set(data, forKey: persistenceKey)
        } catch {
            logger.error("Failed to encode AggregatorState: \(error.localizedDescription)")
        }
    }

    private func loadState() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey) else { return }
        let state: AggregatorState
        do {
            state = try JSONDecoder().decode(AggregatorState.self, from: data)
        } catch {
            logger.error("Failed to decode AggregatorState: \(error.localizedDescription)")
            return
        }

        self.sourceWeights = state.sourceWeights
        self.feedbackEvents = state.recentEvents
        self.totalEventsProcessed = state.totalEventsProcessed

        // Rebuild indices
        for event in feedbackEvents {
            if let modelId = event.context.modelId {
                eventsByModel[modelId, default: []].append(event)
            }
            if let conversationId = event.context.conversationId {
                eventsByConversation[conversationId, default: []].append(event)
            }
        }

        logger.info("Loaded feedback aggregator state: \(self.totalEventsProcessed) total events")
    }

    private struct AggregatorState: Codable {
        let sourceWeights: [FeedbackSource: Double]
        let recentEvents: [FeedbackEvent]
        let totalEventsProcessed: Int
    }

    // MARK: - Reset

    /// Reset all feedback data
    public func resetAll() {
        feedbackEvents.removeAll()
        eventsByModel.removeAll()
        eventsByConversation.removeAll()
        totalEventsProcessed = 0

        // Reset weights to defaults
        for source in FeedbackSource.allCases {
            sourceWeights[source] = source.defaultWeight
        }

        saveState()
        logger.warning("Reset all feedback data")
    }

    // MARK: - Diagnostics

    /// Get feedback statistics
    public func getStatistics() -> AggregatorFeedbackStatistics {
        var sourceStats: [FeedbackSource: AggregatorSourceStatistics] = [:]

        for source in FeedbackSource.allCases {
            let events = feedbackEvents.filter { $0.source == source }
            let avgValue = events.isEmpty ? 0.5 : events.map(\.normalizedValue).reduce(0, +) / Double(events.count)
            sourceStats[source] = AggregatorSourceStatistics(
                eventCount: events.count,
                averageValue: avgValue,
                currentWeight: sourceWeights[source] ?? source.defaultWeight
            )
        }

        return AggregatorFeedbackStatistics(
            totalEvents: feedbackEvents.count,
            totalProcessed: totalEventsProcessed,
            sourceStatistics: sourceStats,
            lastAggregation: lastAggregation
        )
    }
}

// MARK: - Statistics Types

public struct AggregatorFeedbackStatistics: Sendable {
    public let totalEvents: Int
    public let totalProcessed: Int
    public let sourceStatistics: [FeedbackSource: AggregatorSourceStatistics]
    public let lastAggregation: Date?
}

public struct AggregatorSourceStatistics: Sendable {
    public let eventCount: Int
    public let averageValue: Double
    public let currentWeight: Double
}

// MARK: - Helper Extensions

extension Double {
    fileprivate func feedbackClamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
