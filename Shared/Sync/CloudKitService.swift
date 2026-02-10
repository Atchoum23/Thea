//
//  CloudKitService.swift
//  Thea
//
//  CloudKit sync for conversations, settings, and user data
//

import CloudKit
import Combine
import Foundation
import os.log

// MARK: - CloudKit Service

/// Service for managing CloudKit sync across devices
@MainActor
public class CloudKitService: ObservableObject {
    public static let shared = CloudKitService()

    private let logger = Logger(subsystem: "app.theathe", category: "CloudKitService")

    // MARK: - Published State

    @Published public private(set) var syncStatus: CloudSyncStatus = .idle
    @Published public private(set) var lastSyncDate: Date?
    @Published public private(set) var iCloudAvailable = false
    @Published public private(set) var pendingChanges = 0
    @Published public var syncEnabled = true

    // MARK: - CloudKit Configuration

    private let containerIdentifier = "iCloud.app.theathe"
    private var container: CKContainer?
    private var privateDatabase: CKDatabase?
    private var sharedDatabase: CKDatabase?
    private var publicDatabase: CKDatabase?

    // MARK: - Record Types

    private enum RecordType: String {
        case conversation = "Conversation"
        case message = "Message"
        case settings = "Settings"
        case knowledge = "Knowledge"
        case project = "Project"
        case userProfile = "UserProfile"
    }

    // MARK: - Subscriptions

    private var subscriptions: Set<CKSubscription.ID> = []

    // MARK: - Change Tokens (for Delta Sync)

    private let changeTokenKey = "CloudKitChangeTokens"
    private var changeTokens: [String: CKServerChangeToken] = [:]

    // MARK: - Initialization

    private init() {
        // Load initial sync state from SettingsManager
        syncEnabled = SettingsManager.shared.iCloudSyncEnabled

        // Observe settings changes (lightweight, non-blocking)
        setupSettingsObserver()

        // Defer all heavy CloudKit operations to avoid blocking view layout.
        // Container creation, change token loading, and subscription setup
        // all happen on the next run loop iteration.
        Task { [weak self] in
            guard let self else { return }

            // Initialize CloudKit container safely
            do {
                let ckContainer = try Self.createContainer(identifier: self.containerIdentifier)
                self.container = ckContainer
                self.privateDatabase = ckContainer.privateCloudDatabase
                self.sharedDatabase = ckContainer.sharedCloudDatabase
                self.publicDatabase = ckContainer.publicCloudDatabase
            } catch {
                self.iCloudAvailable = false
                self.syncStatus = .error("CloudKit container not configured")
            }

            // Load saved change tokens for delta sync
            self.loadChangeTokens()

            await self.checkiCloudStatus()
            await self.setupSubscriptions()
        }
    }

    /// Create a CKContainer, catching any assertion failures from misconfigured entitlements.
    private static func createContainer(identifier: String) throws -> CKContainer {
        // Use the default container instead of a named one if the identifier
        // isn't present in the app's entitlements.  CKContainer(identifier:)
        // will hit a `brk` instruction (crash) if the identifier is missing.
        // We verify by checking the entitlements key first.
        guard let containers = Bundle.main.object(forInfoDictionaryKey: "com.apple.developer.icloud-container-identifiers") as? [String],
              containers.contains(identifier) else {
            // Identifier not in Info.plist / entitlements — fall back to default container
            return CKContainer.default()
        }
        return CKContainer(identifier: identifier)
    }

    // MARK: - Change Token Persistence

    private func loadChangeTokens() {
        guard let data = UserDefaults.standard.data(forKey: changeTokenKey) else { return }
        do {
            guard let tokens = try NSKeyedUnarchiver.unarchivedObject(
                ofClasses: [NSDictionary.self, NSString.self, CKServerChangeToken.self],
                from: data
            ) as? [String: CKServerChangeToken] else { return }
            changeTokens = tokens
        } catch {
            logger.error("Failed to load CloudKit change tokens: \(error.localizedDescription)")
        }
    }

