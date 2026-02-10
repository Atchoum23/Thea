//
//  ActionTracker.swift
//  Thea
//
//  Real-time user action tracking for context inference
//  Tracks editor, terminal, browser, clipboard, and app actions
//  Enables Windsurf-style proactive suggestions
//

import Foundation
import os.log

// MARK: - Action Types

/// Types of user actions that can be tracked
public enum TrackedActionType: String, Codable, Sendable {
    // Editor actions
    case editorOpen
    case editorClose
    case editorSave
    case editorCursorMove
    case editorSelection
    case editorEdit
    case editorFind
    case editorReplace
    case editorGoToDefinition
    case editorFindReferences

    // Terminal actions
    case terminalCommand
    case terminalOutput
    case terminalError
    case terminalClear

    // Browser actions
    case browserNavigate
    case browserSearch
    case browserBookmark
    case browserTabOpen
    case browserTabClose
    case browserFormFill

    // Clipboard actions
    case clipboardCopy
    case clipboardPaste
    case clipboardCut

    // App actions
    case appSwitch
    case appLaunch
    case appQuit
    case appFocusGain
    case appFocusLose

    // File actions
    case fileCreate
    case fileDelete
    case fileRename
    case fileMove
    case fileOpen

    // System actions
    case screenshotTaken
    case notificationReceived
    case systemIdle
    case systemActive
}

/// A single tracked user action
public struct TrackedAction: Identifiable, Codable, Sendable {
    public let id: UUID
    public let type: TrackedActionType
    public let timestamp: Date
    public let context: ActionContext
    public let metadata: [String: String]

    public init(
        id: UUID = UUID(),
        type: TrackedActionType,
        timestamp: Date = Date(),
        context: ActionContext,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.type = type
        self.timestamp = timestamp
        self.context = context
        self.metadata = metadata
    }
}

/// Context for an action
public struct ActionContext: Codable, Sendable {
    public let application: String?
    public let filePath: String?
    public let url: String?
    public let content: String?
    public let position: ActionPosition?

    public init(
        application: String? = nil,
        filePath: String? = nil,
        url: String? = nil,
        content: String? = nil,
        position: ActionPosition? = nil
    ) {
        self.application = application
        self.filePath = filePath
        self.url = url
        self.content = content
        self.position = position
    }
}

/// Position in a file or document
public struct ActionPosition: Codable, Sendable {
    public let line: Int
    public let column: Int
    public let offset: Int?

    public init(line: Int, column: Int, offset: Int? = nil) {
        self.line = line
        self.column = column
        self.offset = offset
    }
}

// MARK: - Action Stream

/// Stream of tracked actions
public typealias ActionStream = AsyncStream<TrackedAction>

// MARK: - Action Tracker

