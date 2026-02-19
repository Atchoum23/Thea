// ProactiveNotificationIntelligence.swift
// Thea V2 - Proactive Notification Intelligence
//
// Intelligently manages when and how to notify users proactively
// Implements 2026 best practices for non-intrusive AI assistance

import Foundation
import OSLog

// MARK: - Proactive Notification Intelligence

/// Manages intelligent proactive notifications based on user context and preferences
@MainActor
@Observable
public final class ProactiveNotificationIntelligence {
    private let logger = Logger(subsystem: "app.thea.notifications", category: "ProactiveNotification")

    // MARK: - Configuration

    public var configuration = NotificationConfiguration()

    // MARK: - State

    /// Recent notifications sent
    public private(set) var recentNotifications: [SentNotification] = []

    /// Notification effectiveness scores by type
    public private(set) var effectivenessScores: [String: Double] = [:]

    /// Current notification budget remaining
    public private(set) var notificationBudget: Int = 10

    // MARK: - Private State

    private var interactionHistory: [NotificationInteraction] = []
    private let maxHistorySize = 500

    // MARK: - Public API

    /// Determine if a notification should be sent
    public func shouldNotify(
        type: NotificationType,
        priority: ProactiveNotificationPriority,
        context: AmbientContext
    ) -> NotificationDecision {
        // Check budget
        guard notificationBudget > 0 else {
            return .suppress(reason: "Daily notification budget exhausted")
        }

        // Check if user is in a state where interruption is inappropriate
        if context.isInMeeting && priority != .critical {
            return .postpone(until: estimateMeetingEnd(context: context))
        }

        if context.isResting && priority != .critical {
            return .suppress(reason: "User is resting")
        }

        // Check notification frequency
        let recentCount = countRecentNotifications(ofType: type, within: .minutes(30))
        if recentCount >= configuration.maxNotificationsPerHalfHour {
            return .postpone(until: Date().addingTimeInterval(1800))
        }

        // Check effectiveness history
        let effectiveness = effectivenessScores[type.rawValue] ?? 0.5
        if effectiveness < configuration.minEffectivenessThreshold && priority != .critical {
            return .suppress(reason: "Low historical effectiveness for this type")
        }

        // Determine delivery method
        let method = determineDeliveryMethod(priority: priority, context: context)

        return .allow(method: method)
    }

    /// Record that a notification was sent
    public func recordNotificationSent(
        type: NotificationType,
        priority: ProactiveNotificationPriority,
        content: String
    ) {
        let notification = SentNotification(
            type: type,
            priority: priority,
            content: content,
            sentAt: Date()
        )
        recentNotifications.append(notification)

        // Trim old notifications
        let cutoff = Date().addingTimeInterval(-86400) // 24 hours
        recentNotifications.removeAll { $0.sentAt < cutoff }

        // Decrement budget
        notificationBudget -= 1

        logger.debug("Notification sent: \(type.rawValue), budget remaining: \(self.notificationBudget)")
    }

    /// Record user interaction with a notification
    public func recordInteraction(_ interaction: NotificationInteraction) {
        interactionHistory.append(interaction)

        // Trim old history
        if interactionHistory.count > maxHistorySize {
            interactionHistory.removeFirst(interactionHistory.count - maxHistorySize)
        }

        // Update effectiveness scores
        updateEffectivenessScores()
    }

    /// Learn from user interaction feedback
    public func learnFromInteraction(_ feedback: AnticipationFeedback) {
        // Find associated notification
        guard let notification = recentNotifications.first(where: { $0.id == feedback.anticipationId }) else {
            return
        }

        let interaction = NotificationInteraction(
            notificationId: notification.id,
            type: notification.type,
            action: feedback.wasAccepted ? .acted : .dismissed,
            responseTime: Date().timeIntervalSince(notification.sentAt),
            wasHelpful: feedback.wasHelpful
        )

        recordInteraction(interaction)
    }

    /// Reset daily notification budget
    public func resetDailyBudget() {
        notificationBudget = configuration.dailyBudget
        logger.info("Notification budget reset to \(self.notificationBudget)")
    }

    // MARK: - Private Methods

    private func countRecentNotifications(ofType type: NotificationType, within interval: Duration) -> Int {
        let cutoff = Date().addingTimeInterval(-interval.timeInterval)
        return recentNotifications.filter { $0.type == type && $0.sentAt > cutoff }.count
    }

