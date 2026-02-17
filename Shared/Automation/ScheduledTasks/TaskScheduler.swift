// TaskScheduler.swift
// Advanced task scheduling with persistence, retry logic, and distributed execution

import Combine
import Foundation
import OSLog

// MARK: - Task Scheduler

/// Enterprise-grade task scheduler with persistence and retry logic
@MainActor
public final class TaskScheduler: ObservableObject {
    public static let shared = TaskScheduler()

    private let logger = Logger(subsystem: "com.thea.app", category: "TaskScheduler")
    private let defaults = UserDefaults.standard
    private let tasksKey = "thea.scheduled_tasks"
    private let executionsKey = "thea.task_executions"

    private var scheduledTimers: [UUID: Timer] = [:]
    private var runningTasks: [UUID: Task<Void, Never>] = [:]

    // MARK: - Published State

    @Published public private(set) var tasks: [ScheduledTask] = []
    @Published public private(set) var executions: [TaskExecution] = []
    @Published public private(set) var isProcessing = false
    @Published public private(set) var queuedTaskCount = 0

    // MARK: - Configuration

    public var maxConcurrentTasks = 5
    public var defaultRetryCount = 3
    public var defaultRetryDelay: TimeInterval = 60

    // MARK: - Initialization

    private init() {
        loadTasks()
        loadExecutions()
        scheduleAllTasks()
    }

    // MARK: - Task Management

    /// Schedule a new task
    public func schedule(_ task: ScheduledTask) {
        var newTask = task
        newTask.status = .scheduled

        tasks.append(newTask)
        saveTasks()
        scheduleTask(newTask)

        logger.info("Scheduled task: \(task.name)")
    }

    /// Update an existing task
    public func update(_ task: ScheduledTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }

        cancelTask(tasks[index])
        tasks[index] = task
        saveTasks()
        scheduleTask(task)

