//
//  DistributedTaskExecutor.swift
//  Thea
//
//  Created by Thea
//  Execute tasks across devices with progress sync
//

import CloudKit
import Foundation
import os.log

// MARK: - Distributed Task Executor

/// Executes tasks across multiple devices with progress synchronization
public actor DistributedTaskExecutor {
    public static let shared = DistributedTaskExecutor()

    private let logger = Logger(subsystem: "app.thea.distributed", category: "TaskExecutor")

    // MARK: - CloudKit

    private let container: CKContainer
    private let database: CKDatabase

    // MARK: - Active Tasks

    private var activeTasks: [String: DistributedTask] = [:]
    private var taskSubscriptions: [String: Task<Void, Never>] = [:]

    // MARK: - Callbacks

    public var onTaskStarted: ((DistributedTask) -> Void)?
    public var onTaskProgress: ((String, Double, String?) -> Void)?
    public var onTaskCompleted: ((String, TaskResult) -> Void)?
    public var onTaskFailed: ((String, Error) -> Void)?

    // MARK: - Initialization

    private init() {
        container = CKContainer(identifier: "iCloud.app.theathe")
        database = container.privateCloudDatabase
    }

    // MARK: - Task Submission

    /// Submit a task for distributed execution
    public func submitTask(_ task: DistributedTask) async throws -> String {
        let taskId = task.id

        // Route to best device
        let routingDecision = await MainActor.run {
            DeviceCapabilityRouter.shared.findBestDevice(for: task.requirements)
        }

        var mutableTask = task
        mutableTask.targetDeviceId = routingDecision.targetDevice.id
        mutableTask.routingScore = routingDecision.score

        activeTasks[taskId] = mutableTask

        logger.info("Task \(taskId) routed to device \(routingDecision.targetDevice.name)")

        // If local execution, execute immediately
        if routingDecision.isLocalExecution {
            try await executeLocally(mutableTask)
        } else {
            // Push to CloudKit for remote execution
            try await pushTaskToCloud(mutableTask)

            // Start monitoring for results
            startMonitoringTask(taskId)
        }

        onTaskStarted?(mutableTask)

        return taskId
    }

    // MARK: - Local Execution

    private func executeLocally(_ task: DistributedTask) async throws {
        let taskId = task.id

        do {
            // Update status
            await updateTaskStatus(taskId, status: .running, progress: 0)

            // Execute the task
            let result = try await task.execute { progress, message in
                Task {
                    await self.updateTaskStatus(taskId, status: .running, progress: progress, message: message)
                }
            }

            // Mark complete
            await updateTaskStatus(taskId, status: .completed, progress: 1.0)

            onTaskCompleted?(taskId, result)

        } catch {
            await updateTaskStatus(taskId, status: .failed, message: error.localizedDescription)
            onTaskFailed?(taskId, error)
            throw error
        }
    }

    // MARK: - Remote Execution

    private func pushTaskToCloud(_ task: DistributedTask) async throws {
        let record = task.toRecord()
        _ = try await database.save(record)
        logger.info("Task \(task.id) pushed to CloudKit for remote execution")
    }

    private func startMonitoringTask(_ taskId: String) {
        let monitorTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1)) // 1 second

                if let updatedTask = await fetchTaskStatus(taskId) {
                    if updatedTask.status == .completed {
                        if let result = updatedTask.result {
                            onTaskCompleted?(taskId, result)
                        }
                        break
                    } else if updatedTask.status == .failed {
                        onTaskFailed?(taskId, DistributedTaskError.remoteFailed(updatedTask.errorMessage ?? "Unknown error"))
                        break
                    } else {
                        onTaskProgress?(taskId, updatedTask.progress, updatedTask.statusMessage)
                    }
                }
            }
        }
        taskSubscriptions[taskId] = monitorTask
    }

    private func fetchTaskStatus(_ taskId: String) async -> DistributedTask? {
        let recordId = CKRecord.ID(recordName: taskId)

        do {
            let record = try await database.record(for: recordId)
            return DistributedTask(from: record)
        } catch {
            return nil
        }
    }

    // MARK: - Status Updates

    private func updateTaskStatus(
        _ taskId: String,
        status: DistributedTask.Status,
        progress: Double? = nil,
        message: String? = nil
    ) async {
        guard var task = activeTasks[taskId] else { return }

        task.status = status
        if let progress {
            task.progress = progress
        }
        if let message {
            task.statusMessage = message
        }

        activeTasks[taskId] = task

        // Push update to CloudKit for remote tasks
        let localDeviceId = await DeviceRegistry.shared.currentDevice.id
        if task.targetDeviceId != localDeviceId {
            do {
                try await pushTaskUpdate(task)
            } catch {
                logger.error("Failed to push task update to CloudKit for task \(taskId): \(error.localizedDescription)")
            }
        }

        onTaskProgress?(taskId, task.progress, task.statusMessage)
    }

    private func pushTaskUpdate(_ task: DistributedTask) async throws {
        let recordId = CKRecord.ID(recordName: task.id)

        do {
            let record = try await database.record(for: recordId)
            record["status"] = task.status.rawValue
            record["progress"] = task.progress
            record["statusMessage"] = task.statusMessage
            record["updatedAt"] = Date()
            _ = try await database.save(record)
        } catch {
            logger.error("Failed to push task update: \(error)")
        }
    }

    // MARK: - Task Control

    /// Cancel a running task
    public func cancelTask(_ taskId: String) async throws {
        guard var task = activeTasks[taskId] else {
            throw DistributedTaskError.taskNotFound
        }

        task.status = .cancelled
        activeTasks[taskId] = task

        // Cancel local monitoring
        taskSubscriptions[taskId]?.cancel()
        taskSubscriptions.removeValue(forKey: taskId)

        // Update CloudKit
        try await pushTaskUpdate(task)

        logger.info("Task \(taskId) cancelled")
    }

    /// Get task status
    public func getTaskStatus(_ taskId: String) -> DistributedTask? {
        activeTasks[taskId]
    }

    /// Get all active tasks
    public func getActiveTasks() -> [DistributedTask] {
        Array(activeTasks.values)
    }

    // MARK: - Remote Task Pickup (called by receiving device)

    /// Check for and execute pending tasks assigned to this device
    public func checkForPendingTasks() async throws {
        let currentDeviceId = await MainActor.run {
            DeviceRegistry.shared.currentDevice.id
        }

        let predicate = NSPredicate(format: "targetDeviceId == %@ AND status == %@", currentDeviceId, DistributedTask.Status.pending.rawValue)
        let query = CKQuery(recordType: "DistributedTask", predicate: predicate)

        let results = try await database.records(matching: query)

        for (_, result) in results.matchResults {
            if case let .success(record) = result {
                let task = DistributedTask(from: record)
                activeTasks[task.id] = task

                // Execute the task
                Task {
                    do {
                        try await executeLocally(task)
                    } catch {
                        logger.error("Failed to execute remote task \(task.id): \(error)")
                    }
                }
            }
        }
    }
}

