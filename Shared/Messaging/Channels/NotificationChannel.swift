// NotificationChannel.swift
// Thea — System notification channel for MessagingHub
//
// Observes UNUserNotificationCenter for delivered notifications,
// converts them to UnifiedMessage, and routes through MessagingHub.
// Integrates with existing NotificationIntelligenceService for
// classification and auto-action.

import Foundation
import UserNotifications
import OSLog

private let notifChannelLogger = Logger(subsystem: "ai.thea.app", category: "NotificationChannel")

/// Bridges system notifications to MessagingHub.
@MainActor
final class NotificationChannel: NSObject, ObservableObject {
    static let shared = NotificationChannel()

    // MARK: - Published State

    @Published private(set) var isObserving = false
    @Published private(set) var processedCount = 0
    @Published private(set) var lastNotificationAt: Date?

    // MARK: - Configuration

    var enabled = true
    var pollInterval: TimeInterval = 30
    var excludedApps: Set<String> = []

    // MARK: - Private

    private var pollTask: Task<Void, Never>?
    private var processedIDs: Set<String> = []
    private let maxProcessedIDs = 5000

    // MARK: - Init

    private override init() {
        super.init()
    }

    // MARK: - Observation Control

    func startObserving() {
        guard enabled, !isObserving else { return }
        isObserving = true

        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.checkDeliveredNotifications()
                let interval = self?.pollInterval ?? 30
                try? await Task.sleep(for: .seconds(interval))
            }
        }

        notifChannelLogger.info("NotificationChannel started observing (interval: \(self.pollInterval)s)")
    }

    func stopObserving() {
        pollTask?.cancel()
        pollTask = nil
        isObserving = false
        notifChannelLogger.info("NotificationChannel stopped observing")
    }

    // MARK: - Notification Processing

    private func checkDeliveredNotifications() async {
        let center = UNUserNotificationCenter.current()
        let delivered = await center.deliveredNotifications()

        for notification in delivered {
            let identifier = notification.request.identifier
            guard !processedIDs.contains(identifier) else { continue }

            // Skip excluded apps
            let bundleID = notification.request.content.threadIdentifier
            if excludedApps.contains(bundleID) { continue }

            // Convert to UnifiedMessage
            let message = convertToUnifiedMessage(notification)

            // Route through MessagingHub
            await MessagingHub.shared.routeIncomingMessage(message)

            processedIDs.insert(identifier)
            processedCount += 1
            lastNotificationAt = Date()
        }

        // Cap processed ID set
        if processedIDs.count > maxProcessedIDs {
            let sorted = Array(processedIDs).sorted()
            processedIDs = Set(sorted.suffix(maxProcessedIDs / 2))
        }
    }

    private func convertToUnifiedMessage(_ notification: UNNotification) -> UnifiedMessage {
        let content = notification.request.content
        let title = content.title
        let body = content.body
        let subtitle = content.subtitle

        var messageContent = title
        if !subtitle.isEmpty {
            messageContent += " — \(subtitle)"
        }
        if !body.isEmpty {
            messageContent += "\n\(body)"
        }

        var metadata: [String: String] = [:]
        metadata["notification_id"] = notification.request.identifier
        metadata["thread_id"] = content.threadIdentifier
        metadata["category_id"] = content.categoryIdentifier

        // Extract app name from thread identifier or category
        let senderID = content.threadIdentifier.isEmpty
            ? content.categoryIdentifier.isEmpty ? "system" : content.categoryIdentifier
            : content.threadIdentifier

        return UnifiedMessage(
            channelType: .notification,
            channelID: "system_notifications",
            senderID: senderID,
            senderName: title,
            content: messageContent,
            timestamp: notification.date,
            metadata: metadata
        )
    }

    // MARK: - Notification Actions

    /// Clear a specific notification from the notification center.
    func clearNotification(identifier: String) {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
        notifChannelLogger.info("Cleared notification: \(identifier)")
    }

    /// Clear all notifications.
    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        notifChannelLogger.info("Cleared all notifications")
    }

    /// Request notification authorization.
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            return granted
        } catch {
            notifChannelLogger.error("Notification auth failed: \(error.localizedDescription)")
            return false
        }
    }
}
