// BehaviorPatternAnalyzer.swift
// Thea V2 - User Behavior Pattern Recognition
//
// Analyzes user behavior patterns to identify:
// - Repetitive actions that could be automated
// - Peak productivity hours
// - Distraction patterns
// - Workflow inefficiencies
// - Opportunities for improvement
//
// Feeds insights to the EfficiencySuggestionEngine for proactive recommendations.

import Combine
import Foundation
import os.log

// MARK: - Behavior Pattern Analyzer

/// Analyzes user behavior patterns for optimization opportunities
@MainActor
public final class BehaviorPatternAnalyzer: ObservableObject {
    public static let shared = BehaviorPatternAnalyzer()

    private let logger = Logger(subsystem: "ai.thea.app", category: "BehaviorPatternAnalyzer")

    // MARK: - Published State

    @Published public private(set) var isAnalyzing = false
    @Published public private(set) var detectedPatterns: [BehaviorPattern] = []
    @Published public private(set) var productivityInsights: ProductivityInsights = .empty
    @Published public private(set) var lastAnalysisTime: Date?

    // MARK: - Internal State

    private var cancellables = Set<AnyCancellable>()
    private var analysisTimer: Timer?
    private var appSwitchHistory: [AppSwitchRecord] = []
    private var actionSequences: [[UserAction]] = []

    // MARK: - Configuration

    public var configuration = AnalyzerConfiguration()

    // MARK: - Initialization

    private init() {
        logger.info("BehaviorPatternAnalyzer initialized")
    }

    // MARK: - Lifecycle

