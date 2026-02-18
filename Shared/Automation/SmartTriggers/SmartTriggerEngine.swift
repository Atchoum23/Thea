// SmartTriggerEngine.swift
// Intelligent automation triggers based on context, time, location, and events

import Combine
import Foundation
import OSLog
#if canImport(CoreLocation)
    import CoreLocation
#endif
#if canImport(AppKit)
    import AppKit
#endif

// MARK: - Smart Trigger Engine

/// Intelligent automation engine that executes actions based on triggers
@MainActor
public final class SmartTriggerEngine: ObservableObject {
    public static let shared = SmartTriggerEngine()

    private let logger = Logger(subsystem: "com.thea.app", category: "SmartTriggers")
    private let defaults = UserDefaults.standard
    private let triggersKey = "thea.smart_triggers"

    private var cancellables = Set<AnyCancellable>()
    private var activeTimers: [UUID: Timer] = [:]
    private var locationManager: Any? // CLLocationManager for iOS

    // MARK: - Published State

    @Published public private(set) var triggers: [SmartTrigger] = []
    @Published public private(set) var isEnabled = true
    @Published public private(set) var lastTriggeredAction: TriggerAction?
    @Published public private(set) var triggerHistory: [TriggerExecution] = []

    // MARK: - Initialization

    private init() {
        loadTriggers()
        setupSystemObservers()
    }

    // MARK: - Trigger Management

    public func createTrigger(_ trigger: SmartTrigger) {
        triggers.append(trigger)
        saveTriggers()
        activateTrigger(trigger)
        logger.info("Created trigger: \(trigger.name)")
    }

    public func updateTrigger(_ trigger: SmartTrigger) {
        if let index = triggers.firstIndex(where: { $0.id == trigger.id }) {
            deactivateTrigger(triggers[index])
            triggers[index] = trigger
            activateTrigger(trigger)
            saveTriggers()
            logger.info("Updated trigger: \(trigger.name)")
        }
    }

