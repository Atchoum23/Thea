// FocusFilterManager.swift
// Focus Filter support for iOS/macOS Focus modes

import AppIntents
import Foundation
import OSLog
#if canImport(UIKit)
    import UIKit
#endif

// MARK: - Focus Filter

@available(iOS 16.0, macOS 13.0, *)
public struct TheaFocusFilter: SetFocusFilterIntent {
    nonisolated(unsafe) public static var title: LocalizedStringResource = "Thea Focus Settings"
    nonisolated(unsafe) public static var description: IntentDescription? = IntentDescription("Configure Thea behavior during Focus mode")

    @Parameter(title: "Notification Mode", default: .smart)
    public var notificationMode: FocusNotificationMode

    @Parameter(title: "Allow Urgent Only", default: false)
    public var urgentOnly: Bool

    @Parameter(title: "Pause Agents", default: false)
    public var pauseAgents: Bool

    @Parameter(title: "Quick Prompt Enabled", default: true)
    public var quickPromptEnabled: Bool

    @Parameter(title: "Allowed Conversations")
    public var allowedConversations: [String]?

    public init() {
        allowedConversations = nil
    }

    public func perform() async throws -> some IntentResult {
        // Apply focus filter settings
        await FocusFilterManager.shared.applyFilter(
            notificationMode: notificationMode,
            urgentOnly: urgentOnly,
            pauseAgents: pauseAgents,
            quickPromptEnabled: quickPromptEnabled,
            allowedConversations: allowedConversations
        )

        return .result()
    }

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "Thea Focus Settings",
            subtitle: "Customize Thea during Focus"
        )
    }
}

// MARK: - Focus Notification Mode

@available(iOS 16.0, macOS 13.0, *)
public enum FocusNotificationMode: String, AppEnum {
    case all
    case smart
    case important
    case none

    nonisolated(unsafe) public static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Notification Mode")

    nonisolated(unsafe) public static var caseDisplayRepresentations: [FocusNotificationMode: DisplayRepresentation] = [
        .all: DisplayRepresentation(title: "All Notifications", subtitle: "Receive all Thea notifications"),
        .smart: DisplayRepresentation(title: "Smart", subtitle: "AI determines importance"),
        .important: DisplayRepresentation(title: "Important Only", subtitle: "Only critical notifications"),
        .none: DisplayRepresentation(title: "None", subtitle: "Silence all notifications")
    ]
}

// MARK: - Focus Filter Manager

@available(iOS 16.0, macOS 13.0, *)
@MainActor
public final class FocusFilterManager: ObservableObject {
    public static let shared = FocusFilterManager()

    private let logger = Logger(subsystem: "com.thea.app", category: "FocusFilter")

    // MARK: - Current State

    @Published public private(set) var isFilterActive = false
    @Published public private(set) var currentNotificationMode: FocusNotificationMode = .all
    @Published public private(set) var urgentOnly = false
    @Published public private(set) var agentsPaused = false
    @Published public private(set) var quickPromptEnabled = true
    @Published public private(set) var allowedConversations: Set<String> = []

    // MARK: - Initialization

    private init() {}

    // MARK: - Apply Filter

    func applyFilter(
        notificationMode: FocusNotificationMode,
        urgentOnly: Bool,
        pauseAgents: Bool,
        quickPromptEnabled: Bool,
        allowedConversations: [String]?
    ) {
        isFilterActive = true
        currentNotificationMode = notificationMode
        self.urgentOnly = urgentOnly
        agentsPaused = pauseAgents
        self.quickPromptEnabled = quickPromptEnabled

        if let allowed = allowedConversations {
            self.allowedConversations = Set(allowed)
        } else {
            self.allowedConversations = []
        }

        logger.info("Focus filter applied: mode=\(notificationMode.rawValue), urgentOnly=\(urgentOnly), pauseAgents=\(pauseAgents)")

        // Apply settings
        applySettings()

        // Notify the system
        NotificationCenter.default.post(
            name: .focusFilterApplied,
            object: nil,
            userInfo: [
                "notificationMode": notificationMode,
                "urgentOnly": urgentOnly,
                "pauseAgents": pauseAgents
            ]
        )
    }