// MARK: - Distributed Task Model

public struct DistributedTask: Identifiable, Sendable {
    public let id: String
    public let taskType: TaskType
    public let requirements: TaskRequirements
    public let payload: TaskPayload
    public var targetDeviceId: String?
    public var routingScore: Double
    public var status: Status
    public var progress: Double
    public var statusMessage: String?
    public var errorMessage: String?
    public var result: TaskResult?
    public let createdAt: Date
    public var updatedAt: Date

    public enum TaskType: String, Codable, Sendable {
        case aiQuery = "ai_query"
        case fileProcess = "file_process"
        case imageAnalysis = "image_analysis"
        case textSummarization = "text_summarization"
        case codeGeneration = "code_generation"
        case backgroundSync = "background_sync"
        case dataExport = "data_export"
        case custom
    }

    public enum Status: String, Codable, Sendable {
        case pending
        case running
        case completed
        case failed
        case cancelled
    }

    public init(
        id: String = UUID().uuidString,
        taskType: TaskType,
        requirements: TaskRequirements = TaskRequirements(),
        payload: TaskPayload = TaskPayload(),
        targetDeviceId: String? = nil,
        routingScore: Double = 0,
        status: Status = .pending,
        progress: Double = 0,
        statusMessage: String? = nil
    ) {
        self.id = id
        self.taskType = taskType
        self.requirements = requirements
        self.payload = payload
        self.targetDeviceId = targetDeviceId
        self.routingScore = routingScore
        self.status = status
        self.progress = progress
        self.statusMessage = statusMessage
        createdAt = Date()
        updatedAt = Date()
    }

    init(from record: CKRecord) {
        id = record.recordID.recordName
        taskType = TaskType(rawValue: record["taskType"] as? String ?? "custom") ?? .custom
        requirements = TaskRequirements() // Would decode from record
        payload = TaskPayload() // Would decode from record
        targetDeviceId = record["targetDeviceId"] as? String
        routingScore = record["routingScore"] as? Double ?? 0
        status = Status(rawValue: record["status"] as? String ?? "pending") ?? .pending
        progress = record["progress"] as? Double ?? 0
        statusMessage = record["statusMessage"] as? String
        errorMessage = record["errorMessage"] as? String
        createdAt = record["createdAt"] as? Date ?? Date()
        updatedAt = record["updatedAt"] as? Date ?? Date()
    }

