// NotificationPayloadTypesTests.swift
// Tests for cross-device notification types: priorities, categories, sounds, haptics,
// device types, delivery status, quiet hours, and delivery filtering logic

import Testing
import Foundation

// MARK: - Test Doubles

private enum TestNotificationPriority: Int, CaseIterable, Comparable, Sendable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3

    static func < (lhs: TestNotificationPriority, rhs: TestNotificationPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
        case .low: "Low"
        case .normal: "Normal"
        case .high: "High"
        case .critical: "Critical"
        }
    }

    var interruptionLevel: String {
        switch self {
        case .low: "passive"
        case .normal: "active"
        case .high: "time-sensitive"
        case .critical: "critical"
        }
    }

    var shouldAlwaysDeliver: Bool {
        self == .critical
    }
}

private enum TestNotificationCategory: String, CaseIterable, Sendable {
    case taskCompletion = "THEA_CROSS_TASK_COMPLETE"
    case aiResponseReady = "THEA_CROSS_AI_RESPONSE"
    case passwordNeeded = "THEA_CROSS_PASSWORD"
    case approvalRequired = "THEA_CROSS_APPROVAL"
    case syncComplete = "THEA_CROSS_SYNC"
    case errorAlert = "THEA_CROSS_ERROR"
    case agentUpdate = "THEA_CROSS_AGENT"
    case reminder = "THEA_CROSS_REMINDER"
    case fileReady = "THEA_CROSS_FILE"
    case custom = "THEA_CROSS_CUSTOM"

    var defaultPriority: TestNotificationPriority {
        switch self {
        case .passwordNeeded, .approvalRequired: .critical
        case .errorAlert, .aiResponseReady: .high
        case .taskCompletion, .agentUpdate, .fileReady, .reminder: .normal
        case .syncComplete, .custom: .low
        }
    }

    var defaultSound: TestNotificationSound {
        switch self {
        case .passwordNeeded, .approvalRequired: .alert
        case .errorAlert: .error
        case .aiResponseReady, .taskCompletion: .success
        case .agentUpdate: .subtle
        default: .default
        }
    }

    var icon: String {
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
}

private enum TestNotificationSound: String, CaseIterable, Sendable {
    case `default` = "default"
    case subtle = "thea_subtle.caf"
    case success = "thea_success.caf"
    case alert = "thea_alert.caf"
    case error = "thea_error.caf"
    case chime = "thea_chime.caf"
    case none = "none"

