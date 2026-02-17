//
//  CloudKitService+Sync.swift
//  Thea
//
//  Sync operations, save/delete, subscriptions, and notification handling
//

import CloudKit
import Foundation

// MARK: - Sync Operations

extension CloudKitService {
    /// Sync all data using delta sync (only fetches changes since last sync)
    public func syncAll() async throws {
        guard syncEnabled, iCloudAvailable, privateDatabase != nil else { return }

        syncStatus = .syncing

        do {
            // Use delta sync for efficiency (only fetches changes since last token)
            try await performDeltaSync()
            lastSyncDate = Date()
            syncStatus = .idle
        } catch {
            syncStatus = .error(error.localizedDescription)
            throw error
        }
    }

    /// Perform delta sync using CKServerChangeToken
    /// This only fetches records that have changed since the last sync
    func performDeltaSync() async throws {
        guard let privateDatabase else { return }
        let zoneID = Self.theaZoneID

        // Ensure the zone exists
        try await ensureZoneExists(zoneID)

        // Configure the fetch with our saved change token
        let previousToken = getChangeToken(for: zoneID)

        // Collect changed and deleted records using actor-isolated storage
        let collector = RecordCollector()

        // Use CKFetchRecordZoneChangesOperation for delta sync
        let operation = CKFetchRecordZoneChangesOperation()

        let zoneConfig = CKFetchRecordZoneChangesOperation.ZoneConfiguration(
            previousServerChangeToken: previousToken
        )

        operation.configurationsByRecordZoneID = [zoneID: zoneConfig]

        operation.recordWasChangedBlock = { _, result in
            switch result {
            case let .success(record):
                collector.addChanged(record)
            case .failure:
                break
            }
        }

        operation.recordWithIDWasDeletedBlock = { recordID, _ in
            collector.addDeleted(recordID)
        }

        operation.recordZoneChangeTokensUpdatedBlock = { _, token, _ in
            collector.setToken(token)
        }

        operation.recordZoneFetchResultBlock = { _, result in
            switch result {
            case let .success((serverToken, _, _)):
                collector.setToken(serverToken)
            case .failure:
                break
            }
        }

        // Execute and wait
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            operation.fetchRecordZoneChangesResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case let .failure(error):
                    // If token expired, clear it and retry with full fetch
                    if let ckError = error as? CKError, ckError.code == .changeTokenExpired {
                        collector.setTokenExpired()
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: error)
                    }
                }
            }
            privateDatabase.add(operation)
        }

        // Handle token expiry: clear stale token and the results
        if collector.tokenExpired {
            setChangeToken(nil, for: zoneID)
            logger.info("Change token expired, cleared. Next sync will do full fetch.")
            return
        }

        // Save the new token
        let results = collector.results()
        if let token = results.token {
            setChangeToken(token, for: zoneID)
        }

        // Process changes
        pendingChanges = results.changed.count + results.deleted.count

        for record in results.changed {
            await processChangedRecord(record)
            pendingChanges = max(0, pendingChanges - 1)
        }

        for recordID in results.deleted {
            await processDeletedRecord(recordID)
            pendingChanges = max(0, pendingChanges - 1)
        }
    }

    /// Ensure the custom record zone exists
    func ensureZoneExists(_ zoneID: CKRecordZone.ID) async throws {
        guard let privateDatabase else { return }
        let zone = CKRecordZone(zoneID: zoneID)
        do {
            _ = try await privateDatabase.save(zone)
        } catch let error as CKError where error.code == .zoneNotFound || error.code == .serverRejectedRequest {
            // Zone already exists or server rejected duplicate — this is fine
        }
    }

    /// Process a changed record from delta sync, respecting selective sync toggles and decrypting E2E data
    func processChangedRecord(_ record: CKRecord) async {
        switch record.recordType {
        case RecordType.conversation.rawValue:
            guard isSyncEnabled(for: .conversations) else { return }
            await decryptRecordFields(record, type: .conversation)
            let conversation = CloudConversation(from: record)
            await mergeConversation(conversation)
        case RecordType.knowledge.rawValue:
            guard isSyncEnabled(for: .knowledge) else { return }
            await decryptRecordFields(record, type: .knowledge)
            let item = CloudKnowledgeItem(from: record)
            await mergeKnowledgeItem(item)
        case RecordType.project.rawValue:
            guard isSyncEnabled(for: .projects) else { return }
            await decryptRecordFields(record, type: .project)
            let project = CloudProject(from: record)
            await mergeProject(project)
        case RecordType.settings.rawValue:
            let settings = CloudSettings(from: record)
            await applySettings(settings)
        default:
            break
        }
    }

    // MARK: - Selective Sync

    /// Data types that can be individually toggled for sync
    enum SyncDataType: String, CaseIterable, Sendable {
        case conversations
        case knowledge
        case projects
        case favorites
    }

    /// Check whether sync is enabled for a specific data type via AppStorage toggles.
    /// Defaults to true (syncing everything) if the user hasn't explicitly disabled a type.
    func isSyncEnabled(for dataType: SyncDataType) -> Bool {
        let key = "sync.\(dataType.rawValue)"
        // If the key has never been set, default to enabled
        guard UserDefaults.standard.object(forKey: key) != nil else { return true }
        return UserDefaults.standard.bool(forKey: key)
    }

    /// Process a deleted record from delta sync
    func processDeletedRecord(_ recordID: CKRecord.ID) async {
        // Extract UUID from record name (format: "type-uuid")
        let components = recordID.recordName.split(separator: "-", maxSplits: 1)
        guard components.count == 2,
              let uuid = UUID(uuidString: String(components[1]))
        else { return }

        let recordType = String(components[0])
        switch recordType {
        case "conversation":
            await deleteLocalConversation(uuid)
        case "knowledge":
            await deleteLocalKnowledgeItem(uuid)
        case "project":
            await deleteLocalProject(uuid)
        default:
            break
        }
    }

    /// Delete a local conversation that was deleted remotely
    func deleteLocalConversation(_ id: UUID) async {
        NotificationCenter.default.post(
            name: .cloudKitConversationDeleted,
            object: nil,
            userInfo: ["id": id]
        )
    }

    /// Delete a local knowledge item that was deleted remotely
    func deleteLocalKnowledgeItem(_ id: UUID) async {
        NotificationCenter.default.post(
            name: .cloudKitKnowledgeItemDeleted,
            object: nil,
            userInfo: ["id": id]
        )
    }

    /// Delete a local project that was deleted remotely
    func deleteLocalProject(_ id: UUID) async {
        NotificationCenter.default.post(
            name: .cloudKitProjectDeleted,
            object: nil,
            userInfo: ["id": id]
        )
    }

    /// Sync conversations
    public func syncConversations() async throws {
        guard syncEnabled, iCloudAvailable, let privateDatabase else { return }

        // Fetch changes since last sync
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: RecordType.conversation.rawValue, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "modifiedAt", ascending: false)]

        let results = try await privateDatabase.records(matching: query)

        for (_, result) in results.matchResults {
            if case let .success(record) = result {
                let conversation = CloudConversation(from: record)
                await mergeConversation(conversation)
            }
        }
    }

    /// Sync settings
    public func syncSettings() async throws {
        guard syncEnabled, iCloudAvailable, let privateDatabase else { return }

        let recordID = CKRecord.ID(recordName: "userSettings", zoneID: Self.theaZoneID)

        do {
            let record = try await privateDatabase.record(for: recordID)
            let settings = CloudSettings(from: record)
            await applySettings(settings)
        } catch let error as CKError where error.code == .unknownItem {
            // Record doesn't exist yet, create it
            try await saveSettings()
        }
    }

    /// Sync knowledge base
    public func syncKnowledge() async throws {
        guard syncEnabled, iCloudAvailable, let privateDatabase else { return }

        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: RecordType.knowledge.rawValue, predicate: predicate)

        let results = try await privateDatabase.records(matching: query)

        for (_, result) in results.matchResults {
            if case let .success(record) = result {
                let item = CloudKnowledgeItem(from: record)
                await mergeKnowledgeItem(item)
            }
        }
    }

    /// Sync projects
    public func syncProjects() async throws {
        guard syncEnabled, iCloudAvailable, let privateDatabase else { return }

        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: RecordType.project.rawValue, predicate: predicate)

        let results = try await privateDatabase.records(matching: query)

        for (_, result) in results.matchResults {
            if case let .success(record) = result {
                let project = CloudProject(from: record)
                await mergeProject(project)
            }
        }
    }

    // MARK: - Save Operations

    /// Save a conversation to CloudKit with conflict resolution and optional E2E encryption
    public func saveConversation(_ conversation: CloudConversation, retryCount: Int = 0) async throws {
        guard syncEnabled, iCloudAvailable, let privateDatabase, isSyncEnabled(for: .conversations) else { return }

        let record = conversation.toRecord(in: Self.theaZoneID)
        await encryptRecordFields(record, type: .conversation)

        do {
            try await privateDatabase.save(record)
            pendingChanges = max(0, pendingChanges - 1)
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Server has a newer version — check if user should decide
            if let serverRecord = error.serverRecord {
                let remote = CloudConversation(from: serverRecord)

                // Surface to UI if both sides have different titles (meaningful conflict)
                if conversation.title != remote.title, !conversation.title.isEmpty {
                    let conflictItem = SyncConflictItem(
                        id: conversation.id,
                        itemType: .conversation,
                        localTitle: conversation.title,
                        remoteTitle: remote.title,
                        localModified: conversation.modifiedAt,
                        remoteModified: remote.modifiedAt,
                        localDevice: DeviceRegistry.shared.currentDevice.name,
                        remoteDevice: remote.participatingDeviceIDs.last ?? "Other device",
                        localMessageCount: conversation.messages.count,
                        remoteMessageCount: remote.messages.count
                    )
                    await MainActor.run {
                        SyncConflictManager.shared.addConflict(conflictItem)
                    }
                }

                // Auto-merge in the background (user can override via conflict UI)
                // Guard against infinite merge loops with a retry limit
                guard retryCount < 3 else {
                    logger.warning("Merge retry limit reached for conversation \(conversation.id)")
                    throw error
                }
                let merged = mergeConversations(local: conversation, remote: remote)
                merged.applyTo(serverRecord)
                await encryptRecordFields(serverRecord, type: .conversation)
                try await privateDatabase.save(serverRecord)
                pendingChanges = max(0, pendingChanges - 1)
            } else {
                throw error
            }
        }
    }

    /// Save settings to CloudKit with conflict handling
    public func saveSettings() async throws {
        guard syncEnabled, iCloudAvailable, let privateDatabase else { return }

        let settings = CloudSettings.current()
        let zoneID = Self.theaZoneID
        let recordID = CKRecord.ID(recordName: "userSettings", zoneID: zoneID)

        // Try to fetch existing record first to preserve change tag
        do {
            let existingRecord = try await privateDatabase.record(for: recordID)
            existingRecord["theme"] = settings.theme as CKRecordValue
            existingRecord["aiModel"] = settings.aiModel as CKRecordValue
            existingRecord["autoSave"] = settings.autoSave as CKRecordValue
            existingRecord["syncEnabled"] = settings.syncEnabled as CKRecordValue
            existingRecord["notificationsEnabled"] = settings.notificationsEnabled as CKRecordValue
            existingRecord["modifiedAt"] = settings.modifiedAt as CKRecordValue
            try await privateDatabase.save(existingRecord)
        } catch let error as CKError where error.code == .unknownItem {
            // Record doesn't exist yet, create new
            let record = settings.toRecord(in: zoneID)
            try await privateDatabase.save(record)
        }
    }

    /// Save a knowledge item to CloudKit with E2E encryption
    public func saveKnowledgeItem(_ item: CloudKnowledgeItem) async throws {
        guard syncEnabled, iCloudAvailable, let privateDatabase, isSyncEnabled(for: .knowledge) else { return }

        let record = item.toRecord(in: Self.theaZoneID)
        await encryptRecordFields(record, type: .knowledge)
        try await privateDatabase.save(record)
    }

    /// Save a project to CloudKit with E2E encryption
    public func saveProject(_ project: CloudProject) async throws {
        guard syncEnabled, iCloudAvailable, let privateDatabase, isSyncEnabled(for: .projects) else { return }

        let record = project.toRecord(in: Self.theaZoneID)
        await encryptRecordFields(record, type: .project)
        try await privateDatabase.save(record)
    }

    // MARK: - E2E Encryption

    /// Encrypt sensitive fields in a CKRecord before uploading.
    /// Only encrypts content fields (title, content) — metadata (dates, IDs) stays in the clear for CloudKit queries.
    private func encryptRecordFields(_ record: CKRecord, type: RecordType) async {
        guard UserDefaults.standard.bool(forKey: "sync.encryptionEnabled") else { return }

        do {
            let encryption = SyncEncryption.shared
            switch type {
            case .conversation:
                if let title = record["title"] as? String, !title.isEmpty {
                    let encrypted = try await encryption.encrypt(Data(title.utf8))
                    record["encryptedTitle"] = encrypted as CKRecordValue
                    record["title"] = "[encrypted]" as CKRecordValue
                }
            case .knowledge:
                if let content = record["content"] as? String, !content.isEmpty {
                    let encrypted = try await encryption.encrypt(Data(content.utf8))
                    record["encryptedContent"] = encrypted as CKRecordValue
                    record["content"] = "[encrypted]" as CKRecordValue
                }
            case .project:
                if let name = record["name"] as? String, !name.isEmpty {
                    let encrypted = try await encryption.encrypt(Data(name.utf8))
                    record["encryptedName"] = encrypted as CKRecordValue
                    record["name"] = "[encrypted]" as CKRecordValue
                }
            default:
                break
            }
        } catch {
            logger.warning("Encryption failed, saving unencrypted: \(error.localizedDescription)")
        }
    }

    /// Decrypt sensitive fields from a CKRecord after fetching.
    /// Always attempts decryption if encrypted fields exist, regardless of current encryption toggle.
    func decryptRecordFields(_ record: CKRecord, type: RecordType) async {
        do {
            let encryption = SyncEncryption.shared
            switch type {
            case .conversation:
                if let encrypted = record["encryptedTitle"] as? Data {
                    let decrypted = try await encryption.decrypt(encrypted)
                    record["title"] = String(data: decrypted, encoding: .utf8) as CKRecordValue?
                }
            case .knowledge:
                if let encrypted = record["encryptedContent"] as? Data {
                    let decrypted = try await encryption.decrypt(encrypted)
                    record["content"] = String(data: decrypted, encoding: .utf8) as CKRecordValue?
                }
            case .project:
                if let encrypted = record["encryptedName"] as? Data {
                    let decrypted = try await encryption.decrypt(encrypted)
                    record["name"] = String(data: decrypted, encoding: .utf8) as CKRecordValue?
                }
            default:
                break
            }
        } catch {
            logger.warning("Decryption failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Delete Operations

    /// Delete a conversation from CloudKit
    public func deleteConversation(_ id: UUID) async throws {
        guard let privateDatabase else { return }
        let recordID = CKRecord.ID(recordName: "conversation-\(id.uuidString)", zoneID: Self.theaZoneID)
        try await privateDatabase.deleteRecord(withID: recordID)
    }

    /// Delete a knowledge item from CloudKit
    public func deleteKnowledgeItem(_ id: UUID) async throws {
        guard let privateDatabase else { return }
        let recordID = CKRecord.ID(recordName: "knowledge-\(id.uuidString)", zoneID: Self.theaZoneID)
        try await privateDatabase.deleteRecord(withID: recordID)
    }

    // MARK: - Subscriptions

    func setupSubscriptions() async {
        guard let privateDatabase else { return }
        do {
            // Use CKRecordZoneSubscription for custom zone (CKQuerySubscription only works in default zone)
            let zoneSubscription = CKRecordZoneSubscription(
                zoneID: Self.theaZoneID,
                subscriptionID: "thea-zone-changes"
            )

            let notificationInfo = CKSubscription.NotificationInfo()
            notificationInfo.shouldSendContentAvailable = true
            zoneSubscription.notificationInfo = notificationInfo

            try await privateDatabase.save(zoneSubscription)
            subscriptions.insert(zoneSubscription.subscriptionID)
        } catch {
            // Subscription failed - might already exist, which is fine
            logger.info("Subscription setup: \(error.localizedDescription)")
        }
    }

    /// Handle remote notification
    public func handleNotification(_ userInfo: [AnyHashable: Any]) async {
        let notification = CKNotification(fromRemoteNotificationDictionary: userInfo)

        if let zoneNotification = notification as? CKRecordZoneNotification,
           zoneNotification.subscriptionID == "thea-zone-changes" {
            // Zone changed — run delta sync to fetch only changes
            do {
                try await performDeltaSync()
                lastSyncDate = Date()
            } catch {
                logger.error("Failed to delta sync from notification: \(error.localizedDescription)")
            }
            return
        }

        // Legacy: handle old-style query notifications during migration
        guard let queryNotification = notification as? CKQueryNotification else { return }

        switch queryNotification.subscriptionID {
        case "conversation-changes":
            do {
                try await syncConversations()
            } catch {
                logger.error("Failed to sync conversations from notification: \(error.localizedDescription)")
            }
        case "settings-changes":
            do {
                try await syncSettings()
            } catch {
                logger.error("Failed to sync settings from notification: \(error.localizedDescription)")
            }
        default:
            break
        }
    }
}

// MARK: - Thread-Safe Record Collector

/// Collects records from CKFetchRecordZoneChangesOperation callbacks safely.
/// Callbacks are invoked serially by CloudKit, but this ensures safety regardless.
private final class RecordCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var _changed: [CKRecord] = []
    private var _deleted: [CKRecord.ID] = []
    private var _token: CKServerChangeToken?
    private var _tokenExpired = false

    var tokenExpired: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _tokenExpired
    }

    func addChanged(_ record: CKRecord) {
        lock.lock()
        _changed.append(record)
        lock.unlock()
    }

    func addDeleted(_ recordID: CKRecord.ID) {
        lock.lock()
        _deleted.append(recordID)
        lock.unlock()
    }

    func setToken(_ token: CKServerChangeToken?) {
        lock.lock()
        _token = token
        lock.unlock()
    }

    func setTokenExpired() {
        lock.lock()
        _tokenExpired = true
        lock.unlock()
    }

    func results() -> (changed: [CKRecord], deleted: [CKRecord.ID], token: CKServerChangeToken?) {
        lock.lock()
        defer { lock.unlock() }
        return (_changed, _deleted, _token)
    }
}