    private func saveChangeTokens() {
        do {
            let data = try NSKeyedArchiver.archivedData(
                withRootObject: changeTokens as NSDictionary,
                requiringSecureCoding: true
            )
            UserDefaults.standard.set(data, forKey: changeTokenKey)
        } catch {
            logger.error("Failed to save CloudKit change tokens: \(error.localizedDescription)")
        }
    }

    private func getChangeToken(for zoneID: CKRecordZone.ID) -> CKServerChangeToken? {
        changeTokens[zoneID.zoneName]
    }

    private func setChangeToken(_ token: CKServerChangeToken?, for zoneID: CKRecordZone.ID) {
        changeTokens[zoneID.zoneName] = token
        saveChangeTokens()
    }

    private func setupSettingsObserver() {
        // Watch for changes to iCloudSyncEnabled
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.syncEnabled = SettingsManager.shared.iCloudSyncEnabled
            }
        }
    }

    // MARK: - iCloud Status

    private func checkiCloudStatus() async {
        guard let container else {
            iCloudAvailable = false
            return
        }
        do {
            let status = try await container.accountStatus()
            iCloudAvailable = status == .available
        } catch {
            iCloudAvailable = false
        }
    }

    // MARK: - Sync Operations

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
    private func performDeltaSync() async throws {
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
    private func ensureZoneExists(_ zoneID: CKRecordZone.ID) async throws {
        guard let privateDatabase else { return }
        let zone = CKRecordZone(zoneID: zoneID)
        do {
            _ = try await privateDatabase.save(zone)
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Zone already exists, this is fine
        }
    }

    /// Process a changed record from delta sync
    private func processChangedRecord(_ record: CKRecord) async {
        switch record.recordType {
        case RecordType.conversation.rawValue:
            let conversation = CloudConversation(from: record)
            await mergeConversation(conversation)
        case RecordType.knowledge.rawValue:
            let item = CloudKnowledgeItem(from: record)
            await mergeKnowledgeItem(item)
        case RecordType.project.rawValue:
            let project = CloudProject(from: record)
            await mergeProject(project)
        case RecordType.settings.rawValue:
            let settings = CloudSettings(from: record)
            await applySettings(settings)
        default:
            break
        }
    }

    /// Process a deleted record from delta sync
    private func processDeletedRecord(_ recordID: CKRecord.ID) async {
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
    private func deleteLocalConversation(_ id: UUID) async {
        // Notify the app to remove this conversation from local storage
        NotificationCenter.default.post(
            name: .cloudKitConversationDeleted,
            object: nil,
            userInfo: ["id": id]
        )
    }

    /// Delete a local knowledge item that was deleted remotely
    private func deleteLocalKnowledgeItem(_ id: UUID) async {
        NotificationCenter.default.post(
            name: .cloudKitKnowledgeItemDeleted,
            object: nil,
            userInfo: ["id": id]
        )
    }

    /// Delete a local project that was deleted remotely
    private func deleteLocalProject(_ id: UUID) async {
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

    /// Save a conversation to CloudKit with conflict resolution
    public func saveConversation(_ conversation: CloudConversation) async throws {
        guard syncEnabled, iCloudAvailable, let privateDatabase else { return }

        let record = conversation.toRecord()
        do {
            try await privateDatabase.save(record)
            pendingChanges = max(0, pendingChanges - 1)
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Server has a newer version — merge and retry using the server record as base
            if let serverRecord = error.serverRecord {
                let remote = CloudConversation(from: serverRecord)
                let merged = mergeConversations(local: conversation, remote: remote)
                // Apply merged data onto the server record (preserves change tag)
                merged.applyTo(serverRecord)
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

    /// Save a knowledge item to CloudKit
    public func saveKnowledgeItem(_ item: CloudKnowledgeItem) async throws {
        guard syncEnabled, iCloudAvailable, let privateDatabase else { return }

        let record = item.toRecord()
        try await privateDatabase.save(record)
    }

    /// Save a project to CloudKit
    public func saveProject(_ project: CloudProject) async throws {
        guard syncEnabled, iCloudAvailable, let privateDatabase else { return }

        let record = project.toRecord()
        try await privateDatabase.save(record)
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

    private func setupSubscriptions() async {
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

    // MARK: - Merge Operations

    /// Merge a remote conversation with local data using intelligent conflict resolution
    private func mergeConversation(_ remote: CloudConversation) async {
        let localConversation = await getLocalConversation(remote.id)

        if let local = localConversation {
            // Always merge to preserve messages from both sides
            let merged = mergeConversations(local: local, remote: remote)
            await saveLocalConversation(merged)

            // If local had changes not in remote, push the merged version
            let hasLocalOnlyMessages = local.messages.contains { localMsg in
                !remote.messages.contains { $0.id == localMsg.id }
            }
            if hasLocalOnlyMessages || local.modifiedAt > remote.modifiedAt {
                do {
                    try await saveConversation(merged)
                } catch {
                    logger.error("Failed to push merged conversation \(merged.id): \(error.localizedDescription)")
                }
            }
        } else {
            await saveLocalConversation(remote)
        }
    }

    /// Merge a remote knowledge item with local data
    private func mergeKnowledgeItem(_ remote: CloudKnowledgeItem) async {
        let localItem = await getLocalKnowledgeItem(remote.id)

        if let local = localItem {
            // Use Last-Write-Wins strategy based on createdAt (knowledge items are immutable after creation)
            if remote.createdAt > local.createdAt {
                await saveLocalKnowledgeItem(remote)
            } else if local.createdAt > remote.createdAt {
                do {
                    try await saveKnowledgeItem(local)
                } catch {
                    logger.error("Failed to push knowledge item \(local.id): \(error.localizedDescription)")
                }
            }
        } else {
            await saveLocalKnowledgeItem(remote)
        }
    }

    /// Merge a remote project with local data
    private func mergeProject(_ remote: CloudProject) async {
        let localProject = await getLocalProject(remote.id)

        if let local = localProject {
            // Use Last-Write-Wins strategy based on lastModified
            if remote.lastModified > local.lastModified {
                await saveLocalProject(remote)
            } else if local.lastModified > remote.lastModified {
                do {
                    try await saveProject(local)
                } catch {
                    logger.error("Failed to push project \(local.id): \(error.localizedDescription)")
                }
            }
            // Equal timestamps: prefer remote (other device's version) to ensure convergence
            else {
                await saveLocalProject(remote)
            }
        } else {
            await saveLocalProject(remote)
        }
    }

    /// Apply synced settings to local storage with field-level merge
    private func applySettings(_ remote: CloudSettings) async {
        let localLastSync = lastSyncDate ?? .distantPast

        guard remote.modifiedAt > localLastSync else { return }

        // Apply remote settings — the receiving end should apply only
        // fields that differ from its current values
        NotificationCenter.default.post(
            name: .cloudKitApplySettings,
            object: nil,
            userInfo: [
                "settings": remote,
                "syncTimestamp": remote.modifiedAt
            ]
        )

        lastSyncDate = Date()
    }

    // MARK: - Local Storage Helpers

    /// Thread-safe local conversation fetch via notification.
    /// Uses nonisolated(unsafe) flag to track whether the continuation has already resumed.
    private func getLocalConversation(_ id: UUID) async -> CloudConversation? {
        await withCheckedContinuation { continuation in
            nonisolated(unsafe) var hasResumed = false
            let observer = NotificationCenter.default.addObserver(
                forName: .cloudKitLocalConversationResponse,
                object: nil,
                queue: .main
            ) { notification in
                guard !hasResumed,
                      let responseID = notification.userInfo?["id"] as? UUID,
                      responseID == id
                else { return }
                hasResumed = true
                let conversation = notification.userInfo?["conversation"] as? CloudConversation
                continuation.resume(returning: conversation)
            }

            NotificationCenter.default.post(
                name: .cloudKitRequestLocalConversation,
                object: nil,
                userInfo: ["id": id]
            )

            // Timeout after 500ms if no response
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                guard !hasResumed else { return }
                hasResumed = true
                NotificationCenter.default.removeObserver(observer)
                continuation.resume(returning: nil)
            }
        }
    }

    private func saveLocalConversation(_ conversation: CloudConversation) async {
        NotificationCenter.default.post(
            name: .cloudKitSaveLocalConversation,
            object: nil,
            userInfo: ["conversation": conversation]
        )
    }

    private func getLocalKnowledgeItem(_ id: UUID) async -> CloudKnowledgeItem? {
        await withCheckedContinuation { continuation in
            nonisolated(unsafe) var hasResumed = false
            let observer = NotificationCenter.default.addObserver(
                forName: .cloudKitLocalKnowledgeItemResponse,
                object: nil,
                queue: .main
            ) { notification in
                guard !hasResumed,
                      let responseID = notification.userInfo?["id"] as? UUID,
                      responseID == id
                else { return }
                hasResumed = true
                let item = notification.userInfo?["item"] as? CloudKnowledgeItem
                continuation.resume(returning: item)
            }

            NotificationCenter.default.post(
                name: .cloudKitRequestLocalKnowledgeItem,
                object: nil,
                userInfo: ["id": id]
            )

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                guard !hasResumed else { return }
                hasResumed = true
                NotificationCenter.default.removeObserver(observer)
                continuation.resume(returning: nil)
            }
        }
    }

    private func saveLocalKnowledgeItem(_ item: CloudKnowledgeItem) async {
        NotificationCenter.default.post(
            name: .cloudKitSaveLocalKnowledgeItem,
            object: nil,
            userInfo: ["item": item]
        )
    }

    private func getLocalProject(_ id: UUID) async -> CloudProject? {
        await withCheckedContinuation { continuation in
            nonisolated(unsafe) var hasResumed = false
            let observer = NotificationCenter.default.addObserver(
                forName: .cloudKitLocalProjectResponse,
                object: nil,
                queue: .main
            ) { notification in
                guard !hasResumed,
                      let responseID = notification.userInfo?["id"] as? UUID,
                      responseID == id
                else { return }
                hasResumed = true
                let project = notification.userInfo?["project"] as? CloudProject
                continuation.resume(returning: project)
            }

            NotificationCenter.default.post(
                name: .cloudKitRequestLocalProject,
                object: nil,
                userInfo: ["id": id]
            )

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                guard !hasResumed else { return }
                hasResumed = true
                NotificationCenter.default.removeObserver(observer)
                continuation.resume(returning: nil)
            }
        }
    }

    private func saveLocalProject(_ project: CloudProject) async {
        NotificationCenter.default.post(
            name: .cloudKitSaveLocalProject,
            object: nil,
            userInfo: ["project": project]
        )
    }

    // MARK: - Conflict Resolution

    public enum ConflictResolution {
        case keepLocal
        case keepRemote
        case merge
    }

    public func resolveConflict(
        local: CloudConversation,
        remote: CloudConversation,
        resolution: ConflictResolution
    ) async throws -> CloudConversation {
        switch resolution {
        case .keepLocal:
            try await saveConversation(local)
            return local
        case .keepRemote:
            await saveLocalConversation(remote)
            return remote
        case .merge:
            let merged = mergeConversations(local: local, remote: remote)
            try await saveConversation(merged)
            await saveLocalConversation(merged)
            return merged
        }
    }

    /// Merge two conversations by combining messages (deduplicated by ID),
    /// taking the newest metadata fields, and union of device/tag lists.
    private func mergeConversations(local: CloudConversation, remote: CloudConversation) -> CloudConversation {
        // Deduplicate messages by ID, preferring the newer version of each
        var messagesByID: [UUID: CloudMessage] = [:]
        for msg in local.messages {
            messagesByID[msg.id] = msg
        }
        for msg in remote.messages {
            if let existing = messagesByID[msg.id] {
                // Keep whichever version is newer
                if msg.timestamp > existing.timestamp {
                    messagesByID[msg.id] = msg
                }
            } else {
                messagesByID[msg.id] = msg
            }
        }
        let mergedMessages = messagesByID.values.sorted { $0.timestamp < $1.timestamp }

        // Merge metadata: newest title, newest model, union of tags/devices
        let newestTitle = local.modifiedAt >= remote.modifiedAt ? local.title : remote.title
        let newestModel = local.modifiedAt >= remote.modifiedAt ? local.aiModel : remote.aiModel
        let mergedTags = Array(Set(local.tags + remote.tags)).sorted()
        let mergedDevices = Array(Set(local.participatingDeviceIDs + remote.participatingDeviceIDs))

        return CloudConversation(
            id: local.id,
            title: newestTitle,
            messages: mergedMessages,
            aiModel: newestModel,
            createdAt: min(local.createdAt, remote.createdAt),
            modifiedAt: max(local.modifiedAt, remote.modifiedAt),
            tags: mergedTags,
            participatingDeviceIDs: mergedDevices
        )
    }

    // MARK: - Sharing

    /// Share a conversation with another user
    public func shareConversation(_ conversationId: UUID, with participants: [CKShare.Participant]) async throws -> CKShare {
        guard let privateDatabase else { throw CloudKitError.notAuthenticated }
        let recordID = CKRecord.ID(recordName: "conversation-\(conversationId.uuidString)")
        let record = try await privateDatabase.record(for: recordID)

        let share = CKShare(rootRecord: record)
        share[CKShare.SystemFieldKey.title] = "Shared Conversation" as CKRecordValue
        share.publicPermission = .none

        for participant in participants {
            share.addParticipant(participant)
        }

        let results = try await privateDatabase.modifyRecords(saving: [record, share], deleting: [])

        guard let savedShare = try results.saveResults[share.recordID]?.get() as? CKShare else {
            throw CloudKitError.sharingFailed
        }

        return savedShare
    }
}

// MARK: - CloudKit Types

public struct CloudConversation: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var messages: [CloudMessage]
    public var aiModel: String
    public var createdAt: Date
    public var modifiedAt: Date
    public var tags: [String]

    // Track which devices have participated in this conversation
    public var participatingDeviceIDs: [String]

    public init(
        id: UUID = UUID(),
        title: String,
        messages: [CloudMessage] = [],
        aiModel: String = "Claude",
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        tags: [String] = [],
        participatingDeviceIDs: [String] = []
    ) {
        self.id = id
        self.title = title
        self.messages = messages
        self.aiModel = aiModel
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.tags = tags
        self.participatingDeviceIDs = participatingDeviceIDs
    }

    init(from record: CKRecord) {
        id = UUID(uuidString: record.recordID.recordName.replacingOccurrences(of: "conversation-", with: "")) ?? UUID()
        title = record["title"] as? String ?? ""
        messages = [] // Fetched separately
        aiModel = record["aiModel"] as? String ?? "Claude"
        createdAt = record["createdAt"] as? Date ?? Date()
        modifiedAt = record["modifiedAt"] as? Date ?? Date()
        tags = record["tags"] as? [String] ?? []
        participatingDeviceIDs = record["participatingDeviceIDs"] as? [String] ?? []
    }

    func toRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: "conversation-\(id.uuidString)")
        let record = CKRecord(recordType: "Conversation", recordID: recordID)
        applyTo(record)
        return record
    }

    /// Apply this conversation's fields onto an existing CKRecord (preserves change tag for conflict resolution)
    func applyTo(_ record: CKRecord) {
        record["title"] = title as CKRecordValue
        record["aiModel"] = aiModel as CKRecordValue
        record["createdAt"] = createdAt as CKRecordValue
        record["modifiedAt"] = modifiedAt as CKRecordValue
        record["tags"] = tags as CKRecordValue
        record["participatingDeviceIDs"] = participatingDeviceIDs as CKRecordValue
    }
}

public struct CloudMessage: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let content: String
    public let role: String
    public let timestamp: Date

    // Device origin tracking
    public var deviceID: String?
    public var deviceName: String?
    public var deviceType: String?

    public init(
        id: UUID = UUID(),
        content: String,
        role: String,
        timestamp: Date = Date(),
        deviceID: String? = nil,
        deviceName: String? = nil,
        deviceType: String? = nil
    ) {
        self.id = id
        self.content = content
        self.role = role
        self.timestamp = timestamp
        self.deviceID = deviceID
        self.deviceName = deviceName
        self.deviceType = deviceType
    }
}

