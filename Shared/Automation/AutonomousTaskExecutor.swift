import Foundation
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
import BackgroundTasks
#endif

// MARK: - Autonomous Task Executor
// Executes tasks in the background, including when user is away or device is locked
// Supports conditional triggers, app interactions, and automated responses

@MainActor
@Observable
final class AutonomousTaskExecutor {
    static let shared = AutonomousTaskExecutor()

    // MARK: - Task Registry

    private(set) var registeredTasks: [AutonomousTask] = []
    private(set) var executionHistory: [AutonomousTaskExecution] = []
    private(set) var activeConditionMonitors: [UUID: Task<Void, Never>] = [:]

    // State
    private(set) var isEnabled = true
    private(set) var isMonitoring = false
    private(set) var lastExecutionTime: Date?

    // Configuration
    struct Configuration: Codable, Sendable {
        var enableAutonomousExecution: Bool = true
        var enableWhileDeviceLocked: Bool = true
        var enableWhileUserAway: Bool = true
        var maxConcurrentTasks: Int = 3
        var executionTimeoutSeconds: TimeInterval = 300
        var cooldownBetweenExecutionsSeconds: TimeInterval = 60
        var requireUserApprovalForDestructive: Bool = true
    }

    private(set) var configuration = Configuration()

    private init() {
        loadConfiguration()
        loadRegisteredTasks()
        startMonitoring()
    }

    // MARK: - Task Registration

    /// Register a new autonomous task
    func registerTask(_ task: AutonomousTask) {
        guard !registeredTasks.contains(where: { $0.id == task.id }) else { return }
        registeredTasks.append(task)
        saveRegisteredTasks()

        if task.isEnabled {
            startMonitoringTask(task)
        }
    }

    /// Unregister a task
    func unregisterTask(id: UUID) {
        stopMonitoringTask(id: id)
        registeredTasks.removeAll { $0.id == id }
        saveRegisteredTasks()
    }

    /// Enable/disable a task
    func setTaskEnabled(_ id: UUID, enabled: Bool) {
        guard let index = registeredTasks.firstIndex(where: { $0.id == id }) else { return }
        registeredTasks[index].isEnabled = enabled
        saveRegisteredTasks()

        if enabled {
            startMonitoringTask(registeredTasks[index])
        } else {
            stopMonitoringTask(id: id)
        }
    }

    // MARK: - Predefined Task Templates

    /// Create an auto-reply task for messaging apps
    static func createAutoReplyTask(
        appBundleId: String,
        appName: String,
        replyMessage: String,
        whenFocusModeActive: Bool = true,
        whenUserAway: Bool = true
    ) -> AutonomousTask {
        let conditions: [TaskCondition] = [
            whenFocusModeActive ? .focusModeActive : nil,
            whenUserAway ? .userAway(durationMinutes: 5) : nil,
            .appNotification(bundleId: appBundleId)
        ].compactMap { $0 }

        return AutonomousTask(
            name: "Auto-reply to \(appName)",
            description: "Automatically reply when you're away or in Focus mode",
            triggerConditions: conditions,
            conditionLogic: .all,
            actions: [
                .sendReply(appBundleId: appBundleId, message: replyMessage)
            ],
            priority: .normal,
            isDestructive: false
        )
    }

    /// Create a scheduled task
    static func createScheduledTask(
        name: String,
        description: String,
        schedule: AutoTaskSchedule,
        actions: [AutoTaskAction]
    ) -> AutonomousTask {
        AutonomousTask(
            name: name,
            description: description,
            triggerConditions: [.scheduled(schedule)],
            conditionLogic: .all,
            actions: actions,
            priority: .normal,
            isDestructive: false
        )
    }

    // MARK: - Condition Monitoring

    private func startMonitoring() {
        guard configuration.enableAutonomousExecution else { return }
        isMonitoring = true

        for task in registeredTasks where task.isEnabled {
            startMonitoringTask(task)
        }
    }

    private func startMonitoringTask(_ task: AutonomousTask) {
        stopMonitoringTask(id: task.id) // Cancel existing monitor if any

        let monitorTask = Task {
            while !Task.isCancelled {
                // Check conditions periodically
                try? await Task.sleep(for: .seconds(10))

                let conditionsMet = await checkConditions(for: task)

                if conditionsMet {
                    await executeTask(task)
                }
            }
        }

        activeConditionMonitors[task.id] = monitorTask
    }

