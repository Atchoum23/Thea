// TheaExtensionCore.swift
// Shared core infrastructure for Thea browser extensions
// Supports Safari, Chrome, and Brave across macOS, iOS, iPadOS

import Combine
import Foundation
import OSLog

// MARK: - Extension Communication Protocol

/// Protocol for communication between Thea app and browser extensions
public protocol TheaExtensionCommunicator: Sendable {
    func sendMessage(_ message: ExtensionMessage) async throws -> ExtensionResponse
    func subscribe(to channel: String, handler: @escaping @Sendable (ExtensionEvent) -> Void)
    func unsubscribe(from channel: String)
}

// MARK: - Message Types

/// Messages sent between app and extension
public struct ExtensionMessage: Codable, Sendable {
    public let id: String
    public let type: MessageType
    public let action: String
    public let payload: [String: AnyCodable]
    public let timestamp: Date

    public enum MessageType: String, Codable, Sendable {
        case request
        case response
        case event
        case sync
        case error
    }

    public init(
        id: String = UUID().uuidString,
        type: MessageType,
        action: String,
        payload: [String: AnyCodable] = [:],
        timestamp: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.action = action
        self.payload = payload
        self.timestamp = timestamp
    }
}

/// Response from extension operations
public struct ExtensionResponse: Codable, Sendable {
    public let messageId: String
    public let success: Bool
    public let data: [String: AnyCodable]?
    public let error: ExtensionError?
}

/// Events emitted by extensions
public struct ExtensionEvent: Codable, Sendable {
    public let channel: String
    public let eventType: String
    public let data: [String: AnyCodable]
    public let timestamp: Date
}

/// Extension error type
public struct ExtensionError: Error, Codable, Sendable {
    public let code: Int
    public let message: String
    public let details: String?
}

// MARK: - AnyCodable Helper

public struct AnyCodable: Codable, Sendable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map(\.value)
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unable to decode value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: container.codingPath, debugDescription: "Unable to encode value"))
        }
    }
}

// MARK: - Extension State

/// Shared state for all Thea extension features
@MainActor
public final class TheaExtensionState: ObservableObject {
    public static let shared = TheaExtensionState()

    // Feature States
    @Published public var printFriendlyEnabled = true
    @Published public var emailProtectionEnabled = true
    @Published public var passwordManagerEnabled = true
    @Published public var darkModeEnabled = true
    @Published public var adBlockerEnabled = true
    @Published public var privacyProtectionEnabled = true
    @Published public var tabManagerEnabled = true
    @Published public var aiAssistantEnabled = true

    // Connection State
    @Published public var isConnectedToApp = false
    @Published public var lastSyncTime: Date?
    @Published public var syncStatus: SyncStatus = .idle

    public enum SyncStatus: String {
        case idle
        case syncing
        case success
        case error
    }

    // Statistics
    @Published public var stats = ExtensionStats()

    private init() {
        loadState()
    }

    private func loadState() {
        // Load from UserDefaults/Keychain
    }

    public func saveState() {
        // Save to UserDefaults/Keychain
    }
}

/// Extension usage statistics
public struct ExtensionStats: Codable {
    public var adsBlocked: Int = 0
    public var trackersBlocked: Int = 0
    public var emailsProtected: Int = 0
    public var passwordsAutofilled: Int = 0
    public var pagesDarkened: Int = 0
    public var pagesCleaned: Int = 0
    public var aiQueriesProcessed: Int = 0
    public var dataSaved: Int = 0 // bytes
}

// MARK: - Feature Protocols

/// Protocol for print-friendly functionality
public protocol PrintFriendlyFeature {
    func cleanPage(options: PrintCleanOptions) async throws -> CleanedPage
    func exportToPDF(page: CleanedPage) async throws -> Data
    func captureScreenshot(options: ScreenshotOptions) async throws -> Data
}

/// Protocol for email protection functionality
public protocol EmailProtectionFeature {
    func generateAlias(for domain: String) async throws -> EmailAlias
    func listAliases() async throws -> [EmailAlias]
    func toggleAlias(_ aliasId: String, enabled: Bool) async throws
    func deleteAlias(_ aliasId: String) async throws
    func getTrackerReport(for aliasId: String) async throws -> TrackerReport
}