public struct CloudSettings: Sendable {
    public var theme: String
    public var aiModel: String
    public var autoSave: Bool
    public var syncEnabled: Bool
    public var notificationsEnabled: Bool
    public var modifiedAt: Date

    public init(
        theme: String = "system",
        aiModel: String = "Claude",
        autoSave: Bool = true,
        syncEnabled: Bool = true,
        notificationsEnabled: Bool = true,
        modifiedAt: Date = Date()
    ) {
        self.theme = theme
        self.aiModel = aiModel
        self.autoSave = autoSave
        self.syncEnabled = syncEnabled
        self.notificationsEnabled = notificationsEnabled
        self.modifiedAt = modifiedAt
    }

    init(from record: CKRecord) {
        theme = record["theme"] as? String ?? "system"
        aiModel = record["aiModel"] as? String ?? "Claude"
        autoSave = record["autoSave"] as? Bool ?? true
        syncEnabled = record["syncEnabled"] as? Bool ?? true
        notificationsEnabled = record["notificationsEnabled"] as? Bool ?? true
        modifiedAt = record["modifiedAt"] as? Date ?? Date()
    }

    static func current() -> CloudSettings {
        // Load from UserDefaults
        CloudSettings()
    }

    func toRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: "userSettings")
        let record = CKRecord(recordType: "Settings", recordID: recordID)
        record["theme"] = theme as CKRecordValue
        record["aiModel"] = aiModel as CKRecordValue
        record["autoSave"] = autoSave as CKRecordValue
        record["syncEnabled"] = syncEnabled as CKRecordValue
        record["notificationsEnabled"] = notificationsEnabled as CKRecordValue
        record["modifiedAt"] = modifiedAt as CKRecordValue
        return record
    }
}

