// AppUsageMonitor.swift
// Thea V2 - Comprehensive App Usage Monitoring
//
// Monitors ALL app interactions across devices:
// - App launches and time spent
// - Foreground/background transitions
// - Notification interactions
// - Widget usage
// - Keyboard/input activity per app
//
// Integrates with Screen Time API (iOS) and
// native APIs (macOS) for complete coverage.

import Combine
import Foundation
import os.log

#if os(iOS)
    @preconcurrency import DeviceActivity
    @preconcurrency import FamilyControls
    import UIKit
    import ManagedSettings
#endif

#if os(macOS)
    import AppKit
#endif

// MARK: - App Usage Monitor

/// Comprehensive app usage monitoring across all platforms
@MainActor
public final class AppUsageMonitor: ObservableObject {
    public static let shared = AppUsageMonitor()

    private let logger = Logger(subsystem: "ai.thea.app", category: "AppUsageMonitor")

    // MARK: - Published State

    @Published public private(set) var isMonitoring = false
    @Published public private(set) var currentApp: MonitoredAppInfo?
    @Published public private(set) var todayUsage: [AppUsageRecord] = []
    @Published public private(set) var appHistory: [AppSessionRecord] = []
    @Published public private(set) var todayStats: AppUsageStats = .empty

    // MARK: - Internal State

    private var currentSessionStart: Date?
    private var cancellables = Set<AnyCancellable>()
    private var appSwitchObserver: Any?
    private var sessionTimer: Timer?

    // MARK: - Categorization

    private let appCategories: [String: AppCategory] = [
        // Productivity
        "com.apple.mail": .productivity,
        "com.apple.Notes": .productivity,
        "com.apple.reminders": .productivity,
        "com.apple.iCal": .productivity,
        "com.microsoft.Outlook": .productivity,
        "com.microsoft.Word": .productivity,
        "com.microsoft.Excel": .productivity,
        "com.microsoft.Powerpoint": .productivity,
        "com.google.Gmail": .productivity,
        "notion.id": .productivity,
        "com.linear": .productivity,
        "com.figma.Desktop": .productivity,

        // Development
        "com.apple.dt.Xcode": .development,
        "com.microsoft.VSCode": .development,
        "com.sublimetext.4": .development,
        "com.jetbrains.intellij": .development,
        "com.googlecode.iterm2": .development,
        "com.apple.Terminal": .development,

        // Social
        "net.whatsapp.WhatsApp": .social,
        "com.facebook.Facebook": .social,
        "com.burbn.instagram": .social,
        "com.cardify.tinder": .social,
        "com.twitter.twitter": .social,
        "ph.telegra.Telegraph": .social,

        // Communication
        "com.apple.MobileSMS": .communication,
        "com.apple.FaceTime": .communication,
        "us.zoom.videomeetings": .communication,
        "com.microsoft.teams": .communication,
        "com.tinyspeck.slackmacgap": .communication,
        "com.hammerandchisel.discord": .communication,

        // Entertainment
        "com.apple.TV": .entertainment,
        "com.netflix.Netflix": .entertainment,
        "com.spotify.client": .entertainment,
        "com.apple.Music": .entertainment,
        "com.apple.podcasts": .entertainment,
        "tv.plex.plex-for-ios": .entertainment,
        "com.disney.disneyplus": .entertainment,
        "com.amazon.aiv.AIVApp": .entertainment,

        // Browsers
        "com.apple.Safari": .browser,
        "com.brave.Browser": .browser,
        "com.google.Chrome": .browser,
        "org.mozilla.firefox": .browser,
        "com.operasoftware.Opera": .browser,

        // Finance
        "com.apple.stocks": .finance,
        "com.robinhood.release": .finance,
        "com.coinbase.Coinbase": .finance,

        // Health & Fitness
        "com.apple.Health": .health,
        "com.apple.Fitness": .health,
        "com.strava": .health,

        // News & Reading
        "com.apple.news": .news,
        "com.nytimes.NYTimes": .news,
        "com.reddit.Reddit": .news,
        "com.hackernews": .news,

        // Utilities
        "com.apple.finder": .utility,
        "com.apple.systempreferences": .utility,
        "com.apple.AppStore": .utility,
        "com.apple.calculator": .utility,
        "com.apple.Photos": .utility
    ]

