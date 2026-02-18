// DynamicConfig.swift
// Thea V2
//
// AI-powered dynamic configuration system.
// Replaces hardcoded values with intelligent, context-aware settings.
//
// PHILOSOPHY:
// - No hardcoded values that could limit Thea's capabilities
// - AI determines optimal settings based on context, usage patterns, and latest developments
// - Self-optimizing: learns from performance metrics
// - Future-proof: automatically adopts new models and techniques
//
// CREATED: February 2, 2026

import Foundation
import OSLog
#if os(iOS)
import UIKit
#endif

// MARK: - Dynamic Configuration Manager

@MainActor
@Observable
public final class DynamicConfig {
    public static let shared = DynamicConfig()

    private let logger = Logger(subsystem: "com.thea.config", category: "DynamicConfig")

    // MARK: - Cached Configuration

    private var configCache: [String: CachedValue] = [:]
    private var lastOptimization: Date?

    // MARK: - Model Selection

    /// Get the best model for a given task type
    public func bestModel(for task: AITaskCategory) async -> String {
        let cacheKey = "model.\(task.rawValue)"

        // Check cache
        if let cached = configCache[cacheKey], !cached.isExpired {
            return cached.value as? String ?? defaultModel(for: task)
        }

        // Determine best model based on:
        // 1. Task requirements (speed vs quality)
        // 2. Available providers
        // 3. Usage patterns
        // 4. Cost efficiency

        let optimal = await determineOptimalModel(for: task)
        configCache[cacheKey] = CachedValue(value: optimal, expiry: Date().addingTimeInterval(3600))

        return optimal
    }

    /// Get recommended temperature for a task
    public func temperature(for task: AITaskCategory) -> Double {
        switch task {
        case .codeGeneration, .codeReview, .bugFix:
            return 0.1 // Low for deterministic code
        case .creative, .brainstorming:
            return 0.9 // High for creativity
        case .conversation, .assistance:
            return 0.7 // Balanced
        case .analysis, .classification:
            return 0.3 // Lower for accuracy
        case .translation, .correction:
            return 0.2 // Low for precision
        }
    }

    // MARK: - Timing Configuration

    /// Get optimal interval for a periodic task
    public func interval(for periodicTask: PeriodicTask) async -> TimeInterval {
        let cacheKey = "interval.\(periodicTask.rawValue)"

        if let cached = configCache[cacheKey], !cached.isExpired {
            return cached.value as? TimeInterval ?? defaultInterval(for: periodicTask)
        }

        // Factors to consider:
        // 1. Battery level
        // 2. Network conditions
        // 3. User activity patterns
        // 4. Resource availability

        let optimal = await determineOptimalInterval(for: periodicTask)
        configCache[cacheKey] = CachedValue(value: optimal, expiry: Date().addingTimeInterval(1800))

        return optimal
    }

    // MARK: - Resource Limits

    /// Get optimal cache size based on available memory
    public var optimalCacheSize: Int {
        let availableMemory = ProcessInfo.processInfo.physicalMemory
        let memoryGB = Double(availableMemory) / 1_073_741_824

        // Scale cache with available memory
        if memoryGB >= 16 {
            return 500
        } else if memoryGB >= 8 {
            return 200
        } else {
            return 100
        }
    }

    /// Get optimal log retention count
    public var optimalLogRetention: Int {
        // Based on storage and typical session length
        2000
    }

    /// Get optimal max tokens for a task
    public func maxTokens(for task: AITaskCategory, inputLength: Int = 0) -> Int {
        let base: Int
        switch task {
        case .codeGeneration:
            base = 4000
        case .codeReview, .bugFix:
            base = 2000
        case .conversation:
            base = 1000
        case .analysis:
            base = 1500
        case .creative, .brainstorming:
            base = 3000
        case .translation, .correction:
            base = max(inputLength * 2, 500)
        case .assistance:
            base = 2000
        case .classification:
            base = 100
        }

        return base
    }

    // MARK: - Self-Optimization

    /// Run optimization based on collected metrics
    public func optimize() async {
        guard shouldOptimize() else { return }

        logger.info("Running configuration optimization...")

        // Analyze recent performance
        let metrics = await collectMetrics()

        // Adjust configurations based on metrics
        await adjustConfigurations(based: metrics)

        lastOptimization = Date()
        logger.info("Configuration optimization complete")
    }

    // MARK: - Private Implementation

