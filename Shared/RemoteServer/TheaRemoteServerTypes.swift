//
//  TheaRemoteServerTypes.swift
//  Thea
//
//  Supporting types and non-macOS stubs for TheaRemoteServer
//  Copyright 2026. All rights reserved.
//

import Combine
import Foundation
import os.log

// MARK: - Server Configuration (macOS)

#if os(macOS)

    public struct RemoteServerConfiguration: Codable, Sendable {
        public var serverName: String
        public var port: UInt16
        public var maxConnections: Int
        public var authMethod: AuthenticationMethod
        public var authTimeout: TimeInterval
        public var requireConfirmation: Bool
        public var enableDiscovery: Bool
        public var enableScreenSharing: Bool
        public var enableInputControl: Bool
        public var enableFileAccess: Bool
        public var enableSystemControl: Bool
        public var enableNetworkProxy: Bool
        public var useWhitelist: Bool
        public var whitelist: [String]
        public var encryptionRequired: Bool
        public var sessionTimeout: TimeInterval
        public var maxFileTransferSize: Int64
        public var allowedPaths: [String]
        public var blockedPaths: [String]

        // Extended feature toggles
        public var enableClipboardSync: Bool
        public var enableUnattendedAccess: Bool
        public var enableSessionRecording: Bool
        public var autoRecordSessions: Bool
        public var enableAudioStreaming: Bool
        public var enableChatAnnotations: Bool
        public var enableTwoFactor: Bool
        public var auditLogRetentionDays: Int

        public init(
            serverName: String = "Thea Remote",
            port: UInt16 = 9847,
            maxConnections: Int = 5,
            authMethod: AuthenticationMethod = .pairingCode,
            authTimeout: TimeInterval = 30,
            requireConfirmation: Bool = true,
            enableDiscovery: Bool = false,
            enableScreenSharing: Bool = true,
            enableInputControl: Bool = true,
            enableFileAccess: Bool = true,
            enableSystemControl: Bool = false,
            enableNetworkProxy: Bool = false,
            useWhitelist: Bool = false,
            whitelist: [String] = [],
            encryptionRequired: Bool = true,
            sessionTimeout: TimeInterval = 3600,
            maxFileTransferSize: Int64 = 1_073_741_824,
            allowedPaths: [String] = [],
            blockedPaths: [String] = ["/etc", "/var", "/private", "/System"],
            enableClipboardSync: Bool = true,
            enableUnattendedAccess: Bool = false,
            enableSessionRecording: Bool = false,
            autoRecordSessions: Bool = false,
            enableAudioStreaming: Bool = false,
            enableChatAnnotations: Bool = true,
            enableTwoFactor: Bool = false,
            auditLogRetentionDays: Int = 90
        ) {
            self.serverName = serverName
            self.port = port
            self.maxConnections = maxConnections
            self.authMethod = authMethod
            self.authTimeout = authTimeout
            self.requireConfirmation = requireConfirmation
            self.enableDiscovery = enableDiscovery
            self.enableScreenSharing = enableScreenSharing
            self.enableInputControl = enableInputControl
            self.enableFileAccess = enableFileAccess
            self.enableSystemControl = enableSystemControl
            self.enableNetworkProxy = enableNetworkProxy
            self.useWhitelist = useWhitelist
            self.whitelist = whitelist
            self.encryptionRequired = encryptionRequired
            self.sessionTimeout = sessionTimeout
            self.maxFileTransferSize = maxFileTransferSize
            self.allowedPaths = allowedPaths
            self.blockedPaths = blockedPaths
            self.enableClipboardSync = enableClipboardSync
            self.enableUnattendedAccess = enableUnattendedAccess
            self.enableSessionRecording = enableSessionRecording
            self.autoRecordSessions = autoRecordSessions
            self.enableAudioStreaming = enableAudioStreaming
            self.enableChatAnnotations = enableChatAnnotations
            self.enableTwoFactor = enableTwoFactor
            self.auditLogRetentionDays = auditLogRetentionDays
        }

        private static let storageKey = "RemoteServerConfiguration"

        public static func load() -> RemoteServerConfiguration {
            guard let data = UserDefaults.standard.data(forKey: storageKey) else {
                return RemoteServerConfiguration()
            }
            do {
                return try JSONDecoder().decode(RemoteServerConfiguration.self, from: data)
            } catch {
                let logger = Logger(subsystem: "ai.thea.app", category: "TheaRemoteServer")
                logger.error("RemoteServerConfiguration: failed to decode configuration: \(error.localizedDescription)")
                return RemoteServerConfiguration()
            }
        }

        public func save() {
            do {
                let data = try JSONEncoder().encode(self)
                UserDefaults.standard.set(data, forKey: RemoteServerConfiguration.storageKey)
            } catch {
                let logger = Logger(subsystem: "ai.thea.app", category: "TheaRemoteServer")
                logger.error("RemoteServerConfiguration: failed to encode configuration: \(error.localizedDescription)")
            }
        }
    }

    // NOTE: AuthenticationMethod, ServerStatus, RemoteClient, RemotePermission, RemoteServerError,
    // TransferStatistics, SecurityEvent, and SecurityEventType are defined in SharedRemoteTypes.swift