    private func stopMonitoringTask(id: UUID) {
        activeConditionMonitors[id]?.cancel()
        activeConditionMonitors.removeValue(forKey: id)
    }

    func stopAllMonitoring() {
        for (id, _) in activeConditionMonitors {
            stopMonitoringTask(id: id)
        }
        isMonitoring = false
    }

    // MARK: - Condition Checking

    private func checkConditions(for task: AutonomousTask) async -> Bool {
        let results = await withTaskGroup(of: Bool.self) { group in
            for condition in task.triggerConditions {
                group.addTask {
                    await self.evaluateCondition(condition)
                }
            }

            var results: [Bool] = []
            for await result in group {
                results.append(result)
            }
            return results
        }

        switch task.conditionLogic {
        case .all:
            return results.allSatisfy { $0 }
        case .any:
            return results.contains(true)
        }
    }

    private func evaluateCondition(_ condition: TaskCondition) async -> Bool {
        switch condition {
        case .scheduled(let schedule):
            return isScheduleTriggered(schedule)

        case .focusModeActive:
            return await checkFocusModeActive()

        case let .userAway(durationMinutes):
            return await checkUserAway(durationMinutes: durationMinutes)

        case let .appNotification(bundleId):
            return await checkAppNotification(bundleId: bundleId)

        case let .appRunning(bundleId):
            return await checkAppRunning(bundleId: bundleId)

        case let .appNotRunning(bundleId):
            return await !checkAppRunning(bundleId: bundleId)

        case let .batteryLevel(below):
            return await checkBatteryLevel(below: below)

        case .deviceLocked:
            return await checkDeviceLocked()

        case let .networkConnected(type):
            return await checkNetworkConnected(type: type)

        case let .timeRange(start, end):
            return checkTimeRange(start: start, end: end)

        case .custom:
            return false // Custom conditions require implementation
        }
    }

    private func isScheduleTriggered(_ schedule: AutoTaskSchedule) -> Bool {
        let now = Date()
        let calendar = Calendar.current

        switch schedule {
        case let .daily(hour, minute):
            let components = calendar.dateComponents([.hour, .minute], from: now)
            return components.hour == hour && components.minute == minute

        case let .weekly(weekday, hour, minute):
            let components = calendar.dateComponents([.weekday, .hour, .minute], from: now)
            return components.weekday == weekday &&
            components.hour == hour &&
            components.minute == minute

        case let .interval(seconds):
            // Check if enough time has passed since last execution
            guard let lastExecution = lastExecutionTime else { return true }
            return now.timeIntervalSince(lastExecution) >= seconds
        }
    }

    private func checkFocusModeActive() async -> Bool {
        #if os(macOS) || os(iOS)
        // Would need to use Focus API
        // For now, return false as a placeholder
        return false
        #else
        return false
        #endif
    }

    private func checkUserAway(durationMinutes: Int) async -> Bool {
        #if os(macOS)
        // Check idle time on macOS
        let idleTime = getSystemIdleTime()
        return idleTime >= TimeInterval(durationMinutes * 60)
        #else
        return false
        #endif
    }

    private func checkAppNotification(bundleId _: String) async -> Bool {
        // Would need notification observation
        false
    }

