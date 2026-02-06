//
//  NotificationPayload.swift
//  Thea
//
//  Models for cross-device notification system
//  Copyright 2026. All rights reserved.
//

import CloudKit
import Foundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Cross-Device Notification Priority

/// Priority level for cross-device notifications, affects delivery behavior and presentation
public enum PayloadNotificationPriority: Int, Codable, Sendable, CaseIterable, Comparable {
    /// Low priority - silent, batched delivery
    case low = 0
    /// Normal priority - standard delivery
    case normal = 1
    /// High priority - immediate delivery, bypasses some quiet modes
    case high = 2
    /// Critical priority - always delivered, can bypass Do Not Disturb
    case critical = 3

    public var displayName: String {
        switch self {
        case .low: "Low"
        case .normal: "Normal"
        case .high: "High"
        case .critical: "Critical"
        }
    }

    public var priorityDescription: String {
        switch self {
        case .low:
            "Silent notification, delivered when convenient"
        case .normal:
            "Standard notification delivery"
        case .high:
            "Immediate delivery, may bypass quiet hours"
        case .critical:
            "Always delivered, can bypass Do Not Disturb"
        }
    }

    /// APNs interruption level mapping
    public var interruptionLevel: String {
        switch self {
        case .low: "passive"
        case .normal: "active"
        case .high: "time-sensitive"
        case .critical: "critical"
        }
    }

    public static func < (lhs: PayloadNotificationPriority, rhs: PayloadNotificationPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Cross-Device Notification Category

/// Categories of notifications for cross-device delivery
public enum CrossDeviceNotificationCategory: String, Codable, Sendable, CaseIterable {
    /// Task completed on another device
    case taskCompletion = "THEA_CROSS_TASK_COMPLETE"
    /// AI response ready
    case aiResponseReady = "THEA_CROSS_AI_RESPONSE"
    /// Password or authentication needed
    case passwordNeeded = "THEA_CROSS_PASSWORD"
    /// User approval required
    case approvalRequired = "THEA_CROSS_APPROVAL"
    /// Sync completed
    case syncComplete = "THEA_CROSS_SYNC"
    /// Error occurred that needs attention
    case errorAlert = "THEA_CROSS_ERROR"
    /// Agent status update
    case agentUpdate = "THEA_CROSS_AGENT"
    /// Reminder from another device
    case reminder = "THEA_CROSS_REMINDER"
    /// File processing complete
    case fileReady = "THEA_CROSS_FILE"
    /// Custom user-defined notification
    case custom = "THEA_CROSS_CUSTOM"

    public var identifier: String { rawValue }

    public var displayName: String {
        switch self {
        case .taskCompletion: "Task Completion"
        case .aiResponseReady: "AI Response Ready"
        case .passwordNeeded: "Password Needed"
        case .approvalRequired: "Approval Required"
        case .syncComplete: "Sync Complete"
        case .errorAlert: "Error Alert"
        case .agentUpdate: "Agent Update"
        case .reminder: "Reminder"
        case .fileReady: "File Ready"
        case .custom: "Custom"
        }
    }

    public var defaultPriority: CrossDeviceNotificationPriority {
        switch self {
        case .passwordNeeded, .approvalRequired:
            .critical
        case .errorAlert, .aiResponseReady:
            .high
        case .taskCompletion, .agentUpdate, .fileReady, .reminder:
            .normal
        case .syncComplete, .custom:
            .low
        }
    }

    public var icon: String {
        switch self {
        case .taskCompletion: "checkmark.circle.fill"
        case .aiResponseReady: "bubble.left.and.bubble.right.fill"
        case .passwordNeeded: "key.fill"
        case .approvalRequired: "hand.raised.fill"
        case .syncComplete: "arrow.triangle.2.circlepath.circle.fill"
        case .errorAlert: "exclamationmark.triangle.fill"
        case .agentUpdate: "person.crop.circle.badge.clock.fill"
        case .reminder: "clock.fill"
        case .fileReady: "doc.fill"
        case .custom: "bell.fill"
        }
    }

    /// Default sound for this category
    public var defaultSound: CrossDeviceNotificationSound {
        switch self {
        case .passwordNeeded, .approvalRequired:
            .alert
        case .errorAlert:
            .error
        case .aiResponseReady, .taskCompletion:
            .success
        case .agentUpdate:
            .subtle
        default:
            .default
        }
    }
}

// MARK: - Cross-Device Notification Sound

/// Sound options for cross-device notifications
public enum CrossDeviceNotificationSound: String, Codable, Sendable, CaseIterable {
    /// System default notification sound
    case `default` = "default"
    /// Subtle, quiet notification
    case subtle = "thea_subtle.caf"
    /// Success/completion sound
    case success = "thea_success.caf"
    /// Alert/attention sound
    case alert = "thea_alert.caf"
    /// Error notification sound
    case error = "thea_error.caf"
    /// Chime sound
    case chime = "thea_chime.caf"
    /// No sound
    case none = "none"

    public var displayName: String {
        switch self {
        case .default: "Default"
        case .subtle: "Subtle"
        case .success: "Success"
        case .alert: "Alert"
        case .error: "Error"
        case .chime: "Chime"
        case .none: "None"
        }
    }
}

// MARK: - Cross-Device Notification Haptic

/// Haptic feedback options for cross-device notifications
public enum CrossDeviceNotificationHaptic: String, Codable, Sendable, CaseIterable {
    /// No haptic feedback
    case none
    /// Light tap
    case light
    /// Medium tap
    case medium
    /// Heavy tap
    case heavy
    /// Success pattern
    case success
    /// Warning pattern
    case warning
    /// Error pattern
    case error

    public var displayName: String {
        switch self {
        case .none: "None"
        case .light: "Light"
        case .medium: "Medium"
        case .heavy: "Heavy"
        case .success: "Success"
        case .warning: "Warning"
        case .error: "Error"
        }
    }
}

// MARK: - Cross-Device Type

/// Types of Apple devices that can receive cross-device notifications
public enum CrossDeviceType: String, Codable, Sendable, CaseIterable {
    case iPhone
    case iPad
    case mac
    case watch
    case tv
    case vision

    public var displayName: String {
        switch self {
        case .iPhone: "iPhone"
        case .iPad: "iPad"
        case .mac: "Mac"
        case .watch: "Apple Watch"
        case .tv: "Apple TV"
        case .vision: "Apple Vision Pro"
        }
    }

    public var icon: String {
        switch self {
        case .iPhone: "iphone"
        case .iPad: "ipad"
        case .mac: "desktopcomputer"
        case .watch: "applewatch"
        case .tv: "appletv"
        case .vision: "visionpro"
        }
    }

    /// Current device type based on platform
    public static var current: CrossDeviceType {
        #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .pad {
                return .iPad
            }
            return .iPhone
        #elseif os(macOS)
            return .mac
        #elseif os(watchOS)
            return .watch
        #elseif os(tvOS)
            return .tv
        #elseif os(visionOS)
            return .vision
        #else
            return .mac
        #endif
    }
}

// MARK: - Cross-Device Registration

/// Represents a registered device for cross-device notifications
public struct CrossDeviceRegistration: Codable, Sendable, Identifiable, Hashable {
    /// Unique identifier for this device registration
    public let id: UUID

