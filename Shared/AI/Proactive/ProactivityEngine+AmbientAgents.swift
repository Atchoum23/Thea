// ProactivityEngine+AmbientAgents.swift
// Thea V2 - Ambient Agent Management
//
// Manages the lifecycle of ambient agents that run continuously
// and monitor for triggers to generate proactive suggestions.

import Foundation
import os.log
#if canImport(UIKit)
import UIKit
#endif

// MARK: - ProactivityEngine Ambient Agent Management

extension ProactivityEngine {

    // MARK: - Registration

    /// Register and start an ambient agent.
    ///
    /// If the agent is already registered (by `id`), this method logs a warning and returns.
    /// Otherwise the agent is appended to `activeAmbientAgents` and its monitoring loop is started.
    ///
    /// - Parameter agent: The ``AmbientAgent`` to register.
    public func registerAmbientAgent(_ agent: AmbientAgent) {
        guard !activeAmbientAgents.contains(where: { $0.id == agent.id }) else {
            logger.warning("Ambient agent \(agent.id) already registered")
            return
        }

        activeAmbientAgents.append(agent)
        startAgent(agent)
        logger.info("Registered ambient agent: \(agent.name)")
    }

    /// Stop and unregister an ambient agent by its identifier.
    ///
    /// Cancels the agent's background task and removes it from the active list.
    ///
    /// - Parameter id: The unique identifier of the agent to remove.
    public func unregisterAmbientAgent(id: String) {
        ambientAgentTasks[id]?.cancel()
        ambientAgentTasks.removeValue(forKey: id)
        activeAmbientAgents.removeAll { $0.id == id }
        logger.info("Unregistered ambient agent: \(id)")
    }

    // MARK: - Internal

    /// Start the periodic monitoring loop for an ambient agent.
    ///
    /// Creates a `Task` that repeatedly calls the agent's `check()` and
    /// `generateSuggestion()` methods, queuing any resulting suggestion.
    ///
    /// - Parameter agent: The ``AmbientAgent`` whose loop should begin.
    internal func startAgent(_ agent: AmbientAgent) {
        let task = Task {
            while !Task.isCancelled && isEnabled {
                await agent.check()

                if let suggestion = await agent.generateSuggestion() {
                    await queueSuggestion(suggestion)
                }

                // Wait for next check interval
                try? await Task.sleep(for: .seconds(agent.checkIntervalSeconds)) // Safe: poll interval sleep; cancellation exits agent loop; non-fatal
            }
        }

        ambientAgentTasks[agent.id] = task
    }
}

// MARK: - Ambient Agent Protocol

/// An ambient agent that runs continuously and monitors for triggers.
///
/// Conforming types implement periodic checks and optionally produce
/// ``AIProactivitySuggestion`` instances when actionable conditions are detected.
public protocol AmbientAgent: Sendable {
    /// Unique identifier for the agent.
    var id: String { get }
    /// Human-readable display name.
    var name: String { get }
    /// Seconds between successive checks.
    var checkIntervalSeconds: Int { get }

    /// Perform a single monitoring check (e.g. read a sensor value).
    func check() async
    /// Generate a proactive suggestion based on the latest check, or `nil` if none warranted.
    ///
    /// - Returns: An ``AIProactivitySuggestion`` if conditions are met, otherwise `nil`.
    func generateSuggestion() async -> AIProactivitySuggestion?
}

// MARK: - Built-in Ambient Agents

/// Monitors battery level and suggests efficiency actions when power is low.
public actor BatteryAmbientAgent: AmbientAgent {
    public let id = "battery_monitor"
    public let name = "Battery Monitor"
    public let checkIntervalSeconds = 300  // 5 minutes

    private var lastBatteryLevel: Int?
    private var alertedLow = false

    public init() {}

    public func check() async {
        // Get current battery level
        let batteryLevel: Int? = await MainActor.run {
            #if os(macOS)
            // macOS: read battery via IOKit (simplified)
            nil
            #elseif os(iOS)
            Int(UIDevice.current.batteryLevel * 100)
            #else
            nil
            #endif
        }
        lastBatteryLevel = batteryLevel
    }

    /// Generates a power-saving suggestion when battery drops below 20%.
    ///
    /// - Returns: A high-priority suggestion to switch to power saving mode, or `nil`.
    public func generateSuggestion() async -> AIProactivitySuggestion? {
        guard let level = lastBatteryLevel,
              level < 20,
              !alertedLow else {
            return nil
        }

        alertedLow = true

        return AIProactivitySuggestion(
            type: "low_battery",
            title: "Switch to Power Saving Mode",
            reason: "Battery is at \(level)%. I can switch to local-only models to save power.",
            priority: .high
        )
    }
}

/// Monitors time-of-day patterns and suggests daily routines (e.g. morning briefing).
public actor TimePatternAgent: AmbientAgent {
    public let id = "time_pattern"
    public let name = "Time Pattern Monitor"
    public let checkIntervalSeconds = 600  // 10 minutes

    private var lastCheckedHour: Int = -1

    public init() {}

    public func check() async {
        let hour = Calendar.current.component(.hour, from: Date())
        lastCheckedHour = hour
    }

    /// Generates time-of-day suggestions such as morning briefings or end-of-day summaries.
    ///
    /// - Returns: A suggestion matching the current hour, or `nil`.
    public func generateSuggestion() async -> AIProactivitySuggestion? {
        let hour = lastCheckedHour

        switch hour {
        case 9:
            return AIProactivitySuggestion(
                type: "morning_briefing",
                title: "Morning Briefing",
                reason: "Would you like me to summarize your day ahead?",
                priority: .normal
            )
        case 17:
            return AIProactivitySuggestion(
                type: "end_of_day",
                title: "End of Day Summary",
                reason: "Ready to review what you accomplished today?",
                priority: .normal
            )
        default:
            return nil
        }
    }
}