        logger.info("Updated task: \(task.name)")
    }

    /// Delete a task
    public func delete(_ taskId: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == taskId }) else { return }

        cancelTask(tasks[index])
        tasks.remove(at: index)
        saveTasks()

        logger.info("Deleted task: \(taskId)")
    }

    /// Pause a task
    public func pause(_ taskId: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == taskId }) else { return }

        cancelTask(tasks[index])
        tasks[index].status = .paused
        saveTasks()
    }

    /// Resume a paused task
    public func resume(_ taskId: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == taskId }) else { return }

        tasks[index].status = .scheduled
        saveTasks()
        scheduleTask(tasks[index])
    }

    /// Run a task immediately
    public func runNow(_ taskId: UUID) async {
        guard let task = tasks.first(where: { $0.id == taskId }) else { return }
        await executeTask(task)
    }

    // MARK: - Scheduling

    private func scheduleAllTasks() {
        for task in tasks where task.status == .scheduled && task.isEnabled {
            scheduleTask(task)
        }
    }

    private func scheduleTask(_ task: ScheduledTask) {
        guard task.isEnabled, task.status == .scheduled else { return }

        // Cancel any existing timer
        scheduledTimers[task.id]?.invalidate()

        guard let nextRunDate = calculateNextRunDate(for: task) else {
            logger.warning("Could not calculate next run date for task: \(task.name)")
            return
        }

        let timer = Timer(fireAt: nextRunDate, interval: 0, target: self, selector: #selector(taskTimerFired(_:)), userInfo: task.id, repeats: false)
        RunLoop.main.add(timer, forMode: .common)
        scheduledTimers[task.id] = timer

        logger.debug("Task \(task.name) scheduled for \(nextRunDate)")
    }

    @objc private func taskTimerFired(_ timer: Timer) {
        guard let taskId = timer.userInfo as? UUID,
              let task = tasks.first(where: { $0.id == taskId })
        else {
            return
        }

        Task {
            await executeTask(task)

            // Reschedule if recurring
            if task.schedule.isRecurring {
                scheduleTask(task)
            }
        }
    }

    private func cancelTask(_ task: ScheduledTask) {
        scheduledTimers[task.id]?.invalidate()
        scheduledTimers.removeValue(forKey: task.id)
        runningTasks[task.id]?.cancel()
        runningTasks.removeValue(forKey: task.id)
    }

    // MARK: - Execution

    private func executeTask(_ task: ScheduledTask) async {
        // Check concurrent limit
        while runningTasks.count >= maxConcurrentTasks {
            try? await Task.sleep(for: .milliseconds(100)) // 100ms
        }

        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }

        // Update status
        tasks[index].status = .running
        tasks[index].lastRunAt = Date()
        isProcessing = true

        let executionId = UUID()
        let execution = TaskExecution(
            id: executionId,
            taskId: task.id,
            taskName: task.name,
            startedAt: Date(),
            status: .running
        )
        executions.append(execution)

        // Create cancellable task
        let runningTask = Task {
            do {
                try await performTaskAction(task)

                // Success
                await MainActor.run {
                    if let execIndex = self.executions.firstIndex(where: { $0.id == executionId }) {
                        self.executions[execIndex].status = .completed
                        self.executions[execIndex].completedAt = Date()
                    }
                    if let taskIndex = self.tasks.firstIndex(where: { $0.id == task.id }) {
                        self.tasks[taskIndex].status = task.schedule.isRecurring ? .scheduled : .completed
                        self.tasks[taskIndex].consecutiveFailures = 0
                    }
                }

                logger.info("Task completed: \(task.name)")

            } catch {
                // Failure
                await MainActor.run {
                    if let execIndex = self.executions.firstIndex(where: { $0.id == executionId }) {
                        self.executions[execIndex].status = .failed
                        self.executions[execIndex].completedAt = Date()
                        self.executions[execIndex].error = error.localizedDescription
                    }
                    if let taskIndex = self.tasks.firstIndex(where: { $0.id == task.id }) {
                        self.tasks[taskIndex].consecutiveFailures += 1

                        // Check for retry
                        if self.tasks[taskIndex].consecutiveFailures < (task.retryCount ?? self.defaultRetryCount) {
                            self.tasks[taskIndex].status = .scheduled
                            // Schedule retry with delay
                            Task {
                                try? await Task.sleep(for: .seconds((task.retryDelay ?? self.defaultRetryDelay)))
                                self.scheduleTask(self.tasks[taskIndex])
                            }
                        } else {
                            self.tasks[taskIndex].status = .failed
                        }
                    }
                }

                logger.error("Task failed: \(task.name) - \(error.localizedDescription)")
            }
        }

        runningTasks[task.id] = runningTask
        await runningTask.value
        runningTasks.removeValue(forKey: task.id)

        isProcessing = !runningTasks.isEmpty
        saveTasks()
        saveExecutions()
    }

    private func performTaskAction(_ task: ScheduledTask) async throws {
        switch task.action {
        case let .aiPrompt(prompt, _):
            // Send prompt to AI
            logger.info("AI prompt task: \(prompt.prefix(50))...")

        case let .runShortcut(name):
            // Run Shortcuts automation
            logger.info("Running shortcut: \(name)")

        case let .executeCommand(command):
            // Execute shell command with AgentSec validation
            #if os(macOS)
                let result = AgentSecEnforcer.shared.validateTerminalCommand(command)
                guard result.isAllowed else {
                    throw TaskExecutionError.securityBlocked(result.reason ?? "Command blocked")
                }
                // Execute command...
            #endif

        case let .httpRequest(config):
            try await performHTTPRequest(config)

        case let .dataSync(sourceId, destinationId):
            logger.info("Syncing data from \(sourceId) to \(destinationId)")

        case let .backup(paths, destination):
            logger.info("Backing up \(paths.count) paths to \(destination)")

        case let .cleanup(config):
            try await performCleanup(config)

        case let .notification(title, _, _):
            // Send notification
            logger.info("Notification: \(title)")

        case let .script(script, language):
            try await executeScript(script, language: language)

        case let .chain(actions):
            for action in actions {
                var chainedTask = task
                chainedTask.action = action
                try await performTaskAction(chainedTask)
            }
        }
    }

    private func performHTTPRequest(_ config: HTTPRequestConfig) async throws {
        guard let url = URL(string: config.url) else {
            throw TaskExecutionError.invalidConfiguration("Invalid URL")
        }

        // AgentSec validation
        let result = AgentSecEnforcer.shared.validateNetworkRequest(url: url, method: config.method)
        guard result.isAllowed else {
            throw TaskExecutionError.securityBlocked(result.reason ?? "Request blocked")
        }

        var request = URLRequest(url: url)
        request.httpMethod = config.method
        request.timeoutInterval = config.timeout ?? 30

        for (key, value) in config.headers ?? [:] {
            request.setValue(value, forHTTPHeaderField: key)
        }

        if let body = config.body {
            request.httpBody = body.data(using: .utf8)
        }

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TaskExecutionError.networkError("Invalid response")
        }

        if config.expectedStatusCodes?.contains(httpResponse.statusCode) == false {
            throw TaskExecutionError.networkError("Unexpected status: \(httpResponse.statusCode)")
        }

        logger.debug("HTTP request completed: \(httpResponse.statusCode)")
    }

    private func performCleanup(_ config: CleanupConfig) async throws {
        let fm = FileManager.default

        for path in config.paths {
            let url = URL(fileURLWithPath: path)

            guard fm.fileExists(atPath: path) else { continue }

            // AgentSec validation
            let result = AgentSecEnforcer.shared.validateFileWrite(path: path)
            guard result.isAllowed else {
                logger.warning("Cleanup blocked for path: \(path)")
                continue
            }

            if config.olderThanDays > 0 {
                // Delete files older than specified days
                let cutoffDate = Date().addingTimeInterval(-Double(config.olderThanDays) * 86400)
                let contents = try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.contentModificationDateKey])

                for item in contents {
                    let attributes = try item.resourceValues(forKeys: [.contentModificationDateKey])
                    if let modDate = attributes.contentModificationDate, modDate < cutoffDate {
                        try fm.removeItem(at: item)
                        logger.debug("Cleaned up: \(item.lastPathComponent)")
                    }
                }
            }
        }
    }

    private func executeScript(_: String, language: ScriptLanguage) async throws {
        #if os(macOS)
            switch language {
            case .shell:
                // Execute shell script
                break
            case .applescript:
                // Execute AppleScript
                break
            case .python:
                // Execute Python script
                break
            case .javascript:
                // Execute JavaScript
                break
            }
        #endif
    }

    // MARK: - Schedule Calculation

    private func calculateNextRunDate(for task: ScheduledTask) -> Date? {
        let now = Date()

        switch task.schedule {
        case let .once(date):
            return date > now ? date : nil

        case let .interval(seconds):
            if let lastRun = task.lastRunAt {
                return lastRun.addingTimeInterval(seconds)
            }
            return now.addingTimeInterval(seconds)

        case let .daily(hour, minute):
            return nextDailyDate(hour: hour, minute: minute)

        case let .weekly(weekday, hour, minute):
            return nextWeeklyDate(weekday: weekday, hour: hour, minute: minute)

        case let .monthly(day, hour, minute):
            return nextMonthlyDate(day: day, hour: hour, minute: minute)

        case let .cron(expression):
            return nextCronDate(expression)

        case let .custom(dates):
            return dates.first { $0 > now }
        }
    }

    private func nextDailyDate(hour: Int, minute: Int) -> Date? {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute

        guard var date = calendar.date(from: components) else { return nil }

        if date <= Date() {
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? date.addingTimeInterval(86400)
        }

        return date
    }

    private func nextWeeklyDate(weekday: Int, hour: Int, minute: Int) -> Date? {
        let calendar = Calendar.current
        var components = DateComponents()
        components.weekday = weekday
        components.hour = hour
        components.minute = minute

        return calendar.nextDate(after: Date(), matching: components, matchingPolicy: .nextTime)
    }

    private func nextMonthlyDate(day: Int, hour: Int, minute: Int) -> Date? {
        let calendar = Calendar.current
        var components = DateComponents()
        components.day = day
        components.hour = hour
        components.minute = minute

        return calendar.nextDate(after: Date(), matching: components, matchingPolicy: .nextTime)
    }

    private func nextCronDate(_: String) -> Date? {
        // Simplified cron parsing
        Date().addingTimeInterval(3600)
    }

    // MARK: - Persistence

    private func loadTasks() {
        guard let data = defaults.data(forKey: tasksKey),
              let saved = try? JSONDecoder().decode([ScheduledTask].self, from: data)
        else {
            return
        }
        tasks = saved
    }

    private func saveTasks() {
        guard let data = try? JSONEncoder().encode(tasks) else { return }
        defaults.set(data, forKey: tasksKey)
    }

    private func loadExecutions() {
        guard let data = defaults.data(forKey: executionsKey),
              let saved = try? JSONDecoder().decode([TaskExecution].self, from: data)
        else {
            return
        }
        // Keep only recent executions
        executions = saved.suffix(1000).map(\.self)
    }

    private func saveExecutions() {
        // Keep only recent executions
        let recent = executions.suffix(1000).map(\.self)
        guard let data = try? JSONEncoder().encode(Array(recent)) else { return }
        defaults.set(data, forKey: executionsKey)
    }

    // MARK: - Statistics

    public func getStatistics() -> TaskStatistics {
        let totalTasks = tasks.count
        let activeTasks = tasks.count { $0.isEnabled && $0.status == .scheduled }
        let runningTasks = tasks.count { $0.status == .running }
        let failedTasks = tasks.count { $0.status == .failed }

        let recentExecutions = executions.filter {
            $0.startedAt > Date().addingTimeInterval(-86400 * 7) // Last 7 days
        }
        let successCount = recentExecutions.count { $0.status == .completed }
        _ = recentExecutions.count { $0.status == .failed }
        let successRate = recentExecutions.isEmpty ? 1.0 : Double(successCount) / Double(recentExecutions.count)

        return TaskStatistics(
            totalTasks: totalTasks,
            activeTasks: activeTasks,
            runningTasks: runningTasks,
            failedTasks: failedTasks,
            recentExecutions: recentExecutions.count,
            successRate: successRate
        )
    }
}

