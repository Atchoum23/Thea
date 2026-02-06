// ContextAggregator.swift
// Thea V2 - Omni-AI Context Aggregation System
//
// Single source of truth for decision context. Aggregates all signals
// (device state, user context, patterns, resources) for informed AI decisions.
//
// Intelligence Upgrade (2026):
// - Context change detection with significance scoring
// - Outcome correlation to learn from context-outcome pairs
// - Predictive context suggestions
// - Context similarity for pattern matching

import Foundation
import os.log

// MARK: - Context Aggregator

/// THEA's unified context system - aggregates all signals for intelligent decisions
/// Features: change detection, outcome correlation, predictive suggestions
@MainActor
public final class ContextAggregator: ObservableObject {
    public static let shared = ContextAggregator()

    private let logger = Logger(subsystem: "ai.thea.app", category: "Context")

    // MARK: - Published State

    @Published public private(set) var currentContext = AggregatedContext()
    @Published public private(set) var lastUpdate: Date = .distantPast
    @Published public private(set) var recentChanges: [AggregatedContextChange] = []
    @Published public private(set) var contextTrends = ContextTrends()

    // MARK: - Configuration

    public var autoRefreshInterval: TimeInterval = 10
    public var includeSensitiveData = false

    /// Enable context change detection and notification
    public var enableChangeDetection: Bool = true

    /// Minimum significance score for a change to be reported
    public var changeSignificanceThreshold: Double = 0.3

    /// Enable outcome correlation learning
    public var enableOutcomeCorrelation: Bool = true

    // MARK: - Internal

    private var refreshTimer: Timer?
    private var contextHistory: [AggregatedContext] = []
    private let maxHistorySize = 50

    /// Context-outcome correlation data
    private var outcomeCorrelations: [ContextOutcomeCorrelation] = []
    private let maxCorrelations = 500

    /// Change listeners
    private var changeListeners: [(AggregatedContextChange) -> Void] = []

    private init() {
        startAutoRefresh()
        loadOutcomeCorrelations()
        logger.info("ContextAggregator initialized")
    }

    // MARK: - Change Detection

    /// Detect significant changes between two contexts
    public func detectChanges(from old: AggregatedContext, to new: AggregatedContext) -> [AggregatedContextChange] {
        var changes: [AggregatedContextChange] = []

        // Device changes
        if old.device.batteryLevel != new.device.batteryLevel {
            let oldLevel = old.device.batteryLevel ?? 100
            let newLevel = new.device.batteryLevel ?? 100
            let delta = abs(newLevel - oldLevel)
            if delta >= 5 { // Only report 5%+ changes
                let significance = Double(delta) / 100.0
                changes.append(AggregatedContextChange(
                    category: .device,
                    field: "batteryLevel",
                    oldValue: "\(oldLevel)%",
                    newValue: "\(newLevel)%",
                    significance: significance,
                    recommendation: newLevel < 20 ? "Consider switching to local models to save battery" : nil
                ))
            }
        }

        if old.device.networkStatus != new.device.networkStatus {
            let significance: Double = new.device.networkStatus == .disconnected ? 0.9 : 0.6
            changes.append(AggregatedContextChange(
                category: .device,
                field: "networkStatus",
                oldValue: old.device.networkStatus.rawValue,
                newValue: new.device.networkStatus.rawValue,
                significance: significance,
                recommendation: new.device.networkStatus == .disconnected ?
                    "Network disconnected - using local models only" : nil
            ))
        }

        if old.device.thermalState != new.device.thermalState {
            let significance: Double = new.device.thermalState == .critical ? 0.95 : 0.5
            changes.append(AggregatedContextChange(
                category: .device,
                field: "thermalState",
                oldValue: old.device.thermalState.rawValue,
                newValue: new.device.thermalState.rawValue,
                significance: significance,
                recommendation: new.device.thermalState == .critical ?
                    "Device is hot - reducing AI workload" : nil
            ))
        }

        // Temporal changes
        if old.temporal.isWorkingHours != new.temporal.isWorkingHours {
            changes.append(AggregatedContextChange(
                category: .temporal,
                field: "isWorkingHours",
                oldValue: old.temporal.isWorkingHours ? "working" : "personal",
                newValue: new.temporal.isWorkingHours ? "working" : "personal",
                significance: 0.4,
                recommendation: new.temporal.isWorkingHours ?
                    "Work hours started - prioritizing productivity tasks" :
                    "Personal time - more creative and exploratory responses"
            ))
        }

        if old.temporal.isWeekend != new.temporal.isWeekend {
            changes.append(AggregatedContextChange(
                category: .temporal,
                field: "isWeekend",
                oldValue: old.temporal.isWeekend ? "weekend" : "weekday",
                newValue: new.temporal.isWeekend ? "weekend" : "weekday",
                significance: 0.3,
                recommendation: nil
            ))
        }

        // AI Resource changes
        if old.aiResources.localModelCount != new.aiResources.localModelCount {
            let significance = new.aiResources.localModelCount == 0 ? 0.8 : 0.4
            changes.append(AggregatedContextChange(
                category: .aiResources,
                field: "localModelCount",
                oldValue: "\(old.aiResources.localModelCount)",
                newValue: "\(new.aiResources.localModelCount)",
                significance: significance,
                recommendation: new.aiResources.localModelCount > 0 ?
                    "Local models available for private processing" : nil
            ))
        }

        // User activity changes
        if old.user.currentActivity != new.user.currentActivity {
            if let newActivity = new.user.currentActivity, !newActivity.isEmpty {
                changes.append(AggregatedContextChange(
                    category: .user,
                    field: "currentActivity",
                    oldValue: old.user.currentActivity ?? "none",
                    newValue: newActivity,
                    significance: 0.5,
                    recommendation: nil
                ))
            }
        }

        return changes.filter { $0.significance >= changeSignificanceThreshold }
    }

