#if os(macOS)
import Foundation

/// Task queue for managing multiple Cowork tasks
@MainActor
@Observable
final class CoworkTaskQueue {
    var tasks: [CoworkTask] = []
    var maxConcurrentTasks: Int = 3
    var isProcessing: Bool = false
    var isPaused: Bool = false

    private var activeTasks: Set<UUID> = []
    private var completionHandlers: [UUID: (Result<Void, Error>) -> Void] = [:]

    // MARK: - Queue Operations

    func enqueue(_ task: CoworkTask) {
        tasks.append(task)
    }

    func enqueue(_ tasks: [CoworkTask]) {
        self.tasks.append(contentsOf: tasks)
    }

    @discardableResult
    func enqueue(instruction: String, priority: CoworkTask.TaskPriority = .normal) -> CoworkTask {
        let task = CoworkTask(instruction: instruction, priority: priority)
        tasks.append(task)
        return task
    }

    func dequeue(_ taskId: UUID) {
        tasks.removeAll { $0.id == taskId }
    }

    func moveToFront(_ taskId: UUID) {
        if let index = tasks.firstIndex(where: { $0.id == taskId }) {
            let task = tasks.remove(at: index)
            tasks.insert(task, at: 0)
        }
    }

    func changePriority(_ taskId: UUID, to priority: CoworkTask.TaskPriority) {
        if let index = tasks.firstIndex(where: { $0.id == taskId }) {
            tasks[index].priority = priority
        }
        sortByPriority()
    }

    // MARK: - Processing

    func startProcessing(executor: @escaping (CoworkTask) async throws -> Void) async {
        guard !isProcessing else { return }
        isProcessing = true

        while !tasks.isEmpty && !isPaused {
            // Get next tasks up to concurrent limit
            let availableSlots = maxConcurrentTasks - activeTasks.count
            guard availableSlots > 0 else {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                continue
            }

            let pendingTasks = tasks.filter { $0.status == .queued }
                .prefix(availableSlots)

            if pendingTasks.isEmpty {
                if activeTasks.isEmpty {
                    break // All done
                }
                try? await Task.sleep(nanoseconds: 100_000_000)
                continue
            }

            // Start tasks concurrently
            for task in pendingTasks {
                let taskId = task.id
                activeTasks.insert(taskId)

                if let index = tasks.firstIndex(where: { $0.id == taskId }) {
                    tasks[index].status = .inProgress
                    tasks[index].startedAt = Date()
                }

                do {
                    try await executor(task)
                    if let index = tasks.firstIndex(where: { $0.id == taskId }) {
                        tasks[index].status = .completed
                        tasks[index].completedAt = Date()
                    }
                    activeTasks.remove(taskId)
                    completionHandlers[taskId]?(.success(()))
                    completionHandlers.removeValue(forKey: taskId)
                } catch {
                    if let index = tasks.firstIndex(where: { $0.id == taskId }) {
                        tasks[index].status = .failed
                        tasks[index].completedAt = Date()
                        tasks[index].error = error.localizedDescription
                    }
                    activeTasks.remove(taskId)
                    completionHandlers[taskId]?(.failure(error))
                    completionHandlers.removeValue(forKey: taskId)
                }
            }
        }

        isProcessing = false
    }

    func pause() {
        isPaused = true
    }

    func resume(executor: @escaping (CoworkTask) async throws -> Void) async {
        isPaused = false
        await startProcessing(executor: executor)
    }

    func cancelAll() {
        isPaused = true
        for index in tasks.indices {
            if tasks[index].status == .queued || tasks[index].status == .inProgress {
                tasks[index].status = .cancelled
            }
        }
        activeTasks.removeAll()
        isProcessing = false
    }

    func cancelTask(_ taskId: UUID) {
        if let index = tasks.firstIndex(where: { $0.id == taskId }) {
            tasks[index].status = .cancelled
        }
        activeTasks.remove(taskId)
    }

    func clearCompleted() {
        tasks.removeAll { $0.status == .completed || $0.status == .cancelled || $0.status == .failed }
    }

    // MARK: - Queries

    var queuedTasks: [CoworkTask] {
        tasks.filter { $0.status == .queued }
    }

    var inProgressTasks: [CoworkTask] {
        tasks.filter { $0.status == .inProgress }
    }

    var completedTasks: [CoworkTask] {
        tasks.filter { $0.status == .completed }
    }

    var failedTasks: [CoworkTask] {
        tasks.filter { $0.status == .failed }
    }

    var pendingCount: Int {
        queuedTasks.count
    }

    var activeCount: Int {
        inProgressTasks.count
    }

    // MARK: - Helpers

    private func sortByPriority() {
        tasks.sort { $0.priority.rawValue > $1.priority.rawValue }
    }

    func onCompletion(of taskId: UUID, handler: @escaping (Result<Void, Error>) -> Void) {
        completionHandlers[taskId] = handler
    }
}

// MARK: - Cowork Task

struct CoworkTask: Identifiable, Equatable {
    let id: UUID
    var instruction: String
    var priority: TaskPriority
    var status: TaskStatus
    var sessionId: UUID?
    var createdAt: Date
    var startedAt: Date?
    var completedAt: Date?
    var error: String?
    var metadata: [String: String]

    enum TaskPriority: Int, CaseIterable, Codable {
        case low = 0
        case normal = 1
        case high = 2
        case urgent = 3

        var displayName: String {
            switch self {
            case .low: return "Low"
            case .normal: return "Normal"
            case .high: return "High"
            case .urgent: return "Urgent"
            }
        }

        var icon: String {
            switch self {
            case .low: return "arrow.down.circle"
            case .normal: return "minus.circle"
            case .high: return "arrow.up.circle"
            case .urgent: return "exclamationmark.circle"
            }
        }

        var color: String {
            switch self {
            case .low: return "gray"
            case .normal: return "blue"
            case .high: return "orange"
            case .urgent: return "red"
            }
        }
    }

    enum TaskStatus: String, CaseIterable, Codable {
        case queued = "Queued"
        case inProgress = "In Progress"
        case completed = "Completed"
        case failed = "Failed"
        case cancelled = "Cancelled"

        var icon: String {
            switch self {
            case .queued: return "clock"
            case .inProgress: return "play.circle"
            case .completed: return "checkmark.circle"
            case .failed: return "xmark.circle"
            case .cancelled: return "stop.circle"
            }
        }
    }

    init(
        id: UUID = UUID(),
        instruction: String,
        priority: TaskPriority = .normal,
        status: TaskStatus = .queued,
        sessionId: UUID? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.instruction = instruction
        self.priority = priority
        self.status = status
        self.sessionId = sessionId
        self.createdAt = Date()
        self.metadata = metadata
    }

    var duration: TimeInterval? {
        guard let start = startedAt, let end = completedAt else { return nil }
        return end.timeIntervalSince(start)
    }

    var isActive: Bool {
        status == .queued || status == .inProgress
    }

    var isComplete: Bool {
        status == .completed || status == .failed || status == .cancelled
    }
}

#endif
