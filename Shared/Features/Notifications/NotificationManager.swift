// NotificationManager.swift
// Comprehensive notification management with rich notifications

import Combine
import Foundation
import OSLog
import UserNotifications

// MARK: - Notification Manager

/// Manages all notifications for Thea
@MainActor
public final class NotificationManager: ObservableObject {
    public static let shared = NotificationManager()

    private let logger = Logger(subsystem: "com.thea.app", category: "Notifications")
    private let center = UNUserNotificationCenter.current()

    // MARK: - Published State

    @Published public private(set) var isAuthorized = false
    @Published public private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published public var settings = NotificationSettings()

    // MARK: - Categories

    public enum Category: String {
        case conversation = "CONVERSATION"
        case agent = "AGENT"
        case reminder = "REMINDER"
        case system = "SYSTEM"
        case mission = "MISSION"
    }

    // MARK: - Actions

    public enum Action: String {
        case reply = "REPLY_ACTION"
        case view = "VIEW_ACTION"
        case dismiss = "DISMISS_ACTION"
        case snooze = "SNOOZE_ACTION"
        case stop = "STOP_ACTION"
    }

    // MARK: - Initialization

    private init() {
        setupCategories()
        loadSettings()
        Task {
            await checkAuthorizationStatus()
        }
    }

    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: "notifications.settings"),
           let loadedSettings = try? JSONDecoder().decode(NotificationSettings.self, from: data)
        {
            settings = loadedSettings
        }
    }

    public func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: "notifications.settings")
        }
    }

    // MARK: - Authorization

    /// Request notification authorization
    public func requestAuthorization() async -> Bool {
        do {
            let options: UNAuthorizationOptions = [.alert, .sound, .badge, .provisional]
            let granted = try await center.requestAuthorization(options: options)
            isAuthorized = granted
            await checkAuthorizationStatus()

            logger.info("Notification authorization: \(granted ? "granted" : "denied")")
            return granted
        } catch {
            logger.error("Failed to request notification authorization: \(error.localizedDescription)")
            return false
        }
    }

    /// Check current authorization status
    public func checkAuthorizationStatus() async {
        // Extract values in nonisolated context to avoid Sendable issues
        let status = await { @Sendable in
            await center.notificationSettings().authorizationStatus
        }()
        authorizationStatus = status
        isAuthorized = status == .authorized || status == .provisional
    }

    // MARK: - Category Setup

    private func setupCategories() {
        // Conversation category with reply action
        let replyAction = UNTextInputNotificationAction(
            identifier: Action.reply.rawValue,
            title: "Reply",
            options: [.foreground],
            textInputButtonTitle: "Send",
            textInputPlaceholder: "Type your reply..."
        )

        let viewAction = UNNotificationAction(
            identifier: Action.view.rawValue,
            title: "View",
            options: [.foreground]
        )

        let dismissAction = UNNotificationAction(
            identifier: Action.dismiss.rawValue,
            title: "Dismiss",
            options: [.destructive]
        )

        let snoozeAction = UNNotificationAction(
            identifier: Action.snooze.rawValue,
            title: "Snooze",
            options: []
        )

        let stopAction = UNNotificationAction(
            identifier: Action.stop.rawValue,
            title: "Stop",
            options: [.destructive, .authenticationRequired]
        )

        let conversationCategory = UNNotificationCategory(
            identifier: Category.conversation.rawValue,
            actions: [replyAction, viewAction, dismissAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        let agentCategory = UNNotificationCategory(
            identifier: Category.agent.rawValue,
            actions: [viewAction, stopAction, dismissAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        let reminderCategory = UNNotificationCategory(
            identifier: Category.reminder.rawValue,
            actions: [viewAction, snoozeAction, dismissAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        let missionCategory = UNNotificationCategory(
            identifier: Category.mission.rawValue,
            actions: [viewAction, stopAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        let systemCategory = UNNotificationCategory(
            identifier: Category.system.rawValue,
            actions: [viewAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([
            conversationCategory,
            agentCategory,
            reminderCategory,
            missionCategory,
            systemCategory
        ])
    }

    // MARK: - Send Notifications

    /// Send a conversation notification
    public func sendConversationNotification(
        conversationId: String,
        title: String,
        body: String,
        preview: String? = nil
    ) async {
        guard settings.conversationNotifications else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = Category.conversation.rawValue
        content.sound = settings.soundEnabled ? .default : nil
        content.threadIdentifier = "conversation-\(conversationId)"
        content.userInfo = [
            "conversationId": conversationId,
            "type": "conversation"
        ]

        // Rich notification with preview
        if let preview {
            content.subtitle = preview
        }

        let request = UNNotificationRequest(
            identifier: "conversation-\(conversationId)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        do {
            try await center.add(request)
            logger.info("Sent conversation notification: \(conversationId)")
        } catch {
            logger.error("Failed to send notification: \(error.localizedDescription)")
        }
    }

    /// Send an agent notification
    public func sendAgentNotification(
        agentId: String,
        agentName: String,
        status: String,
        detail: String? = nil
    ) async {
        guard settings.agentNotifications else { return }

        let content = UNMutableNotificationContent()
        content.title = agentName
        content.body = status
        content.categoryIdentifier = Category.agent.rawValue
        content.sound = settings.soundEnabled ? .default : nil
        content.threadIdentifier = "agent-\(agentId)"
        content.userInfo = [
            "agentId": agentId,
            "type": "agent"
        ]

        if let detail {
            content.subtitle = detail
        }

        let request = UNNotificationRequest(
            identifier: "agent-\(agentId)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        do {
            try await center.add(request)
            logger.info("Sent agent notification: \(agentName)")
        } catch {
            logger.error("Failed to send notification: \(error.localizedDescription)")
        }
    }

    /// Send a mission notification
    public func sendMissionNotification(
        missionId: String,
        title: String,
        status: String,
        progress: Double? = nil
    ) async {
        guard settings.missionNotifications else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = status
        content.categoryIdentifier = Category.mission.rawValue
        content.sound = settings.soundEnabled ? .default : nil
        content.threadIdentifier = "mission-\(missionId)"
        content.userInfo = [
            "missionId": missionId,
            "type": "mission"
        ]

        if let progress {
            content.subtitle = "\(Int(progress * 100))% complete"
        }

        let request = UNNotificationRequest(
            identifier: "mission-\(missionId)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        do {
            try await center.add(request)
        } catch {
            logger.error("Failed to send mission notification: \(error.localizedDescription)")
        }
    }

    /// Schedule a reminder notification
    public func scheduleReminder(
        id: String,
        title: String,
        body: String,
        date: Date,
        repeats: Bool = false
    ) async {
        guard settings.reminderNotifications else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = Category.reminder.rawValue
        content.sound = settings.soundEnabled ? .default : nil
        content.userInfo = [
            "reminderId": id,
            "type": "reminder"
        ]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: repeats)

        let request = UNNotificationRequest(
            identifier: "reminder-\(id)",
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            logger.info("Scheduled reminder: \(id) for \(date)")
        } catch {
            logger.error("Failed to schedule reminder: \(error.localizedDescription)")
        }
    }

    /// Send a system notification
    public func sendSystemNotification(
        title: String,
        body: String,
        priority: NotificationPriority = .normal
    ) async {
        guard settings.systemNotifications else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = Category.system.rawValue
        content.userInfo = ["type": "system"]

        switch priority {
        case .critical:
            content.interruptionLevel = .critical
            content.sound = .defaultCritical
        case .high:
            content.interruptionLevel = .timeSensitive
            content.sound = settings.soundEnabled ? .default : nil
        case .normal:
            content.interruptionLevel = .active
            content.sound = settings.soundEnabled ? .default : nil
        case .low:
            content.interruptionLevel = .passive
            content.sound = nil
        case .silent:
            content.interruptionLevel = .passive
            content.sound = nil
        }

        let request = UNNotificationRequest(
            identifier: "system-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        do {
            try await center.add(request)
        } catch {
            logger.error("Failed to send system notification: \(error.localizedDescription)")
        }
    }

    // MARK: - Management

    /// Cancel a notification
    public func cancelNotification(identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    /// Cancel all notifications for a thread
    public func cancelNotifications(forThread threadId: String) {
        Task {
            // Extract identifiers in nonisolated context to avoid Sendable issues
            let toRemove = await { @Sendable [center] in
                let delivered = await center.deliveredNotifications()
                return delivered
                    .filter { $0.request.content.threadIdentifier == threadId }
                    .map(\.request.identifier)
            }()
            center.removeDeliveredNotifications(withIdentifiers: toRemove)
        }
    }

    /// Cancel all notifications
    public func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    /// Update badge count
    public func updateBadgeCount(_ count: Int) async {
        do {
            try await center.setBadgeCount(count)
        } catch {
            logger.error("Failed to update badge: \(error.localizedDescription)")
        }
    }

    /// Clear badge
    public func clearBadge() async {
        await updateBadgeCount(0)
    }

    // MARK: - Handle Actions

    /// Handle notification action
    public func handleAction(
        _ actionIdentifier: String,
        for notification: UNNotification,
        withResponse textResponse: String? = nil
    ) async -> NotificationActionResult {
        let userInfo = notification.request.content.userInfo
        // category identifier available for future category-specific handling
        _ = notification.request.content.categoryIdentifier

        switch actionIdentifier {
        case Action.reply.rawValue:
            if let conversationId = userInfo["conversationId"] as? String,
               let reply = textResponse
            {
                return .reply(conversationId: conversationId, text: reply)
            }

        case Action.view.rawValue:
            if let conversationId = userInfo["conversationId"] as? String {
                return .openConversation(id: conversationId)
            } else if let agentId = userInfo["agentId"] as? String {
                return .openAgent(agentId)
            } else if let missionId = userInfo["missionId"] as? String {
                return .openMission(missionId)
            }

        case Action.snooze.rawValue:
            // Reschedule notification for 15 minutes later
            // swiftlint:disable:next force_cast
            let content = notification.request.content.mutableCopy() as! UNMutableNotificationContent
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 900, repeats: false)
            let request = UNNotificationRequest(
                identifier: notification.request.identifier + "-snoozed",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
            return .snoozed(minutes: 15)

        case Action.stop.rawValue:
            if let agentId = userInfo["agentId"] as? String {
                return .stopAgent(agentId)
            } else if let missionId = userInfo["missionId"] as? String {
                return .stopMission(missionId)
            }

        case Action.dismiss.rawValue:
            return .dismissed

        default:
            break
        }

        return .none
    }
}

// MARK: - Types

public struct NotificationSettings: Codable {
    public var soundEnabled: Bool = true
    public var badgeEnabled: Bool = true
    public var conversationNotifications: Bool = true
    public var agentNotifications: Bool = true
    public var missionNotifications: Bool = true
    public var reminderNotifications: Bool = true
    public var systemNotifications: Bool = true
    public var quietHoursEnabled: Bool = false
    public var quietHoursStart: Date = Calendar.current.date(from: DateComponents(hour: 22)) ?? Date()
    public var quietHoursEnd: Date = Calendar.current.date(from: DateComponents(hour: 7)) ?? Date()
}

public enum AlertPriority {
    case critical
    case high
    case normal
    case low
}

// NotificationActionResult and TheaNotificationDelegate are defined in NotificationService.swift

// MARK: - Notifications

public extension Notification.Name {
    static let notificationActionReceived = Notification.Name("thea.notification.actionReceived")
}
