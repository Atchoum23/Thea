// TheaIntegrationHub+NewFeatures.swift
// Integration of all new features into TheaIntegrationHub

import Combine
import Foundation
import OSLog
#if canImport(UserNotifications)
    import UserNotifications
#endif

// MARK: - Private Logger

private let logger = Logger(subsystem: "com.thea.app", category: "IntegrationHub")

// MARK: - New Feature Integration

extension TheaIntegrationHub {
    /// Initialize all new feature managers
    public func initializeNewFeatures() async {
        logger.info("Initializing new feature integrations...")

        // Initialize in parallel where possible
        await withTaskGroup(of: Void.self) { group in
            // Localization
            group.addTask { @MainActor in
                _ = LocalizationManager.shared
            }

            // Analytics
            group.addTask { @MainActor in
                _ = AnalyticsManager.shared
            }

            // Networking
            group.addTask { @MainActor in
                _ = NetworkManager.shared
            }

            // Deep Linking
            group.addTask { @MainActor in
                _ = DeepLinkRouter.shared
            }

            // Backup
            group.addTask { @MainActor in
                _ = BackupManager.shared
            }

            // Onboarding
            group.addTask { @MainActor in
                _ = OnboardingManager.shared
            }

            // Keyboard Shortcuts
            group.addTask { @MainActor in
                _ = KeyboardShortcutsSystem.shared
            }

            // Share Extension
            group.addTask { @MainActor in
                _ = ShareExtensionManager.shared
            }

            // App Clips (iOS)
            #if os(iOS)
                group.addTask { @MainActor in
                    _ = AppClipManager.shared
                }
            #endif

            // Self Evolution
            group.addTask { @MainActor in
                _ = SelfEvolutionEngine.shared
            }

            // Mission Orchestrator
            group.addTask { @MainActor in
                _ = MissionOrchestrator.shared
            }

            // Configuration Manager
            group.addTask { @MainActor in
                _ = ConfigurationManager.shared
            }

            // Window Manager (macOS)
            #if os(macOS)
                group.addTask { @MainActor in
                    _ = WindowManager.shared
                }
            #endif

            // Global Quick Prompt
            group.addTask { @MainActor in
                _ = GlobalQuickPromptManager.shared
            }

            // Spotlight Integration
            group.addTask { @MainActor in
                _ = SpotlightIntegration.shared
            }

            // Handoff (macOS only)
            #if os(macOS)
                group.addTask { @MainActor in
                    _ = HandoffManager.shared
                }
            #endif

            // Live Activities (iOS)
            #if os(iOS)
                group.addTask { @MainActor in
                    _ = LiveActivityManager.shared
                }
            #endif

            // Notifications
            group.addTask { @MainActor in
                _ = NotificationManager.shared
            }

            // Siri Shortcuts
            group.addTask { @MainActor in
                _ = SiriShortcutsManager.shared
            }

            // Focus Filters
            if #available(iOS 16.0, macOS 13.0, *) {
                group.addTask { @MainActor in
                    _ = FocusFilterManager.shared
                }
            }

            // Accessibility
            group.addTask { @MainActor in
                _ = AccessibilityManager.shared
            }
        }

