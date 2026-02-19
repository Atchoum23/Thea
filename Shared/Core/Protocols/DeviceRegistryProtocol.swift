//
//  DeviceRegistryProtocol.swift
//  Thea
//
//  Protocol abstraction for DeviceRegistry, enabling testability
//  and dependency injection across 53+ call sites.
//

import Foundation

// MARK: - Device Registry Protocol

/// Abstracts the DeviceRegistry singleton for testability and dependency injection.
///
/// This protocol captures the public API of DeviceRegistry — used by ChatManager,
/// TheaIdentityPrompt, DistributedTaskExecutor, RemoteCommandService, and UI views
/// to discover and manage devices in the Thea ecosystem.
///
/// **What this enables:**
/// - Unit tests can inject a mock registry with simulated multi-device scenarios
/// - Cross-device features can be tested without needing physical devices
/// - Alternative device discovery backends (e.g., CloudKit-based) can conform
@MainActor
protocol DeviceRegistryProtocol: AnyObject {

    // MARK: - Current Device

    /// The device this app instance is running on
    var currentDevice: DeviceInfo { get }

    // MARK: - Registry

    /// All registered devices (may include offline ones)
    var registeredDevices: [DeviceInfo] { get }

    /// Devices with recent presence (last 5 minutes)
    var onlineDevices: [DeviceInfo] { get }

    // MARK: - Presence

    /// Update current device's last-seen timestamp
    func updatePresence()

    // MARK: - Device Management

    /// Add or update a device in the registry
    func registerDevice(_ device: DeviceInfo)

    /// Remove a device by ID
    func removeDevice(_ deviceId: String)

    /// Remove all devices except the current one
    func removeAllOtherDevices()

    // MARK: - Query

    /// Look up a device by its ID
    func getDevice(_ id: String) -> DeviceInfo?

    /// Check whether a device has been seen recently
    func isDeviceOnline(_ id: String) -> Bool
}
