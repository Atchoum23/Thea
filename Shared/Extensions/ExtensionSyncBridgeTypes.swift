//
//  ExtensionSyncBridgeTypes.swift
//  Thea
//
//  Supporting types and protocols for ExtensionSyncBridge
//

import Foundation

// MARK: - Extension Feature Protocols

// These protocols allow the sync bridge to work with extension managers
// that are defined in the Extensions target

/// Protocol for feature managers that can be enabled/disabled
@MainActor
public protocol ExtensionFeatureManager: AnyObject {
    var isEnabled: Bool { get set }
}

/// Protocol for the ad blocker manager
@MainActor
public protocol AdBlockerManagerProtocol: ExtensionFeatureManager {}

/// Protocol for the dark mode manager
@MainActor
public protocol DarkModeManagerProtocol: ExtensionFeatureManager {
    associatedtype Theme: Identifiable where Theme.ID == String
    var globalTheme: Theme { get }
}

/// Protocol for the privacy protection manager
@MainActor
public protocol PrivacyProtectionManagerProtocol: ExtensionFeatureManager {}

/// Protocol for the password manager
@MainActor
public protocol PasswordManagerProtocol: AnyObject {
    var isLocked: Bool { get }
    func getCredentials(for domain: String) async throws -> [Any]
}

/// Protocol for email protection manager
@MainActor
public protocol EmailProtectionManagerProtocol: AnyObject {
    associatedtype AliasType: EmailAliasProtocol
    associatedtype SettingsType: EmailProtectionSettingsProtocol
    var settings: SettingsType { get }
    func generateAlias(for domain: String) async throws -> AliasType
}

/// Protocol for email alias
public protocol EmailAliasProtocol: Sendable {
    var id: String { get }
    var alias: String { get }
    var domain: String { get }
}

/// Protocol for email protection settings
public protocol EmailProtectionSettingsProtocol {
    var autoRemoveTrackers: Bool { get }
}

/// Protocol for print friendly manager
@MainActor
public protocol PrintFriendlyManagerProtocol: AnyObject {
    associatedtype SettingsType: PrintFriendlySettingsProtocol
    var settings: SettingsType { get }
}

/// Protocol for print friendly settings
public protocol PrintFriendlySettingsProtocol {
    var autoDetectMainContent: Bool { get }
}

/// Global extension stats
public struct ExtensionStats {
    public var adsBlocked: Int = 0
    public var trackersBlocked: Int = 0
    public var emailsProtected: Int = 0
    public var passwordsAutofilled: Int = 0
    public var pagesDarkened: Int = 0

    public init() {}
}

/// Email alias type used by the sync bridge
public struct EmailAlias: Sendable, EmailAliasProtocol {
    public let id: String
    public let alias: String
    public let domain: String

    public init(id: String, alias: String, domain: String) {
        self.id = id
        self.alias = alias
        self.domain = domain
    }
}

// MARK: - Supporting Types

public struct ExtensionConnection: Identifiable {
    public let id = UUID()
    public let connectionId: String
    public let type: ExtensionType
    public let version: String
    public let connectedAt: Date
    public var lastHeartbeat: Date
}

public enum ExtensionType: String, Codable {
    case safari
    case chrome
    case brave
}

public struct SyncMessage: Codable {
    public let type: MessageType
    public let data: [String: AnyCodable]
    public let timestamp: Date

    public enum MessageType: String, Codable {
        case identify
        case sync
        case stateUpdate
        case featureToggle
        case credentialRequest
        case credentialResponse
        case credentialUpdate
        case aliasRequest
        case aliasResponse
        case aliasCreated
        case statsUpdate
        case themeChange
        case heartbeat
    }

    public init(type: MessageType, data: [String: AnyCodable]) {
        self.type = type
        self.data = data
        timestamp = Date()
    }
}

public struct SyncSettings: Codable {
    public var autoSync: Bool = true
    public var syncInterval: TimeInterval = 30
    public var syncOnAppForeground: Bool = true
    public var syncStats: Bool = true
    public var syncCredentials: Bool = true
    public var syncAliases: Bool = true
    public var syncThemes: Bool = true
}

// MARK: - Extension Sync Notifications

public extension Notification.Name {
    static let extensionCredentialRequest = Notification.Name("thea.extension.credentialRequest")
    static let extensionAliasRequest = Notification.Name("thea.extension.aliasRequest")
    static let extensionStateChanged = Notification.Name("thea.extension.stateChanged")
}
