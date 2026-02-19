//
//  DynamicResourceAllocatorTypes.swift
//  Thea
//
//  Supporting types for dynamic resource allocation
//  Extracted from DynamicResourceAllocator.swift for better code organization
//

import Foundation

// MARK: - Configuration

extension DynamicResourceAllocator {
    struct Configuration: Codable, Sendable {
        var enableDynamicAllocation = true
        var updateIntervalSeconds: Double = 5.0
        var aggressivenessLevel: AggressivenessLevel = .balanced
        var enablePredictiveAdjustment = true
        var enableBatteryAwareness = true
        var enableThermalThrottling = true
        var enableMemoryPressureResponse = true
        var maxModelMemoryPercent: Double = 0.6  // Max % of RAM for model
        var minModelMemoryPercent: Double = 0.2  // Min % to maintain inference
        var kvCacheMemoryPercent: Double = 0.15  // % of allocation for KV cache
        var reserveSystemMemoryGB: Double = 4.0  // Always reserve this much for system
        var enableGPUOffload = true
        var enableNeuralEngineOptimization = true

        // MARK: - Scheduled Allocation Modes
        var enableScheduledModes = true
        var scheduledModes: [ScheduledAllocationMode] = [
            // Default night mode: 11 PM - 6 AM, maximum allocation when idle + charging
            ScheduledAllocationMode(
                mode: .maximum,
                startHour: 23, startMinute: 0,
                endHour: 6, endMinute: 0,
                maxMemoryPercent: 0.95,
                requiresUserIdle: true,
                requiresCharging: true,
                isEnabled: true
            )
        ]
        var userIdleThresholdSeconds: Double = 300  // 5 minutes of inactivity = idle

        enum AggressivenessLevel: String, Codable, Sendable, CaseIterable {
            case conservative = "Conservative"  // Prioritize system stability
            case balanced = "Balanced"          // Balance performance and stability
            case aggressive = "Aggressive"      // Maximize inference performance
            case extreme = "Extreme"            // For high-end systems only
            case maximum = "Maximum"            // Night mode: up to 95% RAM when idle + charging

            var memoryMultiplier: Double {
                switch self {
                case .conservative: 0.8
                case .balanced: 1.0
                case .aggressive: 1.2
                case .extreme: 1.4
                case .maximum: 1.9  // Up to 95% with proper conditions
                }
            }
        }
    }
}

// MARK: - Scheduled Allocation Mode

extension DynamicResourceAllocator {
    /// Defines a time-based allocation schedule for automatic resource adjustment
    struct ScheduledAllocationMode: Identifiable, Codable, Sendable {
        let id: UUID
        var mode: Configuration.AggressivenessLevel
        var startHour: Int       // 0-23
        var startMinute: Int     // 0-59
        var endHour: Int         // 0-23
        var endMinute: Int       // 0-59
        var maxMemoryPercent: Double  // Override max memory for this mode (0.2-0.95)
        var requiresUserIdle: Bool    // Only activate when user is idle
        var requiresCharging: Bool    // Only activate when device is charging
        var isEnabled: Bool

        init(
            id: UUID = UUID(),
            mode: Configuration.AggressivenessLevel,
            startHour: Int,
            startMinute: Int,
            endHour: Int,
            endMinute: Int,
            maxMemoryPercent: Double = 0.8,
            requiresUserIdle: Bool = false,
            requiresCharging: Bool = false,
            isEnabled: Bool = true
        ) {
            self.id = id
            self.mode = mode
            self.startHour = startHour
            self.startMinute = startMinute
            self.endHour = endHour
            self.endMinute = endMinute
            self.maxMemoryPercent = min(0.95, max(0.2, maxMemoryPercent))
            self.requiresUserIdle = requiresUserIdle
            self.requiresCharging = requiresCharging
            self.isEnabled = isEnabled
        }

        /// Check if current time falls within this schedule
        // periphery:ignore - Reserved: isActiveNow() instance method — reserved for future feature activation
        func isActiveNow() -> Bool {
            guard isEnabled else { return false }

            let calendar = Calendar.current
            // periphery:ignore - Reserved: isActiveNow() instance method reserved for future feature activation
            let now = Date()
            let hour = calendar.component(.hour, from: now)
            let minute = calendar.component(.minute, from: now)

            let currentMinutes = hour * 60 + minute
            let startMinutes = startHour * 60 + startMinute
            let endMinutes = endHour * 60 + endMinute

            // Handle overnight schedules (e.g., 23:00 - 06:00)
            if startMinutes > endMinutes {
                return currentMinutes >= startMinutes || currentMinutes < endMinutes
            } else {
                return currentMinutes >= startMinutes && currentMinutes < endMinutes
            }
        }
    }
}

// MARK: - Resource Allocation

extension DynamicResourceAllocator {
    struct ResourceAllocation: Codable, Sendable {
        var maxModelMemoryBytes: UInt64 = 0
        var recommendedBatchSize: Int = 1
        var recommendedContextLength: Int = 4096
        var kvCacheSizeBytes: UInt64 = 0
        var useGPUAcceleration: Bool = true
        var useNeuralEngine: Bool = true
        var quantizationLevel: QuantizationLevel = .q4
        var throttleLevel: ThrottleLevel = .none
        var effectiveTokensPerSecond: Double = 0

