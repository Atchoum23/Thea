//
//  FocusOrchestrator.swift
//  Thea
//
//  Created by Thea
//  Automatic Focus mode switching and cross-device sync
//

import Foundation
import os.log

#if canImport(Intents)
    import Intents
#endif

// MARK: - Focus Orchestrator

/// Orchestrates Focus mode management and automatic switching
@MainActor
public final class FocusOrchestrator: ObservableObject {
    public static let shared = FocusOrchestrator()

    private let logger = Logger(subsystem: "app.thea.focus", category: "FocusOrchestrator")

    // MARK: - State

    @Published public private(set) var currentFocus: FocusMode?
    @Published public private(set) var availableFocusModes: [FocusMode] = []
    @Published public private(set) var isAutomationEnabled = true
    @Published public private(set) var scheduledTransitions: [FocusTransition] = []

    // MARK: - Rules

    @Published public var locationRules: [LocationFocusRule] = []
    @Published public var timeRules: [TimeFocusRule] = []
    @Published public var appRules: [AppFocusRule] = []
    @Published public var calendarRules: [CalendarFocusRule] = []

    // MARK: - Callbacks

    public var onFocusChanged: ((FocusMode?) -> Void)?
    public var onFocusSuggested: ((FocusMode, String) -> Void)?

    private init() {
        loadConfiguration()
        setupAvailableFocusModes()
    }

    // MARK: - Focus Mode Management

    /// Set the current focus mode
    public func setFocus(_ mode: FocusMode?) async throws {
        let previousFocus = currentFocus
        currentFocus = mode

        // Apply the focus
        if let mode {
            try await applyFocus(mode)
            logger.info("Focus set to: \(mode.name)")
        } else {
            try await clearFocus()
            logger.info("Focus cleared")
        }

        // Sync across devices
        await syncFocusAcrossDevices(mode)

        onFocusChanged?(mode)

        // Record transition
        if previousFocus != mode {
            recordTransition(from: previousFocus, to: mode)
        }
    }

    /// Toggle focus mode on/off
    public func toggleFocus(_ mode: FocusMode) async throws {
        if currentFocus?.id == mode.id {
            try await setFocus(nil)
        } else {
            try await setFocus(mode)
        }
    }

    /// Apply focus mode using system APIs
    private func applyFocus(_ mode: FocusMode) async throws {
        #if os(iOS)
            // On iOS, use INFocusStatusCenter
            // Note: Can only read focus status, not set it programmatically
            // Would need to trigger a Shortcut to actually change focus
            logger.info("Triggering focus mode shortcut for: \(mode.name)")

            // Use Shortcuts to change focus
            try await ShortcutsOrchestrator.shared.runShortcut(named: "Set Focus to \(mode.name)")
        #elseif os(macOS)
            // On macOS, use Focus status center or AppleScript
            // Note: Direct API access is limited, may need Shortcuts
            logger.info("Setting macOS focus to: \(mode.name)")
        #endif
    }

    private func clearFocus() async throws {
        #if os(iOS)
            logger.info("Clearing iOS focus")
            try await ShortcutsOrchestrator.shared.runShortcut(named: "Turn Off Focus")
        #endif
    }

    // MARK: - Available Focus Modes

    private func setupAvailableFocusModes() {
        // System focus modes
        availableFocusModes = [
            FocusMode(id: "donotdisturb", name: "Do Not Disturb", systemName: "moon.fill", color: "#5856D6"),
            FocusMode(id: "personal", name: "Personal", systemName: "person.fill", color: "#34C759"),
            FocusMode(id: "work", name: "Work", systemName: "briefcase.fill", color: "#007AFF"),
            FocusMode(id: "sleep", name: "Sleep", systemName: "bed.double.fill", color: "#5856D6"),
            FocusMode(id: "driving", name: "Driving", systemName: "car.fill", color: "#FF3B30"),
            FocusMode(id: "fitness", name: "Fitness", systemName: "figure.run", color: "#FF9500"),
            FocusMode(id: "mindfulness", name: "Mindfulness", systemName: "brain.head.profile", color: "#AF52DE"),
            FocusMode(id: "reading", name: "Reading", systemName: "book.fill", color: "#FF9F0A")
        ]
    }

    // MARK: - Automatic Switching

