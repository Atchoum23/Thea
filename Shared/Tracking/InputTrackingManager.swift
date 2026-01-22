import Foundation
import Observation
@preconcurrency import SwiftData

#if os(macOS)
import AppKit
@preconcurrency import Carbon

// MARK: - Input Tracking Manager
// Tracks mouse and keyboard activity for activity level analysis

@MainActor
@Observable
final class InputTrackingManager {
    static let shared = InputTrackingManager()

    private var modelContext: ModelContext?
    private(set) var isTracking = false
    private(set) var dailyStats: InputStatistics?

    private var eventMonitor: Any?
    private var mouseClicks = 0
    private var keystrokes = 0
    private var mouseDistance: Double = 0
    private var lastMousePosition: CGPoint?
    private var activityStartTime: Date?
    private var lastActivityTime: Date?

    private var config: LifeTrackingConfiguration {
        AppConfiguration.shared.lifeTrackingConfig
    }

    private init() {}

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    // MARK: - Permission

    nonisolated func requestAccessibilityPermission() -> Bool {
        // Check if already trusted without showing prompt
        let isTrusted = AXIsProcessTrusted()
        if !isTrusted {
            // Show system prompt for accessibility access
            // Using string literal instead of kAXTrustedCheckOptionPrompt to avoid concurrency warnings
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        }
        return isTrusted
    }

    // MARK: - Tracking Control

    func startTracking() {
        guard config.inputTrackingEnabled, !isTracking else { return }

        guard requestAccessibilityPermission() else {
            print("Accessibility permission not granted")
            return
        }

        isTracking = true
        resetDailyStats()
        activityStartTime = Date()
        lastActivityTime = Date()

        // Monitor mouse and keyboard events
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown, .mouseMoved]) { [weak self] event in
            guard self != nil else { return }
            Task { @MainActor [weak self] in
                await self?.handleEvent(event)
            }
        }

        // Periodic save
        Timer.scheduledTimer(withTimeInterval: config.inputActivityCheckInterval, repeats: true) { [weak self] _ in
            guard self != nil else { return }
            Task { @MainActor [weak self] in
                await self?.saveCurrentStats()
            }
        }
    }

    func stopTracking() {
        isTracking = false

        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }

        Task {
            await saveCurrentStats()
        }
    }

    // MARK: - Event Handling

    private func handleEvent(_ event: NSEvent) async {
        let now = Date()
        lastActivityTime = now

        switch event.type {
        case .leftMouseDown, .rightMouseDown:
            mouseClicks += 1

        case .keyDown:
            keystrokes += 1

        case .mouseMoved:
            if let lastPos = lastMousePosition {
                let currentPos = NSEvent.mouseLocation
                let distance = sqrt(pow(currentPos.x - lastPos.x, 2) + pow(currentPos.y - lastPos.y, 2))
                mouseDistance += distance
            }
            lastMousePosition = NSEvent.mouseLocation

        default:
            break
        }

        updateDailyStats()
    }

    // MARK: - Statistics

    private func resetDailyStats() {
        mouseClicks = 0
        keystrokes = 0
        mouseDistance = 0
        lastMousePosition = nil
    }

    private func updateDailyStats() {
        let activeMinutes = calculateActiveMinutes()

        dailyStats = InputStatistics(
            date: Date(),
            mouseClicks: mouseClicks,
            keystrokes: keystrokes,
            mouseDistance: mouseDistance,
            activeMinutes: activeMinutes
        )
    }

    private func calculateActiveMinutes() -> Int {
        guard let startTime = activityStartTime else { return 0 }
        return Int(Date().timeIntervalSince(startTime) / 60)
    }

    // MARK: - Data Persistence

    private func saveCurrentStats() async {
        guard let context = modelContext, let stats = dailyStats else { return }

        let record = DailyInputStatistics(
            date: Calendar.current.startOfDay(for: Date()),
            mouseClicks: stats.mouseClicks,
            keystrokes: stats.keystrokes,
            mouseDistancePixels: stats.mouseDistance,
            activeMinutes: stats.activeMinutes,
            activityLevel: stats.activityLevel.rawValue
        )

        // Check if record exists - fetch all and filter to avoid Swift 6 #Predicate Sendable issues
        let targetDate = record.date
        let descriptor = FetchDescriptor<DailyInputStatistics>()
        let allRecords = (try? context.fetch(descriptor)) ?? []

        if let existing = allRecords.first(where: { $0.date == targetDate }) {
            existing.mouseClicks = record.mouseClicks
            existing.keystrokes = record.keystrokes
            existing.mouseDistancePixels = record.mouseDistancePixels
            existing.activeMinutes = record.activeMinutes
            existing.activityLevel = record.activityLevel
        } else {
            context.insert(record)
        }

        try? context.save()
    }

    // MARK: - Historical Data

    func getRecord(for date: Date) async -> DailyInputStatistics? {
        guard let context = modelContext else { return nil }

        let startOfDay = Calendar.current.startOfDay(for: date)

        // Fetch all and filter in memory to avoid Swift 6 #Predicate Sendable issues
        let descriptor = FetchDescriptor<DailyInputStatistics>()
        let allRecords = (try? context.fetch(descriptor)) ?? []
        return allRecords.first { $0.date == startOfDay }
    }

    func getRecords(from start: Date, to end: Date) async -> [DailyInputStatistics] {
        guard let context = modelContext else { return [] }

        // Fetch all and filter in memory to avoid Swift 6 #Predicate Sendable issues
        let descriptor = FetchDescriptor<DailyInputStatistics>()
        let allRecords = (try? context.fetch(descriptor)) ?? []
        return allRecords
            .filter { $0.date >= start && $0.date <= end }
            .sorted { $0.date > $1.date }
    }
}

// MARK: - Supporting Structures

struct InputStatistics {
    let date: Date
    let mouseClicks: Int
    let keystrokes: Int
    let mouseDistance: Double
    let activeMinutes: Int

    var activityLevel: ActivityLevel {
        // Calculate activity level based on inputs
        let clicksPerMinute = activeMinutes > 0 ? Double(mouseClicks) / Double(activeMinutes) : 0
        let keystrokesPerMinute = activeMinutes > 0 ? Double(keystrokes) / Double(activeMinutes) : 0

        let totalActivity = clicksPerMinute + keystrokesPerMinute

        if totalActivity < 10 {
            return .sedentary
        } else if totalActivity < 30 {
            return .light
        } else if totalActivity < 60 {
            return .moderate
        } else if totalActivity < 100 {
            return .high
        } else {
            return .veryHigh
        }
    }

    enum ActivityLevel: String {
        case sedentary = "Sedentary"
        case light = "Light"
        case moderate = "Moderate"
        case high = "High"
        case veryHigh = "Very High"
    }
}

#else
// Placeholder for non-macOS platforms
@MainActor
@Observable
final class InputTrackingManager {
    static let shared = InputTrackingManager()
    private init() {}
    func setModelContext(_ context: ModelContext) {}
}
#endif
