// LifeMonitoringCloudSync.swift
// Thea V2 - Life Monitoring iCloud Sync
//
// Syncs life monitoring data across devices via iCloud

import CloudKit
import Foundation
import os.log

#if canImport(UIKit)
    import UIKit
#endif

// MARK: - Life Monitoring Cloud Sync

/// Handles iCloud sync for life monitoring data
@MainActor
public final class LifeMonitoringCloudSync: ObservableObject {
    public static let shared = LifeMonitoringCloudSync()

    private let logger = Logger(subsystem: "ai.thea.app", category: "LifeMonitoringCloudSync")

    // MARK: - State

    @Published public private(set) var syncStatus: SyncStatus = .idle
    @Published public private(set) var lastSyncDate: Date?
    @Published public private(set) var iCloudAvailable = false
    @Published public var syncEnabled = true

    // MARK: - CloudKit Configuration

    private let containerIdentifier = "iCloud.app.theathe"
    private let privateDatabase: CKDatabase
    private let zoneName = "LifeMonitoringZone"

    // Record types for life monitoring
    private enum RecordType: String {
        case browserEvent = "BrowserEvent"
        case clipboardEvent = "ClipboardEvent"
        case messageEvent = "MessageEvent"
        case mailEvent = "MailEvent"
        case fileSystemEvent = "FileSystemEvent"
        case readingSession = "ReadingSession"
        case lifeEvent = "LifeEvent"
        case syncState = "LifeMonitoringSyncState"
    }

    // MARK: - Delta Sync

    private let changeTokenKey = "LifeMonitoringChangeToken"
    private var changeToken: CKServerChangeToken?

    // MARK: - Batch Processing

    private var pendingEvents: [CloudLifeEvent] = []
    private let batchSize = 50
    private var uploadTask: Task<Void, Never>?

    // MARK: - Initialization

    private init() {
        let container = CKContainer(identifier: containerIdentifier)
        privateDatabase = container.privateCloudDatabase

        loadChangeToken()

        Task {
            await checkiCloudStatus()
            await ensureZoneExists()
        }
    }

    // MARK: - iCloud Status

    private func checkiCloudStatus() async {
        do {
            let status = try await CKContainer(identifier: containerIdentifier).accountStatus()
            iCloudAvailable = status == .available
            logger.info("iCloud status: \(self.iCloudAvailable ? "available" : "unavailable")")
        } catch {
            iCloudAvailable = false
            logger.error("Failed to check iCloud status: \(error.localizedDescription)")
        }
    }

    // MARK: - Zone Management

    private func ensureZoneExists() async {
        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
        let zone = CKRecordZone(zoneID: zoneID)

        do {
            _ = try await privateDatabase.save(zone)
            logger.info("Life monitoring zone created/verified")
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Zone already exists
        } catch {
            logger.error("Failed to create zone: \(error.localizedDescription)")
        }
    }

    // MARK: - Change Token Management

    private func loadChangeToken() {
        guard let data = UserDefaults.standard.data(forKey: changeTokenKey) else { return }
        do {
            let token = try NSKeyedUnarchiver.unarchivedObject(
                ofClass: CKServerChangeToken.self,
                from: data
            )
            changeToken = token
        } catch {
            logger.debug("Failed to unarchive change token: \(error.localizedDescription)")
        }
    }

    private func saveChangeToken(_ token: CKServerChangeToken?) {
        changeToken = token
        guard let token = token else { return }
        do {
            let data = try NSKeyedArchiver.archivedData(
                withRootObject: token,
                requiringSecureCoding: true
            )
            UserDefaults.standard.set(data, forKey: changeTokenKey)
        } catch {
            logger.debug("Failed to archive change token: \(error.localizedDescription)")
        }
    }

    // MARK: - Sync Operations

    /// Sync all life monitoring data
    public func syncAll() async throws {
        guard syncEnabled, iCloudAvailable else { return }

        syncStatus = .syncing
        defer { syncStatus = .idle }

        // Perform delta sync
        try await performDeltaSync()

        // Upload pending events
        try await uploadPendingEvents()

        lastSyncDate = Date()
        logger.info("Life monitoring sync completed")
    }

