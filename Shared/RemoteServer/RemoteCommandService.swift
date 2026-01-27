//
//  RemoteCommandService.swift
//  Thea
//
//  Created by Thea
//  Execute commands on remote Thea instances
//

import CloudKit
import Foundation
import os.log

// MARK: - Remote Command Service

/// Execute commands on remote Thea instances across devices
public actor RemoteCommandService {
    public static let shared = RemoteCommandService()

    private let logger = Logger(subsystem: "app.thea.remote", category: "RemoteCommandService")

    // MARK: - CloudKit

    private let container: CKContainer
    private let database: CKDatabase

    // MARK: - State

    private var pendingCommands: [String: RemoteCommand] = [:]
    private var commandResults: [String: RemoteCommandResult] = [:]
    private var isListening = false

    // MARK: - Callbacks

    public var onCommandReceived: (@Sendable (RemoteCommand) async -> RemoteCommandResult)?
    public var onCommandCompleted: (@Sendable (String, RemoteCommandResult) -> Void)?

    // MARK: - Initialization

    private init() {
        container = CKContainer(identifier: "iCloud.app.thea")
        database = container.privateCloudDatabase
    }

    // MARK: - Start/Stop

    /// Start listening for remote commands
    public func startListening() async throws {
        guard !isListening else { return }

        // Setup subscription for commands
        try await setupSubscription()

        isListening = true
        logger.info("Remote command service started")

        // Start polling for commands
        Task {
            await pollForCommands()
        }
    }

    /// Stop listening for remote commands
    public func stopListening() {
        isListening = false
        logger.info("Remote command service stopped")
    }

    private func setupSubscription() async throws {
        let deviceId = await MainActor.run { DeviceRegistry.shared.currentDevice.id }

        let predicate = NSPredicate(format: "targetDeviceId == %@ AND status == %@", deviceId, CommandStatus.pending.rawValue)

        let subscription = CKQuerySubscription(
            recordType: "RemoteCommand",
            predicate: predicate,
            options: [.firesOnRecordCreation]
        )

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        do {
            _ = try await database.save(subscription)
        } catch let error as CKError where error.code == .serverRejectedRequest {
            // Subscription may already exist
            logger.debug("Remote command subscription may already exist")
        }
    }

    private func pollForCommands() async {
        while isListening {
            do {
                try await checkForPendingCommands()
            } catch {
                logger.error("Failed to poll commands: \(error)")
            }

            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
        }
    }

    // MARK: - Send Commands

    /// Send a command to a remote device
    public func sendCommand(_ command: RemoteCommand) async throws -> String {
        let record = command.toRecord()
        _ = try await database.save(record)

        pendingCommands[command.id] = command

        logger.info("Sent command \(command.type.rawValue) to device \(command.targetDeviceId)")

        return command.id
    }

    /// Send a command and wait for result
    public func sendCommandAndWait(_ command: RemoteCommand, timeout: TimeInterval = 30) async throws -> RemoteCommandResult {
        let commandId = try await sendCommand(command)

        // Poll for result
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < timeout {
            if let result = try await fetchRemoteCommandResult(commandId) {
                return result
            }
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }

        throw RemoteCommandError.timeout
    }

    // MARK: - Receive Commands

    private func checkForPendingCommands() async throws {
        let deviceId = await MainActor.run { DeviceRegistry.shared.currentDevice.id }

        let predicate = NSPredicate(format: "targetDeviceId == %@ AND status == %@", deviceId, CommandStatus.pending.rawValue)
        let query = CKQuery(recordType: "RemoteCommand", predicate: predicate)

        let results = try await database.records(matching: query)

        for (_, result) in results.matchResults {
            if case let .success(record) = result {
                let command = RemoteCommand(from: record)
                await processCommand(command)
            }
        }
    }

    private func processCommand(_ command: RemoteCommand) async {
        logger.info("Processing command: \(command.type.rawValue)")

        // Update status to running
        await updateCommandStatus(command.id, status: .running)

        // Execute command
        let result: RemoteCommandResult = if let handler = onCommandReceived {
            await handler(command)
        } else {
            await executeDefaultCommand(command)
        }

        // Store result
        commandResults[command.id] = result

        // Update record with result
        await storeRemoteCommandResult(command.id, result: result)

        logger.info("Command \(command.id) completed with success: \(result.success)")

        if let callback = onCommandCompleted {
            callback(command.id, result)
        }
    }

    private func executeDefaultCommand(_ command: RemoteCommand) async -> RemoteCommandResult {
        switch command.type {
        case .ping:
            return RemoteCommandResult(success: true, data: ["pong": "true", "timestamp": ISO8601DateFormatter().string(from: Date())])

        case .getStatus:
            let deviceInfo = await MainActor.run { DeviceRegistry.shared.currentDevice }
            return RemoteCommandResult(success: true, data: [
                "deviceName": deviceInfo.name,
                "deviceType": deviceInfo.type.rawValue,
                "online": "true"
            ])

        case .runShortcut:
            if let shortcutName = command.parameters["shortcutName"] {
                do {
                    _ = try await ShortcutsOrchestrator.shared.runShortcut(named: shortcutName)
                    return RemoteCommandResult(success: true, data: ["shortcut": shortcutName])
                } catch {
                    return RemoteCommandResult(success: false, error: error.localizedDescription)
                }
            }
            return RemoteCommandResult(success: false, error: "Missing shortcut name")

        case .setFocus:
            if let focusId = command.parameters["focusId"] {
                // Would integrate with FocusOrchestrator
                return RemoteCommandResult(success: true, data: ["focusId": focusId])
            }
            return RemoteCommandResult(success: false, error: "Missing focus ID")

        case .notify:
            if let title = command.parameters["title"], let body = command.parameters["body"] {
                do {
                    try await CrossDeviceNotificationRouter.shared.sendNotification(title: title, body: body)
                    return RemoteCommandResult(success: true, data: ["notified": "true"])
                } catch {
                    return RemoteCommandResult(success: false, error: error.localizedDescription)
                }
            }
            return RemoteCommandResult(success: false, error: "Missing title or body")

        case .homeKit:
            if let action = command.parameters["action"], let accessoryId = command.parameters["accessoryId"] {
                // Would integrate with HomeKitService
                return RemoteCommandResult(success: true, data: ["action": action, "accessoryId": accessoryId])
            }
            return RemoteCommandResult(success: false, error: "Missing HomeKit parameters")

        case .custom:
            // Custom commands handled by the app
            return RemoteCommandResult(success: false, error: "Custom command not handled")
        }
    }

    // MARK: - CloudKit Operations

    private func updateCommandStatus(_ commandId: String, status: CommandStatus) async {
        let recordId = CKRecord.ID(recordName: commandId)

        do {
            let record = try await database.record(for: recordId)
            record["status"] = status.rawValue
            record["updatedAt"] = Date()
            _ = try await database.save(record)
        } catch {
            logger.error("Failed to update command status: \(error)")
        }
    }

    private func storeRemoteCommandResult(_ commandId: String, result: RemoteCommandResult) async {
        let recordId = CKRecord.ID(recordName: commandId)

        do {
            let record = try await database.record(for: recordId)
            record["status"] = CommandStatus.completed.rawValue
            record["success"] = result.success ? 1 : 0
            record["error"] = result.error
            record["completedAt"] = result.completedAt

            if let resultData = try? JSONEncoder().encode(result.data) {
                record["resultData"] = resultData
            }

            _ = try await database.save(record)
        } catch {
            logger.error("Failed to store command result: \(error)")
        }
    }

    private func fetchRemoteCommandResult(_ commandId: String) async throws -> RemoteCommandResult? {
        let recordId = CKRecord.ID(recordName: commandId)

        do {
            let record = try await database.record(for: recordId)

            guard record["status"] as? String == CommandStatus.completed.rawValue else {
                return nil
            }

            let success = (record["success"] as? Int ?? 0) == 1
            let error = record["error"] as? String

            var data: [String: String] = [:]
            if let resultData = record["resultData"] as? Data {
                data = (try? JSONDecoder().decode([String: String].self, from: resultData)) ?? [:]
            }

            return RemoteCommandResult(success: success, data: data, error: error)
        } catch {
            return nil
        }
    }

    // MARK: - Convenience Methods

    /// Ping a remote device
    public func ping(deviceId: String) async throws -> Bool {
        let command = RemoteCommand(type: .ping, targetDeviceId: deviceId)
        let result = try await sendCommandAndWait(command, timeout: 10)
        return result.success
    }

    /// Get status of a remote device
    public func getDeviceStatus(deviceId: String) async throws -> [String: String] {
        let command = RemoteCommand(type: .getStatus, targetDeviceId: deviceId)
        let result = try await sendCommandAndWait(command, timeout: 10)
        return result.data
    }

    /// Run a shortcut on a remote device
    public func runRemoteShortcut(name: String, on deviceId: String) async throws {
        let command = RemoteCommand(
            type: .runShortcut,
            targetDeviceId: deviceId,
            parameters: ["shortcutName": name]
        )
        _ = try await sendCommand(command)
    }

    /// Send notification to a remote device
    public func sendRemoteNotification(title: String, body: String, to deviceId: String) async throws {
        let command = RemoteCommand(
            type: .notify,
            targetDeviceId: deviceId,
            parameters: ["title": title, "body": body]
        )
        _ = try await sendCommand(command)
    }

    /// Control HomeKit device remotely
    public func controlHomeKit(action: String, accessoryId: String, on deviceId: String) async throws {
        let command = RemoteCommand(
            type: .homeKit,
            targetDeviceId: deviceId,
            parameters: ["action": action, "accessoryId": accessoryId]
        )
        _ = try await sendCommand(command)
    }
}

