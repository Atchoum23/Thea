//
//  CrossDeviceNotificationServiceTypes.swift
//  Thea
//
//  Supporting types and extensions for CrossDeviceNotificationService
//  Copyright 2026. All rights reserved.
//

import CloudKit
import Foundation
@preconcurrency import UserNotifications

// MARK: - Errors

/// Errors for cross-device notification operations
public enum CrossDeviceNotificationError: Error, LocalizedError, Sendable {
    case notRegistered
    case registrationFailed(Error)
    case sendFailed(Error)
    case subscriptionFailed(Error)
    case deviceNotFound
    case notificationExpired
    case deliveryFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notRegistered:
            "Device not registered for notifications"
        case .registrationFailed(let error):
            "Failed to register device: \(error.localizedDescription)"
        case .sendFailed(let error):
            "Failed to send notification: \(error.localizedDescription)"
        case .subscriptionFailed(let error):
            "Failed to setup notification subscription: \(error.localizedDescription)"
        case .deviceNotFound:
            "Target device not found"
        case .notificationExpired:
            "Notification has expired"
        case .deliveryFailed(let reason):
            "Notification delivery failed: \(reason)"
        }
    }
}

// MARK: - Notification Names

public extension Notification.Name {
    /// Posted when a cross-device notification is received
    static let theaCrossDeviceNotificationReceived = Notification.Name("theaCrossDeviceNotificationReceived")

    /// Posted when device registration changes
    static let theaDeviceRegistrationChanged = Notification.Name("theaDeviceRegistrationChanged")

    /// Posted when registered devices list updates
    static let theaRegisteredDevicesUpdated = Notification.Name("theaRegisteredDevicesUpdated")
}

// MARK: - UNUserNotificationCenter Extension

public extension UNUserNotificationCenter {
    /// Register notification categories for cross-device notifications
    func registerTheaCrossDeviceCategories() {
        let categories: Set<UNNotificationCategory> = Set(
            CrossDeviceNotificationCategory.allCases.map { category in
                UNNotificationCategory(
                    identifier: category.identifier,
                    actions: actionsForCategory(category),
                    intentIdentifiers: [],
                    options: optionsForCategory(category)
                )
            }
        )

        // Merge with existing categories
        getNotificationCategories { existingCategories in
            let allCategories = existingCategories.union(categories)
            self.setNotificationCategories(allCategories)
        }
    }

    private func actionsForCategory(_ category: CrossDeviceNotificationCategory) -> [UNNotificationAction] {
        switch category {
        case .passwordNeeded:
            [
                UNTextInputNotificationAction(
                    identifier: "ENTER_PASSWORD",
                    title: "Enter Password",
                    options: [.authenticationRequired],
                    textInputButtonTitle: "Submit",
                    textInputPlaceholder: "Password"
                ),
                UNNotificationAction(
                    identifier: "CANCEL",
                    title: "Cancel",
                    options: [.destructive]
                )
            ]

        case .approvalRequired:
            [
                UNNotificationAction(
                    identifier: "APPROVE",
                    title: "Approve",
                    options: [.authenticationRequired]
                ),
                UNNotificationAction(
                    identifier: "DENY",
                    title: "Deny",
                    options: [.destructive]
                )
            ]

        case .aiResponseReady, .taskCompletion:
            [
                UNNotificationAction(
                    identifier: "VIEW",
                    title: "View",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: "DISMISS",
                    title: "Dismiss",
                    options: []
                )
            ]

        case .errorAlert:
            [
                UNNotificationAction(
                    identifier: "VIEW_DETAILS",
                    title: "View Details",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: "RETRY",
                    title: "Retry",
                    options: []
                )
            ]

        case .reminder:
            [
                UNNotificationAction(
                    identifier: "COMPLETE",
                    title: "Mark Complete",
                    options: []
                ),
                UNNotificationAction(
                    identifier: "SNOOZE",
                    title: "Snooze",
                    options: []
                )
            ]

        default:
            [
                UNNotificationAction(
                    identifier: "VIEW",
                    title: "View",
                    options: [.foreground]
                )
            ]
        }
    }