    /// Device token from APNs
    public let deviceToken: String

    /// Type of device
    public let deviceType: CrossDeviceType

    /// User-friendly device name
    public let deviceName: String

    /// Device model identifier (e.g., "iPhone15,2")
    public let modelIdentifier: String

    /// OS version
    public let osVersion: String

    /// App version installed
    public let appVersion: String

    /// When this device was registered
    public let registeredAt: Date

    /// Last time this device checked in
    public var lastSeenAt: Date

    /// Whether push notifications are enabled on this device
    public var pushEnabled: Bool

    /// Whether this device is currently active
    public var isActive: Bool

    /// CloudKit record ID for this registration
    public var recordID: String {
        "device-\(id.uuidString)"
    }

    public init(
        id: UUID = UUID(),
        deviceToken: String,
        deviceType: CrossDeviceType,
        deviceName: String,
        modelIdentifier: String,
        osVersion: String,
        appVersion: String,
        registeredAt: Date = Date(),
        lastSeenAt: Date = Date(),
        pushEnabled: Bool = true,
        isActive: Bool = true
    ) {
        self.id = id
        self.deviceToken = deviceToken
        self.deviceType = deviceType
        self.deviceName = deviceName
        self.modelIdentifier = modelIdentifier
        self.osVersion = osVersion
        self.appVersion = appVersion
        self.registeredAt = registeredAt
        self.lastSeenAt = lastSeenAt
        self.pushEnabled = pushEnabled
        self.isActive = isActive
    }