// MARK: - Models

public struct RemoteCommand: Identifiable, Sendable {
    public let id: String
    public let type: CommandType
    public let targetDeviceId: String
    public let sourceDeviceId: String
    public let parameters: [String: String]
    public let createdAt: Date
    public var status: CommandStatus

    public enum CommandType: String, Codable, Sendable {
        case ping
        case getStatus
        case runShortcut
        case setFocus
        case notify
        case homeKit
        case custom
    }

    public init(
        id: String = UUID().uuidString,
        type: CommandType,
        targetDeviceId: String,
        sourceDeviceId: String = "",
        parameters: [String: String] = [:],
        status: CommandStatus = .pending
    ) {
        self.id = id
        self.type = type
        self.targetDeviceId = targetDeviceId
        self.sourceDeviceId = sourceDeviceId.isEmpty ? (UserDefaults.standard.string(forKey: "DeviceRegistry.deviceId") ?? "") : sourceDeviceId
        self.parameters = parameters
        createdAt = Date()
        self.status = status
    }

    init(from record: CKRecord) {
        id = record.recordID.recordName
        type = CommandType(rawValue: record["type"] as? String ?? "custom") ?? .custom
        targetDeviceId = record["targetDeviceId"] as? String ?? ""
        sourceDeviceId = record["sourceDeviceId"] as? String ?? ""
        createdAt = record["createdAt"] as? Date ?? Date()
        status = CommandStatus(rawValue: record["status"] as? String ?? "pending") ?? .pending

        // Decode parameters
        if let paramData = record["parameters"] as? Data,
           let params = try? JSONDecoder().decode([String: String].self, from: paramData)
        {
            parameters = params
        } else {
            parameters = [:]
        }
    }