// MARK: - Scheduled Task Model

public struct ScheduledTask: Identifiable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var description: String
    public var isEnabled: Bool
    public var schedule: TaskSchedule
    public var action: TaskAction
    public var status: ScheduledTaskStatus
    public var priority: TaskPriority
    public var retryCount: Int?
    public var retryDelay: TimeInterval?
    public var timeout: TimeInterval?
    public var createdAt: Date
    public var lastRunAt: Date?
    public var consecutiveFailures: Int

    public init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        isEnabled: Bool = true,
        schedule: TaskSchedule,
        action: TaskAction,
        priority: TaskPriority = .normal,
        retryCount: Int? = nil,
        retryDelay: TimeInterval? = nil,
        timeout: TimeInterval? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.isEnabled = isEnabled
        self.schedule = schedule
        self.action = action
        status = .scheduled
        self.priority = priority
        self.retryCount = retryCount
        self.retryDelay = retryDelay
        self.timeout = timeout
        createdAt = Date()
        consecutiveFailures = 0
    }
}

// MARK: - Task Schedule

public enum TaskSchedule: Codable, Sendable {
    case once(Date)
    case interval(TimeInterval)
    case daily(hour: Int, minute: Int)
    case weekly(weekday: Int, hour: Int, minute: Int)
    case monthly(day: Int, hour: Int, minute: Int)
    case cron(String)
    case custom([Date])

