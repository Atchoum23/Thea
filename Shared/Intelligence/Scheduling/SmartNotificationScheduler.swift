// SmartNotificationScheduler.swift
// Thea — Behavioral Fingerprint-Driven Notification Timing
//
// Bridges BehavioralFingerprint (user patterns) with NotificationService.
// Determines the optimal time to deliver notifications based on:
//   - User's receptivity patterns (learned from engagement)
//   - Cognitive load at the target time
//   - Whether the user is likely awake
//   - Notification priority vs. optimal timing tradeoff

import Foundation
import OSLog

// MARK: - Smart Notification Scheduler

@MainActor
@Observable
final class SmartNotificationScheduler {
    static let shared = SmartNotificationScheduler()

    private let logger = Logger(subsystem: "com.thea.app", category: "SmartNotificationScheduler")

    // MARK: - Configuration

    /// Whether smart scheduling is enabled (user can turn off to get immediate delivery)
    var isEnabled = true

    /// Maximum delay allowed for non-urgent notifications (in hours)
    var maxDelayHours = 4

    /// Minimum receptivity threshold to deliver now (0.0-1.0)
    var receptivityThreshold = 0.3

    /// Priority levels that bypass smart scheduling entirely
    var bypassPriorities: Set<NotificationPriority> = [.critical]

    // MARK: - Statistics

    private(set) var scheduledCount = 0
    private(set) var immediateCount = 0
    private(set) var deferredCount = 0

    private init() {}

    // MARK: - Scheduling

    /// Determine the optimal delivery time for a notification.
    /// Returns `.now` for immediate delivery, or a future `Date` for deferred delivery.
    func optimalDeliveryTime(
        priority: NotificationPriority,
        category: NotificationService.Category? = nil
    ) -> DeliveryDecision {
        scheduledCount += 1

        // Bypass smart scheduling if disabled or critical
        guard isEnabled, !bypassPriorities.contains(priority) else {
            immediateCount += 1
            return .now(reason: "Smart scheduling disabled or priority bypass")
        }

        let fingerprint = BehavioralFingerprint.shared
        let context = fingerprint.currentContext()

        // Check if user is likely asleep
        if !context.isAwake {
            deferredCount += 1
            let wakeHour = fingerprint.typicalWakeTime
            let deferredDate = nextOccurrence(ofHour: wakeHour)
            return .deferred(
                until: deferredDate,
                reason: "User likely asleep — delivering at wake time"
            )
        }

        // High receptivity right now — deliver immediately
        if context.receptivity >= receptivityThreshold {
            immediateCount += 1
            return .now(reason: "Current receptivity \(String(format: "%.0f%%", context.receptivity * 100)) meets threshold")
        }

        // Low receptivity — find a better time within maxDelayHours
        let calendar = Calendar.current
        let now = Date()
        let weekday = (calendar.component(.weekday, from: now) + 5) % 7
        guard let currentDay = dayOfWeek(from: weekday) else {
            immediateCount += 1
            return .now(reason: "Could not determine day of week")
        }

        let currentHour = calendar.component(.hour, from: now)
        let maxHour = min(currentHour + maxDelayHours, fingerprint.typicalSleepTime)

        var bestHour = currentHour
        var bestReceptivity = context.receptivity

        for hour in (currentHour + 1)...maxHour {
            let hourReceptivity = fingerprint.receptivity(day: currentDay, hour: hour)
            if hourReceptivity > bestReceptivity {
                bestReceptivity = hourReceptivity
                bestHour = hour
            }
        }

        if bestHour == currentHour {
            immediateCount += 1
            return .now(reason: "No better time found within \(maxDelayHours)h window")
        }

        deferredCount += 1
        let deferredDate = nextOccurrence(ofHour: bestHour)
        return .deferred(
            until: deferredDate,
            reason: "Better receptivity at \(bestHour):00 (\(String(format: "%.0f%%", bestReceptivity * 100)) vs current \(String(format: "%.0f%%", context.receptivity * 100)))"
        )
    }

    /// Schedule a notification through NotificationService at the optimal time
    func scheduleOptimally(
        title: String,
        body: String,
        priority: NotificationPriority,
        category: NotificationService.Category? = nil
    ) async {
        let decision = optimalDeliveryTime(priority: priority, category: category)
        let service = NotificationService.shared

        switch decision {
        case .now:
            logger.info("Delivering immediately: \(title)")
            do {
                try await service.scheduleReminder(
                    title: title,
                    body: body,
                    at: Date()
                )
            } catch {
                logger.error("Failed to schedule notification: \(error.localizedDescription)")
            }

        case let .deferred(until, reason):
            logger.info("Deferring until \(until): \(title) — \(reason)")
            do {
                try await service.scheduleReminder(
                    title: title,
                    body: body,
                    at: until
                )
            } catch {
                logger.error("Failed to schedule deferred notification: \(error.localizedDescription)")
            }
        }

        // Record this as a notification sent for the fingerprint
        BehavioralFingerprint.shared.recordNotificationEngagement(engaged: false) // Will be updated when user engages
    }

    /// Record that the user engaged with a notification (opens, responds, etc.)
    func recordEngagement() {
        BehavioralFingerprint.shared.recordNotificationEngagement(engaged: true)
    }

    // MARK: - Helpers

    private func nextOccurrence(ofHour hour: Int) -> Date {
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = 0
        components.second = 0

        if let date = calendar.date(from: components), date > now {
            return date
        }

        // Tomorrow at that hour
        components.day = (components.day ?? 0) + 1
        return calendar.date(from: components) ?? now
    }

    private func dayOfWeek(from index: Int) -> DayOfWeek? {
        switch index {
        case 0: .monday
        case 1: .tuesday
        case 2: .wednesday
        case 3: .thursday
        case 4: .friday
        case 5: .saturday
        case 6: .sunday
        default: nil
        }
    }
}

// MARK: - Types

enum DeliveryDecision: Sendable {
    case now(reason: String)
    case deferred(until: Date, reason: String)

    var isImmediate: Bool {
        if case .now = self { return true }
        return false
    }
}
