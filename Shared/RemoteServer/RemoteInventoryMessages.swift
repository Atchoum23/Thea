//
//  RemoteInventoryMessages.swift
//  Thea
//
//  Asset inventory message types for remote server protocol
//

import Foundation

// MARK: - Inventory Messages

public enum InventoryRequest: Codable, Sendable {
    case getHardwareInventory
    case getSoftwareInventory
    case getFullInventory
}

public enum InventoryResponse: Codable, Sendable {
    case hardwareInventory(HardwareInventory)
    case softwareInventory(SoftwareInventory)
    case error(String)
}

public struct HardwareInventory: Codable, Sendable {
    public let modelName: String
    public let modelIdentifier: String
    public let chipType: String
    public let totalCores: Int
    public let performanceCores: Int?
    public let efficiencyCores: Int?
    public let memoryGB: Int
    public let memoryType: String
    public let serialNumber: String
    public let hardwareUUID: String
    public let osVersion: String
    public let osBuild: String
    public let hostname: String
    public let uptimeSeconds: TimeInterval
    public let storageDevices: [StorageDevice]
    public let displays: [DisplayDevice]
    public let networkInterfaces: [AssetNetworkInterface]
    public let peripherals: [PeripheralDevice]
    public let batteryLevel: String?
    public let batteryHealth: String?
    public let isLaptop: Bool
}

public struct StorageDevice: Codable, Sendable {
    public let name: String
    public let totalBytes: Int64
    public let freeBytes: Int64
    public let fileSystem: String
    public let mountPoint: String
    public let isInternal: Bool
}

public struct DisplayDevice: Codable, Sendable {
    public let name: String
    public let resolution: String
    public let isBuiltIn: Bool
    public let displayID: Int?
}

public struct AssetNetworkInterface: Codable, Sendable {
    public let name: String
    public let interfaceName: String
    public let ipAddress: String?
    public let macAddress: String
    public let isActive: Bool
}

public struct PeripheralDevice: Codable, Sendable {
    public let name: String
    public let type: String
    public let vendor: String?
}

public struct SoftwareInventory: Codable, Sendable {
    public let installedApps: [InstalledApp]
    public let osVersion: String
    public let kernelVersion: String
    public let lastSoftwareUpdate: Date?
}

public struct InstalledApp: Codable, Sendable {
    public let name: String
    public let version: String
    public let bundleIdentifier: String?
    public let location: String
    public let sizeBytes: Int64?
    public let lastModified: Date?
}
