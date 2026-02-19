import Foundation
import Network
import OSLog
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
    // periphery:ignore - Reserved: shared static property — reserved for future feature activation
    static let shared = UnifiedDeviceAwareness()

    private let logger = Logger(subsystem: "ai.thea.app", category: "UnifiedDeviceAwareness")

    // periphery:ignore - Reserved: shared static property reserved for future feature activation
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
                do {
                    try await Task.sleep(for: .seconds(configuration.updateIntervalSeconds))
                } catch {
                    break
                }

                await gatherSystemState()
                await gatherNetworkInfo()

                if configuration.enableProcessMonitoring {
                    await gatherRunningProcesses()
                }

                lastUpdate = Date()
            }
        }
    }

    // periphery:ignore - Reserved: stopMonitoring() instance method — reserved for future feature activation
    func stopMonitoring() {
        updateTask?.cancel()
        updateTask = nil
    // periphery:ignore - Reserved: stopMonitoring() instance method reserved for future feature activation
    }

    // periphery:ignore - Reserved: refreshNow() instance method — reserved for future feature activation
    func refreshNow() async {
        await gatherInitialInfo()
    // periphery:ignore - Reserved: refreshNow() instance method reserved for future feature activation
    }

    // MARK: - Configuration

    // periphery:ignore - Reserved: updateConfiguration(_:) instance method — reserved for future feature activation
    func updateConfiguration(_ config: Configuration) {
        // periphery:ignore - Reserved: updateConfiguration(_:) instance method reserved for future feature activation
        configuration = config
        saveConfiguration()

        if config.enableContinuousMonitoring {
            startContinuousMonitoring()
        } else {
            stopMonitoring()
        }
    }

    private func loadConfiguration() {
        if let data = UserDefaults.standard.data(forKey: "UnifiedDeviceAwareness.config") {
            do {
                let config = try JSONDecoder().decode(Configuration.self, from: data)
                configuration = config
            } catch {
                logger.error("Failed to decode configuration: \(error.localizedDescription)")
            }
        }
    }

    // periphery:ignore - Reserved: saveConfiguration() instance method reserved for future feature activation
    private func saveConfiguration() {
        do {
            let data = try JSONEncoder().encode(configuration)
            UserDefaults.standard.set(data, forKey: "UnifiedDeviceAwareness.config")
        } catch {
            logger.error("Failed to encode configuration: \(error.localizedDescription)")
        }
    }
}

// Supporting types are in UnifiedDeviceAwarenessTypes.swift
// Data gathering methods are in UnifiedDeviceAwareness+Gathering.swift
// Helper methods and context summary are in UnifiedDeviceAwareness+Helpers.swift