    /// Start behavior analysis
    public func start() {
        guard !isAnalyzing else { return }

        logger.info("Starting behavior pattern analysis...")

        // Subscribe to life events
        subscribeToEvents()

        // Run analysis periodically (every 5 minutes)
        analysisTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.runAnalysis()
            }
        }

        isAnalyzing = true
        logger.info("Behavior pattern analysis started")
    }

    /// Stop analysis
    public func stop() {
        guard isAnalyzing else { return }

        analysisTimer?.invalidate()
        analysisTimer = nil
        cancellables.removeAll()

        isAnalyzing = false
        logger.info("Behavior pattern analysis stopped")
    }

    // MARK: - Event Subscription

    private func subscribeToEvents() {
        // Subscribe to life monitoring events
        LifeMonitoringCoordinator.shared.eventStream
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                Task { @MainActor [weak self] in
                    self?.processEvent(event)
                }
            }
            .store(in: &cancellables)
    }

    private func processEvent(_ event: LifeEvent) {
        // Track app switches
        if event.type == .appSwitch {
            if let bundleId = event.data["bundleId"],
               let appName = event.data["appName"]
            {
                appSwitchHistory.append(AppSwitchRecord(
                    timestamp: event.timestamp,
                    fromApp: appSwitchHistory.last?.toApp ?? "",
                    toApp: bundleId,
                    toAppName: appName
                ))

                // Keep only last 1000 switches
                if appSwitchHistory.count > 1000 {
                    appSwitchHistory = Array(appSwitchHistory.suffix(1000))
                }
            }
        }

        // Convert events to user actions for sequence analysis
        let action = UserAction(
            timestamp: event.timestamp,
            type: mapEventToActionType(event.type),
            appBundleId: event.data["bundleId"] ?? event.data["appBundleId"] ?? "",
            details: event.summary
        )

        // Add to current sequence
        if var lastSequence = actionSequences.last,
           !lastSequence.isEmpty,
           let lastAction = lastSequence.last,
           event.timestamp.timeIntervalSince(lastAction.timestamp) < 30
        {
            // Continue existing sequence
            lastSequence.append(action)
            actionSequences[actionSequences.count - 1] = lastSequence
        } else {
            // Start new sequence
            actionSequences.append([action])
        }

        // Keep only last 100 sequences
        if actionSequences.count > 100 {
            actionSequences = Array(actionSequences.suffix(100))
        }
    }

    private func mapEventToActionType(_ eventType: LifeEventType) -> UserActionType {
        switch eventType {
        case .appSwitch: return .appSwitch
        case .clipboardCopy: return .copy
        case .fileActivity: return .fileOperation
        case .pageVisit: return .webNavigation
        case .searchQuery: return .search
        case .documentActivity: return .documentEdit
        case .inputActivity: return .typing
        default: return .other
        }
    }

    // MARK: - Analysis

    /// Run full pattern analysis
    public func runAnalysis() async {
        logger.debug("Running behavior pattern analysis...")

        var patterns: [BehaviorPattern] = []

        // 1. Detect repetitive action sequences
        patterns.append(contentsOf: detectRepetitiveSequences())

        // 2. Detect app switching patterns (distraction indicators)
        patterns.append(contentsOf: detectAppSwitchingPatterns())

        // 3. Detect productivity patterns
        let productivity = analyzeProductivityPatterns()

        // 4. Detect workflow inefficiencies
        patterns.append(contentsOf: detectWorkflowInefficiencies())

        // 5. Detect time-of-day patterns
        patterns.append(contentsOf: detectTimePatterns())

        // Sort by significance
        patterns.sort { $0.significance.rawValue > $1.significance.rawValue }

        // Update state
        detectedPatterns = patterns
        productivityInsights = productivity
        lastAnalysisTime = Date()

        logger.info("Detected \(patterns.count) behavior patterns")

        // Emit patterns as events
        for pattern in patterns.prefix(5) {
            emitPatternEvent(pattern)
        }
    }

    // MARK: - Pattern Detection Methods

    private func detectRepetitiveSequences() -> [BehaviorPattern] {
        var patterns: [BehaviorPattern] = []

        // Look for repeated action sequences
        var sequenceCounts: [String: (count: Int, sequence: [UserAction])] = [:]

        for sequence in actionSequences {
            guard sequence.count >= 3 else { continue }

            // Create a signature for the sequence
            let signature = sequence.map { "\($0.type.rawValue)-\($0.appBundleId)" }.joined(separator: "|")

            if var existing = sequenceCounts[signature] {
                existing.count += 1
                sequenceCounts[signature] = existing
            } else {
                sequenceCounts[signature] = (1, sequence)
            }
        }

        // Find sequences that repeat at least 3 times
        for (signature, data) in sequenceCounts where data.count >= 3 {
            let description = describeSequence(data.sequence)
            patterns.append(BehaviorPattern(
                id: UUID(),
                type: .repetitiveAction,
                title: "Repetitive Action Detected",
                description: "You've done this \(data.count) times: \(description)",
                frequency: data.count,
                significance: data.count >= 10 ? .high : (data.count >= 5 ? .medium : .low),
                suggestion: "Consider creating an automation or shortcut for this workflow",
                potentialTimeSaved: TimeInterval(data.count * 30), // Estimate 30 seconds saved per occurrence
                detectedAt: Date(),
                relatedApps: Set(data.sequence.map { $0.appBundleId })
            ))
        }

        return patterns
    }

    private func detectAppSwitchingPatterns() -> [BehaviorPattern] {
        var patterns: [BehaviorPattern] = []

        // Calculate app switch frequency in the last hour
        let oneHourAgo = Date().addingTimeInterval(-3600)
        let recentSwitches = appSwitchHistory.filter { $0.timestamp >= oneHourAgo }

        if recentSwitches.count > 60 {
            // More than 1 switch per minute on average = high switching
            patterns.append(BehaviorPattern(
                id: UUID(),
                type: .distraction,
                title: "High App Switching Frequency",
                description: "You've switched apps \(recentSwitches.count) times in the last hour",
                frequency: recentSwitches.count,
                significance: .high,
                suggestion: "Consider using focus mode or closing distracting apps",
                potentialTimeSaved: TimeInterval(recentSwitches.count * 5), // 5 seconds lost per switch
                detectedAt: Date(),
                relatedApps: Set(recentSwitches.map { $0.toApp })
            ))
        }

        // Detect ping-pong switching between specific apps
        var switchPairs: [String: Int] = [:]
        for i in 0 ..< (recentSwitches.count - 1) {
            let pair = "\(recentSwitches[i].toApp)⟷\(recentSwitches[i + 1].toApp)"
            switchPairs[pair, default: 0] += 1
        }

        for (pair, count) in switchPairs where count >= 10 {
            let apps = pair.components(separatedBy: "⟷")
            patterns.append(BehaviorPattern(
                id: UUID(),
                type: .distraction,
                title: "Frequent Back-and-Forth Switching",
                description: "You've switched between these apps \(count) times",
                frequency: count,
                significance: .medium,
                suggestion: "Consider using split view or organizing your workflow",
                potentialTimeSaved: TimeInterval(count * 3),
                detectedAt: Date(),
                relatedApps: Set(apps)
            ))
        }

        return patterns
    }

    private func analyzeProductivityPatterns() -> ProductivityInsights {
        var insights = ProductivityInsights.empty

        // Get input activity data
        let inputStats = InputActivityMonitor.shared.todayStats

        // Determine peak hours
        let sortedHours = inputStats.activityByHour.sorted { $0.value > $1.value }
        insights.peakProductivityHours = Array(sortedHours.prefix(3).map { $0.key })

        // Calculate productivity metrics
        insights.averageTypingSpeed = inputStats.averageTypingSpeed
        insights.averageFocusScore = inputStats.averageFocusScore
        insights.totalActiveTime = inputStats.totalActiveTime
        insights.totalKeystrokes = inputStats.totalKeystrokes

        // Determine productivity level
        if inputStats.averageFocusScore >= 0.7 && inputStats.averageTypingSpeed >= 40 {
            insights.overallProductivityLevel = .high
        } else if inputStats.averageFocusScore >= 0.4 && inputStats.averageTypingSpeed >= 25 {
            insights.overallProductivityLevel = .medium
        } else {
            insights.overallProductivityLevel = .low
        }

        // Calculate context switch cost
        let recentSwitches = appSwitchHistory.filter {
            Calendar.current.isDateInToday($0.timestamp)
        }
        insights.contextSwitchCost = TimeInterval(recentSwitches.count * 23) // ~23 seconds to refocus

        return insights
    }

    private func detectWorkflowInefficiencies() -> [BehaviorPattern] {
        var patterns: [BehaviorPattern] = []

        // Detect frequent copy-paste between apps (could use automation)
        // This would need clipboard history - for now just a placeholder
        // TODO: Integrate with clipboard history when available

        // Detect long idle periods followed by burst activity (poor time management)
        let sessions = InputActivityMonitor.shared.recentSessions
        var longIdleSessions = 0

        for session in sessions {
            if session.idleTime > session.duration * 0.5 {
                longIdleSessions += 1
            }
        }

        if longIdleSessions >= 3 {
            patterns.append(BehaviorPattern(
                id: UUID(),
                type: .inefficiency,
                title: "Irregular Work Patterns Detected",
                description: "Several sessions have > 50% idle time",
                frequency: longIdleSessions,
                significance: .medium,
                suggestion: "Try the Pomodoro technique: 25 min work, 5 min break",
                potentialTimeSaved: nil,
                detectedAt: Date(),
                relatedApps: []
            ))
        }

        return patterns
    }

    private func detectTimePatterns() -> [BehaviorPattern] {
        var patterns: [BehaviorPattern] = []

        let inputStats = InputActivityMonitor.shared.todayStats

        // Find the most productive hour
        if let (peakHour, activity) = inputStats.activityByHour.max(by: { $0.value < $1.value }),
           activity > 100
        {
            patterns.append(BehaviorPattern(
                id: UUID(),
                type: .productivityPeak,
                title: "Peak Productivity Time Identified",
                description: "Your most productive hour is around \(peakHour):00",
                frequency: 1,
                significance: .medium,
                suggestion: "Schedule your most important tasks during this time",
                potentialTimeSaved: nil,
                detectedAt: Date(),
                relatedApps: []
            ))
        }

        // Detect late-night work (potential burnout risk)
        let lateNightActivity = (inputStats.activityByHour[22] ?? 0) +
            (inputStats.activityByHour[23] ?? 0) +
            (inputStats.activityByHour[0] ?? 0) +
            (inputStats.activityByHour[1] ?? 0)

        if lateNightActivity > 200 {
            patterns.append(BehaviorPattern(
                id: UUID(),
                type: .healthRisk,
                title: "Late Night Activity Detected",
                description: "Significant activity detected after 10 PM",
                frequency: lateNightActivity,
                significance: .medium,
                suggestion: "Consider setting a work cutoff time for better sleep",
                potentialTimeSaved: nil,
                detectedAt: Date(),
                relatedApps: []
            ))
        }

        return patterns
    }

    // MARK: - Helpers

    private func describeSequence(_ sequence: [UserAction]) -> String {
        let actionDescriptions = sequence.prefix(4).map { action -> String in
            switch action.type {
            case .appSwitch: return "switch app"
            case .copy: return "copy"
            case .paste: return "paste"
            case .fileOperation: return "file action"
            case .webNavigation: return "browse"
            case .search: return "search"
            case .typing: return "type"
            case .click: return "click"
            case .documentEdit: return "edit document"
            default: return "action"
            }
        }
        return actionDescriptions.joined(separator: " → ")
    }

    private func emitPatternEvent(_ pattern: BehaviorPattern) {
        let event = LifeEvent(
            type: .behaviorPattern,
            source: .inputActivity,
            summary: pattern.title,
            data: [
                "patternType": pattern.type.rawValue,
                "description": pattern.description,
                "frequency": String(pattern.frequency),
                "significance": pattern.significance.rawValue,
                "suggestion": pattern.suggestion ?? ""
            ],
            significance: pattern.significance == .high ? .significant : .moderate
        )

        LifeMonitoringCoordinator.shared.submitEvent(event)
    }
}