    // MARK: - CloudKit Conversion

    public init(from record: CKRecord) {
        let idString = record.recordID.recordName.replacingOccurrences(of: "device-", with: "")
        id = UUID(uuidString: idString) ?? UUID()
        deviceToken = record["deviceToken"] as? String ?? ""
        deviceType = CrossDeviceType(rawValue: record["deviceType"] as? String ?? "") ?? .iPhone
        deviceName = record["deviceName"] as? String ?? "Unknown Device"
        modelIdentifier = record["modelIdentifier"] as? String ?? ""
        osVersion = record["osVersion"] as? String ?? ""
        appVersion = record["appVersion"] as? String ?? ""
        registeredAt = record["registeredAt"] as? Date ?? Date()
        lastSeenAt = record["lastSeenAt"] as? Date ?? Date()
        pushEnabled = record["pushEnabled"] as? Bool ?? true
        isActive = record["isActive"] as? Bool ?? true
    }

    public func toRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: self.recordID)
        let record = CKRecord(recordType: "DeviceRegistration", recordID: recordID)
        record["deviceToken"] = deviceToken as CKRecordValue
        record["deviceType"] = deviceType.rawValue as CKRecordValue
        record["deviceName"] = deviceName as CKRecordValue
        record["modelIdentifier"] = modelIdentifier as CKRecordValue
        record["osVersion"] = osVersion as CKRecordValue
        record["appVersion"] = appVersion as CKRecordValue
        record["registeredAt"] = registeredAt as CKRecordValue
        record["lastSeenAt"] = lastSeenAt as CKRecordValue
        record["pushEnabled"] = pushEnabled as CKRecordValue
        record["isActive"] = isActive as CKRecordValue
        return record
    }

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: CrossDeviceRegistration, rhs: CrossDeviceRegistration) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Cross-Device Notification Payload

/// The main payload structure for cross-device notifications
public struct CrossDeviceNotificationPayload: Codable, Sendable, Identifiable {
    /// Unique identifier for this notification
    public let id: UUID

    /// Category of notification
    public let category: CrossDeviceNotificationCategory

    /// Priority level
    public let priority: PayloadNotificationPriority

    /// Notification title
    public let title: String

    /// Notification body/message
    public let body: String

    /// Optional subtitle
    public let subtitle: String?

    /// Sound to play
    public let sound: CrossDeviceNotificationSound

    /// Haptic feedback type
    public let haptic: CrossDeviceNotificationHaptic

    /// Badge count to set (nil means don't change)
    public let badge: Int?

    /// Thread identifier for grouping
    public let threadId: String?

    /// Deep link URL to open
    public let deepLink: URL?

    /// Additional custom data
    public let userInfo: [String: String]

    /// Device that originated this notification
    public let sourceDeviceId: UUID

    /// Source device name for display
    public let sourceDeviceName: String

    /// Specific device IDs to target (nil means all devices)
    public let targetDeviceIds: [UUID]?

    /// When this notification was created
    public let createdAt: Date

    /// When this notification expires (won't be delivered after)
    public let expiresAt: Date?

    /// Whether this notification requires acknowledgment
    public let requiresAcknowledgment: Bool

    /// Action identifier for interactive notifications
    public let actionIdentifier: String?

    /// CloudKit record ID
    public var recordID: String {
        "notification-\(id.uuidString)"
    }

    public init(
        id: UUID = UUID(),
        category: CrossDeviceNotificationCategory,
        priority: PayloadNotificationPriority? = nil,
        title: String,
        body: String,
        subtitle: String? = nil,
        sound: CrossDeviceNotificationSound? = nil,
        haptic: CrossDeviceNotificationHaptic = .medium,
        badge: Int? = nil,
        threadId: String? = nil,
        deepLink: URL? = nil,
        userInfo: [String: String] = [:],
        sourceDeviceId: UUID,
        sourceDeviceName: String,
        targetDeviceIds: [UUID]? = nil,
        createdAt: Date = Date(),
        expiresAt: Date? = nil,
        requiresAcknowledgment: Bool = false,
        actionIdentifier: String? = nil
    ) {
        self.id = id
        self.category = category
        self.priority = priority ?? category.defaultPriority
        self.title = title
        self.body = body
        self.subtitle = subtitle
        self.sound = sound ?? category.defaultSound
        self.haptic = haptic
        self.badge = badge
        self.threadId = threadId
        self.deepLink = deepLink
        self.userInfo = userInfo
        self.sourceDeviceId = sourceDeviceId
        self.sourceDeviceName = sourceDeviceName
        self.targetDeviceIds = targetDeviceIds
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.requiresAcknowledgment = requiresAcknowledgment
        self.actionIdentifier = actionIdentifier
    }

