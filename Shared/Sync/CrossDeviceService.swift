//
//  CrossDeviceService.swift
//  Thea
//
//  Created by Claude Code on 2026-01-20
//  Copyright © 2026. All rights reserved.
//

import CloudKit
import Combine
import Foundation

// MARK: - Cross Device Service

/// Central service for cross-device synchronization
public actor CrossDeviceService {
    public static let shared = CrossDeviceService()

    // MARK: - State

    private var isInitialized = false
    private var syncEnabled = false
    private var lastSyncTime: Date?

    // MARK: - CloudKit

    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let sharedDatabase: CKDatabase

    // MARK: - Configuration

    private var configuration: CrossDeviceSyncConfiguration

    // MARK: - Subscriptions

    private var subscriptions: [CKSubscription.ID: CKSubscription] = [:]

    // MARK: - Initialization

    private init() {
        container = CKContainer.default()
        privateDatabase = container.privateCloudDatabase
        sharedDatabase = container.sharedCloudDatabase
        configuration = CrossDeviceSyncConfiguration.load()
    }

    // MARK: - Setup

    /// Initialize the sync service
    public func initialize() async throws {
        guard !isInitialized else { return }

        // Check iCloud account status
        let status = try await container.accountStatus()
        guard status == .available else {
            throw CrossDeviceSyncError.iCloudNotAvailable
        }

        // Setup subscriptions
        try await setupSubscriptions()

        isInitialized = true
        syncEnabled = configuration.autoSyncEnabled
    }

    /// Setup CloudKit subscriptions for real-time sync
    private func setupSubscriptions() async throws {
        // Subscribe to conversation changes
        let subscriptionID = "conversation-changes-\(UUID().uuidString)"
        let conversationSubscription = CKQuerySubscription(
            recordType: "Conversation",
            predicate: NSPredicate(value: true),
            subscriptionID: subscriptionID,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        conversationSubscription.notificationInfo = notificationInfo

        do {
            let savedSubscription = try await privateDatabase.save(conversationSubscription)
            subscriptions[savedSubscription.subscriptionID] = savedSubscription
        } catch let error as CKError where error.code == .serverRejectedRequest {
            // Subscription may already exist
        }
    }

    // MARK: - Sync Operations

    /// Perform a full sync
    public func performFullSync() async throws {
        guard syncEnabled else {
            throw CrossDeviceSyncError.syncDisabled
        }

        // Sync conversations
        try await syncConversations()

        // Sync settings
        try await syncSettings()

        // Sync device registry
        try await syncDeviceRegistry()

        lastSyncTime = Date()
    }

    /// Sync conversations to/from CloudKit
    private func syncConversations() async throws {
        // Fetch remote changes
        let query = CKQuery(recordType: "Conversation", predicate: NSPredicate(value: true))
        let results = try await privateDatabase.records(matching: query)

        // Process results
        for (_, result) in results.matchResults {
            switch result {
            case let .success(record):
                await processConversationRecord(record)
            case .failure:
                continue
            }
        }
    }

    private func processConversationRecord(_: CKRecord) async {
        // Convert CKRecord to local model
        // This would integrate with the existing conversation storage
    }

    /// Sync settings
    private func syncSettings() async throws {
        // Sync user preferences that should be shared across devices
    }

    /// Sync device registry
    private func syncDeviceRegistry() async throws {
        // Update current device presence
        await MainActor.run {
            DeviceRegistry.shared.updatePresence()
        }

        // Sync device list via CloudKit
        let deviceInfo = await MainActor.run {
            DeviceRegistry.shared.currentDevice
        }

        let record = CKRecord(recordType: "Device")
        record["deviceId"] = deviceInfo.id
        record["name"] = deviceInfo.name
        record["type"] = deviceInfo.type.rawValue
        record["lastSeen"] = deviceInfo.lastSeen

        _ = try await privateDatabase.save(record)
    }

    // MARK: - Push Changes

    /// Push a local change to CloudKit
    public func pushChange(_ change: SyncChange) async throws {
        guard syncEnabled else { return }

        let record = change.toCKRecord()
        _ = try await privateDatabase.save(record)
    }

    // MARK: - Conflict Resolution

    /// Resolve a sync conflict
    public func resolveConflict(
        _ conflict: SyncConflict,
        resolution: ConflictResolution
    ) async throws {
        switch resolution {
        case .keepLocal:
            try await pushChange(conflict.localChange)
        case .keepRemote:
            await applyRemoteChange(conflict.remoteChange)
        case .merge:
            let merged = try conflict.merge()
            try await pushChange(merged)
        }
    }

    private func applyRemoteChange(_: SyncChange) async {
        // Apply the remote change to local storage
    }

    // MARK: - Configuration

    /// Update sync configuration
    public func updateConfiguration(_ config: CrossDeviceSyncConfiguration) {
        configuration = config
        config.save()
        syncEnabled = config.autoSyncEnabled
    }

    public func getConfiguration() -> CrossDeviceSyncConfiguration {
        configuration
    }

    // MARK: - Status

    /// Get sync status
    public func getStatus() async -> SyncStatus {
        let accountStatus: CKAccountStatus
        do {
            accountStatus = try await container.accountStatus()
        } catch {
            accountStatus = .couldNotDetermine
        }

        return SyncStatus(
            isInitialized: isInitialized,
            isEnabled: syncEnabled,
            iCloudStatus: accountStatus,
            lastSyncTime: lastSyncTime,
            pendingChanges: 0
        )
    }
}

// MARK: - Cross Device Sync Configuration

public struct CrossDeviceSyncConfiguration: Codable, Sendable {
    public var autoSyncEnabled: Bool
    public var syncConversations: Bool
    public var syncSettings: Bool
    public var syncProjects: Bool
    public var conflictResolution: ConflictResolutionStrategy
    public var syncInterval: TimeInterval

    public init(
        autoSyncEnabled: Bool = true,
        syncConversations: Bool = true,
        syncSettings: Bool = true,
        syncProjects: Bool = true,
        conflictResolution: ConflictResolutionStrategy = .lastWriteWins,
        syncInterval: TimeInterval = 60
    ) {
        self.autoSyncEnabled = autoSyncEnabled
        self.syncConversations = syncConversations
        self.syncSettings = syncSettings
        self.syncProjects = syncProjects
        self.conflictResolution = conflictResolution
        self.syncInterval = syncInterval
    }

    private static let configKey = "CrossDeviceService.configuration"

    public static func load() -> CrossDeviceSyncConfiguration {
        if let data = UserDefaults.standard.data(forKey: configKey),
           let config = try? JSONDecoder().decode(CrossDeviceSyncConfiguration.self, from: data)
        {
            return config
        }
        return CrossDeviceSyncConfiguration()
    }

    public func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: CrossDeviceSyncConfiguration.configKey)
        }
    }
}

