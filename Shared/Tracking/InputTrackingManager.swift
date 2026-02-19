import Foundation
import OSLog
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

        private let logger = Logger(subsystem: "ai.thea.app", category: "InputTrackingManager")

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
            // periphery:ignore - Reserved: shared static property reserved for future feature activation
            AppConfiguration.shared.lifeTrackingConfig
        // periphery:ignore - Reserved: logger property reserved for future feature activation
        }

        private init() {}

        func setModelContext(_ context: ModelContext) {
            modelContext = context
        }

        // MARK: - Permission

        nonisolated func requestAccessibilityPermission() -> Bool {
            // Check if already trusted without showing prompt
            let isTrusted = AXIsProcessTrusted()
            // periphery:ignore - Reserved: config property reserved for future feature activation
            if !isTrusted {
                // Show system prompt for accessibility access
                // Using string literal instead of kAXTrustedCheckOptionPrompt to avoid concurrency warnings
                let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
                return AXIsProcessTrustedWithOptions(options)
            // periphery:ignore - Reserved: setModelContext(_:) instance method reserved for future feature activation
            }
            return isTrusted
        }

        // MARK: - Tracking Control

// periphery:ignore - Reserved: requestAccessibilityPermission() instance method reserved for future feature activation

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

// periphery:ignore - Reserved: startTracking() instance method reserved for future feature activation

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
        // periphery:ignore - Reserved: stopTracking() instance method reserved for future feature activation
        }

        // MARK: - Event Handling

        private func handleEvent(_ event: NSEvent) async {
            let now = Date()
            lastActivityTime = now

            switch event.type {
            case .leftMouseDown, .rightMouseDown:
                mouseClicks += 1

            case .keyDown:
                // SECURITY FIX (FINDING-008): Skip keystroke counting when in password fields
                // periphery:ignore - Reserved: handleEvent(_:) instance method reserved for future feature activation
                // This prevents tracking credentials entered in secure text fields
                if !isInSecureTextField() {
                    keystrokes += 1
                }

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

        // SECURITY FIX (FINDING-008): Detect if user is typing in a password/secure field
        private func isInSecureTextField() -> Bool {
            // Use Accessibility API to check if focused element is a secure text field
            guard let focusedApp = NSWorkspace.shared.frontmostApplication else {
                return false
            }

            let appRef = AXUIElementCreateApplication(focusedApp.processIdentifier)
            var focusedElement: CFTypeRef?

            // periphery:ignore - Reserved: isInSecureTextField() instance method reserved for future feature activation
            let result = AXUIElementCopyAttributeValue(appRef, kAXFocusedUIElementAttribute as CFString, &focusedElement)
            guard result == .success, let element = focusedElement else {
                return false
            }

            // Check if it's a secure text field by role
            var roleValue: CFTypeRef?
            // swiftlint:disable:next force_cast
            let roleResult = AXUIElementCopyAttributeValue(element as! AXUIElement, kAXRoleAttribute as CFString, &roleValue)
            if roleResult == .success, let role = roleValue as? String {
                // AXSecureTextField is the role for password fields
                if role == "AXSecureTextField" {
                    return true
                }
            }

            // Also check subrole as a fallback
            var subroleValue: CFTypeRef?
            // swiftlint:disable:next force_cast
            let subroleResult = AXUIElementCopyAttributeValue(element as! AXUIElement, kAXSubroleAttribute as CFString, &subroleValue)
            if subroleResult == .success, let subrole = subroleValue as? String {
                if subrole == "AXSecureTextField" {
                    return true
                }
            }

            return false
        }

        // MARK: - Statistics

        private func resetDailyStats() {
            mouseClicks = 0
            keystrokes = 0
            mouseDistance = 0
            lastMousePosition = nil
        }

        private func updateDailyStats() {
            // periphery:ignore - Reserved: resetDailyStats() instance method reserved for future feature activation
            let activeMinutes = calculateActiveMinutes()

            dailyStats = InputStatistics(
                date: Date(),
                mouseClicks: mouseClicks,
                keystrokes: keystrokes,
                // periphery:ignore - Reserved: updateDailyStats() instance method reserved for future feature activation
                mouseDistance: mouseDistance,
                activeMinutes: activeMinutes
            )
        }

        private func calculateActiveMinutes() -> Int {
            guard let startTime = activityStartTime else { return 0 }
            return Int(Date().timeIntervalSince(startTime) / 60)
        }

        // MARK: - Data Persistence

// periphery:ignore - Reserved: calculateActiveMinutes() instance method reserved for future feature activation

        private func saveCurrentStats() async {
            guard let context = modelContext, let stats = dailyStats else { return }

            let record = DailyInputStatistics(
                date: Calendar.current.startOfDay(for: Date()),
                // periphery:ignore - Reserved: saveCurrentStats() instance method reserved for future feature activation
                mouseClicks: stats.mouseClicks,
                keystrokes: stats.keystrokes,
                mouseDistancePixels: stats.mouseDistance,
                activeMinutes: stats.activeMinutes,
                activityLevel: stats.activityLevel.rawValue
            )

            // Check if record exists - fetch all and filter to avoid Swift 6 #Predicate Sendable issues
            let targetDate = record.date
            let descriptor = FetchDescriptor<DailyInputStatistics>()
            let allRecords: [DailyInputStatistics]
            do {
                allRecords = try context.fetch(descriptor)
            } catch {
                logger.error("Failed to fetch input statistics for save: \(error)")
                return
            }

            if let existing = allRecords.first(where: { $0.date == targetDate }) {
                existing.mouseClicks = record.mouseClicks
                existing.keystrokes = record.keystrokes
                existing.mouseDistancePixels = record.mouseDistancePixels
                existing.activeMinutes = record.activeMinutes
                existing.activityLevel = record.activityLevel
            } else {
                context.insert(record)
            }

            do {
                try context.save()
            } catch {
                logger.error("Failed to save input statistics: \(error)")
            }
        }

        // MARK: - Historical Data

        func getRecord(for date: Date) async -> DailyInputStatistics? {
            guard let context = modelContext else { return nil }

            let startOfDay = Calendar.current.startOfDay(for: date)

// periphery:ignore - Reserved: getRecord(for:) instance method reserved for future feature activation

            // Fetch all and filter in memory to avoid Swift 6 #Predicate Sendable issues
            let descriptor = FetchDescriptor<DailyInputStatistics>()
            let allRecords: [DailyInputStatistics]
            do {
                allRecords = try context.fetch(descriptor)
            } catch {
                logger.error("Failed to fetch input statistics: \(error)")
                return nil
            }
            return allRecords.first { $0.date == startOfDay }
        }

        func getRecords(from start: Date, to end: Date) async -> [DailyInputStatistics] {
            guard let context = modelContext else { return [] }

            // periphery:ignore - Reserved: getRecords(from:to:) instance method reserved for future feature activation
            // Fetch all and filter in memory to avoid Swift 6 #Predicate Sendable issues
            let descriptor = FetchDescriptor<DailyInputStatistics>()
            let allRecords: [DailyInputStatistics]
            do {
                allRecords = try context.fetch(descriptor)
            } catch {
                logger.error("Failed to fetch input statistics for range: \(error)")
                return []
            }
            return allRecords
                .filter { $0.date >= start && $0.date <= end }
                .sorted { $0.date > $1.date }
        }
    }

    // MARK: - Supporting Structures

    struct InputStatistics {
        let date: Date
        let mouseClicks: Int
        // periphery:ignore - Reserved: date property reserved for future feature activation
        let keystrokes: Int
        let mouseDistance: Double
        let activeMinutes: Int

        var activityLevel: ActivityLevel {
            // periphery:ignore - Reserved: activityLevel property reserved for future feature activation
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

        // periphery:ignore - Reserved: ActivityLevel type reserved for future feature activation
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

        private let logger = Logger(subsystem: "ai.thea.app", category: "InputTrackingManager")
        private init() {}
        func setModelContext(_: ModelContext) {}
    }
#endif
