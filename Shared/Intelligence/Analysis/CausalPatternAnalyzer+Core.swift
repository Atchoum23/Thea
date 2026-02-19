// CausalPatternAnalyzer+Core.swift
// Thea
//
// CausalPatternAnalyzer actor implementation.

import Foundation
import Observation
import os.log

private let causalLogger = Logger(subsystem: "ai.thea.app", category: "CausalPatternAnalyzer")

// MARK: - Causal Pattern Analyzer

@MainActor
@Observable
public final class CausalPatternAnalyzer {
    public static let shared = CausalPatternAnalyzer()

    // MARK: - State

    private(set) var discoveredRelationships: [CausalRelationship] = []
    private(set) var recentInsights: [CausalInsight] = []
    private(set) var isAnalyzing = false

    // MARK: - Timeline

    private var eventTimeline: [CausalTimelineEntry] = []

    // MARK: - Configuration

    private let maxTimelineEntries = 1000
    private let minEvidenceForRelationship = 3
    private let confidenceThreshold = 0.6
    private let analysisWindowHours = 24

    // MARK: - Initialization

    private init() {
        causalLogger.info("🔬 CausalPatternAnalyzer initializing...")
        startPeriodicAnalysis()
    }

    // MARK: - Public API

    /// Record an event to the timeline
    public func recordEvent(
        type: String,
        value: String,
        category: CausalTimelineEntry.EventCategory,
        metadata: [String: String] = [:]
    ) {
        let entry = CausalTimelineEntry(
            eventType: type,
            eventValue: value,
            category: category,
            metadata: metadata
        )
        eventTimeline.append(entry)

        // Trim old entries
        if eventTimeline.count > maxTimelineEntries {
            eventTimeline.removeFirst(eventTimeline.count - maxTimelineEntries)
        }
    }

    /// Analyze why a specific effect occurred
    public func analyzeEffect(_ effect: ObservedEffect) async -> [CausalInsight] {
        isAnalyzing = true
        defer { isAnalyzing = false }

        var insights: [CausalInsight] = []

        // Find potential causes from timeline
        let potentialCauses = findPotentialCauses(for: effect)

        for cause in potentialCauses {
            // Calculate relationship strength
            let (strength, evidence) = calculateRelationshipStrength(cause: cause, effect: effect)

            if strength >= confidenceThreshold {
                let relationship = CausalRelationship(
                    cause: cause,
                    effect: effect,
                    strength: strength,
                    confidence: min(1.0, Double(evidence.count) / 5.0),
                    evidence: evidence
                )

                // Generate insight
                if let insight = generateInsight(for: relationship) {
                    insights.append(insight)
                }

                // Store relationship
                storeRelationship(relationship)
            }
        }

        // Sort by priority
        insights.sort { priorityValue($0.priority) > priorityValue($1.priority) }

        recentInsights = insights
        return insights
    }

    /// Get explanation for a detected pattern
    public func explainPattern(_ pattern: IntelligencePattern) async -> String {
        // Find related causal relationships
        let relatedRelationships = discoveredRelationships.filter { relationship in
            relationship.effect.description.lowercased().contains(pattern.description.lowercased()) ||
            relationship.cause.description.lowercased().contains(pattern.description.lowercased())
        }

        if relatedRelationships.isEmpty {
            return "This pattern has been observed \(pattern.occurrences) times. " +
                   "Not enough data yet to determine the underlying cause."
        }

        var explanation = "Based on analysis:\n"

        for relationship in relatedRelationships.prefix(3) {
            explanation += "• When \(relationship.cause.description), "
            explanation += "there's a \(Int(relationship.strength * 100))% correlation with "
            explanation += "\(relationship.effect.description).\n"
        }

        return explanation
    }

