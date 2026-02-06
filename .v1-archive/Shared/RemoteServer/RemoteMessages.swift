//
//  RemoteMessages.swift
//  Thea
//
//  Created by Claude Code on 2026-01-22
//  Copyright © 2026. All rights reserved.
//

import CoreGraphics
import Foundation

// MARK: - Remote Message Protocol

/// All messages exchanged between Thea remote server and clients
public enum RemoteMessage: Codable, Sendable {
    // Authentication
    case authChallenge(AuthChallenge)
    case authResponse(AuthResponse)
    case authSuccess(Set<RemotePermission>)
    case authFailure(String)

    // Screen sharing
    case screenRequest(ScreenRequest)
    case screenResponse(ScreenResponse)

    // Input control
    case inputRequest(InputRequest)
    case inputAck

    // File operations
    case fileRequest(FileRequest)
    case fileResponse(FileResponse)

    // System control
    case systemRequest(SystemRequest)
    case systemResponse(SystemResponse)

    // Network proxy
    case networkRequest(NetworkProxyRequest)
    case networkResponse(NetworkProxyResponse)

    // Connection management
    case ping
    case pong
    case disconnect
    case error(String)

    // Required permission for this message type
    public var requiredPermission: RemotePermission {
        switch self {
        case .screenRequest: .viewScreen
        case .inputRequest: .controlScreen
        case let .fileRequest(req):
            switch req {
            case .list, .info: .viewFiles
            case .read, .download: .readFiles
            case .write, .upload, .createDirectory, .move, .copy: .writeFiles
            case .delete: .deleteFiles
            }
        case let .systemRequest(req):
            switch req {
            case .getInfo, .getProcesses: .viewScreen
            case .executeCommand: .executeCommands
            default: .systemControl
            }
        case .networkRequest: .networkAccess
        default: .viewScreen
        }
    }
}

// MARK: - Authentication Messages

public struct AuthChallenge: Codable, Sendable {
    public let challengeId: String
    public let nonce: Data
    public let timestamp: Date
    public let serverPublicKey: Data?

    public init(challengeId: String = UUID().uuidString, nonce: Data, timestamp: Date = Date(), serverPublicKey: Data? = nil) {
        self.challengeId = challengeId
        self.nonce = nonce
        self.timestamp = timestamp
        self.serverPublicKey = serverPublicKey
    }
}

public struct AuthResponse: Codable, Sendable {
    public let challengeId: String
    public let signature: Data
    public let clientName: String
    public let clientType: RemoteClient.DeviceType
    public let clientPublicKey: Data?
    public let requestedPermissions: Set<RemotePermission>
    public let pairingCode: String?
    public let sharedSecret: Data?

    public init(
        challengeId: String,
        signature: Data,
        clientName: String,
        clientType: RemoteClient.DeviceType,
        clientPublicKey: Data? = nil,
        requestedPermissions: Set<RemotePermission>,
        pairingCode: String? = nil,
        sharedSecret: Data? = nil
    ) {
        self.challengeId = challengeId
        self.signature = signature
        self.clientName = clientName
        self.clientType = clientType
        self.clientPublicKey = clientPublicKey
        self.requestedPermissions = requestedPermissions
        self.pairingCode = pairingCode
        self.sharedSecret = sharedSecret
    }
}

// MARK: - Screen Messages

public enum ScreenRequest: Codable, Sendable {
    case captureFullScreen(quality: Float, scale: Float)
    case captureWindow(windowId: Int, quality: Float)
    case captureRegion(x: Int, y: Int, width: Int, height: Int, quality: Float)
    case startStream(fps: Int, quality: Float, scale: Float)
    case stopStream
    case getDisplayInfo
    case getWindowList
}

public enum ScreenResponse: Codable, Sendable {
    case frame(ScreenFrame)
    case displayInfo(DisplayInfo)
    case windowList([RemoteWindowInfo])
    case streamStarted(streamId: String)
    case streamStopped
    case error(String)
}

public struct ScreenFrame: Codable, Sendable {
    public let timestamp: Date
    public let width: Int
    public let height: Int
    public let format: ImageFormat
    public let data: Data
    public let isKeyFrame: Bool
    public let cursorPosition: CGPoint?
    public let cursorVisible: Bool

    public enum ImageFormat: String, Codable, Sendable {
        case jpeg
        case png
        case heic
        case h264
        case h265
    }

    public init(timestamp: Date = Date(), width: Int, height: Int, format: ImageFormat, data: Data, isKeyFrame: Bool = true, cursorPosition: CGPoint? = nil, cursorVisible: Bool = true) {
        self.timestamp = timestamp
        self.width = width
        self.height = height
        self.format = format
        self.data = data
        self.isKeyFrame = isKeyFrame
        self.cursorPosition = cursorPosition
        self.cursorVisible = cursorVisible
    }
}

public struct DisplayInfo: Codable, Sendable {
    public let displays: [DisplayDetails]

    public struct DisplayDetails: Codable, Sendable {
        public let id: Int
        public let name: String
        public let width: Int
        public let height: Int
        public let scaleFactor: Double
        public let isMain: Bool
        public let frame: CGRect
    }
}

