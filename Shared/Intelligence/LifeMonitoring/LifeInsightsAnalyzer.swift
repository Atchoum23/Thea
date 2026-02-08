// LifeInsightsAnalyzer.swift
// Thea V2 - Continuous AI Analysis Pipeline for Life Monitoring
//
// Analyzes life events in real-time to extract insights, patterns,
// and proactive suggestions.

import Combine
import Foundation
import os.log

// MARK: - Life Insights Analyzer

/// Continuous AI analysis pipeline for life monitoring data
@MainActor
public final class LifeInsightsAnalyzer: ObservableObject {
    public static let shared = LifeInsightsAnalyzer()

    private let logger = Logger(subsystem: "ai.thea.app", category: "LifeInsights")

    // MARK: - Published State

    @Published public private(set) var isAnalyzing = false
    @Published public private(set) var recentInsights: [AnalyzedLifeInsight] = []
    @Published public private(set) var activePatterns: [InsightDetectedLifePattern] = []
    @Published public private(set) var dailySummary: DailySummary?
    @Published public private(set) var lastAnalysisTime: Date?

    // MARK: - Configuration

    public var analysisEnabled = true
    public var batchSize = 20
    public var analysisIntervalSeconds: TimeInterval = 300 // 5 minutes
    public var maxRecentInsights = 50

    // MARK: - Internal State

    private var pendingEvents: [LifeEvent] = []
    private var analysisTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Event Aggregation

    private var eventAggregator = EventAggregator()

    // MARK: - Initialization

    private init() {
        logger.info("LifeInsightsAnalyzer initialized")
        setupEventSubscription()
    }

    // MARK: - Lifecycle

    /// Start the continuous analysis pipeline
    public func start() {
        guard analysisTask == nil else { return }

        analysisTask = Task {
            while !Task.isCancelled {
                if analysisEnabled && !pendingEvents.isEmpty {
                    await runAnalysisBatch()
                }

                try? await Task.sleep(nanoseconds: UInt64(analysisIntervalSeconds) * 1_000_000_000)
            }
        }

        logger.info("Life insights analysis pipeline started")
    }

    /// Stop the analysis pipeline
    public func stop() {
        analysisTask?.cancel()
        analysisTask = nil
        logger.info("Life insights analysis pipeline stopped")
    }

    // MARK: - Event Subscription

