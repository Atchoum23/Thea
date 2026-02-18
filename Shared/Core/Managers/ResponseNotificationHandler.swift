//
//  ResponseNotificationHandler.swift
//  Thea
//
//  Handles system notifications for:
//  - Response completion (when app is in background)
//  - Attention required (errors, clarifications)
//  - Background task completion
//  - Scheduled prompt execution
//

import Foundation
import OSLog

private let responseNotificationLogger = Logger(subsystem: "ai.thea.app", category: "ResponseNotificationHandler")
import UserNotifications
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
import OSLog
#endif

// MARK: - Response Notification Handler

@MainActor
final class ResponseNotificationHandler: ObservableObject {
    static let shared = ResponseNotificationHandler()

    @Published var isAuthorized = false
    @Published var pendingNotifications: [String] = []

    private let center = UNUserNotificationCenter.current()
    private var settings = SettingsManager.shared

    // MARK: - Notification Categories

    static let categoryResponseComplete = "RESPONSE_COMPLETE"
    static let categoryAttentionRequired = "ATTENTION_REQUIRED"
    static let categoryBackgroundTask = "BACKGROUND_TASK"
    static let categoryScheduledPrompt = "SCHEDULED_PROMPT"

    // MARK: - Actions

    static let actionView = "VIEW_ACTION"
    static let actionDismiss = "DISMISS_ACTION"
    static let actionRegenerate = "REGENERATE_ACTION"

    private init() {
        Task {
            await checkAuthorization()
            setupCategories()
        }
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        do {
            let options: UNAuthorizationOptions = [.alert, .sound, .badge]
            let granted = try await center.requestAuthorization(options: options)
            isAuthorized = granted
            return granted
        } catch {
            print("❌ Notification authorization failed: \(error)")
            return false
        }
    }

    func checkAuthorization() async {
        let settings = await center.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    // MARK: - Category Setup

    private func setupCategories() {
        // Response Complete category
        let viewAction = UNNotificationAction(
            identifier: Self.actionView,
            title: "View",
            options: [.foreground]
        )

        let dismissAction = UNNotificationAction(
            identifier: Self.actionDismiss,
            title: "Dismiss",
            options: []
        )

        let regenerateAction = UNNotificationAction(
            identifier: Self.actionRegenerate,
            title: "Regenerate",
            options: [.foreground]
        )

        let responseCategory = UNNotificationCategory(
            identifier: Self.categoryResponseComplete,
            actions: [viewAction, dismissAction],
            intentIdentifiers: []
        )

        let attentionCategory = UNNotificationCategory(
            identifier: Self.categoryAttentionRequired,
            actions: [viewAction, dismissAction],
            intentIdentifiers: []
        )

        let backgroundCategory = UNNotificationCategory(
            identifier: Self.categoryBackgroundTask,
            actions: [viewAction, regenerateAction, dismissAction],
            intentIdentifiers: []
        )

        center.setNotificationCategories([
            responseCategory,
            attentionCategory,
            backgroundCategory
        ])
    }

    // MARK: - Send Notifications

    /// Notify when AI response is complete
    func notifyResponseComplete(
        conversationId: UUID,
        conversationTitle: String,
        previewText: String
    ) async {
        guard settings.notificationsEnabled && settings.notifyOnResponseComplete else { return }
        guard isAuthorized else { return }

        // Don't notify if app is in foreground
        guard !isAppInForeground else { return }

        let content = UNMutableNotificationContent()
        content.title = "THEA"
        content.subtitle = conversationTitle
        content.body = String(previewText.prefix(100)) + (previewText.count > 100 ? "..." : "")
        content.categoryIdentifier = Self.categoryResponseComplete
        content.userInfo = ["conversationId": conversationId.uuidString]

        if settings.playNotificationSound {
            content.sound = .default
        }

        // Thread identifier groups notifications by conversation
        content.threadIdentifier = conversationId.uuidString

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )

        do {
            try await center.add(request)
            updateBadgeCount()
        } catch {
            print("❌ Failed to send response notification: \(error)")
        }
    }