public struct RemoteWindowInfo: Codable, Sendable {
    public let id: Int
    public let title: String
    public let ownerName: String
    public let ownerPID: Int
    public let frame: CGRect
    public let isOnScreen: Bool
    public let layer: Int

    public init(id: Int, title: String, ownerName: String, ownerPID: Int, frame: CGRect, isOnScreen: Bool, layer: Int) {
        self.id = id
        self.title = title
        self.ownerName = ownerName
        self.ownerPID = ownerPID
        self.frame = frame
        self.isOnScreen = isOnScreen
        self.layer = layer
    }
}

// MARK: - Input Messages

public enum InputRequest: Codable, Sendable {
    // Mouse
    case mouseMove(x: Int, y: Int)
    case mouseClick(x: Int, y: Int, button: MouseButton, clickCount: Int)
    case mouseDown(x: Int, y: Int, button: MouseButton)
    case mouseUp(x: Int, y: Int, button: MouseButton)
    case mouseDrag(fromX: Int, fromY: Int, toX: Int, toY: Int, button: MouseButton)
    case scroll(x: Int, y: Int, deltaX: Int, deltaY: Int)

    // Keyboard
    case keyPress(keyCode: UInt16, modifiers: RemoteKeyModifiers)
    case keyDown(keyCode: UInt16, modifiers: RemoteKeyModifiers)
    case keyUp(keyCode: UInt16, modifiers: RemoteKeyModifiers)
    case typeText(String)

    // Clipboard
    case setClipboard(String)
    case getClipboard

    public enum MouseButton: String, Codable, Sendable {
        case left
        case right
        case middle
    }
}

public struct RemoteKeyModifiers: OptionSet, Codable, Sendable {
    public let rawValue: UInt

    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    public static let shift = RemoteKeyModifiers(rawValue: 1 << 0)
    public static let control = RemoteKeyModifiers(rawValue: 1 << 1)
    public static let option = RemoteKeyModifiers(rawValue: 1 << 2)
    public static let command = RemoteKeyModifiers(rawValue: 1 << 3)
    public static let function = RemoteKeyModifiers(rawValue: 1 << 4)
    public static let capsLock = RemoteKeyModifiers(rawValue: 1 << 5)
}

// MARK: - File Messages

public enum FileRequest: Codable, Sendable {
    case list(path: String, recursive: Bool, showHidden: Bool)
    case info(path: String)
    case read(path: String, offset: Int64, length: Int64)
    case write(path: String, data: Data, offset: Int64, append: Bool)
    case delete(path: String, recursive: Bool)
    case move(from: String, to: String)
    case copy(from: String, to: String)
    case createDirectory(path: String, intermediate: Bool)
    case download(path: String)
    case upload(path: String, data: Data, overwrite: Bool)
}

public enum FileResponse: Codable, Sendable {
    case listing([FileItem])
    case info(FileItem)
    case data(Data, isComplete: Bool)
    case success(String)
    case error(String)
    case progress(bytesTransferred: Int64, totalBytes: Int64)
}

public struct FileItem: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let path: String
    public let isDirectory: Bool
    public let size: Int64
    public let createdAt: Date?
    public let modifiedAt: Date?
    public let permissions: String
    public let isHidden: Bool
    public let isSymlink: Bool
    public let symlinkTarget: String?

    public init(
        name: String,
        path: String,
        isDirectory: Bool,
        size: Int64,
        createdAt: Date? = nil,
        modifiedAt: Date? = nil,
        permissions: String = "",
        isHidden: Bool = false,
        isSymlink: Bool = false,
        symlinkTarget: String? = nil
    ) {
        id = path
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.size = size
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.permissions = permissions
        self.isHidden = isHidden
        self.isSymlink = isSymlink
        self.symlinkTarget = symlinkTarget
    }
}

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

// MARK: - Network Proxy Messages

public enum NetworkProxyRequest: Codable, Sendable {
    case httpRequest(url: URL, method: String, headers: [String: String], body: Data?)
    case tcpConnect(host: String, port: Int)
    case localNetworkScan
}

public enum NetworkProxyResponse: Codable, Sendable {
    case httpResponse(statusCode: Int, headers: [String: String], body: Data)
    case tcpEstablished(connectionId: String)
    case tcpData(connectionId: String, data: Data)
    case tcpClosed(connectionId: String)
    case networkDevices([NetworkDevice])
    case error(String)
}

public struct NetworkDevice: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let ipAddress: String
    public let macAddress: String?
    public let deviceType: String?
    public let isOnline: Bool
    public let lastSeen: Date
    public let services: [NetworkService]

    public struct NetworkService: Codable, Sendable {
        public let name: String
        public let type: String
        public let port: Int
    }
}

// MARK: - Message Serialization

public extension RemoteMessage {
    /// Encode message to data for transmission
    func encode() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    /// Decode message from received data
    static func decode(from data: Data) throws -> RemoteMessage {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(RemoteMessage.self, from: data)
    }
}
