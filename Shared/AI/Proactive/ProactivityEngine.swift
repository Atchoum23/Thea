// ProactivityEngine.swift
// Thea V2 - Omni-AI Proactivity System
//
// Enables THEA to anticipate user needs and act autonomously.
// Transforms THEA from reactive to proactive assistant.

import Foundation
import os.log
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Proactivity Engine

/// THEA's proactive intelligence - anticipates needs and acts autonomously
@MainActor
public final class ProactivityEngine: ObservableObject {
    public static let shared = ProactivityEngine()

    let logger = Logger(subsystem: "ai.thea.app", category: "Proactivity")

    // MARK: - Published State

    @Published public var isEnabled = true
    @Published public var pendingSuggestions: [AIProactivitySuggestion] = []
    @Published public var activeAmbientAgents: [AmbientAgent] = []
    @Published public var lastPrediction: UserIntentPrediction?

    // MARK: - Configuration

    public var predictionConfidenceThreshold: Double = 0.7
    public var maxPendingSuggestions = 5
    public var suggestionCooldownMinutes = 15

    // MARK: - Internal State

    var lastSuggestionTimes: [String: Date] = [:]
    var ambientAgentTasks: [String: Task<Void, Never>] = [:]
    var patternCache: [MemoryDetectedPattern] = []
    var lastPatternAnalysis: Date?

    // MARK: - Context Watch State

    /// Registered context watches for contradiction detection
    @Published public var contextWatches: [ContextWatch] = []

    /// Detected context changes/contradictions
    @Published public var pendingProactiveContextChanges: [ProactiveContextChange] = []

    /// Task for context monitoring
    var contextWatchTask: Task<Void, Never>?

    /// How often to check for context changes (seconds)
    public var contextCheckInterval: TimeInterval = 300  // 5 minutes

    private init() {
        logger.info("ProactivityEngine initialized")
    }


    // MARK: - Engine Control

    /// Enable or disable proactive features
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

    /// Reset engine state
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
