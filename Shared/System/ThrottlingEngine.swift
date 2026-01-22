//
//  ThrottlingEngine.swift
//  Thea
//
//  Created by Claude Code on 2026-01-20
//  Copyright © 2026. All rights reserved.
//

import Foundation

// MARK: - Throttling Engine

/// Manages resource throttling based on system conditions
@MainActor
@Observable
public final class ThrottlingEngine {
    public static let shared = ThrottlingEngine()

    // MARK: - State

    /// Current throttle level
    public private(set) var throttleLevel: ThrottleLevel = .none

    /// Whether throttling is active
    public var isThrottled: Bool {
        throttleLevel != .none
    }

    /// Current configuration
    public var configuration: ThrottlingConfiguration {
        didSet {
            saveConfiguration()
            evaluateThrottleLevel()
        }
    }

    // MARK: - Dependencies

    private let powerManager = PowerStateManager.shared

    // MARK: - Storage

    private let defaults = UserDefaults.standard
    private let configKey = "ThrottlingEngine.configuration"

    // MARK: - Callbacks

    public var onThrottleLevelChanged: ((ThrottleLevel) -> Void)?

    // MARK: - Initialization

    private init() {
        if let data = defaults.data(forKey: configKey),
           let config = try? JSONDecoder().decode(ThrottlingConfiguration.self, from: data) {
            self.configuration = config
        } else {
            self.configuration = ThrottlingConfiguration()
        }

        setupObservers()
        evaluateThrottleLevel()
    }

    private func saveConfiguration() {
        if let data = try? JSONEncoder().encode(configuration) {
            defaults.set(data, forKey: configKey)
        }
    }

    // MARK: - Setup

    private func setupObservers() {
        // Observe power state changes
        powerManager.onPowerSourceChanged = { [weak self] _ in
            guard self != nil else { return }
            Task { @MainActor [weak self] in
                self?.evaluateThrottleLevel()
            }
        }

        powerManager.onBatteryLevelChanged = { [weak self] _ in
            guard self != nil else { return }
            Task { @MainActor [weak self] in
                self?.evaluateThrottleLevel()
            }
        }

        powerManager.onThermalStateChanged = { [weak self] _ in
            guard self != nil else { return }
            Task { @MainActor [weak self] in
                self?.evaluateThrottleLevel()
            }
        }
    }

    // MARK: - Throttle Evaluation

    /// Evaluate and update throttle level based on current conditions
    public func evaluateThrottleLevel() {
        guard configuration.enabled else {
            updateThrottleLevel(.none)
            return
        }

        let powerStatus = powerManager.powerStatus

        // Critical thermal state always triggers maximum throttling
        if powerStatus.thermalState == .critical {
            updateThrottleLevel(.critical)
            return
        }

        // Serious thermal state triggers heavy throttling
        if powerStatus.thermalState == .serious {
            updateThrottleLevel(.heavy)
            return
        }

        // Battery level based throttling
        if powerStatus.powerSource == .battery, let level = powerStatus.batteryLevel {
            if level <= configuration.criticalBatteryThreshold {
                updateThrottleLevel(.critical)
                return
            }

            if level <= configuration.heavyThrottleBatteryThreshold {
                updateThrottleLevel(.heavy)
                return
            }

            if level <= configuration.lightThrottleBatteryThreshold {
                updateThrottleLevel(.light)
                return
            }

            // On battery but level is okay - apply minimal throttling
            if configuration.throttleOnBattery {
                updateThrottleLevel(.light)
                return
            }
        }

        // Low power mode
        if powerStatus.isLowPowerMode && configuration.respectLowPowerMode {
            updateThrottleLevel(.moderate)
            return
        }

        // Fair thermal state - light throttling
        if powerStatus.thermalState == .fair {
            updateThrottleLevel(.light)
            return
        }

        updateThrottleLevel(.none)
    }

    private func updateThrottleLevel(_ newLevel: ThrottleLevel) {
        guard throttleLevel != newLevel else { return }

        let oldLevel = throttleLevel
        throttleLevel = newLevel

        // Log the change
        print("[ThrottlingEngine] Throttle level changed: \(oldLevel) → \(newLevel)")

        onThrottleLevelChanged?(newLevel)
    }

    // MARK: - Throttled Operations

    /// Get delay for operations based on throttle level
    public func getOperationDelay(for category: OperationCategory) -> TimeInterval {
        guard isThrottled else { return 0 }

        let baseDelay = category.baseDelay
        return baseDelay * throttleLevel.delayMultiplier
    }

    /// Get concurrent operation limit based on throttle level
    public func getConcurrencyLimit(for category: OperationCategory) -> Int {
        let baseLimit = category.baseConcurrency
        return max(1, Int(Double(baseLimit) * throttleLevel.concurrencyMultiplier))
    }

    /// Check if an operation should be deferred
    public func shouldDefer(_ category: OperationCategory) -> Bool {
        guard isThrottled else { return false }

        switch (throttleLevel, category.priority) {
        case (.critical, _):
            return category.priority != .critical
        case (.heavy, .low), (.heavy, .background):
            return true
        case (.moderate, .background):
            return true
        default:
            return false
        }
    }

    /// Execute an operation with appropriate throttling
    public func throttled<T: Sendable>(
        category: OperationCategory,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        // Check if should defer entirely
        if shouldDefer(category) {
            throw ThrottlingError.operationDeferred
        }

        // Apply delay if needed
        let delay = getOperationDelay(for: category)
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        return try await operation()
    }

    // MARK: - Manual Control

