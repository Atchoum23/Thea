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
        defer { syncStatus = .idle }

        // Use delta sync for efficiency (only fetches changes since last token)
        try await performDeltaSync()

        lastSyncDate = Date()
    }

    /// Perform delta sync using CKServerChangeToken
    /// This only fetches records that have changed since the last sync
    func performDeltaSync() async throws {
        guard let privateDatabase else { return }
        let zoneID = CKRecordZone.ID(zoneName: "TheaZone", ownerName: CKCurrentUserDefaultName)

        // Ensure the zone exists
        try await ensureZoneExists(zoneID)

        // Configure the fetch with our saved change token
        let previousToken = getChangeToken(for: zoneID)

        // Collect changed and deleted records
        var changedRecords: [CKRecord] = []
        var deletedRecordIDs: [CKRecord.ID] = []
        var newToken: CKServerChangeToken?

        // Use CKFetchRecordZoneChangesOperation for delta sync
        let operation = CKFetchRecordZoneChangesOperation()

        let zoneConfig = CKFetchRecordZoneChangesOperation.ZoneConfiguration(
            previousServerChangeToken: previousToken
        )

        operation.configurationsByRecordZoneID = [zoneID: zoneConfig]

        operation.recordWasChangedBlock = { _, result in
            switch result {
            case let .success(record):
                changedRecords.append(record)
            case .failure:
                break
            }
        }

        operation.recordWithIDWasDeletedBlock = { recordID, _ in
            deletedRecordIDs.append(recordID)
        }

        operation.recordZoneChangeTokensUpdatedBlock = { _, token, _ in
            newToken = token
        }

        operation.recordZoneFetchResultBlock = { _, result in
            switch result {
            case let .success((serverToken, _, _)):
                newToken = serverToken
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
                    // If token expired, we'll handle it after
                    if let ckError = error as? CKError, ckError.code == .changeTokenExpired {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: error)
                    }
                }
            }
            privateDatabase.add(operation)
        }

        // Save the new token
        if let token = newToken {
            setChangeToken(token, for: zoneID)
        }

        // Process changes
        pendingChanges = changedRecords.count + deletedRecordIDs.count

        for record in changedRecords {
            await processChangedRecord(record)
            pendingChanges = max(0, pendingChanges - 1)
        }

        for recordID in deletedRecordIDs {
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
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Zone already exists, this is fine
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
        // Notify the app to remove this conversation from local storage
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
                // Merge with local data
                await mergeConversation(conversation)
            }
        }
    }

    /// Sync settings
    public func syncSettings() async throws {
        guard syncEnabled, iCloudAvailable, let privateDatabase else { return }

        let recordID = CKRecord.ID(recordName: "userSettings")

        do {
            let record = try await privateDatabase.record(for: recordID)
            let settings = CloudSettings(from: record)
            await applySettings(settings)
        } catch {
            // Record doesn't exist, create it
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
    public func saveConversation(_ conversation: CloudConversation) async throws {
        guard syncEnabled, iCloudAvailable, let privateDatabase, isSyncEnabled(for: .conversations) else { return }

        let record = conversation.toRecord()
        // Encrypt sensitive content if encryption is available
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

    /// Save settings to CloudKit
    public func saveSettings() async throws {
        guard syncEnabled, iCloudAvailable, let privateDatabase else { return }

        let settings = CloudSettings.current()
        let record = settings.toRecord()
        try await privateDatabase.save(record)
    }

    /// Save a knowledge item to CloudKit with E2E encryption
    public func saveKnowledgeItem(_ item: CloudKnowledgeItem) async throws {
        guard syncEnabled, iCloudAvailable, let privateDatabase, isSyncEnabled(for: .knowledge) else { return }

        let record = item.toRecord()
        await encryptRecordFields(record, type: .knowledge)
        try await privateDatabase.save(record)
    }

    /// Save a project to CloudKit with E2E encryption
    public func saveProject(_ project: CloudProject) async throws {
        guard syncEnabled, iCloudAvailable, let privateDatabase, isSyncEnabled(for: .projects) else { return }

        let record = project.toRecord()
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
    func decryptRecordFields(_ record: CKRecord, type: RecordType) async {
        guard UserDefaults.standard.bool(forKey: "sync.encryptionEnabled") else { return }

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
        let recordID = CKRecord.ID(recordName: "conversation-\(id.uuidString)")
        try await privateDatabase.deleteRecord(withID: recordID)
    }

    /// Delete a knowledge item from CloudKit
    public func deleteKnowledgeItem(_ id: UUID) async throws {
        guard let privateDatabase else { return }
        let recordID = CKRecord.ID(recordName: "knowledge-\(id.uuidString)")
        try await privateDatabase.deleteRecord(withID: recordID)
    }

    // MARK: - Subscriptions

    func setupSubscriptions() async {
        guard let privateDatabase else { return }
        do {
            // Subscribe to conversation changes
            let conversationSubscription = CKQuerySubscription(
                recordType: RecordType.conversation.rawValue,
                predicate: NSPredicate(value: true),
                subscriptionID: "conversation-changes",
                options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
            )

            let notificationInfo = CKSubscription.NotificationInfo()
            notificationInfo.shouldSendContentAvailable = true
            conversationSubscription.notificationInfo = notificationInfo

            try await privateDatabase.save(conversationSubscription)
            subscriptions.insert(conversationSubscription.subscriptionID)

            // Subscribe to settings changes
            let settingsSubscription = CKQuerySubscription(
                recordType: RecordType.settings.rawValue,
                predicate: NSPredicate(value: true),
                subscriptionID: "settings-changes",
                options: [.firesOnRecordUpdate]
            )
            settingsSubscription.notificationInfo = notificationInfo

            try await privateDatabase.save(settingsSubscription)
            subscriptions.insert(settingsSubscription.subscriptionID)
        } catch {
            // Subscription failed - might already exist
        }
    }

    /// Handle remote notification
    public func handleNotification(_ userInfo: [AnyHashable: Any]) async {
        let notification = CKNotification(fromRemoteNotificationDictionary: userInfo)

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
