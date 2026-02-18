//
//  UniversalNotificationService.swift
//  Thea
//
//  Created by Claude Code on 2026-01-22
//  Copyright © 2026. All rights reserved.
//

import CloudKit
import Foundation
import OSLog
@preconcurrency import UserNotifications
#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

// MARK: - Universal Notification Service

/// Cross-device notification service that ensures notifications ring on ALL devices
/// when AI responses complete or user input is required
public actor UniversalNotificationService {
    public static let shared = UniversalNotificationService()

    // MARK: - CloudKit

    private let container = CKContainer(identifier: "iCloud.app.theathe")
    private lazy var privateDatabase = container.privateCloudDatabase

    // MARK: - State

    private var isInitialized = false
    private var deviceToken: String?
    private var activeSubscriptions: Set<String> = []

    // MARK: - Constants

    private let recordType = "UniversalNotification"
    private let subscriptionID = "universal-notification-subscription"

    private let logger = Logger(subsystem: "ai.thea.app", category: "UniversalNotificationService")

    // MARK: - Initialization

    private init() {}

    // MARK: - Setup

    /// Initialize the universal notification service
    public func initialize() async throws {
        guard !isInitialized else { return }

        // Check iCloud status
        let status = try await container.accountStatus()
        guard status == .available else {
            throw UniversalNotificationError.iCloudNotAvailable
        }

        // Setup CloudKit subscription for receiving notifications
        try await setupCloudKitSubscription()

        // Register current device
        try await registerCurrentDevice()

        isInitialized = true
    }

    /// Setup CloudKit subscription to receive notifications on all devices
    private func setupCloudKitSubscription() async throws {
        let deviceId = await MainActor.run { DeviceRegistry.shared.currentDevice.id }
        let predicate = NSPredicate(format: "targetDevices CONTAINS %@ OR targetDevices CONTAINS %@",
                                    deviceId,
                                    "all")

        let subscription = CKQuerySubscription(
            recordType: recordType,
            predicate: predicate,
            subscriptionID: subscriptionID,
            options: [.firesOnRecordCreation]
        )

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        notificationInfo.shouldBadge = true
        notificationInfo.alertLocalizationKey = "NOTIFICATION_ALERT"
        notificationInfo.titleLocalizationKey = "NOTIFICATION_TITLE"
        notificationInfo.desiredKeys = ["title", "body", "category", "sound", "priority"]
        subscription.notificationInfo = notificationInfo

        do {
            _ = try await privateDatabase.save(subscription)
            activeSubscriptions.insert(subscriptionID)
        } catch let error as CKError where error.code == .serverRejectedRequest {
            // Subscription already exists - that's fine
        }
    }

    /// Register current device for receiving notifications
    private func registerCurrentDevice() async throws {
        let deviceInfo = await MainActor.run { DeviceRegistry.shared.currentDevice }

        let record = CKRecord(recordType: "NotificationDevice")
        record["deviceId"] = deviceInfo.id
        record["deviceName"] = deviceInfo.name
        record["deviceType"] = deviceInfo.type.rawValue
        record["supportsNotifications"] = deviceInfo.capabilities.supportsNotifications
        record["lastSeen"] = Date()
        record["appVersion"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

        _ = try await privateDatabase.save(record)
    }

    // MARK: - Send Notifications

    /// Send a notification to ALL registered devices
    public func notifyAllDevices(
        title: String,
        body: String,
        category: NotificationCategory = .general,
        sound: NotificationSound = .default,
        priority: TheaNotificationPriority = .normal,
        userInfo: [String: SendableValue] = [:]
    ) async throws {
        // Create CloudKit record for cross-device delivery
        let record = CKRecord(recordType: recordType)
        record["id"] = UUID().uuidString
        record["title"] = title
        record["body"] = body
        record["category"] = category.identifier
        record["sound"] = sound.rawValue
        record["priority"] = priority.rawValue
        record["targetDevices"] = ["all"] as [String]
        record["createdAt"] = Date()
        record["originDevice"] = await MainActor.run { DeviceRegistry.shared.currentDevice.id }
        // Convert SendableValue dict to string dict for JSON serialization
        let stringDict = userInfo.compactMapValues { $0.stringValue }
        do {
            record["userInfo"] = try JSONSerialization.data(withJSONObject: stringDict)
        } catch {
            logger.error("Failed to serialize userInfo: \(error)")
        }

        // Save to CloudKit - will trigger subscription on all devices
        _ = try await privateDatabase.save(record)

        // Also send locally immediately
        try await deliverLocalNotificationImmediate(title: title, body: body, category: category)
    }

    /// Notify all devices when AI response is complete
    public func notifyAIResponseComplete(
        conversationTitle: String,
        responsePreview: String,
        success: Bool = true
    ) async throws {
        let title = success ? "✅ Response Ready" : "⚠️ Response Issue"
        let body = "\(conversationTitle): \(responsePreview.prefix(100))..."

        try await notifyAllDevices(
            title: title,
            body: body,
            category: .aiResponse,
            sound: success ? .message : .warning,
            priority: .high,
            userInfo: [
                "conversationTitle": .string(conversationTitle),
                "type": .string("ai_response"),
                "success": .bool(success)
            ]
        )
    }

    /// Notify all devices when user input is required
    public func notifyUserInputRequired(
        conversationTitle: String,
        promptText: String
    ) async throws {
        try await notifyAllDevices(
            title: "🔔 Input Required",
            body: "\(conversationTitle) needs your response: \(promptText.prefix(80))...",
            category: .aiTask,
            sound: .reminder,
            priority: .urgent,
            userInfo: [
                "conversationTitle": .string(conversationTitle),
                "type": .string("user_input_required"),
                "prompt": .string(promptText)
            ]
        )
    }

    /// Notify all devices of task completion
    public func notifyTaskComplete(
        taskName: String,
        success: Bool,
        duration: TimeInterval? = nil
    ) async throws {
        var body = success ? "Completed successfully" : "Task failed"
        if let duration {
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.hour, .minute, .second]
            formatter.unitsStyle = .abbreviated
            body += " in \(formatter.string(from: duration) ?? "unknown time")"
        }

        try await notifyAllDevices(
            title: success ? "✅ \(taskName)" : "❌ \(taskName)",
            body: body,
            category: .aiTask,
            sound: success ? .success : .error,
            priority: success ? .normal : .high,
            userInfo: [
                "taskName": .string(taskName),
                "type": .string("task_complete"),
                "success": .bool(success)
            ]
        )
    }

    /// Notify specific devices only
    public func notifyDevices(
        deviceIds: [String],
        title: String,
        body: String,
        category: NotificationCategory = .general,
        sound: NotificationSound = .default
    ) async throws {
        let record = CKRecord(recordType: recordType)
        record["id"] = UUID().uuidString
        record["title"] = title
        record["body"] = body
        record["category"] = category.identifier
        record["sound"] = sound.rawValue
        record["priority"] = TheaNotificationPriority.normal.rawValue
        record["targetDevices"] = deviceIds
        record["createdAt"] = Date()
        record["originDevice"] = await MainActor.run { DeviceRegistry.shared.currentDevice.id }

        _ = try await privateDatabase.save(record)
    }

    // MARK: - Handle Incoming Notifications

    /// Process incoming CloudKit notification
    public func processCloudKitNotification(_ userInfo: [AnyHashable: Any]) async {
        guard let ckNotification = CKNotification(fromRemoteNotificationDictionary: userInfo),
              let queryNotification = ckNotification as? CKQueryNotification,
              let recordID = queryNotification.recordID
        else {
            return
        }

        // Fetch the full record
        do {
            let record = try await privateDatabase.record(for: recordID)
            await deliverLocalNotification(from: record)
        } catch {
            // Record may have been deleted or is inaccessible
        }
    }

    /// Deliver a local notification from CloudKit record
    private func deliverLocalNotification(from record: CKRecord) async {
        guard let title = record["title"] as? String,
              let body = record["body"] as? String,
              let originDevice = record["originDevice"] as? String
        else {
            return
        }

        // Don't notify on the device that created the notification
        let currentDeviceId = await MainActor.run { DeviceRegistry.shared.currentDevice.id }
        guard originDevice != currentDeviceId else {
            return
        }

        let categoryId = record["category"] as? String ?? "general"
        let soundName = record["sound"] as? String ?? "default"

        _ = NotificationCategory(rawValue: categoryId) ?? .general
        _ = NotificationSound(rawValue: soundName) ?? .default

        do {
            try await deliverLocalNotificationImmediate(
                title: title,
                body: body,
                category: .general
            )
        } catch {
            logger.error("Failed to deliver local notification: \(error)")
        }
    }

    // MARK: - Device Management

    /// Get all registered devices
    public func getRegisteredDevices() async throws -> [NotificationDevice] {
        let query = CKQuery(recordType: "NotificationDevice", predicate: NSPredicate(value: true))
        let results = try await privateDatabase.records(matching: query)

        return results.matchResults.compactMap { _, result -> NotificationDevice? in
            guard case let .success(record) = result,
                  let deviceId = record["deviceId"] as? String,
                  let deviceName = record["deviceName"] as? String
            else {
                return nil
            }

            return NotificationDevice(
                id: deviceId,
                name: deviceName,
                type: record["deviceType"] as? String ?? "unknown",
                supportsNotifications: record["supportsNotifications"] as? Bool ?? true,
                lastSeen: record["lastSeen"] as? Date ?? Date()
            )
        }
    }

    /// Update device heartbeat
    public func updateDeviceHeartbeat() async throws {
        let deviceId = await MainActor.run { DeviceRegistry.shared.currentDevice.id }
        let recordID = CKRecord.ID(recordName: "device-\(deviceId)")

        do {
            let record = try await privateDatabase.record(for: recordID)
            record["lastSeen"] = Date()
            _ = try await privateDatabase.save(record)
        } catch {
            // Device not registered, register now
            try await registerCurrentDevice()
        }
    }

    // MARK: - Local Notification Helper

    /// Deliver a local notification immediately using UNUserNotificationCenter
    private func deliverLocalNotificationImmediate(
        title: String,
        body: String,
        category: NotificationCategory
    ) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = category.identifier

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        try await UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - Notification Priority

public enum TheaNotificationPriority: String, Codable, Sendable {
    case low
    case normal
    case high
    case urgent
}

// MARK: - Notification Sound

public enum NotificationSound: String, Codable, Sendable {
    case `default`
    case message
    case warning
    case error
    case success
    case reminder
}

// MARK: - Notification Device

public struct NotificationDevice: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let type: String
    public let supportsNotifications: Bool
    public let lastSeen: Date

    public var isOnline: Bool {
        Date().timeIntervalSince(lastSeen) < 300 // 5 minutes
    }
}

// MARK: - Universal Notification Error

public enum UniversalNotificationError: Error, LocalizedError, Sendable {
    case iCloudNotAvailable
    case deviceNotRegistered
    case notificationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .iCloudNotAvailable:
            "iCloud is not available for cross-device notifications"
        case .deviceNotRegistered:
            "This device is not registered for notifications"
        case let .notificationFailed(reason):
            "Notification failed: \(reason)"
        }
    }
}