#else

    // MARK: - iOS/watchOS/tvOS Stub Implementation

    /// Stub implementation for non-macOS platforms
    /// Remote server functionality is only available on macOS
    @MainActor
    public class TheaRemoteServer: ObservableObject {
        public static let shared = TheaRemoteServer()

        @Published public private(set) var isRunning = false
        @Published public private(set) var serverStatus: ServerStatus = .stopped
        @Published public private(set) var connectedClients: [RemoteClient] = []
        @Published public private(set) var serverAddress: String?
        @Published public private(set) var serverPort: UInt16 = 0
        @Published public private(set) var transferStats: TransferStatistics = .init()
        @Published public private(set) var securityEvents: [SecurityEvent] = []

        public let configuration = RemoteServerConfiguration()
        public let sessionManager = RemoteSessionManagerStub()
        public let connectionManager = SecureConnectionManagerStub()

        private init() {}

        public func start() async throws {
            throw RemoteServerError.notSupported("Remote server is only available on macOS")
        }

        public func stop() async {
            // No-op on iOS
        }
    }

    /// Stub for session manager on non-macOS platforms
    public class RemoteSessionManagerStub: ObservableObject {
        public func terminateSession(_: String, reason _: String) async {}
    }

    /// Stub for connection manager on non-macOS platforms
    public class SecureConnectionManagerStub: ObservableObject {
        public var whitelist: Set<String> = []
        public func generatePairingCode() -> String { "000000" }
        public func addToWhitelist(_: String) {}
        public func removeFromWhitelist(_: String) {}
    }

    /// Stub configuration for non-macOS platforms
    public class RemoteServerConfiguration: ObservableObject {
        @Published public var serverName: String = "Thea"
        @Published public var port: UInt16 = 6767
        @Published public var maxConnections: Int = 5
        @Published public var authMethod: AuthenticationMethod = .pairingCode
        @Published public var requireConfirmation: Bool = true
        @Published public var enableDiscovery: Bool = true
        @Published public var enableScreenSharing: Bool = false
        @Published public var enableInputControl: Bool = false
        @Published public var enableFileAccess: Bool = false
        @Published public var enableSystemControl: Bool = false
        @Published public var enableNetworkProxy: Bool = false
        @Published public var encryptionRequired: Bool = true
        @Published public var useWhitelist: Bool = false
        @Published public var sessionTimeout: TimeInterval = 3600
        @Published public var enableClipboardSync: Bool = false
        @Published public var enableUnattendedAccess: Bool = false
        @Published public var enableSessionRecording: Bool = false
        @Published public var autoRecordSessions: Bool = false
        @Published public var enableAudioStreaming: Bool = false
        @Published public var enableChatAnnotations: Bool = false
        @Published public var enableTwoFactor: Bool = false
        @Published public var auditLogRetentionDays: Int = 90
    }

#endif
