//
//  DeviceRegistry.swift
//  Thea
//
//  Created by Claude Code on 2026-01-20
//  Copyright © 2026. All rights reserved.
//

import Foundation
#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

// MARK: - Device Registry

/// Manages registered devices for cross-device sync
@MainActor
@Observable
public final class DeviceRegistry {
    public static let shared = DeviceRegistry()

    // MARK: - State

    /// Current device information
    public private(set) var currentDevice: DeviceInfo

    /// All registered devices
    public private(set) var registeredDevices: [DeviceInfo] = []

    /// Online devices (with recent presence)
    public var onlineDevices: [DeviceInfo] {
        let cutoff = Date().addingTimeInterval(-300) // 5 minutes
        return registeredDevices.filter { $0.lastSeen > cutoff }
    }

    // MARK: - Storage

    private let defaults = UserDefaults.standard
    private let devicesKey = "DeviceRegistry.registeredDevices"

    // MARK: - Initialization

    private init() {
        currentDevice = Self.createCurrentDeviceInfo()
        loadRegisteredDevices()
        registerCurrentDevice()
    }

    // MARK: - Device Info Creation

    private static func createCurrentDeviceInfo() -> DeviceInfo {
        let deviceId = getOrCreateDeviceId()

        #if os(macOS)
            let deviceName = Host.current().localizedName ?? "Mac"
            let deviceType: DeviceType = .mac
            let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        #else
            let deviceName = UIDevice.current.name
            let deviceType: DeviceType = UIDevice.current.userInterfaceIdiom == .pad ? .iPad : .iPhone
            let osVersion = UIDevice.current.systemVersion
        #endif

        return DeviceInfo(
            id: deviceId,
            name: deviceName,
            type: deviceType,
            osVersion: osVersion,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            lastSeen: Date(),
            capabilities: DeviceCapabilities.current
        )
    }

    private static func getOrCreateDeviceId() -> String {
        let defaults = UserDefaults.standard
        let key = "DeviceRegistry.deviceId"

        if let existingId = defaults.string(forKey: key) {
            return existingId
        }

        let newId = UUID().uuidString
        defaults.set(newId, forKey: key)
        return newId
    }

    // MARK: - Registration

    private func registerCurrentDevice() {
        // Update current device in registry
        if let index = registeredDevices.firstIndex(where: { $0.id == currentDevice.id }) {
            registeredDevices[index] = currentDevice
        } else {
            registeredDevices.append(currentDevice)
        }
        saveRegisteredDevices()
    }

    /// Update current device's last seen time
    public func updatePresence() {
        currentDevice = DeviceInfo(
            id: currentDevice.id,
            name: currentDevice.name,
            type: currentDevice.type,
            osVersion: currentDevice.osVersion,
            appVersion: currentDevice.appVersion,
            lastSeen: Date(),
            capabilities: currentDevice.capabilities
        )
        registerCurrentDevice()
    }

    // MARK: - Device Management

    /// Add or update a device
    public func registerDevice(_ device: DeviceInfo) {
        if let index = registeredDevices.firstIndex(where: { $0.id == device.id }) {
            registeredDevices[index] = device
        } else {
            registeredDevices.append(device)
        }
        saveRegisteredDevices()
    }

    /// Remove a device
    public func removeDevice(_ deviceId: String) {
        registeredDevices.removeAll { $0.id == deviceId }
        saveRegisteredDevices()
    }

    /// Remove all devices except current
    public func removeAllOtherDevices() {
        registeredDevices = [currentDevice]
        saveRegisteredDevices()
    }

    // MARK: - Query

    /// Get device by ID
    public func getDevice(_ id: String) -> DeviceInfo? {
        registeredDevices.first { $0.id == id }
    }

    /// Check if device is online
    public func isDeviceOnline(_ id: String) -> Bool {
        guard let device = getDevice(id) else { return false }
        let cutoff = Date().addingTimeInterval(-300)
        return device.lastSeen > cutoff
    }

    // MARK: - Persistence

    private func loadRegisteredDevices() {
        if let data = defaults.data(forKey: devicesKey),
           let devices = try? JSONDecoder().decode([DeviceInfo].self, from: data)
        {
            registeredDevices = devices
        }
    }