/// Protocol for password manager functionality
public protocol PasswordManagerFeature {
    func getCredentials(for domain: String) async throws -> [Credential]
    func saveCredential(_ credential: Credential) async throws
    func generatePassword(options: PasswordOptions) -> String
    func checkBreachStatus(for credential: Credential) async throws -> BreachStatus
    func autofill(credentialId: String, on page: PageContext) async throws
}

/// Protocol for dark mode functionality
public protocol DarkModeFeature {
    func enableDarkMode(on page: PageContext, theme: DarkTheme) async throws
    func disableDarkMode(on page: PageContext) async throws
    func getThemes() -> [DarkTheme]
    func setDefaultTheme(_ theme: DarkTheme) async throws
    func setSitePreference(domain: String, preference: DarkModePreference) async throws
}

/// Protocol for ad blocking functionality
public protocol AdBlockerFeature {
    func blockAds(on page: PageContext) async throws -> BlockingResult
    func updateFilterLists() async throws
    func whitelistDomain(_ domain: String) async throws
    func removeFromWhitelist(_ domain: String) async throws
    func getBlockingStats() async throws -> BlockingStats
}

/// Protocol for privacy protection functionality
public protocol PrivacyProtectionFeature {
    func removeTrackers(on page: PageContext) async throws -> [TrackerInfo]
    func stripTrackingParams(from url: URL) -> URL
    func enableFingerprintProtection() async throws
    func getPrivacyReport(for domain: String) async throws -> PrivacyReport
}

/// Protocol for tab management functionality
public protocol TabManagerFeature {
    func getTabs() async throws -> [TabInfo]
    func groupTabs(by strategy: GroupingStrategy) async throws -> [TabGroup]
    func suspendInactiveTabs(olderThan: TimeInterval) async throws
    func saveSession(name: String) async throws -> SavedSession
    func restoreSession(_ sessionId: String) async throws
}

/// Protocol for AI assistant functionality
public protocol AIAssistantFeature {
    func summarizePage(_ page: PageContext) async throws -> String
    func translatePage(_ page: PageContext, to language: String) async throws
    func askQuestion(_ question: String, about page: PageContext) async throws -> String
    func explainSelection(_ selection: String, context: PageContext) async throws -> String
}

// MARK: - Supporting Types

public struct PrintCleanOptions: Codable, Sendable {
    public var removeAds: Bool = true
    public var removeNavigation: Bool = true
    public var removeComments: Bool = true
    public var removeRelatedContent: Bool = true
    public var preserveImages: Bool = true
    public var preserveLinks: Bool = true
    public var fontSize: Int = 12
    public var pageSize: PageSize = .a4
    public var margins: PageMargins = .standard

    public enum PageSize: String, Codable, Sendable {
        case a4, letter, legal
    }

    public struct PageMargins: Codable, Sendable {
        public var top: Double
        public var bottom: Double
        public var left: Double
        public var right: Double

        public static let standard = PageMargins(top: 20, bottom: 20, left: 20, right: 20)
        public static let minimal = PageMargins(top: 10, bottom: 10, left: 10, right: 10)
    }
}

public struct CleanedPage: Codable, Sendable {
    public let title: String
    public let content: String // HTML
    public let textContent: String
    public let images: [PageImage]
    public let wordCount: Int
    public let estimatedReadTime: Int // minutes
}

public struct PageImage: Codable, Sendable {
    public let url: String
    public let alt: String?
    public let width: Int?
    public let height: Int?
}

public struct ScreenshotOptions: Codable, Sendable {
    public var fullPage: Bool = true
    public var format: ImageFormat = .png
    public var quality: Double = 0.9

    public enum ImageFormat: String, Codable, Sendable {
        case png, jpeg, webp
    }
}

public struct EmailAlias: Codable, Sendable, Identifiable {
    public let id: String
    public let alias: String
    public let forwardTo: String
    public let domain: String
    public let createdAt: Date
    public var isEnabled: Bool
    public var note: String?
    public var emailsReceived: Int
    public var trackersBlocked: Int
}

public struct TrackerReport: Codable, Sendable {
    public let aliasId: String
    public let totalEmails: Int
    public let trackersRemoved: Int
    public let trackerTypes: [String: Int]
    public let recentActivity: [TrackerActivity]
}

