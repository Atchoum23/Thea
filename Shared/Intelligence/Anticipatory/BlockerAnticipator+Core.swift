// BlockerAnticipator+Core.swift
// Thea
//
// BlockerAnticipator class implementation.

import Foundation
import Observation
import os.log

private let blockerLogger = Logger(subsystem: "ai.thea.app", category: "BlockerAnticipator")

// MARK: - Blocker Anticipator

@MainActor
@Observable
public final class BlockerAnticipator {
    public static let shared = BlockerAnticipator()

    // MARK: - State

    private(set) var activeBlockers: [DetectedBlocker] = []
    private(set) var recentSignals: [BlockerSignal] = []
    private(set) var currentTask: TaskTracker?
    private(set) var isMonitoring = false

    // MARK: - Thresholds

    private let taskDurationThreshold: TimeInterval = 300 // 5 minutes
    private let queryRepetitionThreshold = 3
    private let errorThreshold = 2
    private let idleThreshold: TimeInterval = 120 // 2 minutes after error
    private let signalWindowSeconds: TimeInterval = 600 // 10 minute window

    // MARK: - History

    private var queryHistory: [(query: String, timestamp: Date)] = []
    private var errorHistory: [(error: String, timestamp: Date)] = []
    private var resolvedBlockers: [DetectedBlocker] = []

    // MARK: - Initialization

    private init() {
        blockerLogger.info("🚧 BlockerAnticipator initializing...")
        startMonitoring()
    }

    // MARK: - Public API

    /// Start tracking a new task
    public func startTask(type: String, query: String) {
        currentTask = TaskTracker(taskType: type, initialQuery: query)
        blockerLogger.debug("📋 Started tracking task: \(type)")
    }

    /// Record a query
    public func recordQuery(_ query: String) async {
        let timestamp = Date()
        queryHistory.append((query, timestamp))

        if var task = currentTask {
            task.queries.append(query)
            task.lastActivityTime = timestamp
            currentTask = task
        }

        // Check for repetition
        await checkForRepeatedQueries(query)

        // Trim history
        trimHistory()
    }

    /// Record an error
    public func recordError(_ error: String) async {
        let timestamp = Date()
        errorHistory.append((error, timestamp))

        if var task = currentTask {
            task.errors.append(error)
            task.lastActivityTime = timestamp
            currentTask = task
        }

        // Add error signal
        let signal = BlockerSignal(
            type: .errorOccurrence,
            severity: 0.7,
            context: ["error": String(error.prefix(200))]
        )
        await addSignal(signal)

        // Check for error loop
        await checkForErrorLoop()
    }

    /// Record model switch
    public func recordModelSwitch(from: String, to: String) async {
        if var task = currentTask {
            task.modelSwitches += 1
            task.lastActivityTime = Date()
            currentTask = task
        }

        let signal = BlockerSignal(
            type: .modelSwitch,
            severity: 0.5,
            context: ["from": from, "to": to]
        )
        await addSignal(signal)
    }

    /// Record user edit
    public func recordEdit() {
        if var task = currentTask {
            task.editCount += 1
            task.lastActivityTime = Date()
            currentTask = task
        }
    }

    /// Complete current task
    public func completeTask(success: Bool) {
        if let task = currentTask {
            blockerLogger.debug("✅ Task completed: \(task.taskType) (success: \(success))")

            // Clear any blockers related to this task
            activeBlockers.removeAll { blocker in
                blocker.context.taskType == task.taskType
            }
        }
        currentTask = nil
    }

    /// Get current blocker analysis
    public func analyzeCurrentState() async -> BlockerAnalysis? {
        guard let blocker = activeBlockers.first else { return nil }

        let relevantSignals = recentSignals.filter { signal in
            Date().timeIntervalSince(signal.timestamp) < signalWindowSeconds
        }

        let interventions = generateInterventions(for: blocker, signals: relevantSignals)

        return BlockerAnalysis(
            blocker: blocker,
            signals: relevantSignals,
            confidence: blocker.severity == .critical ? 0.9 : (blocker.severity == .high ? 0.75 : 0.6),
            suggestedInterventions: interventions
        )
    }