        var maxModelMemoryGB: Double {
            Double(maxModelMemoryBytes) / 1_073_741_824
        }

        var kvCacheSizeGB: Double {
            Double(kvCacheSizeBytes) / 1_073_741_824
        }
    }

    enum QuantizationLevel: String, Codable, Sendable, CaseIterable {
        case fp32 = "FP32 (32-bit)"      // Full precision
        case fp16 = "FP16 (16-bit)"      // Half precision
        case q8 = "Q8 (8-bit)"           // 8-bit quantized
        case q4 = "Q4 (4-bit)"           // 4-bit quantized
        case q2 = "Q2 (2-bit)"           // 2-bit quantized (emergency)

        var memoryFactor: Double {
            switch self {
            case .fp32: 4.0
            case .fp16: 2.0
            case .q8: 1.0
            case .q4: 0.5
            case .q2: 0.25
            }
        }
    }

    enum ThrottleLevel: String, Codable, Sendable {
        case none = "None"
        case light = "Light (10%)"
        case moderate = "Moderate (25%)"
        case heavy = "Heavy (50%)"
        case severe = "Severe (75%)"

        var delayMultiplier: Double {
            switch self {
            case .none: 1.0
            case .light: 0.9
            case .moderate: 0.75
            case .heavy: 0.5
            case .severe: 0.25
            }
        }
    }
}

// MARK: - System Metrics

extension DynamicResourceAllocator {
    struct SystemMetrics: Codable, Sendable {
        var totalMemoryBytes: UInt64 = 0
        var availableMemoryBytes: UInt64 = 0
        var memoryPressure: MemoryPressureLevel = .nominal
        var thermalState: ThermalState = .nominal
        var cpuUsagePercent: Double = 0
        var gpuUsagePercent: Double = 0
        var gpuMemoryUsedBytes: UInt64 = 0
        var gpuMemoryTotalBytes: UInt64 = 0
        var batteryLevel: Double = 1.0
        var isCharging: Bool = true
        var networkBandwidthMbps: Double = 0
        var diskIOReadMBps: Double = 0
        var diskIOWriteMBps: Double = 0
        var timestamp = Date()

        var availableMemoryGB: Double {
            Double(availableMemoryBytes) / 1_073_741_824
        }

        var totalMemoryGB: Double {
            Double(totalMemoryBytes) / 1_073_741_824
        }

        var memoryUsagePercent: Double {
            guard totalMemoryBytes > 0 else { return 0 }
            return 1.0 - (Double(availableMemoryBytes) / Double(totalMemoryBytes))
        }
    }

    enum MemoryPressureLevel: String, Codable, Sendable {
        case nominal = "Normal"
        case warning = "Warning"
        case critical = "Critical"
    }

    enum ThermalState: String, Codable, Sendable {
        case nominal = "Nominal"
        case fair = "Fair"
        case serious = "Serious"
        case critical = "Critical"
    }
}

// MARK: - Adjustment Records

extension DynamicResourceAllocator {
    struct ResourceAdjustment: Identifiable, Codable, Sendable {
        let id: UUID
        let timestamp: Date
        let reason: String
        let previousAllocation: ResourceAllocation
        let newAllocation: ResourceAllocation
        let triggerMetrics: SystemMetrics

        init(reason: String, previous: ResourceAllocation, new: ResourceAllocation, metrics: SystemMetrics) {
            self.id = UUID()
            self.timestamp = Date()
            self.reason = reason
            self.previousAllocation = previous
            self.newAllocation = new
            self.triggerMetrics = metrics
        }
    }

    struct ResourceRecommendation: Identifiable, Sendable {
        let id = UUID()
        let title: String
        let description: String
        let impact: ImpactLevel
        // periphery:ignore - Reserved: action property — reserved for future feature activation
        let action: RecommendedAction

        enum ImpactLevel: String, Sendable {
            // periphery:ignore - Reserved: action property reserved for future feature activation
            case low, medium, high, critical
        }

        enum RecommendedAction: Sendable {
            case reduceContextLength(to: Int)
            // periphery:ignore - Reserved: switchQuantization(to:) case — reserved for future feature activation
            case switchQuantization(to: QuantizationLevel)
            // periphery:ignore - Reserved: reduceModelSize case — reserved for future feature activation
            case reduceModelSize
            // periphery:ignore - Reserved: switchQuantization(to:) case reserved for future feature activation
            // periphery:ignore - Reserved: reduceModelSize case reserved for future feature activation
            case enableThrottling(level: ThrottleLevel)
            case waitForCooling
            case closeOtherApps
        }
    }
}

// MARK: - Model Inference Settings

// periphery:ignore - Reserved: ModelInferenceSettings type reserved for future feature activation
struct ModelInferenceSettings: Sendable {
    let canLoad: Bool
    let recommendedQuantization: DynamicResourceAllocator.QuantizationLevel
    let recommendedContextLength: Int
    let recommendedBatchSize: Int
    let useGPU: Bool
    let useNeuralEngine: Bool
    let estimatedTokensPerSecond: Double
}

// MARK: - Notifications

extension Notification.Name {
    static let resourceAllocationDidChange = Notification.Name("resourceAllocationDidChange")
}