// MARK: - Sync Status

public struct SyncStatus: Sendable {
    public let isInitialized: Bool
    public let isEnabled: Bool
    public let iCloudStatus: CKAccountStatus
    public let lastSyncTime: Date?
    public let pendingChanges: Int

    public var isReady: Bool {
        isInitialized && isEnabled && iCloudStatus == .available
    }

    public var statusDescription: String {
        if !isInitialized {
            return "Not initialized"
        }
        if !isEnabled {
            return "Sync disabled"
        }
        switch iCloudStatus {
        case .available:
            return "Ready"
        case .noAccount:
            return "No iCloud account"
        case .restricted:
            return "iCloud restricted"
        case .couldNotDetermine:
            return "Unknown status"
        case .temporarilyUnavailable:
            return "Temporarily unavailable"
        @unknown default:
            return "Unknown"
        }
    }
}

// MARK: - Sync Change

public struct SyncChange: Sendable {
    public let id: UUID
    public let type: SyncChangeType
    public let recordType: String
    public let recordId: String
    public let timestamp: Date
    public let data: [String: SendableValue]

    public init(
        id: UUID = UUID(),
        type: SyncChangeType,
        recordType: String,
        recordId: String,
        timestamp: Date = Date(),
        data: [String: SendableValue] = [:]
    ) {
        self.id = id
        self.type = type
        self.recordType = recordType
        self.recordId = recordId
        self.timestamp = timestamp
        self.data = data
    }

    /// Convenience initializer accepting [String: Any]
    public init(
        id: UUID = UUID(),
        type: SyncChangeType,
        recordType: String,
        recordId: String,
        timestamp: Date = Date(),
        rawData: [String: Any]
    ) {
        self.id = id
        self.type = type
        self.recordType = recordType
        self.recordId = recordId
        self.timestamp = timestamp
        data = Dictionary(fromAny: rawData)
    }

    func toCKRecord() -> CKRecord {
        let recordId = CKRecord.ID(recordName: self.recordId)
        let record = CKRecord(recordType: recordType, recordID: recordId)

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

// MARK: - Sync Change Type

public enum SyncChangeType: String, Codable, Sendable {
    case create
    case update
    case delete
}

// MARK: - Sync Conflict

public struct SyncConflict: Sendable {
    public let localChange: SyncChange
    public let remoteChange: SyncChange
    public let detectedAt: Date

    public init(localChange: SyncChange, remoteChange: SyncChange) {
        self.localChange = localChange
        self.remoteChange = remoteChange
        detectedAt = Date()
    }

    func merge() throws -> SyncChange {
        // Simple merge - take the most recent
        if localChange.timestamp > remoteChange.timestamp {
            localChange
        } else {
            remoteChange
        }
    }
}

// MARK: - Conflict Resolution

public enum ConflictResolution: Sendable {
    case keepLocal
    case keepRemote
    case merge
}

public enum ConflictResolutionStrategy: String, Codable, Sendable, CaseIterable {
    case lastWriteWins
    case localWins
    case remoteWins
    case askUser

    public var displayName: String {
        switch self {
        case .lastWriteWins: "Most Recent Wins"
        case .localWins: "Local Always Wins"
        case .remoteWins: "Remote Always Wins"
        case .askUser: "Ask Me"
        }
    }
}

// MARK: - Cross Device Sync Error

public enum CrossDeviceSyncError: Error, LocalizedError, Sendable {
    case iCloudNotAvailable
    case syncDisabled
    case networkError(String)
    case conflictDetected
    case recordNotFound

    public var errorDescription: String? {
        switch self {
        case .iCloudNotAvailable:
            "iCloud is not available. Please sign in to iCloud."
        case .syncDisabled:
            "Sync is currently disabled."
        case let .networkError(message):
            "Network error: \(message)"
        case .conflictDetected:
            "A sync conflict was detected."
        case .recordNotFound:
            "The requested record was not found."
        }
    }
}