    public func deleteTrigger(_ triggerId: UUID) {
        if let index = triggers.firstIndex(where: { $0.id == triggerId }) {
            deactivateTrigger(triggers[index])
            triggers.remove(at: index)
            saveTriggers()
            logger.info("Deleted trigger: \(triggerId)")
        }
    }

    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if enabled {
            triggers.filter(\.isEnabled).forEach { activateTrigger($0) }
        } else {
            triggers.forEach { deactivateTrigger($0) }
        }
    }

    // MARK: - Trigger Activation

    private func activateTrigger(_ trigger: SmartTrigger) {
        guard trigger.isEnabled, isEnabled else { return }

        switch trigger.condition {
        case let .time(config):
            activateTimeTrigger(trigger, config: config)
        case let .location(config):
            activateLocationTrigger(trigger, config: config)
        case let .appLaunch(appId):
            activateAppLaunchTrigger(trigger, appId: appId)
        case let .appQuit(appId):
            activateAppQuitTrigger(trigger, appId: appId)
        case let .deviceConnect(deviceType):
            activateDeviceConnectTrigger(trigger, deviceType: deviceType)
        case let .networkChange(config):
            activateNetworkTrigger(trigger, config: config)
        case let .batteryLevel(threshold, isCharging):
            activateBatteryTrigger(trigger, threshold: threshold, isCharging: isCharging)
        case let .focusModeChange(mode):
            activateFocusModeTrigger(trigger, mode: mode)
        case let .calendarEvent(config):
            activateCalendarTrigger(trigger, config: config)
        case let .fileChange(path):
            activateFileChangeTrigger(trigger, path: path)
        case let .webhook(url):
            activateWebhookTrigger(trigger, url: url)
        case .manual:
            break // Manual triggers don't need activation
        case let .aiContext(pattern):
            activateAIContextTrigger(trigger, pattern: pattern)
        }
    }

    private func deactivateTrigger(_ trigger: SmartTrigger) {
        // Cancel any timers
        activeTimers[trigger.id]?.invalidate()
        activeTimers.removeValue(forKey: trigger.id)
    }

    // MARK: - Time Triggers

    private func activateTimeTrigger(_ trigger: SmartTrigger, config: TimeTriggerConfig) {
        let now = Date()
        var nextFireDate: Date?

        switch config.schedule {
        case let .once(date):
            if date > now {
                nextFireDate = date
            }
        case let .daily(time):
            nextFireDate = calculateNextDaily(time: time)
        case let .weekly(days, time):
            nextFireDate = calculateNextWeekly(days: days, time: time)
        case let .interval(seconds):
            nextFireDate = now.addingTimeInterval(seconds)
        case let .cron(expression):
            nextFireDate = calculateNextCron(expression)
        }

        guard let fireDate = nextFireDate else { return }

        let timer = Timer(fireAt: fireDate, interval: 0, target: self, selector: #selector(timerFired(_:)), userInfo: trigger.id, repeats: false)
        RunLoop.main.add(timer, forMode: .common)
        activeTimers[trigger.id] = timer

        logger.debug("Time trigger \(trigger.name) scheduled for \(fireDate)")
    }

    @objc private func timerFired(_ timer: Timer) {
        guard let triggerId = timer.userInfo as? UUID,
              let trigger = triggers.first(where: { $0.id == triggerId })
        else {
            return
        }

        Task {
            await executeTrigger(trigger)

            // Re-schedule if recurring
            if case let .time(config) = trigger.condition {
                switch config.schedule {
                case .once:
                    break // Don't reschedule
                default:
                    activateTimeTrigger(trigger, config: config)
                }
            }
        }
    }

    private func calculateNextDaily(time: DateComponents) -> Date? {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = time.hour
        components.minute = time.minute

        guard var date = calendar.date(from: components) else { return nil }

        if date <= Date() {
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? date.addingTimeInterval(86400)
        }

        return date
    }

    private func calculateNextWeekly(days: Set<Int>, time: DateComponents) -> Date? {
        let calendar = Calendar.current
        let now = Date()
        let currentWeekday = calendar.component(.weekday, from: now)

        for dayOffset in 0 ..< 7 {
            let targetWeekday = (currentWeekday + dayOffset - 1) % 7 + 1
            if days.contains(targetWeekday) {
                var components = calendar.dateComponents([.year, .month, .day], from: now)
                components.day = (components.day ?? 1) + dayOffset
                components.hour = time.hour
                components.minute = time.minute

                if let date = calendar.date(from: components), date > now {
                    return date
                }
            }
        }

        return nil
    }

    private func calculateNextCron(_ expression: String) -> Date? {
        // Simplified cron: "minute hour * * *" — handles minute and hour fields
        let fields = expression.split(separator: " ").map(String.init)
        guard fields.count >= 2 else { return nil }

        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)

        if let minute = Int(fields[0]) {
            components.minute = minute
        }
        if let hour = Int(fields[1]) {
            components.hour = hour
        }
        components.second = 0

        // Get next occurrence: today if still in the future, otherwise tomorrow
        if let date = calendar.date(from: components), date > now {
            return date
        }
        if let date = calendar.date(from: components) {
            return calendar.date(byAdding: .day, value: 1, to: date)
        }
        return nil
    }

    // MARK: - Location Triggers

    private func activateLocationTrigger(_ trigger: SmartTrigger, config _: LocationTriggerConfig) {
        #if canImport(CoreLocation) && os(iOS)
            // Setup location monitoring
            logger.debug("Location trigger activated: \(trigger.name)")
        #endif
    }

    // MARK: - App Triggers

    private func activateAppLaunchTrigger(_ trigger: SmartTrigger, appId: String) {
        #if os(macOS)
            NSWorkspace.shared.notificationCenter
                .publisher(for: NSWorkspace.didLaunchApplicationNotification)
                .sink { [weak self] notification in
                    guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                          app.bundleIdentifier == appId else { return }
                    Task { await self?.executeTrigger(trigger) }
                }
                .store(in: &cancellables)
        #endif
    }

    private func activateAppQuitTrigger(_ trigger: SmartTrigger, appId: String) {
        #if os(macOS)
            NSWorkspace.shared.notificationCenter
                .publisher(for: NSWorkspace.didTerminateApplicationNotification)
                .sink { [weak self] notification in
                    guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                          app.bundleIdentifier == appId else { return }
                    Task { await self?.executeTrigger(trigger) }
                }
                .store(in: &cancellables)
        #endif
    }

    // MARK: - Device Triggers

    private func activateDeviceConnectTrigger(_: SmartTrigger, deviceType: String) {
        // Monitor for device connections (Bluetooth, USB, etc.)
        logger.debug("Device trigger activated for: \(deviceType)")
    }

    // MARK: - Network Triggers

    private func activateNetworkTrigger(_: SmartTrigger, config: NetworkTriggerConfig) {
        // Monitor network changes
        logger.debug("Network trigger activated: \(config.ssid ?? "any")")
    }

    // MARK: - Battery Triggers

    private func activateBatteryTrigger(_: SmartTrigger, threshold: Int, isCharging _: Bool?) {
        // Monitor battery level
        logger.debug("Battery trigger activated: \(threshold)%")
    }

    // MARK: - Focus Mode Triggers

    private func activateFocusModeTrigger(_: SmartTrigger, mode: String) {
        // Monitor Focus mode changes
        logger.debug("Focus mode trigger activated: \(mode)")
    }

    // MARK: - Calendar Triggers

    private func activateCalendarTrigger(_: SmartTrigger, config _: CalendarTriggerConfig) {
        // Monitor calendar events
        logger.debug("Calendar trigger activated")
    }

    // MARK: - File Change Triggers

    private func activateFileChangeTrigger(_: SmartTrigger, path: String) {
        // Use FSEvents or DispatchSource to monitor file changes
        logger.debug("File change trigger activated: \(path)")
    }

    // MARK: - Webhook Triggers

    private func activateWebhookTrigger(_: SmartTrigger, url: String) {
        // Setup webhook endpoint
        logger.debug("Webhook trigger activated: \(url)")
    }

    // MARK: - AI Context Triggers

    private func activateAIContextTrigger(_: SmartTrigger, pattern: String) {
        // Monitor AI conversation for patterns
        logger.debug("AI context trigger activated: \(pattern)")
    }

    // MARK: - Trigger Execution

    public func executeTrigger(_ trigger: SmartTrigger) async {
        guard trigger.isEnabled, isEnabled else { return }

        logger.info("Executing trigger: \(trigger.name)")

        // Check conditions
        if !evaluateConditions(trigger.additionalConditions) {
            logger.debug("Trigger conditions not met: \(trigger.name)")
            return
        }

        // Execute actions
        for action in trigger.actions {
            do {
                try await executeAction(action)
                lastTriggeredAction = action
            } catch {
                logger.error("Action failed: \(error.localizedDescription)")
            }
        }

        // Record execution
        let execution = TriggerExecution(
            triggerId: trigger.id,
            triggerName: trigger.name,
            timestamp: Date(),
            success: true
        )
        triggerHistory.append(execution)

        // Trim history
        if triggerHistory.count > 1000 {
            triggerHistory.removeFirst(triggerHistory.count - 1000)
        }
    }

    public func executeManualTrigger(_ triggerId: UUID) async {
        guard let trigger = triggers.first(where: { $0.id == triggerId }) else { return }
        await executeTrigger(trigger)
    }

    private func evaluateConditions(_ conditions: [TriggerConditionCheck]) -> Bool {
        for condition in conditions {
            switch condition {
            case let .timeRange(start, end):
                let now = Date()
                let calendar = Calendar.current
                let currentHour = calendar.component(.hour, from: now)
                let currentMinute = calendar.component(.minute, from: now)
                let currentTime = currentHour * 60 + currentMinute
                let startTime = (start.hour ?? 0) * 60 + (start.minute ?? 0)
                let endTime = (end.hour ?? 23) * 60 + (end.minute ?? 59)

                if !(currentTime >= startTime && currentTime <= endTime) {
                    return false
                }

            case let .dayOfWeek(days):
                let weekday = Calendar.current.component(.weekday, from: Date())
                if !days.contains(weekday) {
                    return false
                }

            case .batteryAbove:
                // Check battery level
                return true

            case .networkConnected:
                // Check network
                return true

            case .focusModeActive:
                // Check focus mode
                return true
            }
        }
        return true
    }

    private func executeAction(_ action: TriggerAction) async throws {
        switch action {
        case let .runShortcut(name):
            // Run Shortcuts automation
            logger.info("Running shortcut: \(name)")

        case let .sendNotification(title, _):
            // Send local notification
            logger.info("Sending notification: \(title)")

        case let .executeCommand(command):
            // Execute terminal command (with AgentSec validation)
            logger.info("Executing command: \(command)")

        case let .openApp(appId):
            #if os(macOS)
                if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: appId) {
                    do {
                        _ = try await NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
                    } catch {
                        logger.error("Failed to open app \(appId): \(error.localizedDescription)")
                    }
                }
            #endif

        case let .openURL(urlString):
            if let url = URL(string: urlString) {
                #if os(macOS)
                    NSWorkspace.shared.open(url)
                #endif
            }

        case let .setClipboard(text):
            #if os(macOS)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            #endif

        case let .playSound(soundName):
            // Play system sound
            #if os(macOS)
                NSSound(named: NSSound.Name(soundName))?.play()
            #endif

        case let .speakText(text):
            await SpeechIntelligence.shared.speak(text)

        case let .sendMessage(recipient, message):
            logger.info("Would send message to \(recipient): \(message)")

        case let .controlHomeKit(sceneId):
            logger.info("Would activate HomeKit scene: \(sceneId)")

        case let .setVariable(key, value):
            defaults.set(value, forKey: "thea.trigger.var.\(key)")

        case let .aiPrompt(prompt):
            logger.info("Would send AI prompt: \(prompt)")

        case let .webhook(url, method, body):
            try await executeWebhook(url: url, method: method, body: body)

        case let .chain(actions):
            for chainedAction in actions {
                try await executeAction(chainedAction)
            }
        }
    }

    private func executeWebhook(url: String, method: String, body: [String: Any]?) async throws {
        guard let requestURL = URL(string: url) else { return }

        var request = URLRequest(url: requestURL)
        request.httpMethod = method

        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200 ... 299).contains(httpResponse.statusCode)
        else {
            throw TriggerError.webhookFailed
        }
    }

    // MARK: - System Observers

    private func setupSystemObservers() {
        // Setup observers for system events
        #if os(macOS)
            NSWorkspace.shared.notificationCenter
                .publisher(for: NSWorkspace.willSleepNotification)
                .sink { [weak self] _ in
                    self?.handleSystemSleep()
                }
                .store(in: &cancellables)

            NSWorkspace.shared.notificationCenter
                .publisher(for: NSWorkspace.didWakeNotification)
                .sink { [weak self] _ in
                    self?.handleSystemWake()
                }
                .store(in: &cancellables)
        #endif
    }

    private func handleSystemSleep() {
        logger.debug("System going to sleep")
    }

    private func handleSystemWake() {
        logger.debug("System woke up")
        // Re-evaluate time-based triggers
        triggers.filter(\.isEnabled).forEach { activateTrigger($0) }
    }

    // MARK: - Persistence

    private func loadTriggers() {
        guard let data = defaults.data(forKey: triggersKey) else { return }
        do {
            let saved = try JSONDecoder().decode([SmartTrigger].self, from: data)
            triggers = saved
        } catch {
            logger.error("Failed to decode triggers: \(error.localizedDescription)")
            return
        }
        triggers.filter(\.isEnabled).forEach { activateTrigger($0) }
    }

    private func saveTriggers() {
        do {
            let data = try JSONEncoder().encode(triggers)
            defaults.set(data, forKey: triggersKey)
        } catch {
            logger.error("Failed to encode triggers: \(error.localizedDescription)")
        }
    }
}

