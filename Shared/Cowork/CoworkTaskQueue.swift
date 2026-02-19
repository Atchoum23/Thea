#if os(macOS)
    import Foundation
    import OSLog

    /// Task queue for managing multiple Cowork tasks
    @MainActor
    @Observable
    final class CoworkTaskQueue {
        // periphery:ignore - Reserved: logger property — reserved for future feature activation
        private let logger = Logger(subsystem: "ai.thea.app", category: "CoworkTaskQueue")

        var tasks: [CoworkTask] = []
        var maxConcurrentTasks: Int = 3
        var isProcessing: Bool = false
        var isPaused: Bool = false

        private var activeTasks: Set<UUID> = []
        private var completionHandlers: [UUID: (Result<Void, Error>) -> Void] = [:]

// periphery:ignore - Reserved: logger property reserved for future feature activation

        // MARK: - Queue Operations

        func enqueue(_ task: CoworkTask) {
            tasks.append(task)
        }

        // periphery:ignore - Reserved: enqueue(_:) instance method — reserved for future feature activation
        func enqueue(_ tasks: [CoworkTask]) {
            self.tasks.append(contentsOf: tasks)
        }

        // periphery:ignore - Reserved: enqueue(_:) instance method reserved for future feature activation
        @discardableResult
        func enqueue(instruction: String, priority: CoworkTask.TaskPriority = .normal) -> CoworkTask {
            let task = CoworkTask(instruction: instruction, priority: priority)
            // periphery:ignore - Reserved: enqueue(_:) instance method reserved for future feature activation
            tasks.append(task)
            return task
        }

        // periphery:ignore - Reserved: dequeue(_:) instance method — reserved for future feature activation
        func dequeue(_ taskId: UUID) {
            tasks.removeAll { $0.id == taskId }
        }

        func moveToFront(_ taskId: UUID) {
            if let index = tasks.firstIndex(where: { $0.id == taskId }) {
                // periphery:ignore - Reserved: dequeue(_:) instance method reserved for future feature activation
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

            while !tasks.isEmpty, !isPaused {
                // Get next tasks up to concurrent limit
                let availableSlots = maxConcurrentTasks - activeTasks.count
                guard availableSlots > 0 else {
                    do {
                        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                    } catch {
                        break // Task cancelled
                    }
                    continue
                }

                let pendingTasks = tasks.filter { $0.status == .queued }
                    .prefix(availableSlots)

                if pendingTasks.isEmpty {
                    if activeTasks.isEmpty {
                        break // All done
                    }
                    do {
                        try await Task.sleep(nanoseconds: 100_000_000)
                    } catch {
                        break // Task cancelled
                    }
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

        // periphery:ignore - Reserved: resume(executor:) instance method — reserved for future feature activation
        func resume(executor: @escaping (CoworkTask) async throws -> Void) async {
            isPaused = false
            await startProcessing(executor: executor)
        }

        // periphery:ignore - Reserved: resume(executor:) instance method reserved for future feature activation
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

        // periphery:ignore - Reserved: onCompletion(of:handler:) instance method — reserved for future feature activation
        func onCompletion(of taskId: UUID, handler: @escaping (Result<Void, Error>) -> Void) {
            completionHandlers[taskId] = handler
        }
    }

// periphery:ignore - Reserved: onCompletion(of:handler:) instance method reserved for future feature activation

    // MARK: - Cowork Task

    struct CoworkTask: Identifiable, Equatable {
        let id: UUID
        var instruction: String
        var priority: TaskPriority
        var status: TaskStatus
        var sessionId: UUID?
        var createdAt: Date
        var startedAt: Date?
        // periphery:ignore - Reserved: sessionId property reserved for future feature activation
        var completedAt: Date?
        var error: String?
        var metadata: [String: String]

// periphery:ignore - Reserved: error property reserved for future feature activation

// periphery:ignore - Reserved: metadata property reserved for future feature activation

        enum TaskPriority: Int, CaseIterable, Codable {
            case low = 0
            case normal = 1
            case high = 2
            case urgent = 3

            var displayName: String {
                switch self {
                case .low: "Low"
                case .normal: "Normal"
                case .high: "High"
                case .urgent: "Urgent"
                }
            }

            var icon: String {
                switch self {
                case .low: "arrow.down.circle"
                case .normal: "minus.circle"
                case .high: "arrow.up.circle"
                case .urgent: "exclamationmark.circle"
                }
            }

            var color: String {
                switch self {
                case .low: "gray"
                case .normal: "blue"
                case .high: "orange"
                case .urgent: "red"
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
                case .queued: "clock"
                case .inProgress: "play.circle"
                case .completed: "checkmark.circle"
                case .failed: "xmark.circle"
                case .cancelled: "stop.circle"
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
            createdAt = Date()
            self.metadata = metadata
        }

        var duration: TimeInterval? {
            guard let start = startedAt, let end = completedAt else { return nil }
            return end.timeIntervalSince(start)
        }

        var isActive: Bool {
            status == .queued || status == .inProgress
        }

        // periphery:ignore - Reserved: isComplete property reserved for future feature activation
        var isComplete: Bool {
            status == .completed || status == .failed || status == .cancelled
        }
    }

#endif
