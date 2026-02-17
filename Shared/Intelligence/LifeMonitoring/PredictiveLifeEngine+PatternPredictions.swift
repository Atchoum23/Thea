// PredictiveLifeEngine+PatternPredictions.swift
// Thea V2 - Pattern-Based & Immediate Predictions
//
// Handles pattern-to-prediction mapping and real-time
// immediate predictions (context switch, fatigue, scheduling, communication).
// Split from PredictiveLifeEngine.swift for single-responsibility clarity.

import Foundation

// MARK: - Pattern-Based Predictions

extension PredictiveLifeEngine {

    /// Called when ``HolisticPatternIntelligence`` detects new patterns.
    ///
    /// Iterates through patterns that have a ``predictedNext`` timestamp
    /// and converts them into ``LifePrediction`` instances.
    ///
    /// - Parameter patterns: The newly detected life patterns.
    func onPatternsUpdated(_ patterns: [DetectedLifePattern]) {
        for pattern in patterns where pattern.predictedNext != nil {
            createPatternBasedPrediction(pattern)
        }
    }

    /// Converts a detected life pattern into a ``LifePrediction``.
    ///
    /// Only creates a prediction if the pattern's ``predictedNext``
    /// timestamp is in the future and within the configured horizon.
    ///
    /// - Parameter pattern: The detected pattern with a non-nil ``predictedNext``.
    private func createPatternBasedPrediction(_ pattern: DetectedLifePattern) {
        guard let predictedTime = pattern.predictedNext else { return }

        let horizon = predictedTime.timeIntervalSince(Date())
        guard horizon > 0 && horizon < configuration.maxPredictionHorizon else { return }

        let prediction = LifePrediction(
            type: mapPatternToPredictionType(pattern.category),
            title: "Upcoming: \(pattern.name)",
            description: "Based on your patterns, \(pattern.description.lowercased()) is expected \(formatTimeUntil(predictedTime))",
            confidence: pattern.confidence * 0.8, // Slightly reduce confidence for predictions
            timeframe: PredictionTimeframe(horizon: horizon, specificTime: predictedTime),
            relevance: calculateRelevance(for: horizon),
            suggestedActions: pattern.suggestions.map { suggestion in
                PredictedAction(
                    title: suggestion.title,
                    description: suggestion.description,
                    type: mapSuggestionToActionType(suggestion.type),
                    automatable: suggestion.automatable,
                    impact: suggestion.expectedImpact,
                    effort: suggestion.effort.rawValue
                )
            },
            basedOn: ["Pattern: \(pattern.name)", "\(pattern.dataPoints) observations"],
            expiresAt: predictedTime.addingTimeInterval(3600) // Expire 1 hour after predicted time
        )

        addOrUpdatePrediction(prediction)
    }

    /// Maps a life-pattern category to the most appropriate prediction type.
    ///
    /// - Parameter category: The pattern's ``LifePatternCategory``.
    /// - Returns: The corresponding ``LifePredictionType``.
    func mapPatternToPredictionType(_ category: LifePatternCategory) -> LifePredictionType {
        switch category {
        case .focusPeriods, .taskSwitching:
            return .optimalTime
        case .breakPatterns:
            return .focusBreak
        case .communicationPeaks:
            return .communicationOpportunity
        case .sleepQuality:
            return .sleepImpact
        case .stressIndicators:
            return .stressBuildup
        case .meetingPatterns:
            return .schedulingConflict
        case .activityLevels:
            return .activityDeficit
        default:
            return .nextActivity
        }
    }

    /// Maps a pattern suggestion type to a predicted action type.
    ///
    /// - Parameter type: The suggestion's ``PatternSuggestion.SuggestionType``.
    /// - Returns: The corresponding ``PredictedAction.ActionType``.
    func mapSuggestionToActionType(_ type: PatternSuggestion.SuggestionType) -> PredictedAction.ActionType {
        switch type {
        case .schedule:
            return .schedule
        case .automate:
            return .automate
        case .break_pattern:
            return .avoid
        case .health:
            return .adjust
        default:
            return .doNow
        }
    }
}

// MARK: - Immediate Predictions

extension PredictiveLifeEngine {