    /// Register a listener for context changes
    public func addChangeListener(_ listener: @escaping (AggregatedContextChange) -> Void) {
        changeListeners.append(listener)
    }

    /// Notify listeners of a context change
    private func notifyChangeListeners(_ change: AggregatedContextChange) {
        for listener in changeListeners {
            listener(change)
        }
    }

    // MARK: - Outcome Correlation

    /// Record a context-outcome pair for learning
    public func recordOutcome(
        context: AggregatedContext,
        query: String,
        taskType: TaskType,
        modelUsed: String,
        success: Bool,
        userSatisfaction: Double? = nil,
        latency: TimeInterval
    ) async {
        guard enableOutcomeCorrelation else { return }

        let correlation = ContextOutcomeCorrelation(
            contextHash: hashContext(context),
            timestamp: Date(),
            query: query,
            taskType: taskType,
            modelUsed: modelUsed,
            success: success,
            userSatisfaction: userSatisfaction,
            latency: latency,
            batteryLevel: context.device.batteryLevel,
            networkStatus: context.device.networkStatus,
            isWorkingHours: context.temporal.isWorkingHours,
            hourOfDay: context.temporal.hourOfDay
        )

        outcomeCorrelations.append(correlation)

        // Prune if needed
        if outcomeCorrelations.count > maxCorrelations {
            outcomeCorrelations.removeFirst(100)
        }

        // Update trends
        await updateTrends()

        // Persist
        saveOutcomeCorrelations()

        logger.debug("Recorded outcome for \(taskType.rawValue): \(success ? "success" : "failure")")
    }

    /// Get success rate for a task type in similar contexts
    public func getSuccessRate(
        taskType: TaskType,
        similarTo context: AggregatedContext
    ) -> (rate: Double, sampleSize: Int) {
        let similar = outcomeCorrelations.filter { correlation in
            correlation.taskType == taskType &&
            abs(correlation.hourOfDay - context.temporal.hourOfDay) <= 2 &&
            correlation.isWorkingHours == context.temporal.isWorkingHours
        }

        guard !similar.isEmpty else {
            return (rate: 0.5, sampleSize: 0) // No data, return neutral
        }

        let successCount = similar.filter(\.success).count
        return (
            rate: Double(successCount) / Double(similar.count),
            sampleSize: similar.count
        )
    }