    // MARK: - CloudKit Conversion

    public init(from record: CKRecord) {
        let idString = record.recordID.recordName.replacingOccurrences(of: "notification-", with: "")
        id = UUID(uuidString: idString) ?? UUID()

        let categoryRaw = record["category"] as? String ?? ""
        category = CrossDeviceNotificationCategory(rawValue: categoryRaw) ?? .custom

        priority = PayloadNotificationPriority(rawValue: record["priority"] as? Int ?? 1) ?? .normal

        title = record["title"] as? String ?? ""
        body = record["body"] as? String ?? ""
        subtitle = record["subtitle"] as? String

        let soundRaw = record["sound"] as? String ?? "default"
        sound = CrossDeviceNotificationSound(rawValue: soundRaw) ?? .default

        let hapticRaw = record["haptic"] as? String ?? "medium"
        haptic = CrossDeviceNotificationHaptic(rawValue: hapticRaw) ?? .medium

        badge = record["badge"] as? Int
        threadId = record["threadId"] as? String

        if let deepLinkString = record["deepLink"] as? String {
            deepLink = URL(string: deepLinkString)
        } else {
            deepLink = nil
        }

        // Decode userInfo from JSON string
        if let userInfoData = (record["userInfo"] as? String)?.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String: String].self, from: userInfoData) {
            userInfo = decoded
        } else {
            userInfo = [:]
        }

        let sourceIdString = record["sourceDeviceId"] as? String ?? ""
        sourceDeviceId = UUID(uuidString: sourceIdString) ?? UUID()
        sourceDeviceName = record["sourceDeviceName"] as? String ?? "Unknown"

        // Decode target device IDs
        if let targetIdsData = (record["targetDeviceIds"] as? String)?.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String].self, from: targetIdsData) {
            targetDeviceIds = decoded.compactMap { UUID(uuidString: $0) }
        } else {
            targetDeviceIds = nil
        }

        createdAt = record["createdAt"] as? Date ?? Date()
        expiresAt = record["expiresAt"] as? Date
        requiresAcknowledgment = record["requiresAcknowledgment"] as? Bool ?? false
        actionIdentifier = record["actionIdentifier"] as? String
    }

    public func toRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: self.recordID)
        let record = CKRecord(recordType: "CrossDeviceNotification", recordID: recordID)

        record["category"] = category.rawValue as CKRecordValue
        record["priority"] = priority.rawValue as CKRecordValue
        record["title"] = title as CKRecordValue
        record["body"] = body as CKRecordValue

        if let subtitle {
            record["subtitle"] = subtitle as CKRecordValue
        }

        record["sound"] = sound.rawValue as CKRecordValue
        record["haptic"] = haptic.rawValue as CKRecordValue

        if let badge {
            record["badge"] = badge as CKRecordValue
        }

        if let threadId {
            record["threadId"] = threadId as CKRecordValue
        }

        if let deepLink {
            record["deepLink"] = deepLink.absoluteString as CKRecordValue
        }

        // Encode userInfo as JSON string
        if let userInfoData = try? JSONEncoder().encode(userInfo),
           let userInfoString = String(data: userInfoData, encoding: .utf8) {
            record["userInfo"] = userInfoString as CKRecordValue
        }

        record["sourceDeviceId"] = sourceDeviceId.uuidString as CKRecordValue
        record["sourceDeviceName"] = sourceDeviceName as CKRecordValue

        // Encode target device IDs
        if let targetDeviceIds,
           let targetIdsData = try? JSONEncoder().encode(targetDeviceIds.map(\.uuidString)),
           let targetIdsString = String(data: targetIdsData, encoding: .utf8) {
            record["targetDeviceIds"] = targetIdsString as CKRecordValue
        }

        record["createdAt"] = createdAt as CKRecordValue

        if let expiresAt {
            record["expiresAt"] = expiresAt as CKRecordValue
        }

        record["requiresAcknowledgment"] = requiresAcknowledgment as CKRecordValue

        if let actionIdentifier {
            record["actionIdentifier"] = actionIdentifier as CKRecordValue
        }

        return record
    }

    // MARK: - APNs Payload Generation

    /// Generate APNs-compatible payload dictionary
    public func toAPNsPayload() -> [String: Any] {
        var aps: [String: Any] = [
            "alert": [
                "title": title,
                "body": body,
                "subtitle": subtitle as Any
            ].compactMapValues { $0 },
            "mutable-content": 1,
            "category": category.identifier,
            "interruption-level": priority.interruptionLevel
        ]

        if sound != .none {
            aps["sound"] = sound == .default ? "default" : sound.rawValue
        }

        if let badge {
            aps["badge"] = badge
        }

        if let threadId {
            aps["thread-id"] = threadId
        }

        var payload: [String: Any] = ["aps": aps]

        // Add custom data
        payload["notificationId"] = id.uuidString
        payload["sourceDeviceId"] = sourceDeviceId.uuidString
        payload["sourceDeviceName"] = sourceDeviceName
        payload["haptic"] = haptic.rawValue

        if let deepLink {
            payload["deepLink"] = deepLink.absoluteString
        }

        for (key, value) in userInfo {
            payload[key] = value
        }

        return payload
    }
}

