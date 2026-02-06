//
//  NotificationPreferences.swift
//  Thea
//
//  User preferences for cross-device notifications
//  Copyright 2026. All rights reserved.
//

import CloudKit
import Combine
import Foundation
import OSLog

// MARK: - Cross-Device Notification Preferences

/// User preferences for cross-device notification behavior
@MainActor
public final class CrossDeviceNotificationPreferences: ObservableObject {
    /// Shared instance
    public static let shared = CrossDeviceNotificationPreferences()

    private let logger = Logger(subsystem: "app.thea", category: "NotificationPreferences")
    private let defaults = UserDefaults.standard
    private let cloudKeyValueStore = NSUbiquitousKeyValueStore.default
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Storage Keys

    private enum StorageKey {
        static let enabledDevices = "thea.notifications.enabledDevices"
        static let enabledCategories = "thea.notifications.enabledCategories"
        static let categoryPriorities = "thea.notifications.categoryPriorities"
        static let categorySounds = "thea.notifications.categorySounds"
        static let categoryHaptics = "thea.notifications.categoryHaptics"
        static let globalEnabled = "thea.notifications.globalEnabled"
        static let crossDeviceEnabled = "thea.notifications.crossDeviceEnabled"
        static let quietHoursEnabled = "thea.notifications.quietHoursEnabled"
        static let quietHoursStart = "thea.notifications.quietHoursStart"
        static let quietHoursEnd = "thea.notifications.quietHoursEnd"
        static let quietHoursBypassCritical = "thea.notifications.quietHoursBypassCritical"
        static let groupByThread = "thea.notifications.groupByThread"
        static let showPreviews = "thea.notifications.showPreviews"
        static let badgeCount = "thea.notifications.badgeCount"
        static let syncWithiCloud = "thea.notifications.syncWithiCloud"
        static let lastModified = "thea.notifications.lastModified"
    }

    // MARK: - Published Properties

    /// Whether notifications are globally enabled
    @Published public var globalEnabled: Bool {
        didSet { save(globalEnabled, forKey: StorageKey.globalEnabled) }
    }

    /// Whether cross-device notifications are enabled
    @Published public var crossDeviceEnabled: Bool {
        didSet { save(crossDeviceEnabled, forKey: StorageKey.crossDeviceEnabled) }
    }

    /// Device IDs that should receive notifications
    @Published public var enabledDeviceIds: Set<UUID> {
        didSet { saveDeviceIds() }
    }

    /// Categories that are enabled for notifications
    @Published public var enabledCategories: Set<CrossDeviceNotificationCategory> {
        didSet { saveCategories() }
    }

    /// Custom priority overrides per category
    @Published public var categoryPriorities: [CrossDeviceNotificationCategory: CrossDeviceNotificationPriority] {
        didSet { saveCategoryPriorities() }
    }

    /// Custom sound overrides per category
    @Published public var categorySounds: [CrossDeviceNotificationCategory: CrossDeviceNotificationSound] {
        didSet { saveCategorySounds() }
    }

    /// Custom haptic overrides per category
    @Published public var categoryHaptics: [CrossDeviceNotificationCategory: CrossDeviceNotificationHaptic] {
        didSet { saveCategoryHaptics() }
    }

    // MARK: - Quiet Hours

    /// Whether quiet hours are enabled
    @Published public var quietHoursEnabled: Bool {
        didSet { save(quietHoursEnabled, forKey: StorageKey.quietHoursEnabled) }
    }

    /// Start time for quiet hours (hour and minute)
    @Published public var quietHoursStart: DateComponents {
        didSet { saveQuietHoursStart() }
    }

    /// End time for quiet hours (hour and minute)
    @Published public var quietHoursEnd: DateComponents {
        didSet { saveQuietHoursEnd() }
    }

    /// Whether critical notifications bypass quiet hours
    @Published public var quietHoursBypassCritical: Bool {
        didSet { save(quietHoursBypassCritical, forKey: StorageKey.quietHoursBypassCritical) }
    }

    // MARK: - Display Options

    /// Whether to group notifications by thread
    @Published public var groupByThread: Bool {
        didSet { save(groupByThread, forKey: StorageKey.groupByThread) }
    }

    /// Whether to show notification previews
    @Published public var showPreviews: Bool {
        didSet { save(showPreviews, forKey: StorageKey.showPreviews) }
    }

    /// Whether to show badge count
    @Published public var showBadgeCount: Bool {
        didSet { save(showBadgeCount, forKey: StorageKey.badgeCount) }
    }