    private func saveRegisteredDevices() {
        if let data = try? JSONEncoder().encode(registeredDevices) {
            defaults.set(data, forKey: devicesKey)
        }
    }
}

// MARK: - Device Info

public struct DeviceInfo: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let name: String
    public let type: DeviceType
    public let osVersion: String
    public let appVersion: String
    public let lastSeen: Date
    public let capabilities: DeviceCapabilities

    public init(
        id: String,
        name: String,
        type: DeviceType,
        osVersion: String,
        appVersion: String,
        lastSeen: Date,
        capabilities: DeviceCapabilities
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.osVersion = osVersion
        self.appVersion = appVersion
        self.lastSeen = lastSeen
        self.capabilities = capabilities
    }

    public var isOnline: Bool {
        let cutoff = Date().addingTimeInterval(-300)
        return lastSeen > cutoff
    }

    public var formattedLastSeen: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastSeen, relativeTo: Date())
    }
}

// MARK: - Device Type

public enum DeviceType: String, Codable, Sendable, CaseIterable {
    case mac
    case iPhone
    case iPad
    case watch
    case tv
    case vision

    public var displayName: String {
        switch self {
        case .mac: "Mac"
        case .iPhone: "iPhone"
        case .tv: "Apple TV"
        case .iPad: "iPad"
        case .watch: "Apple Watch"
        case .vision: "Apple Vision"
        }
    }

    public var icon: String {
        switch self {
        case .mac: "desktopcomputer"
        case .iPhone: "iphone"
        case .iPad: "ipad"
        case .watch: "applewatch"
        case .tv: "appletv"
        case .vision: "visionpro"
        }
    }
}

// MARK: - Device Capabilities

public struct DeviceCapabilities: Codable, Sendable, Equatable {
    public let supportsVoice: Bool
    public let supportsNotifications: Bool
    public let supportsBackgroundTasks: Bool
    public let supportsHandoff: Bool
    public let supportsCloudKit: Bool
    public let supportsLocalModels: Bool

    // Hardware capabilities for task routing
    public let hasNeuralEngine: Bool
    public let hasGPU: Bool
    public let hasCellular: Bool
    public let hasWiFi: Bool
    public let isPluggedIn: Bool
    public let batteryLevel: Int

    public init(
        supportsVoice: Bool = true,
        supportsNotifications: Bool = true,
        supportsBackgroundTasks: Bool = true,
        supportsHandoff: Bool = true,
        supportsCloudKit: Bool = true,
        supportsLocalModels: Bool = false,
        hasNeuralEngine: Bool = true,
        hasGPU: Bool = true,
        hasCellular: Bool = false,
        hasWiFi: Bool = true,
        isPluggedIn: Bool = true,
        batteryLevel: Int = 100
    ) {
        self.supportsVoice = supportsVoice
        self.supportsNotifications = supportsNotifications
        self.supportsBackgroundTasks = supportsBackgroundTasks
        self.supportsHandoff = supportsHandoff
        self.supportsCloudKit = supportsCloudKit
        self.supportsLocalModels = supportsLocalModels
        self.hasNeuralEngine = hasNeuralEngine
        self.hasGPU = hasGPU
        self.hasCellular = hasCellular
        self.hasWiFi = hasWiFi
        self.isPluggedIn = isPluggedIn
        self.batteryLevel = batteryLevel
    }

    public static var current: DeviceCapabilities {
        #if os(macOS)
            return DeviceCapabilities(
                supportsVoice: true,
                supportsNotifications: true,
                supportsBackgroundTasks: true,
                supportsHandoff: true,
                supportsCloudKit: true,
                supportsLocalModels: true,
                hasNeuralEngine: true,
                hasGPU: true,
                hasCellular: false,
                hasWiFi: true,
                isPluggedIn: true,
                batteryLevel: 100
            )
        #else
            return DeviceCapabilities(
                supportsVoice: true,
                supportsNotifications: true,
                supportsBackgroundTasks: true,
                supportsHandoff: true,
                supportsCloudKit: true,
                supportsLocalModels: false,
                hasNeuralEngine: true,
                hasGPU: true,
                hasCellular: true,
                hasWiFi: true,
                isPluggedIn: false,
                batteryLevel: 50
            )
        #endif
    }
}