    private func optionsForCategory(_ category: CrossDeviceNotificationCategory) -> UNNotificationCategoryOptions {
        switch category {
        case .passwordNeeded, .approvalRequired:
            return [.customDismissAction, .hiddenPreviewsShowTitle]
        case .aiResponseReady:
            #if os(iOS)
                return [.allowInCarPlay, .customDismissAction]
            #else
                return [.customDismissAction]
            #endif
        default:
            return []
        }
    }
}

// MARK: - Convenience Senders

extension CrossDeviceNotificationService {
    /// Notify that a task completed on this device
    public func notifyTaskCompletion(
        taskName: String,
        result: String,
        deepLink: URL? = nil
    ) async throws {
        try await send(
            category: .taskCompletion,
            title: "Task Completed",
            body: taskName,
            subtitle: result,
            deepLink: deepLink
        )
    }

    /// Notify that an AI response is ready
    public func notifyAIResponseReady(
        conversationId: String,
        preview: String
    ) async throws {
        let preview = preview.prefix(100)
        try await send(
            category: .aiResponseReady,
            title: "AI Response Ready",
            body: String(preview) + (preview.count >= 100 ? "..." : ""),
            deepLink: URL(string: "thea://conversation/\(conversationId)")
        )
    }

    /// Request password input from user on another device
    public func requestPassword(
        service: String,
        reason: String,
        requestId: String
    ) async throws {
        try await send(
            category: .passwordNeeded,
            title: "Password Needed",
            body: "Enter password for \(service)",
            subtitle: reason,
            priority: .critical,
            userInfo: ["requestId": requestId, "service": service]
        )
    }

    /// Request approval for an action
    public func requestApproval(
        action: String,
        details: String,
        requestId: String
    ) async throws {
        try await send(
            category: .approvalRequired,
            title: "Approval Required",
            body: action,
            subtitle: details,
            priority: .critical,
            userInfo: ["requestId": requestId]
        )
    }

    /// Notify sync completed
    public func notifySyncComplete(
        itemCount: Int,
        syncType: String
    ) async throws {
        try await send(
            category: .syncComplete,
            title: "Sync Complete",
            body: "\(itemCount) \(syncType) synced",
            priority: .low
        )
    }

    /// Notify about an error
    public func notifyError(
        errorTitle: String,
        errorMessage: String,
        errorCode: String? = nil
    ) async throws {
        var userInfo: [String: String] = [:]
        if let errorCode {
            userInfo["errorCode"] = errorCode
        }

        try await send(
            category: .errorAlert,
            title: errorTitle,
            body: errorMessage,
            priority: .high,
            userInfo: userInfo
        )
    }

    /// Notify agent status update
    public func notifyAgentUpdate(
        agentName: String,
        status: String,
        details: String? = nil
    ) async throws {
        try await send(
            category: .agentUpdate,
            title: "\(agentName) Update",
            body: status,
            subtitle: details
        )
    }

    /// Send a reminder to other devices
    public func sendReminder(
        title: String,
        message: String,
        dueDate: Date? = nil
    ) async throws {
        var userInfo: [String: String] = [:]
        if let dueDate {
            userInfo["dueDate"] = ISO8601DateFormatter().string(from: dueDate)
        }

        try await send(
            category: .reminder,
            title: title,
            body: message,
            userInfo: userInfo
        )
    }

    /// Notify file processing is complete
    public func notifyFileReady(
        fileName: String,
        fileType: String,
        fileId: String
    ) async throws {
        try await send(
            category: .fileReady,
            title: "File Ready",
            body: fileName,
            subtitle: fileType,
            deepLink: URL(string: "thea://file/\(fileId)")
        )
    }
}