    func toRecord() -> CKRecord {
        let recordId = CKRecord.ID(recordName: id)
        let record = CKRecord(recordType: "DistributedTask", recordID: recordId)

        record["taskType"] = taskType.rawValue
        record["targetDeviceId"] = targetDeviceId
        record["routingScore"] = routingScore
        record["status"] = status.rawValue
        record["progress"] = progress
        record["statusMessage"] = statusMessage
        record["errorMessage"] = errorMessage
        record["createdAt"] = createdAt
        record["updatedAt"] = Date()

        // Encode payload as JSON data
        do {
            let payloadData = try JSONEncoder().encode(payload)
            record["payload"] = payloadData
        } catch {
            Logger(subsystem: "app.thea.distributed", category: "TaskExecutor")
                .warning("Failed to encode task payload: \(error.localizedDescription)")
        }

        return record
    }

    /// Execute the task (called on the executing device)
    func execute(progressHandler: @escaping @Sendable (Double, String?) -> Void) async throws -> TaskResult {
        switch taskType {
        case .aiQuery:
            try await executeAIQuery(progressHandler: progressHandler)
        case .textSummarization:
            try await executeSummarization(progressHandler: progressHandler)
        case .imageAnalysis:
            try await executeImageAnalysis(progressHandler: progressHandler)
        case .codeGeneration:
            try await executeCodeGeneration(progressHandler: progressHandler)
        default:
            try await executeGeneric(progressHandler: progressHandler)
        }
    }

    private func executeAIQuery(progressHandler: @escaping @Sendable (Double, String?) -> Void) async throws -> TaskResult {
        progressHandler(0.2, "Processing query...")
        // Simulated AI processing
        try await Task.sleep(for: .seconds(2))
        progressHandler(0.8, "Generating response...")
        try await Task.sleep(for: .milliseconds(500))
        return TaskResult(success: true, data: ["response": "AI response"])
    }

    private func executeSummarization(progressHandler: @escaping @Sendable (Double, String?) -> Void) async throws -> TaskResult {
        progressHandler(0.3, "Analyzing text...")
        try await Task.sleep(for: .seconds(1))
        progressHandler(0.7, "Generating summary...")
        try await Task.sleep(for: .milliseconds(500))
        return TaskResult(success: true, data: ["summary": "Text summary"])
    }

    private func executeImageAnalysis(progressHandler: @escaping @Sendable (Double, String?) -> Void) async throws -> TaskResult {
        progressHandler(0.2, "Loading image...")
        try await Task.sleep(for: .milliseconds(500))
        progressHandler(0.5, "Analyzing...")
        try await Task.sleep(for: .seconds(1))
        return TaskResult(success: true, data: ["analysis": "Image analysis result"])
    }

    private func executeCodeGeneration(progressHandler: @escaping @Sendable (Double, String?) -> Void) async throws -> TaskResult {
        progressHandler(0.1, "Parsing requirements...")
        try await Task.sleep(for: .milliseconds(500))
        progressHandler(0.5, "Generating code...")
        try await Task.sleep(for: .seconds(2))
        return TaskResult(success: true, data: ["code": "Generated code"])
    }

    private func executeGeneric(progressHandler: @escaping @Sendable (Double, String?) -> Void) async throws -> TaskResult {
        progressHandler(0.5, "Processing...")
        try await Task.sleep(for: .seconds(1))
        return TaskResult(success: true, data: [:])
    }
}

// MARK: - Task Payload

public struct TaskPayload: Codable, Sendable {
    public var inputText: String?
    public var inputData: Data?
    public var parameters: [String: String]
    public var options: [String: Bool]

    public init(
        inputText: String? = nil,
        inputData: Data? = nil,
        parameters: [String: String] = [:],
        options: [String: Bool] = [:]
    ) {
        self.inputText = inputText
        self.inputData = inputData
        self.parameters = parameters
        self.options = options
    }
}

// MARK: - Task Result

public struct TaskResult: Sendable {
    public let success: Bool
    public let data: [String: String]
    public let outputData: Data?
    public let completedAt: Date

    public init(
        success: Bool,
        data: [String: String] = [:],
        outputData: Data? = nil
    ) {
        self.success = success
        self.data = data
        self.outputData = outputData
        completedAt = Date()
    }
}

// MARK: - Distributed Task Error

public enum DistributedTaskError: Error, LocalizedError {
    case taskNotFound
    case executionFailed(String)
    case remoteFailed(String)
    case cancelled
    case timeout

    public var errorDescription: String? {
        switch self {
        case .taskNotFound:
            "Task not found"
        case let .executionFailed(message):
            "Execution failed: \(message)"
        case let .remoteFailed(message):
            "Remote execution failed: \(message)"
        case .cancelled:
            "Task was cancelled"
        case .timeout:
            "Task timed out"
        }
    }
}