    // MARK: - Sync

    /// Whether to sync preferences with iCloud
    @Published public var syncWithiCloud: Bool {
        didSet {
            save(syncWithiCloud, forKey: StorageKey.syncWithiCloud)
            if syncWithiCloud {
                syncToiCloud()
            }
        }
    }

    // MARK: - Initialization

    private init() {
        // Initialize complex types with defaults first (required before calling methods)
        enabledDeviceIds = []
        enabledCategories = Set(CrossDeviceNotificationCategory.allCases)
        categoryPriorities = [:]
        categorySounds = [:]
        categoryHaptics = [:]
        quietHoursStart = DateComponents(hour: 22, minute: 0)
        quietHoursEnd = DateComponents(hour: 7, minute: 0)

        // Load simple defaults
        globalEnabled = defaults.bool(forKey: StorageKey.globalEnabled, default: true)
        crossDeviceEnabled = defaults.bool(forKey: StorageKey.crossDeviceEnabled, default: true)
        quietHoursEnabled = defaults.bool(forKey: StorageKey.quietHoursEnabled, default: false)
        quietHoursBypassCritical = defaults.bool(forKey: StorageKey.quietHoursBypassCritical, default: true)
        groupByThread = defaults.bool(forKey: StorageKey.groupByThread, default: true)
        showPreviews = defaults.bool(forKey: StorageKey.showPreviews, default: true)
        showBadgeCount = defaults.bool(forKey: StorageKey.badgeCount, default: true)
        syncWithiCloud = defaults.bool(forKey: StorageKey.syncWithiCloud, default: true)

        // Now load complex types from storage (self is fully initialized)
        enabledDeviceIds = loadDeviceIds()
        enabledCategories = loadCategories()
        categoryPriorities = loadCategoryPriorities()
        categorySounds = loadCategorySounds()
        categoryHaptics = loadCategoryHaptics()
        quietHoursStart = loadQuietHoursStart()
        quietHoursEnd = loadQuietHoursEnd()

        // Setup iCloud sync observation
        setupiCloudObserver()

        // Initial sync from iCloud if enabled
        if syncWithiCloud {
            syncFromiCloud()
        }
    }

    // MARK: - iCloud Sync