    /// Get prevention advice for a potential issue
    public func getPreventionAdvice(for effectType: ObservedEffect.EffectType) -> [String] {
        // Find relationships where this effect type occurs
        let relevantRelationships = discoveredRelationships.filter { $0.effect.type == effectType }

        var advice: Set<String> = []

        for relationship in relevantRelationships {
            switch relationship.cause.type {
            case .timeOfDay:
                advice.insert("Consider scheduling complex tasks during your peak hours")

            case .workDuration:
                advice.insert("Take regular breaks to maintain focus")

            case .errorFrequency:
                advice.insert("Slow down and review after encountering errors")

            case .taskComplexity:
                advice.insert("Break complex tasks into smaller, manageable steps")

            case .contextSwitch:
                advice.insert("Minimize app switching during focused work")

            case .fatigue:
                advice.insert("Consider taking a break when feeling tired")

            case .learningCurve:
                advice.insert("Allow extra time when working with new technologies")

            default:
                break
            }
        }

        return Array(advice)
    }

    /// Get all insights for current session
    public func getCurrentInsights() -> [CausalInsight] {
        recentInsights.filter { insight in
            insight.priority == .high || insight.priority == .critical
        }
    }

    // MARK: - Private Analysis Methods

    private func findPotentialCauses(for effect: ObservedEffect) -> [CausalFactor] {
        var causes: [CausalFactor] = []
        let now = Date()
        let windowStart = now.addingTimeInterval(-Double(analysisWindowHours) * 3600)

        // Get recent events
        let recentEvents = eventTimeline.filter { $0.timestamp > windowStart }

        // Analyze time patterns
        let hour = Calendar.current.component(.hour, from: now)
        if hour < 9 || hour > 20 {
            causes.append(CausalFactor(
                type: .timeOfDay,
                description: "Working outside typical hours",
                observedValue: "\(hour):00",
                normalValue: "9:00-20:00"
            ))
        }

        // Analyze error frequency
        let errorEvents = recentEvents.filter { $0.eventType.contains("error") }
        if errorEvents.count >= 3 {
            causes.append(CausalFactor(
                type: .errorFrequency,
                description: "Multiple recent errors",
                observedValue: "\(errorEvents.count) errors",
                normalValue: "< 3 errors"
            ))
        }

        // Analyze context switches
        let switchEvents = recentEvents.filter { $0.eventType.contains("switch") || $0.eventType.contains("change") }
        if switchEvents.count >= 5 {
            causes.append(CausalFactor(
                type: .contextSwitch,
                description: "Frequent context switching",
                observedValue: "\(switchEvents.count) switches",
                normalValue: "< 5 switches"
            ))
        }

        // Analyze work duration
        if let firstEvent = recentEvents.first {
            let sessionDuration = now.timeIntervalSince(firstEvent.timestamp) / 3600
            if sessionDuration > 4 {
                causes.append(CausalFactor(
                    type: .workDuration,
                    description: "Long work session",
                    observedValue: "\(Int(sessionDuration)) hours",
                    normalValue: "< 4 hours"
                ))
            }
        }

        // Check for complexity indicators
        let complexityEvents = recentEvents.filter {
            $0.eventValue.lowercased().contains("complex") ||
            $0.eventValue.lowercased().contains("difficult") ||
            $0.eventValue.lowercased().contains("advanced")
        }
        if !complexityEvents.isEmpty {
            causes.append(CausalFactor(
                type: .taskComplexity,
                description: "Working on complex task",
                observedValue: "Complex",
                normalValue: "Standard"
            ))
        }

        return causes
    }

    private func calculateRelationshipStrength(
        cause: CausalFactor,
        effect: ObservedEffect
    ) -> (Double, [Evidence]) {
        var evidence: [Evidence] = []
        var totalWeight: Double = 0

        // Check co-occurrence in timeline
        let coOccurrences = countCoOccurrences(cause: cause, effect: effect)
        if coOccurrences >= minEvidenceForRelationship {
            evidence.append(Evidence(
                type: .coOccurrence,
                description: "Observed together \(coOccurrences) times",
                weight: min(1.0, Double(coOccurrences) / 10.0)
            ))
            totalWeight += evidence.last!.weight
        }

        // Check temporal sequence (cause before effect)
        if checkTemporalSequence(cause: cause, effect: effect) {
            evidence.append(Evidence(
                type: .temporalSequence,
                description: "Cause consistently precedes effect",
                weight: 0.7
            ))
            totalWeight += 0.7
        }

        // Check for existing relationship
        if let existing = discoveredRelationships.first(where: {
            $0.cause.type == cause.type && $0.effect.type == effect.type
        }) {
            evidence.append(Evidence(
                type: .statisticalCorrelation,
                description: "Previously observed relationship",
                weight: existing.confidence
            ))
            totalWeight += existing.confidence
        }

        let strength = min(1.0, totalWeight / Double(evidence.count + 1))
        return (strength, evidence)
    }

