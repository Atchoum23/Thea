//
//  ActionButtonHandler.swift
//  Thea
//
//  Created by Thea
//  Handles iPhone 15 Pro+ Action Button integration
//

#if os(iOS)
    import Foundation
    import os.log
    import UIKit

    /// Handles iPhone 15 Pro+ Action Button integration
    /// The Action Button can be configured to launch Thea or trigger specific actions
    @MainActor
    public final class ActionButtonHandler: ObservableObject {
        public static let shared = ActionButtonHandler()

        private let logger = Logger(subsystem: "app.thea.actionbutton", category: "ActionButtonHandler")

        // MARK: - Published State

        @Published public private(set) var isActionButtonAvailable = false
        @Published public var configuredAction: ActionButtonAction = .quickAsk

        // MARK: - Action Button Actions

        public enum ActionButtonAction: String, CaseIterable, Codable, Sendable {
            case quickAsk = "quick_ask"
            case voiceInput = "voice_input"
            case startFocus = "start_focus"
            case screenshotAndAsk = "screenshot_ask"
            case newConversation = "new_conversation"
            case toggleListening = "toggle_listening"
            case runShortcut = "run_shortcut"
            case custom

            public var displayName: String {
                switch self {
                case .quickAsk: "Quick Ask"
                case .voiceInput: "Voice Input"
                case .startFocus: "Start Focus Session"
                case .screenshotAndAsk: "Screenshot & Ask"
                case .newConversation: "New Conversation"
                case .toggleListening: "Toggle Listening"
                case .runShortcut: "Run Shortcut"
                case .custom: "Custom Action"
                }
            }

            public var systemImage: String {
                switch self {
                case .quickAsk: "bubble.left.fill"
                case .voiceInput: "mic.fill"
                case .startFocus: "timer"
                case .screenshotAndAsk: "camera.viewfinder"
                case .newConversation: "plus.bubble"
                case .toggleListening: "ear"
                case .runShortcut: "bolt.fill"
                case .custom: "gearshape.fill"
                }
            }
        }

        // MARK: - Callbacks

        public var onActionButtonPressed: ((ActionButtonAction) -> Void)?
        public var onQuickAskRequested: (() -> Void)?
        public var onVoiceInputRequested: (() -> Void)?
        public var onFocusSessionRequested: (() -> Void)?
        public var onScreenshotAskRequested: (() -> Void)?
        public var onNewConversationRequested: (() -> Void)?

        // MARK: - Custom Action

        public var customShortcutName: String?

        private init() {
            checkActionButtonAvailability()
            loadConfiguration()
        }

        // MARK: - Availability Check

        private func checkActionButtonAvailability() {
            // Action Button is available on iPhone 15 Pro and later
            // Check device model to determine availability
            let deviceModel = getDeviceModel()

            // iPhone 15 Pro models have Action Button
            isActionButtonAvailable = deviceModel.contains("iPhone16") || // iPhone 15 Pro/Pro Max
                deviceModel.contains("iPhone17") || // iPhone 16 series
                deviceModel.contains("iPhone18") // Future models

            logger.info("Action Button available: \(isActionButtonAvailable), device: \(deviceModel)")
        }

        private func getDeviceModel() -> String {
            var systemInfo = utsname()
            uname(&systemInfo)
            let machineMirror = Mirror(reflecting: systemInfo.machine)
            let identifier = machineMirror.children.reduce("") { identifier, element in
                guard let value = element.value as? Int8, value != 0 else { return identifier }
                return identifier + String(UnicodeScalar(UInt8(value)))
            }
            return identifier
        }

        // MARK: - Configuration

        private let configKey = "thea.actionButton.config"

        private func loadConfiguration() {
            if let rawValue = UserDefaults.standard.string(forKey: configKey),
               let action = ActionButtonAction(rawValue: rawValue)
            {
                configuredAction = action
            }
        }

        public func saveConfiguration() {
            UserDefaults.standard.set(configuredAction.rawValue, forKey: configKey)
        }

        public func setAction(_ action: ActionButtonAction) {
            configuredAction = action
            saveConfiguration()
            logger.info("Action Button configured to: \(action.rawValue)")
        }

        // MARK: - Action Handling

        /// Called when the Action Button is pressed (via App Intent or URL scheme)
        public func handleActionButtonPress() {
            logger.info("Action Button pressed, executing: \(configuredAction.rawValue)")

            // Notify listeners
            onActionButtonPressed?(configuredAction)

            // Execute the configured action
            executeAction(configuredAction)
        }

        public func executeAction(_ action: ActionButtonAction) {
            switch action {
            case .quickAsk:
                onQuickAskRequested?()
                postNotification(.theaQuickAskRequested)

            case .voiceInput:
                onVoiceInputRequested?()
                postNotification(.theaVoiceInputRequested)

            case .startFocus:
                onFocusSessionRequested?()
                postNotification(.theaFocusSessionRequested)

            case .screenshotAndAsk:
                onScreenshotAskRequested?()
                postNotification(.theaScreenshotAskRequested)

            case .newConversation:
                onNewConversationRequested?()
                postNotification(.theaNewConversationRequested)

            case .toggleListening:
                postNotification(.theaToggleListeningRequested)

            case .runShortcut:
                if let shortcutName = customShortcutName {
                    runShortcut(named: shortcutName)
                }

            case .custom:
                postNotification(.theaCustomActionRequested)
            }
        }

        private func postNotification(_ name: Notification.Name) {
            NotificationCenter.default.post(name: name, object: nil)
        }

        // MARK: - Shortcuts Integration

        private func runShortcut(named name: String) {
            // Use URL scheme to run Shortcuts
            let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
            if let url = URL(string: "shortcuts://run-shortcut?name=\(encodedName)") {
                Task { @MainActor in
                    await UIApplication.shared.open(url)
                }
            }
        }

        // MARK: - Haptic Feedback

        public func provideHapticFeedback() {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
        }
    }

    // MARK: - Notification Names

    public extension Notification.Name {
        static let theaQuickAskRequested = Notification.Name("theaQuickAskRequested")
        static let theaVoiceInputRequested = Notification.Name("theaVoiceInputRequested")
        static let theaFocusSessionRequested = Notification.Name("theaFocusSessionRequested")
        static let theaScreenshotAskRequested = Notification.Name("theaScreenshotAskRequested")
        static let theaNewConversationRequested = Notification.Name("theaNewConversationRequested")
        static let theaToggleListeningRequested = Notification.Name("theaToggleListeningRequested")
        static let theaCustomActionRequested = Notification.Name("theaCustomActionRequested")
    }

    // MARK: - App Intent for Action Button

    import AppIntents

    /// App Intent for Action Button integration
    @available(iOS 16.0, *)
    public struct TheaActionButtonIntent: AppIntent {
        public static var title: LocalizedStringResource = "Thea Action"
        public static var description = IntentDescription("Execute configured Thea action")

        public static var openAppWhenRun: Bool = true

        public init() {}

        @MainActor
        public func perform() async throws -> some IntentResult {
            ActionButtonHandler.shared.handleActionButtonPress()
            return .result()
        }
    }

    /// App Shortcut for Action Button
    @available(iOS 16.0, *)
    public struct TheaActionButtonShortcuts: AppShortcutsProvider {
        public static var appShortcuts: [AppShortcut] {
            AppShortcut(
                intent: TheaActionButtonIntent(),
                phrases: [
                    "Activate \(.applicationName)",
                    "Ask \(.applicationName)",
                    "Hey \(.applicationName)"
                ],
                shortTitle: "Thea Action",
                systemImageName: "brain"
            )
        }
    }
#endif