    /// Dismiss a blocker (user acknowledged or resolved)
    public func dismissBlocker(blockerId: UUID) {
        if let index = activeBlockers.firstIndex(where: { $0.id == blockerId }) {
            let blocker = activeBlockers.remove(at: index)
            resolvedBlockers.append(blocker)
            blockerLogger.info("🗑️ Blocker dismissed: \(blocker.type.rawValue)")
        }
    }

    /// Check if user is currently blocked
    public func isUserBlocked() -> Bool {
        !activeBlockers.isEmpty
    }

    /// Get blockers above a severity threshold
    public func getBlockers(minSeverity: DetectedBlocker.Severity) -> [DetectedBlocker] {
        let severityOrder: [DetectedBlocker.Severity] = [.low, .medium, .high, .critical]
        guard let minIndex = severityOrder.firstIndex(of: minSeverity) else { return [] }

        return activeBlockers.filter { blocker in
            guard let blockerIndex = severityOrder.firstIndex(of: blocker.severity) else { return false }
            return blockerIndex >= minIndex
        }
    }

    // MARK: - Signal Processing

    private func addSignal(_ signal: BlockerSignal) async {
        recentSignals.append(signal)

        // Trim old signals
        let cutoff = Date().addingTimeInterval(-signalWindowSeconds)
        recentSignals = recentSignals.filter { $0.timestamp > cutoff }

        // Analyze for blockers
        await analyzeSignals()
    }

    private func analyzeSignals() async {
        // Count signal types in recent window
        var signalCounts: [BlockerSignal.SignalType: Int] = [:]
        var totalSeverity: Double = 0

        for signal in recentSignals {
            signalCounts[signal.type, default: 0] += 1
            totalSeverity += signal.severity
        }

        // Determine if blocked
        let isRepeatBlocked = (signalCounts[.repeatedQuery] ?? 0) >= queryRepetitionThreshold ||
                              (signalCounts[.queryReformulation] ?? 0) >= 2
        let isErrorBlocked = (signalCounts[.errorOccurrence] ?? 0) >= errorThreshold
        let isStuckBlocked = currentTask?.duration ?? 0 > taskDurationThreshold
        let isFrustrated = (signalCounts[.negativeLanguage] ?? 0) > 0 ||
                           (signalCounts[.modelSwitch] ?? 0) >= 2

        // Create blocker if needed
        if isRepeatBlocked {
            await createBlocker(
                type: .repeatedQuery,
                description: "You seem to be asking similar questions. Let me try a different approach.",
                severity: .medium
            )
        }

        if isErrorBlocked {
            await createBlocker(
                type: .errorLoop,
                description: "I notice we've encountered multiple errors. Let me help troubleshoot.",
                severity: .high
            )
        }

        if isStuckBlocked && !isRepeatBlocked && !isErrorBlocked {
            await createBlocker(
                type: .stuckOnTask,
                description: "This task is taking longer than usual. Would you like me to break it down?",
                severity: .medium
            )
        }

        if isFrustrated && totalSeverity > 2.0 {
            await createBlocker(
                type: .complexityOverload,
                description: "This seems challenging. Let me suggest a simpler approach.",
                severity: .medium
            )
        }
    }

