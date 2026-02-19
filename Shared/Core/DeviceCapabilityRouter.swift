//
//  DeviceCapabilityRouter.swift
//  Thea
//
//  Created by Thea
//  Routes tasks to best-suited device based on capabilities
//

import Foundation
import os.log

#if canImport(UIKit)
    import UIKit
#endif

#if canImport(WatchKit)
    import WatchKit
#endif

#if os(macOS)
    import IOKit.ps
#endif

// MARK: - Device Capability Router

/// Routes tasks to the most suitable device based on capabilities
@MainActor
public final class DeviceCapabilityRouter: ObservableObject {
    public static let shared = DeviceCapabilityRouter()

    // periphery:ignore - Reserved: logger property reserved for future feature activation
    private let logger = Logger(subsystem: "app.thea.router", category: "DeviceCapabilityRouter")

    // MARK: - State

    @Published public private(set) var availableDevices: [DeviceInfo] = []
    @Published public private(set) var currentDevice: DeviceInfo

    // MARK: - Initialization

    private init() {
        currentDevice = DeviceRegistry.shared.currentDevice
        updateAvailableDevices()
    }

    // MARK: - Device Discovery

    /// Update list of available devices
    public func updateAvailableDevices() {
        currentDevice = DeviceRegistry.shared.currentDevice
        availableDevices = DeviceRegistry.shared.onlineDevices
    }

    // MARK: - Task Routing

    /// Find the best device to execute a task
    public func findBestDevice(for task: TaskRequirements) -> DeviceRoutingDecision {
        updateAvailableDevices()

        // Score each device
        var deviceScores: [(DeviceInfo, Double)] = []

        for device in availableDevices {
            let score = calculateScore(for: device, task: task)
            deviceScores.append((device, score))
        }

        // Sort by score descending
        deviceScores.sort { $0.1 > $1.1 }

        guard let best = deviceScores.first else {
            // Fallback to current device
            return DeviceRoutingDecision(
                targetDevice: currentDevice,
                score: 0.5,
                reasoning: "No other devices available, using current device"
            )
        }

        let reasoning = generateReasoning(device: best.0, task: task)

        return DeviceRoutingDecision(
            targetDevice: best.0,
            score: best.1,
            reasoning: reasoning
        )
    }

    /// Calculate device suitability score for a task
    private func calculateScore(for device: DeviceInfo, task: TaskRequirements) -> Double {
        var score = 0.0
        let capabilities = device.capabilities

        // Base score factors

        // 1. CPU requirement match (0-25 points)
        if task.requiresHighCPU {
            switch device.type {
            case .mac:
                score += 25 // Mac typically has best CPU
            case .iPad:
                score += 20 // iPad Pro has good CPU
            case .iPhone:
                score += 15
            case .watch:
                score += 5
            case .tv:
                score += 10
            case .vision:
                score += 22 // Vision Pro has M2
            }
        } else {
            score += 15 // Baseline for non-intensive tasks
        }

        // 2. GPU/Neural Engine requirement (0-25 points)
        if task.requiresGPU || task.requiresNeuralEngine {
            if capabilities.hasNeuralEngine {
                score += 25
            } else if capabilities.hasGPU {
                score += 20
            } else {
                score += 5
            }
        } else {
            score += 15
        }

        // 3. Memory requirement (0-20 points)
        if task.requiresHighMemory {
            switch device.type {
            case .mac:
                score += 20
            case .iPad:
                score += 15
            case .iPhone:
                score += 10
            case .vision:
                score += 18
            default:
                score += 5
            }
        } else {
            score += 15
        }

        // 4. Battery consideration (0-15 points)
        if !capabilities.isPluggedIn {
            // Penalize battery-powered devices for heavy tasks
            if task.estimatedDuration > 300 || task.requiresHighCPU {
                score -= 10
            }

            // Extra penalty for low battery
            if capabilities.batteryLevel < 20 {
                score -= 10
            }
        } else {
            score += 15
        }

        // 5. Network requirement (0-10 points)
        if task.requiresNetwork {
            if capabilities.hasWiFi {
                score += 10
            } else if capabilities.hasCellular {
                score += 5
            }
        } else {
            score += 8
        }

        // 6. Screen requirement (0-5 points)
        if task.requiresScreen {
            if device.type == .mac || device.type == .iPad {
                score += 5
            } else if device.type == .iPhone {
                score += 3
            }
        }

        // 7. Locality bonus - prefer current device if capable (0-10 points)
        if device.id == currentDevice.id {
            score += 10
        }

        // Normalize to 0-1 range
        return max(0, min(1, score / 100))
    }

