//
//  SmartSuggestionEngine.swift
//  Thea
//
//  Proactive Task Suggestion Engine - monitors user patterns and suggests
//  actions before they're requested. Based on 2026 AI assistant best practices.
//
//  Copyright 2026. All rights reserved.
//

import Foundation
import SwiftUI
import os.log

// MARK: - Proactive Suggestion Types

/// Types of proactive suggestions THEA can offer
public enum SmartSuggestionType: String, Codable, Sendable, CaseIterable {
    case routine          // Based on daily patterns
    case contextual       // Based on current app/document
    case followUp         // Incomplete tasks from previous sessions
    case timeBased        // Time-sensitive suggestions
    case locationBased    // Location-aware suggestions
    case eventBased       // Calendar/meeting related
    case contentBased     // Based on clipboard/screen content
    case learningBased    // From user correction patterns

    var icon: String {
        switch self {
        case .routine: return "clock.arrow.circlepath"
        case .contextual: return "sparkles"
        case .followUp: return "arrow.counterclockwise"
        case .timeBased: return "clock"
        case .locationBased: return "location"
        case .eventBased: return "calendar"
        case .contentBased: return "doc.text.magnifyingglass"
        case .learningBased: return "brain.head.profile"
        }
    }

    var priority: Int {
        switch self {
        case .followUp: return 100      // High - unfinished work
        case .timeBased: return 90      // High - time sensitive
        case .eventBased: return 85     // High - meeting prep
        case .contextual: return 80     // High - relevant now
        case .routine: return 60        // Medium - daily patterns
        case .contentBased: return 50   // Medium - based on content
        case .locationBased: return 40  // Lower - location context
        case .learningBased: return 30  // Lower - learned preferences
        }
    }
}

/// Urgency level for suggestions
public enum SuggestionUrgency: String, Codable, Sendable {
    case low
    case medium
    case high
    case critical

    var displayColor: Color {
        switch self {
        case .low: return .secondary
        case .medium: return .blue
        case .high: return .orange
        case .critical: return .red
        }
    }
}

/// A proactive suggestion from THEA
public struct SmartSuggestion: Identifiable, Codable, Sendable {
    public let id: UUID
    public let type: SmartSuggestionType
    public let title: String
    public let description: String
    public let urgency: SuggestionUrgency
    public let action: SuggestionAction
    public let confidence: Double
    public let createdAt: Date
    public var expiresAt: Date?
    public var dismissedAt: Date?
    public var acceptedAt: Date?

    /// Context that triggered this suggestion
    public let triggerContext: TriggerContext

    public struct TriggerContext: Codable, Sendable {
        public let source: String
        public let metadata: [String: String]
        public let timestamp: Date

        public init(source: String, metadata: [String: String] = [:]) {
            self.source = source
            self.metadata = metadata
            self.timestamp = Date()
        }
    }

    public enum SuggestionAction: Codable, Sendable {
        case sendMessage(prompt: String)
        case openConversation(id: UUID)
        case runShortcut(name: String)
        case openURL(url: String)
        case showReminder(text: String)
        case custom(actionId: String, parameters: [String: String])
    }

    public init(
        id: UUID = UUID(),
        type: SmartSuggestionType,
        title: String,
        description: String,
        urgency: SuggestionUrgency = .medium,
        action: SuggestionAction,
        confidence: Double,
        triggerContext: TriggerContext,
        expiresAt: Date? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.description = description
        self.urgency = urgency
        self.action = action
        self.confidence = confidence
        self.createdAt = Date()
        self.expiresAt = expiresAt
        self.triggerContext = triggerContext
    }

    public var isExpired: Bool {
        guard let expiresAt else { return false }
        return Date() > expiresAt
    }

    public var isActive: Bool {
        !isExpired && dismissedAt == nil && acceptedAt == nil
    }
}

// MARK: - User Pattern

/// Represents a learned user behavior pattern
public struct LearnedUserPattern: Codable, Sendable, Identifiable {
    public let id: UUID
    public let patternType: PatternType
    public let description: String
    public var occurrences: Int
    public var lastOccurrence: Date
    public var confidence: Double
    public var timeSlots: [TimeSlot]
    public var dayOfWeek: [Int]? // 1=Sunday, 7=Saturday
    public var associatedApps: [String]?
    public var associatedLocations: [String]?

