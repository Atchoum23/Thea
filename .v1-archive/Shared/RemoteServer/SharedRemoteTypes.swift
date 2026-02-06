//
//  SharedRemoteTypes.swift
//  Thea
//
//  Shared types for remote server functionality
//  These types are used across platforms even though the server itself is macOS-only
//

import Foundation

// MARK: - Transfer Statistics

public struct TransferStatistics: Sendable {
    public var bytesReceived: Int64 = 0
    public var bytesSent: Int64 = 0
    public var messagesReceived: Int64 = 0
    public var messagesSent: Int64 = 0
    public var screenFramesSent: Int64 = 0
    public var filesTransferred: Int64 = 0

    public init() {}
}

// MARK: - Security Event

public struct SecurityEvent: Identifiable, Sendable {
    public let id = UUID()
    public let type: SecurityEventType
    public let details: String
    public let timestamp: Date

    public init(type: SecurityEventType, details: String, timestamp: Date = Date()) {
        self.type = type
        self.details = details
        self.timestamp = timestamp
    }
}

public enum SecurityEventType: String, Codable, Sendable {
    case serverStarted
    case serverStopped
    case serverError
    case clientConnected
    case clientDisconnected
    case connectionRejected
    case authenticationFailed
    case permissionDenied
    case rateLimitExceeded
    case suspiciousActivity
    case fileAccessBlocked
    case commandBlocked
}

// MARK: - Authentication Method

public enum AuthenticationMethod: String, Codable, Sendable, CaseIterable {
    case pairingCode // One-time pairing code
    case sharedSecret // Pre-shared secret
    case certificate // Client certificate
    case iCloudIdentity // Same iCloud account
    case biometric // Require biometric on server

    public var displayName: String {
        switch self {
        case .pairingCode: "Pairing Code"
        case .sharedSecret: "Shared Secret"
        case .certificate: "Client Certificate"
        case .iCloudIdentity: "iCloud Identity"
        case .biometric: "Biometric Verification"
        }
    }
}

// MARK: - Server Status

public enum ServerStatus: Sendable, Equatable {
    case stopped
    case starting
    case running
    case stopping
    case error(String)

    public var isActive: Bool {
        switch self {
        case .running, .starting: true
        default: false
        }
    }
}

// MARK: - Remote Client

public struct RemoteClient: Identifiable, Codable, Sendable {
    public let id: String
    public let name: String
    public let deviceType: DeviceType
    public let ipAddress: String
    public let connectedAt: Date
    public var lastActivityAt: Date
    public let permissions: Set<RemotePermission>

    public enum DeviceType: String, Codable, Sendable {
        case mac
        case iPhone
        case iPad
        case unknown
    }

    public init(
        id: String,
        name: String,
        deviceType: DeviceType,
        ipAddress: String,
        connectedAt: Date = Date(),
        lastActivityAt: Date = Date(),
        permissions: Set<RemotePermission>
    ) {
        self.id = id
        self.name = name
        self.deviceType = deviceType
        self.ipAddress = ipAddress
        self.connectedAt = connectedAt
        self.lastActivityAt = lastActivityAt
        self.permissions = permissions
    }
}

// MARK: - Remote Permission

public enum RemotePermission: String, Codable, Sendable, CaseIterable {
    case viewScreen
    case controlScreen
    case viewFiles
    case readFiles
    case writeFiles
    case deleteFiles
    case executeCommands
    case systemControl
    case networkAccess

    public var displayName: String {
        switch self {
        case .viewScreen: "View Screen"
        case .controlScreen: "Control Screen"
        case .viewFiles: "View Files"
        case .readFiles: "Read Files"
        case .writeFiles: "Write Files"
        case .deleteFiles: "Delete Files"
        case .executeCommands: "Execute Commands"
        case .systemControl: "System Control"
        case .networkAccess: "Network Access"
        }
    }

    public var riskLevel: RiskLevel {
        switch self {
        case .viewScreen, .viewFiles: .low
        case .controlScreen, .readFiles: .medium
        case .writeFiles, .executeCommands, .networkAccess: .high
        case .deleteFiles, .systemControl: .critical
        }
    }

    public enum RiskLevel: Int, Sendable, Comparable {
        case low = 0
        case medium = 1
        case high = 2
        case critical = 3

        public static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
}

// MARK: - Remote Server Error

public enum RemoteServerError: Error, LocalizedError, Sendable {
    case notSupported(String)
    case notRunning
    case alreadyRunning
    case authenticationFailed(String)
    case permissionDenied(String)
    case connectionFailed(String)
    case networkError(String)
    case featureDisabled(String)
    case timeout
    case invalidMessage
    case serverFull

    public var errorDescription: String? {
        switch self {
        case let .notSupported(message): message
        case .notRunning: "Server is not running"
        case .alreadyRunning: "Server is already running"
        case let .authenticationFailed(reason): "Authentication failed: \(reason)"
        case let .permissionDenied(action): "Permission denied for: \(action)"
        case let .connectionFailed(reason): "Connection failed: \(reason)"
        case let .networkError(reason): "Network error: \(reason)"
        case let .featureDisabled(feature): "Feature disabled: \(feature)"
        case .timeout: "Operation timed out"
        case .invalidMessage: "Invalid message received"
        case .serverFull: "Server has reached maximum connections"
        }
    }
}