    /// Predicts the cost of frequent context switching.
    ///
    /// Fires when the recent context window contains more than 10 app-switch
    /// events in the last 20 snapshots, suggesting high task fragmentation.
    func predictContextSwitchImpact() {
        let recentSwitches = contextWindow.suffix(20).filter { $0.eventType == "app_switch" }

        if recentSwitches.count > 10 {
            let prediction = LifePrediction(
                type: .contextSwitch,
                title: "High Context Switching",
                description: "You've switched apps \(recentSwitches.count) times recently. This may be affecting your focus.",
                confidence: 0.8,
                timeframe: .immediate,
                relevance: 0.9,
                actionability: .recommended,
                suggestedActions: [
                    PredictedAction(
                        title: "Focus Mode",
                        description: "Consider enabling focus mode to reduce distractions",
                        type: .doNow,
                        automatable: true,
                        impact: 0.3,
                        effort: "minimal"
                    )
                ],
                basedOn: ["Recent activity: \(recentSwitches.count) app switches"]
            )

            addOrUpdatePrediction(prediction)
        }
    }

    /// Predicts fatigue onset from sustained input activity.
    ///
    /// Triggers when the user has been continuously typing for over 60 minutes
    /// without a detected break, based on the context window.
    func predictFatigueOnset() {
        let recentActivity = contextWindow.suffix(30)
        let typingEvents = recentActivity.filter { $0.eventType == "input_activity" }

        // Simple heuristic: continuous activity without breaks
        if typingEvents.count > 20, let first = typingEvents.first, let last = typingEvents.last {
            let duration = last.timestamp.timeIntervalSince(first.timestamp)

            if duration > 3600 { // Over 1 hour of continuous activity
                let prediction = LifePrediction(
                    type: .fatigueOnset,
                    title: "Break Recommended",
                    description: "You've been working continuously for \(Int(duration / 60)) minutes. A short break can improve focus.",
                    confidence: 0.75,
                    timeframe: PredictionTimeframe(horizon: 300, window: 900), // Next 5-15 min
                    relevance: 0.95,
                    actionability: .recommended,
                    suggestedActions: [
                        PredictedAction(
                            title: "Take a 5-minute break",
                            description: "Step away, stretch, or look at something far away",
                            type: .doNow,
                            automatable: false,
                            impact: 0.4,
                            effort: "minimal"
                        ),
                        PredictedAction(
                            title: "Schedule break reminder",
                            description: "Set a reminder for regular breaks",
                            type: .automate,
                            automatable: true,
                            impact: 0.3,
                            effort: "minimal"
                        )
                    ],
                    basedOn: ["Continuous activity: \(Int(duration / 60)) minutes"]
                )

                addOrUpdatePrediction(prediction)
            }
        }
    }

    /// Predicts scheduling conflicts in the next 24 hours.
    ///
    /// Queries ``CalendarMonitor`` for upcoming events and checks for
    /// overlapping time ranges, generating a prediction for each conflict found.
    func predictSchedulingConflicts() {
        Task {
            let events = await CalendarMonitor.shared.getUpcomingEvents(hours: 24)
            let sorted = events.sorted { $0.startDate < $1.startDate }

            // Check for overlapping events
            for i in 0 ..< sorted.count {
                for j in (i + 1) ..< sorted.count {
                    let a = sorted[i]
                    let b = sorted[j]
                    // Overlap: event B starts before event A ends
                    if b.startDate < a.endDate {
                        let prediction = LifePrediction(
                            type: .schedulingConflict,
                            title: "Scheduling Conflict",
                            description: "\"\(a.title)\" overlaps with \"\(b.title)\"",
                            confidence: 0.95,
                            timeframe: .shortTerm,
                            relevance: 0.9,
                            actionability: .recommended,
                            basedOn: [
                                "\(a.title): \(a.startDate.formatted()) – \(a.endDate.formatted())",
                                "\(b.title): \(b.startDate.formatted()) – \(b.endDate.formatted())"
                            ]
                        )
                        await MainActor.run {
                            addOrUpdatePrediction(prediction)
                        }
                    }
                }
            }
        }
    }

    /// Predicts whether an incoming message needs urgent attention.
    ///
    /// Generates a communication-opportunity prediction when the event
    /// has a significance level of `.significant` or higher.
    ///
    /// - Parameter event: The incoming message/email life event.
    func predictCommunicationNeed(for event: LifeEvent) {
        if event.significance >= .significant {
            let prediction = LifePrediction(
                type: .communicationOpportunity,
                title: "Important Message",
                description: event.summary,
                confidence: 0.7,
                timeframe: .shortTerm,
                relevance: 0.8,
                actionability: .recommended,
                basedOn: ["Message significance: \(event.significance.rawValue)"]
            )

            addOrUpdatePrediction(prediction)
        }
    }
}
