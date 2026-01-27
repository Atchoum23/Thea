//
//  UnifiedContextSync.swift
//  Thea
//
//  Created by Thea
//  Delta sync for context changes across devices
//

import CloudKit
import Combine
import Foundation
import os.log

// MARK: - Unified Context Sync

/// Handles delta sync for context changes across devices
public actor UnifiedContextSync {
    public static let shared = UnifiedContextSync()

    private let logger = Logger(subsystem: "app.thea.sync", category: "ContextSync")

    // MARK: - CloudKit

    private let container: CKContainer
    private let database: CKDatabase
    private let zoneID: CKRecordZone.ID

    // MARK: - Change Tracking

    private var serverChangeToken: CKServerChangeToken?
    private var pendingChanges: [ContextChange] = []
    private let tokenKey = "ContextSync.serverChangeToken"

    // MARK: - Configuration

    private var syncInterval: TimeInterval = 500 // 500ms for near-real-time
    private var batchSize: Int = 50

    // MARK: - State

    private var isSyncing = false
    private var lastSyncTime: Date?
    private var syncTimer: Task<Void, Never>?

    // MARK: - Initialization

    private init() {
        container = CKContainer(identifier: "iCloud.app.thea")
        database = container.privateCloudDatabase
        zoneID = CKRecordZone.ID(zoneName: "TheaContext", ownerName: CKCurrentUserDefaultName)

        loadServerChangeToken()
    }

    // MARK: - Setup

    /// Initialize the context sync system
    public func initialize() async throws {
        // Create custom zone for efficient syncing
        try await createZoneIfNeeded()

        // Start background sync timer
        startSyncTimer()

        logger.info("Context sync initialized")
    }

    private func createZoneIfNeeded() async throws {
        let zone = CKRecordZone(zoneID: zoneID)

        do {
            _ = try await database.save(zone)
            logger.info("Created context sync zone")
        } catch let error as CKError where error.code == .zoneNotFound || error.code == .serverRejectedRequest {
            // Zone already exists or other expected error
            logger.debug("Zone already exists or creation skipped")
        }
    }

    // MARK: - Sync Timer

    private func startSyncTimer() {
        syncTimer?.cancel()
        syncTimer = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(syncInterval * 1_000_000_000))
                await performDeltaSync()
            }
        }
    }

    public func stopSync() {
        syncTimer?.cancel()
        syncTimer = nil
    }

    // MARK: - Delta Sync

    /// Fetch changes since last sync using server change token
    public func performDeltaSync() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        do {
            // Fetch remote changes
            let changes = try await fetchChanges()
            await processRemoteChanges(changes)

            // Push local changes
            try await pushPendingChanges()

            lastSyncTime = Date()

        } catch {
            logger.error("Delta sync failed: \(error.localizedDescription)")
        }
    }

    /// Fetch changes using CKFetchRecordZoneChangesOperation
    private func fetchChanges() async throws -> [ContextChange] {
        let configuration = CKFetchRecordZoneChangesOperation.ZoneConfiguration(
            previousServerChangeToken: serverChangeToken
        )

        var fetchedChanges: [ContextChange] = []
        var newToken: CKServerChangeToken?

        return try await withCheckedThrowingContinuation { continuation in
            let operation = CKFetchRecordZoneChangesOperation(
                recordZoneIDs: [zoneID],
                configurationsByRecordZoneID: [zoneID: configuration]
            )

            operation.recordWasChangedBlock = { _, result in
                if case let .success(record) = result {
                    let change = ContextChange(from: record)
                    fetchedChanges.append(change)
                }
            }

            operation.recordWithIDWasDeletedBlock = { recordID, recordType in
                let change = ContextChange(
                    id: recordID.recordName,
                    type: .delete,
                    contextType: recordType,
                    data: [:]
                )
                fetchedChanges.append(change)
            }

            operation.recordZoneChangeTokensUpdatedBlock = { _, token, _ in
                newToken = token
            }

            operation.recordZoneFetchResultBlock = { _, result in
                switch result {
                case let .success((token, _, _)):
                    newToken = token
                case let .failure(error):
                    self.logger.error("Zone fetch failed: \(error.localizedDescription)")
                }
            }

            operation.fetchRecordZoneChangesResultBlock = { result in
                if let token = newToken {
                    Task {
                        await self.saveServerChangeToken(token)
                    }
                }

                switch result {
                case .success:
                    continuation.resume(returning: fetchedChanges)
                case let .failure(error):
                    continuation.resume(throwing: error)
                }
            }

            database.add(operation)
        }
    }

    private func processRemoteChanges(_ changes: [ContextChange]) async {
        guard !changes.isEmpty else { return }

        logger.info("Processing \(changes.count) remote context changes")

        for change in changes {
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .contextChangeReceived,
                    object: nil,
                    userInfo: ["change": change]
                )
            }
        }
    }

    // MARK: - Push Changes

    /// Queue a local context change for sync
    public func queueChange(_ change: ContextChange) {
        pendingChanges.append(change)

        // Trigger immediate sync if batch is full
        if pendingChanges.count >= batchSize {
            Task {
                try? await pushPendingChanges()
            }
        }
    }

    /// Push all pending changes to CloudKit
    private func pushPendingChanges() async throws {
        guard !pendingChanges.isEmpty else { return }

        let changesToPush = pendingChanges
        pendingChanges.removeAll()

        var recordsToSave: [CKRecord] = []
        var recordIDsToDelete: [CKRecord.ID] = []

        for change in changesToPush {
            switch change.type {
            case .create, .update:
                recordsToSave.append(change.toRecord(zoneID: zoneID))
            case .delete:
                recordIDsToDelete.append(CKRecord.ID(recordName: change.id, zoneID: zoneID))
            }
        }

        let operation = CKModifyRecordsOperation(
            recordsToSave: recordsToSave,
            recordIDsToDelete: recordIDsToDelete
        )
        operation.savePolicy = .changedKeys

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case let .failure(error):
                    continuation.resume(throwing: error)
                }
            }

            database.add(operation)
        }

        logger.info("Pushed \(changesToPush.count) context changes")
    }

    // MARK: - Token Management

    private func loadServerChangeToken() {
        if let data = UserDefaults.standard.data(forKey: tokenKey) {
            do {
                serverChangeToken = try NSKeyedUnarchiver.unarchivedObject(
                    ofClass: CKServerChangeToken.self,
                    from: data
                )
            } catch {
                logger.error("Failed to load server change token: \(error)")
            }
        }
    }

    private func saveServerChangeToken(_ token: CKServerChangeToken) {
        serverChangeToken = token
        do {
            let data = try NSKeyedArchiver.archivedData(
                withRootObject: token,
                requiringSecureCoding: true
            )
            UserDefaults.standard.set(data, forKey: tokenKey)
        } catch {
            logger.error("Failed to save server change token: \(error)")
        }
    }

    /// Reset sync state (for debugging/recovery)
    public func resetSyncState() {
        serverChangeToken = nil
        UserDefaults.standard.removeObject(forKey: tokenKey)
        pendingChanges.removeAll()
        logger.info("Sync state reset")
    }
}

