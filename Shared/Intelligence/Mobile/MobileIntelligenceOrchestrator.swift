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
public struct MobileRoutingDecision: Sendable {
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

    private let powerMonitor = MobilePowerStateMonitor.shared
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
        powerMonitor.onMobilePowerStateChanged = { [weak self] _ in
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
    ) -> MobileRoutingDecision {
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
            return MobileRoutingDecision(
                mode: .cloud,
                reasoning: "No available modes, defaulting to cloud",
                confidence: 0.5,
                fallbacks: [],
                constraints: defaultConstraints(for: .cloud, budget: budget)
            )
        }

        // periphery:ignore - Reserved: budget parameter — kept for API compatibility
        let fallbacks = modeScores.dropFirst().prefix(2).map { $0.0 }

        return MobileRoutingDecision(
            mode: best.0,
            reasoning: best.2,
            confidence: min(best.1, 1.0),
            fallbacks: Array(fallbacks),
            constraints: defaultConstraints(for: best.0, budget: budget)
        )
    }

    // periphery:ignore:parameters budget - Reserved: parameter(s) kept for API compatibility
    private func scoreMode(
        _ mode: InferenceMode,
        power: MobilePowerState,
        network: NetworkCondition,
        budget: InferenceBudget,
        taskType: TaskType,
        // periphery:ignore - Reserved: budget parameter kept for API compatibility
        urgency: QueryUrgency,
        queryLength: Int
    ) -> (Float, String) {
        var score: Float = 0.5
        var reasons: [String] = []

        let modeAdjustments = scoreModeAdjustments(
            mode, power: power, network: network,
            taskType: taskType, urgency: urgency, queryLength: queryLength
        )
        for (delta, reason) in modeAdjustments {
            score += delta
            reasons.append(reason)
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

    /// Returns score adjustments for a given inference mode based on device context.
    private func scoreModeAdjustments(
        _ mode: InferenceMode,
        power: MobilePowerState,
        network: NetworkCondition,
        taskType: TaskType,
        urgency: QueryUrgency,
        queryLength: Int
    ) -> [(Float, String)] {
        switch mode {
        case .localLight:
            return scoreLocalLight(power: power, network: network, taskType: taskType)
        case .localFull:
            return scoreLocalFull(power: power, network: network, taskType: taskType)
        case .remoteMac:
            return scoreRemoteMac(power: power, network: network, taskType: taskType)
        case .cloud:
            return scoreCloud(network: network, taskType: taskType, urgency: urgency)
        case .hybrid:
            return queryLength > 1000 ? [(0.2, "Long query benefits from hybrid")] : []
        }
    }

    private func scoreLocalLight(power: MobilePowerState, network: NetworkCondition, taskType: TaskType) -> [(Float, String)] {
        var adjustments: [(Float, String)] = []
        if taskType.isSimple { adjustments.append((0.3, "Simple task suits light model")) }
        if power.batteryLevel < 0.40 { adjustments.append((0.2, "Low battery favors light model")) }
        if network.connectionType == .none { adjustments.append((0.4, "No network, must use local")) }
        return adjustments
    }

    private func scoreLocalFull(power: MobilePowerState, network: NetworkCondition, taskType: TaskType) -> [(Float, String)] {
        var adjustments: [(Float, String)] = []
        if !taskType.isSimple { adjustments.append((0.2, "Complex task benefits from full model")) }
        if power.isCharging { adjustments.append((0.3, "Charging, can use full model")) }
        if network.connectionType == .none { adjustments.append((0.4, "No network, using local")) }
        if power.batteryLevel < 0.30 { adjustments.append((-0.3, "Low battery penalty")) }
        return adjustments
    }

    private func scoreRemoteMac(power: MobilePowerState, network: NetworkCondition, taskType: TaskType) -> [(Float, String)] {
        var adjustments: [(Float, String)] = [(0.3, "Remote Mac available")]
        if !taskType.isSimple { adjustments.append((0.2, "Complex task benefits from Mac")) }
        if power.batteryLevel < 0.50 { adjustments.append((0.2, "Saves device battery")) }
        if network.connectionType == .wifi { adjustments.append((0.1, "Good WiFi connection")) }
        return adjustments
    }

    private func scoreCloud(network: NetworkCondition, taskType: TaskType, urgency: QueryUrgency) -> [(Float, String)] {
        var adjustments: [(Float, String)] = []
        if network.canUseCloud { adjustments.append((0.2, "Cloud available")) }
        if urgency == .high { adjustments.append((0.2, "Fast response needed")) }
        if network.isExpensive { adjustments.append((-0.3, "Expensive connection penalty")) }
        if !taskType.isSimple { adjustments.append((0.1, "Complex task")) }
        return adjustments
    }

    private func defaultConstraints(for mode: InferenceMode, budget: InferenceBudget) -> MobileRoutingDecision.RoutingConstraints {
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
        // periphery:ignore - Reserved: userSatisfaction parameter — kept for API compatibility
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
    // periphery:ignore:parameters latency,userSatisfaction - Reserved: parameter(s) kept for API compatibility
    public func recordOutcome(
        mode: InferenceMode,
        taskType: TaskType,
        urgency: QueryUrgency,
        success: Bool,
        latency: TimeInterval,
        // periphery:ignore - Reserved: latency parameter kept for API compatibility
        // periphery:ignore - Reserved: userSatisfaction parameter kept for API compatibility
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