        logger.info("All new feature integrations initialized")
    }

    /// Setup cross-feature communication
    public func setupFeatureIntegration() {
        // Keyboard shortcut for quick prompt
        KeyboardShortcutsSystem.shared.registerHandler(for: "quick-prompt") {
            Task { @MainActor in
                GlobalQuickPromptManager.shared.show()
            }
        }

        // Connect analytics to key events
        setupAnalyticsIntegration()

        // Setup notification handling
        setupNotificationIntegration()

        // Setup deep link routing
        setupDeepLinkIntegration()

        // Setup handoff for conversations
        setupHandoffIntegration()

        // Setup accessibility announcements
        setupAccessibilityIntegration()

        logger.info("Feature integration setup complete")
    }

    private func setupAnalyticsIntegration() {
        // Track conversation events
        NotificationCenter.default.addObserver(
            forName: .conversationCreated,
            object: nil,
            queue: .main
        ) { notification in
            if let id = notification.userInfo?["conversationId"] as? String {
                Task { @MainActor in
                    AnalyticsManager.shared.track("conversation_created", properties: [
                        "conversationId": id
                    ])
                }
            }
        }

        // Track agent events
        NotificationCenter.default.addObserver(
            forName: .agentStarted,
            object: nil,
            queue: .main
        ) { notification in
            if let name = notification.userInfo?["agentName"] as? String {
                Task { @MainActor in
                    AnalyticsManager.shared.track("agent_started", properties: [
                        "agentName": name
                    ])
                }
            }
        }

        // Track mission events
        NotificationCenter.default.addObserver(
            forName: .missionCompleted,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                AnalyticsManager.shared.track("mission_completed")
            }
        }
    }

    private func setupNotificationIntegration() {
        // Set notification delegate
        UNUserNotificationCenter.current().delegate = TheaNotificationDelegate.shared

        // Handle notification actions
        NotificationCenter.default.addObserver(
            forName: .notificationActionReceived,
            object: nil,
            queue: .main
        ) { notification in
            guard let result = notification.userInfo?["result"] as? NotificationActionResult else { return }

            Task { @MainActor in
                switch result {
                case let .reply(conversationId, text):
                    // Handle reply
                    self.handleNotificationReply(conversationId: conversationId, text: text)

                case let .openConversation(id):
                    _ = await DeepLinkRouter.shared.navigate(to: "/conversation/\(id)")

                case let .openAgent(id):
                    _ = await DeepLinkRouter.shared.navigate(to: "/agent/\(id)")

                case let .openMission(id):
                    _ = await DeepLinkRouter.shared.navigate(to: "/mission/\(id)")

                case .stopAgent:
                    // Stop the agent
                    break

                case .stopMission:
                    MissionOrchestrator.shared.cancelMission()

                default:
                    break
                }
            }
        }
    }

    private func handleNotificationReply(conversationId _: String, text _: String) {
        // Process the reply
        Task {
            // Add message to conversation
            // Send to AI
            // etc.
        }
    }

    private func setupDeepLinkIntegration() {
        // Register handlers for various routes
        DeepLinkRouter.shared.register("/quick-prompt") { _ async in
            await MainActor.run {
                GlobalQuickPromptManager.shared.show()
            }
            return true
        }

        DeepLinkRouter.shared.register("/settings/:section") { link async in
            if let section = link.parameters["section"] {
                // Navigate to settings section
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: .openSettingsSection,
                        object: nil,
                        userInfo: ["section": section]
                    )
                }
            }
            return true
        }

        DeepLinkRouter.shared.register("/backup/restore") { _ async in
            // Open backup restore UI
            true
        }
    }

    private func setupHandoffIntegration() {
        #if os(macOS)
            // Start handoff for active conversations
            NotificationCenter.default.addObserver(
                forName: .conversationBecameActive,
                object: nil,
                queue: .main
            ) { notification in
                guard let id = notification.userInfo?["conversationId"] as? String,
                      let title = notification.userInfo?["title"] as? String else { return }

                // Extract preview value before crossing async boundary
                let preview = (notification.userInfo?["preview"] as? String) ?? ""
                Task { @MainActor in
                    HandoffManager.shared.startConversationActivity(
                        conversationId: id,
                        title: title,
                        preview: preview
                    )
                }
            }
        #endif
    }

    private func setupAccessibilityIntegration() {
        // Announce AI responses
        NotificationCenter.default.addObserver(
            forName: .aiResponseReceived,
            object: nil,
            queue: .main
        ) { notification in
            // Extract response before entering Task to avoid data race
            let response = notification.userInfo?["response"] as? String
            Task { @MainActor in
                if AccessibilityManager.shared.isVoiceOverRunning,
                   AccessibilityManager.shared.settings.autoReadResponses
                {
                    if let response {
                        AccessibilityManager.shared.announce("AI responded: \(response.prefix(200))")
                    }
                }
            }
        }
    }

    // MARK: - Lifecycle

    /// Handle app becoming active
    public func handleAppBecameActive() {
        // Check for pending shortcuts
        SiriShortcutsManager.shared.handlePendingShortcuts()

        // Check for shared content
        Task { @MainActor in
            if !ShareExtensionManager.shared.pendingSharedContent.isEmpty {
                // Process shared content
                for content in ShareExtensionManager.shared.pendingSharedContent {
                    let result = await ShareExtensionManager.shared.processSharedContent(content)
                    if result.success {
                        ShareExtensionManager.shared.removeContent(content)
                    }
                }
            }
        }

        // Import migrated data from App Clip
        #if os(iOS)
            if let data = AppClipManager.shared.importMigratedData() {
                // Process migrated data
                handleMigratedAppClipData(data)
            }
        #endif
    }

    #if os(iOS)
        private func handleMigratedAppClipData(_ data: AppClipData) {
            // Import conversations
            for _ in data.conversations {
                // Create conversation from data - implementation pending
            }

            // Apply preferences
            // ...
        }
    #endif

    /// Handle URL opening
    public func handleURL(_ url: URL) -> Bool {
        // Check for App Clip invocation
        #if os(iOS)
            if url.scheme == "https", url.host?.contains("appclip") == true {
                AppClipManager.shared.handleInvocation(url: url)
                return true
            }
        #endif

        // Handle deep links
        Task {
            _ = await DeepLinkRouter.shared.handle(url)
        }

        return true
    }

    /// Handle user activity (Handoff, Spotlight, etc.)
    public func handleUserActivity(_ activity: NSUserActivity) -> Bool {
        #if os(macOS)
            // Handoff
            if HandoffManager.shared.handleIncomingActivity(activity) {
                // Handoff was handled
                return true
            }
        #endif

        // Spotlight
        if let conversationId = SpotlightIntegration.shared.handleSpotlightActivity(activity) {
            Task {
                _ = await DeepLinkRouter.shared.navigate(to: "/conversation/\(conversationId)")
            }
            return true
        }

        return false
    }
}

// MARK: - Additional Notifications

public extension Notification.Name {
    static let conversationCreated = Notification.Name("thea.conversation.created")
    static let conversationBecameActive = Notification.Name("thea.conversation.becameActive")
    static let agentStarted = Notification.Name("thea.agent.started")
    // missionCompleted defined in MissionOrchestrator.swift
    static let aiResponseReceived = Notification.Name("thea.ai.responseReceived")
    static let openSettingsSection = Notification.Name("thea.settings.openSection")
}