    private func countCoOccurrences(cause: CausalFactor, effect: ObservedEffect) -> Int {
        // Simplified: count events matching cause/effect in close proximity
        var count = 0
        let causeType = cause.type.rawValue
        let effectType = effect.type.rawValue

        for (index, entry) in eventTimeline.enumerated() {
            if entry.eventType.contains(causeType) {
                // Look for effect within next 10 entries
                let searchEnd = min(index + 10, eventTimeline.count)
                for nextIndex in (index + 1)..<searchEnd {
                    if eventTimeline[nextIndex].eventType.contains(effectType) {
                        count += 1
                        break
                    }
                }
            }
        }

        return count
    }

    private func checkTemporalSequence(cause: CausalFactor, effect: ObservedEffect) -> Bool {
        let causeType = cause.type.rawValue
        let effectType = effect.type.rawValue

        var causeTimes: [Date] = []
        var effectTimes: [Date] = []

        for entry in eventTimeline {
            if entry.eventType.contains(causeType) {
                causeTimes.append(entry.timestamp)
            }
            if entry.eventType.contains(effectType) {
                effectTimes.append(entry.timestamp)
            }
        }

        // Check if causes generally precede effects
        var precedenceCount = 0
        for effectTime in effectTimes {
            if causeTimes.contains(where: { $0 < effectTime && effectTime.timeIntervalSince($0) < 3600 }) {
                precedenceCount += 1
            }
        }

        return precedenceCount > effectTimes.count / 2
    }

    private func generateInsight(for relationship: CausalRelationship) -> CausalInsight? {
        let explanation = generateExplanation(for: relationship)
        let advice = generateAdvice(for: relationship)
        let prevention = generatePreventionStrategy(for: relationship)
        let impact = estimateImpact(for: relationship)
        let priority = determinePriority(for: relationship)

        return CausalInsight(
            relationship: relationship,
            explanation: explanation,
            actionableAdvice: advice,
            preventionStrategy: prevention,
            expectedImpact: impact,
            priority: priority
        )
    }

    private func generateExplanation(for relationship: CausalRelationship) -> String {
        let cause = relationship.cause
        let effect = relationship.effect

        var explanation = "Analysis indicates that \(cause.description) "
        explanation += "is \(Int(relationship.strength * 100))% correlated with \(effect.description). "

        switch cause.type {
        case .timeOfDay:
            explanation += "This may be due to natural energy fluctuations throughout the day."

        case .workDuration:
            explanation += "Extended work periods can lead to mental fatigue and decreased focus."

        case .errorFrequency:
            explanation += "A cascade of errors can increase cognitive load and frustration."

        case .contextSwitch:
            explanation += "Frequent switching interrupts deep work and requires mental context rebuilding."

        case .taskComplexity:
            explanation += "Complex tasks require sustained attention and may exceed working memory capacity."

        case .fatigue:
            explanation += "Fatigue reduces cognitive resources available for problem-solving."

        default:
            explanation += "This pattern has been consistently observed in your work sessions."
        }

        return explanation
    }