    public enum PatternType: String, Codable, Sendable {
        case dailyRoutine
        case weeklyRoutine
        case appUsage
        case queryPattern
        case workflowPattern
        case preferencePattern
    }

    public struct TimeSlot: Codable, Sendable {
        public let hour: Int
        public let minute: Int
        public var frequency: Int

        public init(hour: Int, minute: Int, frequency: Int = 1) {
            self.hour = hour
            self.minute = minute
            self.frequency = frequency
        }
    }

    public init(
        id: UUID = UUID(),
        patternType: PatternType,
        description: String,
        timeSlots: [TimeSlot] = [],
        dayOfWeek: [Int]? = nil
    ) {
        self.id = id
        self.patternType = patternType
        self.description = description
        self.occurrences = 1
        self.lastOccurrence = Date()
        self.confidence = 0.5
        self.timeSlots = timeSlots
        self.dayOfWeek = dayOfWeek
    }

    public mutating func recordOccurrence() {
        occurrences += 1
        lastOccurrence = Date()
        // Increase confidence with more occurrences (asymptotic to 1.0)
        confidence = min(0.95, 1.0 - (1.0 / Double(occurrences + 1)))
    }
}

// MARK: - Proactive Suggestion Engine

/// Engine that generates proactive suggestions based on user patterns and context
@MainActor
public final class SmartSuggestionEngine: ObservableObject {
    public static let shared = SmartSuggestionEngine()

    private let logger = Logger(subsystem: "ai.thea.app", category: "SmartSuggestions")

    // MARK: - Published State

    /// Active suggestions to display
    @Published public private(set) var activeSuggestions: [SmartSuggestion] = []

    /// Learned user patterns
    @Published public private(set) var patterns: [LearnedUserPattern] = []

    /// Whether proactive suggestions are enabled
    @Published public var isEnabled: Bool = true {
        didSet { savePreferences() }
    }

    /// Minimum confidence threshold for showing suggestions
    @Published public var confidenceThreshold: Double = 0.6 {
        didSet { savePreferences() }
    }

    /// Maximum number of suggestions to show at once
    @Published public var maxSuggestions: Int = 3 {
        didSet { savePreferences() }
    }

    /// Suggestion types the user wants to receive
    @Published public var enabledTypes: Set<SmartSuggestionType> = Set(SmartSuggestionType.allCases) {
        didSet { savePreferences() }
    }

    // MARK: - Private State

    private var patternMonitorTask: Task<Void, Never>?
    private var contextMonitorTask: Task<Void, Never>?
    private var suggestionHistory: [SmartSuggestion] = []
    private let maxHistorySize = 1000

    // MARK: - Initialization

    private init() {
        loadPatterns()
        loadPreferences()
        loadSuggestionHistory()
        startMonitoring()
        logger.info("SmartSuggestionEngine initialized")
    }

    deinit {
        patternMonitorTask?.cancel()
        contextMonitorTask?.cancel()
    }

    // MARK: - Public API

    /// Record a user action for pattern learning
    public func recordAction(
        type: String,
        context: [String: String] = [:],
        timestamp: Date = Date()
    ) {
        guard isEnabled else { return }

        // Check if this matches an existing pattern
        if let patternIndex = findMatchingPattern(type: type, context: context) {
            patterns[patternIndex].recordOccurrence()
        } else {
            // Create new potential pattern
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: timestamp)
            let minute = calendar.component(.minute, from: timestamp)
            let dayOfWeek = calendar.component(.weekday, from: timestamp)

            let newPattern = LearnedUserPattern(
                patternType: .queryPattern,
                description: type,
                timeSlots: [LearnedUserPattern.TimeSlot(hour: hour, minute: minute)],
                dayOfWeek: [dayOfWeek]
            )
            patterns.append(newPattern)
        }

