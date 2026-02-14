//
//  CrossDeviceNotificationTypes.swift
//  Thea
//
//  Type definitions for cross-device notification system
//  Copyright 2026. All rights reserved.
//

import CloudKit
import Foundation

// MARK: - Device Registration

/// Represents a device registered for cross-device notifications
public struct TheaDeviceRegistration: Identifiable, Codable, Sendable {
    public let id: String
    public let deviceType: TheaDeviceType
    public let deviceName: String
    public let osVersion: String
    public let appVersion: String
    public var pushToken: String?
    public var lastSeen: Date
    public var isActive: Bool
    public var capabilities: Set<NotificationCapability>

    public init(
        id: String = UUID().uuidString,
        deviceType: TheaDeviceType,
        deviceName: String,
        osVersion: String,
        appVersion: String,
        pushToken: String? = nil,
        lastSeen: Date = Date(),
        isActive: Bool = true,
        capabilities: Set<NotificationCapability> = []
    ) {
        self.id = id
        self.deviceType = deviceType
        self.deviceName = deviceName
        self.osVersion = osVersion
        self.appVersion = appVersion
        self.pushToken = pushToken
        self.lastSeen = lastSeen
        self.isActive = isActive
        self.capabilities = capabilities
    }

    // CloudKit initialization
    public init?(from record: CKRecord) {
        guard let id = record["deviceId"] as? String else { return nil }
        self.id = id
        self.deviceType = TheaDeviceType(rawValue: record["deviceType"] as? String ?? "unknown") ?? .unknown
        self.deviceName = record["deviceName"] as? String ?? "Unknown Device"
        self.osVersion = record["osVersion"] as? String ?? ""
        self.appVersion = record["appVersion"] as? String ?? ""
        self.pushToken = record["pushToken"] as? String
        self.lastSeen = record["lastSeen"] as? Date ?? Date()
        self.isActive = record["isActive"] as? Bool ?? true
        self.capabilities = []
    }
}

// MARK: - Device Type

public enum TheaDeviceType: String, Codable, Sendable, CaseIterable {
    case iPhone
    case iPad
    case mac
    case watch
    case tv
    case vision
    case unknown

    public var displayName: String {
        switch self {
        case .iPhone: "iPhone"
        case .iPad: "iPad"
        case .mac: "Mac"
        case .watch: "Apple Watch"
        case .tv: "Apple TV"
        case .vision: "Apple Vision Pro"
        case .unknown: "Unknown Device"
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
        case .unknown: "questionmark.circle"
        }
    }
}

// MARK: - Notification Capability

public enum NotificationCapability: String, Codable, Sendable {
    case push
    case alert
    case badge
    case sound
    case criticalAlert
    case carPlay
    case announcement
}

// MARK: - Notification Payload

/// Complete payload for a cross-device notification
public struct TheaNotificationPayload: Identifiable, Codable, Sendable {
    public let id: UUID
    public let title: String
    public let body: String
    public var subtitle: String?
    public let category: TheaCrossDeviceNotificationCategory
    public let priority: CrossDeviceNotificationPriority
    public var threadIdentifier: String?
    public var interruptionLevel: InterruptionLevel
    public var relevanceScore: Double
    public var targetDevices: [String]  // Device IDs, empty = all devices
    public var expiresAt: Date?
    public var userInfo: [String: String]
    public var sound: TheaNotificationSound
    public var haptic: TheaNotificationHaptic?
    public let createdAt: Date
    public let sourceDeviceId: String

    public init(
        id: UUID = UUID(),
        title: String,
        body: String,
        subtitle: String? = nil,
        category: TheaCrossDeviceNotificationCategory = .custom,
        priority: CrossDeviceNotificationPriority = .normal,
        threadIdentifier: String? = nil,
        interruptionLevel: InterruptionLevel = .active,
        relevanceScore: Double = 0.5,
        targetDevices: [String] = [],
        expiresAt: Date? = nil,
        userInfo: [String: String] = [:],
        sound: TheaNotificationSound = .default,
        haptic: TheaNotificationHaptic? = nil,
        createdAt: Date = Date(),
        sourceDeviceId: String
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.subtitle = subtitle
        self.category = category
        self.priority = priority
        self.threadIdentifier = threadIdentifier
        self.interruptionLevel = interruptionLevel
        self.relevanceScore = relevanceScore
        self.targetDevices = targetDevices
        self.expiresAt = expiresAt
        self.userInfo = userInfo
        self.sound = sound
        self.haptic = haptic
        self.createdAt = createdAt
        self.sourceDeviceId = sourceDeviceId
    }
}

// MARK: - Interruption Level

public enum InterruptionLevel: String, Codable, Sendable {
    case passive
    case active
    case timeSensitive
    case critical
}

// MARK: - Notification Sound

public enum TheaNotificationSound: String, Codable, Sendable {
    case `default`
    case none
    case subtle
    case prominent
    case urgent
    case custom
}

// MARK: - Notification Haptic

public struct TheaNotificationHaptic: Codable, Sendable {
    public let type: HapticType
    public let intensity: Double

    public enum HapticType: String, Codable, Sendable {
        case light
        case medium
        case heavy
        case success
        case warning
        case error
    }

    public init(type: HapticType = .medium, intensity: Double = 1.0) {
        self.type = type
        self.intensity = intensity
    }
}

// MARK: - Notification Delivery

/// Tracks delivery status of a notification to a specific device
public struct TheaNotificationDelivery: Identifiable, Codable, Sendable {
    public let id: UUID
    public let notificationId: UUID
    public let deviceId: String
    public var status: DeliveryStatus
    public var sentAt: Date?
    public var deliveredAt: Date?
    public var readAt: Date?
    public var failureReason: String?

    public enum DeliveryStatus: String, Codable, Sendable {
        case pending
        case sent
        case delivered
        case read
        case failed
        case expired
    }

    public init(
        id: UUID = UUID(),
        notificationId: UUID,
        deviceId: String,
        status: DeliveryStatus = .pending
    ) {
        self.id = id
        self.notificationId = notificationId
        self.deviceId = deviceId
        self.status = status
    }
}

// MARK: - Cross-Device Notification Category

/// Categories of cross-device notifications (aliased from NotificationPayload)
public typealias TheaCrossDeviceNotificationCategory = CrossDeviceNotificationCategory

// Note: CrossDeviceNotificationPriority is defined in UniversalNotificationService.swift