    private func setupiCloudObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloudKeyValueStore
        )

        // Start syncing
        cloudKeyValueStore.synchronize()
    }

    @objc private func iCloudDidChange(_ notification: Notification) {
        guard syncWithiCloud else { return }

        Task { @MainActor in
            syncFromiCloud()
        }
    }

    private func syncFromiCloud() {
        // Check if iCloud has newer data
        let cloudModified = cloudKeyValueStore.object(forKey: StorageKey.lastModified) as? Date ?? .distantPast
        let localModified = defaults.object(forKey: StorageKey.lastModified) as? Date ?? .distantPast

        guard cloudModified > localModified else { return }

        logger.info("Syncing notification preferences from iCloud")

        // Sync each preference
        if let value = cloudKeyValueStore.object(forKey: StorageKey.globalEnabled) as? Bool {
            globalEnabled = value
        }

        if let value = cloudKeyValueStore.object(forKey: StorageKey.crossDeviceEnabled) as? Bool {
            crossDeviceEnabled = value
        }

        if let value = cloudKeyValueStore.object(forKey: StorageKey.quietHoursEnabled) as? Bool {
            quietHoursEnabled = value
        }

        if let value = cloudKeyValueStore.object(forKey: StorageKey.quietHoursBypassCritical) as? Bool {
            quietHoursBypassCritical = value
        }

        if let value = cloudKeyValueStore.object(forKey: StorageKey.groupByThread) as? Bool {
            groupByThread = value
        }

        if let value = cloudKeyValueStore.object(forKey: StorageKey.showPreviews) as? Bool {
            showPreviews = value
        }

        if let value = cloudKeyValueStore.object(forKey: StorageKey.badgeCount) as? Bool {
            showBadgeCount = value
        }

        // Sync complex types
        if let data = cloudKeyValueStore.data(forKey: StorageKey.enabledCategories),
           let categories = try? JSONDecoder().decode(Set<String>.self, from: data) {
            enabledCategories = Set(categories.compactMap { CrossDeviceNotificationCategory(rawValue: $0) })
        }
    }

    private func syncToiCloud() {
        guard syncWithiCloud else { return }

        logger.info("Syncing notification preferences to iCloud")

        cloudKeyValueStore.set(globalEnabled, forKey: StorageKey.globalEnabled)
        cloudKeyValueStore.set(crossDeviceEnabled, forKey: StorageKey.crossDeviceEnabled)
        cloudKeyValueStore.set(quietHoursEnabled, forKey: StorageKey.quietHoursEnabled)
        cloudKeyValueStore.set(quietHoursBypassCritical, forKey: StorageKey.quietHoursBypassCritical)
        cloudKeyValueStore.set(groupByThread, forKey: StorageKey.groupByThread)
        cloudKeyValueStore.set(showPreviews, forKey: StorageKey.showPreviews)
        cloudKeyValueStore.set(showBadgeCount, forKey: StorageKey.badgeCount)
        cloudKeyValueStore.set(Date(), forKey: StorageKey.lastModified)

        // Sync complex types
        if let data = try? JSONEncoder().encode(Set(enabledCategories.map(\.rawValue))) {
            cloudKeyValueStore.set(data, forKey: StorageKey.enabledCategories)
        }

        cloudKeyValueStore.synchronize()
    }

    // MARK: - Save Helpers

    private func save(_ value: Bool, forKey key: String) {
        defaults.set(value, forKey: key)
        if syncWithiCloud {
            cloudKeyValueStore.set(value, forKey: key)
            cloudKeyValueStore.set(Date(), forKey: StorageKey.lastModified)
            cloudKeyValueStore.synchronize()
        }
    }

    private func saveDeviceIds() {
        let ids = enabledDeviceIds.map(\.uuidString)
        if let data = try? JSONEncoder().encode(ids) {
            defaults.set(data, forKey: StorageKey.enabledDevices)
        }
    }

    private func loadDeviceIds() -> Set<UUID> {
        guard let data = defaults.data(forKey: StorageKey.enabledDevices),
              let ids = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return Set(ids.compactMap { UUID(uuidString: $0) })
    }

    private func saveCategories() {
        let rawValues = enabledCategories.map(\.rawValue)
        if let data = try? JSONEncoder().encode(rawValues) {
            defaults.set(data, forKey: StorageKey.enabledCategories)
            if syncWithiCloud {
                cloudKeyValueStore.set(data, forKey: StorageKey.enabledCategories)
                syncToiCloud()
            }
        }
    }

    private func loadCategories() -> Set<CrossDeviceNotificationCategory> {
        guard let data = defaults.data(forKey: StorageKey.enabledCategories),
              let rawValues = try? JSONDecoder().decode([String].self, from: data)
        else {
            // Default: all categories enabled
            return Set(CrossDeviceNotificationCategory.allCases)
        }
        return Set(rawValues.compactMap { CrossDeviceNotificationCategory(rawValue: $0) })
    }

    private func saveCategoryPriorities() {
        let dict = Dictionary(uniqueKeysWithValues: categoryPriorities.map { ($0.key.rawValue, $0.value.rawValue) })
        if let data = try? JSONEncoder().encode(dict) {
            defaults.set(data, forKey: StorageKey.categoryPriorities)
        }
    }

    private func loadCategoryPriorities() -> [CrossDeviceNotificationCategory: CrossDeviceNotificationPriority] {
        guard let data = defaults.data(forKey: StorageKey.categoryPriorities),
              let dict = try? JSONDecoder().decode([String: Int].self, from: data)
        else { return [:] }

        var result: [CrossDeviceNotificationCategory: CrossDeviceNotificationPriority] = [:]
        for (key, value) in dict {
            if let category = CrossDeviceNotificationCategory(rawValue: key),
               let priority = CrossDeviceNotificationPriority(rawValue: value) {
                result[category] = priority
            }
        }
        return result
    }

    private func saveCategorySounds() {
        let dict = Dictionary(uniqueKeysWithValues: categorySounds.map { ($0.key.rawValue, $0.value.rawValue) })
        if let data = try? JSONEncoder().encode(dict) {
            defaults.set(data, forKey: StorageKey.categorySounds)
        }
    }

    private func loadCategorySounds() -> [CrossDeviceNotificationCategory: CrossDeviceNotificationSound] {
        guard let data = defaults.data(forKey: StorageKey.categorySounds),
              let dict = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }

        var result: [CrossDeviceNotificationCategory: CrossDeviceNotificationSound] = [:]
        for (key, value) in dict {
            if let category = CrossDeviceNotificationCategory(rawValue: key),
               let sound = CrossDeviceNotificationSound(rawValue: value) {
                result[category] = sound
            }
        }
        return result
    }

    private func saveCategoryHaptics() {
        let dict = Dictionary(uniqueKeysWithValues: categoryHaptics.map { ($0.key.rawValue, $0.value.rawValue) })
        if let data = try? JSONEncoder().encode(dict) {
            defaults.set(data, forKey: StorageKey.categoryHaptics)
        }
    }

    private func loadCategoryHaptics() -> [CrossDeviceNotificationCategory: CrossDeviceNotificationHaptic] {
        guard let data = defaults.data(forKey: StorageKey.categoryHaptics),
              let dict = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }

        var result: [CrossDeviceNotificationCategory: CrossDeviceNotificationHaptic] = [:]
        for (key, value) in dict {
            if let category = CrossDeviceNotificationCategory(rawValue: key),
               let haptic = CrossDeviceNotificationHaptic(rawValue: value) {
                result[category] = haptic
            }
        }
        return result
    }

    private func saveQuietHoursStart() {
        let dict: [String: Int] = [
            "hour": quietHoursStart.hour ?? 22,
            "minute": quietHoursStart.minute ?? 0
        ]
        if let data = try? JSONEncoder().encode(dict) {
            defaults.set(data, forKey: StorageKey.quietHoursStart)
        }
    }

    private func loadQuietHoursStart() -> DateComponents {
        guard let data = defaults.data(forKey: StorageKey.quietHoursStart),
              let dict = try? JSONDecoder().decode([String: Int].self, from: data)
        else {
            // Default: 10 PM
            return DateComponents(hour: 22, minute: 0)
        }
        return DateComponents(hour: dict["hour"], minute: dict["minute"])
    }

    private func saveQuietHoursEnd() {
        let dict: [String: Int] = [
            "hour": quietHoursEnd.hour ?? 7,
            "minute": quietHoursEnd.minute ?? 0
        ]
        if let data = try? JSONEncoder().encode(dict) {
            defaults.set(data, forKey: StorageKey.quietHoursEnd)
        }
    }

    private func loadQuietHoursEnd() -> DateComponents {
        guard let data = defaults.data(forKey: StorageKey.quietHoursEnd),
              let dict = try? JSONDecoder().decode([String: Int].self, from: data)
        else {
            // Default: 7 AM
            return DateComponents(hour: 7, minute: 0)
        }
        return DateComponents(hour: dict["hour"], minute: dict["minute"])
    }

    // MARK: - Public API

    /// Check if a category is enabled for notifications
    public func isCategoryEnabled(_ category: CrossDeviceNotificationCategory) -> Bool {
        enabledCategories.contains(category)
    }

    /// Enable or disable a category
    public func setCategory(_ category: CrossDeviceNotificationCategory, enabled: Bool) {
        if enabled {
            enabledCategories.insert(category)
        } else {
            enabledCategories.remove(category)
        }
    }

    /// Get effective priority for a category (custom or default)
    public func effectivePriority(for category: CrossDeviceNotificationCategory) -> CrossDeviceNotificationPriority {
        categoryPriorities[category] ?? category.defaultPriority
    }

    /// Get effective sound for a category (custom or default)
    public func effectiveSound(for category: CrossDeviceNotificationCategory) -> CrossDeviceNotificationSound {
        categorySounds[category] ?? category.defaultSound
    }

    /// Get effective haptic for a category
    public func effectiveHaptic(for category: CrossDeviceNotificationCategory) -> CrossDeviceNotificationHaptic {
        categoryHaptics[category] ?? .medium
    }

    /// Check if currently in quiet hours
    public func isInQuietHours(at date: Date = Date()) -> Bool {
        guard quietHoursEnabled else { return false }

        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let currentMinutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)

        let startMinutes = (quietHoursStart.hour ?? 22) * 60 + (quietHoursStart.minute ?? 0)
        let endMinutes = (quietHoursEnd.hour ?? 7) * 60 + (quietHoursEnd.minute ?? 0)

        if startMinutes < endMinutes {
            // Same day range (e.g., 9 AM to 5 PM)
            return currentMinutes >= startMinutes && currentMinutes < endMinutes
        } else {
            // Overnight range (e.g., 10 PM to 7 AM)
            return currentMinutes >= startMinutes || currentMinutes < endMinutes
        }
    }

    /// Check if a notification should be delivered based on preferences
    public func shouldDeliver(
        category: CrossDeviceNotificationCategory,
        priority: CrossDeviceNotificationPriority,
        toDevice deviceId: UUID? = nil
    ) -> Bool {
        // Check global enabled
        guard globalEnabled, crossDeviceEnabled else { return false }

        // Check category enabled
        guard isCategoryEnabled(category) else { return false }

        // Check device enabled (if specified)
        if let deviceId, !enabledDeviceIds.isEmpty, !enabledDeviceIds.contains(deviceId) {
            return false
        }

        // Check quiet hours
        if isInQuietHours() {
            // Allow critical if bypass enabled
            if quietHoursBypassCritical && priority == .critical {
                return true
            }
            return false
        }

        return true
    }

    /// Enable notifications for a device
    public func enableDevice(_ deviceId: UUID) {
        enabledDeviceIds.insert(deviceId)
    }

    /// Disable notifications for a device
    public func disableDevice(_ deviceId: UUID) {
        enabledDeviceIds.remove(deviceId)
    }

    /// Check if a device is enabled
    public func isDeviceEnabled(_ deviceId: UUID) -> Bool {
        enabledDeviceIds.isEmpty || enabledDeviceIds.contains(deviceId)
    }

    /// Reset all preferences to defaults
    public func resetToDefaults() {
        globalEnabled = true
        crossDeviceEnabled = true
        enabledDeviceIds = []
        enabledCategories = Set(CrossDeviceNotificationCategory.allCases)
        categoryPriorities = [:]
        categorySounds = [:]
        categoryHaptics = [:]
        quietHoursEnabled = false
        quietHoursStart = DateComponents(hour: 22, minute: 0)
        quietHoursEnd = DateComponents(hour: 7, minute: 0)
        quietHoursBypassCritical = true
        groupByThread = true
        showPreviews = true
        showBadgeCount = true

        logger.info("Reset notification preferences to defaults")
    }
}

