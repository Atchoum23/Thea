//
//  NotificationObserver.swift
//  Thea
//
//  Created by Thea
//

#if os(iOS)
    import Foundation
    import os.log
    @preconcurrency import UserNotifications

    /// Observes and analyzes notification patterns on iOS
    /// Tracks notification history and provides insights
    @MainActor
    public final class NotificationObserver: NSObject, ObservableObject {
        public static let shared = NotificationObserver()

        private let logger = Logger(subsystem: "app.thea.notifications", category: "NotificationObserver")

        // Notification center
        private let notificationCenter = UNUserNotificationCenter.current()

        // Authorization status
        @Published public private(set) var isAuthorized = false
        @Published public private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

        // Notification data
        @Published public private(set) var pendingNotifications: [TheaNotificationInfo] = []
        @Published public private(set) var deliveredNotifications: [TheaNotificationInfo] = []
        @Published public private(set) var notificationHistory: [TheaNotificationInfo] = []

        // Analytics
        @Published public private(set) var todayCount: Int = 0
        @Published public private(set) var topApps: [AppNotificationSummary] = []

        // Callbacks
        public var onNotificationReceived: ((TheaNotificationInfo) -> Void)?
        public var onNotificationPatternDetected: ((NotificationPattern) -> Void)?

        // Storage
        private let historyKey = "thea.notification.history"
        private let maxHistorySize = 500

        override private init() {
            super.init()
        }

        // MARK: - Authorization

        /// Request notification authorization
        public func requestAuthorization() async throws {
            do {
                let granted = try await notificationCenter.requestAuthorization(
                    options: [.alert, .badge, .sound, .provisional, .criticalAlert]
                )
                isAuthorized = granted
                logger.info("Notification authorization: \(granted)")
            } catch {
                logger.error("Notification authorization failed: \(error)")
                throw error
            }
        }

        /// Check current authorization status
        public func checkAuthorizationStatus() async {
            let settings = await notificationCenter.notificationSettings()
            authorizationStatus = settings.authorizationStatus
            isAuthorized = settings.authorizationStatus == .authorized ||
                settings.authorizationStatus == .provisional
        }

        // MARK: - Monitoring

        /// Start observing notifications
        public func startObserving() {
            notificationCenter.delegate = self
            loadHistory()
            refreshNotifications()

            logger.info("Notification observing started")
        }

        /// Stop observing
        public func stopObserving() {
            notificationCenter.delegate = nil
            logger.info("Notification observing stopped")
        }

        /// Refresh pending and delivered notifications
        public func refreshNotifications() {
            Task {
                await fetchPendingNotifications()
                await fetchDeliveredNotifications()
                updateAnalytics()
            }
        }

        private func fetchPendingNotifications() async {
            let requests = await notificationCenter.pendingNotificationRequests()
            pendingNotifications = requests.map { TheaNotificationInfo(from: $0) }
        }

        private func fetchDeliveredNotifications() async {
            let notifications = await notificationCenter.deliveredNotifications()
            deliveredNotifications = notifications.map { TheaNotificationInfo(from: $0) }
        }

        // MARK: - History Management

        private func loadHistory() {
            if let data = UserDefaults.standard.data(forKey: historyKey) {
            do {
                notificationHistory = try JSONDecoder().decode([TheaNotificationInfo].self, from: data)
            } catch {
                logger.error("Failed to decode notification history: \(error.localizedDescription)")
            }
        }
        }

        private func saveHistory() {
            let trimmedHistory = Array(notificationHistory.prefix(maxHistorySize))
            do {
                let data = try JSONEncoder().encode(trimmedHistory)
                UserDefaults.standard.set(data, forKey: historyKey)
            } catch {
                logger.error("Failed to encode notification history: \(error.localizedDescription)")
            }
        }

        private func recordNotification(_ notification: TheaNotificationInfo) {
            notificationHistory.insert(notification, at: 0)
            if notificationHistory.count > maxHistorySize {
                notificationHistory = Array(notificationHistory.prefix(maxHistorySize))
            }
            saveHistory()
            updateAnalytics()

            // Check for patterns
            detectPatterns(for: notification)

            onNotificationReceived?(notification)
        }

        // MARK: - Analytics

        private func updateAnalytics() {
            // Count today's notifications
            let startOfDay = Calendar.current.startOfDay(for: Date())
            todayCount = notificationHistory.count { $0.receivedAt >= startOfDay }

            // Calculate top apps
            var appCounts: [String: Int] = [:]
            for notification in notificationHistory {
                if let bundleID = notification.appBundleID {
                    appCounts[bundleID, default: 0] += 1
                }
            }

            topApps = appCounts
                .map { AppNotificationSummary(bundleID: $0.key, count: $0.value) }
                .sorted { $0.count > $1.count }
                .prefix(10)
                .map(\.self)
        }

        // MARK: - Pattern Detection

        private func detectPatterns(for notification: TheaNotificationInfo) {
            guard let bundleID = notification.appBundleID else { return }

            // Check for notification burst (many notifications from same app in short time)
            let recentFromApp = notificationHistory
                .prefix(20)
                .filter { $0.appBundleID == bundleID }
                .filter { $0.receivedAt > Date().addingTimeInterval(-300) } // Last 5 minutes

            if recentFromApp.count >= 5 {
                let pattern = NotificationPattern(
                    type: .burst,
                    appBundleID: bundleID,
                    count: recentFromApp.count,
                    timeWindow: 300,
                    message: "Received \(recentFromApp.count) notifications from \(bundleID) in 5 minutes"
                )
                onNotificationPatternDetected?(pattern)
            }

            // Check for repeated notifications (same content)
            let sameContent = notificationHistory
                .prefix(50)
                .filter { $0.title == notification.title && $0.body == notification.body }

            if sameContent.count >= 3 {
                let pattern = NotificationPattern(
                    type: .repeated,
                    appBundleID: bundleID,
                    count: sameContent.count,
                    message: "Repeated notification detected: \(notification.title ?? "Unknown")"
                )
                onNotificationPatternDetected?(pattern)
            }
        }

        // MARK: - Queries

        /// Get notifications for a specific app
        public func getNotifications(for bundleID: String) -> [TheaNotificationInfo] {
            notificationHistory.filter { $0.appBundleID == bundleID }
        }

        /// Get notifications within a time range
        public func getNotifications(from startDate: Date, to endDate: Date = Date()) -> [TheaNotificationInfo] {
            notificationHistory.filter { $0.receivedAt >= startDate && $0.receivedAt <= endDate }
        }

        /// Get notification frequency for an app
        public func getNotificationFrequency(for bundleID: String, days: Int = 7) -> Double {
            let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
            let count = notificationHistory.count {
                $0.appBundleID == bundleID && $0.receivedAt >= startDate
            }

            return Double(count) / Double(days)
        }

        /// Get quiet hours (hours with fewest notifications)
        public func getQuietHours() -> [Int] {
            var hourCounts: [Int: Int] = [:]

            for notification in notificationHistory {
                let hour = Calendar.current.component(.hour, from: notification.receivedAt)
                hourCounts[hour, default: 0] += 1
            }

            let sortedHours = hourCounts.sorted { $0.value < $1.value }
            return Array(sortedHours.prefix(3).map(\.key))
        }

        /// Get notification summary
        public var notificationSummary: NotificationSummary {
            NotificationSummary(
                totalToday: todayCount,
                pendingCount: pendingNotifications.count,
                deliveredCount: deliveredNotifications.count,
                topApps: topApps,
                quietHours: getQuietHours()
            )
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    extension NotificationObserver: UNUserNotificationCenterDelegate {
        nonisolated public func userNotificationCenter(
            _: UNUserNotificationCenter,
            willPresent notification: UNNotification
        ) async -> UNNotificationPresentationOptions {
            let info = TheaNotificationInfo(from: notification)

            await MainActor.run {
                self.recordNotification(info)
            }

            return [.banner, .badge, .sound]
        }

        nonisolated public func userNotificationCenter(
            _: UNUserNotificationCenter,
            didReceive response: UNNotificationResponse
        ) async {
            let info = TheaNotificationInfo(from: response.notification)

            await MainActor.run {
                self.logger.debug("User interacted with notification: \(info.title ?? "Unknown")")
            }
        }
    }

    // MARK: - Data Models

    public struct TheaNotificationInfo: Identifiable, Codable, Sendable {
        public let id: String
        public let title: String?
        public let subtitle: String?
        public let body: String?
        public let appBundleID: String?
        public let categoryIdentifier: String?
        public let threadIdentifier: String?
        public let receivedAt: Date
        public let badge: Int?
        public let sound: Bool

        init(from notification: UNNotification) {
            let content = notification.request.content
            id = notification.request.identifier
            title = content.title.isEmpty ? nil : content.title
            subtitle = content.subtitle.isEmpty ? nil : content.subtitle
            body = content.body.isEmpty ? nil : content.body
            appBundleID = content.targetContentIdentifier
            categoryIdentifier = content.categoryIdentifier.isEmpty ? nil : content.categoryIdentifier
            threadIdentifier = content.threadIdentifier.isEmpty ? nil : content.threadIdentifier
            receivedAt = notification.date
            badge = content.badge?.intValue
            sound = content.sound != nil
        }

        init(from request: UNNotificationRequest) {
            let content = request.content
            id = request.identifier
            title = content.title.isEmpty ? nil : content.title
            subtitle = content.subtitle.isEmpty ? nil : content.subtitle
            body = content.body.isEmpty ? nil : content.body
            appBundleID = content.targetContentIdentifier
            categoryIdentifier = content.categoryIdentifier.isEmpty ? nil : content.categoryIdentifier
            threadIdentifier = content.threadIdentifier.isEmpty ? nil : content.threadIdentifier
            receivedAt = Date()
            badge = content.badge?.intValue
            sound = content.sound != nil
        }
    }

    public struct AppNotificationSummary: Identifiable, Sendable {
        public var id: String { bundleID }
        public let bundleID: String
        public let count: Int

        public var appName: String {
            // In a real implementation, would resolve bundle ID to app name
            bundleID.components(separatedBy: ".").last ?? bundleID
        }
    }

    public struct NotificationPattern: Sendable {
        public let type: PatternType
        public let appBundleID: String?
        public let count: Int
        public let timeWindow: TimeInterval?
        public let message: String
        public let detectedAt: Date

        public enum PatternType: String, Sendable {
            case burst // Many notifications in short time
            case repeated // Same notification content
            case scheduled // Regular interval notifications
            case unusual // Outside normal patterns
        }

        init(
            type: PatternType,
            appBundleID: String? = nil,
            count: Int,
            timeWindow: TimeInterval? = nil,
            message: String
        ) {
            self.type = type
            self.appBundleID = appBundleID
            self.count = count
            self.timeWindow = timeWindow
            self.message = message
            detectedAt = Date()
        }
    }

    public struct NotificationSummary: Sendable {
        public let totalToday: Int
        public let pendingCount: Int
        public let deliveredCount: Int
        public let topApps: [AppNotificationSummary]
        public let quietHours: [Int]
        public let timestamp: Date

        init(
            totalToday: Int,
            pendingCount: Int,
            deliveredCount: Int,
            topApps: [AppNotificationSummary],
            quietHours: [Int]
        ) {
            self.totalToday = totalToday
            self.pendingCount = pendingCount
            self.deliveredCount = deliveredCount
            self.topApps = topApps
            self.quietHours = quietHours
            timestamp = Date()
        }

        public var formattedQuietHours: String {
            quietHours.map { hour in
                let formatter = DateFormatter()
                formatter.dateFormat = "ha"
                let date = Calendar.current.date(from: DateComponents(hour: hour))!
                return formatter.string(from: date)
            }.joined(separator: ", ")
        }
    }
#endif