public struct CloudKnowledgeItem: Identifiable, Sendable {
    public let id: UUID
    public var title: String
    public var content: String
    public var category: String
    public var tags: [String]
    public var source: String
    public var createdAt: Date

    init(from record: CKRecord) {
        id = UUID(uuidString: record.recordID.recordName.replacingOccurrences(of: "knowledge-", with: "")) ?? UUID()
        title = record["title"] as? String ?? ""
        content = record["content"] as? String ?? ""
        category = record["category"] as? String ?? ""
        tags = record["tags"] as? [String] ?? []
        source = record["source"] as? String ?? ""
        createdAt = record["createdAt"] as? Date ?? Date()
    }

    func toRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: "knowledge-\(id.uuidString)")
        let record = CKRecord(recordType: "Knowledge", recordID: recordID)
        record["title"] = title as CKRecordValue
        record["content"] = content as CKRecordValue
        record["category"] = category as CKRecordValue
        record["tags"] = tags as CKRecordValue
        record["source"] = source as CKRecordValue
        record["createdAt"] = createdAt as CKRecordValue
        return record
    }
}

public struct CloudProject: Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var description: String
    public var path: String
    public var tags: [String]
    public var lastModified: Date

    init(from record: CKRecord) {
        id = UUID(uuidString: record.recordID.recordName.replacingOccurrences(of: "project-", with: "")) ?? UUID()
        name = record["name"] as? String ?? ""
        description = record["description"] as? String ?? ""
        path = record["path"] as? String ?? ""
        tags = record["tags"] as? [String] ?? []
        lastModified = record["lastModified"] as? Date ?? Date()
    }

    func toRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: "project-\(id.uuidString)")
        let record = CKRecord(recordType: "Project", recordID: recordID)
        record["name"] = name as CKRecordValue
        record["description"] = description as CKRecordValue
        record["path"] = path as CKRecordValue
        record["tags"] = tags as CKRecordValue
        record["lastModified"] = lastModified as CKRecordValue
        return record
    }
}