    /// Evaluate rules and suggest focus change
    public func evaluateContext(_ context: OrchestratorFocusContext) async {
        guard isAutomationEnabled else { return }

        var suggestedFocus: FocusMode?
        var reason = ""

        // Check location rules
        if let location = context.location {
            for rule in locationRules where rule.isEnabled {
                if rule.matchesLocation(location) {
                    suggestedFocus = rule.targetFocus
                    reason = "Location: \(rule.locationName)"
                    break
                }
            }
        }

        // Check time rules (override location)
        let currentHour = Calendar.current.component(.hour, from: Date())
        for rule in timeRules where rule.isEnabled {
            if rule.matchesTime(currentHour, weekday: context.weekday) {
                suggestedFocus = rule.targetFocus
                reason = "Time: \(rule.name)"
                break
            }
        }

        // Check app rules (highest priority)
        if let frontApp = context.frontmostApp {
            for rule in appRules where rule.isEnabled {
                if rule.matchesApp(frontApp) {
                    suggestedFocus = rule.targetFocus
                    reason = "App: \(frontApp)"
                    break
                }
            }
        }

        // Check calendar rules
        if let event = context.currentCalendarEvent {
            for rule in calendarRules where rule.isEnabled {
                if rule.matchesEvent(event) {
                    suggestedFocus = rule.targetFocus
                    reason = "Calendar: \(event)"
                    break
                }
            }
        }

        // Suggest if different from current
        if let suggested = suggestedFocus, suggested.id != currentFocus?.id {
            onFocusSuggested?(suggested, reason)

            // Auto-apply if confidence is high
            if shouldAutoApply(suggested, reason: reason) {
                try? await setFocus(suggested)
            }
        }
    }

    private func shouldAutoApply(_: FocusMode, reason: String) -> Bool {
        // Auto-apply for time-based rules and calendar events
        reason.hasPrefix("Time:") || reason.hasPrefix("Calendar:")
    }

    // MARK: - Cross-Device Sync

    private func syncFocusAcrossDevices(_ mode: FocusMode?) async {
        // Use CloudKit to sync focus state
        let change = ContextChange(
            type: mode != nil ? .update : .delete,
            contextType: "FocusState",
            data: [
                "focusId": .string(mode?.id ?? ""),
                "focusName": .string(mode?.name ?? ""),
                "deviceId": .string(DeviceRegistry.shared.currentDevice.id)
            ]
        )

        await UnifiedContextSync.shared.queueChange(change)
    }

    // MARK: - Scheduling

    /// Schedule a focus mode transition
    public func scheduleFocus(_ mode: FocusMode, at date: Date, duration: TimeInterval? = nil) {
        let transition = FocusTransition(
            id: UUID().uuidString,
            targetFocus: mode,
            scheduledTime: date,
            duration: duration
        )

        scheduledTransitions.append(transition)
        scheduledTransitions.sort { $0.scheduledTime < $1.scheduledTime }

        setupTransitionTimer(for: transition)
        saveConfiguration()

        logger.info("Scheduled focus '\(mode.name)' for \(date)")
    }

    /// Cancel a scheduled transition
    public func cancelScheduledFocus(_ transitionId: String) {
        scheduledTransitions.removeAll { $0.id == transitionId }
        saveConfiguration()
    }

    private func setupTransitionTimer(for transition: FocusTransition) {
        let delay = transition.scheduledTime.timeIntervalSinceNow
        guard delay > 0 else { return }

        Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            try? await setFocus(transition.targetFocus)

            // If duration specified, schedule end
            if let duration = transition.duration {
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                try? await setFocus(nil)
            }

            scheduledTransitions.removeAll { $0.id == transition.id }
        }
    }

    // MARK: - History

    private var transitionHistory: [FocusTransitionRecord] = []

    private func recordTransition(from: FocusMode?, to: FocusMode?) {
        let record = FocusTransitionRecord(
            fromFocus: from,
            toFocus: to,
            timestamp: Date()
        )
        transitionHistory.append(record)

        // Keep last 100 transitions
        if transitionHistory.count > 100 {
            transitionHistory = Array(transitionHistory.suffix(100))
        }
    }

    /// Get focus statistics
    public func getFocusStats(for period: TimePeriod = .week) -> FocusStatistics {
        let cutoff: Date = switch period {
        case .day:
            Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        case .week:
            Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        case .month:
            Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        }

        let relevantTransitions = transitionHistory.filter { $0.timestamp >= cutoff }

        var timeInFocus: [String: TimeInterval] = [:]
        // Calculate time spent in each focus mode

        return FocusStatistics(
            totalFocusTime: timeInFocus.values.reduce(0, +),
            timeByMode: timeInFocus,
            transitionCount: relevantTransitions.count,
            period: period
        )
    }

    public enum TimePeriod: Sendable {
        case day, week, month
    }

    // MARK: - Configuration

    private func loadConfiguration() {
        // Load rules from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "thea.focus.locationRules"),
           let rules = try? JSONDecoder().decode([LocationFocusRule].self, from: data)
        {
            locationRules = rules
        }

        if let data = UserDefaults.standard.data(forKey: "thea.focus.timeRules"),
           let rules = try? JSONDecoder().decode([TimeFocusRule].self, from: data)
        {
            timeRules = rules
        }

        if let data = UserDefaults.standard.data(forKey: "thea.focus.appRules"),
           let rules = try? JSONDecoder().decode([AppFocusRule].self, from: data)
        {
            appRules = rules
        }

        isAutomationEnabled = UserDefaults.standard.bool(forKey: "thea.focus.automationEnabled")
    }

    private func saveConfiguration() {
        if let data = try? JSONEncoder().encode(locationRules) {
            UserDefaults.standard.set(data, forKey: "thea.focus.locationRules")
        }
        if let data = try? JSONEncoder().encode(timeRules) {
            UserDefaults.standard.set(data, forKey: "thea.focus.timeRules")
        }
        if let data = try? JSONEncoder().encode(appRules) {
            UserDefaults.standard.set(data, forKey: "thea.focus.appRules")
        }
        UserDefaults.standard.set(isAutomationEnabled, forKey: "thea.focus.automationEnabled")
    }

    /// Enable/disable automatic switching
    public func setAutomation(enabled: Bool) {
        isAutomationEnabled = enabled
        saveConfiguration()
    }
}