    // periphery:ignore - Reserved: context parameter kept for API compatibility
    private func estimateMeetingEnd(context: AmbientContext) -> Date {
        // Default to 30 minutes from now
        Date().addingTimeInterval(1800)
    }

    private func determineDeliveryMethod(
        priority: ProactiveNotificationPriority,
        context: AmbientContext
    ) -> DeliveryMethod {
        switch priority {
        case .critical:
            return .immediate
        case .high:
            return context.activityLevel > 0.7 ? .quiet : .standard
        case .normal:
            return context.activityLevel > 0.5 ? .batched : .standard
        case .low:
            return .batched
        }
    }

    private func updateEffectivenessScores() {
        // Group interactions by type
        var typeInteractions: [String: [NotificationInteraction]] = [:]

        for interaction in interactionHistory {
            let key = interaction.type.rawValue
            typeInteractions[key, default: []].append(interaction)
        }

        // Calculate effectiveness for each type
        for (typeKey, interactions) in typeInteractions {
            let actedCount = interactions.filter { $0.action == .acted }.count
            let totalCount = interactions.count

            guard totalCount >= 5 else { continue } // Need minimum samples

            let effectiveness = Double(actedCount) / Double(totalCount)
            effectivenessScores[typeKey] = effectiveness
        }
    }
}

// MARK: - Supporting Types

public struct NotificationConfiguration: Sendable {
    /// Maximum notifications per 30-minute window
    public var maxNotificationsPerHalfHour: Int = 3

    /// Daily notification budget
    public var dailyBudget: Int = 20

    /// Minimum effectiveness score to continue notifications of a type
    public var minEffectivenessThreshold: Double = 0.2

    /// Hours during which notifications are allowed
    public var quietHoursStart: Int = 22 // 10 PM
    public var quietHoursEnd: Int = 7    // 7 AM

    public init() {}
}

public enum NotificationType: String, Sendable {
    case suggestion = "suggestion"
    case reminder = "reminder"
    case contextUpdate = "context_update"
    case taskComplete = "task_complete"
    case proactiveInsight = "proactive_insight"
    case systemAlert = "system_alert"
}

public enum ProactiveNotificationPriority: String, Sendable, Comparable {
    case low
    case normal
    case high
    case critical

    public static func < (lhs: ProactiveNotificationPriority, rhs: ProactiveNotificationPriority) -> Bool {
        let order: [ProactiveNotificationPriority] = [.low, .normal, .high, .critical]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else { return false }
        return lhsIndex < rhsIndex
    }
}

public enum NotificationDecision: Sendable {
    case allow(method: DeliveryMethod)
    case postpone(until: Date)
    case suppress(reason: String)

    public var shouldSend: Bool {
        if case .allow = self { return true }
        return false
    }
}

public enum DeliveryMethod: String, Sendable {
    case immediate    // Show right away with sound/haptic
    case standard     // Show right away, no sound
    case quiet        // Show in notification center only
    case batched      // Group with other notifications
}

public struct SentNotification: Identifiable, Sendable {
    public let id: UUID
    public let type: NotificationType
    public let priority: ProactiveNotificationPriority
    public let content: String
    public let sentAt: Date

    public init(type: NotificationType, priority: ProactiveNotificationPriority, content: String, sentAt: Date) {
        self.id = UUID()
        self.type = type
        self.priority = priority
        self.content = content
        self.sentAt = sentAt
    }
}

public struct NotificationInteraction: Sendable {
    public let notificationId: UUID
    public let type: NotificationType
    public let action: InteractionAction
    public let responseTime: TimeInterval
    public let wasHelpful: Bool?

    public enum InteractionAction: String, Sendable {
        case acted      // User acted on the notification
        case dismissed  // User dismissed without acting
        case ignored    // User didn't interact (timed out)
        case expanded   // User expanded for more details
    }

    public init(
        notificationId: UUID,
        type: NotificationType,
        action: InteractionAction,
        responseTime: TimeInterval,
        wasHelpful: Bool? = nil
    ) {
        self.notificationId = notificationId
        self.type = type
        self.action = action
        self.responseTime = responseTime
        self.wasHelpful = wasHelpful
    }
}

// MARK: - Duration Extension

private extension Duration {
    var timeInterval: TimeInterval {
        let components = self.components
        return Double(components.seconds) + Double(components.attoseconds) / 1e18
    }

    static func minutes(_ minutes: Int) -> Duration {
        .seconds(minutes * 60)
    }
}