    /// Clear the focus filter
    public func clearFilter() {
        isFilterActive = false
        currentNotificationMode = .all
        urgentOnly = false
        agentsPaused = false
        quickPromptEnabled = true
        allowedConversations = []

        logger.info("Focus filter cleared")

        // Restore default settings
        restoreDefaults()

        NotificationCenter.default.post(name: .focusFilterCleared, object: nil)
    }

    // MARK: - Settings Application

    private func applySettings() {
        // Update notification manager
        Task {
            var settings = NotificationManager.shared.settings

            switch currentNotificationMode {
            case .none:
                settings.conversationNotifications = false
                settings.agentNotifications = false
                settings.missionNotifications = false
            case .important:
                settings.conversationNotifications = false
                settings.agentNotifications = true
                settings.missionNotifications = true
            case .smart:
                settings.conversationNotifications = true
                settings.agentNotifications = true
                settings.missionNotifications = true
            case .all:
                settings.conversationNotifications = true
                settings.agentNotifications = true
                settings.missionNotifications = true
            }

            NotificationManager.shared.settings = settings
            NotificationManager.shared.saveSettings()
        }

        // Pause agents if requested
        if agentsPaused {
            // Signal to pause background agents
            NotificationCenter.default.post(name: .pauseAllAgents, object: nil)
        }

        // Update quick prompt availability
        if !quickPromptEnabled {
            GlobalQuickPromptManager.shared.hide()
        }
    }

    private func restoreDefaults() {
        // Restore notification settings
        Task {
            var settings = NotificationManager.shared.settings
            settings.conversationNotifications = true
            settings.agentNotifications = true
            settings.missionNotifications = true
            NotificationManager.shared.settings = settings
            NotificationManager.shared.saveSettings()
        }

        // Resume agents
        NotificationCenter.default.post(name: .resumeAllAgents, object: nil)
    }

    // MARK: - Query Methods

    /// Check if a notification should be delivered
    public func shouldDeliverNotification(
        type _: String,
        priority: NotificationPriority,
        conversationId: String? = nil
    ) -> Bool {
        guard isFilterActive else { return true }

        // Check urgent only filter
        if urgentOnly, priority != .critical, priority != .high {
            return false
        }

        // Check allowed conversations
        if let convId = conversationId,
           !allowedConversations.isEmpty,
           !allowedConversations.contains(convId)
        {
            return false
        }

        // Check notification mode
        switch currentNotificationMode {
        case .none:
            return false
        case .important:
            return priority == .critical || priority == .high
        case .smart:
            // AI would determine importance here
            return true
        case .all:
            return true
        }
    }

    /// Check if quick prompt should be available
    public func isQuickPromptAvailable() -> Bool {
        guard isFilterActive else { return true }
        return quickPromptEnabled
    }

    /// Check if agents should run
    public func shouldRunAgents() -> Bool {
        guard isFilterActive else { return true }
        return !agentsPaused
    }
}

// MARK: - Notifications

public extension Notification.Name {
    static let focusFilterApplied = Notification.Name("thea.focusFilter.applied")
    static let focusFilterCleared = Notification.Name("thea.focusFilter.cleared")
    static let pauseAllAgents = Notification.Name("thea.agents.pauseAll")
    static let resumeAllAgents = Notification.Name("thea.agents.resumeAll")
}

// MARK: - Focus State Observer

@available(iOS 16.0, macOS 13.0, *)
@MainActor
public final class FocusStateObserver: ObservableObject {
    public static let shared = FocusStateObserver()

    @Published public private(set) var isFocusActive = false
    @Published public private(set) var currentFocusName: String?

    private init() {
        setupObserver()
    }

    private func setupObserver() {
        // Observe focus state changes
        #if os(iOS)
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(focusDidChange),
                name: UIApplication.didBecomeActiveNotification,
                object: nil
            )
        #endif
    }

    @objc private func focusDidChange() {
        // Check current focus state
        // This would use the appropriate APIs to detect focus state
    }
}
