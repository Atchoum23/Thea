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
        case .general: return "General"
        case .aiTask: return "AI Tasks"
        case .aiResponse: return "AI Responses"
        case .reminder: return "Reminders"
        case .sync: return "Sync"
        case .health: return "Health"
        case .financial: return "Financial"
        case .system: return "System"
        case .error: return "Errors"
        case .achievement: return "Achievements"
        }
    }

    public var description: String {
        switch self {
        case .general:
            return "General notifications from Thea"
        case .aiTask:
            return "Updates about AI task progress and completion"
        case .aiResponse:
            return "New AI responses in conversations"
        case .reminder:
            return "Scheduled reminders and alerts"
        case .sync:
            return "Sync status across devices"
        case .health:
            return "Health tracking insights and alerts"
        case .financial:
            return "Financial updates and alerts"
        case .system:
            return "System status and updates"
        case .error:
            return "Error notifications requiring attention"
        case .achievement:
            return "Achievement unlocks and milestones"
        }
    }

    public var icon: String {
        switch self {
        case .general: return "bell"
        case .aiTask: return "cpu"
        case .aiResponse: return "bubble.left.and.bubble.right"
        case .reminder: return "clock"
        case .sync: return "arrow.triangle.2.circlepath"
        case .health: return "heart"
        case .financial: return "dollarsign.circle"
        case .system: return "gear"
        case .error: return "exclamationmark.triangle"
        case .achievement: return "star"
        }
    }

    /// Actions available for this category
    public var actions: [UNNotificationAction] {
        switch self {
        case .general:
            return [
                NotificationAction.open.unAction,
                NotificationAction.dismiss.unAction
            ]

        case .aiTask:
            return [
                NotificationAction.viewDetails.unAction,
                NotificationAction.retry.unAction,
                NotificationAction.dismiss.unAction
            ]

        case .aiResponse:
            return [
                NotificationAction.reply.unAction,
                NotificationAction.viewConversation.unAction,
                NotificationAction.dismiss.unAction
            ]

        case .reminder:
            return [
                NotificationAction.markComplete.unAction,
                NotificationAction.snooze15.unAction,
                NotificationAction.snooze1Hour.unAction,
                NotificationAction.dismiss.unAction
            ]

        case .sync:
            return [
                NotificationAction.viewDetails.unAction,
                NotificationAction.dismiss.unAction
            ]

        case .health:
            return [
                NotificationAction.viewDetails.unAction,
                NotificationAction.logEntry.unAction,
                NotificationAction.dismiss.unAction
            ]

        case .financial:
            return [
                NotificationAction.viewDetails.unAction,
                NotificationAction.categorize.unAction,
                NotificationAction.dismiss.unAction
            ]

        case .system:
            return [
                NotificationAction.viewDetails.unAction,
                NotificationAction.dismiss.unAction
            ]

        case .error:
            return [
                NotificationAction.viewDetails.unAction,
                NotificationAction.retry.unAction,
                NotificationAction.dismiss.unAction
            ]

        case .achievement:
            return [
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
            return [.allowInCarPlay, .customDismissAction]
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
        case .open: return "Open"
        case .dismiss: return "Dismiss"
        case .reply: return "Reply"
        case .viewDetails: return "View Details"
        case .viewConversation: return "View Conversation"
        case .retry: return "Retry"
        case .markComplete: return "Mark Complete"
        case .snooze15: return "Snooze 15 min"
        case .snooze1Hour: return "Snooze 1 hour"
        case .logEntry: return "Log Entry"
        case .categorize: return "Categorize"
        case .share: return "Share"
        }
    }

    public var options: UNNotificationActionOptions {
        switch self {
        case .open, .viewDetails, .viewConversation:
            return [.foreground]
        case .dismiss:
            return [.destructive]
        case .markComplete:
            return [.authenticationRequired]
        default:
            return []
        }
    }

    public var unAction: UNNotificationAction {
        switch self {
        case .reply:
            return UNTextInputNotificationAction(
                identifier: identifier,
                title: title,
                options: options,
                textInputButtonTitle: "Send",
                textInputPlaceholder: "Type your reply..."
            )
        default:
            return UNNotificationAction(
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