    /// Get best performing model for a context
    public func getBestModelForContext(
        taskType: TaskType,
        context: AggregatedContext
    ) -> (model: String?, confidence: Double) {
        let similar = outcomeCorrelations.filter { correlation in
            correlation.taskType == taskType &&
            correlation.success
        }

        guard !similar.isEmpty else {
            return (model: nil, confidence: 0)
        }

        // Group by model and calculate success rates
        let byModel = Dictionary(grouping: similar) { $0.modelUsed }
        let modelStats = byModel.mapValues { correlations -> (successes: Int, total: Int, avgLatency: Double) in
            let total = outcomeCorrelations.filter { $0.modelUsed == correlations[0].modelUsed && $0.taskType == taskType }.count
            let avgLatency = correlations.map(\.latency).reduce(0, +) / Double(correlations.count)
            return (correlations.count, total, avgLatency)
        }

        // Find best by success rate
        let best = modelStats.max { a, b in
            let rateA = Double(a.value.successes) / Double(max(1, a.value.total))
            let rateB = Double(b.value.successes) / Double(max(1, b.value.total))
            return rateA < rateB
        }

        if let best = best {
            let rate = Double(best.value.successes) / Double(max(1, best.value.total))
            return (model: best.key, confidence: rate)
        }

        return (model: nil, confidence: 0)
    }

    /// Update context trends from correlation data
    private func updateTrends() async {
        guard !outcomeCorrelations.isEmpty else { return }

        // Calculate hourly success rates
        var hourlyRates: [Int: Double] = [:]
        for hour in 0..<24 {
            let hourCorrelations = outcomeCorrelations.filter { $0.hourOfDay == hour }
            if !hourCorrelations.isEmpty {
                let successRate = Double(hourCorrelations.filter(\.success).count) / Double(hourCorrelations.count)
                hourlyRates[hour] = successRate
            }
        }

        // Find best hours
        let bestHours = hourlyRates
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { $0.key }

        // Calculate task type distribution
        let taskDistribution = Dictionary(grouping: outcomeCorrelations) { $0.taskType }
            .mapValues { $0.count }

        // Calculate average latency trend
        let recentCorrelations = outcomeCorrelations.suffix(50)
        let avgLatency = recentCorrelations.isEmpty ? 0 :
            recentCorrelations.map(\.latency).reduce(0, +) / Double(recentCorrelations.count)

        contextTrends = ContextTrends(
            hourlySuccessRates: hourlyRates,
            bestPerformanceHours: Array(bestHours),
            taskTypeDistribution: taskDistribution,
            averageLatency: avgLatency,
            totalInteractions: outcomeCorrelations.count
        )
    }

    /// Hash a context for efficient lookup
    private func hashContext(_ context: AggregatedContext) -> String {
        let components = [
            context.device.networkStatus.rawValue,
            context.temporal.isWorkingHours ? "work" : "personal",
            String(context.temporal.hourOfDay),
            String(context.device.batteryLevel ?? 100),
            context.device.platform
        ]
        return components.joined(separator: "-")
    }

    // MARK: - Predictive Context

    /// Predict likely context needs based on patterns
    public func predictContextNeeds() -> [ContextPrediction] {
        var predictions: [ContextPrediction] = []

        let now = Date()
        let hour = Calendar.current.component(.hour, from: now)

        // Check historical patterns for this hour
        let hourPatterns = outcomeCorrelations.filter { $0.hourOfDay == hour }

        if !hourPatterns.isEmpty {
            // Most common task types at this hour
            let taskCounts = Dictionary(grouping: hourPatterns) { $0.taskType }
                .mapValues { $0.count }
                .sorted { $0.value > $1.value }

            if let topTask = taskCounts.first, topTask.value >= 3 {
                predictions.append(ContextPrediction(
                    prediction: "You often work on \(topTask.key.description) tasks at this time",
                    confidence: min(0.9, Double(topTask.value) / 10.0),
                    suggestedAction: "Pre-load \(topTask.key.rawValue) resources"
                ))
            }
        }

        // Battery predictions
        if let battery = currentContext.device.batteryLevel, battery < 30 {
            predictions.append(ContextPrediction(
                prediction: "Low battery may impact AI performance",
                confidence: 0.8,
                suggestedAction: "Switch to efficient local models"
            ))
        }

        // Working hours predictions
        if currentContext.temporal.isWorkingHours {
            predictions.append(ContextPrediction(
                prediction: "Work hours - optimizing for productivity",
                confidence: 0.7,
                suggestedAction: "Prioritize accuracy over speed"
            ))
        }

        return predictions
    }