        savePatterns()
        evaluatePatternsForSuggestions()
    }

    /// Record an incomplete task for follow-up
    public func recordIncompleteTask(
        conversationId: UUID,
        taskDescription: String,
        context: [String: String] = [:]
    ) {
        let suggestion = SmartSuggestion(
            type: .followUp,
            title: "Continue: \(taskDescription.prefix(50))",
            description: "You started this task earlier but didn't complete it.",
            urgency: .medium,
            action: .openConversation(id: conversationId),
            confidence: 0.8,
            triggerContext: SmartSuggestion.TriggerContext(
                source: "incomplete_task",
                metadata: context
            ),
            expiresAt: Calendar.current.date(byAdding: .day, value: 7, to: Date())
        )

        addSuggestion(suggestion)
    }

    /// Generate contextual suggestion based on current app/content
    public func generateContextualSuggestion(
        app: String,
        windowTitle: String?,
        clipboardContent: String?
    ) async {
        guard isEnabled && enabledTypes.contains(.contextual) else { return }

        var suggestions: [SmartSuggestion] = []

        // Xcode context
        if app.lowercased().contains("xcode") {
            if let title = windowTitle, title.contains(".swift") {
                suggestions.append(SmartSuggestion(
                    type: .contextual,
                    title: "Review this Swift file?",
                    description: "I can help review \(title) for issues and improvements.",
                    urgency: .low,
                    action: .sendMessage(prompt: "Please review the Swift code I'm currently working on for potential issues, performance improvements, and best practices."),
                    confidence: 0.7,
                    triggerContext: .init(source: "xcode_context", metadata: ["file": title])
                ))
            }
        }

        // Browser context
        if app.lowercased().contains("safari") || app.lowercased().contains("chrome") {
            if let title = windowTitle {
                suggestions.append(SmartSuggestion(
                    type: .contextual,
                    title: "Summarize this page?",
                    description: "I can summarize '\(title.prefix(40))...' for you.",
                    urgency: .low,
                    action: .sendMessage(prompt: "Please summarize the key points from the webpage I'm currently viewing: \(title)"),
                    confidence: 0.65,
                    triggerContext: .init(source: "browser_context", metadata: ["title": title])
                ))
            }
        }

        // Clipboard content
        if let clipboard = clipboardContent, clipboard.count > 20 {
            if clipboard.contains("func ") || clipboard.contains("class ") || clipboard.contains("struct ") {
                suggestions.append(SmartSuggestion(
                    type: .contentBased,
                    title: "Explain this code?",
                    description: "I noticed code on your clipboard. Want me to explain it?",
                    urgency: .low,
                    action: .sendMessage(prompt: "Please explain this code:\n\n```\n\(clipboard.prefix(500))\n```"),
                    confidence: 0.75,
                    triggerContext: .init(source: "clipboard", metadata: ["length": "\(clipboard.count)"])
                ))
            }
        }

        for suggestion in suggestions where suggestion.confidence >= confidenceThreshold {
            addSuggestion(suggestion)
        }
    }

    /// Generate time-based suggestions
    public func evaluateTimeBasedSuggestions() {
        guard isEnabled && enabledTypes.contains(.timeBased) else { return }

        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)

        // Morning routine suggestion (8-9 AM)
        if hour >= 8 && hour < 9 {
            if let emailPattern = patterns.first(where: { $0.description.contains("email") && $0.confidence > 0.7 }) {
                let suggestion = SmartSuggestion(
                    type: .routine,
                    title: "Morning email summary?",
                    description: "You usually check emails around this time. Want a summary?",
                    urgency: .medium,
                    action: .sendMessage(prompt: "Please summarize my important emails from today and highlight any that need immediate attention."),
                    confidence: emailPattern.confidence,
                    triggerContext: .init(source: "morning_routine"),
                    expiresAt: calendar.date(byAdding: .hour, value: 2, to: now)
                )
                addSuggestion(suggestion)
            }
        }

        // End of day summary (5-6 PM)
        if hour >= 17 && hour < 18 {
            let suggestion = SmartSuggestion(
                type: .timeBased,
                title: "End of day summary?",
                description: "Would you like me to summarize today's conversations and tasks?",
                urgency: .low,
                action: .sendMessage(prompt: "Please provide a summary of our conversations today, including any action items or follow-ups needed."),
                confidence: 0.6,
                triggerContext: .init(source: "end_of_day"),
                expiresAt: calendar.date(byAdding: .hour, value: 2, to: now)
            )
            addSuggestion(suggestion)
        }
    }

    /// Accept a suggestion
    public func acceptSuggestion(_ suggestion: SmartSuggestion) {
        if let index = activeSuggestions.firstIndex(where: { $0.id == suggestion.id }) {
            activeSuggestions[index].acceptedAt = Date()
            moveToHistory(activeSuggestions.remove(at: index))

            // Record this acceptance for pattern learning
            recordAction(
                type: "suggestion_accepted_\(suggestion.type.rawValue)",
                context: ["title": suggestion.title]
            )
        }
    }

    /// Dismiss a suggestion
    public func dismissSuggestion(_ suggestion: SmartSuggestion, reason: String? = nil) {
        if let index = activeSuggestions.firstIndex(where: { $0.id == suggestion.id }) {
            activeSuggestions[index].dismissedAt = Date()
            moveToHistory(activeSuggestions.remove(at: index))

            // Record this dismissal for pattern learning
            recordAction(
                type: "suggestion_dismissed_\(suggestion.type.rawValue)",
                context: ["title": suggestion.title, "reason": reason ?? "unknown"]
            )
        }
    }

    /// Dismiss all suggestions
    public func dismissAllSuggestions() {
        for suggestion in activeSuggestions {
            dismissSuggestion(suggestion, reason: "bulk_dismiss")
        }
    }

    // MARK: - Private Methods

    private func startMonitoring() {
        // Pattern evaluation every 15 minutes
        patternMonitorTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(900))
                await MainActor.run {
                    self.evaluatePatternsForSuggestions()
                    self.evaluateTimeBasedSuggestions()
                    self.cleanupExpiredSuggestions()
                }
            }
        }
    }

    private func evaluatePatternsForSuggestions() {
        let calendar = Calendar.current
        let now = Date()
        let currentHour = calendar.component(.hour, from: now)
        let currentDayOfWeek = calendar.component(.weekday, from: now)

        for pattern in patterns where pattern.confidence >= confidenceThreshold {
            // Check if current time matches pattern
            let matchesTime = pattern.timeSlots.contains { slot in
                abs(slot.hour - currentHour) <= 1
            }

            let matchesDay = pattern.dayOfWeek?.contains(currentDayOfWeek) ?? true

            if matchesTime && matchesDay {
                // Generate suggestion based on pattern
                let suggestion = SmartSuggestion(
                    type: .routine,
                    title: pattern.description.prefix(50) + "?",
                    description: "Based on your usual routine at this time.",
                    urgency: .low,
                    action: .sendMessage(prompt: pattern.description),
                    confidence: pattern.confidence,
                    triggerContext: .init(source: "pattern_\(pattern.id)"),
                    expiresAt: calendar.date(byAdding: .hour, value: 2, to: now)
                )
                addSuggestion(suggestion)
            }
        }
    }

    private func addSuggestion(_ suggestion: SmartSuggestion) {
        // Check if similar suggestion already exists
        let isDuplicate = activeSuggestions.contains { existing in
            existing.type == suggestion.type &&
            existing.title == suggestion.title &&
            existing.isActive
        }

        guard !isDuplicate else { return }

        activeSuggestions.append(suggestion)

        // Sort by priority and limit count
        activeSuggestions.sort { $0.type.priority > $1.type.priority }
        while activeSuggestions.count > maxSuggestions {
            let removed = activeSuggestions.removeLast()
            moveToHistory(removed)
        }

        logger.info("Added suggestion: \(suggestion.title)")
    }

    private func moveToHistory(_ suggestion: SmartSuggestion) {
        suggestionHistory.append(suggestion)
        if suggestionHistory.count > maxHistorySize {
            suggestionHistory.removeFirst(suggestionHistory.count - maxHistorySize)
        }
        saveSuggestionHistory()
    }

    private func cleanupExpiredSuggestions() {
        activeSuggestions.removeAll { $0.isExpired }
    }

    private func findMatchingPattern(type: String, context _context: [String: String]) -> Int? {
        patterns.firstIndex { pattern in
            pattern.description.lowercased().contains(type.lowercased()) ||
            type.lowercased().contains(pattern.description.lowercased())
        }
    }

    // MARK: - Persistence

    private func loadPatterns() {
        if let data = UserDefaults.standard.data(forKey: "thea.proactive.patterns"),
           let decoded = try? JSONDecoder().decode([LearnedUserPattern].self, from: data) {
            patterns = decoded
        }
    }

    private func savePatterns() {
        if let encoded = try? JSONEncoder().encode(patterns) {
            UserDefaults.standard.set(encoded, forKey: "thea.proactive.patterns")
        }
    }

    private func loadPreferences() {
        isEnabled = UserDefaults.standard.bool(forKey: "thea.proactive.enabled")
        if isEnabled == false && !UserDefaults.standard.bool(forKey: "thea.proactive.initialized") {
            isEnabled = true  // Default to enabled
            UserDefaults.standard.set(true, forKey: "thea.proactive.initialized")
        }
        confidenceThreshold = UserDefaults.standard.double(forKey: "thea.proactive.threshold")
        if confidenceThreshold == 0 { confidenceThreshold = 0.6 }
        maxSuggestions = UserDefaults.standard.integer(forKey: "thea.proactive.maxSuggestions")
        if maxSuggestions == 0 { maxSuggestions = 3 }
    }

    private func savePreferences() {
        UserDefaults.standard.set(isEnabled, forKey: "thea.proactive.enabled")
        UserDefaults.standard.set(confidenceThreshold, forKey: "thea.proactive.threshold")
        UserDefaults.standard.set(maxSuggestions, forKey: "thea.proactive.maxSuggestions")
    }

    private func loadSuggestionHistory() {
        if let data = UserDefaults.standard.data(forKey: "thea.proactive.history"),
           let decoded = try? JSONDecoder().decode([SmartSuggestion].self, from: data) {
            suggestionHistory = decoded
        }
    }

    private func saveSuggestionHistory() {
        if let encoded = try? JSONEncoder().encode(suggestionHistory) {
            UserDefaults.standard.set(encoded, forKey: "thea.proactive.history")
        }
    }
}

