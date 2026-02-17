//
//  InsightEngine.swift
//  Thea
//
//  Created by Thea
//  Proactive insights based on context analysis
//

import Foundation
import os.log

#if canImport(UIKit)
    import UIKit
#endif

#if canImport(AppKit)
    import AppKit
#endif

// MARK: - Insight Engine

/// Generates proactive insights based on aggregated context
@MainActor
public final class InsightEngine: ObservableObject {
    public static let shared = InsightEngine()

    private let logger = Logger(subsystem: "app.thea.context", category: "InsightEngine")

    // MARK: - Published State

    @Published public private(set) var activeInsights: [Insight] = []
    @Published public private(set) var insightHistory: [Insight] = []
    @Published public private(set) var isAnalyzing = false

    // MARK: - Configuration

    public var insightGenerationInterval: TimeInterval = 300 // 5 minutes
    public var maxActiveInsights = 5
    public var maxHistorySize = 100
    public var minimumConfidence: Double = 0.6

    // MARK: - Insight Generators

    private var generators: [InsightGenerator] = []
    private var analysisTask: Task<Void, Never>?

    private init() {
        registerDefaultGenerators()
    }

    // MARK: - Lifecycle

    public func start() {
        logger.info("Starting InsightEngine")

        analysisTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.generateInsights()
                try? await Task.sleep(for: .seconds(self?.insightGenerationInterval ?? 300))
            }
        }
    }

    public func stop() {
        analysisTask?.cancel()
        analysisTask = nil
        logger.info("InsightEngine stopped")
    }

    // MARK: - Insight Generation

    public func generateInsights() async {
        guard !isAnalyzing else { return }

        isAnalyzing = true
        defer { isAnalyzing = false }

        let context = await UnifiedContextEngine.shared.captureSnapshot()
        var newInsights: [Insight] = []

        for generator in generators {
            if let insights = await generator.generate(from: context) {
                newInsights.append(contentsOf: insights.filter { $0.confidence >= minimumConfidence })
            }
        }

        // Sort by priority and confidence
        newInsights.sort { ($0.priority.rawValue, $0.confidence) > ($1.priority.rawValue, $1.confidence) }

        // Keep top insights
        let topInsights = Array(newInsights.prefix(maxActiveInsights))

        // Update state
        await MainActor.run {
            // Archive old insights
            for insight in self.activeInsights where !topInsights.contains(where: { $0.id == insight.id }) {
                var archived = insight
                archived.status = .archived
                self.insightHistory.append(archived)
            }

            // Trim history
            if self.insightHistory.count > self.maxHistorySize {
                self.insightHistory = Array(self.insightHistory.suffix(self.maxHistorySize))
            }

            self.activeInsights = topInsights
        }

        logger.debug("Generated \(newInsights.count) insights, \(topInsights.count) active")
    }

    // MARK: - Generator Registration

    public func registerGenerator(_ generator: InsightGenerator) {
        generators.append(generator)
        logger.debug("Registered insight generator: \(type(of: generator))")
    }

    private func registerDefaultGenerators() {
        generators = [
            ProductivityInsightGenerator(),
            HealthInsightGenerator(),
            ScheduleInsightGenerator(),
            FocusInsightGenerator(),
            WorkflowInsightGenerator(),
            LocationInsightGenerator(),
            CommunicationInsightGenerator()
        ]
    }

    // MARK: - Insight Actions

    public func dismissInsight(_ insight: Insight) {
        if let index = activeInsights.firstIndex(where: { $0.id == insight.id }) {
            var dismissed = activeInsights.remove(at: index)
            dismissed.status = .dismissed
            insightHistory.append(dismissed)
        }
    }

    public func actOnInsight(_ insight: Insight) async {
        guard let action = insight.suggestedAction else { return }

        logger.info("Acting on insight: \(insight.title)")

        // Mark as acted upon
        if let index = activeInsights.firstIndex(where: { $0.id == insight.id }) {
            activeInsights[index].status = .actedUpon
        }

        // Execute action
        await executeAction(action)
    }

    private func executeAction(_ action: InsightAction) async {
        switch action.type {
        case let .openApp(bundleId):
            #if os(macOS)
                if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                    _ = try? await NSWorkspace.shared.openApplication(at: url, configuration: .init())
                }
            #elseif os(iOS)
                // Use URL schemes or shortcuts
                break
            #endif

        case .runShortcut:
            // Execute via ShortcutsOrchestrator
            break

        case .setFocus:
            // Use FocusOrchestrator
            break

        case let .sendNotification(title, body):
            try? await CrossDeviceNotificationRouter.shared.sendNotification(title: title, body: body)

        case let .navigate(url):
            #if os(macOS)
                NSWorkspace.shared.open(url)
            #elseif os(iOS)
                await UIApplication.shared.open(url)
            #endif

        case let .custom(handler):
            await handler()
        }
    }

    // MARK: - Query

    public func insightsMatching(category: InsightCategory) -> [Insight] {
        activeInsights.filter { $0.category == category }
    }

    public func highPriorityInsights() -> [Insight] {
        activeInsights.filter { $0.priority == .high || $0.priority == .critical }
    }
}