    // MARK: - Context Capture

    /// Capture a full context snapshot
    public func captureContext(query: String? = nil, intent: String? = nil) async -> AggregatedContext {
        let startTime = Date()
        let previousContext = currentContext

        let deviceState = await captureDeviceState()
        let userContext = await captureUserContext()
        let aiResources = await captureAIResources()
        let temporalContext = captureTemporalContext()
        let patterns = await captureLearnedPatterns()
        let queryContext = ContextQuery(
            currentQuery: query,
            inferredIntent: intent,
            recentQueries: getRecentQueries()
        )

        let context = AggregatedContext(
            timestamp: startTime,
            device: deviceState,
            user: userContext,
            aiResources: aiResources,
            temporal: temporalContext,
            patterns: patterns,
            query: queryContext
        )

        currentContext = context
        lastUpdate = Date()

        // Detect and report changes
        if enableChangeDetection && !contextHistory.isEmpty {
            let changes = detectChanges(from: previousContext, to: context)
            if !changes.isEmpty {
                recentChanges = changes
                for change in changes {
                    notifyChangeListeners(change)
                    logger.info("Context change: \(change.field) from \(change.oldValue) to \(change.newValue)")
                }
            }
        }

        contextHistory.append(context)
        if contextHistory.count > maxHistorySize {
            contextHistory.removeFirst()
        }

        let captureTime = Date().timeIntervalSince(startTime) * 1000
        logger.debug("Context captured in \(Int(captureTime))ms")

        return context
    }

    /// Convert to MemoryContextSnapshot for use with MemoryManager/ProactivityEngine
    public func toMemorySnapshot(query: String? = nil) -> MemoryContextSnapshot {
        MemoryContextSnapshot(
            userActivity: currentContext.user.currentActivity,
            currentQuery: query ?? currentContext.query.currentQuery,
            location: currentContext.user.approximateLocation,
            timeOfDay: currentContext.temporal.hourOfDay,
            dayOfWeek: currentContext.temporal.dayOfWeek,
            batteryLevel: currentContext.device.batteryLevel,
            isPluggedIn: currentContext.device.isPluggedIn
        )
    }

    // MARK: - Context-Aware Decision Helpers

    /// Recommend model routing weights based on context
    public func recommendRoutingWeights() -> ContextRoutingWeights {
        var quality: Double = 0.5
        var cost: Double = 0.3
        var speed: Double = 0.2

        // Adjust based on battery
        if let battery = currentContext.device.batteryLevel,
           battery < 30 && currentContext.device.isPluggedIn != true {
            speed = 0.4
            cost = 0.4
            quality = 0.2
        }

        // Adjust based on network
        if currentContext.device.networkStatus == .constrained {
            speed = 0.5
            quality = 0.3
            cost = 0.2
        }

        // Adjust based on time of day
        let hour = currentContext.temporal.hourOfDay
        if hour >= 21 || hour <= 6 {
            quality = 0.6
            speed = 0.2
            cost = 0.2
        } else if hour >= 7 && hour <= 9 {
            speed = 0.5
            quality = 0.3
            cost = 0.2
        }

        // Normalize to sum to 1.0
        let total = quality + cost + speed
        return ContextRoutingWeights(
            quality: quality / total,
            cost: cost / total,
            speed: speed / total
        )
    }

    /// Determine if local models should be preferred
    public func shouldPreferLocalModels() -> (prefer: Bool, reason: String) {
        if SettingsManager.shared.preferLocalModels {
            return (true, "User preference")
        }

        if currentContext.device.networkStatus == .disconnected {
            return (true, "No network connection")
        }

        if let battery = currentContext.device.batteryLevel,
           battery < 20 && currentContext.device.isPluggedIn != true {
            return (true, "Low battery - conserving power")
        }

        guard currentContext.aiResources.localModelCount > 0 else {
            return (false, "No local models available")
        }

        return (false, "Cloud models provide better quality")
    }