    /// Force a specific throttle level (for testing or user override)
    public func forceThrottleLevel(_ level: ThrottleLevel) {
        guard configuration.allowManualOverride else { return }
        updateThrottleLevel(level)
    }

    /// Clear forced throttle level and re-evaluate
    public func clearForcedThrottleLevel() {
        evaluateThrottleLevel()
    }

    /// Temporarily disable throttling
    public func temporarilyDisable(for duration: TimeInterval) {
        let previousConfig = configuration
        configuration.enabled = false

        Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            await MainActor.run {
                self.configuration = previousConfig
            }
        }
    }

    // MARK: - Status

    /// Get current throttling status
    public var status: ThrottlingStatus {
        ThrottlingStatus(
            level: throttleLevel,
            isThrottled: isThrottled,
            reason: currentThrottleReason,
            configuration: configuration
        )
    }

    private var currentThrottleReason: String {
        let powerStatus = powerManager.powerStatus

        if powerStatus.thermalState == .critical {
            return "Critical thermal state"
        }

        if powerStatus.thermalState == .serious {
            return "High thermal state"
        }

        if let level = powerStatus.batteryLevel {
            if level <= configuration.criticalBatteryThreshold {
                return "Critical battery (\(level)%)"
            }
            if level <= configuration.heavyThrottleBatteryThreshold {
                return "Low battery (\(level)%)"
            }
            if level <= configuration.lightThrottleBatteryThreshold {
                return "Battery saver (\(level)%)"
            }
        }

        if powerStatus.isLowPowerMode {
            return "Low Power Mode enabled"
        }

        if powerStatus.powerSource == .battery && configuration.throttleOnBattery {
            return "Running on battery"
        }

        return "No throttling"
    }
}

// MARK: - Throttle Level

public enum ThrottleLevel: Int, Codable, Sendable, CaseIterable, Comparable {
    case none = 0
    case light = 1
    case moderate = 2
    case heavy = 3
    case critical = 4

    public static func < (lhs: ThrottleLevel, rhs: ThrottleLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var displayName: String {
        switch self {
        case .none: return "None"
        case .light: return "Light"
        case .moderate: return "Moderate"
        case .heavy: return "Heavy"
        case .critical: return "Critical"
        }
    }

    public var icon: String {
        switch self {
        case .none: return "bolt.fill"
        case .light: return "bolt"
        case .moderate: return "bolt.slash"
        case .heavy: return "tortoise"
        case .critical: return "tortoise.fill"
        }
    }

    /// Delay multiplier for operations
    var delayMultiplier: Double {
        switch self {
        case .none: return 0.0
        case .light: return 0.5
        case .moderate: return 1.0
        case .heavy: return 2.0
        case .critical: return 5.0
        }
    }

    /// Concurrency multiplier (lower = fewer concurrent operations)
    var concurrencyMultiplier: Double {
        switch self {
        case .none: return 1.0
        case .light: return 0.8
        case .moderate: return 0.5
        case .heavy: return 0.25
        case .critical: return 0.1
        }
    }
}

// MARK: - Operation Category

public enum OperationCategory: String, Codable, Sendable {
    case aiRequest
    case fileOperation
    case networkRequest
    case backgroundSync
    case uiUpdate
    case indexing

    public var priority: OperationPriority {
        switch self {
        case .aiRequest: return .high
        case .uiUpdate: return .high
        case .fileOperation: return .normal
        case .networkRequest: return .normal
        case .backgroundSync: return .background
        case .indexing: return .background
        }
    }

    var baseDelay: TimeInterval {
        switch self {
        case .aiRequest: return 0.5
        case .uiUpdate: return 0.1
        case .fileOperation: return 0.2
        case .networkRequest: return 0.3
        case .backgroundSync: return 1.0
        case .indexing: return 2.0
        }
    }

    var baseConcurrency: Int {
        switch self {
        case .aiRequest: return 2
        case .uiUpdate: return 10
        case .fileOperation: return 4
        case .networkRequest: return 6
        case .backgroundSync: return 2
        case .indexing: return 1
        }
    }
}

// MARK: - Operation Priority

public enum OperationPriority: Int, Codable, Sendable, Comparable {
    case background = 0
    case low = 1
    case normal = 2
    case high = 3
    case critical = 4

    public static func < (lhs: OperationPriority, rhs: OperationPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Throttling Configuration

public struct ThrottlingConfiguration: Codable, Sendable, Equatable {
    /// Whether throttling is enabled
    public var enabled: Bool = true

    /// Throttle when on battery power
    public var throttleOnBattery: Bool = true

    /// Respect system Low Power Mode
    public var respectLowPowerMode: Bool = true

    /// Battery threshold for light throttling
    public var lightThrottleBatteryThreshold: Int = 50

    /// Battery threshold for heavy throttling
    public var heavyThrottleBatteryThreshold: Int = 20

    /// Battery threshold for critical throttling
    public var criticalBatteryThreshold: Int = 10

    /// Allow manual throttle level override
    public var allowManualOverride: Bool = true

    public init() {}
}

// MARK: - Throttling Status

public struct ThrottlingStatus: Sendable {
    public let level: ThrottleLevel
    public let isThrottled: Bool
    public let reason: String
    public let configuration: ThrottlingConfiguration
}

// MARK: - Throttling Error

public enum ThrottlingError: Error, LocalizedError, Sendable {
    case operationDeferred
    case throttlingDisabled

    public var errorDescription: String? {
        switch self {
        case .operationDeferred:
            return "Operation deferred due to throttling"
        case .throttlingDisabled:
            return "Throttling is disabled"
        }
    }
}
