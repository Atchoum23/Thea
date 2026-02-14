//
//  ShortcutsMonitor.swift
//  Thea
//
//  Shortcuts execution monitoring for life tracking
//  Emits LifeEvents when Shortcuts are run
//

import Foundation
import os.log
#if os(macOS)
    import AppKit
#endif

// MARK: - Shortcuts Monitor

/// Monitors Shortcuts execution for life tracking
/// Wraps ShortcutsIntegration to emit LifeEvents
public actor ShortcutsMonitor {
    public static let shared = ShortcutsMonitor()

    private let logger = Logger(subsystem: "ai.thea.app", category: "ShortcutsMonitor")

    private var isRunning = false
    private var executionHistory: [MonitoredShortcutExecution] = []
    private let maxHistorySize = 100

    private init() {}

    // MARK: - Lifecycle

    /// Start monitoring shortcuts
    public func start() async {
        guard !isRunning else { return }

        isRunning = true
        logger.info("Shortcuts monitor started")
    }

    /// Stop monitoring
    public func stop() async {
        guard isRunning else { return }

        isRunning = false
        logger.info("Shortcuts monitor stopped")
    }

    // MARK: - Shortcut Execution Tracking

    /// Run a shortcut and track the execution
    /// - Parameters:
    ///   - name: Name of the shortcut
    ///   - input: Optional input to pass
    ///   - context: Optional context about why it's being run
    /// - Returns: Output from the shortcut
    @discardableResult
    public func runShortcut(
        _ name: String,
        input: String? = nil,
        context: MonitoredShortcutContext? = nil
    ) async throws -> String? {
        let startTime = Date()

        do {
            // Run via the integration
            let output = try await ShortcutsIntegration.shared.runShortcut(name, input: input)

            let duration = Date().timeIntervalSince(startTime)

            // Track successful execution
            await trackExecution(
                name: name,
                input: input,
                output: output,
                duration: duration,
                success: true,
                error: nil,
                context: context
            )

            return output
        } catch {
            let duration = Date().timeIntervalSince(startTime)

            // Track failed execution
            await trackExecution(
                name: name,
                input: input,
                output: nil,
                duration: duration,
                success: false,
                error: error.localizedDescription,
                context: context
            )

            throw error
        }
    }

    private func trackExecution(
        name: String,
        input: String?,
        output: String?,
        duration: TimeInterval,
        success: Bool,
        error: String?,
        context: MonitoredShortcutContext?
    ) async {
        let execution = MonitoredShortcutExecution(
            shortcutName: name,
            timestamp: Date(),
            duration: duration,
            input: input,
            output: output,
            success: success,
            error: error,
            context: context
        )

        // Add to history
        executionHistory.append(execution)
        if executionHistory.count > maxHistorySize {
            executionHistory.removeFirst()
        }

        // Emit life event
        await emitShortcutEvent(execution)
    }

    private func emitShortcutEvent(_ execution: MonitoredShortcutExecution) async {
        let eventType: LifeEventType = execution.success ? .shortcutExecuted : .shortcutFailed
        let significance: EventSignificance = execution.success ? .moderate : .minor

        var summary: String
        if execution.success {
            summary = "Ran shortcut: \(execution.shortcutName)"
        } else {
            summary = "Shortcut failed: \(execution.shortcutName)"
        }

        var eventData: [String: String] = [
            "shortcutName": execution.shortcutName,
            "success": String(execution.success),
            "duration": String(format: "%.2f", execution.duration)
        ]

        if let input = execution.input {
            eventData["hasInput"] = "true"
            eventData["inputPreview"] = String(input.prefix(100))
        }

        if let output = execution.output {
            eventData["hasOutput"] = "true"
            eventData["outputPreview"] = String(output.prefix(200))
        }

        if let error = execution.error {
            eventData["error"] = error
        }

        if let context = execution.context {
            eventData["trigger"] = context.trigger.rawValue
            if let reason = context.reason {
                eventData["reason"] = reason
            }
        }

        let lifeEvent = LifeEvent(
            type: eventType,
            source: .shortcuts,
            summary: summary,
            data: eventData,
            significance: significance
        )

        await MainActor.run {
            LifeMonitoringCoordinator.shared.submitEvent(lifeEvent)
        }

        logger.info("Shortcut \(execution.success ? "completed" : "failed"): \(execution.shortcutName)")
    }

    // MARK: - Query Methods

    /// Get recent shortcut executions
    public func getRecentExecutions(limit: Int = 10) -> [MonitoredShortcutExecution] {
        Array(executionHistory.suffix(limit))
    }

    /// Get executions for a specific shortcut
    public func getExecutions(for shortcutName: String) -> [MonitoredShortcutExecution] {
        executionHistory.filter { $0.shortcutName == shortcutName }
    }

    /// Get execution statistics
    public func getStatistics() -> ShortcutStatistics {
        let totalExecutions = executionHistory.count
        let successfulExecutions = executionHistory.filter(\.success).count
        let failedExecutions = totalExecutions - successfulExecutions

        let averageDuration: TimeInterval
        if !executionHistory.isEmpty {
            averageDuration = executionHistory.map(\.duration).reduce(0, +) / Double(totalExecutions)
        } else {
            averageDuration = 0
        }

        // Count by shortcut
        var countByShortcut: [String: Int] = [:]
        for execution in executionHistory {
            countByShortcut[execution.shortcutName, default: 0] += 1
        }

        let mostUsed = countByShortcut.max { $0.value < $1.value }?.key

        return ShortcutStatistics(
            totalExecutions: totalExecutions,
            successfulExecutions: successfulExecutions,
            failedExecutions: failedExecutions,
            averageDuration: averageDuration,
            mostUsedShortcut: mostUsed,
            executionsByShortcut: countByShortcut
        )
    }
}

