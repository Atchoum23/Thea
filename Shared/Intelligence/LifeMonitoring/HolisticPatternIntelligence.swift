// HolisticPatternIntelligence.swift
// Thea V2 - AI-Powered Holistic Life Pattern Recognition
//
// This is the central intelligence for analyzing patterns across ALL aspects
// of the user's life - devices, routines, habits, activities, relationships,
// health, productivity, and more. Uses AI to identify patterns, predict
// behaviors, and provide proactive suggestions for life optimization.

import Combine
import Foundation
import os.log

// MARK: - Holistic Pattern Intelligence

/// Central AI engine for holistic life pattern recognition
@MainActor
public final class HolisticPatternIntelligence: ObservableObject {
    public static let shared = HolisticPatternIntelligence()

    private let logger = Logger(subsystem: "ai.thea.app", category: "HolisticPatternIntelligence")

    // MARK: - Published State

    @Published public private(set) var detectedPatterns: [DetectedLifePattern] = []
    @Published public private(set) var isAnalyzing = false
    @Published public private(set) var lastAnalysis: Date?
    @Published public private(set) var overallLifeScore: Double = 0.5 // 0-1
    @Published public private(set) var insights: [PatternInsight] = []

    // MARK: - Configuration

    public var configuration = HolisticPatternConfiguration()

    // MARK: - Data Stores

    private var eventHistory: [LifeEvent] = []
    private var patternObservations: [UUID: [Date]] = [:]  // Pattern ID -> observation times
    private var analysisCache: [LifePatternCategory: Date] = [:]

    // MARK: - Analysis Tasks

    private var analysisTask: Task<Void, Never>?
    private var periodicAnalysisTask: Task<Void, Never>?