// MARK: - Sync Status

public enum CloudSyncStatus: Sendable, Equatable {
    case idle
    case syncing
    case error(String)
    case offline

    public var description: String {
        switch self {
        case .idle:
            return "Ready"
        case .syncing:
            return "Syncing..."
        case .error(let message):
            return "Error: \(message)"
        case .offline:
            return "Offline"
        }
    }
}

// MARK: - Errors

public enum CloudKitError: Error, LocalizedError, Sendable {
    case notAuthenticated
    case networkError
    case quotaExceeded
    case sharingFailed
    case recordNotFound
    case conflictDetected

    public var errorDescription: String? {
        switch self {
        case .notAuthenticated: "Not signed in to iCloud"
        case .networkError: "Network connection error"
        case .quotaExceeded: "iCloud storage quota exceeded"
        case .sharingFailed: "Failed to share content"
        case .recordNotFound: "Record not found"
        case .conflictDetected: "Sync conflict detected"
        }
    }
}

// MARK: - CloudKit Sync Notifications

public extension Notification.Name {
    /// Posted when a conversation is deleted remotely
    static let cloudKitConversationDeleted = Notification.Name("cloudKitConversationDeleted")

    /// Posted when a knowledge item is deleted remotely
    static let cloudKitKnowledgeItemDeleted = Notification.Name("cloudKitKnowledgeItemDeleted")

