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
    var availableCapacityGB: Double = 0
    var usedCapacityGB: Double = 0
    var usagePercentage: Double = 0
}

struct NetworkInfo: Sendable {
    var isConnected: Bool = false
    var connectionType: String = ""
    var wifiSSID: String?
    var ipAddress: String?
}

struct DeviceInstalledApp: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let bundleId: String
    let version: String
    let path: String
}

struct RunningProcess: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let bundleId: String
    let pid: Int
    let isActive: Bool
    let isHidden: Bool
}

struct TheaInfo: Sendable {
    var version: String = ""
    var buildNumber: String = ""
    var bundleId: String = ""
    var installDate: Date?
    var lastLaunchDate: Date?
    var totalConversations: Int = 0
    var totalMessages: Int = 0
    var preferredModel: String?
    var isFirstLaunch: Bool = true
    var enabledFeatures: [String] = []
}

#if os(watchOS)
import WatchKit
#endif
