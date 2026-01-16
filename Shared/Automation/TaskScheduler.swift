import Foundation

/// Task scheduler for recurring automation workflows
/// Matches ChatGPT Agent's scheduling capabilities
public actor TaskScheduler {
    public struct ScheduledTask: Sendable, Codable, Identifiable {
        public let id: UUID
        public let name: String
        public let schedule: Schedule
        public let actions: [String] // Serialized automation actions
        public let isActive: Bool
        public let createdAt: Date
        public var lastRun: Date?
        public var nextRun: Date?

        public init(
            id: UUID = UUID(),
            name: String,
            schedule: Schedule,
            actions: [String],
            isActive: Bool = true,
            createdAt: Date = Date(),
            lastRun: Date? = nil,
            nextRun: Date? = nil
        ) {
            self.id = id
            self.name = name
            self.schedule = schedule
            self.actions = actions
            self.isActive = isActive
            self.createdAt = createdAt
            self.lastRun = lastRun
            self.nextRun = nextRun
        }
    }

    public enum Schedule: Sendable, Codable {
        case daily(hour: Int, minute: Int)
        case weekly(dayOfWeek: Int, hour: Int, minute: Int) // 1=Sunday
        case monthly(day: Int, hour: Int, minute: Int)
        case custom(cronExpression: String)

        public var displayName: String {
            switch self {
            case .daily(let hour, let minute):
                return "Daily at \(hour):\(String(format: "%02d", minute))"
            case .weekly(let day, let hour, let minute):
                let dayName = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][day - 1]
                return "Weekly on \(dayName) at \(hour):\(String(format: "%02d", minute))"
            case .monthly(let day, let hour, let minute):
                return "Monthly on day \(day) at \(hour):\(String(format: "%02d", minute))"
            case .custom(let cron):
                return "Custom: \(cron)"
            }
        }
    }

    private var tasks: [ScheduledTask] = []
    private var timer: Task<Void, Never>?

    public init() {}

    // MARK: - Task Management

    public func scheduleTask(_ task: ScheduledTask) async {
        var updatedTask = task
        updatedTask.nextRun = calculateNextRun(for: task.schedule)
        tasks.append(updatedTask)
    }

    public func cancelTask(id: UUID) async throws {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else {
            throw SchedulerError.taskNotFound
        }
        tasks.remove(at: index)
    }

    public func updateTask(_ task: ScheduledTask) async throws {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else {
            throw SchedulerError.taskNotFound
        }
        var updatedTask = task
        updatedTask.nextRun = calculateNextRun(for: task.schedule)
        tasks[index] = updatedTask
    }

    public func getScheduledTasks() async -> [ScheduledTask] {
        tasks.sorted { ($0.nextRun ?? .distantFuture) < ($1.nextRun ?? .distantFuture) }
    }

    public func getUpcomingTasks(limit: Int = 10) async -> [ScheduledTask] {
        await getScheduledTasks()
            .filter { $0.isActive && $0.nextRun != nil }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Task Execution

    public func startScheduler() {
        timer?.cancel()

        timer = Task {
            while !Task.isCancelled {
                await checkAndExecuteTasks()

                // Check every minute
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }

    public func stopScheduler() {
        timer?.cancel()
        timer = nil
    }

    private func checkAndExecuteTasks() async {
        let now = Date()

        for (index, task) in tasks.enumerated() where task.isActive {
            guard let nextRun = task.nextRun, nextRun <= now else { continue }

            // Execute task
            await executeTask(task)

            // Update task for next run
            var updatedTask = task
            updatedTask.lastRun = now
            updatedTask.nextRun = calculateNextRun(for: task.schedule, after: now)
            tasks[index] = updatedTask
        }
    }

    private func executeTask(_ task: ScheduledTask) async {
        // In production, would deserialize actions and execute via AutomationEngine
        print("Executing scheduled task: \(task.name)")
    }

    // MARK: - Schedule Calculation

    private func calculateNextRun(for schedule: Schedule, after date: Date = Date()) -> Date? {
        let calendar = Calendar.current

        switch schedule {
        case .daily(let hour, let minute):
            var components = calendar.dateComponents([.year, .month, .day], from: date)
            components.hour = hour
            components.minute = minute
            components.second = 0

            guard let nextDate = calendar.date(from: components) else { return nil }

            if nextDate <= date {
                return calendar.date(byAdding: .day, value: 1, to: nextDate)
            }
            return nextDate

        case .weekly(let dayOfWeek, let hour, let minute):
            var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            components.weekday = dayOfWeek
            components.hour = hour
            components.minute = minute
            components.second = 0

            guard let nextDate = calendar.date(from: components) else { return nil }

            if nextDate <= date {
                return calendar.date(byAdding: .weekOfYear, value: 1, to: nextDate)
            }
            return nextDate

        case .monthly(let day, let hour, let minute):
            var components = calendar.dateComponents([.year, .month], from: date)
            components.day = day
            components.hour = hour
            components.minute = minute
            components.second = 0

            guard let nextDate = calendar.date(from: components) else { return nil }

            if nextDate <= date {
                return calendar.date(byAdding: .month, value: 1, to: nextDate)
            }
            return nextDate

        case .custom:
            // In production, would implement full cron parsing
            return calendar.date(byAdding: .day, value: 1, to: date)
        }
    }

    // MARK: - Statistics

    public func getTaskHistory(for taskId: UUID, limit: Int = 20) async -> [TaskExecution] {
        // In production, would return execution history
        []
    }

    public func getExecutionStats() async -> ExecutionStats {
        let totalTasks = tasks.count
        let activeTasks = tasks.filter(\.isActive).count
        let totalExecutions = 0 // Would track in production

        return ExecutionStats(
            totalTasks: totalTasks,
            activeTasks: activeTasks,
            totalExecutions: totalExecutions,
            averageExecutionTime: 0
        )
    }
}

// MARK: - Supporting Types

public struct TaskExecution: Sendable, Identifiable {
    public let id: UUID
    public let taskId: UUID
    public let executedAt: Date
    public let duration: TimeInterval
    public let success: Bool
    public let error: String?

    public init(
        id: UUID = UUID(),
        taskId: UUID,
        executedAt: Date,
        duration: TimeInterval,
        success: Bool,
        error: String? = nil
    ) {
        self.id = id
        self.taskId = taskId
        self.executedAt = executedAt
        self.duration = duration
        self.success = success
        self.error = error
    }
}

public struct ExecutionStats: Sendable {
    public let totalTasks: Int
    public let activeTasks: Int
    public let totalExecutions: Int
    public let averageExecutionTime: TimeInterval

    public init(
        totalTasks: Int,
        activeTasks: Int,
        totalExecutions: Int,
        averageExecutionTime: TimeInterval
    ) {
        self.totalTasks = totalTasks
        self.activeTasks = activeTasks
        self.totalExecutions = totalExecutions
        self.averageExecutionTime = averageExecutionTime
    }
}

// MARK: - Errors

public enum SchedulerError: Error, Sendable, LocalizedError {
    case taskNotFound
    case invalidSchedule
    case executionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .taskNotFound:
            return "The scheduled task was not found"
        case .invalidSchedule:
            return "The schedule configuration is invalid"
        case .executionFailed(let reason):
            return "Task execution failed: \(reason)"
        }
    }
}