    private func checkAppRunning(bundleId: String) async -> Bool {
        #if os(macOS)
        return NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == bundleId }
        #else
        return false
        #endif
    }

    private func checkBatteryLevel(below: Int) async -> Bool {
        guard let level = UnifiedDeviceAwareness.shared.systemState.batteryLevel else { return false }
        return Int(level) < below
    }

    private func checkDeviceLocked() async -> Bool {
        #if os(macOS)
        // Check screen saver or login window
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.contains { $0.bundleIdentifier == "com.apple.loginwindow" }
        #else
        return false
        #endif
    }

    private func checkNetworkConnected(type: NetworkType) async -> Bool {
        let networkInfo = UnifiedDeviceAwareness.shared.networkInfo
        guard networkInfo.isConnected else { return false }

        switch type {
        case .any:
            return true
        case .wifi:
            return networkInfo.wifiSSID != nil
        case .cellular:
            return networkInfo.connectionType == "cellular"
        }
    }

    private func checkTimeRange(start: DateComponents, end: DateComponents) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        let currentComponents = calendar.dateComponents([.hour, .minute], from: now)

        guard let currentMinutes = currentComponents.hour.flatMap({ h in currentComponents.minute.map { h * 60 + $0 } }),
              let startMinutes = start.hour.flatMap({ h in start.minute.map { h * 60 + $0 } }),
              let endMinutes = end.hour.flatMap({ h in end.minute.map { h * 60 + $0 } })
        else { return false }

        if startMinutes <= endMinutes {
            return currentMinutes >= startMinutes && currentMinutes <= endMinutes
        } else {
            // Range crosses midnight
            return currentMinutes >= startMinutes || currentMinutes <= endMinutes
        }
    }

    #if os(macOS)
    private func getSystemIdleTime() -> TimeInterval {
        var iterator: io_iterator_t = 0
        defer { IOObjectRelease(iterator) }

        guard IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("IOHIDSystem"),
            &iterator
        ) == KERN_SUCCESS else { return 0 }

        let entry = IOIteratorNext(iterator)
        defer { IOObjectRelease(entry) }

        guard entry != 0 else { return 0 }

        var unmanagedDict: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(entry, &unmanagedDict, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = unmanagedDict?.takeRetainedValue() as? [String: Any],
              let idleTime = dict["HIDIdleTime"] as? UInt64
        else { return 0 }

        return TimeInterval(idleTime) / 1_000_000_000 // Convert from nanoseconds
    }
    #endif

    // MARK: - Task Execution

    private func executeTask(_ task: AutonomousTask) async {
        // Check cooldown
        if let lastExecution = executionHistory.last(where: { $0.taskId == task.id }),
           Date().timeIntervalSince(lastExecution.timestamp) < configuration.cooldownBetweenExecutionsSeconds
        {
            return
        }

        // Check if destructive and needs approval
        if task.isDestructive && configuration.requireUserApprovalForDestructive {
            // Would show notification asking for approval
            return
        }

        let execution = AutonomousTaskExecution(
            taskId: task.id,
            taskName: task.name,
            timestamp: Date()
        )

        do {
            for action in task.actions {
                try await executeAction(action)
            }

            var completedExecution = execution
            completedExecution.status = .completed
            completedExecution.completedAt = Date()
            executionHistory.append(completedExecution)
            lastExecutionTime = Date()

        } catch {
            var failedExecution = execution
            failedExecution.status = .failed
            failedExecution.errorMessage = error.localizedDescription
            failedExecution.completedAt = Date()
            executionHistory.append(failedExecution)
        }

        saveExecutionHistory()
    }

    private func executeAction(_ action: AutoTaskAction) async throws {
        switch action {
        case let .sendReply(bundleId, message):
            try await sendAutoReply(to: bundleId, message: message)

        case let .runShortcut(name):
            try await runShortcut(name: name)

        case let .executeAppleScript(script):
            try await executeAppleScript(script)

        case let .sendNotification(title, body):
            try await sendLocalNotification(title: title, body: body)

        case let .openApp(bundleId):
            try await openApp(bundleId: bundleId)

        case let .openURL(url):
            try await openURL(url)

        case .lockScreen:
            try await lockScreen()

        case .custom:
            break // Custom actions require implementation
        }
    }

    // MARK: - Action Implementations

    private func sendAutoReply(to bundleId: String, message: String) async throws {
        #if os(macOS)
        // Use AppleScript to send message
        let script: String
        switch bundleId {
        case "net.whatsapp.WhatsApp":
            script = """
            tell application "WhatsApp"
                -- Would need specific WhatsApp automation
            end tell
            """
        case "com.apple.MobileSMS":
            script = """
            tell application "Messages"
                -- Send to most recent conversation
                set targetService to 1st account whose service type = iMessage
                set targetBuddy to buddy 1 of targetService
                send "\(message)" to targetBuddy
            end tell
            """
        default:
            throw AutoTaskExecutionError.unsupportedApp(bundleId)
        }

        try await executeAppleScript(script)
        #else
        throw AutoTaskExecutionError.platformNotSupported
        #endif
    }

    private func runShortcut(name: String) async throws {
        #if os(macOS)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["run", name]
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw AutoTaskExecutionError.shortcutFailed(name)
        }
        #elseif os(iOS)
        // Use Shortcuts URL scheme
        guard let url = URL(string: "shortcuts://run-shortcut?name=\(name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name)") else {
            throw AutoTaskExecutionError.invalidShortcutName(name)
        }
        await UIApplication.shared.open(url)
        #endif
    }

    private func executeAppleScript(_ script: String) async throws {
        #if os(macOS)
        guard let appleScript = NSAppleScript(source: script) else {
            throw AutoTaskExecutionError.invalidScript
        }

        var error: NSDictionary?
        appleScript.executeAndReturnError(&error)

        if let error {
            throw AutoTaskExecutionError.scriptError(error.description)
        }
        #else
        throw AutoTaskExecutionError.platformNotSupported
        #endif
    }

    private func sendLocalNotification(title: String, body: String) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        try await UNUserNotificationCenter.current().add(request)
    }

    private func openApp(bundleId: String) async throws {
        #if os(macOS)
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            throw AutoTaskExecutionError.appNotFound(bundleId)
        }
        try await NSWorkspace.shared.openApplication(at: url, configuration: .init())
        #elseif os(iOS)
        // iOS can't open arbitrary apps
        throw AutoTaskExecutionError.platformNotSupported
        #endif
    }

    private func openURL(_ url: URL) async throws {
        #if os(macOS)
        NSWorkspace.shared.open(url)
        #elseif os(iOS)
        await UIApplication.shared.open(url)
        #endif
    }

    private func lockScreen() async throws {
        #if os(macOS)
        let script = """
        tell application "System Events" to keystroke "q" using {control down, command down}
        """
        try await executeAppleScript(script)
        #else
        throw AutoTaskExecutionError.platformNotSupported
        #endif
    }

    // MARK: - Persistence

    private func saveRegisteredTasks() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(registeredTasks.map(AutonomousTaskDTO.init)) {
            UserDefaults.standard.set(data, forKey: "AutonomousTaskExecutor.tasks")
        }
    }

    private func loadRegisteredTasks() {
        let decoder = JSONDecoder()
        if let data = UserDefaults.standard.data(forKey: "AutonomousTaskExecutor.tasks"),
           let dtos = try? decoder.decode([AutonomousTaskDTO].self, from: data)
        {
            registeredTasks = dtos.map(AutonomousTask.init)
        }
    }

    private func saveExecutionHistory() {
        // Keep only last 100 executions
        let recentHistory = Array(executionHistory.suffix(100))
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(recentHistory) {
            UserDefaults.standard.set(data, forKey: "AutonomousTaskExecutor.history")
        }
    }

    func updateConfiguration(_ config: Configuration) {
        configuration = config
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: "AutonomousTaskExecutor.config")
        }

        if config.enableAutonomousExecution && !isMonitoring {
            startMonitoring()
        } else if !config.enableAutonomousExecution && isMonitoring {
            stopAllMonitoring()
        }
    }

    private func loadConfiguration() {
        if let data = UserDefaults.standard.data(forKey: "AutonomousTaskExecutor.config"),
           let config = try? JSONDecoder().decode(Configuration.self, from: data)
        {
            configuration = config
        }
    }
}

