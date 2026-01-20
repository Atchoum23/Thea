//
//  BatteryOptimizer.swift
//  Thea
//
//  Created by Claude Code on 2026-01-20
//  Copyright © 2026. All rights reserved.
//

import Foundation

// MARK: - Battery Optimizer

/// Optimizes app behavior to conserve battery
@MainActor
@Observable
public final class BatteryOptimizer {
    public static let shared = BatteryOptimizer()

    // MARK: - Dependencies

    private let powerManager = PowerStateManager.shared
    private let throttlingEngine = ThrottlingEngine.shared

    // MARK: - State

    /// Current optimization mode
    public private(set) var optimizationMode: OptimizationMode = .balanced

    /// Configuration
    public var configuration: BatteryOptimizerConfiguration {
        didSet {
            saveConfiguration()
            evaluateOptimizationMode()
        }
    }

    // MARK: - Storage

    private let defaults = UserDefaults.standard
    private let configKey = "BatteryOptimizer.configuration"

    // MARK: - Callbacks

    public var onOptimizationModeChanged: ((OptimizationMode) -> Void)?

    // MARK: - Initialization

    private init() {
        if let data = defaults.data(forKey: configKey),
           let config = try? JSONDecoder().decode(BatteryOptimizerConfiguration.self, from: data) {
            self.configuration = config
        } else {
            self.configuration = BatteryOptimizerConfiguration()
        }

        setupObservers()
        evaluateOptimizationMode()
    }

    private func saveConfiguration() {
        if let data = try? JSONEncoder().encode(configuration) {
            defaults.set(data, forKey: configKey)
        }
    }

    // MARK: - Setup

    private func setupObservers() {
        powerManager.onPowerSourceChanged = { [weak self] _ in
            Task { @MainActor in
                self?.evaluateOptimizationMode()
            }
        }

        powerManager.onBatteryLevelChanged = { [weak self] _ in
            Task { @MainActor in
                self?.evaluateOptimizationMode()
            }
        }
    }

    // MARK: - Mode Evaluation

    private func evaluateOptimizationMode() {
        guard configuration.automaticOptimization else {
            updateMode(configuration.manualMode)
            return
        }

        let powerStatus = powerManager.powerStatus

        // On AC power - use performance mode
        if powerStatus.powerSource == .ac && !powerStatus.isLowPowerMode {
            updateMode(.performance)
            return
        }

        // Critical battery
        if let level = powerStatus.batteryLevel, level <= 10 {
            updateMode(.ultraSaver)
            return
        }

        // Low battery
        if let level = powerStatus.batteryLevel, level <= 20 {
            updateMode(.maxSaver)
            return
        }

        // Low power mode active
        if powerStatus.isLowPowerMode {
            updateMode(.maxSaver)
            return
        }

        // Medium battery
        if let level = powerStatus.batteryLevel, level <= 50 {
            updateMode(.balanced)
            return
        }

        // Good battery on battery power
        if powerStatus.powerSource == .battery {
            updateMode(.balanced)
            return
        }

        updateMode(.performance)
    }

    private func updateMode(_ newMode: OptimizationMode) {
        guard optimizationMode != newMode else { return }

        optimizationMode = newMode
        applyOptimizations()
        onOptimizationModeChanged?(newMode)
    }

    // MARK: - Apply Optimizations

    private func applyOptimizations() {
        let settings = optimizationMode.settings

        // Apply to relevant systems
        applyNetworkOptimizations(settings)
        applyBackgroundOptimizations(settings)
        applyUIOptimizations(settings)
    }

    private func applyNetworkOptimizations(_ settings: OptimizationSettings) {
        // These would be read by network managers
        // Settings stored in configuration for access by other components
    }

    private func applyBackgroundOptimizations(_ settings: OptimizationSettings) {
        // These would be read by background task managers
    }

    private func applyUIOptimizations(_ settings: OptimizationSettings) {
        // These would be read by UI components
    }

    // MARK: - Public API

    /// Get current optimization settings
    public var currentSettings: OptimizationSettings {
        optimizationMode.settings
    }

    /// Check if a feature should be disabled for battery savings
    public func shouldDisableFeature(_ feature: BatteryFeature) -> Bool {
        switch optimizationMode {
        case .performance:
            return false
        case .balanced:
            return feature.priority == .low
        case .maxSaver:
            return feature.priority != .critical
        case .ultraSaver:
            return feature.priority != .critical
        }
    }

    /// Get recommended polling interval for a service
    public func getPollingInterval(for service: ServiceType) -> TimeInterval {
        let baseInterval = service.basePollingInterval
        return baseInterval * optimizationMode.pollingMultiplier
    }

    /// Get recommended batch size for operations
    public func getBatchSize(for operation: BatchOperation) -> Int {
        let baseSize = operation.baseBatchSize
        return max(1, Int(Double(baseSize) * optimizationMode.batchMultiplier))
    }

    /// Check if network prefetching should be enabled
    public var shouldPrefetch: Bool {
        optimizationMode == .performance || optimizationMode == .balanced
    }

    /// Check if animations should be reduced
    public var shouldReduceAnimations: Bool {
        optimizationMode == .maxSaver || optimizationMode == .ultraSaver
    }

    /// Check if background refresh should be enabled
    public var shouldBackgroundRefresh: Bool {
        optimizationMode != .ultraSaver
    }

    // MARK: - Manual Control

    /// Set manual optimization mode
    public func setManualMode(_ mode: OptimizationMode) {
        configuration.automaticOptimization = false
        configuration.manualMode = mode
        updateMode(mode)
    }