    private func generateAdvice(for relationship: CausalRelationship) -> [String] {
        var advice: [String] = []

        switch relationship.cause.type {
        case .timeOfDay:
            advice.append("Schedule complex tasks during your peak productivity hours")
            advice.append("Save routine tasks for lower-energy periods")

        case .workDuration:
            advice.append("Take a 5-10 minute break every 90 minutes")
            advice.append("Use the Pomodoro technique for sustained focus")

        case .errorFrequency:
            advice.append("Slow down and carefully review after encountering errors")
            advice.append("Consider stepping back to reassess the approach")

        case .contextSwitch:
            advice.append("Batch similar tasks together to minimize switching")
            advice.append("Use focus modes to reduce interruptions")

        case .taskComplexity:
            advice.append("Break the task into smaller, manageable steps")
            advice.append("Write out a plan before diving into implementation")

        case .fatigue:
            advice.append("Take a short break to refresh")
            advice.append("Consider switching to a less demanding task")

        default:
            advice.append("Be mindful of this pattern and adjust as needed")
        }

        return advice
    }

    private func generatePreventionStrategy(for relationship: CausalRelationship) -> String? {
        switch relationship.effect.type {
        case .frustration:
            return "Proactively take breaks and check in on progress before frustration builds"

        case .errorIncrease:
            return "Slow down and add verification steps when working in challenging conditions"

        case .productivityDrop:
            return "Recognize early signs and take preventive action (break, task switch, etc.)"

        case .stuckBehavior:
            return "Set a timer - if stuck for 15 minutes, try a different approach"

        case .abandonedTask:
            return "Break tasks into achievable milestones to maintain momentum"

        default:
            return nil
        }
    }

    private func estimateImpact(for relationship: CausalRelationship) -> String {
        let strengthDescription = relationship.strength > 0.8 ? "significant" :
                                  relationship.strength > 0.6 ? "moderate" : "minor"

        let frequencyNote = relationship.effect.frequency > 5 ?
            "This occurs frequently." : "This is an occasional pattern."

        return "Addressing this could have a \(strengthDescription) positive impact. \(frequencyNote)"
    }

    private func determinePriority(for relationship: CausalRelationship) -> CausalInsight.Priority {
        if relationship.effect.severity == .critical {
            return .critical
        } else if relationship.effect.severity == .high && relationship.strength > 0.7 {
            return .high
        } else if relationship.strength > 0.5 {
            return .medium
        }
        return .low
    }

    private func storeRelationship(_ relationship: CausalRelationship) {
        // Update or add relationship
        if let existingIndex = discoveredRelationships.firstIndex(where: {
            $0.cause.type == relationship.cause.type && $0.effect.type == relationship.effect.type
        }) {
            let existing = discoveredRelationships[existingIndex]
            discoveredRelationships[existingIndex] = CausalRelationship(
                id: existing.id,
                cause: relationship.cause,
                effect: relationship.effect,
                strength: (existing.strength + relationship.strength) / 2,
                confidence: min(1.0, existing.confidence + 0.1),
                evidence: existing.evidence + relationship.evidence,
                discoveredAt: existing.discoveredAt,
                lastObserved: Date()
            )
        } else {
            discoveredRelationships.append(relationship)
        }

        causalLogger.debug("📊 Stored causal relationship: \(relationship.cause.type.rawValue) → \(relationship.effect.type.rawValue)")
    }

    private func priorityValue(_ priority: CausalInsight.Priority) -> Int {
        switch priority {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .critical: return 4
        }
    }

    private func startPeriodicAnalysis() {
        Task.detached { [weak self] in
            while true {
                do {
                    try await Task.sleep(for: .seconds(600))
                } catch {
                    break
                } // Every 10 minutes
                await self?.performPeriodicAnalysis()
            }
        }
    }

    private func performPeriodicAnalysis() {
        // Decay old relationships
        let cutoff = Date().addingTimeInterval(-7 * 86400) // 7 days
        discoveredRelationships = discoveredRelationships.filter { $0.lastObserved > cutoff }

        // Clean old timeline entries
        let timelineCutoff = Date().addingTimeInterval(-Double(analysisWindowHours) * 3600)
        eventTimeline = eventTimeline.filter { $0.timestamp > timelineCutoff }
    }
}