    /// Posted when a project is deleted remotely
    static let cloudKitProjectDeleted = Notification.Name("cloudKitProjectDeleted")

    /// Posted to request a local conversation for merge
    static let cloudKitRequestLocalConversation = Notification.Name("cloudKitRequestLocalConversation")

    /// Posted to save a merged conversation locally
    static let cloudKitSaveLocalConversation = Notification.Name("cloudKitSaveLocalConversation")

    /// Posted to save a merged knowledge item locally
    static let cloudKitSaveLocalKnowledgeItem = Notification.Name("cloudKitSaveLocalKnowledgeItem")

    /// Posted to save a merged project locally
    static let cloudKitSaveLocalProject = Notification.Name("cloudKitSaveLocalProject")

    /// Response notifications for local storage lookups
    static let cloudKitLocalConversationResponse = Notification.Name("cloudKitLocalConversationResponse")
    static let cloudKitLocalKnowledgeItemResponse = Notification.Name("cloudKitLocalKnowledgeItemResponse")
    static let cloudKitLocalProjectResponse = Notification.Name("cloudKitLocalProjectResponse")

    /// Posted to request a local knowledge item for merge
    static let cloudKitRequestLocalKnowledgeItem = Notification.Name("cloudKitRequestLocalKnowledgeItem")

    /// Posted to request a local project for merge
    static let cloudKitRequestLocalProject = Notification.Name("cloudKitRequestLocalProject")

    /// Posted when sync completes successfully
    static let cloudKitSyncCompleted = Notification.Name("cloudKitSyncCompleted")

    /// Posted when sync fails
    static let cloudKitSyncFailed = Notification.Name("cloudKitSyncFailed")

    /// Posted to apply synced settings
    static let cloudKitApplySettings = Notification.Name("cloudKitApplySettings")

    /// Posted by CrossDeviceService to apply a remote sync change to local storage
    static let crossDeviceApplyRemoteChange = Notification.Name("crossDeviceApplyRemoteChange")
}