public struct TrackerActivity: Codable, Sendable {
    public let timestamp: Date
    public let senderDomain: String
    public let trackersFound: Int
    public let trackersBlocked: Int
}

public struct Credential: Codable, Sendable, Identifiable {
    public let id: String
    public var domain: String
    public var username: String
    public var password: String
    public var totpSecret: String?
    public var notes: String?
    public var tags: [String]
    public let createdAt: Date
    public var updatedAt: Date
    public var lastUsedAt: Date?
}

public struct PasswordOptions: Codable, Sendable {
    public var length: Int = 20
    public var includeUppercase: Bool = true
    public var includeLowercase: Bool = true
    public var includeNumbers: Bool = true
    public var includeSymbols: Bool = true
    public var excludeAmbiguous: Bool = true
    public var customSymbols: String?
}

public struct BreachStatus: Codable, Sendable {
    public let isBreached: Bool
    public let breachCount: Int
    public let breaches: [BreachInfo]
    public let lastChecked: Date
}

public struct BreachInfo: Codable, Sendable {
    public let name: String
    public let date: Date
    public let compromisedData: [String]
}

public struct DarkTheme: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public var backgroundColor: String // hex
    public var textColor: String
    public var linkColor: String
    public var borderColor: String
    public var accentColor: String
    public var brightness: Double
    public var contrast: Double
    public var grayscale: Double
    public var sepia: Double

    public static let pure = DarkTheme(
        id: "pure", name: "Pure Black",
        backgroundColor: "#000000", textColor: "#ffffff",
        linkColor: "#4da6ff", borderColor: "#333333", accentColor: "#4da6ff",
        brightness: 1.0, contrast: 1.0, grayscale: 0, sepia: 0
    )

    public static let midnight = DarkTheme(
        id: "midnight", name: "Midnight",
        backgroundColor: "#1a1a2e", textColor: "#eaeaea",
        linkColor: "#6b9fff", borderColor: "#2d2d44", accentColor: "#6b9fff",
        brightness: 1.0, contrast: 1.0, grayscale: 0, sepia: 0
    )

    public static let warm = DarkTheme(
        id: "warm", name: "Warm Dark",
        backgroundColor: "#1f1b18", textColor: "#e8e4df",
        linkColor: "#d4a574", borderColor: "#3d3530", accentColor: "#d4a574",
        brightness: 1.0, contrast: 1.0, grayscale: 0, sepia: 0.1
    )
}

public enum DarkModePreference: String, Codable, Sendable {
    case auto // follow system
    case always
    case never
    case scheduled
}

public struct PageContext: Codable, Sendable {
    public let url: URL
    public let domain: String
    public let title: String
    public let tabId: String
}

public struct BlockingResult: Codable, Sendable {
    public let adsBlocked: Int
    public let trackersBlocked: Int
    public let scriptsBlocked: Int
    public let elementsHidden: Int
    public let dataSaved: Int // bytes
}

public struct BlockingStats: Codable, Sendable {
    public let totalAdsBlocked: Int
    public let totalTrackersBlocked: Int
    public let totalDataSaved: Int
    public let topBlockedDomains: [String: Int]
    public let blocksByDay: [String: Int]
}

public struct TrackerInfo: Codable, Sendable {
    public let name: String
    public let company: String
    public let category: TrackerCategory
    public let blocked: Bool

    public enum TrackerCategory: String, Codable, Sendable {
        case advertising
        case analytics
        case social
        case fingerprinting
        case cryptomining
        case other
    }
}

public struct PrivacyReport: Codable, Sendable {
    public let domain: String
    public let grade: String // A+, A, B, C, D, F
    public let trackersFound: Int
    public let trackersBlocked: Int
    public let fingerprintingAttempts: Int
    public let httpsStatus: Bool
    public let privacyPractices: [String: Bool]
}

public struct TabInfo: Codable, Sendable, Identifiable {
    public let id: String
    public let url: URL?
    public let title: String
    public let favIconUrl: String?
    public let isActive: Bool
    public let isPinned: Bool
    public let isSuspended: Bool
    public let lastAccessed: Date
    public let memoryUsage: Int? // bytes
}

public struct TabGroup: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let color: String
    public let tabs: [TabInfo]
    public let createdAt: Date
}

public enum GroupingStrategy: String, Codable, Sendable {
    case domain
    case topic
    case activity
    case manual
    case ai // AI-powered grouping
}

