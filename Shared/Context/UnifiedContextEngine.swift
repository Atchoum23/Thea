import Combine
import Foundation
import os.log

// MARK: - Unified Context Engine

/// Central actor that aggregates all context from various providers into a unified view
@MainActor
public final class UnifiedContextEngine: ObservableObject {
    public static let shared = UnifiedContextEngine()

    // MARK: - Published State

    @Published public private(set) var currentSnapshot: ContextSnapshot
    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var activeProviderCount: Int = 0

    // MARK: - Private Properties

    private let logger = Logger(subsystem: "app.thea", category: "UnifiedContextEngine")
    private var providers: [String: any ContextProvider] = [:]
    private var providerTasks: [String: Task<Void, Never>] = [:]
    private var snapshotHistory: [ContextSnapshot] = []
    private let maxHistoryCount = 100
    private var updateTask: Task<Void, Never>?

    // Configuration
    private var updateInterval: TimeInterval = 1.0
    private var isAggregating = false

    // Callbacks
    private var onSnapshotUpdate: ((ContextSnapshot) -> Void)?
    private var onInsightDetected: ((ContextInsight) -> Void)?

    // MARK: - Initialization

    private init() {
        currentSnapshot = ContextSnapshot()
    }

    // MARK: - Public API

    /// Start the context engine with all registered providers
    public func start() async {
        guard !isRunning else {
            logger.warning("Context engine already running")
            return
        }

        logger.info("Starting Unified Context Engine")
        isRunning = true

        // Register default providers
        await registerDefaultProviders()

        // Start all providers
        for (id, provider) in providers {
            await startProvider(id: id, provider: provider)
        }

        activeProviderCount = providerTasks.count

        // Start periodic snapshot updates
        startPeriodicUpdates()

        logger.info("Context engine started with \(self.providers.count) providers")
    }

    /// Stop the context engine
    public func stop() async {
        guard isRunning else { return }

        logger.info("Stopping Unified Context Engine")

        // Cancel all provider tasks
        for (id, task) in providerTasks {
            task.cancel()
            logger.debug("Stopped provider: \(id)")
        }
        providerTasks.removeAll()

        // Stop all providers
        for provider in providers.values {
            await provider.stop()
        }

        // Cancel update task
        updateTask?.cancel()
        updateTask = nil

        isRunning = false
        activeProviderCount = 0

        logger.info("Context engine stopped")
    }

    /// Register a custom context provider
    public func registerProvider(_ provider: any ContextProvider) async {
        let id = await provider.providerId
        providers[id] = provider

        if isRunning {
            await startProvider(id: id, provider: provider)
            activeProviderCount = providerTasks.count
        }

        logger.info("Registered provider: \(id)")
    }

    /// Unregister a context provider
    public func unregisterProvider(id: String) async {
        providerTasks[id]?.cancel()
        providerTasks.removeValue(forKey: id)

        if let provider = providers.removeValue(forKey: id) {
            await provider.stop()
        }

        activeProviderCount = providerTasks.count
        logger.info("Unregistered provider: \(id)")
    }

    /// Get the current context snapshot
    public func getSnapshot() -> ContextSnapshot {
        currentSnapshot
    }

    /// Capture a fresh context snapshot
    public func captureSnapshot() async -> ContextSnapshot {
        await refresh()
        return currentSnapshot
    }

    /// Get context summary for AI injection
    public func getContextSummary(maxLength: Int = 500) -> String {
        currentSnapshot.summary(maxLength: maxLength)
    }

    /// Get recent context history
    public func getHistory(limit: Int = 10) -> [ContextSnapshot] {
        Array(snapshotHistory.suffix(limit))
    }

    /// Force an immediate context refresh
    public func refresh() async {
        await aggregateContext()
    }

    /// Set callback for snapshot updates
    public func onUpdate(_ callback: @escaping (ContextSnapshot) -> Void) {
        onSnapshotUpdate = callback
    }

    /// Set callback for insight detection
    public func onInsight(_ callback: @escaping (ContextInsight) -> Void) {
        onInsightDetected = callback
    }

    /// Set the update interval
    public func setUpdateInterval(_ interval: TimeInterval) {
        updateInterval = max(0.5, interval)
    }

    // MARK: - Private Methods

    private func registerDefaultProviders() async {
        // Register platform-appropriate providers
        #if os(iOS)
            await registerProvider(LocationContextProvider())
            await registerProvider(DeviceStateContextProvider())
            await registerProvider(HealthContextProvider())
            await registerProvider(FocusContextProvider())
            await registerProvider(CalendarContextProvider())
            await registerProvider(MediaContextProvider())
        #elseif os(macOS)
            await registerProvider(LocationContextProvider())
            await registerProvider(DeviceStateContextProvider())
            await registerProvider(AppActivityContextProvider())
            await registerProvider(CalendarContextProvider())
            await registerProvider(ClipboardContextProvider())
            await registerProvider(MediaContextProvider())
        #elseif os(watchOS)
            await registerProvider(HealthContextProvider())
            await registerProvider(DeviceStateContextProvider())
        #endif

        // Common providers
        await registerProvider(EnvironmentContextProvider())
    }