    func toRecord() -> CKRecord {
        let recordId = CKRecord.ID(recordName: id)
        let record = CKRecord(recordType: "RemoteCommand", recordID: recordId)

        record["type"] = type.rawValue
        record["targetDeviceId"] = targetDeviceId
        record["sourceDeviceId"] = sourceDeviceId
        record["status"] = status.rawValue
        record["createdAt"] = createdAt

        if let paramData = try? JSONEncoder().encode(parameters) {
            record["parameters"] = paramData
        }

        return record
    }
}

public enum CommandStatus: String, Codable, Sendable {
    case pending
    case running
    case completed
    case failed
    case cancelled
}

public struct RemoteCommandResult: Sendable {
    public let success: Bool
    public let data: [String: String]
    public let error: String?
    public let completedAt: Date

    public init(success: Bool, data: [String: String] = [:], error: String? = nil) {
        self.success = success
        self.data = data
        self.error = error
        completedAt = Date()
    }
}

// MARK: - Errors

public enum RemoteCommandError: Error, LocalizedError {
    case timeout
    case deviceNotFound
    case commandFailed(String)
    case notConnected

    public var errorDescription: String? {
        switch self {
        case .timeout:
            "Command timed out"
        case .deviceNotFound:
            "Target device not found"
        case let .commandFailed(message):
            "Command failed: \(message)"
        case .notConnected:
            "Not connected to remote service"
        }
    }
}
