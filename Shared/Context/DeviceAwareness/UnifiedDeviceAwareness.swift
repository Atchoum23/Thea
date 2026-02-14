import Foundation
import Network
#if os(iOS) || os(watchOS)
import UIKit
import CoreMotion
import HealthKit
#elseif os(macOS)
import AppKit
import IOKit.ps
#endif

// MARK: - Unified Device Awareness
// Provides comprehensive device awareness across all Apple platforms
// Includes hardware, software, sensors, apps, and content awareness

@MainActor
@Observable
final class UnifiedDeviceAwareness {
    static let shared = UnifiedDeviceAwareness()

    // MARK: - Device Information

    var deviceInfo = DeviceHardwareInfo()
    var systemState = SystemState()
    var sensorData = SensorData()
    var installedApps: [DeviceInstalledApp] = []
    var runningProcesses: [RunningProcess] = []
    var storageInfo = StorageInfo()
    var networkInfo = NetworkInfo()

    // Self-awareness
    var theaInfo = TheaInfo()

    // Update tracking
    private(set) var lastUpdate: Date?
    var updateTask: Task<Void, Never>?

    // Configuration
    struct Configuration: Codable, Sendable {
        var enableContinuousMonitoring: Bool = true
        var updateIntervalSeconds: TimeInterval = 30
        var enableSensorMonitoring: Bool = true
        var enableAppMonitoring: Bool = true
        var enableProcessMonitoring: Bool = true
        var enableContentAwareness: Bool = true
    }

    private(set) var configuration = Configuration()

    private init() {
        loadConfiguration()
        Task {
            await gatherInitialInfo()
            startContinuousMonitoring()
        }
    }

    // MARK: - Initial Gathering

    private func gatherInitialInfo() async {
        await gatherDeviceInfo()
        await gatherSystemState()
        await gatherStorageInfo()
        await gatherNetworkInfo()
        await gatherTheaInfo()

        if configuration.enableAppMonitoring {
            await gatherDeviceInstalledApps()
        }

        if configuration.enableProcessMonitoring {
            await gatherRunningProcesses()
        }

        lastUpdate = Date()
    }

    // MARK: - Continuous Monitoring

    private func startContinuousMonitoring() {
        guard configuration.enableContinuousMonitoring else { return }

        updateTask?.cancel()
        updateTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(configuration.updateIntervalSeconds))

                await gatherSystemState()
                await gatherNetworkInfo()

                if configuration.enableProcessMonitoring {
                    await gatherRunningProcesses()
                }

                lastUpdate = Date()
            }
        }
    }

    func stopMonitoring() {
        updateTask?.cancel()
        updateTask = nil
    }

    func refreshNow() async {
        await gatherInitialInfo()
    }

    // MARK: - Configuration

    func updateConfiguration(_ config: Configuration) {
        configuration = config
        saveConfiguration()

        if config.enableContinuousMonitoring {
            startContinuousMonitoring()
        } else {
            stopMonitoring()
        }
    }

    private func loadConfiguration() {
        if let data = UserDefaults.standard.data(forKey: "UnifiedDeviceAwareness.config"),
           let config = try? JSONDecoder().decode(Configuration.self, from: data)
        {
            configuration = config
        }
    }

    private func saveConfiguration() {
        if let data = try? JSONEncoder().encode(configuration) {
            UserDefaults.standard.set(data, forKey: "UnifiedDeviceAwareness.config")
        }
    }
}

// Supporting types are in UnifiedDeviceAwarenessTypes.swift
// Data gathering methods are in UnifiedDeviceAwareness+Gathering.swift
// Helper methods and context summary are in UnifiedDeviceAwareness+Helpers.swift