    private func createBlocker(
        type: DetectedBlocker.BlockerType,
        description: String,
        severity: DetectedBlocker.Severity
    ) async {
        // Don't duplicate blockers of same type
        guard !activeBlockers.contains(where: { $0.type == type }) else { return }

        let resolutions = generateResolutions(for: type)

        let blocker = DetectedBlocker(
            type: type,
            description: description,
            severity: severity,
            context: DetectedBlocker.BlockerContext(
                taskType: currentTask?.taskType,
                timeSpent: currentTask?.duration ?? 0,
                attemptCount: queryHistory.count,
                relatedQueries: queryHistory.suffix(5).map(\.query),
                errorMessages: errorHistory.suffix(3).map(\.error)
            ),
            suggestedResolutions: resolutions
        )

        activeBlockers.append(blocker)
        blockerLogger.warning("🚧 Blocker detected: \(type.rawValue) (\(severity.rawValue))")

        // Notify hub
        await UnifiedIntelligenceHub.shared.processEvent(.blockerDetected(blocker: blocker))
    }

    private func generateResolutions(for type: DetectedBlocker.BlockerType) -> [String] {
        switch type {
        case .stuckOnTask:
            return [
                "Would you like me to break this into smaller steps?",
                "Let me try a different approach",
                "I can show you examples of similar solutions"
            ]

        case .repeatedQuery:
            return [
                "Let me rephrase the problem to understand better",
                "Can you clarify what specific part isn't working?",
                "Here's a step-by-step breakdown"
            ]

        case .errorLoop:
            return [
                "Let me analyze the error pattern",
                "I'll try a more robust solution",
                "Would you like to see the error history?"
            ]

        case .resourceExhausted:
            return [
                "Let's save progress and continue in a new conversation",
                "I can summarize what we've done so far"
            ]

        case .dependencyWait:
            return [
                "While waiting, let me prepare the next steps",
                "I can work on something else in the meantime"
            ]

        case .complexityOverload:
            return [
                "Let me simplify the approach",
                "We can tackle one part at a time",
                "Here's the core concept without the complexity"
            ]

        case .toolFailure:
            return [
                "Let me try an alternative method",
                "I can work around this limitation"
            ]
        }
    }

    private func generateInterventions(for blocker: DetectedBlocker, signals: [BlockerSignal]) -> [BlockerAnalysis.Intervention] {
        var interventions: [BlockerAnalysis.Intervention] = []

        switch blocker.type {
        case .stuckOnTask:
            interventions.append(BlockerAnalysis.Intervention(
                type: .suggestBreakdown,
                message: "Let me break this into smaller, manageable steps",
                action: .showMessage("I'll split this task into phases. Starting with the core functionality first."),
                priority: 1
            ))

        case .repeatedQuery:
            interventions.append(BlockerAnalysis.Intervention(
                type: .askClarifyingQuestion,
                message: "I want to make sure I understand correctly",
                action: .showMessage("Could you describe the specific behavior you're expecting vs. what's happening?"),
                priority: 1
            ))

        case .errorLoop:
            interventions.append(BlockerAnalysis.Intervention(
                type: .offerAlternativeApproach,
                message: "Let me try a different approach",
                action: .showMessage("I've noticed a pattern in these errors. Let me suggest an alternative solution."),
                priority: 1
            ))

        case .complexityOverload:
            interventions.append(BlockerAnalysis.Intervention(
                type: .offerSimplification,
                message: "Simplifying the approach",
                action: .showMessage("Let's start with the simplest version that works, then add complexity gradually."),
                priority: 1
            ))

            interventions.append(BlockerAnalysis.Intervention(
                type: .suggestBreak,
                message: "Consider taking a short break",
                action: .showMessage("Complex problems often benefit from fresh eyes. A 5-minute break might help."),
                priority: 3
            ))

        default:
            interventions.append(BlockerAnalysis.Intervention(
                type: .offerAlternativeApproach,
                message: "Let me help",
                action: .showMessage("I've noticed you might be stuck. Would you like me to try a different approach?"),
                priority: 2
            ))
        }

        return interventions.sorted { $0.priority < $1.priority }
    }

    // MARK: - Detection Logic

