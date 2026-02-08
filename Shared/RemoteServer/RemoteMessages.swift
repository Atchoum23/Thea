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

    // Clipboard sync
    case clipboardRequest(ClipboardRequest)
    case clipboardResponse(ClipboardResponse)

    // Session chat
    case chatMessage(ChatMessageData)

    // Annotations
    case annotationRequest(AnnotationRequest)

    // Recording
    case recordingRequest(RecordingRequest)
    case recordingResponse(RecordingResponse)

    // Audio streaming
    case audioRequest(AudioRequest)
    case audioResponse(AudioResponse)

    // Inventory
    case inventoryRequest(InventoryRequest)
    case inventoryResponse(InventoryResponse)

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
        case .clipboardRequest, .clipboardResponse: .controlScreen
        case .chatMessage: .viewScreen
        case .annotationRequest: .viewScreen
        case .recordingRequest, .recordingResponse: .viewScreen
        case .audioRequest, .audioResponse: .viewScreen
        case .inventoryRequest, .inventoryResponse: .viewScreen
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
    // Multi-monitor support
    case captureDisplay(displayId: Int, quality: Float, scale: Float)
    case startStreamForDisplay(displayId: Int, fps: Int, quality: Float, scale: Float)
    // Video codec configuration
    case configureStream(codec: VideoCodec, profile: StreamQualityProfile)
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

// MARK: - Clipboard Messages

public enum ClipboardRequest: Codable, Sendable {
    case getClipboard
    case setClipboard(ClipboardData)
    case startSync
    case stopSync
}

public enum ClipboardResponse: Codable, Sendable {
    case clipboardData(ClipboardData)
    case syncStarted
    case syncStopped
    case error(String)
}

public struct ClipboardData: Codable, Sendable {
    public let type: ClipboardContentType
    public let data: Data
    public let uti: String?
    public let timestamp: Date

    public init(type: ClipboardContentType, data: Data, uti: String? = nil, timestamp: Date = Date()) {
        self.type = type
        self.data = data
        self.uti = uti
        self.timestamp = timestamp
    }

    public enum ClipboardContentType: String, Codable, Sendable {
        case text
        case image
        case fileReference
        case rtf
    }
}

// MARK: - Chat Messages

public struct ChatMessageData: Codable, Sendable, Identifiable {
    public let id: String
    public let senderId: String
    public let senderName: String
    public let text: String
    public let timestamp: Date

    public init(senderId: String, senderName: String, text: String) {
        id = UUID().uuidString
        self.senderId = senderId
        self.senderName = senderName
        self.text = text
        timestamp = Date()
    }
}

// MARK: - Annotation Messages

public enum AnnotationRequest: Codable, Sendable {
    case addAnnotation(AnnotationData)
    case removeAnnotation(id: String)
    case clearAnnotations
    case undoLastAnnotation
}

public struct AnnotationData: Codable, Sendable, Identifiable {
    public let id: String
    public let shape: AnnotationShape
    public let color: AnnotationColor
    public let lineWidth: Float
    public let points: [CGPoint]
    public let text: String?
    public let timestamp: Date

    public init(shape: AnnotationShape, color: AnnotationColor, lineWidth: Float = 2.0, points: [CGPoint], text: String? = nil) {
        id = UUID().uuidString
        self.shape = shape
        self.color = color
        self.lineWidth = lineWidth
        self.points = points
        self.text = text
        timestamp = Date()
    }

    public enum AnnotationShape: String, Codable, Sendable {
        case freehand
        case line
        case arrow
        case rectangle
        case circle
        case text
        case highlight
    }

    public struct AnnotationColor: Codable, Sendable {
        public let red: Float
        public let green: Float
        public let blue: Float
        public let alpha: Float

        public init(red: Float, green: Float, blue: Float, alpha: Float = 1.0) {
            self.red = red
            self.green = green
            self.blue = blue
            self.alpha = alpha
        }

        public static let red = AnnotationColor(red: 1, green: 0, blue: 0)
        public static let blue = AnnotationColor(red: 0, green: 0, blue: 1)
        public static let green = AnnotationColor(red: 0, green: 1, blue: 0)
        public static let yellow = AnnotationColor(red: 1, green: 1, blue: 0, alpha: 0.5)
    }
}

// MARK: - Recording Messages

public enum RecordingRequest: Codable, Sendable {
    case startRecording(sessionId: String)
    case stopRecording
    case listRecordings
    case deleteRecording(id: String)
}

public enum RecordingResponse: Codable, Sendable {
    case recordingStarted(recordingId: String)
    case recordingStopped(recordingId: String, durationSeconds: Double, fileSizeBytes: Int64)
    case recordingList([RecordingMetadata])
    case error(String)
}

public struct RecordingMetadata: Codable, Sendable, Identifiable {
    public let id: String
    public let sessionId: String
    public let startTime: Date
    public let durationSeconds: Double
    public let fileSizeBytes: Int64
    public let resolution: String
    public let codec: String
    public let filePath: String

    public init(id: String, sessionId: String, startTime: Date, durationSeconds: Double, fileSizeBytes: Int64, resolution: String, codec: String, filePath: String) {
        self.id = id
        self.sessionId = sessionId
        self.startTime = startTime
        self.durationSeconds = durationSeconds
        self.fileSizeBytes = fileSizeBytes
        self.resolution = resolution
        self.codec = codec
        self.filePath = filePath
    }
}

// MARK: - Audio Messages

public enum AudioRequest: Codable, Sendable {
    case startAudioStream(sampleRate: Int, channels: Int)
    case stopAudioStream
    case setAudioVolume(Float)
    case startMicrophoneForward
    case stopMicrophoneForward
}

public enum AudioResponse: Codable, Sendable {
    case audioFrame(AudioFrame)
    case audioStreamStarted
    case audioStreamStopped
    case error(String)
}

public struct AudioFrame: Codable, Sendable {
    public let data: Data
    public let codec: AudioCodecType
    public let sampleRate: Int
    public let channels: Int
    public let timestamp: Double

    public init(data: Data, codec: AudioCodecType, sampleRate: Int, channels: Int, timestamp: Double) {
        self.data = data
        self.codec = codec
        self.sampleRate = sampleRate
        self.channels = channels
        self.timestamp = timestamp
    }

    public enum AudioCodecType: String, Codable, Sendable {
        case opus
        case aac
        case pcm
    }
}

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