    private func generateReasoning(device: DeviceInfo, task: TaskRequirements) -> String {
        var reasons: [String] = []

        if device.id == currentDevice.id {
            reasons.append("Using current device")
        } else {
            reasons.append("Routing to \(device.name)")
        }

        if task.requiresHighCPU, device.type == .mac {
            reasons.append("Mac has best CPU performance")
        }

        if task.requiresNeuralEngine, device.capabilities.hasNeuralEngine {
            reasons.append("Device has Neural Engine")
        }

        if device.capabilities.isPluggedIn {
            reasons.append("Device is plugged in")
        }

        return reasons.joined(separator: "; ")
    }

    // MARK: - Quick Routing Methods

    /// Route AI processing task
    /// Returns the best device for a standard AI inference task.
    public func routeAITask() -> DeviceRoutingDecision {
        let requirements = TaskRequirements(
            requiresHighCPU: true,
            requiresGPU: true,
            requiresNeuralEngine: true,
            requiresHighMemory: true,
            requiresNetwork: true
        )
        return findBestDevice(for: requirements)
    }

    /// Route lightweight query
    /// Returns the best device for a lightweight (low-resource) task.
    public func routeLightweightTask() -> DeviceRoutingDecision {
        let requirements = TaskRequirements(
            requiresHighCPU: false,
            requiresNetwork: true
        )
        return findBestDevice(for: requirements)
    }

    /// Route file processing task
    /// Returns the best device for processing a file of the given byte size.
    public func routeFileProcessingTask(estimatedSize: Int) -> DeviceRoutingDecision {
        let requirements = TaskRequirements(
            requiresHighCPU: estimatedSize > 10_000_000, // > 10MB
            requiresHighMemory: estimatedSize > 50_000_000, // > 50MB
            requiresNetwork: false,
            requiresStorage: true
        )
        return findBestDevice(for: requirements)
    }

    /// Route background sync task
    /// Returns the best device for a background (non-interactive) task.
    public func routeBackgroundTask() -> DeviceRoutingDecision {
        let requirements = TaskRequirements(
            requiresHighCPU: false,
            requiresNetwork: true,
            estimatedDuration: 600 // 10 minutes max
        )
        return findBestDevice(for: requirements)
    }
}

// MARK: - Task Requirements

/// Hardware and capability requirements used to route a task to the best available device.
public struct TaskRequirements: Sendable {
    public var requiresHighCPU: Bool
    public var requiresGPU: Bool
    public var requiresNeuralEngine: Bool
    public var requiresHighMemory: Bool
    public var requiresNetwork: Bool
    public var requiresScreen: Bool
    public var requiresStorage: Bool
    public var estimatedDuration: TimeInterval // seconds

    public init(
        requiresHighCPU: Bool = false,
        requiresGPU: Bool = false,
        requiresNeuralEngine: Bool = false,
        requiresHighMemory: Bool = false,
        requiresNetwork: Bool = false,
        requiresScreen: Bool = false,
        requiresStorage: Bool = false,
        estimatedDuration: TimeInterval = 60
    ) {
        self.requiresHighCPU = requiresHighCPU
        self.requiresGPU = requiresGPU
        self.requiresNeuralEngine = requiresNeuralEngine
        self.requiresHighMemory = requiresHighMemory
        self.requiresNetwork = requiresNetwork
        self.requiresScreen = requiresScreen
        self.requiresStorage = requiresStorage
        self.estimatedDuration = estimatedDuration
    }
}

// MARK: - Routing Decision

/// The result of routing a task: the selected target device, a confidence score, and human-readable reasoning.
public struct DeviceRoutingDecision: Sendable {
    public let targetDevice: DeviceInfo
    public let score: Double // 0-1 confidence score
    public let reasoning: String
    public let timestamp: Date
    public let localDeviceId: String

    @MainActor
    public init(targetDevice: DeviceInfo, score: Double, reasoning: String) {
        self.targetDevice = targetDevice
        self.score = score
        self.reasoning = reasoning
        timestamp = Date()
        localDeviceId = DeviceRegistry.shared.currentDevice.id
    }

    public var isLocalExecution: Bool {
        targetDevice.id == localDeviceId
    }

    public var confidenceLevel: ConfidenceLevel {
        switch score {
        case 0.8...: .high
        case 0.5 ..< 0.8: .medium
        default: .low
        }
    }

    /// Qualitative confidence band for a routing decision score.
    public enum ConfidenceLevel: String {
        case high = "High"
        case medium = "Medium"
        case low = "Low"
    }
}

// MARK: - Device Capabilities Extension

