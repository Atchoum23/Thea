// AdaptiveModelRouter.swift
// Thea - Mobile Intelligence
//
// Dynamically selects the optimal model and backend based on device
// conditions, learning from outcomes to improve over time.

import Foundation
import Observation

// MARK: - Route

/// A specific inference route with model and backend
public struct InferenceRoute: Identifiable, Sendable {
    public let id = UUID()
    public let backend: InferenceBackend
    public let modelId: String
    public let modelName: String
    public let estimatedLatency: TimeInterval
    public let estimatedPowerCost: Float
    public let qualityScore: Float

    public enum InferenceBackend: String, Sendable, CaseIterable {
        case localMLX      // On-device MLX model
        case localOllama   // Local Ollama (macOS)
        case remoteMac     // Remote Mac running Thea
        case openAI        // OpenAI API
        case anthropic     // Anthropic API
        case google        // Google AI API

        public var isLocal: Bool {
            self == .localMLX || self == .localOllama
        }

        public var isRemote: Bool {
            !isLocal
        }
    }
}

// MARK: - Routing Context

/// Context for making routing decisions
public struct RoutingContext: Sendable {
    public let taskType: TaskType
    public let queryComplexity: QueryComplexity
    public let expectedResponseLength: ResponseLength
    public let urgency: QueryUrgency
    public let userPreferences: UserRoutingPreferences

    public enum QueryComplexity: String, Sendable {
        case simple     // Single-turn, straightforward
        case moderate   // Multi-step reasoning
        case complex    // Deep analysis needed
    }

    public struct UserRoutingPreferences: Sendable {
        public let preferLocal: Bool
        public let preferSpeed: Bool
        public let preferQuality: Bool
        public let allowExpensiveAPIs: Bool

        public static let `default` = UserRoutingPreferences(
            preferLocal: true,
            preferSpeed: false,
            preferQuality: true,
            allowExpensiveAPIs: true
        )
    }
}

// MARK: - Adaptive Model Router

/// Routes queries to optimal models based on conditions and learning
@MainActor
@Observable
public final class AdaptiveModelRouter {
    public static let shared = AdaptiveModelRouter()

    // MARK: - Dependencies

    private let orchestrator = MobileIntelligenceOrchestrator.shared
    private let powerMonitor = MobilePowerStateMonitor.shared
    private let networkMonitor = NetworkConditionMonitor.shared

    // MARK: - State

    public private(set) var availableRoutes: [InferenceRoute] = []
    public private(set) var lastSelectedRoute: InferenceRoute?

    /// Learning: success rates per route per context
    private var routePerformance: [String: RoutePerformanceData] = [:]

    private init() {
        Task {
            await discoverRoutes()
        }
    }

    // MARK: - Route Discovery

    /// Discover all available inference routes
    public func discoverRoutes() async {
        var routes: [InferenceRoute] = []

        // Local MLX models (iOS/macOS)
        let localModels = await discoverLocalMLXModels()
        routes.append(contentsOf: localModels)

        // Remote Mac
        if orchestrator.isRemoteMacAvailable {
            routes.append(InferenceRoute(
                backend: .remoteMac,
                modelId: "remote-mac",
                modelName: "Remote Mac",
                estimatedLatency: 1.0,
                estimatedPowerCost: 0.1,
                qualityScore: 0.9
            ))
        }

        // Cloud APIs (if network available)
        if networkMonitor.currentCondition.canUseCloud {
            routes.append(contentsOf: discoverCloudRoutes())
        }

        availableRoutes = routes
    }

    private func discoverLocalMLXModels() async -> [InferenceRoute] {
        // Check for installed MLX models
        // This would integrate with MobileLLMManager
        var routes: [InferenceRoute] = []

        // Example: Check common model locations
        let modelCandidates = [
            ("Qwen2.5-0.5B", 0.5, 0.2, 0.7),
            ("Phi-3-mini", 1.0, 0.4, 0.8),
            ("SmolLM2-1.7B", 0.8, 0.3, 0.75)
        ]

        for (name, latency, power, quality) in modelCandidates {
            // Would check if model is actually installed
            routes.append(InferenceRoute(
                backend: .localMLX,
                modelId: name.lowercased().replacingOccurrences(of: " ", with: "-"),
                modelName: name,
                estimatedLatency: latency,
                estimatedPowerCost: Float(power),
                qualityScore: Float(quality)
            ))
        }

        return routes
    }

    private func discoverCloudRoutes() -> [InferenceRoute] {
        // Return available cloud API routes
        // Would check API key availability
        [
            InferenceRoute(
                backend: .anthropic,
                modelId: "claude-3-5-sonnet",
                modelName: "Claude 3.5 Sonnet",
                estimatedLatency: 2.0,
                estimatedPowerCost: 0.15,
                qualityScore: 0.95
            ),
            InferenceRoute(
                backend: .openAI,
                modelId: "gpt-4o",
                modelName: "GPT-4o",
                estimatedLatency: 1.5,
                estimatedPowerCost: 0.15,
                qualityScore: 0.93
            )
        ]
    }