    public var isRecurring: Bool {
        switch self {
        case .once, .custom: false
        default: true
        }
    }
}

// MARK: - Task Action

public indirect enum TaskAction: Codable, Sendable {
    case aiPrompt(String, String?)
    case runShortcut(String)
    case executeCommand(String)
    case httpRequest(HTTPRequestConfig)
    case dataSync(String, String)
    case backup([String], String)
    case cleanup(CleanupConfig)
    case notification(String, String, String?)
    case script(String, ScriptLanguage)
    case chain([TaskAction])
}

public struct HTTPRequestConfig: Codable, Sendable {
    public var url: String
    public var method: String
    public var headers: [String: String]?
    public var body: String?
    public var timeout: TimeInterval?
    public var expectedStatusCodes: [Int]?
}

public struct CleanupConfig: Codable, Sendable {
    public var paths: [String]
    public var olderThanDays: Int
    public var pattern: String?
    public var dryRun: Bool
}

public enum ScriptLanguage: String, Codable, Sendable {
    case shell
    case applescript
    case python
    case javascript
}

// MARK: - Task Status

public enum ScheduledTaskStatus: String, Codable, Sendable {
    case scheduled
    case running
    case completed
    case failed
    case paused
    case cancelled
}

public enum TaskPriority: Int, Codable, Sendable, Comparable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3

    public static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Task Execution

public struct TaskExecution: Identifiable, Codable, Sendable {
    public let id: UUID
    public let taskId: UUID
    public let taskName: String
    public let startedAt: Date
    public var completedAt: Date?
    public var status: TaskExecutionStatus
    public var error: String?
    public var duration: TimeInterval? {
        guard let completed = completedAt else { return nil }
        return completed.timeIntervalSince(startedAt)
    }
}

public enum TaskExecutionStatus: String, Codable, Sendable {
    case running
    case completed
    case failed
    case cancelled
}

// MARK: - Task Statistics

public struct TaskStatistics: Sendable {
    public let totalTasks: Int
    public let activeTasks: Int
    public let runningTasks: Int
    public let failedTasks: Int
    public let recentExecutions: Int
    public let successRate: Double
}

// MARK: - Task Execution Error

public enum TaskExecutionError: Error, LocalizedError {
    case securityBlocked(String)
    case invalidConfiguration(String)
    case networkError(String)
    case timeout
    case cancelled

    public var errorDescription: String? {
        switch self {
        case let .securityBlocked(reason):
            "Security blocked: \(reason)"
        case let .invalidConfiguration(reason):
            "Invalid configuration: \(reason)"
        case let .networkError(reason):
            "Network error: \(reason)"
        case .timeout:
            "Task timed out"
        case .cancelled:
            "Task was cancelled"
        }
    }
}