    private func startProvider(id: String, provider: any ContextProvider) async {
        // Check permission if required
        let requiresPermission = await provider.requiresPermission
        if requiresPermission {
            let hasPermission = await provider.hasPermission
            if !hasPermission {
                logger.warning("Provider \(id) requires permission but doesn't have it")
                return
            }
        }

        // Start the provider
        do {
            try await provider.start()
        } catch {
            logger.error("Failed to start provider \(id): \(error.localizedDescription)")
            return
        }

        // Create task to listen for updates
        let task = Task { [weak self] in
            let updates = await provider.updates
            for await update in updates {
                guard !Task.isCancelled else { break }
                await self?.handleUpdate(update)
            }
        }

        providerTasks[id] = task
    }

    private func handleUpdate(_ update: ContextUpdate) async {
        // Apply update to current snapshot
        var snapshot = currentSnapshot

        switch update.updateType {
        case let .location(context):
            snapshot.location = context
        case let .appActivity(context):
            snapshot.appActivity = context
        case let .health(context):
            snapshot.health = context
        case let .calendar(context):
            snapshot.calendar = context
        case let .communication(context):
            snapshot.communication = context
        case let .clipboard(context):
            snapshot.clipboard = context
        case let .focus(context):
            snapshot.focus = context
        case let .deviceState(context):
            snapshot.deviceState = context
        case let .media(context):
            snapshot.media = context
        case let .environment(context):
            snapshot.environment = context
        }

        // Update the current snapshot
        currentSnapshot = ContextSnapshot(
            id: snapshot.id,
            timestamp: Date(),
            location: snapshot.location,
            appActivity: snapshot.appActivity,
            health: snapshot.health,
            calendar: snapshot.calendar,
            communication: snapshot.communication,
            clipboard: snapshot.clipboard,
            focus: snapshot.focus,
            deviceState: snapshot.deviceState,
            media: snapshot.media,
            environment: snapshot.environment
        )

        // High priority updates trigger immediate analysis
        if update.priority >= .high {
            await analyzeForInsights()
        }
    }

    private func startPeriodicUpdates() {
        updateTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(self?.updateInterval ?? 1.0))
                } catch {
                    break // Task cancelled — stop periodic updates
                }
                guard !Task.isCancelled else { break }
                await self?.aggregateContext()
            }
        }
    }

    private func aggregateContext() async {
        guard !isAggregating else { return }
        isAggregating = true
        defer { isAggregating = false }

        // Collect current context from all providers
        var updates: [ContextUpdate] = []
        for provider in providers.values {
            if let update = await provider.getCurrentContext() {
                updates.append(update)
            }
        }

        // Apply all updates
        for update in updates {
            await handleUpdate(update)
        }

        // Add to history
        addToHistory(currentSnapshot)

        // Notify callback
        onSnapshotUpdate?(currentSnapshot)

        // Analyze for insights
        await analyzeForInsights()
    }

    private func addToHistory(_ snapshot: ContextSnapshot) {
        snapshotHistory.append(snapshot)
        if snapshotHistory.count > maxHistoryCount {
            snapshotHistory.removeFirst(snapshotHistory.count - maxHistoryCount)
        }
    }

    private func analyzeForInsights() async {
        // Detect patterns and generate insights
        let insights = await ContextInsightEngine.shared.analyze(
            currentSnapshot: currentSnapshot,
            history: snapshotHistory
        )

        for insight in insights {
            onInsightDetected?(insight)
        }
    }
}

// MARK: - Context Insight

/// Represents a proactive insight generated from context analysis
public struct ContextInsight: Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let type: InsightType
    public let title: String
    public let message: String
    public let priority: Priority
    public let actionable: Bool
    public let suggestedAction: SuggestedAction?

    public enum InsightType: String, Sendable {
        case reminder
        case suggestion
        case warning
        case opportunity
        case pattern
        case anomaly
    }

    public enum Priority: Int, Sendable {
        case low = 0
        case normal = 1
        case high = 2
        case urgent = 3
    }

    public struct SuggestedAction: Sendable {
        public let title: String
        public let actionId: String
        public let parameters: [String: String]

        public init(title: String, actionId: String, parameters: [String: String] = [:]) {
            self.title = title
            self.actionId = actionId
            self.parameters = parameters
        }
    }

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        type: InsightType,
        title: String,
        message: String,
        priority: Priority = .normal,
        actionable: Bool = false,
        suggestedAction: SuggestedAction? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.title = title
        self.message = message
        self.priority = priority
        self.actionable = actionable
        self.suggestedAction = suggestedAction
    }
}