    // MARK: - Route Selection

    /// Select the best route for the given context
    public func selectRoute(for context: RoutingContext) -> InferenceRoute? {
        guard !availableRoutes.isEmpty else { return nil }

        let power = powerMonitor.currentState
        let network = networkMonitor.currentCondition

        // Score each route
        var scoredRoutes: [(InferenceRoute, Float)] = []

        for route in availableRoutes {
            let score = scoreRoute(
                route,
                context: context,
                power: power,
                network: network
            )
            scoredRoutes.append((route, score))
        }

        // Sort by score descending
        scoredRoutes.sort { $0.1 > $1.1 }

        let selected = scoredRoutes.first?.0
        lastSelectedRoute = selected
        return selected
    }

    private func scoreRoute(
        _ route: InferenceRoute,
        context: RoutingContext,
        power: MobilePowerState,
        network: NetworkCondition
    ) -> Float {
        var score: Float = 0.5

        // Quality factor
        score += route.qualityScore * 0.3

        // Latency factor (inverse - lower is better)
        let latencyScore = max(0, 1.0 - Float(route.estimatedLatency / 5.0))
        score += latencyScore * 0.2

        // Power factor
        if power.isCharging {
            // Don't penalize power cost when charging
        } else if power.batteryLevel < 0.30 {
            // Heavily penalize power-hungry routes
            score -= route.estimatedPowerCost * 0.4
        } else {
            score -= route.estimatedPowerCost * 0.1
        }

        // Network factor
        if route.backend.isRemote {
            if !network.canUseCloud {
                return 0 // Can't use remote routes
            }
            if network.isExpensive {
                score -= 0.2
            }
            if network.signalStrength == .weak {
                score -= 0.3
            }
        }

        // Local preference
        if context.userPreferences.preferLocal && route.backend.isLocal {
            score += 0.2
        }

        // Speed preference
        if context.userPreferences.preferSpeed {
            score += latencyScore * 0.2
        }

        // Quality preference
        if context.userPreferences.preferQuality {
            score += route.qualityScore * 0.2
        }

        // Task complexity matching
        switch context.queryComplexity {
        case .simple:
            if route.backend == .localMLX {
                score += 0.2 // Local is fine for simple
            }
        case .moderate:
            // Balanced
            break
        case .complex:
            if route.qualityScore > 0.85 {
                score += 0.2 // Prefer high quality for complex
            }
        }

        // Apply learned performance data
        let contextKey = "\(context.taskType.rawValue)_\(route.modelId)"
        if let performance = routePerformance[contextKey] {
            score += (performance.successRate - 0.5) * 0.3
        }

        return score
    }

    // MARK: - Learning

    /// Record the outcome of using a route
    public func recordOutcome(
        route: InferenceRoute,
        context: RoutingContext,
        success: Bool,
        actualLatency: TimeInterval,
        userRating: Float? = nil
    ) {
        let contextKey = "\(context.taskType.rawValue)_\(route.modelId)"

        var performance = routePerformance[contextKey] ?? RoutePerformanceData()

        performance.totalAttempts += 1
        if success {
            performance.successfulAttempts += 1
        }

        // Update latency estimate (exponential moving average)
        let alpha: Float = 0.2
        performance.averageLatency = alpha * Float(actualLatency) + (1 - alpha) * performance.averageLatency

        if let rating = userRating {
            performance.userRatingSum += rating
            performance.userRatingCount += 1
        }

        routePerformance[contextKey] = performance
    }

    // MARK: - Fallback

    /// Get fallback routes if the primary fails
    public func getFallbackRoutes(excluding: InferenceRoute, context: RoutingContext) -> [InferenceRoute] {
        availableRoutes
            .filter { $0.id != excluding.id }
            .sorted { route1, route2 in
                let score1 = scoreRoute(route1, context: context, power: powerMonitor.currentState, network: networkMonitor.currentCondition)
                let score2 = scoreRoute(route2, context: context, power: powerMonitor.currentState, network: networkMonitor.currentCondition)
                return score1 > score2
            }
    }
}

// MARK: - Performance Data

private struct RoutePerformanceData {
    var totalAttempts: Int = 0
    var successfulAttempts: Int = 0
    var averageLatency: Float = 0
    var userRatingSum: Float = 0
    var userRatingCount: Int = 0

    var successRate: Float {
        guard totalAttempts > 0 else { return 0.5 }
        return Float(successfulAttempts) / Float(totalAttempts)
    }

    var averageUserRating: Float? {
        guard userRatingCount > 0 else { return nil }
        return userRatingSum / Float(userRatingCount)
    }
}