// MARK: - Supporting Types

/// Record of a shortcut execution (prefixed to avoid conflict with ShortcutsOrchestrator.ShortcutExecution)
public struct MonitoredShortcutExecution: Identifiable, Sendable {
    public let id = UUID()
    public let shortcutName: String
    public let timestamp: Date
    public let duration: TimeInterval
    public let input: String?
    public let output: String?
    public let success: Bool
    public let error: String?
    public let context: MonitoredShortcutContext?
}

/// Context for why a shortcut was run (prefixed to avoid conflict with ShortcutsOrchestrator.ShortcutContext)
public struct MonitoredShortcutContext: Sendable {
    public let trigger: ShortcutTrigger
    public let reason: String?

    public init(trigger: ShortcutTrigger, reason: String? = nil) {
        self.trigger = trigger
        self.reason = reason
    }
}

public enum ShortcutTrigger: String, Sendable {
    case userRequest = "user_request"       // User explicitly asked THEA to run it
    case automation = "automation"          // Triggered by THEA automation
    case schedule = "schedule"              // Scheduled execution
    case voiceCommand = "voice_command"     // Triggered via Siri/voice
    case menuBar = "menu_bar"               // Triggered from menu bar
    case unknown = "unknown"
}

/// Statistics about shortcut usage
public struct ShortcutStatistics: Sendable {
    public let totalExecutions: Int
    public let successfulExecutions: Int
    public let failedExecutions: Int
    public let averageDuration: TimeInterval
    public let mostUsedShortcut: String?
    public let executionsByShortcut: [String: Int]

    public var successRate: Double {
        guard totalExecutions > 0 else { return 0 }
        return Double(successfulExecutions) / Double(totalExecutions)
    }
}

// MARK: - LifeEventType & DataSourceType
// Note: LifeEventType cases (.shortcutExecuted, .shortcutFailed)
// and DataSourceType.shortcuts are defined in LifeMonitoringCoordinator.swift

// MARK: - Convenience Extension for ShortcutsIntegration

public extension ShortcutsIntegration {
    /// Run a shortcut with life monitoring
    func runWithMonitoring(
        _ name: String,
        input: String? = nil,
        context: MonitoredShortcutContext? = nil
    ) async throws -> String? {
        try await ShortcutsMonitor.shared.runShortcut(name, input: input, context: context)
    }
}
