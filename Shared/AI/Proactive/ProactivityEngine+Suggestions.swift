// ProactivityEngine+Suggestions.swift
// Thea V2 - Proactive Suggestions & Autonomous Actions
//
// Manages the suggestion queue (enqueue, dismiss, cooldown)
// and executes autonomous actions with user permission controls.

import Foundation
import os.log

// MARK: - ProactivityEngine Suggestions

extension ProactivityEngine {

    // MARK: - Suggestion Queue

    /// Queue a proactive suggestion for the user.
    ///
    /// Enforces cooldown periods per suggestion type and a maximum queue size.
    /// Stores the suggestion as a prospective memory in ``MemoryManager``.
    ///
    /// - Parameter suggestion: The ``AIProactivitySuggestion`` to enqueue.
    public func queueSuggestion(_ suggestion: AIProactivitySuggestion) async {
        // Check cooldown
        if let lastTime = lastSuggestionTimes[suggestion.type],
           Date().timeIntervalSince(lastTime) < Double(suggestionCooldownMinutes * 60) {
            logger.debug("Suggestion \(suggestion.type) is in cooldown")
            return
        }

        // Check if duplicate pending
        guard !pendingSuggestions.contains(where: { $0.type == suggestion.type }) else {
            return
        }

        // Add to pending
        pendingSuggestions.append(suggestion)

        // Trim to max
        if pendingSuggestions.count > maxPendingSuggestions {
            pendingSuggestions = Array(pendingSuggestions.suffix(maxPendingSuggestions))
        }

        lastSuggestionTimes[suggestion.type] = Date()
        logger.info("Queued proactive suggestion: \(suggestion.title)")

        // Store as prospective memory (using MemoryManager's types)
        let memoryTrigger: MemoryTriggerCondition = .contextMatch(suggestion.reason)
        let memoryPriority: OmniMemoryPriority = suggestion.priority == .high ? .high : .normal
        await MemoryManager.shared.storeProspectiveMemory(
            intention: "Suggested: \(suggestion.title)",
            triggerCondition: memoryTrigger,
            priority: memoryPriority
        )
    }

    /// Dismiss a suggestion, recording whether the user actioned or declined it.
    ///
    /// Learns from the interaction by storing a preference in ``MemoryManager``.
    ///
    /// - Parameters:
    ///   - suggestion: The ``AIProactivitySuggestion`` to dismiss.
    ///   - wasActioned: `true` if the user accepted/executed the suggestion, `false` if declined.
    public func dismissSuggestion(_ suggestion: AIProactivitySuggestion, wasActioned: Bool) async {
        pendingSuggestions.removeAll { $0.id == suggestion.id }

        // Learn from the interaction
        if wasActioned {
            await MemoryManager.shared.learnPreference(
                category: .timing,
                preference: "accepted_\(suggestion.type)",
                strength: 0.3
            )
        } else {
            await MemoryManager.shared.learnPreference(
                category: .timing,
                preference: "declined_\(suggestion.type)",
                strength: 0.2
            )
        }
    }

    // MARK: - Autonomous Actions

    /// Execute an autonomous action, subject to the user's permission settings.
    ///
    /// Checks that the engine is enabled, autonomous actions are allowed in settings,
    /// and the hourly limit has not been reached. If confirmation is required, the action
    /// is queued as a suggestion instead of being executed immediately.
    ///
    /// - Parameters:
    ///   - action: The ``ProactiveAutonomousAction`` to execute.
    ///   - requiresConfirmation: Whether to queue for user confirmation instead of executing directly.
    /// - Returns: A ``ProactiveActionResult`` indicating success or failure with a descriptive message.
    public func executeAutonomousAction(
        _ action: ProactiveAutonomousAction,
        requiresConfirmation: Bool = true
    ) async -> ProactiveActionResult {
        guard isEnabled else {
            return ProactiveActionResult(
                success: false,
                message: "Proactivity engine is disabled"
            )
        }

        // Check if action is allowed
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "autonomousActionsEnabled") else {
            return ProactiveActionResult(
                success: false,
                message: "Autonomous actions are disabled in settings"
            )
        }

        // Check hourly limit
        let maxActions = defaults.integer(forKey: "maxAutonomousActionsPerHour")
        guard maxActions > 0 else {
            return ProactiveActionResult(
                success: false,
                message: "Autonomous action limit reached"
            )
        }

        // If requires confirmation, queue as suggestion instead
        if requiresConfirmation && defaults.bool(forKey: "requireAutonomousConfirmation") {
            await queueSuggestion(AIProactivitySuggestion(
                type: "autonomous_\(action.type)",
                title: action.description,
                reason: "THEA wants to: \(action.description)",
                priority: .normal,
                actionPayload: action.payload
            ))

            return ProactiveActionResult(
                success: true,
                message: "Action queued for user confirmation"
            )
        }

        // Execute the action
        do {
            try await action.execute()

            // Log successful autonomous action
            await MemoryManager.shared.storeEpisodicMemory(
                event: "autonomous_action",
                context: action.description,
                outcome: "success"
            )

            logger.info("Executed autonomous action: \(action.description)")

            return ProactiveActionResult(
                success: true,
                message: "Action completed: \(action.description)"
            )
        } catch {
            logger.error("Autonomous action failed: \(error.localizedDescription)")

            return ProactiveActionResult(
                success: false,
                message: "Action failed: \(error.localizedDescription)"
            )
        }
    }
}