// MARK: - Task Types

struct AutonomousTask: Identifiable, Sendable {
    let id: UUID
    var name: String
    var description: String
    var triggerConditions: [TaskCondition]
    var conditionLogic: ConditionLogic
    var actions: [AutoTaskAction]
    var priority: AutonomousTaskPriority
    var isEnabled: Bool
    var isDestructive: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        triggerConditions: [TaskCondition],
        conditionLogic: ConditionLogic = .all,
        actions: [AutoTaskAction],
        priority: AutonomousTaskPriority = .normal,
        isEnabled: Bool = true,
        isDestructive: Bool = false
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.triggerConditions = triggerConditions
        self.conditionLogic = conditionLogic
        self.actions = actions
        self.priority = priority
        self.isEnabled = isEnabled
        self.isDestructive = isDestructive
        createdAt = Date()
    }

    init(from dto: AutonomousTaskDTO) {
        id = dto.id
        name = dto.name
        description = dto.description
        triggerConditions = dto.triggerConditions
        conditionLogic = dto.conditionLogic
        actions = dto.actions
        priority = dto.priority
        isEnabled = dto.isEnabled
        isDestructive = dto.isDestructive
        createdAt = dto.createdAt
    }
}

struct AutonomousTaskDTO: Codable {
    let id: UUID
    let name: String
    let description: String
    let triggerConditions: [TaskCondition]
    let conditionLogic: ConditionLogic
    let actions: [AutoTaskAction]
    let priority: AutonomousTaskPriority
    let isEnabled: Bool
    let isDestructive: Bool
    let createdAt: Date