// MARK: - Cross-Device Notification Acknowledgment

/// Tracks acknowledgment of notifications that require it
public struct CrossDeviceNotificationAcknowledgment: Codable, Sendable, Identifiable {
    public let id: UUID
    public let notificationId: UUID
    public let deviceId: UUID
    public let acknowledgedAt: Date
    public let action: String?

    public init(
        id: UUID = UUID(),
        notificationId: UUID,
        deviceId: UUID,
        acknowledgedAt: Date = Date(),
        action: String? = nil
    ) {
        self.id = id
        self.notificationId = notificationId
        self.deviceId = deviceId
        self.acknowledgedAt = acknowledgedAt
        self.action = action
    }

    public var recordID: String {
        "ack-\(id.uuidString)"
    }

    public init(from record: CKRecord) {
        let idString = record.recordID.recordName.replacingOccurrences(of: "ack-", with: "")
        id = UUID(uuidString: idString) ?? UUID()
        notificationId = UUID(uuidString: record["notificationId"] as? String ?? "") ?? UUID()
        deviceId = UUID(uuidString: record["deviceId"] as? String ?? "") ?? UUID()
        acknowledgedAt = record["acknowledgedAt"] as? Date ?? Date()
        action = record["action"] as? String
    }

    public func toRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: self.recordID)
        let record = CKRecord(recordType: "NotificationAcknowledgment", recordID: recordID)
        record["notificationId"] = notificationId.uuidString as CKRecordValue
        record["deviceId"] = deviceId.uuidString as CKRecordValue
        record["acknowledgedAt"] = acknowledgedAt as CKRecordValue
        if let action {
            record["actionTaken"] = action as CKRecordValue
        }
        return record
    }
}

// MARK: - Cross-Device Notification Delivery Status

/// Tracks delivery status of a notification to each device
public enum CrossDeviceDeliveryStatus: String, Codable, Sendable {
    case pending
    case sent
    case delivered
    case failed
    case expired

    public var displayName: String {
        switch self {
        case .pending: "Pending"
        case .sent: "Sent"
        case .delivered: "Delivered"
        case .failed: "Failed"
        case .expired: "Expired"
        }
    }
}

/// Tracks delivery of a notification to a specific device
public struct CrossDeviceNotificationDelivery: Codable, Sendable, Identifiable {
    public let id: UUID
    public let notificationId: UUID
    public let deviceId: UUID
    public var status: CrossDeviceDeliveryStatus
    public var sentAt: Date?
    public var deliveredAt: Date?
    public var failureReason: String?

    public init(
        id: UUID = UUID(),
        notificationId: UUID,
        deviceId: UUID,
        status: CrossDeviceDeliveryStatus = .pending,
        sentAt: Date? = nil,
        deliveredAt: Date? = nil,
        failureReason: String? = nil
    ) {
        self.id = id
        self.notificationId = notificationId
        self.deviceId = deviceId
        self.status = status
        self.sentAt = sentAt
        self.deliveredAt = deliveredAt
        self.failureReason = failureReason
    }
}