/// Tracks real-time user actions for context inference
/// Core component of Windsurf-style action awareness
public actor ActionTracker {
    public static let shared = ActionTracker()

    private let logger = Logger(subsystem: "ai.thea.app", category: "ActionTracker")

    // MARK: - State

    private var isTracking = false
    private var recentActions: [TrackedAction] = []
    private let maxRecentActions = 1000

    // Action stream for real-time subscribers
    private var streamContinuation: AsyncStream<TrackedAction>.Continuation?

    // Action patterns for proactive suggestions
    private var actionPatterns: [ActionPattern] = []

    // Observers for specific action types
    private var actionObservers: [TrackedActionType: [(TrackedAction) async -> Void]] = [:]

    // Statistics
    private var actionCounts: [TrackedActionType: Int] = [:]
    private var trackingStartTime: Date?

    private init() {}

    // MARK: - Lifecycle

    /// Start tracking user actions
    public func startTracking() async {
        guard !isTracking else { return }

        isTracking = true
        trackingStartTime = Date()
        logger.info("Action tracking started")
    }

    /// Stop tracking user actions
    public func stopTracking() async {
        guard isTracking else { return }

        isTracking = false
        streamContinuation?.finish()
        streamContinuation = nil
        logger.info("Action tracking stopped")
    }

    /// Check if tracking is active
    public func isActive() -> Bool {
        isTracking
    }

    // MARK: - Action Recording

    /// Record a user action
    public func recordAction(_ action: TrackedAction) async {
        guard isTracking else { return }

        // Add to recent actions
        recentActions.append(action)
        if recentActions.count > maxRecentActions {
            recentActions.removeFirst(recentActions.count - maxRecentActions)
        }

        // Update statistics
        actionCounts[action.type, default: 0] += 1

        // Notify stream subscribers
        streamContinuation?.yield(action)

        // Notify type-specific observers
        if let observers = actionObservers[action.type] {
            for observer in observers {
                await observer(action)
            }
        }

        // Check for patterns
        await detectPatterns(with: action)

        logger.debug("Recorded action: \(action.type.rawValue)")
    }

    /// Convenience method to record an action with basic parameters
    public func record(
        type: TrackedActionType,
        application: String? = nil,
        filePath: String? = nil,
        url: String? = nil,
        content: String? = nil,
        metadata: [String: String] = [:]
    ) async {
        let context = ActionContext(
            application: application,
            filePath: filePath,
            url: url,
            content: content?.prefix(500).description  // Limit content size
        )

        let action = TrackedAction(
            type: type,
            context: context,
            metadata: metadata
        )

        await recordAction(action)
    }

    // MARK: - Action Stream

    /// Get a stream of real-time actions
    nonisolated public func actionStream() -> ActionStream {
        AsyncStream { continuation in
            Task { [weak self] in
                await self?.setStreamContinuation(continuation)
            }
        }
    }

    private func setStreamContinuation(_ continuation: AsyncStream<TrackedAction>.Continuation) {
        // Cancel previous continuation if any
        streamContinuation?.finish()
        streamContinuation = continuation

        continuation.onTermination = { [weak self] _ in
            Task {
                await self?.clearStreamContinuation()
            }
        }
    }

    private func clearStreamContinuation() {
        streamContinuation = nil
    }

    // MARK: - Observers

    /// Add an observer for a specific action type
    public func addObserver(
        for type: TrackedActionType,
        handler: @escaping (TrackedAction) async -> Void
    ) {
        if actionObservers[type] == nil {
            actionObservers[type] = []
        }
        actionObservers[type]?.append(handler)
    }

    /// Remove all observers for a specific action type
    public func removeObservers(for type: TrackedActionType) {
        actionObservers.removeValue(forKey: type)
    }

    // MARK: - Query Methods

    /// Get recent actions
    public func getRecentActions(limit: Int = 100) -> [TrackedAction] {
        Array(recentActions.suffix(limit))
    }

    /// Get recent actions of a specific type
    public func getRecentActions(ofType type: TrackedActionType, limit: Int = 50) -> [TrackedAction] {
        recentActions.filter { $0.type == type }.suffix(limit).map { $0 }
    }

    /// Get actions in a time range
    public func getActions(from startDate: Date, to endDate: Date = Date()) -> [TrackedAction] {
        recentActions.filter { $0.timestamp >= startDate && $0.timestamp <= endDate }
    }

    /// Get actions for a specific application
    public func getActions(forApplication app: String, limit: Int = 50) -> [TrackedAction] {
        recentActions.filter { $0.context.application == app }.suffix(limit).map { $0 }
    }

    /// Get actions for a specific file
    public func getActions(forFile filePath: String, limit: Int = 50) -> [TrackedAction] {
        recentActions.filter { $0.context.filePath == filePath }.suffix(limit).map { $0 }
    }

    /// Get action count statistics
    public func getActionCounts() -> [TrackedActionType: Int] {
        actionCounts
    }

    /// Get the most frequent action types
    public func getMostFrequentActions(limit: Int = 10) -> [(type: TrackedActionType, count: Int)] {
        actionCounts
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { (type: $0.key, count: $0.value) }
    }

    // MARK: - Context Analysis

    /// Get the current working context based on recent actions
    public func getCurrentContext() -> WorkingContext {
        let recentWindow = recentActions.suffix(20)

        // Determine current application
        let currentApp = recentWindow
            .last { $0.context.application != nil }?
            .context.application

        // Determine current file
        let currentFile = recentWindow
            .last { $0.context.filePath != nil }?
            .context.filePath

        // Determine current URL
        let currentURL = recentWindow
            .last { $0.context.url != nil }?
            .context.url

        // Detect activity type
        let activityType = detectTrackedActivityType(from: recentWindow)

        return WorkingContext(
            application: currentApp,
            filePath: currentFile,
            url: currentURL,
            activityType: activityType,
            recentActionTypes: recentWindow.map(\.type)
        )
    }

    /// Detect the type of activity based on recent actions
    private func detectTrackedActivityType(from actions: ArraySlice<TrackedAction>) -> TrackedActivityType {
        let types = actions.map(\.type)

        // Count action categories
        let editorCount = types.filter {
            [.editorOpen, .editorEdit, .editorSave, .editorCursorMove, .editorSelection].contains($0)
        }.count

        let terminalCount = types.filter {
            [.terminalCommand, .terminalOutput, .terminalError].contains($0)
        }.count

        let browserCount = types.filter {
            [.browserNavigate, .browserSearch, .browserTabOpen].contains($0)
        }.count

        // Determine primary activity
        let maxCount = max(editorCount, terminalCount, browserCount)

        if maxCount == 0 {
            return .idle
        } else if editorCount == maxCount {
            return .coding
        } else if terminalCount == maxCount {
            return .terminal
        } else if browserCount == maxCount {
            return .browsing
        }

        return .general
    }

    // MARK: - Pattern Detection

    /// Register an action pattern to detect
    public func registerPattern(_ pattern: ActionPattern) {
        actionPatterns.append(pattern)
        logger.debug("Registered pattern: \(pattern.name)")
    }

    /// Check if recent actions match any patterns
    private func detectPatterns(with newAction: TrackedAction) async {
        let recentWindow = Array(recentActions.suffix(10))

        for pattern in actionPatterns {
            if pattern.matches(actions: recentWindow) {
                logger.info("Pattern detected: \(pattern.name)")
                await pattern.onMatch?(recentWindow)
            }
        }
    }

    // MARK: - Clear Data

    /// Clear all recent actions
    public func clearRecentActions() {
        recentActions.removeAll()
        logger.info("Cleared recent actions")
    }

    /// Clear statistics
    public func clearStatistics() {
        actionCounts.removeAll()
        trackingStartTime = Date()
        logger.info("Cleared statistics")
    }
}