// MARK: - UserDefaults Extension

private extension UserDefaults {
    func bool(forKey key: String, default defaultValue: Bool) -> Bool {
        object(forKey: key) != nil ? bool(forKey: key) : defaultValue
    }
}

// MARK: - Per-Device Preferences

/// Device-specific notification preferences
public struct CrossDeviceSpecificPreferences: Codable, Sendable {
    public let deviceId: UUID
    public var soundEnabled: Bool
    public var hapticEnabled: Bool
    public var badgeEnabled: Bool
    public var previewsEnabled: Bool
    public var priorityFilter: CrossDeviceNotificationPriority // Minimum priority to show

    public init(
        deviceId: UUID,
        soundEnabled: Bool = true,
        hapticEnabled: Bool = true,
        badgeEnabled: Bool = true,
        previewsEnabled: Bool = true,
        priorityFilter: CrossDeviceNotificationPriority = .low
    ) {
        self.deviceId = deviceId
        self.soundEnabled = soundEnabled
        self.hapticEnabled = hapticEnabled
        self.badgeEnabled = badgeEnabled
        self.previewsEnabled = previewsEnabled
        self.priorityFilter = priorityFilter
    }
}

// MARK: - Notification Schedule

/// Schedule for notification delivery
public struct CrossDeviceNotificationSchedule: Codable, Sendable {
    public let id: UUID
    public let name: String
    public let startTime: DateComponents
    public let endTime: DateComponents
    public let daysOfWeek: Set<Int> // 1 = Sunday, 7 = Saturday
    public let categories: Set<CrossDeviceNotificationCategory>
    public let maxPriority: CrossDeviceNotificationPriority
    public let isActive: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        startTime: DateComponents,
        endTime: DateComponents,
        daysOfWeek: Set<Int>,
        categories: Set<CrossDeviceNotificationCategory>,
        maxPriority: CrossDeviceNotificationPriority = .normal,
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.startTime = startTime
        self.endTime = endTime
        self.daysOfWeek = daysOfWeek
        self.categories = categories
        self.maxPriority = maxPriority
        self.isActive = isActive
    }

    /// Check if this schedule applies at a given time
    public func appliesAt(_ date: Date) -> Bool {
        guard isActive else { return false }

        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .weekday], from: date)

        // Check day of week
        guard let weekday = components.weekday, daysOfWeek.contains(weekday) else {
            return false
        }

        // Check time range
        let currentMinutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        let startMinutes = (startTime.hour ?? 0) * 60 + (startTime.minute ?? 0)
        let endMinutes = (endTime.hour ?? 23) * 60 + (endTime.minute ?? 59)

        if startMinutes < endMinutes {
            return currentMinutes >= startMinutes && currentMinutes <= endMinutes
        } else {
            return currentMinutes >= startMinutes || currentMinutes <= endMinutes
        }
    }
}
