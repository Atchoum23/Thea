// ControlCenterWidget.swift
// Control Center integration for quick AI access

import Foundation
import OSLog
#if canImport(WidgetKit)
    import WidgetKit
#endif
#if canImport(UIKit)
    import UIKit
#endif

// MARK: - Control Center Widget Manager

/// Manages Control Center widget and quick toggles
@MainActor
public final class ControlCenterWidgetManager: ObservableObject {
    public static let shared = ControlCenterWidgetManager()

    private let logger = Logger(subsystem: "ai.thea.app", category: "ControlCenterWidgetManager")

    // MARK: - Published State

    @Published public private(set) var quickActions: [ControlCenterAction] = []
    @Published public private(set) var widgetState: WidgetState = .idle

    // MARK: - Initialization

    private init() {
        setupDefaultActions()
    }

    // MARK: - Setup

    private func setupDefaultActions() {
        quickActions = [
            ControlCenterAction(
                id: "quick-ask",
                title: "Ask Thea",
                icon: "sparkles",
                type: .toggle,
                isEnabled: true
            ),
            ControlCenterAction(
                id: "voice-mode",
                title: "Voice Mode",
                icon: "mic.fill",
                type: .toggle,
                isEnabled: false
            ),
            ControlCenterAction(
                id: "clipboard-ai",
                title: "AI on Clipboard",
                icon: "doc.on.clipboard",
                type: .action,
                isEnabled: true
            ),
            ControlCenterAction(
                id: "screen-capture",
                title: "Capture & Analyze",
                icon: "camera.viewfinder",
                type: .action,
                isEnabled: true
            ),
            ControlCenterAction(
                id: "focus-assist",
                title: "Focus Assist",
                icon: "brain.head.profile",
                type: .toggle,
                isEnabled: false
            ),
            ControlCenterAction(
                id: "notifications",
                title: "AI Notifications",
                icon: "bell.fill",
                type: .toggle,
                isEnabled: true
            )
        ]
    }

    // MARK: - Actions

    /// Execute a Control Center action
    public func executeAction(_ actionId: String) async {
        guard let action = quickActions.first(where: { $0.id == actionId }) else {
            logger.warning("Unknown action: \(actionId)")
            return
        }

        logger.info("Executing Control Center action: \(actionId)")

        switch actionId {
        case "quick-ask":
            await handleQuickAsk()

        case "voice-mode":
            await handleVoiceMode(action)

        case "clipboard-ai":
            await handleClipboardAI()

        case "screen-capture":
            await handleScreenCapture()

        case "focus-assist":
            await handleFocusAssist(action)

        case "notifications":
            await handleNotificationsToggle(action)

        default:
            logger.warning("Unhandled action: \(actionId)")
        }

        // Reload widgets
        reloadWidgets()
    }

    /// Toggle an action's enabled state
    public func toggleAction(_ actionId: String) {
        guard let index = quickActions.firstIndex(where: { $0.id == actionId }) else { return }
        quickActions[index].isEnabled.toggle()

        // Persist state
        saveActionStates()
        reloadWidgets()
    }

    // MARK: - Action Handlers

    private func handleQuickAsk() async {
        widgetState = .processing

        // Launch quick ask overlay
        NotificationCenter.default.post(name: .controlCenterQuickAsk, object: nil)

        widgetState = .idle
    }

    private func handleVoiceMode(_ action: ControlCenterAction) async {
        if action.isEnabled {
            // Stop voice mode
            SpeechIntelligence.shared.stopRecognition()
            toggleAction(action.id)
        } else {
            // Start voice mode
            do {
                try await SpeechIntelligence.shared.startRecognition()
                toggleAction(action.id)
            } catch {
                logger.error("Failed to start voice mode: \(error.localizedDescription)")
            }
        }
    }

    private func handleClipboardAI() async {
        widgetState = .processing

        // Get clipboard content
        #if os(macOS)
            guard let text = UniversalClipboardManager.shared.getText() else {
                widgetState = .idle
                return
            }
        #elseif os(iOS)
            guard let text = UIPasteboard.general.string else {
                widgetState = .idle
                return
            }
        #else
            let text: String? = nil
            guard text != nil else {
                widgetState = .idle
                return
            }
        #endif

        // Send to AI
        NotificationCenter.default.post(
            name: .controlCenterClipboardAI,
            object: nil,
            userInfo: ["content": text]
        )

        widgetState = .idle
    }

    private func handleScreenCapture() async {
        widgetState = .processing

        #if os(macOS)
            // Trigger screen capture
            NotificationCenter.default.post(name: .controlCenterScreenCapture, object: nil)
        #elseif os(iOS)
            // Use screenshot API
            NotificationCenter.default.post(name: .controlCenterScreenCapture, object: nil)
        #endif

        widgetState = .idle
    }

    private func handleFocusAssist(_ action: ControlCenterAction) async {
        toggleAction(action.id)

        if !action.isEnabled {
            // Enable focus assist
            // This could integrate with Focus modes
            NotificationCenter.default.post(name: .controlCenterFocusAssist, object: nil, userInfo: ["enabled": true])
        } else {
            // Disable focus assist
            NotificationCenter.default.post(name: .controlCenterFocusAssist, object: nil, userInfo: ["enabled": false])
        }
    }