    // MARK: - Initialization

    private init() {
        logger.info("AppUsageMonitor initialized")
    }

    // MARK: - Lifecycle

    /// Start monitoring app usage
    public func start() async {
        guard !isMonitoring else { return }

        logger.info("Starting app usage monitoring...")

        #if os(iOS)
            await startIOSMonitoring()
        #elseif os(macOS)
            await startMacOSMonitoring()
        #endif

        // Start session timer (update every 10 seconds)
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateCurrentSession()
            }
        }

        isMonitoring = true
        logger.info("App usage monitoring started")
    }

    /// Stop monitoring
    public func stop() async {
        guard isMonitoring else { return }

        sessionTimer?.invalidate()
        sessionTimer = nil

        if let observer = appSwitchObserver {
            NotificationCenter.default.removeObserver(observer)
        }

        // End current session
        if let app = currentApp {
            endSession(for: app)
        }

        isMonitoring = false
        logger.info("App usage monitoring stopped")
    }

    // MARK: - iOS Monitoring

    #if os(iOS)
        private func startIOSMonitoring() async {
            // Request Screen Time authorization
            if #available(iOS 16.0, *) {
                do {
                    try await ScreenTimeObserver.shared.requestAuthorization()
                    ScreenTimeObserver.shared.startMonitoring()
                } catch {
                    logger.error("Screen Time authorization failed: \(error.localizedDescription)")
                }
            }

            // Monitor app state changes
            NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleAppBecameActive()
                }
            }

            NotificationCenter.default.addObserver(
                forName: UIApplication.willResignActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleAppWillResignActive()
                }
            }
        }

        private func handleAppBecameActive() {
            // On iOS, we track when THEA becomes active
            // For other apps, we rely on Screen Time data
            startSession(for: MonitoredAppInfo(
                bundleIdentifier: Bundle.main.bundleIdentifier ?? "unknown",
                name: "Thea",
                category: .productivity
            ))
        }

        private func handleAppWillResignActive() {
            if let app = currentApp {
                endSession(for: app)
            }
        }
    #endif

    // MARK: - macOS Monitoring

    #if os(macOS)
        private func startMacOSMonitoring() async {
            // Monitor frontmost application changes
            appSwitchObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                else { return }

                Task { @MainActor [weak self] in
                    self?.handleAppActivation(app)
                }
            }

            // Get initial frontmost app
            if let frontmost = NSWorkspace.shared.frontmostApplication {
                handleAppActivation(frontmost)
            }
        }

        private func handleAppActivation(_ app: NSRunningApplication) {
            let bundleId = app.bundleIdentifier ?? "unknown"
            let appName = app.localizedName ?? "Unknown"
            let category = appCategories[bundleId] ?? categorizeByName(appName)

            let appInfo = MonitoredAppInfo(
                bundleIdentifier: bundleId,
                name: appName,
                category: category
            )

            // End previous session
            if let current = currentApp, current.bundleIdentifier != bundleId {
                endSession(for: current)
            }

            // Start new session
            if currentApp?.bundleIdentifier != bundleId {
                startSession(for: appInfo)
            }
        }
    #endif

    // MARK: - Session Management

    private func startSession(for app: MonitoredAppInfo) {
        currentApp = app
        currentSessionStart = Date()

        logger.debug("Started session for: \(app.name)")
    }

    private func endSession(for app: MonitoredAppInfo) {
        guard let start = currentSessionStart else { return }

        let duration = Date().timeIntervalSince(start)

        // Only record sessions longer than 1 second
        guard duration >= 1 else { return }

        let session = AppSessionRecord(
            id: UUID(),
            app: app,
            startTime: start,
            endTime: Date(),
            duration: duration
        )

        // Add to history
        appHistory.insert(session, at: 0)

        // Trim history
        if appHistory.count > 1000 {
            appHistory = Array(appHistory.prefix(1000))
        }

        // Update today's usage
        updateTodayUsage(with: session)

        // Publish event
        publishAppUsage(session)

        currentApp = nil
        currentSessionStart = nil

        logger.debug("Ended session for \(app.name): \(Int(duration))s")
    }

    private func updateCurrentSession() {
        guard let app = currentApp, let start = currentSessionStart else { return }

        // Update duration for current session
        let duration = Date().timeIntervalSince(start)

        // Update stats every 10 seconds
        var stats = todayStats

        // Check if new day
        if !Calendar.current.isDateInToday(stats.date) {
            stats = .empty
        }

        stats.date = Date()
        todayStats = stats
    }

    private func updateTodayUsage(with session: AppSessionRecord) {
        // Check if we have an existing record for this app today
        if let index = todayUsage.firstIndex(where: {
            $0.app.bundleIdentifier == session.app.bundleIdentifier
        }) {
            todayUsage[index].totalDuration += session.duration
            todayUsage[index].sessionCount += 1
        } else {
            todayUsage.append(AppUsageRecord(
                app: session.app,
                totalDuration: session.duration,
                sessionCount: 1,
                date: Date()
            ))
        }

        // Sort by duration (most used first)
        todayUsage.sort { $0.totalDuration > $1.totalDuration }

        // Update today stats
        var stats = todayStats

        if !Calendar.current.isDateInToday(stats.date) {
            stats = .empty
        }

        stats.totalScreenTime += session.duration
        stats.appSwitches += 1
        stats.categoryBreakdown[session.app.category, default: 0] += session.duration
        stats.date = Date()

        todayStats = stats
    }

    // MARK: - Categorization

    private func categorizeByName(_ name: String) -> AppCategory {
        let lowercased = name.lowercased()

        if lowercased.contains("mail") || lowercased.contains("outlook") ||
            lowercased.contains("calendar") || lowercased.contains("notes") ||
            lowercased.contains("reminder")
        {
            return .productivity
        }

        if lowercased.contains("code") || lowercased.contains("studio") ||
            lowercased.contains("terminal") || lowercased.contains("xcode")
        {
            return .development
        }

        if lowercased.contains("chat") || lowercased.contains("messenger") ||
            lowercased.contains("whatsapp") || lowercased.contains("telegram")
        {
            return .social
        }

        if lowercased.contains("safari") || lowercased.contains("chrome") ||
            lowercased.contains("firefox") || lowercased.contains("brave")
        {
            return .browser
        }

        if lowercased.contains("music") || lowercased.contains("spotify") ||
            lowercased.contains("netflix") || lowercased.contains("video") ||
            lowercased.contains("youtube")
        {
            return .entertainment
        }

        return .other
    }

    // MARK: - Event Publishing

    private func publishAppUsage(_ session: AppSessionRecord) {
        let event = LifeEvent(
            type: .appSwitch,
            source: .appUsage,
            summary: "Used \(session.app.name) for \(formatDuration(session.duration))",
            data: [
                "bundleId": session.app.bundleIdentifier,
                "appName": session.app.name,
                "category": session.app.category.rawValue,
                "durationSeconds": String(Int(session.duration))
            ],
            significance: session.duration > 300 ? .moderate : .minor
        )

        LifeMonitoringCoordinator.shared.submitEvent(event)
    }

    // MARK: - Analytics

    /// Get usage statistics for a time period
    public func getStats(for period: StatsPeriod) -> AppUsageStats {
        let cutoff: Date
        switch period {
        case .today:
            cutoff = Calendar.current.startOfDay(for: Date())
        case .week:
            cutoff = Date().addingTimeInterval(-7 * 24 * 3600)
        case .month:
            cutoff = Date().addingTimeInterval(-30 * 24 * 3600)
        }

        let relevantSessions = appHistory.filter { $0.startTime >= cutoff }

        var stats = AppUsageStats.empty

        for session in relevantSessions {
            stats.totalScreenTime += session.duration
            stats.appSwitches += 1
            stats.categoryBreakdown[session.app.category, default: 0] += session.duration
        }

        // Calculate productivity score
        let productiveTime = (stats.categoryBreakdown[.productivity] ?? 0) +
            (stats.categoryBreakdown[.development] ?? 0)
        let distractionTime = (stats.categoryBreakdown[.social] ?? 0) +
            (stats.categoryBreakdown[.entertainment] ?? 0)

        if stats.totalScreenTime > 0 {
            stats.productivityScore = productiveTime / stats.totalScreenTime
        }

        stats.date = Date()

        return stats
    }

    /// Get most used apps
    public func getTopApps(limit: Int = 10, period: StatsPeriod = .today) -> [AppUsageRecord] {
        let cutoff: Date
        switch period {
        case .today:
            cutoff = Calendar.current.startOfDay(for: Date())
        case .week:
            cutoff = Date().addingTimeInterval(-7 * 24 * 3600)
        case .month:
            cutoff = Date().addingTimeInterval(-30 * 24 * 3600)
        }

        let relevantSessions = appHistory.filter { $0.startTime >= cutoff }

        // Aggregate by app
        var appTotals: [String: (app: MonitoredAppInfo, duration: TimeInterval, sessions: Int)] = [:]

        for session in relevantSessions {
            let key = session.app.bundleIdentifier
            if var existing = appTotals[key] {
                existing.duration += session.duration
                existing.sessions += 1
                appTotals[key] = existing
            } else {
                appTotals[key] = (session.app, session.duration, 1)
            }
        }

        // Convert to records and sort
        return appTotals.values
            .map { AppUsageRecord(app: $0.app, totalDuration: $0.duration, sessionCount: $0.sessions, date: Date()) }
            .sorted { $0.totalDuration > $1.totalDuration }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "\(Int(seconds))s"
        }
    }

    public enum StatsPeriod {
        case today
        case week
        case month
    }
}