// MARK: - Models

public struct FocusMode: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let systemName: String
    public let color: String

    public static func == (lhs: FocusMode, rhs: FocusMode) -> Bool {
        lhs.id == rhs.id
    }
}

public struct OrchestratorFocusContext: Sendable {
    public let location: String?
    public let weekday: Int
    public let frontmostApp: String?
    public let currentCalendarEvent: String?

    public init(
        location: String? = nil,
        weekday: Int = Calendar.current.component(.weekday, from: Date()),
        frontmostApp: String? = nil,
        currentCalendarEvent: String? = nil
    ) {
        self.location = location
        self.weekday = weekday
        self.frontmostApp = frontmostApp
        self.currentCalendarEvent = currentCalendarEvent
    }
}

public struct FocusTransition: Identifiable, Codable, Sendable {
    public let id: String
    public let targetFocus: FocusMode
    public let scheduledTime: Date
    public let duration: TimeInterval?
}

public struct FocusTransitionRecord: Codable, Sendable {
    public let fromFocus: FocusMode?
    public let toFocus: FocusMode?
    public let timestamp: Date
}

public struct FocusStatistics: Sendable {
    public let totalFocusTime: TimeInterval
    public let timeByMode: [String: TimeInterval]
    public let transitionCount: Int
    public let period: FocusOrchestrator.TimePeriod
}

// MARK: - Rules

public struct LocationFocusRule: Identifiable, Codable, Sendable {
    public let id: String
    public let locationName: String
    public let latitude: Double
    public let longitude: Double
    public let radius: Double // meters
    public let targetFocus: FocusMode
    public var isEnabled: Bool

    public func matchesLocation(_ location: String) -> Bool {
        // Simplified - would use CLLocation distance
        location.lowercased().contains(locationName.lowercased())
    }
}

public struct TimeFocusRule: Identifiable, Codable, Sendable {
    public let id: String
    public let name: String
    public let startHour: Int
    public let endHour: Int
    public let weekdays: [Int] // 1=Sunday, 7=Saturday
    public let targetFocus: FocusMode
    public var isEnabled: Bool

    public func matchesTime(_ hour: Int, weekday: Int) -> Bool {
        guard weekdays.contains(weekday) else { return false }

        if startHour < endHour {
            return hour >= startHour && hour < endHour
        } else {
            // Overnight range
            return hour >= startHour || hour < endHour
        }
    }
}

public struct AppFocusRule: Identifiable, Codable, Sendable {
    public let id: String
    public let appBundleId: String
    public let appName: String
    public let targetFocus: FocusMode
    public var isEnabled: Bool

    public func matchesApp(_ bundleId: String) -> Bool {
        bundleId == appBundleId || bundleId.lowercased().contains(appName.lowercased())
    }
}

public struct CalendarFocusRule: Identifiable, Codable, Sendable {
    public let id: String
    public let eventTitleContains: String?
    public let calendarName: String?
    public let targetFocus: FocusMode
    public var isEnabled: Bool

    public func matchesEvent(_ eventTitle: String) -> Bool {
        if let contains = eventTitleContains {
            return eventTitle.lowercased().contains(contains.lowercased())
        }
        return false
    }
}