// MARK: - Insight Engine

/// Analyzes context to generate proactive insights
public actor ContextInsightEngine {
    public static let shared = ContextInsightEngine()

    private var patterns: [String: PatternData] = [:]
    private var lastInsightTime: [String: Date] = [:]
    private let minimumInsightInterval: TimeInterval = 300 // 5 minutes

    private init() {}

    public func analyze(currentSnapshot: ContextSnapshot, history _: [ContextSnapshot]) async -> [ContextInsight] {
        var insights: [ContextInsight] = []

        // Check for various insight opportunities
        if let batteryInsight = checkBatteryInsight(currentSnapshot) {
            insights.append(batteryInsight)
        }

        if let calendarInsight = checkCalendarInsight(currentSnapshot) {
            insights.append(calendarInsight)
        }

        if let healthInsight = checkHealthInsight(currentSnapshot) {
            insights.append(healthInsight)
        }

        if let focusInsight = checkFocusInsight(currentSnapshot) {
            insights.append(focusInsight)
        }

        // Filter out recently shown insights
        return insights.filter { insight in
            guard let lastTime = lastInsightTime[insight.type.rawValue] else {
                lastInsightTime[insight.type.rawValue] = Date()
                return true
            }
            if Date().timeIntervalSince(lastTime) > minimumInsightInterval {
                lastInsightTime[insight.type.rawValue] = Date()
                return true
            }
            return false
        }
    }

    private func checkBatteryInsight(_ snapshot: ContextSnapshot) -> ContextInsight? {
        guard let deviceState = snapshot.deviceState else { return nil }

        if deviceState.batteryLevel < 0.2, deviceState.batteryState == .unplugged {
            return ContextInsight(
                type: .warning,
                title: "Low Battery",
                message: "Your battery is at \(Int(deviceState.batteryLevel * 100))%. Consider charging soon.",
                priority: .high,
                actionable: true,
                suggestedAction: .init(title: "Enable Low Power Mode", actionId: "enableLowPowerMode")
            )
        }
        return nil
    }

    private func checkCalendarInsight(_ snapshot: ContextSnapshot) -> ContextInsight? {
        guard let calendar = snapshot.calendar,
              let nextEvent = calendar.upcomingEvents.first else { return nil }

        let timeUntilEvent = nextEvent.startDate.timeIntervalSinceNow

        if timeUntilEvent > 0, timeUntilEvent < 600 { // Within 10 minutes
            return ContextInsight(
                type: .reminder,
                title: "Upcoming Event",
                message: "\(nextEvent.title) starts in \(Int(timeUntilEvent / 60)) minutes",
                priority: .high,
                actionable: nextEvent.hasVideoCall,
                suggestedAction: nextEvent.hasVideoCall ? .init(title: "Join Call", actionId: "joinVideoCall", parameters: ["eventId": nextEvent.id]) : nil
            )
        }
        return nil
    }

    private func checkHealthInsight(_ snapshot: ContextSnapshot) -> ContextInsight? {
        guard let health = snapshot.health else { return nil }

        if let heartRate = health.heartRate, heartRate > 100 {
            if let activity = health.activityLevel, activity == .sedentary {
                return ContextInsight(
                    type: .suggestion,
                    title: "Elevated Heart Rate",
                    message: "Your heart rate is \(Int(heartRate)) bpm while sedentary. Consider taking a break.",
                    priority: .normal,
                    actionable: true,
                    suggestedAction: .init(title: "Start Breathing Exercise", actionId: "startBreathingExercise")
                )
            }
        }
        return nil
    }

    private func checkFocusInsight(_ snapshot: ContextSnapshot) -> ContextInsight? {
        guard let focus = snapshot.focus,
              let calendar = snapshot.calendar else { return nil }

        // Suggest focus mode if busy
        if !focus.isActive, calendar.busyLevel == .busy {
            return ContextInsight(
                type: .suggestion,
                title: "Enable Focus Mode",
                message: "You have a busy schedule. Would you like to enable Focus mode?",
                priority: .normal,
                actionable: true,
                suggestedAction: .init(title: "Enable Do Not Disturb", actionId: "enableFocusMode", parameters: ["mode": "doNotDisturb"])
            )
        }
        return nil
    }
}

// MARK: - Pattern Data

private struct PatternData {
    var occurrences: Int = 0
    var lastOccurrence: Date?
    var averageInterval: TimeInterval?
}