    private func checkForRepeatedQueries(_ newQuery: String) async {
        let recentQueries = queryHistory.suffix(10)
        var similarCount = 0

        for (query, _) in recentQueries {
            if isSimilarQuery(newQuery, query) {
                similarCount += 1
            }
        }

        if similarCount >= queryRepetitionThreshold {
            let signal = BlockerSignal(
                type: .repeatedQuery,
                severity: 0.8,
                context: ["similarCount": String(similarCount)]
            )
            await addSignal(signal)
        } else if similarCount >= 2 {
            let signal = BlockerSignal(
                type: .queryReformulation,
                severity: 0.5,
                context: ["similarCount": String(similarCount)]
            )
            await addSignal(signal)
        }
    }

    private func checkForErrorLoop() async {
        let recentErrors = errorHistory.suffix(5)
        let cutoff = Date().addingTimeInterval(-300) // Last 5 minutes

        let errorCount = recentErrors.filter { $0.timestamp > cutoff }.count

        if errorCount >= errorThreshold {
            blockerLogger.warning("⚠️ Error loop detected: \(errorCount) errors in 5 minutes")
        }
    }

    private func isSimilarQuery(_ a: String, _ b: String) -> Bool {
        let aLower = a.lowercased()
        let bLower = b.lowercased()

        if aLower == bLower { return true }

        let aWords = Set(aLower.split(separator: " ").map(String.init))
        let bWords = Set(bLower.split(separator: " ").map(String.init))

        guard !aWords.isEmpty && !bWords.isEmpty else { return false }

        let overlap = aWords.intersection(bWords)
        let similarity = Double(overlap.count) / Double(max(aWords.count, bWords.count))

        return similarity > 0.6
    }

    private func trimHistory() {
        let cutoff = Date().addingTimeInterval(-3600) // Keep 1 hour

        queryHistory = queryHistory.filter { $0.timestamp > cutoff }
        errorHistory = errorHistory.filter { $0.timestamp > cutoff }
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        isMonitoring = true

        Task.detached { [weak self] in
            while true {
                do {
                    try await Task.sleep(for: .seconds(30))
                } catch {
                    break
                }
                await self?.checkTaskDuration()
                await self?.checkIdleTime()
            }
        }
    }

    private func checkTaskDuration() async {
        guard let task = currentTask else { return }

        if task.duration > taskDurationThreshold {
            let signal = BlockerSignal(
                type: .longTaskDuration,
                severity: min(1.0, task.duration / (taskDurationThreshold * 2)),
                context: ["duration": String(format: "%.0f", task.duration)]
            )
            await addSignal(signal)
        }
    }

    private func checkIdleTime() async {
        guard let task = currentTask else { return }

        // If idle after an error, that's a strong stuck signal
        if task.idleTime > idleThreshold && !task.errors.isEmpty {
            let signal = BlockerSignal(
                type: .longIdlePeriod,
                severity: 0.6,
                context: ["idleTime": String(format: "%.0f", task.idleTime)]
            )
            await addSignal(signal)
        }
    }
}

// MARK: - Language Analysis Extension

extension BlockerAnticipator {
    /// Analyze message for frustration indicators
    public func analyzeLanguage(_ message: String) async {
        let messageLower = message.lowercased()

        let frustrationIndicators = [
            "doesn't work", "not working", "still not", "again",
            "why isn't", "why won't", "this is wrong", "broken",
            "frustrated", "confused", "don't understand", "makes no sense"
        ]

        let helpIndicators = [
            "help me", "i'm stuck", "can't figure out", "what am i doing wrong",
            "i give up", "please help", "need help"
        ]

        for indicator in frustrationIndicators {
            if messageLower.contains(indicator) {
                let signal = BlockerSignal(
                    type: .negativeLanguage,
                    severity: 0.6,
                    context: ["indicator": indicator]
                )
                await addSignal(signal)
                break
            }
        }

        for indicator in helpIndicators {
            if messageLower.contains(indicator) {
                let signal = BlockerSignal(
                    type: .helpRequest,
                    severity: 0.8,
                    context: ["indicator": indicator]
                )
                await addSignal(signal)
                break
            }
        }
    }
}