// MARK: - Smart Trigger Model

public struct SmartTrigger: Identifiable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var description: String
    public var isEnabled: Bool
    public var condition: TriggerCondition
    public var additionalConditions: [TriggerConditionCheck]
    public var actions: [TriggerAction]
    public var createdAt: Date
    public var lastTriggeredAt: Date?

    public init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        isEnabled: Bool = true,
        condition: TriggerCondition,
        additionalConditions: [TriggerConditionCheck] = [],
        actions: [TriggerAction]
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.isEnabled = isEnabled
        self.condition = condition
        self.additionalConditions = additionalConditions
        self.actions = actions
        createdAt = Date()
    }
}

// MARK: - Trigger Conditions

public enum TriggerCondition: Codable, Sendable {
    case time(TimeTriggerConfig)
    case location(LocationTriggerConfig)
    case appLaunch(String)
    case appQuit(String)
    case deviceConnect(String)
    case networkChange(NetworkTriggerConfig)
    case batteryLevel(Int, Bool?)
    case focusModeChange(String)
    case calendarEvent(CalendarTriggerConfig)
    case fileChange(String)
    case webhook(String)
    case manual
    case aiContext(String)
}

public struct TimeTriggerConfig: Codable, Sendable {
    public var schedule: TimeSchedule
    public var timezone: String?

