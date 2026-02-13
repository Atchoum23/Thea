import Foundation
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
            guard config.screenTimeTrackingEnabled, !isTracking else { return }

            isTracking = true
            usageDatabase.removeAll()

            // Start periodic tracking
            timer = Timer.scheduledTimer(withTimeInterval: config.screenTimeCheckInterval, repeats: true) { [weak self] _ in
                guard let self else { return }
                Task { @MainActor [weak self] in
                    await self?.trackActiveApp()
                }
            }

            // Track immediately
            Task {
                await trackActiveApp()
            }
        }

        func stopTracking() {
            isTracking = false
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
            let usageData = (try? encoder.encode(usageDatabase)) ?? Data()

            let record = DailyScreenTimeRecord(
                date: Calendar.current.startOfDay(for: Date()),
                totalScreenTime: totalTime,
                appUsageData: usageData,
                productivityScore: productivityScore,
                focusTimeMinutes: focusTime
            )

            context.insert(record)
            ErrorLogger.tryOrNil(context: "ScreenTimeTracker.save") { try context.save() }
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
        }

        // MARK: - Historical Data

        func getRecord(for date: Date) async -> DailyScreenTimeRecord? {
            guard let context = modelContext else { return nil }

            let startOfDay = Calendar.current.startOfDay(for: date)

            // Fetch all and filter in memory to avoid Swift 6 #Predicate Sendable issues
            let descriptor = FetchDescriptor<DailyScreenTimeRecord>()
            let allRecords = (try? context.fetch(descriptor)) ?? []
            return allRecords.first { $0.date == startOfDay }
        }

        func getRecords(from start: Date, to end: Date) async -> [DailyScreenTimeRecord] {
            guard let context = modelContext else { return [] }

            // Fetch all and filter in memory to avoid Swift 6 #Predicate Sendable issues
            let descriptor = FetchDescriptor<DailyScreenTimeRecord>()
            let allRecords = (try? context.fetch(descriptor)) ?? []
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
            case development
            case social
            case other
        }
    }

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
        private init() {}
        func setModelContext(_: ModelContext) {}
    }
#endif