// MARK: - Proactive Suggestion Card View

/// UI component for displaying a proactive suggestion
public struct SmartSuggestionCard: View {
    let suggestion: SmartSuggestion
    let onAccept: () -> Void
    let onDismiss: () -> Void

    @State private var isHovered = false

    public var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: suggestion.type.icon)
                .font(.system(size: 20))
                .foregroundStyle(suggestion.urgency.displayColor)
                .frame(width: 32)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(suggestion.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            // Actions
            HStack(spacing: 8) {
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Button {
                    onAccept()
                } label: {
                    Text("Go")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(suggestion.urgency.displayColor.opacity(0.3), lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Proactive Suggestions List View

/// Container view for showing all active suggestions
public struct SmartSuggestionsView: View {
    @ObservedObject var engine = SmartSuggestionEngine.shared
    let onExecuteAction: (SmartSuggestion.SuggestionAction) -> Void

    public init(onExecuteAction: @escaping (SmartSuggestion.SuggestionAction) -> Void) {
        self.onExecuteAction = onExecuteAction
    }

    public var body: some View {
        if !engine.activeSuggestions.isEmpty && engine.isEnabled {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    TheaSpiralIconView(size: 16, isThinking: false, showGlow: false)
                    Text("Suggestions")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Dismiss All") {
                        engine.dismissAllSuggestions()
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)

                ForEach(engine.activeSuggestions) { suggestion in
                    SmartSuggestionCard(
                        suggestion: suggestion,
                        onAccept: {
                            engine.acceptSuggestion(suggestion)
                            onExecuteAction(suggestion.action)
                        },
                        onDismiss: {
                            engine.dismissSuggestion(suggestion)
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
                }
            }
            .padding()
            .animation(.spring(response: 0.4), value: engine.activeSuggestions.count)
        }
    }
}