// MARK: - Supporting Types

/// Current working context inferred from actions
public struct WorkingContext: Sendable {
    public let application: String?
    public let filePath: String?
    public let url: String?
    public let activityType: TrackedActivityType
    public let recentActionTypes: [TrackedActionType]

    public var isIdle: Bool {
        activityType == .idle
    }

    public var isCoding: Bool {
        activityType == .coding
    }

    public var isBrowsing: Bool {
        activityType == .browsing
    }
}

/// Types of detected activities
public enum TrackedActivityType: String, Codable, Sendable {
    case coding
    case terminal
    case browsing
    case reading
    case writing
    case general
    case idle
}

/// A pattern of actions to detect
public struct ActionPattern: Sendable {
    public let name: String
    public let description: String
    public let actionSequence: [TrackedActionType]
    public let timeWindowSeconds: TimeInterval
    public let onMatch: (@Sendable ([TrackedAction]) async -> Void)?

    public init(
        name: String,
        description: String,
        actionSequence: [TrackedActionType],
        timeWindowSeconds: TimeInterval = 60,
        onMatch: (@Sendable ([TrackedAction]) async -> Void)? = nil
    ) {
        self.name = name
        self.description = description
        self.actionSequence = actionSequence
        self.timeWindowSeconds = timeWindowSeconds
        self.onMatch = onMatch
    }

    /// Check if a sequence of actions matches this pattern
    func matches(actions: [TrackedAction]) -> Bool {
        guard !actionSequence.isEmpty, actions.count >= actionSequence.count else {
            return false
        }

        // Check time window
        guard let first = actions.first, let last = actions.last else {
            return false
        }

        let timeSpan = last.timestamp.timeIntervalSince(first.timestamp)
        guard timeSpan <= timeWindowSeconds else {
            return false
        }

        // Check if action sequence is present in order
        let actionTypes = actions.map(\.type)
        var sequenceIndex = 0

        for actionType in actionTypes {
            if actionType == actionSequence[sequenceIndex] {
                sequenceIndex += 1
                if sequenceIndex == actionSequence.count {
                    return true
                }
            }
        }

        return false
    }
}

// MARK: - Common Patterns

extension ActionPattern {
    /// Pattern: Copy-paste workflow (copy, switch app, paste)
    public static let copyPaste = ActionPattern(
        name: "copy-paste",
        description: "User copied something and is about to paste",
        actionSequence: [.clipboardCopy, .appSwitch]
    )

    /// Pattern: Search and navigate (browser search, navigate)
    public static let searchNavigate = ActionPattern(
        name: "search-navigate",
        description: "User searched and navigated to result",
        actionSequence: [.browserSearch, .browserNavigate]
    )

    /// Pattern: Edit and save (multiple edits, then save)
    public static let editSave = ActionPattern(
        name: "edit-save",
        description: "User edited and saved a file",
        actionSequence: [.editorEdit, .editorEdit, .editorSave]
    )

    /// Pattern: Error investigation (terminal error, browser search)
    public static let errorInvestigation = ActionPattern(
        name: "error-investigation",
        description: "User encountered error and is searching for solution",
        actionSequence: [.terminalError, .browserSearch]
    )

    /// Pattern: Code lookup (go to definition, find references)
    public static let codeLookup = ActionPattern(
        name: "code-lookup",
        description: "User is investigating code structure",
        actionSequence: [.editorGoToDefinition, .editorFindReferences]
    )
}

// MARK: - Integration with LifeMonitoring

extension ActionTracker {
    /// Connect to LifeMonitoring system for automatic action tracking
    public func connectToLifeMonitoring() async {
        // This will be implemented to observe LifeMonitoringCoordinator events
        // and convert them to TrackedActions automatically
        logger.info("Connected to LifeMonitoring system")
    }
}