// MARK: - Insight Model

public struct Insight: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let description: String
    public let category: InsightCategory
    public let priority: InsightPriority
    public let confidence: Double // 0.0 - 1.0
    public var status: InsightStatus
    public let createdAt: Date
    public let expiresAt: Date?
    public let suggestedAction: InsightAction?
    public let relatedContext: [String: String]

    public init(
        id: String = UUID().uuidString,
        title: String,
        description: String,
        category: InsightCategory,
        priority: InsightPriority = .normal,
        confidence: Double,
        status: InsightStatus = .active,
        expiresAt: Date? = nil,
        suggestedAction: InsightAction? = nil,
        relatedContext: [String: String] = [:]
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.priority = priority
        self.confidence = min(1.0, max(0.0, confidence))
        self.status = status
        createdAt = Date()
        self.expiresAt = expiresAt
        self.suggestedAction = suggestedAction
        self.relatedContext = relatedContext
    }
}

public enum InsightCategory: String, Codable, Sendable, CaseIterable {
    case productivity
    case health
    case schedule
    case focus
    case workflow
    case location
    case communication
    case finance
    case learning
    case entertainment
}

public enum InsightPriority: Int, Codable, Sendable, Comparable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3

    public static func < (lhs: InsightPriority, rhs: InsightPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum InsightStatus: String, Codable, Sendable {
    case active
    case dismissed
    case actedUpon
    case expired
    case archived
}

// MARK: - Insight Action

public struct InsightAction: Sendable {
    public let label: String
    public let type: ActionType

    public enum ActionType: Sendable {
        case openApp(bundleId: String)
        case runShortcut(name: String)
        case setFocus(mode: String)
        case sendNotification(title: String, body: String)
        case navigate(url: URL)
        case custom(handler: @Sendable () async -> Void)
    }

    public init(label: String, type: ActionType) {
        self.label = label
        self.type = type
    }
}

// MARK: - Insight Generator Protocol

public protocol InsightGenerator: Sendable {
    func generate(from context: ContextSnapshot) async -> [Insight]?
}

// MARK: - Default Generators

public struct ProductivityInsightGenerator: InsightGenerator {
    public init() {}

    public func generate(from context: ContextSnapshot) async -> [Insight]? {
        var insights: [Insight] = []

        // Check for long work sessions without breaks
        if let workDurationStr = context.metadata["workSessionDuration"],
           let workDuration = TimeInterval(workDurationStr),
           workDuration > 7200
        { // 2 hours
            insights.append(Insight(
                title: "Time for a Break",
                description: "You've been working for over 2 hours. A short break can boost productivity.",
                category: .productivity,
                priority: .high,
                confidence: 0.85,
                suggestedAction: InsightAction(
                    label: "Start Break Timer",
                    type: .runShortcut(name: "Start Break")
                )
            ))
        }

        // Check for context switching
        if let appSwitchesStr = context.metadata["recentAppSwitches"],
           let appSwitches = Int(appSwitchesStr),
           appSwitches > 20
        {
            insights.append(Insight(
                title: "High Context Switching",
                description: "You've switched apps \(appSwitches) times recently. Consider focusing on one task.",
                category: .productivity,
                priority: .normal,
                confidence: 0.7,
                suggestedAction: InsightAction(
                    label: "Enable Focus Mode",
                    type: .setFocus(mode: "Work")
                )
            ))
        }

        return insights.isEmpty ? nil : insights
    }
}

public struct HealthInsightGenerator: InsightGenerator {
    public init() {}

    public func generate(from context: ContextSnapshot) async -> [Insight]? {
        var insights: [Insight] = []

        // Check screen time
        if let screenTimeStr = context.metadata["todayScreenTime"],
           let screenTime = TimeInterval(screenTimeStr),
           screenTime > 28800
        { // 8 hours
            insights.append(Insight(
                title: "Extended Screen Time",
                description: "You've had over 8 hours of screen time today. Consider taking a break.",
                category: .health,
                priority: .normal,
                confidence: 0.9
            ))
        }

        // Check for late night usage
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 23 || hour < 5 {
            insights.append(Insight(
                title: "Late Night Usage",
                description: "Using devices late at night can affect sleep quality.",
                category: .health,
                priority: .normal,
                confidence: 0.75,
                suggestedAction: InsightAction(
                    label: "Enable Night Mode",
                    type: .setFocus(mode: "Sleep")
                )
            ))
        }

        return insights.isEmpty ? nil : insights
    }
}

public struct ScheduleInsightGenerator: InsightGenerator {
    public init() {}

    public func generate(from context: ContextSnapshot) async -> [Insight]? {
        var insights: [Insight] = []

        // Check upcoming events
        if let nextEvent = context.metadata["nextCalendarEvent"],
           let minutesUntilStr = context.metadata["minutesUntilNextEvent"],
           let minutesUntil = Int(minutesUntilStr),
           minutesUntil <= 15, minutesUntil > 0
        {
            insights.append(Insight(
                title: "Upcoming: \(nextEvent)",
                description: "Starts in \(minutesUntil) minutes",
                category: .schedule,
                priority: .high,
                confidence: 1.0,
                expiresAt: Date().addingTimeInterval(TimeInterval(minutesUntil * 60))
            ))
        }

        return insights.isEmpty ? nil : insights
    }
}

public struct FocusInsightGenerator: InsightGenerator {
    public init() {}

    public func generate(from context: ContextSnapshot) async -> [Insight]? {
        var insights: [Insight] = []

        // Suggest focus mode based on activity
        if let currentApp = context.metadata["focusedApp"] {
            let workApps = ["Xcode", "Visual Studio Code", "Slack", "Microsoft Teams"]
            let creativeApps = ["Figma", "Sketch", "Adobe Photoshop", "Logic Pro"]

            if workApps.contains(currentApp) {
                if context.metadata["currentFocusMode"] != "Work" {
                    insights.append(Insight(
                        title: "Enable Work Focus?",
                        description: "You're using \(currentApp). Work Focus can reduce distractions.",
                        category: .focus,
                        priority: .normal,
                        confidence: 0.7,
                        suggestedAction: InsightAction(
                            label: "Enable Work Focus",
                            type: .setFocus(mode: "Work")
                        )
                    ))
                }
            } else if creativeApps.contains(currentApp) {
                insights.append(Insight(
                    title: "Creative Session Detected",
                    description: "Consider enabling Do Not Disturb for uninterrupted flow.",
                    category: .focus,
                    priority: .normal,
                    confidence: 0.65,
                    suggestedAction: InsightAction(
                        label: "Enable DND",
                        type: .setFocus(mode: "Do Not Disturb")
                    )
                ))
            }
        }

        return insights.isEmpty ? nil : insights
    }
}

public struct WorkflowInsightGenerator: InsightGenerator {
    public init() {}

    public func generate(from context: ContextSnapshot) async -> [Insight]? {
        var insights: [Insight] = []

        // Detect common workflows and suggest automation
        // Parse comma-separated actions from metadata string
        if let actionsStr = context.metadata["recentActions"] {
            let recentActions = actionsStr.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            if recentActions.count >= 3 {
                // Check for repetitive patterns
                let actionCounts = Dictionary(grouping: recentActions) { $0 }
                    .mapValues { $0.count }

                for (action, count) in actionCounts where count >= 3 {
                    insights.append(Insight(
                        title: "Repetitive Action Detected",
                        description: "You've done '\(action)' \(count) times. Want to automate it?",
                        category: .workflow,
                        priority: .low,
                        confidence: 0.6,
                        suggestedAction: InsightAction(
                            label: "Create Shortcut",
                            type: .openApp(bundleId: "com.apple.shortcuts")
                        )
                    ))
                }
            }
        }

        return insights.isEmpty ? nil : insights
    }
}

public struct LocationInsightGenerator: InsightGenerator {
    public init() {}

    public func generate(from context: ContextSnapshot) async -> [Insight]? {
        var insights: [Insight] = []

        // Location-based insights
        if let location = context.metadata["currentLocation"] {
            switch location.lowercased() {
            case let l where l.contains("office") || l.contains("work"):
                if context.metadata["currentFocusMode"] != "Work" {
                    insights.append(Insight(
                        title: "At Work",
                        description: "Enable Work Focus to stay productive?",
                        category: .location,
                        priority: .normal,
                        confidence: 0.8,
                        suggestedAction: InsightAction(
                            label: "Enable Work Focus",
                            type: .setFocus(mode: "Work")
                        )
                    ))
                }

            case let l where l.contains("home"):
                let hour = Calendar.current.component(.hour, from: Date())
                if hour >= 18 {
                    insights.append(Insight(
                        title: "Home Evening",
                        description: "Consider switching to Personal Focus mode.",
                        category: .location,
                        priority: .low,
                        confidence: 0.6,
                        suggestedAction: InsightAction(
                            label: "Enable Personal Focus",
                            type: .setFocus(mode: "Personal")
                        )
                    ))
                }

            default:
                break
            }
        }

        return insights.isEmpty ? nil : insights
    }
}

public struct CommunicationInsightGenerator: InsightGenerator {
    public init() {}

    public func generate(from context: ContextSnapshot) async -> [Insight]? {
        var insights: [Insight] = []

        // Check for unread messages
        if let unreadCountStr = context.metadata["unreadMessages"],
           let unreadCount = Int(unreadCountStr),
           unreadCount > 10
        {
            insights.append(Insight(
                title: "\(unreadCount) Unread Messages",
                description: "You have pending messages across apps.",
                category: .communication,
                priority: .normal,
                confidence: 0.9,
                suggestedAction: InsightAction(
                    label: "View Messages",
                    type: .openApp(bundleId: "com.apple.MobileSMS")
                )
            ))
        }

        // Check for missed calls
        if let missedCallsStr = context.metadata["missedCalls"],
           let missedCalls = Int(missedCallsStr),
           missedCalls > 0
        {
            insights.append(Insight(
                title: "\(missedCalls) Missed Call\(missedCalls > 1 ? "s" : "")",
                description: "You have missed calls to return.",
                category: .communication,
                priority: .high,
                confidence: 1.0,
                suggestedAction: InsightAction(
                    label: "View Calls",
                    type: .openApp(bundleId: "com.apple.mobilephone")
                )
            ))
        }

        return insights.isEmpty ? nil : insights
    }
}