    // MARK: - Private Capture Methods

    private func captureDeviceState() async -> ContextDeviceState {
        let system = THEASelfAwareness.shared.systemContext

        return ContextDeviceState(
            platform: system.platform,
            batteryLevel: system.batteryLevel,
            isPluggedIn: system.isPluggedIn,
            totalMemoryGB: system.totalMemoryGB,
            availableMemoryGB: system.availableMemoryGB,
            availableStorageGB: system.availableStorageGB,
            thermalState: .nominal,
            networkStatus: .connected,
            hasAppleSilicon: system.hasAppleSilicon,
            hasNeuralEngine: system.hasNeuralEngine
        )
    }

    private func captureUserContext() async -> ContextUserState {
        let user = THEASelfAwareness.shared.userContext
        let responseStylePrefs = await MemoryManager.shared.getPreferences(category: .responseStyle)
        let preferredStyle = responseStylePrefs.max { $0.value < $1.value }?.key

        return ContextUserState(
            userName: user.userName,
            preferredLanguage: user.preferredLanguage,
            interactionCount: user.interactionCount,
            currentActivity: nil,
            approximateLocation: nil,
            preferredResponseStyle: preferredStyle ?? user.preferredResponseStyle,
            workingHoursStart: user.workingHoursStart,
            workingHoursEnd: user.workingHoursEnd
        )
    }

    private func captureAIResources() async -> ContextAIResources {
        let resources = THEASelfAwareness.shared.aiResources

        return ContextAIResources(
            localModelCount: resources.localModelsCount,
            localModelNames: resources.localModelsNames,
            cloudProvidersConfigured: resources.cloudProvidersConfigured,
            preferredProvider: resources.defaultProvider,
            preferredModel: resources.defaultModel,
            orchestratorEnabled: resources.orchestratorEnabled,
            totalModelsAvailable: resources.totalModelsAvailable
        )
    }

    private func captureTemporalContext() -> ContextTemporal {
        let now = Date()
        let calendar = Calendar.current

        return ContextTemporal(
            timestamp: now,
            hourOfDay: calendar.component(.hour, from: now),
            dayOfWeek: calendar.component(.weekday, from: now),
            isWeekend: calendar.isDateInWeekend(now),
            timeZone: TimeZone.current.identifier,
            isWorkingHours: isWithinWorkingHours()
        )
    }

    private func captureLearnedPatterns() async -> ContextPatterns {
        let patterns = await MemoryManager.shared.detectPatterns(windowDays: 14, minOccurrences: 2)
        let modelPrefs = await MemoryManager.shared.getPreferences(category: .modelSelection)
        let preferredModel = modelPrefs.max { $0.value < $1.value }?.key

        return ContextPatterns(
            detectedPatterns: patterns,
            preferredModelByTask: modelPrefs,
            topPreferredModel: preferredModel
        )
    }

    private func getRecentQueries() -> [String] {
        contextHistory.suffix(10).compactMap { $0.query.currentQuery }
    }

    private func isWithinWorkingHours() -> Bool {
        let user = THEASelfAwareness.shared.userContext
        let hour = Calendar.current.component(.hour, from: Date())

        if user.workingHoursStart == 0 && user.workingHoursEnd == 0 {
            return hour >= 9 && hour < 17
        }

        return hour >= user.workingHoursStart && hour < user.workingHoursEnd
    }

    // MARK: - Auto Refresh