// MARK: - Supporting Types

/// Configuration for the behavior analyzer
public struct AnalyzerConfiguration: Sendable {
    public var analysisIntervalSeconds: TimeInterval = 300 // 5 minutes
    public var minSequenceLengthForPattern: Int = 3
    public var minRepetitionsForPattern: Int = 3
    public var appSwitchDistractioThreshold: Int = 60 // per hour
}

/// A detected behavior pattern
public struct BehaviorPattern: Identifiable, Sendable {
    public let id: UUID
    public let type: PatternType
    public let title: String
    public let description: String
    public let frequency: Int
    public let significance: PatternSignificance
    public let suggestion: String?
    public let potentialTimeSaved: TimeInterval?
    public let detectedAt: Date
    public let relatedApps: Set<String>

    public enum PatternType: String, Sendable {
        case repetitiveAction = "repetitive_action"
        case distraction = "distraction"
        case inefficiency = "inefficiency"
        case productivityPeak = "productivity_peak"
        case healthRisk = "health_risk"
        case opportunity = "opportunity"
    }

    public enum PatternSignificance: String, Sendable, Comparable {
        case low, medium, high

        public static func < (lhs: PatternSignificance, rhs: PatternSignificance) -> Bool {
            let order: [PatternSignificance] = [.low, .medium, .high]
            return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
        }
    }
}