    private func setupEventSubscription() {
        // Subscribe to life events from the coordinator
        LifeMonitoringCoordinator.shared.eventStream
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.queueEvent(event)
            }
            .store(in: &cancellables)
    }

    /// Queue an event for analysis
    public func queueEvent(_ event: LifeEvent) {
        pendingEvents.append(event)
        eventAggregator.add(event)

        // Immediate analysis for significant events
        if event.significance >= .significant {
            Task {
                await analyzeImmediately(event)
            }
        }

        // Trigger batch analysis if threshold reached
        if pendingEvents.count >= batchSize {
            Task {
                await runAnalysisBatch()
            }
        }
    }

    // MARK: - Analysis Operations

    /// Run batch analysis on pending events
    private func runAnalysisBatch() async {
        guard !pendingEvents.isEmpty else { return }

        isAnalyzing = true
        defer { isAnalyzing = false }

        let eventsToAnalyze = pendingEvents
        pendingEvents = []

        logger.info("Analyzing batch of \(eventsToAnalyze.count) events")

        // 1. Extract patterns from the batch
        let patterns = extractPatterns(from: eventsToAnalyze)
        await updateActivePatterns(with: patterns)

        // 2. Generate insights from patterns and events
        let insights = await generateInsights(from: eventsToAnalyze, patterns: patterns)
        await addInsights(insights)

        // 3. Check for proactive opportunities
        await checkProactiveOpportunities(from: eventsToAnalyze, insights: insights)

        // 4. Update daily summary
        await updateDailySummary(with: eventsToAnalyze)

        lastAnalysisTime = Date()
    }

    /// Immediate analysis for significant events
    private func analyzeImmediately(_ event: LifeEvent) async {
        logger.debug("Immediate analysis for significant event: \(event.type.rawValue)")

        // Generate insight for this specific event
        if let insight = await generateEventInsight(event) {
            await addInsights([insight])

            if insight.isActionable {
                logger.info("Actionable insight: \(insight.title)")
            }
        }
    }

    // MARK: - Pattern Extraction

    private func extractPatterns(from events: [LifeEvent]) -> [InsightDetectedLifePattern] {
        var patterns: [InsightDetectedLifePattern] = []

        // Group events by type
        let eventsByType = Dictionary(grouping: events) { $0.type }

        for (type, typeEvents) in eventsByType {
            // Time-based patterns
            if let timePattern = detectTimePattern(events: typeEvents, type: type) {
                patterns.append(timePattern)
            }

            // Frequency patterns
            if let freqPattern = detectFrequencyPattern(events: typeEvents, type: type) {
                patterns.append(freqPattern)
            }
        }

        // Cross-event patterns (sequences)
        if let sequencePatterns = detectSequencePatterns(events: events) {
            patterns.append(contentsOf: sequencePatterns)
        }

        // Domain/topic patterns (for browser events)
        let domainPatterns = detectDomainPatterns(events: events)
        patterns.append(contentsOf: domainPatterns)

        return patterns
    }

    private func detectTimePattern(events: [LifeEvent], type: LifeEventType) -> InsightDetectedLifePattern? {
        guard events.count >= 3 else { return nil }

        // Analyze hour distribution
        let hours = events.map { Calendar.current.component(.hour, from: $0.timestamp) }
        let hourCounts = Dictionary(grouping: hours) { $0 }.mapValues { $0.count }

        if let (peakHour, count) = hourCounts.max(by: { $0.value < $1.value }),
           Double(count) / Double(events.count) > 0.5 {
            return InsightDetectedLifePattern(
                id: UUID(),
                type: .timeBased,
                description: "\(type.rawValue) activity peaks around \(peakHour):00",
                confidence: Double(count) / Double(events.count),
                frequency: count,
                relatedEventTypes: [type],
                metadata: ["peakHour": String(peakHour)]
            )
        }

        return nil
    }

    private func detectFrequencyPattern(events: [LifeEvent], type: LifeEventType) -> InsightDetectedLifePattern? {
        guard events.count >= 5 else { return nil }

        // Calculate events per day
        let days = Set(events.map { Calendar.current.startOfDay(for: $0.timestamp) }).count
        let avgPerDay = Double(events.count) / max(Double(days), 1.0)

        if avgPerDay >= 5 {
            return InsightDetectedLifePattern(
                id: UUID(),
                type: .frequency,
                description: "High frequency: \(Int(avgPerDay)) \(type.rawValue) events per day",
                confidence: min(avgPerDay / 10.0, 1.0),
                frequency: events.count,
                relatedEventTypes: [type],
                metadata: ["avgPerDay": String(format: "%.1f", avgPerDay)]
            )
        }

        return nil
    }

    private func detectSequencePatterns(events: [LifeEvent]) -> [InsightDetectedLifePattern]? {
        guard events.count >= 4 else { return nil }

        var patterns: [InsightDetectedLifePattern] = []
        let sortedEvents = events.sorted { $0.timestamp < $1.timestamp }

        // Look for A -> B patterns
        var transitions: [String: Int] = [:]

        for i in 0..<(sortedEvents.count - 1) {
            let current = sortedEvents[i]
            let next = sortedEvents[i + 1]

            // Only count if within 10 minutes
            if next.timestamp.timeIntervalSince(current.timestamp) <= 600 {
                let key = "\(current.type.rawValue)->\(next.type.rawValue)"
                transitions[key, default: 0] += 1
            }
        }

        for (transition, count) in transitions where count >= 3 {
            let components = transition.components(separatedBy: "->")
            if components.count == 2 {
                patterns.append(InsightDetectedLifePattern(
                    id: UUID(),
                    type: .sequence,
                    description: "\(components[0]) often followed by \(components[1])",
                    confidence: Double(count) / Double(events.count),
                    frequency: count,
                    relatedEventTypes: [],
                    metadata: ["from": components[0], "to": components[1]]
                ))
            }
        }

        return patterns.isEmpty ? nil : patterns
    }

    private func detectDomainPatterns(events: [LifeEvent]) -> [InsightDetectedLifePattern] {
        let browserEvents = events.filter { $0.source == .browserExtension }
        guard !browserEvents.isEmpty else { return [] }

        // Group by domain
        var domainCounts: [String: Int] = [:]
        for event in browserEvents {
            if let domain = event.data["hostname"] ?? event.data["domain"] {
                domainCounts[domain, default: 0] += 1
            }
        }

        var patterns: [InsightDetectedLifePattern] = []

        // Find top domains
        let topDomains = domainCounts.sorted { $0.value > $1.value }.prefix(5)

        for (domain, count) in topDomains where count >= 3 {
            patterns.append(InsightDetectedLifePattern(
                id: UUID(),
                type: .topicFocus,
                description: "Frequent visits to \(domain)",
                confidence: Double(count) / Double(browserEvents.count),
                frequency: count,
                relatedEventTypes: [.pageVisit, .pageRead],
                metadata: ["domain": domain]
            ))
        }

        return patterns
    }

    // MARK: - Insight Generation

    private func generateInsights(
        from events: [LifeEvent],
        patterns: [InsightDetectedLifePattern]
    ) async -> [AnalyzedLifeInsight] {
        var insights: [AnalyzedLifeInsight] = []

        // Pattern-based insights
        for pattern in patterns where pattern.confidence >= 0.5 {
            insights.append(AnalyzedLifeInsight(
                id: UUID(),
                type: patternToInsightType(pattern.type),
                title: pattern.description,
                description: generatePatternDescription(pattern),
                confidence: pattern.confidence,
                priority: pattern.confidence >= 0.8 ? .high : .medium,
                relatedEventIds: [],
                suggestedAction: generateSuggestedAction(for: pattern),
                timestamp: Date()
            ))
        }

        // Aggregate insights
        let aggregation = eventAggregator.getAggregation()

        // Productivity insight
        if aggregation.productivityScore > 0 {
            insights.append(AnalyzedLifeInsight(
                id: UUID(),
                type: .productivity,
                title: "Productivity Update",
                description: generateProductivityDescription(aggregation),
                confidence: 0.8,
                priority: .low,
                relatedEventIds: [],
                suggestedAction: nil,
                timestamp: Date()
            ))
        }

        // Reading insight
        if aggregation.totalReadingTimeMinutes >= 30 {
            insights.append(AnalyzedLifeInsight(
                id: UUID(),
                type: .learning,
                title: "Reading Progress",
                description: "You've spent \(aggregation.totalReadingTimeMinutes) minutes reading today across \(aggregation.uniqueDomainsVisited) sources.",
                confidence: 0.9,
                priority: .low,
                relatedEventIds: [],
                suggestedAction: nil,
                timestamp: Date()
            ))
        }

        // Communication insight
        let commCount = aggregation.messagesSent + aggregation.messagesReceived + aggregation.emailsReceived
        if commCount >= 10 {
            insights.append(AnalyzedLifeInsight(
                id: UUID(),
                type: .communication,
                title: "Communication Activity",
                description: "High communication activity: \(aggregation.messagesReceived) messages received, \(aggregation.emailsReceived) emails.",
                confidence: 0.85,
                priority: .medium,
                relatedEventIds: [],
                suggestedAction: "Consider setting focus time for deep work.",
                timestamp: Date()
            ))
        }

        return insights
    }

    private func generateEventInsight(_ event: LifeEvent) async -> AnalyzedLifeInsight? {
        switch event.type {
        case .pageRead:
            if let wordCount = event.data["wordCount"].flatMap(Int.init), wordCount > 2000 {
                return AnalyzedLifeInsight(
                    id: UUID(),
                    type: .learning,
                    title: "Long-form Reading Completed",
                    description: "You just read a \(wordCount)-word article: \(event.summary)",
                    confidence: 0.9,
                    priority: .medium,
                    relatedEventIds: [event.id],
                    suggestedAction: "Would you like me to summarize the key points?",
                    timestamp: Date()
                )
            }

        case .messageReceived:
            if event.significance >= .significant {
                return AnalyzedLifeInsight(
                    id: UUID(),
                    type: .communication,
                    title: "Important Message",
                    description: event.summary,
                    confidence: 0.85,
                    priority: .high,
                    relatedEventIds: [event.id],
                    suggestedAction: "Would you like to draft a response?",
                    timestamp: Date()
                )
            }

        case .emailReceived:
            if event.significance >= .significant {
                return AnalyzedLifeInsight(
                    id: UUID(),
                    type: .communication,
                    title: "Priority Email",
                    description: event.summary,
                    confidence: 0.85,
                    priority: .high,
                    relatedEventIds: [event.id],
                    suggestedAction: "Would you like me to help compose a reply?",
                    timestamp: Date()
                )
            }

        case .fileActivity:
            if event.data["changeType"] == "created",
               let fileType = event.data["fileType"],
               ["doc", "docx", "pdf", "txt", "md"].contains(fileType) {
                return AnalyzedLifeInsight(
                    id: UUID(),
                    type: .productivity,
                    title: "New Document Created",
                    description: "Created: \(event.data["path"] ?? event.summary)",
                    confidence: 0.8,
                    priority: .low,
                    relatedEventIds: [event.id],
                    suggestedAction: nil,
                    timestamp: Date()
                )
            }

        default:
            break
        }

        return nil
    }

    // MARK: - Proactive Opportunities

    private func checkProactiveOpportunities(
        from events: [LifeEvent],
        insights: [AnalyzedLifeInsight]
    ) async {
        for insight in insights where insight.isActionable {
            logger.info("Actionable insight: \(insight.title)")
        }

        let aggregation = eventAggregator.getAggregation()

        if aggregation.focusTimeMinutes >= 90 {
            logger.info("Break suggestion: focused for \(aggregation.focusTimeMinutes) minutes")
        }

        if aggregation.contextSwitches >= 10 {
            logger.info("Context switch alert: \(aggregation.contextSwitches) switches")
        }
    }

    // MARK: - Daily Summary

    private func updateDailySummary(with events: [LifeEvent]) async {
        let aggregation = eventAggregator.getAggregation()

        dailySummary = DailySummary(
            date: Date(),
            totalEvents: aggregation.totalEvents,
            browsingTimeMinutes: aggregation.totalReadingTimeMinutes,
            communicationCount: aggregation.messagesSent + aggregation.messagesReceived + aggregation.emailsReceived,
            filesModified: aggregation.filesModified,
            topDomains: aggregation.topDomains,
            productivityScore: aggregation.productivityScore,
            highlights: recentInsights.filter { $0.priority == .high }.map { $0.title }
        )
    }

    /// Generate end-of-day summary
    public func generateDailyReport() async -> String {
        let summary = dailySummary ?? DailySummary.empty

        return """
        📊 Daily Life Summary

        📱 Activity Overview:
        • Total events tracked: \(summary.totalEvents)
        • Reading time: \(summary.browsingTimeMinutes) minutes
        • Communications: \(summary.communicationCount) messages/emails
        • Files modified: \(summary.filesModified)

        🌐 Top Sites:
        \(summary.topDomains.prefix(5).enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))

        📈 Productivity Score: \(Int(summary.productivityScore * 100))%

        ⭐ Highlights:
        \(summary.highlights.isEmpty ? "• No major highlights today" : summary.highlights.map { "• \($0)" }.joined(separator: "\n"))
        """
    }

    // MARK: - Helper Methods

    private func updateActivePatterns(with newPatterns: [InsightDetectedLifePattern]) async {
        // Merge with existing patterns
        for pattern in newPatterns {
            if let existingIndex = activePatterns.firstIndex(where: { $0.description == pattern.description }) {
                // Update confidence
                activePatterns[existingIndex].confidence = (activePatterns[existingIndex].confidence + pattern.confidence) / 2
                activePatterns[existingIndex].frequency += pattern.frequency
            } else {
                activePatterns.append(pattern)
            }
        }

        // Remove stale patterns (low confidence after multiple observations)
        activePatterns.removeAll { $0.confidence < 0.3 }

        // Keep only top patterns
        if activePatterns.count > 20 {
            activePatterns.sort { $0.confidence > $1.confidence }
            activePatterns = Array(activePatterns.prefix(20))
        }
    }

    private func addInsights(_ insights: [AnalyzedLifeInsight]) async {
        recentInsights.insert(contentsOf: insights, at: 0)

        // Trim to max size
        if recentInsights.count > maxRecentInsights {
            recentInsights = Array(recentInsights.prefix(maxRecentInsights))
        }
    }

    private func patternToInsightType(_ patternType: InsightDetectedLifePattern.InsightPatternType) -> LifeInsightType {
        switch patternType {
        case .timeBased: return .routine
        case .frequency: return .productivity
        case .sequence: return .workflow
        case .topicFocus: return .learning
        case .communication: return .communication
        }
    }

    private func generatePatternDescription(_ pattern: InsightDetectedLifePattern) -> String {
        switch pattern.type {
        case .timeBased:
            return "This pattern has been observed \(pattern.frequency) times with \(Int(pattern.confidence * 100))% confidence."
        case .frequency:
            return "This activity level suggests \(pattern.confidence >= 0.7 ? "high engagement" : "regular usage")."
        case .sequence:
            return "This workflow pattern suggests an opportunity for automation."
        case .topicFocus:
            return "Consider creating a collection or project for this topic."
        case .communication:
            return "Communication patterns can help optimize your response times."
        }
    }

    private func generateSuggestedAction(for pattern: InsightDetectedLifePattern) -> String? {
        switch pattern.type {
        case .timeBased:
            if let peakHour = pattern.metadata["peakHour"] {
                return "Schedule important tasks around \(peakHour):00 for better focus."
            }
        case .sequence:
            return "Would you like me to create a shortcut for this workflow?"
        case .topicFocus:
            if let domain = pattern.metadata["domain"] {
                return "Save interesting content from \(domain) for later review."
            }
        default:
            break
        }
        return nil
    }

    private func generateProductivityDescription(_ aggregation: EventAggregation) -> String {
        let score = aggregation.productivityScore
        if score >= 0.8 {
            return "Excellent productivity! You've maintained strong focus today."
        } else if score >= 0.6 {
            return "Good productivity. Consider reducing context switches."
        } else if score >= 0.4 {
            return "Moderate productivity. Try time-blocking for better focus."
        } else {
            return "Low productivity detected. Many distractions today."
        }
    }
}