    private func startAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: autoRefreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                _ = await self?.captureContext()
            }
        }
    }

    public func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Persistence

    /// URL for storing outcome correlations
    private var correlationsFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let theaDir = appSupport.appendingPathComponent("ai.thea.app", isDirectory: true)
        try? FileManager.default.createDirectory(at: theaDir, withIntermediateDirectories: true)
        return theaDir.appendingPathComponent("context_correlations.json")
    }

    private func loadOutcomeCorrelations() {
        guard FileManager.default.fileExists(atPath: correlationsFileURL.path) else {
            outcomeCorrelations = []
            return
        }

        do {
            let data = try Data(contentsOf: correlationsFileURL)
            outcomeCorrelations = try JSONDecoder().decode([ContextOutcomeCorrelation].self, from: data)
            logger.info("Loaded \(self.outcomeCorrelations.count) context-outcome correlations")

            // Update trends after loading
            Task {
                await updateTrends()
            }
        } catch {
            logger.error("Failed to load correlations: \(error.localizedDescription)")
            outcomeCorrelations = []
        }
    }

    private func saveOutcomeCorrelations() {
        do {
            let data = try JSONEncoder().encode(outcomeCorrelations)
            try data.write(to: correlationsFileURL, options: .atomic)
        } catch {
            logger.error("Failed to save correlations: \(error.localizedDescription)")
        }
    }

    // MARK: - Context Analysis

    /// Get context similarity score between two contexts
    public func contextSimilarity(_ a: AggregatedContext, _ b: AggregatedContext) -> Double {
        var score = 0.0
        var weights = 0.0

        // Temporal similarity (weight: 0.3)
        let temporalWeight = 0.3
        var temporalScore = 0.0
        if a.temporal.isWorkingHours == b.temporal.isWorkingHours { temporalScore += 0.5 }
        if a.temporal.isWeekend == b.temporal.isWeekend { temporalScore += 0.3 }
        if abs(a.temporal.hourOfDay - b.temporal.hourOfDay) <= 2 { temporalScore += 0.2 }
        score += temporalScore * temporalWeight
        weights += temporalWeight

        // Device similarity (weight: 0.2)
        let deviceWeight = 0.2
        var deviceScore = 0.0
        if a.device.networkStatus == b.device.networkStatus { deviceScore += 0.5 }
        if let batA = a.device.batteryLevel, let batB = b.device.batteryLevel {
            let batDiff = abs(batA - batB)
            if batDiff <= 20 { deviceScore += 0.3 }
        }
        if a.device.thermalState == b.device.thermalState { deviceScore += 0.2 }
        score += deviceScore * deviceWeight
        weights += deviceWeight

        // User similarity (weight: 0.2)
        let userWeight = 0.2
        var userScore = 0.0
        if a.user.currentActivity == b.user.currentActivity { userScore += 0.5 }
        if a.user.preferredResponseStyle == b.user.preferredResponseStyle { userScore += 0.5 }
        score += userScore * userWeight
        weights += userWeight

        // AI resources similarity (weight: 0.15)
        let aiWeight = 0.15
        var aiScore = 0.0
        if (a.aiResources.localModelCount > 0) == (b.aiResources.localModelCount > 0) { aiScore += 0.5 }
        if a.aiResources.preferredProvider == b.aiResources.preferredProvider { aiScore += 0.5 }
        score += aiScore * aiWeight
        weights += aiWeight

        // Query similarity (weight: 0.15)
        let queryWeight = 0.15
        var queryScore = 0.0
        if let intentA = a.query.inferredIntent, let intentB = b.query.inferredIntent {
            if intentA == intentB { queryScore += 1.0 }
        }
        score += queryScore * queryWeight
        weights += queryWeight

        return weights > 0 ? score / weights : 0
    }

    /// Find similar historical contexts
    public func findSimilarContexts(to target: AggregatedContext, limit: Int = 5) -> [(AggregatedContext, Double)] {
        contextHistory
            .map { (context: $0, similarity: contextSimilarity($0, target)) }
            .sorted { $0.similarity > $1.similarity }
            .prefix(limit)
            .map { ($0.context, $0.similarity) }
    }
}

// MARK: - Aggregated Context

public struct AggregatedContext: Sendable {
    public var timestamp: Date
    public var device: ContextDeviceState
    public var user: ContextUserState
    public var aiResources: ContextAIResources
    public var temporal: ContextTemporal
    public var patterns: ContextPatterns
    public var query: ContextQuery