    /// Perform delta sync to fetch changes from other devices
    private func performDeltaSync() async throws {
        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)

        var changedRecords: [CKRecord] = []
        var deletedRecordIDs: [CKRecord.ID] = []
        var newToken: CKServerChangeToken?

        let operation = CKFetchRecordZoneChangesOperation()

        let zoneConfig = CKFetchRecordZoneChangesOperation.ZoneConfiguration(
            previousServerChangeToken: changeToken
        )

        operation.configurationsByRecordZoneID = [zoneID: zoneConfig]

        operation.recordWasChangedBlock = { _, result in
            if case let .success(record) = result {
                changedRecords.append(record)
            }
        }

        operation.recordWithIDWasDeletedBlock = { recordID, _ in
            deletedRecordIDs.append(recordID)
        }

        operation.recordZoneChangeTokensUpdatedBlock = { _, token, _ in
            newToken = token
        }

        operation.recordZoneFetchResultBlock = { _, result in
            if case let .success((serverToken, _, _)) = result {
                newToken = serverToken
            }
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            operation.fetchRecordZoneChangesResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case let .failure(error):
                    if let ckError = error as? CKError, ckError.code == .changeTokenExpired {
                        // Token expired, reset and try again
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: error)
                    }
                }
            }
            privateDatabase.add(operation)
        }

        // Save new token
        if let token = newToken {
            saveChangeToken(token)
        }

        // Process changes
        for record in changedRecords {
            await processRemoteRecord(record)
        }

        logger.info("Delta sync: \(changedRecords.count) changes, \(deletedRecordIDs.count) deletions")
    }

    /// Process a record received from another device
    private func processRemoteRecord(_ record: CKRecord) async {
        // Check if this is from the current device
        let sourceDeviceID = record["sourceDeviceID"] as? String
        #if os(macOS)
            let currentDeviceID = Host.current().localizedName
        #elseif canImport(UIKit)
            let currentDeviceID = UIDevice.current.identifierForVendor?.uuidString
        #else
            let currentDeviceID: String? = nil
        #endif

        // Skip if from current device
        if sourceDeviceID == currentDeviceID {
            return
        }

        // Process based on record type
        switch record.recordType {
        case RecordType.lifeEvent.rawValue:
            let event = CloudLifeEvent(from: record)
            // Notify coordinator about the new event
            NotificationCenter.default.post(
                name: .lifeMonitoringRemoteEventReceived,
                object: nil,
                userInfo: ["event": event]
            )

        case RecordType.readingSession.rawValue:
            let session = CloudReadingSession(from: record)
            NotificationCenter.default.post(
                name: .lifeMonitoringRemoteReadingSession,
                object: nil,
                userInfo: ["session": session]
            )

        default:
            break
        }
    }

    // MARK: - Upload Operations

    /// Queue a life event for upload
    public func queueEvent(_ event: CloudLifeEvent) {
        pendingEvents.append(event)

        // Upload when batch size reached
        if pendingEvents.count >= batchSize {
            uploadTask?.cancel()
            uploadTask = Task {
                do {
                    try await uploadPendingEvents()
                } catch {
                    self.logger.debug("Failed to upload pending events: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Upload all pending events
    private func uploadPendingEvents() async throws {
        guard syncEnabled, iCloudAvailable, !pendingEvents.isEmpty else { return }

        let eventsToUpload = pendingEvents
        pendingEvents = []

        let records = eventsToUpload.map { $0.toRecord(zoneName: zoneName) }

        do {
            let results = try await privateDatabase.modifyRecords(
                saving: records,
                deleting: [],
                savePolicy: .allKeys
            )

            let successCount = results.saveResults.values.filter {
                if case .success = $0 { return true }
                return false
            }.count

            logger.info("Uploaded \(successCount)/\(records.count) life events to iCloud")
        } catch {
            // Put events back in queue on failure
            pendingEvents.insert(contentsOf: eventsToUpload, at: 0)
            logger.error("Failed to upload life events: \(error.localizedDescription)")
            throw error
        }
    }

    /// Force upload all pending events
    public func flushPendingEvents() async throws {
        try await uploadPendingEvents()
    }

    // MARK: - Query Operations

    /// Fetch recent life events from iCloud
    public func fetchRecentEvents(limit: Int = 100) async throws -> [CloudLifeEvent] {
        guard syncEnabled, iCloudAvailable else { return [] }

        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: RecordType.lifeEvent.rawValue, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]

        let results = try await privateDatabase.records(
            matching: query,
            resultsLimit: limit
        )

        var events: [CloudLifeEvent] = []
        for (_, result) in results.matchResults {
            if case let .success(record) = result {
                events.append(CloudLifeEvent(from: record))
            }
        }

        return events
    }

    /// Fetch reading sessions from a date range
    public func fetchReadingSessions(from startDate: Date, to endDate: Date) async throws -> [CloudReadingSession] {
        guard syncEnabled, iCloudAvailable else { return [] }

        let predicate = NSPredicate(
            format: "startedAt >= %@ AND startedAt <= %@",
            startDate as NSDate,
            endDate as NSDate
        )
        let query = CKQuery(recordType: RecordType.readingSession.rawValue, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "startedAt", ascending: false)]

        let results = try await privateDatabase.records(matching: query)

        var sessions: [CloudReadingSession] = []
        for (_, result) in results.matchResults {
            if case let .success(record) = result {
                sessions.append(CloudReadingSession(from: record))
            }
        }

        return sessions
    }

    // MARK: - Status

    public enum SyncStatus: Sendable, Equatable {
        case idle
        case syncing
        case uploading(Int)
        case error(String)
        case offline

        public var description: String {
            switch self {
            case .idle:
                return "Ready"
            case .syncing:
                return "Syncing..."
            case let .uploading(count):
                return "Uploading \(count) events..."
            case let .error(message):
                return "Error: \(message)"
            case .offline:
                return "Offline"
            }
        }
    }
}

// MARK: - Cloud Life Event

/// Life event that can be synced to iCloud
public struct CloudLifeEvent: Identifiable, Sendable {
    public let id: UUID
    public let eventType: String
    public let sourceType: String
    public let timestamp: Date
    public let sourceDeviceID: String
    public let sourceDeviceName: String
    public let data: Data // JSON-encoded event data

    public init(
        id: UUID = UUID(),
        eventType: String,
        sourceType: String,
        timestamp: Date = Date(),
        data: Data
    ) {
        self.id = id
        self.eventType = eventType
        self.sourceType = sourceType
        self.timestamp = timestamp
        #if os(macOS)
            self.sourceDeviceID = Host.current().localizedName ?? "unknown"
            self.sourceDeviceName = Host.current().localizedName ?? "Mac"
        #elseif canImport(UIKit)
            if Thread.isMainThread {
                self.sourceDeviceID = MainActor.assumeIsolated { UIDevice.current.identifierForVendor?.uuidString ?? "unknown" }
                self.sourceDeviceName = MainActor.assumeIsolated { UIDevice.current.name }
            } else {
                self.sourceDeviceID = "unknown"
                self.sourceDeviceName = "Device"
            }
        #else
            self.sourceDeviceID = "unknown"
            self.sourceDeviceName = "Device"
        #endif
        self.data = data
    }

    init(from record: CKRecord) {
        id = UUID(uuidString: record.recordID.recordName.replacingOccurrences(of: "life-", with: "")) ?? UUID()
        eventType = record["eventType"] as? String ?? ""
        sourceType = record["sourceType"] as? String ?? ""
        timestamp = record["timestamp"] as? Date ?? Date()
        sourceDeviceID = record["sourceDeviceID"] as? String ?? ""
        sourceDeviceName = record["sourceDeviceName"] as? String ?? ""
        data = record["data"] as? Data ?? Data()
    }

    func toRecord(zoneName: String) -> CKRecord {
        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
        let recordID = CKRecord.ID(recordName: "life-\(id.uuidString)", zoneID: zoneID)
        let record = CKRecord(recordType: "LifeEvent", recordID: recordID)

        record["eventType"] = eventType as CKRecordValue
        record["sourceType"] = sourceType as CKRecordValue
        record["timestamp"] = timestamp as CKRecordValue
        record["sourceDeviceID"] = sourceDeviceID as CKRecordValue
        record["sourceDeviceName"] = sourceDeviceName as CKRecordValue
        record["data"] = data as CKRecordValue

        return record
    }
}

// MARK: - Cloud Reading Session

/// Reading session that can be synced to iCloud
public struct CloudReadingSession: Identifiable, Sendable {
    public let id: UUID
    public let url: String
    public let domain: String
    public let title: String
    public let startedAt: Date
    public let endedAt: Date
    public let timeOnPageMs: Int
    public let activeTimeMs: Int
    public let maxScrollDepth: Int
    public let wordCount: Int
    public let sourceDeviceID: String
    public let sourceDeviceName: String

    public init(
        id: UUID = UUID(),
        url: String,
        domain: String,
        title: String,
        startedAt: Date,
        endedAt: Date,
        timeOnPageMs: Int,
        activeTimeMs: Int,
        maxScrollDepth: Int,
        wordCount: Int
    ) {
        self.id = id
        self.url = url
        self.domain = domain
        self.title = title
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.timeOnPageMs = timeOnPageMs
        self.activeTimeMs = activeTimeMs
        self.maxScrollDepth = maxScrollDepth
        self.wordCount = wordCount
        #if os(macOS)
            self.sourceDeviceID = Host.current().localizedName ?? "unknown"
            self.sourceDeviceName = Host.current().localizedName ?? "Mac"
        #elseif canImport(UIKit)
            if Thread.isMainThread {
                self.sourceDeviceID = MainActor.assumeIsolated { UIDevice.current.identifierForVendor?.uuidString ?? "unknown" }
                self.sourceDeviceName = MainActor.assumeIsolated { UIDevice.current.name }
            } else {
                self.sourceDeviceID = "unknown"
                self.sourceDeviceName = "Device"
            }
        #else
            self.sourceDeviceID = "unknown"
            self.sourceDeviceName = "Device"
        #endif
    }

    init(from record: CKRecord) {
        id = UUID(uuidString: record.recordID.recordName.replacingOccurrences(of: "reading-", with: "")) ?? UUID()
        url = record["url"] as? String ?? ""
        domain = record["domain"] as? String ?? ""
        title = record["title"] as? String ?? ""
        startedAt = record["startedAt"] as? Date ?? Date()
        endedAt = record["endedAt"] as? Date ?? Date()
        timeOnPageMs = record["timeOnPageMs"] as? Int ?? 0
        activeTimeMs = record["activeTimeMs"] as? Int ?? 0
        maxScrollDepth = record["maxScrollDepth"] as? Int ?? 0
        wordCount = record["wordCount"] as? Int ?? 0
        sourceDeviceID = record["sourceDeviceID"] as? String ?? ""
        sourceDeviceName = record["sourceDeviceName"] as? String ?? ""
    }

    func toRecord(zoneName: String) -> CKRecord {
        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
        let recordID = CKRecord.ID(recordName: "reading-\(id.uuidString)", zoneID: zoneID)
        let record = CKRecord(recordType: "ReadingSession", recordID: recordID)

        record["url"] = url as CKRecordValue
        record["domain"] = domain as CKRecordValue
        record["title"] = title as CKRecordValue
        record["startedAt"] = startedAt as CKRecordValue
        record["endedAt"] = endedAt as CKRecordValue
        record["timeOnPageMs"] = timeOnPageMs as CKRecordValue
        record["activeTimeMs"] = activeTimeMs as CKRecordValue
        record["maxScrollDepth"] = maxScrollDepth as CKRecordValue
        record["wordCount"] = wordCount as CKRecordValue
        record["sourceDeviceID"] = sourceDeviceID as CKRecordValue
        record["sourceDeviceName"] = sourceDeviceName as CKRecordValue

        return record
    }
}

// MARK: - Notifications

public extension Notification.Name {
    /// Posted when a life event is received from another device
    static let lifeMonitoringRemoteEventReceived = Notification.Name("lifeMonitoringRemoteEventReceived")

    /// Posted when a reading session is received from another device
    static let lifeMonitoringRemoteReadingSession = Notification.Name("lifeMonitoringRemoteReadingSession")
}