    var displayName: String {
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

private enum TestNotificationHaptic: String, CaseIterable, Sendable {
    case none, light, medium, heavy, success, warning, error
}

private enum TestDeviceType: String, CaseIterable, Sendable {
    case iPhone, iPad, mac, watch, tv, vision

    var displayName: String {
        switch self {
        case .iPhone: "iPhone"
        case .iPad: "iPad"
        case .mac: "Mac"
        case .watch: "Apple Watch"
        case .tv: "Apple TV"
        case .vision: "Apple Vision Pro"
        }
    }

    var icon: String {
        switch self {
        case .iPhone: "iphone"
        case .iPad: "ipad"
        case .mac: "desktopcomputer"
        case .watch: "applewatch"
        case .tv: "appletv"
        case .vision: "visionpro"
        }
    }
}

private enum TestDeliveryStatus: String, CaseIterable, Sendable {
    case pending, sent, delivered, failed, expired
}

/// Mirrors quiet hours logic from NotificationPreferences
private func isInQuietHours(at time: (hour: Int, minute: Int), start: (hour: Int, minute: Int), end: (hour: Int, minute: Int)) -> Bool {
    let currentMinutes = time.hour * 60 + time.minute
    let startMinutes = start.hour * 60 + start.minute
    let endMinutes = end.hour * 60 + end.minute

    if startMinutes <= endMinutes {
        // Same day range (e.g., 09:00 - 17:00)
        return currentMinutes >= startMinutes && currentMinutes < endMinutes
    } else {
        // Overnight range (e.g., 22:00 - 07:00)
        return currentMinutes >= startMinutes || currentMinutes < endMinutes
    }
}

/// Mirrors shouldDeliver logic
private func shouldDeliver(
    category: TestNotificationCategory,
    priority: TestNotificationPriority,
    inQuietHours: Bool,
    deviceEnabled: Bool
) -> Bool {
    guard deviceEnabled else { return false }
    if priority == .critical { return true }
    if inQuietHours && priority.rawValue < TestNotificationPriority.high.rawValue { return false }
    return true
}

// MARK: - Tests: Priority

@Suite("Notification Priority")
struct NotificationPriorityTests {
    @Test("4 priority levels exist")
    func count() {
        #expect(TestNotificationPriority.allCases.count == 4)
    }

    @Test("Raw values are 0-3")
    func rawValues() {
        #expect(TestNotificationPriority.low.rawValue == 0)
        #expect(TestNotificationPriority.critical.rawValue == 3)
    }

    @Test("Comparable ordering")
    func ordering() {
        #expect(TestNotificationPriority.low < .normal)
        #expect(TestNotificationPriority.normal < .high)
        #expect(TestNotificationPriority.high < .critical)
    }

    @Test("APNs interruption levels")
    func interruptionLevels() {
        #expect(TestNotificationPriority.low.interruptionLevel == "passive")
        #expect(TestNotificationPriority.normal.interruptionLevel == "active")
        #expect(TestNotificationPriority.high.interruptionLevel == "time-sensitive")
        #expect(TestNotificationPriority.critical.interruptionLevel == "critical")
    }

    @Test("Only critical should always deliver")
    func alwaysDeliver() {
        #expect(!TestNotificationPriority.low.shouldAlwaysDeliver)
        #expect(!TestNotificationPriority.normal.shouldAlwaysDeliver)
        #expect(!TestNotificationPriority.high.shouldAlwaysDeliver)
        #expect(TestNotificationPriority.critical.shouldAlwaysDeliver)
    }

    @Test("Display names")
    func displayNames() {
        #expect(TestNotificationPriority.low.displayName == "Low")
        #expect(TestNotificationPriority.critical.displayName == "Critical")
    }
}

// MARK: - Tests: Category

@Suite("Notification Category")
struct NotificationCategoryTests {
    @Test("10 categories exist")
    func count() {
        #expect(TestNotificationCategory.allCases.count == 10)
    }

    @Test("All raw values are unique")
    func uniqueRawValues() {
        let rawValues = TestNotificationCategory.allCases.map(\.rawValue)
        #expect(Set(rawValues).count == rawValues.count)
    }

    @Test("All raw values start with THEA_CROSS_")
    func rawValuePrefix() {
        for cat in TestNotificationCategory.allCases {
            #expect(cat.rawValue.hasPrefix("THEA_CROSS_"))
        }
    }

    @Test("Password and approval have critical priority")
    func criticalCategories() {
        #expect(TestNotificationCategory.passwordNeeded.defaultPriority == .critical)
        #expect(TestNotificationCategory.approvalRequired.defaultPriority == .critical)
    }

    @Test("Error and AI response have high priority")
    func highCategories() {
        #expect(TestNotificationCategory.errorAlert.defaultPriority == .high)
        #expect(TestNotificationCategory.aiResponseReady.defaultPriority == .high)
    }

    @Test("Task completion and agent update have normal priority")
    func normalCategories() {
        #expect(TestNotificationCategory.taskCompletion.defaultPriority == .normal)
        #expect(TestNotificationCategory.agentUpdate.defaultPriority == .normal)
    }

    @Test("Sync and custom have low priority")
    func lowCategories() {
        #expect(TestNotificationCategory.syncComplete.defaultPriority == .low)
        #expect(TestNotificationCategory.custom.defaultPriority == .low)
    }

    @Test("Password gets alert sound")
    func passwordSound() {
        #expect(TestNotificationCategory.passwordNeeded.defaultSound == .alert)
    }

    @Test("Error gets error sound")
    func errorSound() {
        #expect(TestNotificationCategory.errorAlert.defaultSound == .error)
    }

    @Test("Task completion gets success sound")
    func taskSound() {
        #expect(TestNotificationCategory.taskCompletion.defaultSound == .success)
    }

    @Test("Agent update gets subtle sound")
    func agentSound() {
        #expect(TestNotificationCategory.agentUpdate.defaultSound == .subtle)
    }

    @Test("Sync gets default sound")
    func syncSound() {
        #expect(TestNotificationCategory.syncComplete.defaultSound == .default)
    }

    @Test("All categories have icons")
    func allHaveIcons() {
        for cat in TestNotificationCategory.allCases {
            #expect(!cat.icon.isEmpty)
        }
    }
}

// MARK: - Tests: Sound

@Suite("Notification Sound")
struct NotificationSoundTests {
    @Test("7 sound options")
    func count() {
        #expect(TestNotificationSound.allCases.count == 7)
    }

    @Test("Custom sounds use .caf extension")
    func cafExtension() {
        let customSounds: [TestNotificationSound] = [.subtle, .success, .alert, .error, .chime]
        for sound in customSounds {
            #expect(sound.rawValue.hasSuffix(".caf"))
        }
    }

    @Test("None has 'none' raw value (not .caf)")
    func noneRawValue() {
        #expect(TestNotificationSound.none.rawValue == "none")
    }

    @Test("Default has 'default' raw value")
    func defaultRawValue() {
        #expect(TestNotificationSound.default.rawValue == "default")
    }
}

// MARK: - Tests: Haptic

@Suite("Notification Haptic")
struct NotificationHapticTests {
    @Test("7 haptic patterns")
    func count() {
        #expect(TestNotificationHaptic.allCases.count == 7)
    }

    @Test("All raw values are unique")
    func unique() {
        let rawValues = TestNotificationHaptic.allCases.map(\.rawValue)
        #expect(Set(rawValues).count == rawValues.count)
    }
}

// MARK: - Tests: Device Type

@Suite("Device Type")
struct DeviceTypeTests {
    @Test("6 device types")
    func count() {
        #expect(TestDeviceType.allCases.count == 6)
    }

    @Test("Display names are human-readable")
    func displayNames() {
        #expect(TestDeviceType.iPhone.displayName == "iPhone")
        #expect(TestDeviceType.watch.displayName == "Apple Watch")
        #expect(TestDeviceType.vision.displayName == "Apple Vision Pro")
    }

    @Test("All have SF Symbol icons")
    func icons() {
        for device in TestDeviceType.allCases {
            #expect(!device.icon.isEmpty)
        }
    }

    @Test("Mac uses desktopcomputer icon")
    func macIcon() {
        #expect(TestDeviceType.mac.icon == "desktopcomputer")
    }
}

// MARK: - Tests: Delivery Status

@Suite("Delivery Status")
struct DeliveryStatusTests {
    @Test("5 delivery statuses")
    func count() {
        #expect(TestDeliveryStatus.allCases.count == 5)
    }

    @Test("All raw values are unique")
    func unique() {
        let rawValues = TestDeliveryStatus.allCases.map(\.rawValue)
        #expect(Set(rawValues).count == rawValues.count)
    }
}

// MARK: - Tests: Quiet Hours Logic

@Suite("Quiet Hours — isInQuietHours()")
struct QuietHoursTests {
    @Test("Same-day range: 9 AM to 5 PM")
    func sameDayInRange() {
        #expect(isInQuietHours(at: (12, 0), start: (9, 0), end: (17, 0)))
    }

    @Test("Same-day range: before start")
    func sameDayBeforeStart() {
        #expect(!isInQuietHours(at: (8, 59), start: (9, 0), end: (17, 0)))
    }

    @Test("Same-day range: at end time")
    func sameDayAtEnd() {
        #expect(!isInQuietHours(at: (17, 0), start: (9, 0), end: (17, 0)))
    }

    @Test("Same-day range: at start time")
    func sameDayAtStart() {
        #expect(isInQuietHours(at: (9, 0), start: (9, 0), end: (17, 0)))
    }

    @Test("Overnight range: 10 PM to 7 AM — midnight in range")
    func overnightMidnight() {
        #expect(isInQuietHours(at: (0, 0), start: (22, 0), end: (7, 0)))
    }

    @Test("Overnight range: 10 PM to 7 AM — 11 PM in range")
    func overnight11PM() {
        #expect(isInQuietHours(at: (23, 0), start: (22, 0), end: (7, 0)))
    }

    @Test("Overnight range: 10 PM to 7 AM — 6 AM in range")
    func overnight6AM() {
        #expect(isInQuietHours(at: (6, 0), start: (22, 0), end: (7, 0)))
    }

    @Test("Overnight range: 10 PM to 7 AM — 8 AM not in range")
    func overnight8AM() {
        #expect(!isInQuietHours(at: (8, 0), start: (22, 0), end: (7, 0)))
    }

    @Test("Overnight range: 10 PM to 7 AM — 3 PM not in range")
    func overnight3PM() {
        #expect(!isInQuietHours(at: (15, 0), start: (22, 0), end: (7, 0)))
    }

    @Test("Overnight range: at start")
    func overnightAtStart() {
        #expect(isInQuietHours(at: (22, 0), start: (22, 0), end: (7, 0)))
    }

    @Test("Overnight range: at end")
    func overnightAtEnd() {
        #expect(!isInQuietHours(at: (7, 0), start: (22, 0), end: (7, 0)))
    }
}

// MARK: - Tests: Delivery Filtering

@Suite("Delivery Filtering — shouldDeliver()")
struct DeliveryFilteringTests {
    @Test("Disabled device never delivers")
    func disabledDevice() {
        let result = shouldDeliver(category: .passwordNeeded, priority: .critical, inQuietHours: false, deviceEnabled: false)
        #expect(!result)
    }

    @Test("Critical priority always delivers during quiet hours")
    func criticalDuringQuiet() {
        let result = shouldDeliver(category: .passwordNeeded, priority: .critical, inQuietHours: true, deviceEnabled: true)
        #expect(result)
    }

    @Test("High priority delivers during quiet hours")
    func highDuringQuiet() {
        let result = shouldDeliver(category: .errorAlert, priority: .high, inQuietHours: true, deviceEnabled: true)
        #expect(result)
    }

    @Test("Normal priority blocked during quiet hours")
    func normalBlockedQuiet() {
        let result = shouldDeliver(category: .taskCompletion, priority: .normal, inQuietHours: true, deviceEnabled: true)
        #expect(!result)
    }

    @Test("Low priority blocked during quiet hours")
    func lowBlockedQuiet() {
        let result = shouldDeliver(category: .syncComplete, priority: .low, inQuietHours: true, deviceEnabled: true)
        #expect(!result)
    }

    @Test("Normal priority delivers outside quiet hours")
    func normalOutsideQuiet() {
        let result = shouldDeliver(category: .taskCompletion, priority: .normal, inQuietHours: false, deviceEnabled: true)
        #expect(result)
    }

    @Test("Low priority delivers outside quiet hours")
    func lowOutsideQuiet() {
        let result = shouldDeliver(category: .syncComplete, priority: .low, inQuietHours: false, deviceEnabled: true)
        #expect(result)
    }
}