    // MARK: - Subscriptions

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        logger.info("HolisticPatternIntelligence initialized")
        setupEventSubscription()
        loadPersistedPatterns()
    }

    // MARK: - Setup

    private func setupEventSubscription() {
        // Subscribe to life events from the coordinator
        LifeMonitoringCoordinator.shared.eventStream
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                Task { @MainActor in
                    self?.processEvent(event)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Lifecycle

    public func start() {
        logger.info("Starting holistic pattern analysis")

        // Start periodic deep analysis
        periodicAnalysisTask = Task {
            while !Task.isCancelled {
                // Run deep analysis every configured interval
                try? await Task.sleep(for: .seconds(configuration.deepAnalysisInterval))
                guard !Task.isCancelled else { break }
                await runDeepAnalysis()
            }
        }
    }

    public func stop() {
        logger.info("Stopping holistic pattern analysis")
        periodicAnalysisTask?.cancel()
        analysisTask?.cancel()
        persistPatterns()
    }

    // MARK: - Event Processing

    private func processEvent(_ event: LifeEvent) {
        // Add to history
        eventHistory.append(event)

        // Trim history if too large
        if eventHistory.count > configuration.maxEventHistory {
            eventHistory.removeFirst(eventHistory.count - configuration.maxEventHistory)
        }

        // Check for quick pattern matches
        checkQuickPatterns(for: event)

        // Schedule incremental analysis if needed
        scheduleIncrementalAnalysis(for: event.type)
    }

    private func checkQuickPatterns(for event: LifeEvent) {
        // Check if this event matches any known pattern
        for pattern in detectedPatterns {
            if matchesPattern(event, pattern: pattern) {
                // Record observation
                patternObservations[pattern.id, default: []].append(event.timestamp)

                // Update pattern statistics
                updatePatternStatistics(pattern.id)
            }
        }
    }

    private func matchesPattern(_ event: LifeEvent, pattern: DetectedLifePattern) -> Bool {
        // Check if event category matches pattern category
        let eventCategory = mapEventTypeToCategory(event.type)
        guard eventCategory == pattern.category else { return false }

        // Check time context if available
        if let timeContext = pattern.timeContext.timeOfDay {
            let hour = Calendar.current.component(.hour, from: event.timestamp)
            guard timeContext.contains(hour) else { return false }
        }

        if let dayContext = pattern.timeContext.daysOfWeek {
            let day = Calendar.current.component(.weekday, from: event.timestamp)
            guard dayContext.contains(day) else { return false }
        }

        return true
    }

    private func mapEventTypeToCategory(_ type: LifeEventType) -> LifePatternCategory {
        switch type {
        case .appSwitch:
            return .appUsageSequences
        case .inputActivity:
            return .inputPatterns
        case .documentActivity:
            return .focusPeriods
        case .messageReceived, .messageSent, .emailReceived, .emailSent:
            return .communicationPeaks
        case .healthMetric:
            return .activityLevels
        case .locationArrival, .locationDeparture:
            return .locationRoutines
        case .musicPlaying, .musicPaused, .videoPlaying, .videoPaused:
            return .mediaConsumption
        case .socialLike, .socialComment, .socialFollow:
            return .socialEngagement
        case .calendarEventCreated, .eventStart:
            return .meetingPatterns
        case .reminderDue, .reminderCompleted:
            return .taskSwitching
        case .homeKitPowerChange, .homeKitBrightnessChange, .homeKitThermostatChange:
            return .homeAutomation
        default:
            return .deviceSwitching
        }
    }

    private func updatePatternStatistics(_ patternId: UUID) {
        guard let index = detectedPatterns.firstIndex(where: { $0.id == patternId }) else { return }

        let observations = patternObservations[patternId] ?? []
        let pattern = detectedPatterns[index]

        // Update frequency based on observations
        let newFrequency = calculateFrequency(from: observations)
        let newTrend = calculateTrend(from: observations)
        let nextPrediction = predictNextOccurrence(from: observations, pattern: pattern)

        // Create updated pattern
        detectedPatterns[index] = DetectedLifePattern(
            id: pattern.id,
            category: pattern.category,
            name: pattern.name,
            description: pattern.description,
            confidence: min(1.0, pattern.confidence + 0.01), // Slightly increase confidence with each observation
            frequency: newFrequency,
            timeContext: pattern.timeContext,
            triggers: pattern.triggers,
            correlations: pattern.correlations,
            impact: pattern.impact,
            suggestions: pattern.suggestions,
            dataPoints: observations.count,
            firstObserved: pattern.firstObserved,
            lastObserved: Date(),
            trend: newTrend,
            predictedNext: nextPrediction
        )
    }

    private func calculateFrequency(from observations: [Date]) -> PatternFrequency {
        guard observations.count >= 2 else { return .rare }

        let sorted = observations.sorted()
        var intervals: [TimeInterval] = []

        for i in 1..<sorted.count {
            intervals.append(sorted[i].timeIntervalSince(sorted[i-1]))
        }

        let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
        let hoursPerInterval = avgInterval / 3600

        switch hoursPerInterval {
        case 0..<4: return .multipleDays
        case 4..<24: return .daily
        case 24..<72: return .frequent
        case 72..<168: return .weekly
        case 168..<720: return .occasional
        default: return .rare
        }
    }

    private func calculateTrend(from observations: [Date]) -> PatternTrend {
        guard observations.count >= 5 else { return .emerging }

        // Compare frequency in first half vs second half
        let sorted = observations.sorted()
        let midpoint = sorted.count / 2

        let firstHalf = Array(sorted[..<midpoint])
        let secondHalf = Array(sorted[midpoint...])

        guard let firstStart = firstHalf.first, let firstEnd = firstHalf.last,
              let secondStart = secondHalf.first, let secondEnd = secondHalf.last else {
            return .stable
        }

        let firstDuration = firstEnd.timeIntervalSince(firstStart)
        let secondDuration = secondEnd.timeIntervalSince(secondStart)

        let firstRate = Double(firstHalf.count) / max(1, firstDuration)
        let secondRate = Double(secondHalf.count) / max(1, secondDuration)

        let change = (secondRate - firstRate) / max(0.001, firstRate)

        if change > 0.2 {
            return .increasing
        } else if change < -0.2 {
            return secondRate < 0.001 ? .declining : .decreasing
        } else {
            return .stable
        }
    }

    private func predictNextOccurrence(from observations: [Date], pattern _pattern: DetectedLifePattern) -> Date? {
        guard observations.count >= 3 else { return nil }

        let sorted = observations.sorted()
        var intervals: [TimeInterval] = []

        for i in 1..<sorted.count {
            intervals.append(sorted[i].timeIntervalSince(sorted[i-1]))
        }

        let avgInterval = intervals.reduce(0, +) / Double(intervals.count)

        if let last = sorted.last {
            return last.addingTimeInterval(avgInterval)
        }
        return nil
    }

    // MARK: - Incremental Analysis

    private func scheduleIncrementalAnalysis(for eventType: LifeEventType) {
        let category = mapEventTypeToCategory(eventType)

        // Check if we've analyzed this category recently
        if let lastAnalysisTime = analysisCache[category],
           Date().timeIntervalSince(lastAnalysisTime) < configuration.incrementalAnalysisThrottle {
            return
        }

        analysisCache[category] = Date()

        // Run lightweight analysis for this category
        analysisTask?.cancel()
        analysisTask = Task {
            await analyzeCategory(category)
        }
    }

    private func analyzeCategory(_ category: LifePatternCategory) async {
        // Filter events relevant to this category
        let relevantEvents = eventHistory.filter { mapEventTypeToCategory($0.type) == category }

        guard relevantEvents.count >= configuration.minimumDataPoints else { return }

        // Look for new patterns
        let newPatterns = await detectPatternsInCategory(category, events: relevantEvents)

        // Merge with existing patterns
        for newPattern in newPatterns {
            if let existingIndex = detectedPatterns.firstIndex(where: { isSimilarPattern($0, newPattern) }) {
                // Update existing pattern
                detectedPatterns[existingIndex] = mergePatterns(detectedPatterns[existingIndex], newPattern)
            } else {
                // Add new pattern
                detectedPatterns.append(newPattern)
            }
        }

        // Generate insights
        await generateInsights()
    }

    private func detectPatternsInCategory(_ category: LifePatternCategory, events: [LifeEvent]) async -> [DetectedLifePattern] {
        var patterns: [DetectedLifePattern] = []

        // Time-based pattern detection
        let hourlyDistribution = analyzeHourlyDistribution(events)
        if let peakHours = findSignificantPeaks(in: hourlyDistribution) {
            let pattern = DetectedLifePattern(
                category: category,
                name: "\(category.rawValue.capitalized) Peak Time",
                description: "You tend to \(category.rawValue.replacingOccurrences(of: "_", with: " ")) most during \(formatHours(peakHours))",
                confidence: 0.7,
                frequency: .daily,
                timeContext: PatternTimeContext(timeOfDay: peakHours, peakTime: peakHours.first),
                impact: PatternImpact(overallScore: 0.0, description: "Identified timing pattern"),
                dataPoints: events.count,
                firstObserved: events.first?.timestamp ?? Date(),
                lastObserved: events.last?.timestamp ?? Date()
            )
            patterns.append(pattern)
        }

        // Day-of-week pattern detection
        let dailyDistribution = analyzeDailyDistribution(events)
        if let significantDays = findSignificantDays(in: dailyDistribution) {
            let pattern = DetectedLifePattern(
                category: category,
                name: "\(category.rawValue.capitalized) Day Pattern",
                description: "You tend to \(category.rawValue.replacingOccurrences(of: "_", with: " ")) more on \(formatDays(significantDays))",
                confidence: 0.6,
                frequency: .weekly,
                timeContext: PatternTimeContext(daysOfWeek: significantDays),
                impact: PatternImpact(overallScore: 0.0, description: "Identified day-of-week pattern"),
                dataPoints: events.count,
                firstObserved: events.first?.timestamp ?? Date(),
                lastObserved: events.last?.timestamp ?? Date()
            )
            patterns.append(pattern)
        }

        // Sequence pattern detection
        let sequences = analyzeEventSequences(events)
        for sequence in sequences {
            let pattern = DetectedLifePattern(
                category: category,
                name: "Sequence: \(sequence.name)",
                description: sequence.description,
                confidence: sequence.confidence,
                frequency: calculateFrequency(from: sequence.occurrences),
                timeContext: PatternTimeContext(),
                impact: PatternImpact(overallScore: 0.0, description: "Identified behavioral sequence"),
                dataPoints: sequence.occurrences.count,
                firstObserved: sequence.occurrences.first ?? Date(),
                lastObserved: sequence.occurrences.last ?? Date()
            )
            patterns.append(pattern)
        }

        return patterns
    }

    // MARK: - Statistical Analysis

    private func analyzeHourlyDistribution(_ events: [LifeEvent]) -> [Int: Int] {
        var distribution: [Int: Int] = [:]
        for event in events {
            let hour = Calendar.current.component(.hour, from: event.timestamp)
            distribution[hour, default: 0] += 1
        }
        return distribution
    }

    private func analyzeDailyDistribution(_ events: [LifeEvent]) -> [Int: Int] {
        var distribution: [Int: Int] = [:]
        for event in events {
            let day = Calendar.current.component(.weekday, from: event.timestamp)
            distribution[day, default: 0] += 1
        }
        return distribution
    }

    private func findSignificantPeaks(in distribution: [Int: Int]) -> [Int]? {
        guard !distribution.isEmpty else { return nil }

        let total = distribution.values.reduce(0, +)
        let average = Double(total) / 24.0
        let threshold = average * 1.5

        let peaks = distribution.filter { Double($0.value) > threshold }.keys.sorted()
        return peaks.isEmpty ? nil : peaks
    }

    private func findSignificantDays(in distribution: [Int: Int]) -> [Int]? {
        guard !distribution.isEmpty else { return nil }

        let total = distribution.values.reduce(0, +)
        let average = Double(total) / 7.0
        let threshold = average * 1.3

        let significantDays = distribution.filter { Double($0.value) > threshold }.keys.sorted()
        return significantDays.isEmpty ? nil : significantDays
    }

    private struct DetectedSequence {
        let name: String
        let description: String
        let confidence: Double
        let occurrences: [Date]
    }

    private func analyzeEventSequences(_ events: [LifeEvent]) -> [DetectedSequence] {
        var sequences: [DetectedSequence] = []

        // Look for events that frequently follow each other within a time window
        let windowSize: TimeInterval = 300 // 5 minutes
        var sequenceCounts: [String: [Date]] = [:]

        for i in 0..<(events.count - 1) {
            let current = events[i]
            let next = events[i + 1]

            let timeDiff = next.timestamp.timeIntervalSince(current.timestamp)
            if timeDiff < windowSize {
                let sequenceKey = "\(current.type.rawValue)->\(next.type.rawValue)"
                sequenceCounts[sequenceKey, default: []].append(current.timestamp)
            }
        }

        // Filter for significant sequences
        for (sequence, occurrences) in sequenceCounts {
            if occurrences.count >= 5 {
                let parts = sequence.split(separator: ">").map { String($0).trimmingCharacters(in: CharacterSet(charactersIn: "-")) }
                if parts.count == 2 {
                    sequences.append(DetectedSequence(
                        name: sequence,
                        description: "You often do '\(parts[1])' shortly after '\(parts[0])'",
                        confidence: min(1.0, Double(occurrences.count) / 20.0),
                        occurrences: occurrences
                    ))
                }
            }
        }

        return sequences
    }

    // MARK: - Deep Analysis

    private func runDeepAnalysis() async {
        guard !isAnalyzing else { return }

        isAnalyzing = true
        logger.info("Running deep pattern analysis")

        // Analyze all categories
        for category in LifePatternCategory.allCases {
            await analyzeCategory(category)
        }

        // Analyze cross-category correlations
        await analyzeCrossPatternCorrelations()

        // Generate AI-powered suggestions
        await generateAISuggestions()

        // Calculate overall life score
        calculateOverallLifeScore()

        // Generate insights
        await generateInsights()

        lastAnalysis = Date()
        isAnalyzing = false

        // Persist patterns
        persistPatterns()

        logger.info("Deep analysis complete. Found \(self.detectedPatterns.count) patterns")
    }

    private func analyzeCrossPatternCorrelations() async {
        // Look for patterns that tend to occur together
        for i in 0..<detectedPatterns.count {
            for j in (i+1)..<detectedPatterns.count {
                let patternA = detectedPatterns[i]
                let patternB = detectedPatterns[j]

                let observationsA = patternObservations[patternA.id] ?? []
                let observationsB = patternObservations[patternB.id] ?? []

                if let correlation = calculateCorrelation(observationsA, observationsB) {
                    // Add correlation to both patterns
                    addCorrelation(from: patternA.id, to: patternB.id, correlation: correlation)
                }
            }
        }
    }

    private func calculateCorrelation(_ datesA: [Date], _ datesB: [Date]) -> PatternCorrelation? {
        guard datesA.count >= 5 && datesB.count >= 5 else { return nil }

        // Check for temporal proximity
        let windowSize: TimeInterval = 3600 // 1 hour
        var coOccurrences = 0

        for dateA in datesA {
            for dateB in datesB {
                if abs(dateA.timeIntervalSince(dateB)) < windowSize {
                    coOccurrences += 1
                    break
                }
            }
        }

        let correlationStrength = Double(coOccurrences) / Double(datesA.count)

        guard correlationStrength > 0.3 else { return nil }

        return PatternCorrelation(
            relatedPatternId: UUID(), // Will be set by caller
            relationshipType: .correlates,
            strength: correlationStrength,
            description: "These patterns often occur together"
        )
    }

    private func addCorrelation(from patternAId: UUID, to patternBId: UUID, correlation: PatternCorrelation) {
        // Update pattern A
        if let indexA = detectedPatterns.firstIndex(where: { $0.id == patternAId }) {
            let pattern = detectedPatterns[indexA]
            var correlations = pattern.correlations
            correlations.append(PatternCorrelation(
                relatedPatternId: patternBId,
                relationshipType: correlation.relationshipType,
                strength: correlation.strength,
                description: correlation.description
            ))
            // Note: We'd need to reconstruct the pattern to update it
        }
    }

    // MARK: - AI Suggestions

    private func generateAISuggestions() async {
        for i in 0..<detectedPatterns.count {
            let pattern = detectedPatterns[i]
            let suggestions = generateSuggestionsForPattern(pattern)

            // Update pattern with suggestions
            detectedPatterns[i] = DetectedLifePattern(
                id: pattern.id,
                category: pattern.category,
                name: pattern.name,
                description: pattern.description,
                confidence: pattern.confidence,
                frequency: pattern.frequency,
                timeContext: pattern.timeContext,
                triggers: pattern.triggers,
                correlations: pattern.correlations,
                impact: pattern.impact,
                suggestions: suggestions,
                dataPoints: pattern.dataPoints,
                firstObserved: pattern.firstObserved,
                lastObserved: pattern.lastObserved,
                trend: pattern.trend,
                predictedNext: pattern.predictedNext
            )
        }
    }

    private func generateSuggestionsForPattern(_ pattern: DetectedLifePattern) -> [PatternSuggestion] {
        var suggestions: [PatternSuggestion] = []

        // Generate suggestions based on pattern category and impact
        switch pattern.category {
        case .focusPeriods:
            if let peakTime = pattern.timeContext.peakTime {
                suggestions.append(PatternSuggestion(
                    type: .schedule,
                    title: "Schedule Deep Work",
                    description: "Block \(formatHour(peakTime)) to \(formatHour((peakTime + 2) % 24)) for your most important tasks - this is your peak focus time.",
                    automatable: true,
                    expectedImpact: 0.3,
                    effort: .low,
                    priority: 4
                ))
            }

        case .procrastination:
            suggestions.append(PatternSuggestion(
                type: .break_pattern,
                title: "Break Procrastination Cycle",
                description: "When you notice this pattern starting, try the 2-minute rule: commit to just 2 minutes of the task.",
                expectedImpact: 0.4,
                effort: .medium,
                priority: 4
            ))

        case .sleepQuality:
            suggestions.append(PatternSuggestion(
                type: .habit,
                title: "Consistent Sleep Schedule",
                description: "Going to bed at the same time each night can improve sleep quality by up to 30%.",
                expectedImpact: 0.3,
                effort: .medium,
                priority: 5
            ))

        case .communicationPeaks:
            suggestions.append(PatternSuggestion(
                type: .optimize,
                title: "Batch Communication",
                description: "Consider batching messages during your peak communication hours rather than responding throughout the day.",
                automatable: true,
                expectedImpact: 0.2,
                effort: .low,
                priority: 3
            ))

        case .breakPatterns:
            if pattern.frequency == .rare {
                suggestions.append(PatternSuggestion(
                    type: .health,
                    title: "More Frequent Breaks",
                    description: "You take breaks less frequently than recommended. Consider the 52-17 method: 52 minutes of work, 17 minutes of break.",
                    automatable: true,
                    expectedImpact: 0.25,
                    effort: .low,
                    priority: 4
                ))
            }

        case .screenTimeDistribution:
            suggestions.append(PatternSuggestion(
                type: .health,
                title: "20-20-20 Rule",
                description: "Every 20 minutes, look at something 20 feet away for 20 seconds to reduce eye strain.",
                automatable: true,
                expectedImpact: 0.15,
                effort: .minimal,
                priority: 3
            ))

        default:
            break
        }

        // Add trend-based suggestions
        if pattern.trend == .increasing && pattern.impact.overallScore < 0 {
            suggestions.append(PatternSuggestion(
                type: .break_pattern,
                title: "Address Growing Concern",
                description: "This pattern is increasing and may be affecting your \(pattern.impact.description.lowercased()). Consider setting boundaries.",
                expectedImpact: 0.3,
                effort: .medium,
                priority: 4
            ))
        }

        return suggestions
    }

    // MARK: - Life Score

    private func calculateOverallLifeScore() {
        guard !detectedPatterns.isEmpty else {
            overallLifeScore = 0.5
            return
        }

        var totalScore = 0.0
        var totalWeight = 0.0

        for pattern in detectedPatterns {
            let weight = pattern.confidence * Double(pattern.dataPoints) / 100.0
            totalScore += (pattern.impact.overallScore + 1) / 2 * weight // Normalize to 0-1
            totalWeight += weight
        }

        overallLifeScore = totalWeight > 0 ? totalScore / totalWeight : 0.5
    }

    // MARK: - Insights

    private func generateInsights() async {
        var newInsights: [PatternInsight] = []

        // Most impactful positive patterns
        let positivePatterns = detectedPatterns
            .filter { $0.impact.overallScore > 0.3 }
            .sorted { $0.impact.overallScore > $1.impact.overallScore }
            .prefix(3)

        for pattern in positivePatterns {
            newInsights.append(PatternInsight(
                type: .positive,
                title: "Strong Pattern: \(pattern.name)",
                description: pattern.description,
                relatedPatternId: pattern.id
            ))
        }

        // Patterns that need attention
        let negativePatterns = detectedPatterns
            .filter { $0.impact.overallScore < -0.2 && $0.trend != .decreasing }
            .sorted { $0.impact.overallScore < $1.impact.overallScore }
            .prefix(3)

        for pattern in negativePatterns {
            newInsights.append(PatternInsight(
                type: .warning,
                title: "Pattern to Address: \(pattern.name)",
                description: "\(pattern.description). \(pattern.suggestions.first?.description ?? "")",
                relatedPatternId: pattern.id
            ))
        }

        // Emerging patterns
        let emergingPatterns = detectedPatterns
            .filter { $0.trend == .emerging && $0.confidence > 0.5 }
            .prefix(2)

        for pattern in emergingPatterns {
            newInsights.append(PatternInsight(
                type: .info,
                title: "New Pattern Detected: \(pattern.name)",
                description: "Thea has noticed a new pattern: \(pattern.description)",
                relatedPatternId: pattern.id
            ))
        }

        self.insights = newInsights
    }

    // MARK: - Helpers

    private func isSimilarPattern(_ a: DetectedLifePattern, _ b: DetectedLifePattern) -> Bool {
        // Check if two patterns are essentially the same
        a.category == b.category &&
               a.name == b.name &&
               a.timeContext.timeOfDay == b.timeContext.timeOfDay &&
               a.timeContext.daysOfWeek == b.timeContext.daysOfWeek
    }

    private func mergePatterns(_ existing: DetectedLifePattern, _ new: DetectedLifePattern) -> DetectedLifePattern {
        // Merge two similar patterns
        DetectedLifePattern(
            id: existing.id,
            category: existing.category,
            name: existing.name,
            description: new.description.count > existing.description.count ? new.description : existing.description,
            confidence: (existing.confidence + new.confidence) / 2,
            frequency: new.frequency,
            timeContext: new.timeContext,
            triggers: existing.triggers + new.triggers.filter { newTrigger in
                !existing.triggers.contains { $0.description == newTrigger.description }
            },
            correlations: existing.correlations,
            impact: new.impact,
            suggestions: existing.suggestions,
            dataPoints: existing.dataPoints + new.dataPoints,
            firstObserved: existing.firstObserved,
            lastObserved: new.lastObserved,
            trend: new.trend,
            predictedNext: new.predictedNext
        )
    }

    private func formatHours(_ hours: [Int]) -> String {
        let formatted = hours.map { formatHour($0) }
        return formatted.joined(separator: ", ")
    }

    private func formatHour(_ hour: Int) -> String {
        if hour == 0 { return "12 AM" }
        if hour < 12 { return "\(hour) AM" }
        if hour == 12 { return "12 PM" }
        return "\(hour - 12) PM"
    }

    private func formatDays(_ days: [Int]) -> String {
        let dayNames = ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        return days.map { dayNames[$0] }.joined(separator: ", ")
    }

    // MARK: - Persistence

    private let persistenceKey = "HolisticPatternIntelligence.patterns"

    private func persistPatterns() {
        if let data = try? JSONEncoder().encode(detectedPatterns) {
            UserDefaults.standard.set(data, forKey: persistenceKey)
        }
    }

    private func loadPersistedPatterns() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey),
              let patterns = try? JSONDecoder().decode([DetectedLifePattern].self, from: data) else {
            return
        }
        self.detectedPatterns = patterns
        logger.info("Loaded \(patterns.count) persisted patterns")
    }

    // MARK: - Public API

    /// Get patterns for a specific category
    public func patterns(for category: LifePatternCategory) -> [DetectedLifePattern] {
        detectedPatterns.filter { $0.category == category }
    }

    /// Get patterns sorted by impact
    public func patternsByImpact() -> [DetectedLifePattern] {
        detectedPatterns.sorted { abs($0.impact.overallScore) > abs($1.impact.overallScore) }
    }

    /// Get patterns that need attention
    public func patternsNeedingAttention() -> [DetectedLifePattern] {
        detectedPatterns.filter { $0.impact.overallScore < -0.2 && $0.trend != .decreasing }
    }

    /// Get positive patterns to reinforce
    public func positivePatterns() -> [DetectedLifePattern] {
        detectedPatterns.filter { $0.impact.overallScore > 0.2 }
    }

    /// Get all suggestions across patterns
    public func allSuggestions() -> [PatternSuggestion] {
        detectedPatterns.flatMap { $0.suggestions }.sorted { $0.priority > $1.priority }
    }

    /// Trigger manual analysis
    public func triggerAnalysis() async {
        await runDeepAnalysis()
    }
}