    public init(
        timestamp: Date = Date(),
        device: ContextDeviceState = ContextDeviceState(),
        user: ContextUserState = ContextUserState(),
        aiResources: ContextAIResources = ContextAIResources(),
        temporal: ContextTemporal = ContextTemporal(),
        patterns: ContextPatterns = ContextPatterns(),
        query: ContextQuery = ContextQuery()
    ) {
        self.timestamp = timestamp
        self.device = device
        self.user = user
        self.aiResources = aiResources
        self.temporal = temporal
        self.patterns = patterns
        self.query = query
    }
}

// MARK: - Context Components

public struct ContextDeviceState: Sendable {
    public var platform: String
    public var batteryLevel: Int?
    public var isPluggedIn: Bool?
    public var totalMemoryGB: Double
    public var availableMemoryGB: Double
    public var availableStorageGB: Double
    public var thermalState: ContextThermalState
    public var networkStatus: ContextNetworkStatus
    public var hasAppleSilicon: Bool
    public var hasNeuralEngine: Bool

    public init(
        platform: String = "Unknown",
        batteryLevel: Int? = nil,
        isPluggedIn: Bool? = nil,
        totalMemoryGB: Double = 0,
        availableMemoryGB: Double = 0,
        availableStorageGB: Double = 0,
        thermalState: ContextThermalState = .nominal,
        networkStatus: ContextNetworkStatus = .connected,
        hasAppleSilicon: Bool = false,
        hasNeuralEngine: Bool = false
    ) {
        self.platform = platform
        self.batteryLevel = batteryLevel
        self.isPluggedIn = isPluggedIn
        self.totalMemoryGB = totalMemoryGB
        self.availableMemoryGB = availableMemoryGB
        self.availableStorageGB = availableStorageGB
        self.thermalState = thermalState
        self.networkStatus = networkStatus
        self.hasAppleSilicon = hasAppleSilicon
        self.hasNeuralEngine = hasNeuralEngine
    }
}

public struct ContextUserState: Sendable {
    public var userName: String
    public var preferredLanguage: String
    public var interactionCount: Int
    public var currentActivity: String?
    public var approximateLocation: String?
    public var preferredResponseStyle: String
    public var workingHoursStart: Int
    public var workingHoursEnd: Int

    public init(
        userName: String = "User",
        preferredLanguage: String = "en",
        interactionCount: Int = 0,
        currentActivity: String? = nil,
        approximateLocation: String? = nil,
        preferredResponseStyle: String = "balanced",
        workingHoursStart: Int = 9,
        workingHoursEnd: Int = 17
    ) {
        self.userName = userName
        self.preferredLanguage = preferredLanguage
        self.interactionCount = interactionCount
        self.currentActivity = currentActivity
        self.approximateLocation = approximateLocation
        self.preferredResponseStyle = preferredResponseStyle
        self.workingHoursStart = workingHoursStart
        self.workingHoursEnd = workingHoursEnd
    }
}

public struct ContextAIResources: Sendable {
    public var localModelCount: Int
    public var localModelNames: [String]
    public var cloudProvidersConfigured: [String]
    public var preferredProvider: String
    public var preferredModel: String
    public var orchestratorEnabled: Bool
    public var totalModelsAvailable: Int

    public init(
        localModelCount: Int = 0,
        localModelNames: [String] = [],
        cloudProvidersConfigured: [String] = [],
        preferredProvider: String = "",
        preferredModel: String = "",
        orchestratorEnabled: Bool = false,
        totalModelsAvailable: Int = 0
    ) {
        self.localModelCount = localModelCount
        self.localModelNames = localModelNames
        self.cloudProvidersConfigured = cloudProvidersConfigured
        self.preferredProvider = preferredProvider
        self.preferredModel = preferredModel
        self.orchestratorEnabled = orchestratorEnabled
        self.totalModelsAvailable = totalModelsAvailable
    }
}

public struct ContextTemporal: Sendable {
    public var timestamp: Date
    public var hourOfDay: Int
    public var dayOfWeek: Int
    public var isWeekend: Bool
    public var timeZone: String
    public var isWorkingHours: Bool