    init(_ task: AutonomousTask) {
        id = task.id
        name = task.name
        description = task.description
        triggerConditions = task.triggerConditions
        conditionLogic = task.conditionLogic
        actions = task.actions
        priority = task.priority
        isEnabled = task.isEnabled
        isDestructive = task.isDestructive
        createdAt = task.createdAt
    }
}

enum TaskCondition: Codable, Sendable {
    case scheduled(AutoTaskSchedule)
    case focusModeActive
    case userAway(durationMinutes: Int)
    case appNotification(bundleId: String)
    case appRunning(bundleId: String)
    case appNotRunning(bundleId: String)
    case batteryLevel(below: Int)
    case deviceLocked
    case networkConnected(type: NetworkType)
    case timeRange(start: DateComponents, end: DateComponents)
    case custom(id: String)
}

enum AutoTaskSchedule: Codable, Sendable {
    case daily(hour: Int, minute: Int)
    case weekly(weekday: Int, hour: Int, minute: Int)
    case interval(seconds: TimeInterval)
}

enum NetworkType: String, Codable, Sendable {
    case any
    case wifi
    case cellular
}

enum ConditionLogic: String, Codable, Sendable {
    case all // AND
    case any // OR
}

enum AutoTaskAction: Codable, Sendable {
    case sendReply(appBundleId: String, message: String)
    case runShortcut(name: String)
    case executeAppleScript(script: String)
    case sendNotification(title: String, body: String)
    case openApp(bundleId: String)
    case openURL(url: URL)
    case lockScreen
    case custom(id: String)
}

enum AutonomousTaskPriority: String, Codable, Sendable {
    case low
    case normal
    case high
    case critical
}

struct AutonomousTaskExecution: Codable, Identifiable, Sendable {
    let id: UUID
    let taskId: UUID
    let taskName: String
    let timestamp: Date
    var status: AutoExecutionStatus
    var errorMessage: String?
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        taskId: UUID,
        taskName: String,
        timestamp: Date,
        status: AutoExecutionStatus = .running,
        errorMessage: String? = nil,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.taskId = taskId
        self.taskName = taskName
        self.timestamp = timestamp
        self.status = status
        self.errorMessage = errorMessage
        self.completedAt = completedAt
    }
}

enum AutoExecutionStatus: String, Codable, Sendable {
    case running
    case completed
    case failed
    case cancelled
}

enum AutoTaskExecutionError: LocalizedError {
    case unsupportedApp(String)
    case platformNotSupported
    case shortcutFailed(String)
    case invalidShortcutName(String)
    case invalidScript
    case scriptError(String)
    case appNotFound(String)

    var errorDescription: String? {
        switch self {
        case let .unsupportedApp(bundleId):
            return "App not supported for automation: \(bundleId)"
        case .platformNotSupported:
            return "This action is not supported on this platform"
        case let .shortcutFailed(name):
            return "Shortcut failed: \(name)"
        case let .invalidShortcutName(name):
            return "Invalid shortcut name: \(name)"
        case .invalidScript:
            return "Invalid AppleScript"
        case let .scriptError(message):
            return "Script error: \(message)"
        case let .appNotFound(bundleId):
            return "App not found: \(bundleId)"
        }
    }
}

import UserNotifications
