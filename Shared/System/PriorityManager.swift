//
//  PriorityManager.swift
//  Thea
//
//  Created by Claude Code on 2026-01-20
//  Copyright © 2026. All rights reserved.
//

import Foundation
import os.log

// MARK: - Priority Manager

/// Manages notification and task priority levels
@MainActor
@Observable
public final class PriorityManager {
    private let logger = Logger(subsystem: "ai.thea.app", category: "PriorityManager")
    public static let shared = PriorityManager()

    private let defaults = UserDefaults.standard
    private let configKey = "PriorityManager.configuration"

    // MARK: - Configuration

    public var configuration: PriorityConfiguration {
        didSet {
            saveConfiguration()
        }
    }

    // MARK: - Initialization

    private init() {
        if let data = defaults.data(forKey: configKey) {
            do {
                configuration = try JSONDecoder().decode(PriorityConfiguration.self, from: data)
            } catch {
                logger.error("PriorityManager: failed to decode priority configuration: \(error.localizedDescription)")
                configuration = PriorityConfiguration()
            }
        } else {
            configuration = PriorityConfiguration()
        }
    }

    // MARK: - Persistence

    private func saveConfiguration() {
        do {
            let data = try JSONEncoder().encode(configuration)
            defaults.set(data, forKey: configKey)
        } catch {
            logger.error("PriorityManager: failed to encode priority configuration: \(error.localizedDescription)")
        }
    }

    // MARK: - Priority Evaluation

    /// Evaluate the priority of a notification based on category and context
    public func evaluatePriority(
        category: NotificationCategory,
        context: PriorityContext
    ) -> NotificationPriority {
        // Check if category is muted
        if configuration.mutedCategories.contains(category) {
            return .silent
        }

        // Check Do Not Disturb mode
        if configuration.doNotDisturbEnabled, !context.isUrgent {
            if isInDoNotDisturbPeriod() {
                return configuration.doNotDisturbAllowUrgent && context.isUrgent ? .high : .silent
            }
        }

        // Check focus mode overrides
        if let focusMode = configuration.currentFocusMode,
           let override = configuration.focusModeOverrides[focusMode]?[category]
        {
            return override
        }

        // Get base priority for category
        let basePriority = configuration.categoryPriorities[category] ?? .normal

        // Apply context modifiers
        return applyContextModifiers(basePriority: basePriority, context: context)
    }

    /// Check if we should send a notification based on priority
    public func shouldNotify(priority: NotificationPriority) -> Bool {
        switch priority {
        case .critical:
            true
        case .high:
            configuration.allowHighPriority
        case .normal:
            configuration.allowNormalPriority
        case .low:
            configuration.allowLowPriority
        case .silent:
            false
        }
    }

    // MARK: - Do Not Disturb

    private func isInDoNotDisturbPeriod() -> Bool {
        guard let startHour = configuration.doNotDisturbStartHour,
              let endHour = configuration.doNotDisturbEndHour
        else {
            return false
        }

        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)

        if startHour < endHour {
            return hour >= startHour && hour < endHour
        } else {
            // Spans midnight
            return hour >= startHour || hour < endHour
        }
    }

    // MARK: - Focus Mode

    /// Set the current focus mode
    public func setFocusMode(_ mode: SystemFocusMode?) {
        configuration.currentFocusMode = mode
    }

    /// Add a focus mode override for a category
    public func setFocusModeOverride(
        mode: SystemFocusMode,
        category: NotificationCategory,
        priority: NotificationPriority
    ) {
        if configuration.focusModeOverrides[mode] == nil {
            configuration.focusModeOverrides[mode] = [:]
        }
        configuration.focusModeOverrides[mode]?[category] = priority
    }

    // MARK: - Category Management

    /// Mute a category
    public func muteCategory(_ category: NotificationCategory) {
        configuration.mutedCategories.insert(category)
    }

    /// Unmute a category
    public func unmuteCategory(_ category: NotificationCategory) {
        configuration.mutedCategories.remove(category)
    }

    /// Set priority for a category
    public func setCategoryPriority(_ category: NotificationCategory, priority: NotificationPriority) {
        configuration.categoryPriorities[category] = priority
    }

    // MARK: - Context Modifiers

    private func applyContextModifiers(
        basePriority: NotificationPriority,
        context: PriorityContext
    ) -> NotificationPriority {
        var priority = basePriority

        // Urgent context boosts priority
        if context.isUrgent {
            priority = min(.critical, priority.boosted)
        }

        // Time-sensitive context boosts priority
        if context.isTimeSensitive {
            priority = min(.high, priority.boosted)
        }

        // Repeated context (multiple notifications) may reduce priority
        if context.repeatCount > configuration.repeatThreshold {
            priority = priority.reduced
        }

        return priority
    }

    // MARK: - Reset

    public func resetToDefaults() {
        configuration = PriorityConfiguration()
    }
}