public struct RouterDeviceCapabilities: Codable, Sendable {
    public var hasNeuralEngine: Bool
    public var hasGPU: Bool
    public var hasCellular: Bool
    public var hasWiFi: Bool
    public var isPluggedIn: Bool
    public var batteryLevel: Int // 0-100
    public var availableStorage: Int64 // bytes
    public var ramSize: Int64 // bytes

    public init(
        hasNeuralEngine: Bool = false,
        hasGPU: Bool = false,
        hasCellular: Bool = false,
        hasWiFi: Bool = true,
        isPluggedIn: Bool = false,
        batteryLevel: Int = 100,
        availableStorage: Int64 = 0,
        ramSize: Int64 = 0
    ) {
        self.hasNeuralEngine = hasNeuralEngine
        self.hasGPU = hasGPU
        self.hasCellular = hasCellular
        self.hasWiFi = hasWiFi
        self.isPluggedIn = isPluggedIn
        self.batteryLevel = batteryLevel
        self.availableStorage = availableStorage
        self.ramSize = ramSize
    }

    /// Get current device capabilities
    @MainActor
    public static var current: RouterDeviceCapabilities {
        #if os(iOS)
            let device = UIDevice.current
            device.isBatteryMonitoringEnabled = true

            return RouterDeviceCapabilities(
                hasNeuralEngine: true, // All modern iOS devices have Neural Engine
                hasGPU: true,
                hasCellular: true, // Most iPhones/iPads have cellular option
                hasWiFi: true,
                isPluggedIn: device.batteryState == .charging || device.batteryState == .full,
                batteryLevel: Int(device.batteryLevel * 100),
                availableStorage: getAvailableStorage(),
                ramSize: Int64(ProcessInfo.processInfo.physicalMemory)
            )
        #elseif os(macOS)
            return RouterDeviceCapabilities(
                hasNeuralEngine: ProcessInfo.processInfo.isiOSAppOnMac || isAppleSilicon(),
                hasGPU: true,
                hasCellular: false,
                hasWiFi: true,
                isPluggedIn: getMacPowerStatus(),
                batteryLevel: getMacBatteryLevel(),
                availableStorage: getAvailableStorage(),
                ramSize: Int64(ProcessInfo.processInfo.physicalMemory)
            )
        #elseif os(watchOS)
            return RouterDeviceCapabilities(
                hasNeuralEngine: true,
                hasGPU: true,
                hasCellular: WKInterfaceDevice.current().wristLocation != .none,
                hasWiFi: true,
                isPluggedIn: false,
                batteryLevel: 80, // Watch doesn't expose battery level directly
                availableStorage: 0,
                ramSize: 0
            )
        #else
            return RouterDeviceCapabilities(
                hasNeuralEngine: true,
                hasGPU: true,
                hasCellular: false,
                hasWiFi: true,
                isPluggedIn: true, // tvOS is always plugged in
                batteryLevel: 100,
                availableStorage: getAvailableStorage(),
                ramSize: Int64(ProcessInfo.processInfo.physicalMemory)
            )
        #endif
    }

    #if os(macOS)
        private static func isAppleSilicon() -> Bool {
            var sysinfo = utsname()
            uname(&sysinfo)
            let machine = withUnsafePointer(to: &sysinfo.machine) {
                $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                    String(cString: $0)
                }
            }
            return machine.contains("arm64")
        }

        private static func getMacPowerStatus() -> Bool {
            guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
                  let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [Any],
                  let source = sources.first,
                  let description = IOPSGetPowerSourceDescription(snapshot, source as CFTypeRef)?.takeUnretainedValue() as? [String: Any],
                  let powerSource = description[kIOPSPowerSourceStateKey as String] as? String
            else {
                return true // Assume plugged in for desktop Macs
            }
            return powerSource == kIOPSACPowerValue
        }

        private static func getMacBatteryLevel() -> Int {
            guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
                  let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [Any],
                  let source = sources.first,
                  let description = IOPSGetPowerSourceDescription(snapshot, source as CFTypeRef)?.takeUnretainedValue() as? [String: Any],
                  let capacity = description[kIOPSCurrentCapacityKey as String] as? Int,
                  let maxCapacity = description[kIOPSMaxCapacityKey as String] as? Int,
                  maxCapacity > 0
            else {
                return 100 // Desktop Mac or unable to determine
            }
            return (capacity * 100) / maxCapacity
        }
    #endif

    private static func getAvailableStorage() -> Int64 {
        do {
            let resourceValues = try FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
                .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            return resourceValues?.volumeAvailableCapacityForImportantUsage ?? 0
        } catch {
            return 0
        }
    }
}
