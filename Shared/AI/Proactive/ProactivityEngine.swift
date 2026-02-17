// ProactivityEngine.swift
// Thea V2 - Omni-AI Proactivity System
//
// Enables THEA to anticipate user needs and act autonomously.
// Transforms THEA from reactive to proactive assistant.
//
// This file contains the core class definition and engine lifecycle controls.
// Functionality is split across focused extensions:
//   - ProactivityEngine+AmbientAgents.swift  — Agent registration and lifecycle
//   - ProactivityEngine+IntentPrediction.swift — User intent prediction pipeline
//   - ProactivityEngine+Suggestions.swift     — Suggestion queue and autonomous actions
//   - ProactivityEngine+ContextWatch.swift    — Context watch monitoring and contradiction detection
//   - ProactivityEngine+Models.swift          — All supporting data types

import Foundation
import os.log
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Proactivity Engine

/// THEA's proactive intelligence engine — anticipates user needs and acts autonomously.
///
/// The engine combines ambient agent monitoring, user intent prediction, proactive
/// suggestion queuing, autonomous action execution, and context watch contradiction
/// detection into a unified proactive intelligence layer.
///
/// Access the shared singleton via ``ProactivityEngine/shared``.
@MainActor
public final class ProactivityEngine: ObservableObject {

    /// Shared singleton instance.
    public static let shared = ProactivityEngine()

    /// Logger for proactivity subsystem diagnostics.
    internal let logger = Logger(subsystem: "ai.thea.app", category: "Proactivity")

    // MARK: - Published State

    /// Whether the proactivity engine is currently enabled.
    @Published public private(set) var isEnabled = true

    /// Suggestions awaiting user review, ordered by arrival time.
    @Published public private(set) var pendingSuggestions: [AIProactivitySuggestion] = []

    /// Currently registered and running ambient agents.
    @Published public private(set) var activeAmbientAgents: [AmbientAgent] = []

    /// The most recent user intent prediction, if any.
    @Published public private(set) var lastPrediction: UserIntentPrediction?

    // MARK: - Configuration

    /// Minimum confidence score (0.0–1.0) required to surface an intent prediction.
    public var predictionConfidenceThreshold: Double = 0.7

    /// Maximum number of suggestions held in the pending queue.
    public var maxPendingSuggestions = 5

    /// Minimum minutes between suggestions of the same type.
    public var suggestionCooldownMinutes = 15

    // MARK: - Internal State

    /// Tracks the last time each suggestion type was queued, keyed by type string.
    internal var lastSuggestionTimes: [String: Date] = [:]

    /// Active background tasks for each ambient agent, keyed by agent ID.
    internal var ambientAgentTasks: [String: Task<Void, Never>] = [:]

    /// Cached patterns from ``MemoryManager`` for intent prediction.
    internal var patternCache: [MemoryDetectedPattern] = []

    /// When the pattern cache was last refreshed.
    internal var lastPatternAnalysis: Date?

    // MARK: - Context Watch State

    /// Registered context watches for contradiction detection.
    @Published public private(set) var contextWatches: [ContextWatch] = []

    /// Detected context changes/contradictions awaiting user review.
    @Published public private(set) var pendingProactiveContextChanges: [ProactiveContextChange] = []

    /// Background task for periodic context watch checking.
    internal var contextWatchTask: Task<Void, Never>?

    /// How often to check for context changes, in seconds. Default is 300 (5 minutes).
    public var contextCheckInterval: TimeInterval = 300  // 5 minutes

    // MARK: - Initialization

    private init() {
        logger.info("ProactivityEngine initialized")
    }

    // MARK: - Engine Control

    /// Enable or disable all proactive features.
    ///
    /// When enabled, restarts all registered ambient agents.
    /// When disabled, cancels all running agent tasks.
    ///
    /// - Parameter enabled: `true` to enable, `false` to disable.
    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled

        if enabled {
            // Restart all agents
            for agent in activeAmbientAgents {
                startAgent(agent)
            }
            logger.info("Proactivity engine enabled")
        } else {
            // Stop all agents
            for (id, task) in ambientAgentTasks {
                task.cancel()
                ambientAgentTasks.removeValue(forKey: id)
            }
            logger.info("Proactivity engine disabled")
        }
    }

    /// Reset all engine state to defaults.
    ///
    /// Clears pending suggestions, pattern cache, context watches, and
    /// stops the context watch monitoring loop.
    public func reset() {
        pendingSuggestions.removeAll()
        lastSuggestionTimes.removeAll()
        patternCache.removeAll()
        lastPatternAnalysis = nil
        lastPrediction = nil
        contextWatches.removeAll()
        pendingProactiveContextChanges.removeAll()
        stopContextWatching()
        logger.info("Proactivity engine reset")
    }
}
