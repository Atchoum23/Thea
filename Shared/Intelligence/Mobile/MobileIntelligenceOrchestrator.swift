// MobileIntelligenceOrchestrator.swift
// Thea - Mobile Intelligence
//
// Meta-AI brain for iOS/iPadOS/macOS laptops that intelligently routes
// inference between local models, remote Mac, and cloud APIs based on
// battery, network, thermal state, and learned patterns.

import Foundation
import Observation

// MARK: - Inference Mode

/// Available inference modes
public enum InferenceMode: String, Sendable, CaseIterable {
    case localLight     // Small local model (0.5-1B)
    case localFull      // Full local model (3-7B)
    case remoteMac      // Route to Mac running Thea
    case cloud          // Cloud API (OpenAI, Anthropic, etc.)
    case hybrid         // Split across multiple backends

    public var displayName: String {
        switch self {
        case .localLight: return "Local (Light)"
        case .localFull: return "Local (Full)"
        case .remoteMac: return "Remote Mac"
        case .cloud: return "Cloud"
        case .hybrid: return "Hybrid"
        }
    }

    public var powerCost: Float {
        switch self {
        case .localLight: return 0.3
        case .localFull: return 1.0
        case .remoteMac: return 0.1  // Only network cost
        case .cloud: return 0.15     // Network cost
        case .hybrid: return 0.5
        }
    }
}

// MARK: - Routing Decision

/// Result of routing decision
public struct RoutingDecision: Sendable {
    public let mode: InferenceMode
    public let reasoning: String
    public let confidence: Float
    public let fallbacks: [InferenceMode]
    public let constraints: RoutingConstraints

    public struct RoutingConstraints: Sendable {
        public let maxTokens: Int
        public let timeoutSeconds: TimeInterval
        public let allowStreaming: Bool
    }
}

// MARK: - Mobile Intelligence Orchestrator

/// Orchestrates inference routing based on device state and learned patterns
@MainActor
@Observable
public final class MobileIntelligenceOrchestrator {
    public static let shared = MobileIntelligenceOrchestrator()

    // MARK: - Dependencies

    private let powerMonitor = PowerStateMonitor.shared
    private let networkMonitor = NetworkConditionMonitor.shared

    // MARK: - State

    public private(set) var currentMode: InferenceMode = .cloud
    public private(set) var isRemoteMacAvailable = false
    public private(set) var availableModes: Set<InferenceMode> = [.cloud]

    /// Learning: track which modes work best for which contexts
    private var modeSuccessRates: [String: [InferenceMode: Float]] = [:]

    // MARK: - Configuration

    public var preferLocalWhenPossible = true
    public var preferRemoteMacWhenAvailable = true
    public var maxLocalModelSizeGB: Float = 4.0

    private init() {
        setupMonitoring()
    }

    // MARK: - Setup

    private func setupMonitoring() {
        networkMonitor.startMonitoring()

        // React to power changes
        powerMonitor.onPowerStateChanged = { [weak self] _ in
            Task { @MainActor in
                self?.updateAvailableModes()
            }
        }

        // React to network changes
        networkMonitor.onConditionChanged = { [weak self] _ in
            Task { @MainActor in
                self?.updateAvailableModes()
            }
        }

        updateAvailableModes()
    }

    // MARK: - Mode Discovery

    private func updateAvailableModes() {
        var modes: Set<InferenceMode> = []

        let power = powerMonitor.currentState
        let network = networkMonitor.currentCondition

        // Local modes - based on power state
        if power.canDoLocalInference {
            modes.insert(.localLight)
            if power.batteryLevel > 0.30 && power.thermalState != .serious {
                modes.insert(.localFull)
            }
        }

        // Remote Mac - based on network and discovery
        if isRemoteMacAvailable && network.connectionType != .none {
            modes.insert(.remoteMac)
        }

        // Cloud - based on network
        if network.canUseCloud {
            modes.insert(.cloud)
        }

        // Hybrid - when we have multiple options
        if modes.count >= 2 {
            modes.insert(.hybrid)
        }

        availableModes = modes
    }

    // MARK: - Routing

    /// Decide the best inference mode for a given query
    public func routeQuery(
        _ query: String,
        taskType: TaskType,
        urgency: QueryUrgency = .normal
    ) -> RoutingDecision {
        let power = powerMonitor.currentState
        let network = networkMonitor.currentCondition
        let budget = powerMonitor.currentBudget

        // Score each available mode
        var modeScores: [(InferenceMode, Float, String)] = []

        for mode in availableModes {
            let (score, reason) = scoreMode(
                mode,
                power: power,
                network: network,
                budget: budget,
                taskType: taskType,
                urgency: urgency,
                queryLength: query.count
            )
            modeScores.append((mode, score, reason))
        }

        // Sort by score
        modeScores.sort { $0.1 > $1.1 }

        guard let best = modeScores.first else {
            // Fallback to cloud
            return RoutingDecision(
                mode: .cloud,
                reasoning: "No available modes, defaulting to cloud",
                confidence: 0.5,
                fallbacks: [],
                constraints: defaultConstraints(for: .cloud, budget: budget)
            )
        }

        let fallbacks = modeScores.dropFirst().prefix(2).map { $0.0 }

        return RoutingDecision(
            mode: best.0,
            reasoning: best.2,
            confidence: min(best.1, 1.0),
            fallbacks: Array(fallbacks),
            constraints: defaultConstraints(for: best.0, budget: budget)
        )
    }