// MARK: - Priority Configuration

public struct PriorityConfiguration: Codable, Sendable, Equatable {
    /// Priority level per category
    public var categoryPriorities: [NotificationCategory: NotificationPriority] = [
        .general: .normal,
        .aiTask: .normal,
        .aiResponse: .normal,
        .reminder: .high,
        .sync: .low,
        .health: .normal,
        .financial: .high,
        .system: .normal,
        .error: .high,
        .achievement: .low
    ]

    /// Muted categories (won't notify)
    public var mutedCategories: Set<NotificationCategory> = []

    /// Allow different priority levels
    public var allowHighPriority: Bool = true
    public var allowNormalPriority: Bool = true
    public var allowLowPriority: Bool = true

    /// Do Not Disturb settings
    public var doNotDisturbEnabled: Bool = false
    public var doNotDisturbStartHour: Int?
    public var doNotDisturbEndHour: Int?
    public var doNotDisturbAllowUrgent: Bool = true

    /// Current focus mode (if any)
    public var currentFocusMode: SystemFocusMode?

    /// Focus mode category overrides
    public var focusModeOverrides: [SystemFocusMode: [NotificationCategory: NotificationPriority]] = [
        .work: [
            .achievement: .silent,
            .health: .low,
            .aiResponse: .normal
        ],
        .personal: [
            .aiTask: .low,
            .financial: .normal
        ],
        .sleep: [
            .general: .silent,
            .aiTask: .silent,
            .aiResponse: .silent,
            .sync: .silent,
            .achievement: .silent
        ]
    ]

    /// Repeat threshold before reducing priority
    public var repeatThreshold: Int = 3

    public init() {}
}

// MARK: - Notification Priority

public enum NotificationPriority: Int, Codable, Sendable, CaseIterable, Comparable {
    case silent = 0
    case low = 1
    case normal = 2
    case high = 3
    case critical = 4

    public static func < (lhs: NotificationPriority, rhs: NotificationPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var displayName: String {
        switch self {
        case .silent: "Silent"
        case .low: "Low"
        case .normal: "Normal"
        case .high: "High"
        case .critical: "Critical"
        }
    }

    public var icon: String {
        switch self {
        case .silent: "speaker.slash"
        case .low: "speaker"
        case .normal: "speaker.wave.1"
        case .high: "speaker.wave.2"
        case .critical: "speaker.wave.3"
        }
    }

    /// Get boosted priority
    public var boosted: NotificationPriority {
        NotificationPriority(rawValue: Swift.min(rawValue + 1, NotificationPriority.critical.rawValue)) ?? .critical
    }

    /// Get reduced priority
    public var reduced: NotificationPriority {
        NotificationPriority(rawValue: Swift.max(rawValue - 1, NotificationPriority.silent.rawValue)) ?? .silent
    }
}

// MARK: - Priority Context

public struct PriorityContext: Sendable {
    public var isUrgent: Bool
    public var isTimeSensitive: Bool
    public var repeatCount: Int
    public var source: String?

    public init(
        isUrgent: Bool = false,
        isTimeSensitive: Bool = false,
        repeatCount: Int = 0,
        source: String? = nil
    ) {
        self.isUrgent = isUrgent
        self.isTimeSensitive = isTimeSensitive
        self.repeatCount = repeatCount
        self.source = source
    }

    public static let `default` = PriorityContext()
    public static let urgent = PriorityContext(isUrgent: true)
    public static let timeSensitive = PriorityContext(isTimeSensitive: true)
}

// MARK: - System Focus Mode

public enum SystemFocusMode: String, Codable, Sendable, CaseIterable {
    case work
    case personal
    case sleep
    case fitness
    case reading
    case driving

    public var displayName: String {
        switch self {
        case .work: "Work"
        case .personal: "Personal"
        case .sleep: "Sleep"
        case .fitness: "Fitness"
        case .reading: "Reading"
        case .driving: "Driving"
        }
    }

    public var icon: String {
        switch self {
        case .work: "briefcase"
        case .personal: "person"
        case .sleep: "moon"
        case .fitness: "figure.run"
        case .reading: "book"
        case .driving: "car"
        }
    }
}