    /// Notify when attention is required (error, clarification needed)
    func notifyAttentionRequired(
        conversationId: UUID,
        conversationTitle: String,
        reason: String
    ) async {
        guard settings.notificationsEnabled && settings.notifyOnAttentionRequired else { return }
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "THEA - Attention Required"
        content.subtitle = conversationTitle
        content.body = reason
        content.categoryIdentifier = Self.categoryAttentionRequired
        content.userInfo = [
            "conversationId": conversationId.uuidString,
            "attentionRequired": true
        ]

        if settings.playNotificationSound {
            content.sound = .defaultCritical
        }

        content.threadIdentifier = conversationId.uuidString

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        do {
            try await center.add(request)
            updateBadgeCount()
        } catch {
            print("❌ Failed to send attention notification: \(error)")
        }
    }

    /// Notify when background task completes
    func notifyBackgroundTaskComplete(
        taskName: String,
        result: String
    ) async {
        guard settings.notificationsEnabled else { return }
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "THEA - Task Complete"
        content.subtitle = taskName
        content.body = result
        content.categoryIdentifier = Self.categoryBackgroundTask

        if settings.playNotificationSound {
            content.sound = .default
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        do {
            try await center.add(request)
        } catch {
            print("❌ Failed to send task notification: \(error)")
        }
    }

    // MARK: - Badge Management

    func updateBadgeCount() {
        guard settings.showDockBadge else {
            clearBadge()
            return
        }

        // Count unread conversations
        let unreadCount = ChatManager.shared.conversations.filter { $0.hasUnreadMessages }.count

        #if os(macOS)
        if unreadCount > 0 {
            NSApp.dockTile.badgeLabel = "\(unreadCount)"
        } else {
            NSApp.dockTile.badgeLabel = nil
        }
        #elseif os(iOS)
        UNUserNotificationCenter.current().setBadgeCount(unreadCount)
        #endif
    }

    func clearBadge() {
        #if os(macOS)
        NSApp.dockTile.badgeLabel = nil
        #elseif os(iOS)
        UNUserNotificationCenter.current().setBadgeCount(0)
        #endif
    }

    // MARK: - Helpers

    private var isAppInForeground: Bool {
        #if os(macOS)
        return NSApp.isActive
        #elseif os(iOS)
        return UIApplication.shared.applicationState == .active
        #else
        return true
        #endif
    }

    /// Remove pending notifications for a conversation
    func clearNotifications(for conversationId: UUID) {
        center.getDeliveredNotifications { notifications in
            let idsToRemove = notifications
                .filter { notification in
                    notification.request.content.userInfo["conversationId"] as? String == conversationId.uuidString
                }
                .map(\.request.identifier)

            Task { @MainActor in
                self.center.removeDeliveredNotifications(withIdentifiers: idsToRemove)
            }
        }
    }

    /// Clear all THEA notifications
    func clearAllNotifications() {
        center.removeAllDeliveredNotifications()
        center.removeAllPendingNotificationRequests()
        clearBadge()
    }
}

// MARK: - Response Notification Delegate

@MainActor
final class ResponseNotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = ResponseNotificationDelegate()

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Show banner even when app is in foreground (for background tasks)
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo

        switch response.actionIdentifier {
        case ResponseNotificationHandler.actionView, UNNotificationDefaultActionIdentifier:
            // Navigate to conversation
            if let conversationIdString = userInfo["conversationId"] as? String,
               let conversationId = UUID(uuidString: conversationIdString) {
                await MainActor.run {
                    self.navigateToConversation(conversationId)
                }
            }

        case ResponseNotificationHandler.actionRegenerate:
            // Regenerate last response
            if let conversationIdString = userInfo["conversationId"] as? String,
               let conversationId = UUID(uuidString: conversationIdString) {
                await self.regenerateResponse(for: conversationId)
            }

        case ResponseNotificationHandler.actionDismiss:
            // Just dismiss - no action needed
            break

        default:
            break
        }
    }

    private func navigateToConversation(_ id: UUID) {
        // Find and select the conversation
        if let conversation = ChatManager.shared.conversations.first(where: { $0.id == id }) {
            ChatManager.shared.selectConversation(conversation)
            conversation.markAsViewed()

            // Bring app to foreground
            #if os(macOS)
            NSApp.activate(ignoringOtherApps: true)
            #endif
        }
    }

    private func regenerateResponse(for conversationId: UUID) async {
        if let conversation = ChatManager.shared.conversations.first(where: { $0.id == conversationId }) {
            do {
                try await ChatManager.shared.regenerateLastMessage(in: conversation)
            } catch {
                responseNotificationLogger.error("Failed to regenerate last message: \(error.localizedDescription)")
            }
        }
    }
}