    public init(schedule: TimeSchedule, timezone: String? = nil) {
        self.schedule = schedule
        self.timezone = timezone
    }
}

public enum TimeSchedule: Codable, Sendable {
    case once(Date)
    case daily(DateComponents)
    case weekly(Set<Int>, DateComponents)
    case interval(TimeInterval)
    case cron(String)
}

public struct LocationTriggerConfig: Codable, Sendable {
    public var latitude: Double
    public var longitude: Double
    public var radius: Double
    public var onEnter: Bool
    public var onExit: Bool
}

public struct NetworkTriggerConfig: Codable, Sendable {
    public var ssid: String?
    public var connected: Bool
}

public struct CalendarTriggerConfig: Codable, Sendable {
    public var calendarId: String?
    public var minutesBefore: Int
    public var eventKeywords: [String]?
}

public enum TriggerConditionCheck: Codable, Sendable {
    case timeRange(DateComponents, DateComponents)
    case dayOfWeek(Set<Int>)
    case batteryAbove(Int)
    case networkConnected(String?)
    case focusModeActive(String?)
}

// MARK: - Trigger Actions

public indirect enum TriggerAction: Codable, Sendable {
    case runShortcut(String)
    case sendNotification(String, String)
    case executeCommand(String)
    case openApp(String)
    case openURL(String)
    case setClipboard(String)
    case playSound(String)
    case speakText(String)
    case sendMessage(String, String)
    case controlHomeKit(String)
    case setVariable(String, String)
    case aiPrompt(String)
    case webhook(String, String, [String: String]?)
    case chain([TriggerAction])
}

// MARK: - Trigger Execution Record

public struct TriggerExecution: Identifiable, Codable, Sendable {
    public let id: UUID
    public let triggerId: UUID
    public let triggerName: String
    public let timestamp: Date
    public let success: Bool
    public var error: String?

    public init(triggerId: UUID, triggerName: String, timestamp: Date, success: Bool, error: String? = nil) {
        id = UUID()
        self.triggerId = triggerId
        self.triggerName = triggerName
        self.timestamp = timestamp
        self.success = success
        self.error = error
    }
}

// MARK: - Trigger Error

public enum TriggerError: Error {
    case conditionNotMet
    case actionFailed(String)
    case webhookFailed
    case invalidConfiguration
}