    /// Enable automatic optimization
    public func enableAutomaticOptimization() {
        configuration.automaticOptimization = true
        evaluateOptimizationMode()
    }

    // MARK: - Status

    /// Get current optimization status
    public var status: BatteryOptimizationStatus {
        BatteryOptimizationStatus(
            mode: optimizationMode,
            isAutomatic: configuration.automaticOptimization,
            settings: currentSettings,
            powerStatus: powerManager.powerStatus
        )
    }
}

// MARK: - Optimization Mode

public enum OptimizationMode: String, Codable, Sendable, CaseIterable {
    case performance
    case balanced
    case maxSaver
    case ultraSaver

    public var displayName: String {
        switch self {
        case .performance: return "Performance"
        case .balanced: return "Balanced"
        case .maxSaver: return "Battery Saver"
        case .ultraSaver: return "Ultra Saver"
        }
    }

    public var description: String {
        switch self {
        case .performance:
            return "Maximum performance, no restrictions"
        case .balanced:
            return "Balance between performance and battery life"
        case .maxSaver:
            return "Significantly reduce power consumption"
        case .ultraSaver:
            return "Minimal power usage, essential features only"
        }
    }

    public var icon: String {
        switch self {
        case .performance: return "bolt.fill"
        case .balanced: return "leaf"
        case .maxSaver: return "battery.75"
        case .ultraSaver: return "battery.25"
        }
    }

    var pollingMultiplier: Double {
        switch self {
        case .performance: return 1.0
        case .balanced: return 1.5
        case .maxSaver: return 3.0
        case .ultraSaver: return 6.0
        }
    }

    var batchMultiplier: Double {
        switch self {
        case .performance: return 1.0
        case .balanced: return 0.75
        case .maxSaver: return 0.5
        case .ultraSaver: return 0.25
        }
    }

    var settings: OptimizationSettings {
        switch self {
        case .performance:
            return OptimizationSettings(
                reduceAnimations: false,
                reduceSyncFrequency: false,
                reduceBackgroundActivity: false,
                deferNonCriticalWork: false,
                compressNetworkData: false,
                reduceFetchFrequency: false,
                disablePrefetching: false,
                reduceImageQuality: false
            )
        case .balanced:
            return OptimizationSettings(
                reduceAnimations: false,
                reduceSyncFrequency: true,
                reduceBackgroundActivity: false,
                deferNonCriticalWork: false,
                compressNetworkData: false,
                reduceFetchFrequency: true,
                disablePrefetching: false,
                reduceImageQuality: false
            )
        case .maxSaver:
            return OptimizationSettings(
                reduceAnimations: true,
                reduceSyncFrequency: true,
                reduceBackgroundActivity: true,
                deferNonCriticalWork: true,
                compressNetworkData: true,
                reduceFetchFrequency: true,
                disablePrefetching: true,
                reduceImageQuality: true
            )
        case .ultraSaver:
            return OptimizationSettings(
                reduceAnimations: true,
                reduceSyncFrequency: true,
                reduceBackgroundActivity: true,
                deferNonCriticalWork: true,
                compressNetworkData: true,
                reduceFetchFrequency: true,
                disablePrefetching: true,
                reduceImageQuality: true
            )
        }
    }
}

// MARK: - Optimization Settings

public struct OptimizationSettings: Sendable {
    public let reduceAnimations: Bool
    public let reduceSyncFrequency: Bool
    public let reduceBackgroundActivity: Bool
    public let deferNonCriticalWork: Bool
    public let compressNetworkData: Bool
    public let reduceFetchFrequency: Bool
    public let disablePrefetching: Bool
    public let reduceImageQuality: Bool
}

// MARK: - Battery Feature

public enum BatteryFeature: String, Codable, Sendable {
    case animations
    case backgroundSync
    case prefetching
    case hdImages
    case liveActivity
    case voiceActivation
    case continuousMonitoring

    public var priority: FeaturePriority {
        switch self {
        case .animations: return .low
        case .backgroundSync: return .normal
        case .prefetching: return .low
        case .hdImages: return .low
        case .liveActivity: return .normal
        case .voiceActivation: return .high
        case .continuousMonitoring: return .critical
        }
    }
}

public enum FeaturePriority: Int, Sendable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3
}

// MARK: - Service Type

public enum ServiceType: String, Codable, Sendable {
    case aiStatus
    case sync
    case health
    case notifications
    case monitoring

    var basePollingInterval: TimeInterval {
        switch self {
        case .aiStatus: return 5.0
        case .sync: return 60.0
        case .health: return 300.0
        case .notifications: return 30.0
        case .monitoring: return 10.0
        }
    }
}

// MARK: - Batch Operation

public enum BatchOperation: String, Codable, Sendable {
    case messageSync
    case fileIndex
    case healthData
    case notifications

    var baseBatchSize: Int {
        switch self {
        case .messageSync: return 50
        case .fileIndex: return 100
        case .healthData: return 24
        case .notifications: return 20
        }
    }
}

// MARK: - Configuration

public struct BatteryOptimizerConfiguration: Codable, Sendable, Equatable {
    /// Enable automatic optimization
    public var automaticOptimization: Bool = true

    /// Manual mode when automatic is disabled
    public var manualMode: OptimizationMode = .balanced

    /// Notify on mode changes
    public var notifyOnModeChange: Bool = true

    public init() {}
}

// MARK: - Status

public struct BatteryOptimizationStatus: Sendable {
    public let mode: OptimizationMode
    public let isAutomatic: Bool
    public let settings: OptimizationSettings
    public let powerStatus: PowerStatus
}