// MARK: - Context Change Model

public struct ContextChange: Sendable {
    public let id: String
    public let type: ChangeType
    public let contextType: String
    public let data: [String: SendableValue]
    public let timestamp: Date
    public let deviceId: String

    public enum ChangeType: String, Sendable {
        case create
        case update
        case delete
    }

    public init(
        id: String = UUID().uuidString,
        type: ChangeType,
        contextType: String,
        data: [String: SendableValue],
        timestamp: Date = Date(),
        deviceId: String = ""
    ) {
        self.id = id
        self.type = type
        self.contextType = contextType
        self.data = data
        self.timestamp = timestamp
        self.deviceId = deviceId.isEmpty ? (UserDefaults.standard.string(forKey: "DeviceRegistry.deviceId") ?? "") : deviceId
    }

    init(from record: CKRecord) {
        id = record.recordID.recordName
        type = ChangeType(rawValue: record["changeType"] as? String ?? "update") ?? .update
        contextType = record.recordType
        timestamp = record["timestamp"] as? Date ?? record.modificationDate ?? Date()
        deviceId = record["deviceId"] as? String ?? ""

        // Extract data fields
        var extractedData: [String: SendableValue] = [:]
        for key in record.allKeys() {
            if let value = record[key] {
                if let stringValue = value as? String {
                    extractedData[key] = .string(stringValue)
                } else if let intValue = value as? Int {
                    extractedData[key] = .int(intValue)
                } else if let doubleValue = value as? Double {
                    extractedData[key] = .double(doubleValue)
                } else if let dateValue = value as? Date {
                    extractedData[key] = .date(dateValue)
                } else if let dataValue = value as? Data {
                    extractedData[key] = .data(dataValue)
                }
            }
        }
        data = extractedData
    }

    func toRecord(zoneID: CKRecordZone.ID) -> CKRecord {
        let recordID = CKRecord.ID(recordName: id, zoneID: zoneID)
        let record = CKRecord(recordType: contextType, recordID: recordID)

        record["changeType"] = type.rawValue
        record["timestamp"] = timestamp
        record["deviceId"] = deviceId

        for (key, value) in data {
            switch value {
            case let .string(v): record[key] = v
            case let .int(v): record[key] = v
            case let .double(v): record[key] = v
            case let .date(v): record[key] = v
            case let .bool(v): record[key] = v ? 1 : 0
            case let .data(v): record[key] = v
            default: break
            }
        }

        return record
    }
}

// MARK: - Notification Names

public extension Notification.Name {
    static let contextChangeReceived = Notification.Name("contextChangeReceived")
    static let contextSyncCompleted = Notification.Name("contextSyncCompleted")
}
