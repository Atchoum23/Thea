//
//  RemoteSystemMessages.swift
//  Thea
//
//  System control message types for remote server protocol
//

import Foundation

// MARK: - System Messages

public enum SystemRequest: Codable, Sendable {
    case getInfo
    case getProcesses
    case killProcess(pid: Int32)
    case executeCommand(command: String, workingDirectory: String?, timeout: TimeInterval?)
    case launchApp(bundleId: String, arguments: [String]?)
    case reboot
    case shutdown
    case sleep
    case wake
    case lock
    case logout
    case setVolume(level: Float)
    case setBrightness(level: Float)
    case getNotifications
    case dismissNotification(id: String)
    // Privacy mode
    case enablePrivacyMode
    case disablePrivacyMode
    // Wake-on-LAN
    case wakeOnLan(macAddress: String)
    // Asset inventory
    case getHardwareInventory
    case getSoftwareInventory
}

public enum SystemResponse: Codable, Sendable {
    case info(RemoteSystemInfo)
    case processes([RemoteProcessInfo])
    case commandOutput(exitCode: Int32, stdout: String, stderr: String)
    case appLaunched(pid: Int32)
    case confirmationRequired(action: String, confirmationId: String)
    case actionPerformed(String)
    case notifications([NotificationInfo])
    case error(String)
}

public struct RemoteSystemInfo: Codable, Sendable {
    public let hostname: String
    public let osVersion: String
    public let osName: String
    public let architecture: String
    public let cpuCount: Int
    public let totalMemory: UInt64
    public let availableMemory: UInt64
    public let totalDiskSpace: UInt64
    public let availableDiskSpace: UInt64
    public let uptime: TimeInterval
    public let batteryLevel: Float?
    public let isCharging: Bool?
    public let currentUser: String

    public init(hostname: String, osVersion: String, osName: String, architecture: String, cpuCount: Int, totalMemory: UInt64, availableMemory: UInt64, totalDiskSpace: UInt64, availableDiskSpace: UInt64, uptime: TimeInterval, batteryLevel: Float?, isCharging: Bool?, currentUser: String) {
        self.hostname = hostname
        self.osVersion = osVersion
        self.osName = osName
        self.architecture = architecture
        self.cpuCount = cpuCount
        self.totalMemory = totalMemory
        self.availableMemory = availableMemory
        self.totalDiskSpace = totalDiskSpace
        self.availableDiskSpace = availableDiskSpace
        self.uptime = uptime
        self.batteryLevel = batteryLevel
        self.isCharging = isCharging
        self.currentUser = currentUser
    }
}

public struct RemoteProcessInfo: Codable, Sendable, Identifiable {
    public let id: Int32
    public let name: String
    public let path: String?
    public let user: String
    public let cpuUsage: Double
    public let memoryUsage: UInt64
    public let startTime: Date?
    public let parentPID: Int32

    public init(id: Int32, name: String, path: String?, user: String, cpuUsage: Double, memoryUsage: UInt64, startTime: Date?, parentPID: Int32) {
        self.id = id
        self.name = name
        self.path = path
        self.user = user
        self.cpuUsage = cpuUsage
        self.memoryUsage = memoryUsage
        self.startTime = startTime
        self.parentPID = parentPID
    }
}

public struct NotificationInfo: Codable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let body: String
    public let appName: String
    public let timestamp: Date
}