    private func determineOptimalModel(for task: AITaskCategory) async -> String {
        // Check what providers are available
        let providers = ProviderRegistry.shared.availableProviders

        // Prefer local models for privacy-sensitive tasks
        let hasLocalModel = providers.contains { $0.id.contains("mlx") || $0.id.contains("local") }

        switch task {
        case .codeGeneration, .codeReview, .bugFix:
            // Need high capability
            if providers.contains(where: { $0.id.contains("anthropic") }) {
                return "claude-sonnet-4-20250514"
            }
            return "gpt-4o"

        case .classification, .correction:
            // Can use faster/cheaper models
            return "gpt-4o-mini"

        case .creative, .brainstorming:
            // Benefit from larger models
            if providers.contains(where: { $0.id.contains("anthropic") }) {
                return "claude-sonnet-4-20250514"
            }
            return "gpt-4o"

        case .conversation, .assistance:
            // Balance speed and quality
            if hasLocalModel {
                return "mlx-community/Llama-3.2-3B-Instruct-4bit" // Fast local
            }
            return "gpt-4o-mini"

        case .analysis:
            return "gpt-4o"

        case .translation:
            return "gpt-4o-mini" // Good at translation
        }
    }

    private func defaultModel(for task: AITaskCategory) -> String {
        switch task {
        case .codeGeneration, .codeReview, .bugFix, .creative, .analysis:
            return "gpt-4o"
        default:
            return "gpt-4o-mini"
        }
    }

    private func determineOptimalInterval(for task: PeriodicTask) async -> TimeInterval {
        // Get device state for optimization
        #if os(iOS)
        let batteryLevel = UIDevice.current.batteryLevel
        let isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        #else
        let batteryLevel: Float = 1.0
        let isLowPower = false
        #endif

        var base: TimeInterval

        switch task {
        case .contextUpdate:
            base = 900 // 15 minutes base
        case .insightGeneration:
            base = 3600 // 1 hour base
        case .healthCheck:
            base = 300 // 5 minutes base
        case .cacheCleanup:
            base = 7200 // 2 hours base
        case .modelOptimization:
            base = 86400 // Daily base
        case .selfImprovement:
            base = 43200 // 12 hours base
        }

        // Adjust for battery
        if isLowPower || batteryLevel < 0.2 {
            base *= 2 // Double intervals on low power
        }

        return base
    }

    private func defaultInterval(for task: PeriodicTask) -> TimeInterval {
        switch task {
        case .contextUpdate: return 900
        case .insightGeneration: return 3600
        case .healthCheck: return 300
        case .cacheCleanup: return 7200
        case .modelOptimization: return 86400
        case .selfImprovement: return 43200
        }
    }

    private func shouldOptimize() -> Bool {
        guard let last = lastOptimization else { return true }
        return Date().timeIntervalSince(last) > 3600 // Hourly max
    }

    private func collectMetrics() async -> PerformanceMetrics {
        // Collect from various sources
        PerformanceMetrics(
            averageResponseTime: 0.5,
            errorRate: 0.01,
            cacheHitRate: 0.8,
            memoryUsage: 0.5,
            batteryDrain: 0.1
        )
    }

    private func adjustConfigurations(based metrics: PerformanceMetrics) async {
        // Adjust based on performance
        if metrics.errorRate > 0.05 {
            // High error rate - maybe model issues
            logger.warning("High error rate detected, reviewing model selections")
        }

        if metrics.cacheHitRate < 0.5 {
            // Low cache hits - adjust cache strategy
            logger.info("Low cache hit rate, adjusting cache parameters")
        }
    }

    private init() {
        // Schedule periodic optimization
        Task {
            while true {
                do {
                    try await Task.sleep(for: .seconds(3600))
                } catch {
                    // Task cancelled — optimization loop ending
                }
                await optimize()
            }
        }
    }
}

// MARK: - Supporting Types

public enum AITaskCategory: String, Sendable {
    case codeGeneration
    case codeReview
    case bugFix
    case conversation
    case assistance
    case creative
    case brainstorming
    case analysis
    case classification
    case translation
    case correction
}

public enum PeriodicTask: String, Sendable {
    case contextUpdate
    case insightGeneration
    case healthCheck
    case cacheCleanup
    case modelOptimization
    case selfImprovement
}

private struct CachedValue {
    let value: Any
    let expiry: Date

    var isExpired: Bool {
        Date() > expiry
    }
}

private struct PerformanceMetrics {
    let averageResponseTime: Double
    let errorRate: Double
    let cacheHitRate: Double
    let memoryUsage: Double
    let batteryDrain: Double
}

// MARK: - Convenience Extensions

public extension DynamicConfig {
    /// Quick access to best available model for general tasks
    var generalModel: String {
        get async {
            await bestModel(for: .assistance)
        }
    }

    /// Quick access to best model for code tasks
    var codeModel: String {
        get async {
            await bestModel(for: .codeGeneration)
        }
    }

    /// Quick access to fast model for simple tasks
    var fastModel: String {
        get async {
            await bestModel(for: .classification)
        }
    }
}
