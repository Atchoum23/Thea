// SmartTriggerEngine.swift
// Intelligent automation triggers based on context, time, location, and events

import Foundation
import OSLog
import Combine
#if canImport(CoreLocation)
import CoreLocation
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
            triggers.filter { $0.isEnabled }.forEach { activateTrigger($0) }
        } else {
            triggers.forEach { deactivateTrigger($0) }
        }
    }

    // MARK: - Trigger Activation

    private func activateTrigger(_ trigger: SmartTrigger) {
        guard trigger.isEnabled && isEnabled else { return }

        switch trigger.condition {
        case .time(let config):
            activateTimeTrigger(trigger, config: config)
        case .location(let config):
            activateLocationTrigger(trigger, config: config)
        case .appLaunch(let appId):
            activateAppLaunchTrigger(trigger, appId: appId)
        case .appQuit(let appId):
            activateAppQuitTrigger(trigger, appId: appId)
        case .deviceConnect(let deviceType):
            activateDeviceConnectTrigger(trigger, deviceType: deviceType)
        case .networkChange(let config):
            activateNetworkTrigger(trigger, config: config)
        case .batteryLevel(let threshold, let isCharging):
            activateBatteryTrigger(trigger, threshold: threshold, isCharging: isCharging)
        case .focusModeChange(let mode):
            activateFocusModeTrigger(trigger, mode: mode)
        case .calendarEvent(let config):
            activateCalendarTrigger(trigger, config: config)
        case .fileChange(let path):
            activateFileChangeTrigger(trigger, path: path)
        case .webhook(let url):
            activateWebhookTrigger(trigger, url: url)
        case .manual:
            break // Manual triggers don't need activation
        case .aiContext(let pattern):
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
        case .once(let date):
            if date > now {
                nextFireDate = date
            }
        case .daily(let time):
            nextFireDate = calculateNextDaily(time: time)
        case .weekly(let days, let time):
            nextFireDate = calculateNextWeekly(days: days, time: time)
        case .interval(let seconds):
            nextFireDate = now.addingTimeInterval(seconds)
        case .cron(let expression):
            nextFireDate = calculateNextCron(expression: expression)
        }

        guard let fireDate = nextFireDate else { return }

        let timer = Timer(fireAt: fireDate, interval: 0, target: self, selector: #selector(timerFired(_:)), userInfo: trigger.id, repeats: false)
        RunLoop.main.add(timer, forMode: .common)
        activeTimers[trigger.id] = timer

        logger.debug("Time trigger \(trigger.name) scheduled for \(fireDate)")
    }

    @objc private func timerFired(_ timer: Timer) {
        guard let triggerId = timer.userInfo as? UUID,
              let trigger = triggers.first(where: { $0.id == triggerId }) else {
            return
        }

        Task {
            await executeTrigger(trigger)

            // Re-schedule if recurring
            if case .time(let config) = trigger.condition {
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
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }

        return date
    }

    private func calculateNextWeekly(days: Set<Int>, time: DateComponents) -> Date? {
        let calendar = Calendar.current
        let now = Date()
        let currentWeekday = calendar.component(.weekday, from: now)

        for dayOffset in 0..<7 {
            let targetWeekday = (currentWeekday + dayOffset - 1) % 7 + 1
            if days.contains(targetWeekday) {
                var components = calendar.dateComponents([.year, .month, .day], from: now)
                components.day! += dayOffset
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
        // Simplified cron parsing (minute hour day month weekday)
        // For full cron support, use a proper cron library
        return Date().addingTimeInterval(3600) // Placeholder: 1 hour
    }

    // MARK: - Location Triggers

    private func activateLocationTrigger(_ trigger: SmartTrigger, config: LocationTriggerConfig) {
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

    private func activateDeviceConnectTrigger(_ trigger: SmartTrigger, deviceType: String) {
        // Monitor for device connections (Bluetooth, USB, etc.)
        logger.debug("Device trigger activated for: \(deviceType)")
    }

    // MARK: - Network Triggers

    private func activateNetworkTrigger(_ trigger: SmartTrigger, config: NetworkTriggerConfig) {
        // Monitor network changes
        logger.debug("Network trigger activated: \(config.ssid ?? "any")")
    }

    // MARK: - Battery Triggers

    private func activateBatteryTrigger(_ trigger: SmartTrigger, threshold: Int, isCharging: Bool?) {
        // Monitor battery level
        logger.debug("Battery trigger activated: \(threshold)%")
    }

    // MARK: - Focus Mode Triggers

    private func activateFocusModeTrigger(_ trigger: SmartTrigger, mode: String) {
        // Monitor Focus mode changes
        logger.debug("Focus mode trigger activated: \(mode)")
    }

    // MARK: - Calendar Triggers

    private func activateCalendarTrigger(_ trigger: SmartTrigger, config: CalendarTriggerConfig) {
        // Monitor calendar events
        logger.debug("Calendar trigger activated")
    }

    // MARK: - File Change Triggers

    private func activateFileChangeTrigger(_ trigger: SmartTrigger, path: String) {
        // Use FSEvents or DispatchSource to monitor file changes
        logger.debug("File change trigger activated: \(path)")
    }

    // MARK: - Webhook Triggers

    private func activateWebhookTrigger(_ trigger: SmartTrigger, url: String) {
        // Setup webhook endpoint
        logger.debug("Webhook trigger activated: \(url)")
    }

    // MARK: - AI Context Triggers

    private func activateAIContextTrigger(_ trigger: SmartTrigger, pattern: String) {
        // Monitor AI conversation for patterns
        logger.debug("AI context trigger activated: \(pattern)")
    }

    // MARK: - Trigger Execution

    public func executeTrigger(_ trigger: SmartTrigger) async {
        guard trigger.isEnabled && isEnabled else { return }

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
            case .timeRange(let start, let end):
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

            case .dayOfWeek(let days):
                let weekday = Calendar.current.component(.weekday, from: Date())
                if !days.contains(weekday) {
                    return false
                }

            case .batteryAbove(let threshold):
                // Check battery level
                break

            case .networkConnected(let ssid):
                // Check network
                break

            case .focusModeActive(let mode):
                // Check focus mode
                break
            }
        }
        return true
    }

    private func executeAction(_ action: TriggerAction) async throws {
        switch action {
        case .runShortcut(let name):
            // Run Shortcuts automation
            logger.info("Running shortcut: \(name)")

        case .sendNotification(let title, let body):
            // Send local notification
            logger.info("Sending notification: \(title)")

        case .executeCommand(let command):
            // Execute terminal command (with AgentSec validation)
            logger.info("Executing command: \(command)")

        case .openApp(let appId):
            #if os(macOS)
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: appId) {
                NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
            }
            #endif

        case .openURL(let urlString):
            if let url = URL(string: urlString) {
                #if os(macOS)
                NSWorkspace.shared.open(url)
                #endif
            }

        case .setClipboard(let text):
            #if os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            #endif

        case .playSound(let soundName):
            // Play system sound
            #if os(macOS)
            NSSound(named: NSSound.Name(soundName))?.play()
            #endif

        case .speakText(let text):
            await SpeechIntelligence.shared.speak(text)

        case .sendMessage(let recipient, let message):
            logger.info("Would send message to \(recipient): \(message)")

        case .controlHomeKit(let sceneId):
            logger.info("Would activate HomeKit scene: \(sceneId)")

        case .setVariable(let key, let value):
            defaults.set(value, forKey: "thea.trigger.var.\(key)")

        case .aiPrompt(let prompt):
            logger.info("Would send AI prompt: \(prompt)")

        case .webhook(let url, let method, let body):
            try await executeWebhook(url: url, method: method, body: body)

        case .chain(let actions):
            for chainedAction in actions {
                try await executeAction(chainedAction)
            }
        }
    }

    private func executeWebhook(url: String, method: String, body: [String: Any]?) async throws {
        guard let requestURL = URL(string: url) else { return }

        var request = URLRequest(url: requestURL)
        request.httpMethod = method

        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
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
        triggers.filter { $0.isEnabled }.forEach { activateTrigger($0) }
    }

    // MARK: - Persistence

    private func loadTriggers() {
        guard let data = defaults.data(forKey: triggersKey),
              let saved = try? JSONDecoder().decode([SmartTrigger].self, from: data) else {
            return
        }
        triggers = saved
        triggers.filter { $0.isEnabled }.forEach { activateTrigger($0) }
    }

    private func saveTriggers() {
        guard let data = try? JSONEncoder().encode(triggers) else { return }
        defaults.set(data, forKey: triggersKey)
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
        self.createdAt = Date()
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
        self.id = UUID()
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
