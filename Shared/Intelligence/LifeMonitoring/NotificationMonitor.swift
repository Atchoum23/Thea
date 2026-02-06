//
//  NotificationMonitor.swift
//  Thea
//
//  Notification interaction monitoring for life tracking
//  Tracks notifications received and user interactions
//

import Combine
import Foundation
import os.log
#if canImport(UserNotifications)
    import UserNotifications
#endif
#if os(macOS)
    import AppKit
#endif

// MARK: - Notification Monitor

/// Monitors notifications and user interactions
/// Emits LifeEvents for notification delivery and actions
@MainActor
public class NotificationMonitor: NSObject, ObservableObject {
    public static let shared = NotificationMonitor()

    private let logger = Logger(subsystem: "ai.thea.app", category: "NotificationMonitor")

    @Published public private(set) var isRunning = false
    @Published public private(set) var todayNotificationCount = 0
    @Published public private(set) var todayInteractionCount = 0
    @Published public private(set) var notificationsByApp: [String: Int] = [:]

    private var notificationHistory: [NotificationRecord] = []
    private let maxHistorySize = 500

    override private init() {
        super.init()
    }

    // MARK: - Lifecycle

    /// Start monitoring notifications
    public func start() async {
        guard !isRunning else { return }

        #if canImport(UserNotifications)
            // Request notification authorization
            let center = UNUserNotificationCenter.current()

            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                if !granted {
                    logger.warning("Notification permission denied")
                }
            } catch {
                logger.error("Failed to request notification permission: \(error.localizedDescription)")
            }

            // Set delegate to track notifications
            center.delegate = self
        #endif

        #if os(macOS)
            // Observe distributed notification center for app notifications
            setupDistributedNotificationObserving()
        #endif

        isRunning = true
        logger.info("Notification monitor started")
    }

    /// Stop monitoring
    public func stop() async {
        guard isRunning else { return }

        isRunning = false

        #if canImport(UserNotifications)
            UNUserNotificationCenter.current().delegate = nil
        #endif

        logger.info("Notification monitor stopped")
    }

    // MARK: - macOS Distributed Notifications

    #if os(macOS)
        private func setupDistributedNotificationObserving() {
            // Observe system-wide notification center
            let center = DistributedNotificationCenter.default()

            // This observes notifications posted by other apps
            // Note: This requires specific entitlements and won't catch all notifications
            center.addObserver(
                self,
                selector: #selector(handleDistributedNotification(_:)),
                name: nil, // Observe all notifications
                object: nil,
                suspensionBehavior: .deliverImmediately
            )
        }

        @objc private func handleDistributedNotification(_ notification: Notification) {
            // Filter to only user-facing notifications
            let interestingPrefixes = [
                "com.apple.notification",
                "com.apple.UserNotificationCenter"
            ]

            let notificationName = notification.name.rawValue
            guard interestingPrefixes.contains(where: { notificationName.hasPrefix($0) }) else {
                return
            }

            Task { @MainActor in
                await recordNotification(
                    appIdentifier: notification.object as? String ?? "unknown",
                    title: nil,
                    body: nil,
                    category: nil
                )
            }
        }
    #endif

    // MARK: - Record Notifications

    /// Record a notification received
    public func recordNotification(
        appIdentifier: String,
        title: String?,
        body: String?,
        category: String?
    ) async {
        let record = NotificationRecord(
            appIdentifier: appIdentifier,
            title: title,
            body: body,
            category: category,
            timestamp: Date(),
            interacted: false,
            interactionType: nil
        )

        notificationHistory.append(record)
        if notificationHistory.count > maxHistorySize {
            notificationHistory.removeFirst()
        }

        // Update counts
        todayNotificationCount += 1
        notificationsByApp[appIdentifier, default: 0] += 1

        // Emit event
        await emitNotificationEvent(record, action: .received)
    }

    /// Record user interaction with a notification
    public func recordNotificationInteraction(
        appIdentifier: String,
        interactionType: NotificationInteractionType,
        actionIdentifier: String? = nil
    ) async {
        // Find and update the most recent notification from this app
        if let index = notificationHistory.lastIndex(where: { $0.appIdentifier == appIdentifier && !$0.interacted }) {
            notificationHistory[index].interacted = true
            notificationHistory[index].interactionType = interactionType
            notificationHistory[index].interactionTime = Date()
            notificationHistory[index].actionIdentifier = actionIdentifier

            todayInteractionCount += 1

            await emitNotificationEvent(notificationHistory[index], action: .interacted)
        }
    }

    private func emitNotificationEvent(_ record: NotificationRecord, action: MonitoredNotificationAction) async {
        let eventType: LifeEventType
        let significance: EventSignificance
        var summary: String

        switch action {
        case .received:
            eventType = .notificationReceived
            significance = .trivial
            summary = "Notification from \(appDisplayName(record.appIdentifier))"
            if let title = record.title {
                summary += ": \(title)"
            }
        case .interacted:
            eventType = .notificationInteracted
            significance = .minor
            summary = "Interacted with notification from \(appDisplayName(record.appIdentifier))"
        case .dismissed:
            eventType = .notificationDismissed
            significance = .trivial
            summary = "Dismissed notification from \(appDisplayName(record.appIdentifier))"
        }

        var eventData: [String: String] = [
            "appIdentifier": record.appIdentifier,
            "appName": appDisplayName(record.appIdentifier),
            "action": action.rawValue
        ]

        if let title = record.title {
            eventData["title"] = String(title.prefix(100))
        }

        if let category = record.category {
            eventData["category"] = category
        }

        if let interactionType = record.interactionType {
            eventData["interactionType"] = interactionType.rawValue
        }

        if let responseTime = record.responseTime {
            eventData["responseTimeSeconds"] = String(format: "%.1f", responseTime)
        }

        let lifeEvent = LifeEvent(
            type: eventType,
            source: .notifications,
            summary: summary,
            data: eventData,
            significance: significance
        )

        LifeMonitoringCoordinator.shared.submitEvent(lifeEvent)
        logger.debug("Notification \(action.rawValue): \(record.appIdentifier)")
    }

    private func appDisplayName(_ bundleId: String) -> String {
        #if os(macOS)
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId),
               let bundle = Bundle(url: url),
               let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            {
                return name
            }
        #endif

        // Fallback: extract app name from bundle ID
        let components = bundleId.components(separatedBy: ".")
        return components.last?.capitalized ?? bundleId
    }

    // MARK: - Query Methods

    /// Get notification statistics for today
    public func getTodayStatistics() -> NotificationStatistics {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let todayRecords = notificationHistory.filter { $0.timestamp >= startOfDay }

        let totalReceived = todayRecords.count
        let totalInteracted = todayRecords.filter(\.interacted).count

        // Calculate average response time
        let responseTimes = todayRecords.compactMap(\.responseTime)
        let averageResponseTime = responseTimes.isEmpty ? nil : responseTimes.reduce(0, +) / Double(responseTimes.count)

        // Count by app
        var countByApp: [String: Int] = [:]
        for record in todayRecords {
            countByApp[record.appIdentifier, default: 0] += 1
        }

        // Most notifications from
        let topApp = countByApp.max { $0.value < $1.value }

        return NotificationStatistics(
            totalReceived: totalReceived,
            totalInteracted: totalInteracted,
            interactionRate: totalReceived > 0 ? Double(totalInteracted) / Double(totalReceived) : 0,
            averageResponseTime: averageResponseTime,
            countByApp: countByApp,
            topAppIdentifier: topApp?.key,
            topAppCount: topApp?.value ?? 0
        )
    }

    /// Get recent notifications
    public func getRecentNotifications(limit: Int = 20) -> [NotificationRecord] {
        Array(notificationHistory.suffix(limit))
    }

    /// Get notifications from a specific app
    public func getNotifications(from appIdentifier: String) -> [NotificationRecord] {
        notificationHistory.filter { $0.appIdentifier == appIdentifier }
    }
}

