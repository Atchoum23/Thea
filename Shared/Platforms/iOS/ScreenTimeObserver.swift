//
//  ScreenTimeObserver.swift
//  Thea
//
//  Created by Thea
//

#if os(iOS)
    @preconcurrency import DeviceActivity
    @preconcurrency import FamilyControls
    import Foundation
    import ManagedSettings
    import os.log

    /// Observes Screen Time data on iOS
    /// Provides insights into app usage patterns
    @available(iOS 16.0, *)
    @MainActor
    public final class ScreenTimeObserver: ObservableObject {
        public static let shared = ScreenTimeObserver()

        private let logger = Logger(subsystem: "app.thea.screentime", category: "ScreenTimeObserver")

        // Authorization status
        @Published public private(set) var isAuthorized = false

        // Usage data
        @Published public private(set) var todayUsage: ScreenTimeUsage?
        @Published public private(set) var weeklyUsage: [ScreenTimeUsage] = []

        // Activity center
        private let authorizationCenter = AuthorizationCenter.shared

        private init() {}

        // MARK: - Authorization

        /// Request Screen Time authorization
        public func requestAuthorization() async throws {
            do {
                try await authorizationCenter.requestAuthorization(for: .individual)
                isAuthorized = authorizationCenter.authorizationStatus == .approved
                logger.info("Screen Time authorization: \(self.isAuthorized)")
            } catch {
                logger.error("Screen Time authorization failed: \(error)")
                throw error
            }
        }

        /// Check current authorization status
        public var authorizationStatus: AuthorizationStatus {
            authorizationCenter.authorizationStatus
        }

        // MARK: - Usage Monitoring

        /// Start monitoring device activity
        public func startMonitoring() {
            guard isAuthorized else {
                logger.warning("Cannot start monitoring - not authorized")
                return
            }

            // Create a schedule for activity monitoring
            let schedule = DeviceActivitySchedule(
                intervalStart: DateComponents(hour: 0, minute: 0),
                intervalEnd: DateComponents(hour: 23, minute: 59),
                repeats: true
            )

            let center = DeviceActivityCenter()
            do {
                try center.startMonitoring(
                    DeviceActivityName("thea.daily"),
                    during: schedule
                )
                logger.info("Device activity monitoring started")
            } catch {
                logger.error("Failed to start monitoring: \(error)")
            }
        }

        /// Stop monitoring
        public func stopMonitoring() {
            let center = DeviceActivityCenter()
            center.stopMonitoring([DeviceActivityName("thea.daily")])
            logger.info("Device activity monitoring stopped")
        }

        // MARK: - Data Queries

        /// Get usage for a specific app
        public func getAppUsage(bundleIdentifier _: String) -> AppUsageInfo? {
            // In a real implementation, this would query the DeviceActivity framework
            // The actual usage data is available through activity reports
            nil
        }

        /// Get category usage summary
        public func getCategoryUsage() -> [CategoryUsageInfo] {
            // Return categorized usage data
            []
        }

        /// Check if app has exceeded limit
        public func isAppOverLimit(bundleIdentifier _: String) -> Bool {
            // Check if app has exceeded time limit
            false
        }
    }

    // MARK: - Data Models

    @available(iOS 16.0, *)
    public struct ScreenTimeUsage: Sendable {
        public let date: Date
        public let totalScreenTime: TimeInterval
        public let pickups: Int
        public let notifications: Int
        public let appUsage: [AppUsageInfo]
        public let categoryUsage: [CategoryUsageInfo]
    }

    @available(iOS 16.0, *)
    public struct AppUsageInfo: Identifiable, Sendable {
        public let id: String
        public let bundleIdentifier: String
        public let name: String
        public let duration: TimeInterval
        public let pickups: Int
        public let notifications: Int
        public let category: String?

        public var formattedDuration: String {
            let hours = Int(duration) / 3600
            let minutes = (Int(duration) % 3600) / 60

            if hours > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(minutes)m"
            }
        }
    }

    @available(iOS 16.0, *)
    public struct CategoryUsageInfo: Identifiable, Sendable {
        public let id: String
        public let name: String
        public let duration: TimeInterval
        public let appCount: Int
    }

    // MARK: - Device Activity Monitor Extension

    @available(iOS 16.0, *)
    public class TheaDeviceActivityMonitor: DeviceActivityMonitor {
        private let logger = Logger(subsystem: "app.thea.screentime", category: "DeviceActivityMonitor")

        override public func intervalDidStart(for activity: DeviceActivityName) {
            super.intervalDidStart(for: activity)
            logger.info("Activity interval started: \(activity.rawValue)")

            // Notify main app
            notifyMainApp(event: .intervalStarted, activity: activity)
        }

        override public func intervalDidEnd(for activity: DeviceActivityName) {
            super.intervalDidEnd(for: activity)
            logger.info("Activity interval ended: \(activity.rawValue)")

            // Notify main app
            notifyMainApp(event: .intervalEnded, activity: activity)
        }

        override public func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
            super.eventDidReachThreshold(event, activity: activity)
            logger.info("Event threshold reached: \(event.rawValue)")

            // Notify main app
            notifyMainApp(event: .thresholdReached, activity: activity)
        }

        override public func intervalWillStartWarning(for activity: DeviceActivityName) {
            super.intervalWillStartWarning(for: activity)
            logger.info("Interval will start warning: \(activity.rawValue)")
        }

        override public func intervalWillEndWarning(for activity: DeviceActivityName) {
            super.intervalWillEndWarning(for: activity)
            logger.info("Interval will end warning: \(activity.rawValue)")
        }

        private enum ActivityEvent: String {
            case intervalStarted
            case intervalEnded
            case thresholdReached
        }

        private func notifyMainApp(event: ActivityEvent, activity _: DeviceActivityName) {
            // Use Darwin notifications to notify main app
            let notificationName = CFNotificationName("app.thea.DeviceActivity.\(event.rawValue)" as CFString)
            CFNotificationCenterPostNotification(
                CFNotificationCenterGetDarwinNotifyCenter(),
                notificationName,
                nil,
                nil,
                true
            )
        }
    }
#endif
