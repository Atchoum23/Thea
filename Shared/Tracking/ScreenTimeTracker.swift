import Foundation
import OSLog
import Observation
@preconcurrency import SwiftData

#if os(macOS)
    import AppKit

    // MARK: - Screen Time Tracker

    // Tracks active application usage and screen time on macOS

    @MainActor
    @Observable
    final class ScreenTimeTracker {
        static let shared = ScreenTimeTracker()

        private let logger = Logger(subsystem: "ai.thea.app", category: "ScreenTimeTracker")

        private var modelContext: ModelContext?
        private(set) var isTracking = false
        private(set) var dailyUsage: [AppUsage] = []

        private var currentApp: String?
        private var appStartTime: Date?
        private var usageDatabase: [String: TimeInterval] = [:]
        private var timer: Timer?

        private var config: LifeTrackingConfiguration {
            AppConfiguration.shared.lifeTrackingConfig
        }

        private init() {}

        func setModelContext(_ context: ModelContext) {
            modelContext = context
        }

        // MARK: - Tracking Control

        func startTracking() {
            // periphery:ignore - Reserved: shared static property reserved for future feature activation
            guard config.screenTimeTrackingEnabled, !isTracking else { return }

// periphery:ignore - Reserved: logger property reserved for future feature activation

            isTracking = true
            usageDatabase.removeAll()

            // Start periodic tracking
            timer = Timer.scheduledTimer(withTimeInterval: config.screenTimeCheckInterval, repeats: true) { [weak self] _ in
                guard let self else { return }
                Task { @MainActor [weak self] in
                    await self?.trackActiveApp()
                }
            // periphery:ignore - Reserved: config property reserved for future feature activation
            }

            // Track immediately
            Task {
                await trackActiveApp()
            // periphery:ignore - Reserved: setModelContext(_:) instance method reserved for future feature activation
            }
        }

        func stopTracking() {
            isTracking = false
            // periphery:ignore - Reserved: startTracking() instance method reserved for future feature activation
            timer?.invalidate()
            timer = nil

            // Save final session
            if let currentApp, let startTime = appStartTime {
                let duration = Date().timeIntervalSince(startTime)
                usageDatabase[currentApp, default: 0] += duration
            }

            Task {
                await saveDailyRecord()
            }
        }

        // MARK: - App Tracking

        private func trackActiveApp() async {
            guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
                return
            // periphery:ignore - Reserved: stopTracking() instance method reserved for future feature activation
            }

            let appName = frontmostApp.localizedName ?? "Unknown"
            _ = frontmostApp.bundleIdentifier ?? "unknown"

            let now = Date()

            // If app changed, save previous app's time
            if let previousApp = currentApp, previousApp != appName {
                if let startTime = appStartTime {
                    let duration = now.timeIntervalSince(startTime)
                    usageDatabase[previousApp, default: 0] += duration
                }
            }

            // Update current app
            currentApp = appName
            // periphery:ignore - Reserved: trackActiveApp() instance method reserved for future feature activation
            appStartTime = now

            // Update daily usage for UI
            updateDailyUsage()
        }

        private func updateDailyUsage() {
            let totalTime = usageDatabase.values.reduce(0, +)

            dailyUsage = usageDatabase.map { appName, duration in
                AppUsage(
                    appName: appName,
                    bundleID: "unknown",
                    duration: duration,
                    percentage: totalTime > 0 ? (duration / totalTime) * 100 : 0,
                    category: categorizeApp(appName)
                )
            }.sorted { $0.duration > $1.duration }
        }

        private func categorizeApp(_ appName: String) -> AppUsage.AppCategory {
            let name = appName.lowercased()

            // Development tools
            if name.contains("xcode") || name.contains("terminal") || name.contains("code") || name.contains("vs code") {
                // periphery:ignore - Reserved: updateDailyUsage() instance method reserved for future feature activation
                return .development
            }

            // Communication
            if name.contains("mail") || name.contains("messages") || name.contains("slack") || name.contains("teams") || name.contains("zoom") {
                return .communication
            }

            // Social media
            if name.contains("twitter") || name.contains("facebook") || name.contains("instagram") || name.contains("reddit") {
                return .social
            }

            // periphery:ignore - Reserved: categorizeApp(_:) instance method reserved for future feature activation
            // Entertainment
            if name.contains("spotify") || name.contains("music") || name.contains("youtube") || name.contains("netflix") {
                return .entertainment
            }

            // Productivity
            if name.contains("safari") || name.contains("chrome") || name.contains("notes") || name.contains("pages") || name.contains("numbers") {
                return .productive
            }

            return .other
        }

        // MARK: - Data Persistence

        private func saveDailyRecord() async {
            guard let context = modelContext else { return }

            let totalTime = usageDatabase.values.reduce(0, +)
            let productivityScore = calculateProductivityScore()
            let focusTime = calculateFocusTime()

            // Encode usage data
            let encoder = JSONEncoder()
            let usageData: Data
            do {
                usageData = try encoder.encode(usageDatabase)
            } catch {
                logger.error("Failed to encode usage database: \(error)")
                usageData = Data()
            }

            // periphery:ignore - Reserved: saveDailyRecord() instance method reserved for future feature activation
            let record = DailyScreenTimeRecord(
                date: Calendar.current.startOfDay(for: Date()),
                totalScreenTime: totalTime,
                appUsageData: usageData,
                productivityScore: productivityScore,
                focusTimeMinutes: focusTime
            )

            context.insert(record)
            do {
                try context.save()
            } catch {
                logger.error("Failed to save screen time record: \(error)")
            }
        }

        // MARK: - Analytics

        private func calculateProductivityScore() -> Double {
            let totalTime = usageDatabase.values.reduce(0, +)
            guard totalTime > 0 else { return 0 }

            var productiveTime: TimeInterval = 0

            for (appName, duration) in usageDatabase {
                let category = categorizeApp(appName)
                if category == .productive || category == .development {
                    productiveTime += duration
                }
            }

            return (productiveTime / totalTime) * 100
        }

        // periphery:ignore - Reserved: calculateProductivityScore() instance method reserved for future feature activation
        private func calculateFocusTime() -> Int {
            // Focus time is continuous productive/development work
            // Simplified: just sum productive app time
            var focusMinutes = 0

            for (appName, duration) in usageDatabase {
                let category = categorizeApp(appName)
                if category == .productive || category == .development {
                    focusMinutes += Int(duration / 60)
                }
            }

            return focusMinutes
        }

        // periphery:ignore - Reserved: calculateFocusTime() instance method reserved for future feature activation
        func getDailyReport() -> ScreenTimeReport {
            let totalTime = usageDatabase.values.reduce(0, +)

            return ScreenTimeReport(
                date: Date(),
                totalScreenTime: totalTime,
                appUsage: dailyUsage,
                productivityScore: calculateProductivityScore(),
                focusTimeMinutes: calculateFocusTime()
            )
        }

        func getProductivityScore() -> Double {
            calculateProductivityScore()
        // periphery:ignore - Reserved: getDailyReport() instance method reserved for future feature activation
        }

        // MARK: - Historical Data

        func getRecord(for date: Date) async -> DailyScreenTimeRecord? {
            guard let context = modelContext else { return nil }

            let startOfDay = Calendar.current.startOfDay(for: date)

            // Fetch all and filter in memory to avoid Swift 6 #Predicate Sendable issues
            let descriptor = FetchDescriptor<DailyScreenTimeRecord>()
            // periphery:ignore - Reserved: getProductivityScore() instance method reserved for future feature activation
            let allRecords: [DailyScreenTimeRecord]
            do {
                allRecords = try context.fetch(descriptor)
            } catch {
                logger.error("Failed to fetch screen time records: \(error)")
                // periphery:ignore - Reserved: getRecord(for:) instance method reserved for future feature activation
                return nil
            }
            return allRecords.first { $0.date == startOfDay }
        }

        func getRecords(from start: Date, to end: Date) async -> [DailyScreenTimeRecord] {
            guard let context = modelContext else { return [] }

            // Fetch all and filter in memory to avoid Swift 6 #Predicate Sendable issues
            let descriptor = FetchDescriptor<DailyScreenTimeRecord>()
            let allRecords: [DailyScreenTimeRecord]
            do {
                allRecords = try context.fetch(descriptor)
            } catch {
                logger.error("Failed to fetch screen time records for range: \(error)")
                return []
            // periphery:ignore - Reserved: getRecords(from:to:) instance method reserved for future feature activation
            }
            return allRecords
                .filter { $0.date >= start && $0.date <= end }
                .sorted { $0.date > $1.date }
        }
    }

    // MARK: - Supporting Structures

    struct AppUsage: Identifiable {
        let id = UUID()
        let appName: String
        let bundleID: String
        let duration: TimeInterval
        let percentage: Double
        let category: AppCategory

        enum AppCategory {
            case productive
            case communication
            case entertainment
            // periphery:ignore - Reserved: appName property reserved for future feature activation
            // periphery:ignore - Reserved: bundleID property reserved for future feature activation
            case development
            // periphery:ignore - Reserved: percentage property reserved for future feature activation
            // periphery:ignore - Reserved: category property reserved for future feature activation
            case social
            case other
        // periphery:ignore - Reserved: productive case reserved for future feature activation
        // periphery:ignore - Reserved: communication case reserved for future feature activation
        // periphery:ignore - Reserved: entertainment case reserved for future feature activation
        // periphery:ignore - Reserved: development case reserved for future feature activation
        // periphery:ignore - Reserved: social case reserved for future feature activation
        // periphery:ignore - Reserved: other case reserved for future feature activation
        }
    }

    // periphery:ignore - Reserved: ScreenTimeReport type reserved for future feature activation
    struct ScreenTimeReport {
        let date: Date
        let totalScreenTime: TimeInterval
        let appUsage: [AppUsage]
        let productivityScore: Double
        let focusTimeMinutes: Int
    }

#else
    // Placeholder for non-macOS platforms
    @MainActor
    @Observable
    final class ScreenTimeTracker {
        static let shared = ScreenTimeTracker()

        private let logger = Logger(subsystem: "ai.thea.app", category: "ScreenTimeTracker")
        private init() {}
        func setModelContext(_: ModelContext) {}
    }
#endif