// MARK: - UNUserNotificationCenterDelegate

#if canImport(UserNotifications)
    extension NotificationMonitor: UNUserNotificationCenterDelegate {
        nonisolated public func userNotificationCenter(
            _ center: UNUserNotificationCenter,
            willPresent notification: UNNotification
        ) async -> UNNotificationPresentationOptions {
            let request = notification.request
            let content = request.content

            // Record the notification
            await recordNotification(
                appIdentifier: request.content.threadIdentifier.isEmpty
                    ? "com.apple.unknown"
                    : request.content.threadIdentifier,
                title: content.title.isEmpty ? nil : content.title,
                body: content.body.isEmpty ? nil : content.body,
                category: content.categoryIdentifier.isEmpty ? nil : content.categoryIdentifier
            )

            // Allow the notification to be displayed
            return [.banner, .sound, .badge]
        }

        nonisolated public func userNotificationCenter(
            _ center: UNUserNotificationCenter,
            didReceive response: UNNotificationResponse
        ) async {
            let request = response.notification.request
            let actionIdentifier = response.actionIdentifier

            let interactionType: NotificationInteractionType
            switch actionIdentifier {
            case UNNotificationDefaultActionIdentifier:
                interactionType = .tapped
            case UNNotificationDismissActionIdentifier:
                interactionType = .dismissed
            default:
                interactionType = .customAction
            }

            await recordNotificationInteraction(
                appIdentifier: request.content.threadIdentifier.isEmpty
                    ? "com.apple.unknown"
                    : request.content.threadIdentifier,
                interactionType: interactionType,
                actionIdentifier: actionIdentifier
            )
        }
    }
#endif

// MARK: - Supporting Types

public struct NotificationRecord: Identifiable, Sendable {
    public let id = UUID()
    public let appIdentifier: String
    public let title: String?
    public let body: String?
    public let category: String?
    public let timestamp: Date
    public var interacted: Bool
    public var interactionType: NotificationInteractionType?
    public var interactionTime: Date?
    public var actionIdentifier: String?

    public var responseTime: TimeInterval? {
        guard let interaction = interactionTime else { return nil }
        return interaction.timeIntervalSince(timestamp)
    }
}

public enum NotificationInteractionType: String, Sendable {
    case tapped
    case dismissed
    case customAction = "custom_action"
    case replied
    case expanded
}

private enum MonitoredNotificationAction: String {
    case received
    case interacted
    case dismissed
}

public struct NotificationStatistics: Sendable {
    public let totalReceived: Int
    public let totalInteracted: Int
    public let interactionRate: Double
    public let averageResponseTime: TimeInterval?
    public let countByApp: [String: Int]
    public let topAppIdentifier: String?
    public let topAppCount: Int

    public var ignoredCount: Int {
        totalReceived - totalInteracted
    }
}

// MARK: - LifeEventType & DataSourceType
// Note: LifeEventType cases (notification*) and DataSourceType.notifications
// are defined in LifeMonitoringCoordinator.swift