    public init(
        timestamp: Date = Date(),
        hourOfDay: Int = Calendar.current.component(.hour, from: Date()),
        dayOfWeek: Int = Calendar.current.component(.weekday, from: Date()),
        isWeekend: Bool = Calendar.current.isDateInWeekend(Date()),
        timeZone: String = TimeZone.current.identifier,
        isWorkingHours: Bool = true
    ) {
        self.timestamp = timestamp
        self.hourOfDay = hourOfDay
        self.dayOfWeek = dayOfWeek
        self.isWeekend = isWeekend
        self.timeZone = timeZone
        self.isWorkingHours = isWorkingHours
    }
}

public struct ContextPatterns: Sendable {
    public var detectedPatterns: [MemoryDetectedPattern]
    public var preferredModelByTask: [String: Double]
    public var topPreferredModel: String?

    public init(
        detectedPatterns: [MemoryDetectedPattern] = [],
        preferredModelByTask: [String: Double] = [:],
        topPreferredModel: String? = nil
    ) {
        self.detectedPatterns = detectedPatterns
        self.preferredModelByTask = preferredModelByTask
        self.topPreferredModel = topPreferredModel
    }
}

public struct ContextQuery: Sendable {
    public var currentQuery: String?
    public var inferredIntent: String?
    public var recentQueries: [String]

    public init(
        currentQuery: String? = nil,
        inferredIntent: String? = nil,
        recentQueries: [String] = []
    ) {
        self.currentQuery = currentQuery
        self.inferredIntent = inferredIntent
        self.recentQueries = recentQueries
    }
}

// MARK: - Routing Weights

public struct ContextRoutingWeights: Sendable {
    public var quality: Double
    public var cost: Double
    public var speed: Double

    public var description: String {
        "Q:\(Int(quality*100))% C:\(Int(cost*100))% S:\(Int(speed*100))%"
    }
}

// MARK: - Enums

public enum ContextThermalState: String, Sendable, Codable {
    case nominal
    case fair
    case serious
    case critical
}

public enum ContextNetworkStatus: String, Sendable, Codable {
    case connected
    case constrained
    case disconnected
}

// MARK: - Aggregated Context Change

/// Represents a detected change in aggregated context
public struct AggregatedContextChange: Identifiable, Sendable {
    public let id = UUID()
    public let category: ContextChangeCategory
    public let field: String
    public let oldValue: String
    public let newValue: String
    public let significance: Double // 0-1, how important this change is
    public let recommendation: String?
    public let timestamp: Date

    public init(
        category: ContextChangeCategory,
        field: String,
        oldValue: String,
        newValue: String,
        significance: Double,
        recommendation: String? = nil,
        timestamp: Date = Date()
    ) {
        self.category = category
        self.field = field
        self.oldValue = oldValue
        self.newValue = newValue
        self.significance = significance
        self.recommendation = recommendation
        self.timestamp = timestamp
    }
}

public enum ContextChangeCategory: String, Sendable {
    case device
    case user
    case temporal
    case aiResources
    case query
}

// MARK: - Context Outcome Correlation

/// Correlation between context and task outcome for learning
struct ContextOutcomeCorrelation: Codable, Sendable {
    let contextHash: String
    let timestamp: Date
    let query: String
    let taskType: TaskType
    let modelUsed: String
    let success: Bool
    let userSatisfaction: Double?
    let latency: TimeInterval
    let batteryLevel: Int?
    let networkStatus: ContextNetworkStatus
    let isWorkingHours: Bool
    let hourOfDay: Int
}

// MARK: - Context Trends

/// Trends learned from context-outcome correlations
public struct ContextTrends: Sendable {
    public var hourlySuccessRates: [Int: Double] = [:]
    public var bestPerformanceHours: [Int] = []
    public var taskTypeDistribution: [TaskType: Int] = [:]
    public var averageLatency: TimeInterval = 0
    public var totalInteractions: Int = 0

    public var description: String {
        let bestHours = bestPerformanceHours.map { "\($0):00" }.joined(separator: ", ")
        return "ContextTrends(interactions: \(totalInteractions), avgLatency: \(String(format: "%.1f", averageLatency))s, bestHours: \(bestHours))"
    }
}

// MARK: - Context Prediction

/// A prediction about context needs
public struct ContextPrediction: Identifiable, Sendable {
    public let id = UUID()
    public let prediction: String
    public let confidence: Double
    public let suggestedAction: String?
}