// MARK: - Supporting Types

/// App info for usage monitoring (prefixed to avoid conflict with AppIntegrationFramework.AppInfo)
public struct MonitoredAppInfo: Codable, Sendable, Equatable {
    public let bundleIdentifier: String
    public let name: String
    public let category: AppCategory

    public init(bundleIdentifier: String, name: String, category: AppCategory) {
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.category = category
    }
}

public enum AppCategory: String, Codable, CaseIterable, Sendable {
    case productivity
    case development
    case social
    case communication
    case entertainment
    case browser
    case finance
    case health
    case news
    case utility
    case games
    case education
    case travel
    case shopping
    case other

    public var displayName: String {
        rawValue.capitalized
    }

    public var isProductive: Bool {
        [.productivity, .development, .education].contains(self)
    }

    public var isDistraction: Bool {
        [.social, .entertainment, .games].contains(self)
    }
}

public struct AppSessionRecord: Identifiable, Sendable {
    public let id: UUID
    public let app: MonitoredAppInfo
    public let startTime: Date
    public let endTime: Date
    public let duration: TimeInterval
}

public struct AppUsageRecord: Identifiable, Sendable {
    public var id: String { app.bundleIdentifier }
    public let app: MonitoredAppInfo
    public var totalDuration: TimeInterval
    public var sessionCount: Int
    public let date: Date

    public var formattedDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

public struct AppUsageStats: Sendable {
    public var date: Date
    public var totalScreenTime: TimeInterval
    public var appSwitches: Int
    public var categoryBreakdown: [AppCategory: TimeInterval]
    public var productivityScore: Double

    public static var empty: AppUsageStats {
        AppUsageStats(
            date: Date(),
            totalScreenTime: 0,
            appSwitches: 0,
            categoryBreakdown: [:],
            productivityScore: 0
        )
    }

    public var formattedScreenTime: String {
        let hours = Int(totalScreenTime) / 3600
        let minutes = (Int(totalScreenTime) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
