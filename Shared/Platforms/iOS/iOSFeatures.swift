// iOSFeatures.swift
// iOS-specific features: Home Screen Quick Actions, Share Extensions, Haptic Feedback
// Note: Siri Shortcuts are managed by SiriShortcutsManager in SiriShortcuts.swift
// Note: QuickAction struct is defined in ShareExtensionManager.swift

#if os(iOS)
    import Foundation
    import Intents
    import IntentsUI
    import OSLog
    import UIKit

    // MARK: - Legacy SiriKit Intents (Placeholder definitions)

    // Note: Modern App Intents are defined in TheaAppIntents.swift

    public class LegacyAskTheaIntent: INIntent {
        // Intent definition would be in Intents.intentdefinition
    }

    public class LegacyQuickActionIntent: INIntent {
        var actionType: String?
    }

    public class LegacyVoiceCommandIntent: INIntent {
        var commandPhrase: String?
    }

    // MARK: - Quick Action Type for Home Screen

    public enum HomeScreenQuickActionType: String, CaseIterable {
        case newConversation = "new_conversation"
        case voiceInput = "voice_input"
        case processClipboard = "process_clipboard"
        case translateClipboard = "translate_clipboard"
        case summarizeClipboard = "summarize_clipboard"
        case askAboutPhoto = "ask_about_photo"

        public var suggestedPhrase: String {
            switch self {
            case .newConversation: "Start a new conversation with Thea"
            case .voiceInput: "Talk to Thea"
            case .processClipboard: "Ask Thea about my clipboard"
            case .translateClipboard: "Translate my clipboard"
            case .summarizeClipboard: "Summarize my clipboard"
            case .askAboutPhoto: "Ask Thea about this photo"
            }
        }

        public var title: String {
            switch self {
            case .newConversation: "New Conversation"
            case .voiceInput: "Voice Input"
            case .processClipboard: "Process Clipboard"
            case .translateClipboard: "Translate"
            case .summarizeClipboard: "Summarize"
            case .askAboutPhoto: "Ask About Photo"
            }
        }

        public var iconName: String {
            switch self {
            case .newConversation: "plus.message"
            case .voiceInput: "mic"
            case .processClipboard: "doc.on.clipboard"
            case .translateClipboard: "globe"
            case .summarizeClipboard: "doc.plaintext"
            case .askAboutPhoto: "photo"
            }
        }
    }

    // MARK: - Home Screen Quick Actions Manager

    /// Manages Home Screen 3D Touch / Haptic Touch quick actions
    @MainActor
    public final class HomeScreenActionsManager: ObservableObject {
        public static let shared = HomeScreenActionsManager()

        private let logger = Logger(subsystem: "com.thea.app", category: "HomeScreenActions")

        // MARK: - Setup

        public func setupQuickActions() {
            var shortcuts: [UIApplicationShortcutItem] = []

            // Static shortcuts
            shortcuts.append(UIApplicationShortcutItem(
                type: "com.thea.newConversation",
                localizedTitle: "New Conversation",
                localizedSubtitle: "Start a new chat",
                icon: UIApplicationShortcutIcon(systemImageName: "plus.message"),
                userInfo: nil
            ))

            shortcuts.append(UIApplicationShortcutItem(
                type: "com.thea.voiceInput",
                localizedTitle: "Voice Input",
                localizedSubtitle: "Talk to Thea",
                icon: UIApplicationShortcutIcon(systemImageName: "mic"),
                userInfo: nil
            ))

            shortcuts.append(UIApplicationShortcutItem(
                type: "com.thea.clipboard",
                localizedTitle: "Process Clipboard",
                localizedSubtitle: "Analyze clipboard content",
                icon: UIApplicationShortcutIcon(systemImageName: "doc.on.clipboard"),
                userInfo: nil
            ))

            shortcuts.append(UIApplicationShortcutItem(
                type: "com.thea.search",
                localizedTitle: "Search",
                localizedSubtitle: "Search conversations",
                icon: UIApplicationShortcutIcon(systemImageName: "magnifyingglass"),
                userInfo: nil
            ))

            UIApplication.shared.shortcutItems = shortcuts
            logger.info("Setup \(shortcuts.count) home screen quick actions")
        }

        /// Handle quick action
        public func handleQuickAction(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
            switch shortcutItem.type {
            case "com.thea.newConversation":
                NotificationCenter.default.post(name: .theaNewConversation, object: nil)
                return true

            case "com.thea.voiceInput":
                NotificationCenter.default.post(name: .theaVoiceInput, object: nil)
                return true

            case "com.thea.clipboard":
                NotificationCenter.default.post(name: .theaProcessClipboard, object: nil)
                return true

            case "com.thea.search":
                NotificationCenter.default.post(name: .theaSearch, object: nil)
                return true

            default:
                return false
            }
        }

        /// Add dynamic shortcut for recent conversation
        public func addRecentConversationShortcut(id: String, title: String) {
            var shortcuts = UIApplication.shared.shortcutItems ?? []

            // Remove existing dynamic shortcuts (keep only static ones)
            shortcuts = shortcuts.filter { !$0.type.hasPrefix("com.thea.recent.") }

            // Add new recent conversation
            let recentShortcut = UIApplicationShortcutItem(
                type: "com.thea.recent.\(id)",
                localizedTitle: title,
                localizedSubtitle: "Continue conversation",
                icon: UIApplicationShortcutIcon(systemImageName: "bubble.left"),
                userInfo: ["conversationId": id as NSString]
            )

            shortcuts.insert(recentShortcut, at: min(4, shortcuts.count))

            // Keep max 4 shortcuts
            if shortcuts.count > 4 {
                shortcuts = Array(shortcuts.prefix(4))
            }

            UIApplication.shared.shortcutItems = shortcuts
        }
    }

    // MARK: - Share Extension Handler

    /// Handles Share Extension data
    /// Note: Uses SharedContent from ShareExtensionManager.swift
    @MainActor
    public final class ShareExtensionHandler: ObservableObject {
        public static let shared = ShareExtensionHandler()

        private let logger = Logger(subsystem: "com.thea.app", category: "ShareExtension")

        // MARK: - Published State

        @Published public var sharedContent: SharedContent?

        // MARK: - Handle Shared Content

        public func handleSharedContent(_ extensionContext: NSExtensionContext?) async {
            guard let extensionContext,
                  let inputItems = extensionContext.inputItems as? [NSExtensionItem]
            else {
                return
            }

            for inputItem in inputItems {
                guard let attachments = inputItem.attachments else { continue }

                for provider in attachments {
                    // Handle text
                    if provider.hasItemConformingToTypeIdentifier("public.plain-text") {
                        if let text = try? await loadText(from: provider) {
                            sharedContent = SharedContent(type: .text, text: text)
                            return
                        }
                    }

                    // Handle URL
                    if provider.hasItemConformingToTypeIdentifier("public.url") {
                        if let url = try? await loadURL(from: provider) {
                            sharedContent = SharedContent(type: .url, url: url.absoluteString)
                            return
                        }
                    }

                    // Handle image
                    if provider.hasItemConformingToTypeIdentifier("public.image") {
                        if let imageData = try? await loadImage(from: provider) {
                            sharedContent = SharedContent(type: .image, data: imageData)
                            return
                        }
                    }

                    // Handle PDF
                    if provider.hasItemConformingToTypeIdentifier("com.adobe.pdf") {
                        if let pdfData = try? await loadPDF(from: provider) {
                            sharedContent = SharedContent(type: .pdf, data: pdfData)
                            return
                        }
                    }
                }
            }
        }

        private func loadText(from provider: NSItemProvider) async throws -> String {
            try await withCheckedThrowingContinuation { continuation in
                provider.loadItem(forTypeIdentifier: "public.plain-text", options: nil) { item, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let text = item as? String {
                        continuation.resume(returning: text)
                    } else {
                        continuation.resume(throwing: ShareError.invalidContent)
                    }
                }
            }
        }

        private func loadURL(from provider: NSItemProvider) async throws -> URL {
            try await withCheckedThrowingContinuation { continuation in
                provider.loadItem(forTypeIdentifier: "public.url", options: nil) { item, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let url = item as? URL {
                        continuation.resume(returning: url)
                    } else {
                        continuation.resume(throwing: ShareError.invalidContent)
                    }
                }
            }
        }

        private func loadImage(from provider: NSItemProvider) async throws -> Data {
            try await withCheckedThrowingContinuation { continuation in
                provider.loadItem(forTypeIdentifier: "public.image", options: nil) { item, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let image = item as? UIImage, let data = image.pngData() {
                        continuation.resume(returning: data)
                    } else if let url = item as? URL, let data = try? Data(contentsOf: url) {
                        continuation.resume(returning: data)
                    } else {
                        continuation.resume(throwing: ShareError.invalidContent)
                    }
                }
            }
        }

        private func loadPDF(from provider: NSItemProvider) async throws -> Data {
            try await withCheckedThrowingContinuation { continuation in
                provider.loadItem(forTypeIdentifier: "com.adobe.pdf", options: nil) { item, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let url = item as? URL, let data = try? Data(contentsOf: url) {
                        continuation.resume(returning: data)
                    } else {
                        continuation.resume(throwing: ShareError.invalidContent)
                    }
                }
            }
        }
    }

    public enum ShareError: Error {
        case invalidContent
        case loadFailed
    }

    // MARK: - Haptic Feedback Manager

    /// Manages haptic feedback for iOS
    @MainActor
    public final class HapticFeedbackManager {
        public static let shared = HapticFeedbackManager()

        private let impactLight = UIImpactFeedbackGenerator(style: .light)
        private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
        private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
        private let selectionFeedback = UISelectionFeedbackGenerator()
        private let notificationFeedback = UINotificationFeedbackGenerator()

        private init() {
            prepare()
        }

        public func prepare() {
            impactLight.prepare()
            impactMedium.prepare()
            selectionFeedback.prepare()
            notificationFeedback.prepare()
        }

        public func lightImpact() {
            impactLight.impactOccurred()
        }

        public func mediumImpact() {
            impactMedium.impactOccurred()
        }

        public func heavyImpact() {
            impactHeavy.impactOccurred()
        }

        public func selection() {
            selectionFeedback.selectionChanged()
        }

        public func success() {
            notificationFeedback.notificationOccurred(.success)
        }

        public func warning() {
            notificationFeedback.notificationOccurred(.warning)
        }

        public func error() {
            notificationFeedback.notificationOccurred(.error)
        }

        /// Feedback for AI response completion
        public func aiResponseComplete() {
            success()
        }

        /// Feedback for message sent
        public func messageSent() {
            lightImpact()
        }

        /// Feedback for button tap
        public func buttonTap() {
            selection()
        }
    }

    // MARK: - Notification Names

    public extension Notification.Name {
        static let theaNewConversation = Notification.Name("theaNewConversation")
        static let theaVoiceInput = Notification.Name("theaVoiceInput")
        static let theaProcessClipboard = Notification.Name("theaProcessClipboard")
        static let theaSearch = Notification.Name("theaSearch")
    }

#endif
