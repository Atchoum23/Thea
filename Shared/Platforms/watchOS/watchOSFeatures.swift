// watchOSFeatures.swift
// watchOS-specific features: Complications, Glances, Digital Crown, Haptics

#if os(watchOS)
import Foundation
import WatchKit
import OSLog
import ClockKit
import WidgetKit

// MARK: - Watch Session Manager

/// Manages Watch Connectivity for Thea
@MainActor
public final class WatchSessionManager: NSObject, ObservableObject {
    public static let shared = WatchSessionManager()

    private let logger = Logger(subsystem: "com.thea.app.watch", category: "WatchSession")

    // MARK: - Published State

    @Published public private(set) var isReachable = false
    @Published public private(set) var lastReceivedMessage: WatchMessage?
    @Published public private(set) var pendingMessages: [WatchMessage] = []

    // MARK: - Initialization

    private override init() {
        super.init()
    }

    // MARK: - Message Handling

    public func sendMessage(_ message: WatchMessage) {
        // Send to companion app
        pendingMessages.append(message)
        logger.info("Queued message: \(message.type.rawValue)")
    }

    public func sendQuickAsk(_ text: String) {
        let message = WatchMessage(
            type: .quickAsk,
            payload: ["text": text]
        )
        sendMessage(message)
    }

    public func sendVoiceTranscript(_ transcript: String) {
        let message = WatchMessage(
            type: .voiceInput,
            payload: ["transcript": transcript]
        )
        sendMessage(message)
    }

    public func requestConversationSync() {
        let message = WatchMessage(type: .syncRequest, payload: [:])
        sendMessage(message)
    }
}

// MARK: - Watch Message

public struct WatchMessage: Identifiable, Codable {
    public let id: UUID
    public let type: WatchMessageType
    public let payload: [String: String]
    public let timestamp: Date

    public init(type: WatchMessageType, payload: [String: String]) {
        self.id = UUID()
        self.type = type
        self.payload = payload
        self.timestamp = Date()
    }
}

public enum WatchMessageType: String, Codable {
    case quickAsk
    case voiceInput
    case syncRequest
    case notification
    case response
    case status
}

// MARK: - Complication Manager

/// Manages watchOS Complications
@MainActor
public final class ComplicationManager: ObservableObject {
    public static let shared = ComplicationManager()

    private let logger = Logger(subsystem: "com.thea.app.watch", category: "Complication")

    // MARK: - Published State

    @Published public var currentState: ComplicationState = .idle

    // MARK: - Update Complications

    public func updateComplications() {
        #if canImport(ClockKit)
        let server = CLKComplicationServer.sharedInstance()

        for complication in server.activeComplications ?? [] {
            server.reloadTimeline(for: complication)
        }

        logger.info("Updated complications")
        #endif
    }

    public func updateState(_ state: ComplicationState) {
        currentState = state
        updateComplications()
    }

    // MARK: - Complication Data

    public func getComplicationDescriptors() -> [Any] {
        // Return complication descriptors
        return []
    }
}

public enum ComplicationState: String {
    case idle
    case processing
    case hasNotification
    case error
}

// MARK: - Digital Crown Manager

/// Handles Digital Crown input for navigation
@MainActor
public final class DigitalCrownManager: ObservableObject {
    public static let shared = DigitalCrownManager()

    // MARK: - Published State

    @Published public var crownValue: Double = 0
    @Published public var isScrolling = false

    // MARK: - Crown Handling

    public func handleCrownRotation(_ value: Double) {
        crownValue = value
    }

    public func handleScrollStart() {
        isScrolling = true
    }

    public func handleScrollEnd() {
        isScrolling = false
    }
}

// MARK: - Watch Haptic Manager

/// Manages haptic feedback on watchOS
public final class WatchHapticManager {
    public static let shared = WatchHapticManager()

    private init() {}

    public func success() {
        WKInterfaceDevice.current().play(.success)
    }

    public func failure() {
        WKInterfaceDevice.current().play(.failure)
    }

    public func notification() {
        WKInterfaceDevice.current().play(.notification)
    }

    public func click() {
        WKInterfaceDevice.current().play(.click)
    }

    public func start() {
        WKInterfaceDevice.current().play(.start)
    }

    public func stop() {
        WKInterfaceDevice.current().play(.stop)
    }

    public func directionUp() {
        WKInterfaceDevice.current().play(.directionUp)
    }

    public func directionDown() {
        WKInterfaceDevice.current().play(.directionDown)
    }

    /// Feedback for AI response received
    public func aiResponse() {
        success()
    }

    /// Feedback for voice input started
    public func voiceStart() {
        start()
    }

    /// Feedback for voice input ended
    public func voiceEnd() {
        stop()
    }
}

// MARK: - Quick Actions Manager

/// Manages watch-specific quick actions
@MainActor
public final class WatchQuickActionsManager: ObservableObject {
    public static let shared = WatchQuickActionsManager()

    // MARK: - Quick Actions

    public let quickActions: [WatchQuickAction] = [
        WatchQuickAction(id: "voice", title: "Voice", icon: "mic.fill", color: .blue),
        WatchQuickAction(id: "dictate", title: "Dictate", icon: "text.bubble", color: .green),
        WatchQuickAction(id: "recent", title: "Recent", icon: "clock.fill", color: .orange),
        WatchQuickAction(id: "favorites", title: "Favorites", icon: "star.fill", color: .yellow)
    ]

    // MARK: - Execute Action

    public func executeAction(_ actionId: String) {
        switch actionId {
        case "voice":
            startVoiceInput()
        case "dictate":
            startDictation()
        case "recent":
            showRecentConversations()
        case "favorites":
            showFavorites()
        default:
            break
        }
    }

    private func startVoiceInput() {
        WatchHapticManager.shared.voiceStart()
        NotificationCenter.default.post(name: .watchVoiceInput, object: nil)
    }

    private func startDictation() {
        NotificationCenter.default.post(name: .watchDictation, object: nil)
    }

    private func showRecentConversations() {
        NotificationCenter.default.post(name: .watchShowRecent, object: nil)
    }

    private func showFavorites() {
        NotificationCenter.default.post(name: .watchShowFavorites, object: nil)
    }
}

public struct WatchQuickAction: Identifiable {
    public let id: String
    public let title: String
    public let icon: String
    public let color: WatchColor
}

public enum WatchColor {
    case blue
    case green
    case orange
    case yellow
    case red
    case purple
}

// MARK: - Notification Names

public extension Notification.Name {
    static let watchVoiceInput = Notification.Name("watchVoiceInput")
    static let watchDictation = Notification.Name("watchDictation")
    static let watchShowRecent = Notification.Name("watchShowRecent")
    static let watchShowFavorites = Notification.Name("watchShowFavorites")
}

#endif