public struct SavedSession: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let tabs: [TabInfo]
    public let groups: [TabGroup]
    public let createdAt: Date
    public let updatedAt: Date
}

// MARK: - App-Extension Bridge

/// Bridge for communication between main Thea app and extensions
@MainActor
public final class TheaExtensionBridge: ObservableObject {
    public static let shared = TheaExtensionBridge()

    private let logger = Logger(subsystem: "com.thea.extension", category: "Bridge")

    @Published public private(set) var connectedExtensions: Set<ExtensionType> = []
    @Published public private(set) var lastHeartbeat: [ExtensionType: Date] = [:]

    public enum ExtensionType: String, Codable, CaseIterable {
        case safari
        case chrome
        case brave
    }

    private var messageHandlers: [String: (ExtensionMessage) async -> ExtensionResponse] = [:]
    private var eventSubscribers: [String: [(ExtensionEvent) -> Void]] = [:]

    private init() {
        setupMessageHandlers()
        startHeartbeatMonitor()
    }

    private func setupMessageHandlers() {
        // Register default handlers
        registerHandler(for: "getState") { [weak self] _ in
            guard let self else {
                return ExtensionResponse(messageId: "", success: false, data: nil, error: ExtensionError(code: -1, message: "Bridge unavailable", details: nil))
            }

            let state = TheaExtensionState.shared
            return ExtensionResponse(
                messageId: "",
                success: true,
                data: [
                    "printFriendlyEnabled": AnyCodable(state.printFriendlyEnabled),
                    "emailProtectionEnabled": AnyCodable(state.emailProtectionEnabled),
                    "passwordManagerEnabled": AnyCodable(state.passwordManagerEnabled),
                    "darkModeEnabled": AnyCodable(state.darkModeEnabled),
                    "adBlockerEnabled": AnyCodable(state.adBlockerEnabled),
                    "privacyProtectionEnabled": AnyCodable(state.privacyProtectionEnabled),
                    "isConnectedToApp": AnyCodable(state.isConnectedToApp)
                ],
                error: nil
            )
        }

        registerHandler(for: "sync") { [weak self] message in
            // Handle sync request
            return ExtensionResponse(messageId: message.id, success: true, data: nil, error: nil)
        }
    }

    private func startHeartbeatMonitor() {
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkHeartbeats()
            }
        }
    }

    private func checkHeartbeats() {
        let timeout: TimeInterval = 60
        let now = Date()

        for (type, lastBeat) in lastHeartbeat {
            if now.timeIntervalSince(lastBeat) > timeout {
                connectedExtensions.remove(type)
                logger.warning("Extension \(type.rawValue) timed out")
            }
        }
    }

    // MARK: - Public API

    public func registerHandler(for action: String, handler: @escaping (ExtensionMessage) async -> ExtensionResponse) {
        messageHandlers[action] = handler
    }

    public func handleMessage(_ message: ExtensionMessage) async -> ExtensionResponse {
        guard let handler = messageHandlers[message.action] else {
            return ExtensionResponse(
                messageId: message.id,
                success: false,
                data: nil,
                error: ExtensionError(code: 404, message: "Unknown action: \(message.action)", details: nil)
            )
        }

        return await handler(message)
    }

    public func broadcastEvent(_ event: ExtensionEvent) {
        eventSubscribers[event.channel]?.forEach { $0(event) }
    }

    public func subscribe(to channel: String, handler: @escaping (ExtensionEvent) -> Void) {
        if eventSubscribers[channel] == nil {
            eventSubscribers[channel] = []
        }
        eventSubscribers[channel]?.append(handler)
    }

    public func recordHeartbeat(from extension: ExtensionType) {
        lastHeartbeat[`extension`] = Date()
        connectedExtensions.insert(`extension`)
    }

    public func notifyExtensions(_ notification: ExtensionNotification) {
        let event = ExtensionEvent(
            channel: "notifications",
            eventType: notification.type.rawValue,
            data: notification.data,
            timestamp: Date()
        )
        broadcastEvent(event)
    }
}

public struct ExtensionNotification {
    public let type: NotificationType
    public let data: [String: AnyCodable]

    public enum NotificationType: String {
        case stateChanged
        case credentialUpdated
        case aliasCreated
        case settingsChanged
        case syncRequired
    }
}
