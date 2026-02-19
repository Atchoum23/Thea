//
//  UnifiedDeviceAwarenessTypes.swift
//  Thea
//
//  Supporting types for UnifiedDeviceAwareness
//

import Foundation

// MARK: - Supporting Types
// Note: Uses Platform from PlatformFeaturesHub

enum DeviceThermalState: String, Codable, Sendable {
    case nominal
    case fair
    case serious
    case critical
}

struct DeviceHardwareInfo: Sendable {
    var platform: Platform = .unknown
    var modelIdentifier: String = ""
    var modelName: String = ""
    var osVersion: String = ""
    var processorType: String = ""
    var processorCores: Int = 0
    var totalMemoryGB: Double = 0
    var thermalState: DeviceThermalState = .nominal
    var isLowPowerMode: Bool = false
    var screenResolution: String = ""
    var screenCount: Int = 1
}

struct SystemState: Sendable {
    var batteryLevel: Double?
    var isCharging: Bool?
    var uptime: TimeInterval = 0
    var activeAppName: String?
    var activeAppBundleId: String?
    var isFocusModeActive: Bool = false
    var currentLocale: String = ""
    var timezone: String = ""
    var isDarkMode: Bool = false
}

struct SensorData: Sendable {
    var accelerometerData: (x: Double, y: Double, z: Double)?
    var gyroscopeData: (x: Double, y: Double, z: Double)?
    var magnetometerData: (x: Double, y: Double, z: Double)?
    var altitude: Double?
    var pressure: Double?
    var ambientLight: Double?
}

struct StorageInfo: Sendable {
    var totalCapacityGB: Double = 0
    // periphery:ignore - Reserved: modelIdentifier property reserved for future feature activation
    var availableCapacityGB: Double = 0
    var usedCapacityGB: Double = 0
    var usagePercentage: Double = 0
}

// periphery:ignore - Reserved: thermalState property reserved for future feature activation
// periphery:ignore - Reserved: isLowPowerMode property reserved for future feature activation
// periphery:ignore - Reserved: screenResolution property reserved for future feature activation
// periphery:ignore - Reserved: screenCount property reserved for future feature activation
struct NetworkInfo: Sendable {
    var isConnected: Bool = false
    var connectionType: String = ""
    var wifiSSID: String?
    var ipAddress: String?
// periphery:ignore - Reserved: uptime property reserved for future feature activation
}

// periphery:ignore - Reserved: activeAppBundleId property reserved for future feature activation

// periphery:ignore - Reserved: isFocusModeActive property reserved for future feature activation

// periphery:ignore - Reserved: currentLocale property reserved for future feature activation

// periphery:ignore - Reserved: timezone property reserved for future feature activation

// periphery:ignore - Reserved: isDarkMode property reserved for future feature activation

struct DeviceInstalledApp: Identifiable, Sendable {
    let id = UUID()
    // periphery:ignore - Reserved: accelerometerData property reserved for future feature activation
    // periphery:ignore - Reserved: gyroscopeData property reserved for future feature activation
    // periphery:ignore - Reserved: magnetometerData property reserved for future feature activation
    // periphery:ignore - Reserved: altitude property reserved for future feature activation
    // periphery:ignore - Reserved: pressure property reserved for future feature activation
    // periphery:ignore - Reserved: ambientLight property reserved for future feature activation
    let name: String
    let bundleId: String
    let version: String
    let path: String
}

// periphery:ignore - Reserved: usedCapacityGB property reserved for future feature activation

// periphery:ignore - Reserved: usagePercentage property reserved for future feature activation

struct RunningProcess: Identifiable, Sendable {
    let id = UUID()
    let name: String
    // periphery:ignore - Reserved: connectionType property reserved for future feature activation
    // periphery:ignore - Reserved: wifiSSID property reserved for future feature activation
    // periphery:ignore - Reserved: ipAddress property reserved for future feature activation
    let bundleId: String
    let pid: Int
    let isActive: Bool
    let isHidden: Bool
}

// periphery:ignore - Reserved: bundleId property reserved for future feature activation

// periphery:ignore - Reserved: version property reserved for future feature activation

// periphery:ignore - Reserved: path property reserved for future feature activation

struct TheaInfo: Sendable {
    var version: String = ""
    var buildNumber: String = ""
    var bundleId: String = ""
    // periphery:ignore - Reserved: bundleId property reserved for future feature activation
    // periphery:ignore - Reserved: pid property reserved for future feature activation
    // periphery:ignore - Reserved: isActive property reserved for future feature activation
    // periphery:ignore - Reserved: isHidden property reserved for future feature activation
    var installDate: Date?
    var lastLaunchDate: Date?
    var totalConversations: Int = 0
    var totalMessages: Int = 0
    var preferredModel: String?
    // periphery:ignore - Reserved: bundleId property reserved for future feature activation
    // periphery:ignore - Reserved: installDate property reserved for future feature activation
    // periphery:ignore - Reserved: lastLaunchDate property reserved for future feature activation
    var isFirstLaunch: Bool = true
    // periphery:ignore - Reserved: totalMessages property reserved for future feature activation
    // periphery:ignore - Reserved: preferredModel property reserved for future feature activation
    // periphery:ignore - Reserved: isFirstLaunch property reserved for future feature activation
    // periphery:ignore - Reserved: enabledFeatures property reserved for future feature activation
    var enabledFeatures: [String] = []
}

#if os(watchOS)
import WatchKit
#endif