/// Productivity insights from behavior analysis
public struct ProductivityInsights: Sendable {
    public var peakProductivityHours: [Int]
    public var averageTypingSpeed: Double
    public var averageFocusScore: Double
    public var totalActiveTime: TimeInterval
    public var totalKeystrokes: Int
    public var overallProductivityLevel: ProductivityLevel
    public var contextSwitchCost: TimeInterval

    public enum ProductivityLevel: String, Sendable {
        case low, medium, high
    }

    public static var empty: ProductivityInsights {
        ProductivityInsights(
            peakProductivityHours: [],
            averageTypingSpeed: 0,
            averageFocusScore: 0,
            totalActiveTime: 0,
            totalKeystrokes: 0,
            overallProductivityLevel: .low,
            contextSwitchCost: 0
        )
    }
}

/// Record of an app switch
struct AppSwitchRecord: Sendable {
    let timestamp: Date
    let fromApp: String
    let toApp: String
    let toAppName: String
}

/// A user action for sequence analysis
struct UserAction: Sendable {
    let timestamp: Date
    let type: UserActionType
    let appBundleId: String
    let details: String
}

/// Types of user actions
enum UserActionType: String, Sendable {
    case appSwitch = "app_switch"
    case copy = "copy"
    case paste = "paste"
    case fileOperation = "file_op"
    case webNavigation = "web_nav"
    case search = "search"
    case typing = "typing"
    case click = "click"
    case documentEdit = "doc_edit"
    case other = "other"
}