// MARK: - Supporting Types

public struct AnalyzedLifeInsight: Identifiable, Sendable {
    public let id: UUID
    public let type: LifeInsightType
    public let title: String
    public let description: String
    public let confidence: Double
    public let priority: LifeInsightPriority
    public let relatedEventIds: [UUID]
    public let suggestedAction: String?
    public let timestamp: Date

    public var isActionable: Bool {
        suggestedAction != nil
    }
}

public enum LifeInsightType: String, Codable, Sendable {
    case productivity
    case learning
    case communication
    case routine
    case workflow
    case wellness
    case general
}

/// Priority level for life insights (prefixed to avoid conflict with InsightEngine.InsightPriority)
public enum LifeInsightPriority: Int, Codable, Comparable, Sendable {
    case low = 0
    case medium = 1
    case high = 2

    public static func < (lhs: LifeInsightPriority, rhs: LifeInsightPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct InsightDetectedLifePattern: Identifiable, Sendable {
    public let id: UUID
    public let type: InsightPatternType
    public let description: String
    public var confidence: Double
    public var frequency: Int
    public let relatedEventTypes: [LifeEventType]
    public let metadata: [String: String]

    public enum InsightPatternType: String, Codable, Sendable {
        case timeBased
        case frequency
        case sequence
        case topicFocus
        case communication
    }
}

public struct DailySummary: Sendable {
    public let date: Date
    public let totalEvents: Int
    public let browsingTimeMinutes: Int
    public let communicationCount: Int
    public let filesModified: Int
    public let topDomains: [String]
    public let productivityScore: Double
    public let highlights: [String]

    public static var empty: DailySummary {
        DailySummary(
            date: Date(),
            totalEvents: 0,
            browsingTimeMinutes: 0,
            communicationCount: 0,
            filesModified: 0,
            topDomains: [],
            productivityScore: 0,
            highlights: []
        )
    }
}

// MARK: - Event Aggregator

private class EventAggregator {
    private var events: [LifeEvent] = []
    private var lastReset: Date = Calendar.current.startOfDay(for: Date())

    func add(_ event: LifeEvent) {
        // Reset if new day
        let today = Calendar.current.startOfDay(for: Date())
        if today > lastReset {
            events = []
            lastReset = today
        }

        events.append(event)
    }

    func getAggregation() -> EventAggregation {
        let browserEvents = events.filter { $0.source == .browserExtension }
        let messageEvents = events.filter { $0.type == .messageReceived || $0.type == .messageSent }
        let emailEvents = events.filter { $0.type == .emailReceived || $0.type == .emailSent }
        let fileEvents = events.filter { $0.source == .fileSystem }

        // Calculate reading time from focus time data
        let readingTime = browserEvents.compactMap { event -> Int? in
            guard let focusTimeStr = event.data["focusTimeMs"],
                  let focusTime = Int(focusTimeStr) else { return nil }
            return focusTime / 1000 / 60 // Convert to minutes
        }.reduce(0, +)

        // Get unique domains
        let domains = browserEvents.compactMap { $0.data["hostname"] ?? $0.data["domain"] }
        let uniqueDomains = Set(domains)
        let domainCounts = Dictionary(grouping: domains) { $0 }.mapValues { $0.count }
        let topDomains = domainCounts.sorted { $0.value > $1.value }.prefix(10).map { $0.key }

        // Calculate context switches (type changes within 5 minutes)
        var contextSwitches = 0
        let sortedEvents = events.sorted { $0.timestamp < $1.timestamp }
        for i in 1..<sortedEvents.count {
            if sortedEvents[i].type != sortedEvents[i - 1].type,
               sortedEvents[i].timestamp.timeIntervalSince(sortedEvents[i - 1].timestamp) <= 300 {
                contextSwitches += 1
            }
        }

        // Calculate productivity score
        let productivityScore = calculateProductivityScore(
            readingTime: readingTime,
            contextSwitches: contextSwitches,
            totalEvents: events.count
        )

        return EventAggregation(
            totalEvents: events.count,
            totalReadingTimeMinutes: readingTime,
            uniqueDomainsVisited: uniqueDomains.count,
            topDomains: Array(topDomains),
            messagesSent: messageEvents.filter { $0.type == .messageSent }.count,
            messagesReceived: messageEvents.filter { $0.type == .messageReceived }.count,
            emailsReceived: emailEvents.filter { $0.type == .emailReceived }.count,
            filesModified: fileEvents.count,
            contextSwitches: contextSwitches,
            focusTimeMinutes: readingTime, // Simplified
            productivityScore: productivityScore
        )
    }

    private func calculateProductivityScore(readingTime: Int, contextSwitches: Int, totalEvents: Int) -> Double {
        guard totalEvents > 0 else { return 0.5 }

        // Factors:
        // + Reading time (up to 120 minutes ideal)
        // - Context switches (penalize high switching)
        // + Total engagement (more events generally good)

        let readingFactor = min(Double(readingTime) / 120.0, 1.0) * 0.4
        let switchPenalty = min(Double(contextSwitches) / 20.0, 1.0) * 0.3
        let engagementFactor = min(Double(totalEvents) / 50.0, 1.0) * 0.3

        return readingFactor + engagementFactor - switchPenalty + 0.3 // Base of 0.3
    }
}

struct EventAggregation {
    let totalEvents: Int
    let totalReadingTimeMinutes: Int
    let uniqueDomainsVisited: Int
    let topDomains: [String]
    let messagesSent: Int
    let messagesReceived: Int
    let emailsReceived: Int
    let filesModified: Int
    let contextSwitches: Int
    let focusTimeMinutes: Int
    let productivityScore: Double
}