    private func handleNotificationsToggle(_ action: ControlCenterAction) async {
        toggleAction(action.id)

        // Toggle AI notifications
        UserDefaults.standard.set(!action.isEnabled, forKey: "ai.notifications.enabled")
    }

    // MARK: - Widget Data

    /// Get data for WidgetKit widget
    public func getWidgetData() -> ControlCenterWidgetData {
        ControlCenterWidgetData(
            actions: quickActions,
            lastConversation: getLastConversationPreview(),
            aiStatus: getAIStatus()
        )
    }

    private func getLastConversationPreview() -> String? {
        // Return last conversation preview
        UserDefaults.standard.string(forKey: "lastConversationPreview")
    }

    private func getAIStatus() -> AIStatus {
        if widgetState == .processing {
            return .processing
        }
        return .ready
    }

    // MARK: - Persistence

    private func saveActionStates() {
        let states = quickActions.reduce(into: [String: Bool]()) { result, action in
            result[action.id] = action.isEnabled
        }
        do {
            let data = try JSONEncoder().encode(states)
            UserDefaults.standard.set(data, forKey: "controlCenter.actionStates")
        } catch {
            logger.error("Failed to encode action states: \(error.localizedDescription)")
        }
    }

    // periphery:ignore - Reserved: loadActionStates() instance method reserved for future feature activation
    private func loadActionStates() {
        guard let data = UserDefaults.standard.data(forKey: "controlCenter.actionStates") else {
            return
        }
        let states: [String: Bool]
        do {
            states = try JSONDecoder().decode([String: Bool].self, from: data)
        } catch {
            logger.error("Failed to decode action states: \(error.localizedDescription)")
            return
        }

        for (id, isEnabled) in states {
            if let index = quickActions.firstIndex(where: { $0.id == id }) {
                quickActions[index].isEnabled = isEnabled
            }
        }
    }

    // MARK: - Widget Reload

    private func reloadWidgets() {
        #if canImport(WidgetKit)
            WidgetCenter.shared.reloadTimelines(ofKind: "TheaControlCenterWidget")
        #endif
    }
}

// MARK: - Supporting Types

public struct ControlCenterAction: Identifiable, Codable {
    public let id: String
    public let title: String
    public let icon: String
    public let type: ActionType
    public var isEnabled: Bool

    public enum ActionType: String, Codable {
        case toggle
        case action
    }
}

public struct ControlCenterWidgetData {
    public let actions: [ControlCenterAction]
    public let lastConversation: String?
    public let aiStatus: AIStatus
}

public enum WidgetState: Equatable {
    case idle
    case processing
    case error(String)
}

public enum AIStatus {
    case ready
    case processing
    case offline
}

// MARK: - Notifications

public extension Notification.Name {
    static let controlCenterQuickAsk = Notification.Name("thea.controlCenter.quickAsk")
    static let controlCenterClipboardAI = Notification.Name("thea.controlCenter.clipboardAI")
    static let controlCenterScreenCapture = Notification.Name("thea.controlCenter.screenCapture")
    static let controlCenterFocusAssist = Notification.Name("thea.controlCenter.focusAssist")
}

// MARK: - Widget Intent Configuration

#if canImport(AppIntents)
    import AppIntents

    @available(iOS 16.0, macOS 13.0, *)
    public struct QuickAskIntent: AppIntent {
        nonisolated(unsafe) public static var title: LocalizedStringResource = "Ask Thea"
        nonisolated(unsafe) public static var description = IntentDescription("Quickly ask Thea a question")

        @Parameter(title: "Question")
        public var question: String?

        public init() {}

        public init(question: String) {
            self.question = question
        }

        public func perform() async throws -> some IntentResult {
            if let question {
                // Process the question
                NotificationCenter.default.post(
                    name: .controlCenterQuickAsk,
                    object: nil,
                    userInfo: ["question": question]
                )
            }
            return .result()
        }
    }

    @available(iOS 16.0, macOS 13.0, *)
    public struct ToggleVoiceModeIntent: AppIntent {
        nonisolated(unsafe) public static var title: LocalizedStringResource = "Toggle Voice Mode"
        nonisolated(unsafe) public static var description = IntentDescription("Enable or disable voice interaction")

        public init() {}

        public func perform() async throws -> some IntentResult {
            await ControlCenterWidgetManager.shared.executeAction("voice-mode")
            return .result()
        }
    }

    @available(iOS 16.0, macOS 13.0, *)
    public struct AnalyzeClipboardIntent: AppIntent {
        nonisolated(unsafe) public static var title: LocalizedStringResource = "Analyze Clipboard"
        nonisolated(unsafe) public static var description = IntentDescription("Have AI analyze clipboard contents")

        public init() {}

        public func perform() async throws -> some IntentResult {
            await ControlCenterWidgetManager.shared.executeAction("clipboard-ai")
            return .result()
        }
    }

    // MARK: - Control Center Shortcuts (Intents only - shortcuts registered in TheaAppIntents.swift)

#endif
