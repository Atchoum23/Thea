// NotificationPayloadTypes.swift
// Supporting types for NotificationPayload

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
    @MainActor
    public static var current: CrossDeviceType {
        #if os(iOS)
            let idiom = UIDevice.current.userInterfaceIdiom
            return idiom == .pad ? .iPad : .iPhone
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

// MARK: - Cross-Device Delivery Status

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
