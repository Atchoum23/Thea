//
//  NotificationService.swift
//  Thea
//
//  Created by Claude Code on 2026-01-20
//  Copyright © 2026. All rights reserved.
//

import Foundation
import UserNotifications
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Notification Service

/// Centralized service for managing all app notifications
public actor NotificationService {
    public static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private var isAuthorized = false
    private var pendingNotifications: [TheaNotification] = []

    // MARK: - Initialization

    private init() {}

    // MARK: - Authorization

    /// Request notification authorization
    public func requestAuthorization() async throws -> Bool {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge, .provisional]

        do {
            isAuthorized = try await center.requestAuthorization(options: options)
            if isAuthorized {
                await registerCategories()
                await deliverPendingNotifications()
            }
            return isAuthorized
        } catch {
            throw NotificationError.authorizationFailed(error.localizedDescription)
        }
    }

    /// Check current authorization status
    public func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }

    // MARK: - Category Registration

    private func registerCategories() async {
        let categories = NotificationCategories.allCategories
        center.setNotificationCategories(categories)
    }

    // MARK: - Send Notifications

    /// Schedule a notification
    public func schedule(_ notification: TheaNotification) async throws {
        guard isAuthorized else {
            pendingNotifications.append(notification)
            throw NotificationError.notAuthorized
        }

        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = notification.sound.unSound
        content.categoryIdentifier = notification.category.identifier

        if let subtitle = notification.subtitle {
            content.subtitle = subtitle
        }

        if let badge = notification.badge {
            content.badge = NSNumber(value: badge)
        }

        if let threadIdentifier = notification.threadIdentifier {
            content.threadIdentifier = threadIdentifier
        }

        content.userInfo = notification.userInfo

        let trigger: UNNotificationTrigger?
        switch notification.trigger {
        case .immediate:
            trigger = nil
        case .timeInterval(let seconds):
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        case .date(let dateComponents):
            trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        case .repeating(let dateComponents):
            trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        }

        let request = UNNotificationRequest(
            identifier: notification.id.uuidString,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
        } catch {
            throw NotificationError.schedulingFailed(error.localizedDescription)
        }
    }

    /// Send an immediate notification
    public func send(_ notification: TheaNotification) async throws {
        var immediateNotification = notification
        immediateNotification.trigger = .immediate
        try await schedule(immediateNotification)
    }

    // MARK: - Pending Notifications

    private func deliverPendingNotifications() async {
        for notification in pendingNotifications {
            try? await schedule(notification)
        }
        pendingNotifications.removeAll()
    }

    // MARK: - Cancel Notifications

    /// Cancel a specific notification
    public func cancel(id: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [id.uuidString])
        center.removeDeliveredNotifications(withIdentifiers: [id.uuidString])
    }

    /// Cancel all notifications for a category
    public func cancel(category: NotificationCategory) {
        Task {
            let pending = await center.pendingNotificationRequests()
            let delivered = await center.deliveredNotifications()

            let pendingIds = pending
                .filter { $0.content.categoryIdentifier == category.identifier }
                .map(\.identifier)

            let deliveredIds = delivered
                .filter { $0.request.content.categoryIdentifier == category.identifier }
                .map(\.request.identifier)

            center.removePendingNotificationRequests(withIdentifiers: pendingIds)
            center.removeDeliveredNotifications(withIdentifiers: deliveredIds)
        }
    }

    /// Cancel all notifications
    public func cancelAll() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    // MARK: - Query Notifications

    /// Get all pending notifications
    public func getPendingNotifications() async -> [UNNotificationRequest] {
        await center.pendingNotificationRequests()
    }

    /// Get all delivered notifications
    public func getDeliveredNotifications() async -> [UNNotification] {
        await center.deliveredNotifications()
    }

    // MARK: - Convenience Methods

    /// Send a simple notification
    public func notify(
        title: String,
        body: String,
        category: NotificationCategory = .general
    ) async throws {
        let notification = TheaNotification(
            title: title,
            body: body,
            category: category
        )
        try await send(notification)
    }

    /// Send an AI task completion notification
    public func notifyTaskComplete(taskName: String, success: Bool) async throws {
        let notification = TheaNotification(
            title: success ? "Task Complete" : "Task Failed",
            body: taskName,
            category: .aiTask,
            sound: success ? .default : .error,
            userInfo: ["taskName": taskName, "success": success]
        )
        try await send(notification)
    }

    /// Send a reminder notification
    public func scheduleReminder(
        title: String,
        body: String,
        at date: Date
    ) async throws -> UUID {
        let calendar = Calendar.current
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )

        let notification = TheaNotification(
            title: title,
            body: body,
            category: .reminder,
            trigger: .date(components)
        )
        try await schedule(notification)
        return notification.id
    }
}

// MARK: - Thea Notification

public struct TheaNotification: Sendable, Identifiable {
    public let id: UUID
    public var title: String
    public var body: String
    public var subtitle: String?
    public var category: NotificationCategory
    public var sound: NotificationSound
    public var badge: Int?
    public var threadIdentifier: String?
    public var trigger: NotificationTrigger
    public var userInfo: [String: any Sendable]

    public init(
        id: UUID = UUID(),
        title: String,
        body: String,
        subtitle: String? = nil,
        category: NotificationCategory = .general,
        sound: NotificationSound = .default,
        badge: Int? = nil,
        threadIdentifier: String? = nil,
        trigger: NotificationTrigger = .immediate,
        userInfo: [String: any Sendable] = [:]
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.subtitle = subtitle
        self.category = category
        self.sound = sound
        self.badge = badge
        self.threadIdentifier = threadIdentifier
        self.trigger = trigger
        self.userInfo = userInfo
    }
}

// MARK: - Notification Trigger

public enum NotificationTrigger: Sendable {
    case immediate
    case timeInterval(TimeInterval)
    case date(DateComponents)
    case repeating(DateComponents)
}

// MARK: - Notification Sound

public enum NotificationSound: String, Codable, Sendable, CaseIterable {
    case `default` = "default"
    case success = "success"
    case error = "error"
    case warning = "warning"
    case message = "message"
    case reminder = "reminder"
    case silent = "silent"

    public var unSound: UNNotificationSound {
        switch self {
        case .default: return .default
        case .success: return UNNotificationSound(named: UNNotificationSoundName("success.aiff"))
        case .error: return UNNotificationSound(named: UNNotificationSoundName("error.aiff"))
        case .warning: return UNNotificationSound(named: UNNotificationSoundName("warning.aiff"))
        case .message: return UNNotificationSound(named: UNNotificationSoundName("message.aiff"))
        case .reminder: return UNNotificationSound(named: UNNotificationSoundName("reminder.aiff"))
        case .silent: return .default // Silent handled via settings
        }
    }
}

// MARK: - Notification Error

public enum NotificationError: Error, LocalizedError, Sendable {
    case notAuthorized
    case authorizationFailed(String)
    case schedulingFailed(String)
    case invalidTrigger

    public var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Notifications are not authorized. Please enable in System Settings."
        case .authorizationFailed(let reason):
            return "Authorization failed: \(reason)"
        case .schedulingFailed(let reason):
            return "Failed to schedule notification: \(reason)"
        case .invalidTrigger:
            return "Invalid notification trigger configuration"
        }
    }
}