    private func scoreMode(
        _ mode: InferenceMode,
        power: PowerState,
        network: NetworkCondition,
        budget: InferenceBudget,
        taskType: TaskType,
        urgency: QueryUrgency,
        queryLength: Int
    ) -> (Float, String) {
        var score: Float = 0.5
        var reasons: [String] = []

        switch mode {
        case .localLight:
            // Good for simple tasks, low power
            if taskType.isSimple {
                score += 0.3
                reasons.append("Simple task suits light model")
            }
            if power.batteryLevel < 0.40 {
                score += 0.2
                reasons.append("Low battery favors light model")
            }
            if network.connectionType == .none {
                score += 0.4
                reasons.append("No network, must use local")
            }

        case .localFull:
            // Good for complex tasks when we have power
            if !taskType.isSimple {
                score += 0.2
                reasons.append("Complex task benefits from full model")
            }
            if power.isCharging {
                score += 0.3
                reasons.append("Charging, can use full model")
            }
            if network.connectionType == .none {
                score += 0.4
                reasons.append("No network, using local")
            }
            if power.batteryLevel < 0.30 {
                score -= 0.3
                reasons.append("Low battery penalty")
            }

        case .remoteMac:
            // Great when available - full power of Mac, minimal local cost
            score += 0.3
            reasons.append("Remote Mac available")
            if !taskType.isSimple {
                score += 0.2
                reasons.append("Complex task benefits from Mac")
            }
            if power.batteryLevel < 0.50 {
                score += 0.2
                reasons.append("Saves device battery")
            }
            if network.connectionType == .wifi {
                score += 0.1
                reasons.append("Good WiFi connection")
            }

        case .cloud:
            // Default fallback, good quality
            if network.canUseCloud {
                score += 0.2
                reasons.append("Cloud available")
            }
            if urgency == .high {
                score += 0.2
                reasons.append("Fast response needed")
            }
            if network.isExpensive {
                score -= 0.3
                reasons.append("Expensive connection penalty")
            }
            if !taskType.isSimple {
                score += 0.1
                reasons.append("Complex task")
            }

        case .hybrid:
            // Use when we need to split work
            if queryLength > 1000 {
                score += 0.2
                reasons.append("Long query benefits from hybrid")
            }
        }

        // Apply learned preferences
        let contextHash = "\(taskType.rawValue)_\(urgency.rawValue)"
        if let successRates = modeSuccessRates[contextHash],
           let rate = successRates[mode] {
            score += (rate - 0.5) * 0.3
            reasons.append("Learned preference adjustment")
        }

        return (score, reasons.joined(separator: "; "))
    }

    private func defaultConstraints(for mode: InferenceMode, budget: InferenceBudget) -> RoutingDecision.RoutingConstraints {
        switch mode {
        case .localLight:
            return .init(
                maxTokens: min(512, budget.maxTokensPerQuery),
                timeoutSeconds: 30,
                allowStreaming: true
            )
        case .localFull:
            return .init(
                maxTokens: min(2048, budget.maxTokensPerQuery),
                timeoutSeconds: 60,
                allowStreaming: true
            )
        case .remoteMac:
            return .init(
                maxTokens: budget.maxTokensPerQuery,
                timeoutSeconds: 120,
                allowStreaming: true
            )
        case .cloud:
            return .init(
                maxTokens: budget.maxTokensPerQuery,
                timeoutSeconds: 60,
                allowStreaming: true
            )
        case .hybrid:
            return .init(
                maxTokens: budget.maxTokensPerQuery,
                timeoutSeconds: 90,
                allowStreaming: false
            )
        }
    }

    // MARK: - Learning

    /// Record outcome of an inference to improve future routing
    public func recordOutcome(
        mode: InferenceMode,
        taskType: TaskType,
        urgency: QueryUrgency,
        success: Bool,
        latency: TimeInterval,
        userSatisfaction: Float? = nil
    ) {
        let contextHash = "\(taskType.rawValue)_\(urgency.rawValue)"

        if modeSuccessRates[contextHash] == nil {
            modeSuccessRates[contextHash] = [:]
        }

        let currentRate = modeSuccessRates[contextHash]?[mode] ?? 0.5
        let successValue: Float = success ? 1.0 : 0.0

        // Exponential moving average
        let alpha: Float = 0.2
        let newRate = alpha * successValue + (1 - alpha) * currentRate

        modeSuccessRates[contextHash]?[mode] = newRate
    }

    // MARK: - Remote Mac Management

    /// Called when a Mac is discovered on the network
    public func setRemoteMacAvailable(_ available: Bool) {
        isRemoteMacAvailable = available
        updateAvailableModes()
    }
}

// MARK: - Supporting Types

public enum QueryUrgency: String, Sendable {
    case low        // Can wait for best quality
    case normal     // Standard response time
    case high       // Need fast response
}

// Note: TaskType.isSimple is defined in Intelligence/Classification/TaskType.swift
