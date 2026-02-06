//
//  NotificationCategories.swift
//  Thea
//
//  Created by Claude Code on 2026-01-20
//  Copyright © 2026. All rights reserved.
//

import Foundation
import UserNotifications

// MARK: - Notification Category

/// Defines all notification categories used by Thea
public enum NotificationCategory: String, Codable, Sendable, CaseIterable {
    case general = "THEA_GENERAL"
    case aiTask = "THEA_AI_TASK"
    case aiResponse = "THEA_AI_RESPONSE"
    case reminder = "THEA_REMINDER"
    case sync = "THEA_SYNC"
    case health = "THEA_HEALTH"
    case financial = "THEA_FINANCIAL"
    case system = "THEA_SYSTEM"
    case error = "THEA_ERROR"
    case achievement = "THEA_ACHIEVEMENT"

    public var identifier: String { rawValue }

    public var displayName: String {
        switch self {
        case .general: "General"
        case .aiTask: "AI Tasks"
        case .aiResponse: "AI Responses"
        case .reminder: "Reminders"
        case .sync: "Sync"
        case .health: "Health"
        case .financial: "Financial"
        case .system: "System"
        case .error: "Errors"
        case .achievement: "Achievements"
        }
    }

    public var description: String {
        switch self {
        case .general:
            "General notifications from Thea"
        case .aiTask:
            "Updates about AI task progress and completion"
        case .aiResponse:
            "New AI responses in conversations"
        case .reminder:
            "Scheduled reminders and alerts"
        case .sync:
            "Sync status across devices"
        case .health:
            "Health tracking insights and alerts"
        case .financial:
            "Financial updates and alerts"
        case .system:
            "System status and updates"
        case .error:
            "Error notifications requiring attention"
        case .achievement:
            "Achievement unlocks and milestones"
        }
    }

    public var icon: String {
        switch self {
        case .general: "bell"
        case .aiTask: "cpu"
        case .aiResponse: "bubble.left.and.bubble.right"
        case .reminder: "clock"
        case .sync: "arrow.triangle.2.circlepath"
        case .health: "heart"
        case .financial: "dollarsign.circle"
        case .system: "gear"
        case .error: "exclamationmark.triangle"
        case .achievement: "star"
        }
    }

    /// Actions available for this category
    public var actions: [UNNotificationAction] {
        switch self {
        case .general:
            [
                NotificationAction.open.unAction,
                NotificationAction.dismiss.unAction
            ]

        case .aiTask:
            [
                NotificationAction.viewDetails.unAction,
                NotificationAction.retry.unAction,
                NotificationAction.dismiss.unAction
            ]

        case .aiResponse:
            [
                NotificationAction.reply.unAction,
                NotificationAction.viewConversation.unAction,
                NotificationAction.dismiss.unAction
            ]

        case .reminder:
            [
                NotificationAction.markComplete.unAction,
                NotificationAction.snooze15.unAction,
                NotificationAction.snooze1Hour.unAction,
                NotificationAction.dismiss.unAction
            ]

        case .sync:
            [
                NotificationAction.viewDetails.unAction,
                NotificationAction.dismiss.unAction
            ]

        case .health:
            [
                NotificationAction.viewDetails.unAction,
                NotificationAction.logEntry.unAction,
                NotificationAction.dismiss.unAction
            ]

        case .financial:
            [
                NotificationAction.viewDetails.unAction,
                NotificationAction.categorize.unAction,
                NotificationAction.dismiss.unAction
            ]

        case .system:
            [
                NotificationAction.viewDetails.unAction,
                NotificationAction.dismiss.unAction
            ]

        case .error:
            [
                NotificationAction.viewDetails.unAction,
                NotificationAction.retry.unAction,
                NotificationAction.dismiss.unAction
            ]

        case .achievement:
            [
                NotificationAction.share.unAction,
                NotificationAction.viewDetails.unAction,
                NotificationAction.dismiss.unAction
            ]
        }
    }

    /// Create UNNotificationCategory
    public var unCategory: UNNotificationCategory {
        UNNotificationCategory(
            identifier: identifier,
            actions: actions,
            intentIdentifiers: [],
            options: categoryOptions
        )
    }

    private var categoryOptions: UNNotificationCategoryOptions {
        switch self {
        case .aiResponse:
            #if os(iOS)
                return [.allowInCarPlay, .customDismissAction]
            #else
                return [.customDismissAction]
            #endif
        case .reminder:
            return [.customDismissAction, .hiddenPreviewsShowTitle]
        case .error:
            return [.customDismissAction]
        default:
            return []
        }
    }
}

// MARK: - Notification Categories Helper

public enum NotificationCategories {
    /// Get all notification categories
    public static var allCategories: Set<UNNotificationCategory> {
        Set(NotificationCategory.allCases.map(\.unCategory))
    }
}

// MARK: - Notification Action

public enum NotificationAction: String, Sendable {
    case open = "THEA_OPEN"
    case dismiss = "THEA_DISMISS"
    case reply = "THEA_REPLY"
    case viewDetails = "THEA_VIEW_DETAILS"
    case viewConversation = "THEA_VIEW_CONVERSATION"
    case retry = "THEA_RETRY"
    case markComplete = "THEA_MARK_COMPLETE"
    case snooze15 = "THEA_SNOOZE_15"
    case snooze1Hour = "THEA_SNOOZE_1H"
    case logEntry = "THEA_LOG_ENTRY"
    case categorize = "THEA_CATEGORIZE"
    case share = "THEA_SHARE"

    public var identifier: String { rawValue }

    public var title: String {
        switch self {
        case .open: "Open"
        case .dismiss: "Dismiss"
        case .reply: "Reply"
        case .viewDetails: "View Details"
        case .viewConversation: "View Conversation"
        case .retry: "Retry"
        case .markComplete: "Mark Complete"
        case .snooze15: "Snooze 15 min"
        case .snooze1Hour: "Snooze 1 hour"
        case .logEntry: "Log Entry"
        case .categorize: "Categorize"
        case .share: "Share"
        }
    }

    public var options: UNNotificationActionOptions {
        switch self {
        case .open, .viewDetails, .viewConversation:
            [.foreground]
        case .dismiss:
            [.destructive]
        case .markComplete:
            [.authenticationRequired]
        default:
            []
        }
    }

    public var unAction: UNNotificationAction {
        switch self {
        case .reply:
            UNTextInputNotificationAction(
                identifier: identifier,
                title: title,
                options: options,
                textInputButtonTitle: "Send",
                textInputPlaceholder: "Type your reply..."
            )
        default:
            UNNotificationAction(
                identifier: identifier,
                title: title,
                options: options
            )
        }
    }
}

// MARK: - Notification Action Handler

/// Protocol for handling notification actions
public protocol NotificationActionHandler: Actor {
    func handleAction(_ action: NotificationAction, notification: UNNotification) async
    func handleTextInputAction(_ action: NotificationAction, text: String, notification: UNNotification) async
}
