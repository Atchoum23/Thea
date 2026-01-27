//
//  CloudKitService.swift
//  Thea
//
//  CloudKit sync for conversations, settings, and user data
//

import CloudKit
import Combine
import Foundation

// MARK: - CloudKit Service

/// Service for managing CloudKit sync across devices
@MainActor
public class CloudKitService: ObservableObject {
    public static let shared = CloudKitService()

    // MARK: - Published State

    @Published public private(set) var syncStatus: CloudSyncStatus = .idle
    @Published public private(set) var lastSyncDate: Date?
    @Published public private(set) var iCloudAvailable = false
    @Published public private(set) var pendingChanges = 0
    @Published public var syncEnabled = true

    // MARK: - CloudKit Configuration

    private let containerIdentifier = "iCloud.app.thea"
    private let privateDatabase: CKDatabase
    private let sharedDatabase: CKDatabase
    private let publicDatabase: CKDatabase

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

    // MARK: - Initialization

    private init() {
        let container = CKContainer(identifier: containerIdentifier)
        privateDatabase = container.privateCloudDatabase
        sharedDatabase = container.sharedCloudDatabase
        publicDatabase = container.publicCloudDatabase

        Task {
            await checkiCloudStatus()
            await setupSubscriptions()
        }
    }

    // MARK: - iCloud Status

    private func checkiCloudStatus() async {
        do {
            let status = try await CKContainer(identifier: containerIdentifier).accountStatus()
            iCloudAvailable = status == .available
        } catch {
            iCloudAvailable = false
        }
    }

    // MARK: - Sync Operations

    /// Sync all data
    public func syncAll() async throws {
        guard syncEnabled, iCloudAvailable else { return }

        syncStatus = .syncing
        defer { syncStatus = .idle }

        // Sync in order of priority
        try await syncSettings()
        try await syncConversations()
        try await syncKnowledge()
        try await syncProjects()

        lastSyncDate = Date()
    }

    /// Sync conversations
    public func syncConversations() async throws {
        guard syncEnabled, iCloudAvailable else { return }

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
        guard syncEnabled, iCloudAvailable else { return }

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
        guard syncEnabled, iCloudAvailable else { return }

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
        guard syncEnabled, iCloudAvailable else { return }

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

    /// Save a conversation to CloudKit
    public func saveConversation(_ conversation: CloudConversation) async throws {
        guard syncEnabled, iCloudAvailable else { return }

        let record = conversation.toRecord()
        try await privateDatabase.save(record)
        pendingChanges = max(0, pendingChanges - 1)
    }

    /// Save settings to CloudKit
    public func saveSettings() async throws {
        guard syncEnabled, iCloudAvailable else { return }

        let settings = CloudSettings.current()
        let record = settings.toRecord()
        try await privateDatabase.save(record)
    }

    /// Save a knowledge item to CloudKit
    public func saveKnowledgeItem(_ item: CloudKnowledgeItem) async throws {
        guard syncEnabled, iCloudAvailable else { return }

        let record = item.toRecord()
        try await privateDatabase.save(record)
    }

    /// Save a project to CloudKit
    public func saveProject(_ project: CloudProject) async throws {
        guard syncEnabled, iCloudAvailable else { return }

        let record = project.toRecord()
        try await privateDatabase.save(record)
    }

    // MARK: - Delete Operations

    /// Delete a conversation from CloudKit
    public func deleteConversation(_ id: UUID) async throws {
        let recordID = CKRecord.ID(recordName: "conversation-\(id.uuidString)")
        try await privateDatabase.deleteRecord(withID: recordID)
    }

    /// Delete a knowledge item from CloudKit
    public func deleteKnowledgeItem(_ id: UUID) async throws {
        let recordID = CKRecord.ID(recordName: "knowledge-\(id.uuidString)")
        try await privateDatabase.deleteRecord(withID: recordID)
    }

    // MARK: - Subscriptions

    private func setupSubscriptions() async {
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
            try? await syncConversations()
        case "settings-changes":
            try? await syncSettings()
        default:
            break
        }
    }

    // MARK: - Merge Operations

    private func mergeConversation(_: CloudConversation) async {
        // Implement conflict resolution
        // Compare modifiedAt timestamps
        // Keep newer version or merge intelligently
    }

    private func mergeKnowledgeItem(_: CloudKnowledgeItem) async {
        // Merge knowledge items
    }

    private func mergeProject(_: CloudProject) async {
        // Merge project data
    }

    private func applySettings(_: CloudSettings) async {
        // Apply synced settings to local storage
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
            return remote
        case .merge:
            // Intelligent merge - combine messages, keep newest metadata
            var merged = local
            merged.messages = Array(Set(local.messages + remote.messages)).sorted { $0.timestamp < $1.timestamp }
            merged.modifiedAt = max(local.modifiedAt, remote.modifiedAt)
            try await saveConversation(merged)
            return merged
        }
    }

    // MARK: - Sharing

    /// Share a conversation with another user
    public func shareConversation(_ conversationId: UUID, with participants: [CKShare.Participant]) async throws -> CKShare {
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

    public init(
        id: UUID = UUID(),
        title: String,
        messages: [CloudMessage] = [],
        aiModel: String = "Claude",
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        tags: [String] = []
    ) {
        self.id = id
        self.title = title
        self.messages = messages
        self.aiModel = aiModel
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.tags = tags
    }

    init(from record: CKRecord) {
        id = UUID(uuidString: record.recordID.recordName.replacingOccurrences(of: "conversation-", with: "")) ?? UUID()
        title = record["title"] as? String ?? ""
        messages = [] // Fetched separately
        aiModel = record["aiModel"] as? String ?? "Claude"
        createdAt = record["createdAt"] as? Date ?? Date()
        modifiedAt = record["modifiedAt"] as? Date ?? Date()
        tags = record["tags"] as? [String] ?? []
    }

    func toRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: "conversation-\(id.uuidString)")
        let record = CKRecord(recordType: "Conversation", recordID: recordID)
        record["title"] = title as CKRecordValue
        record["aiModel"] = aiModel as CKRecordValue
        record["createdAt"] = createdAt as CKRecordValue
        record["modifiedAt"] = modifiedAt as CKRecordValue
        record["tags"] = tags as CKRecordValue
        return record
    }
}

public struct CloudMessage: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let content: String
    public let role: String
    public let timestamp: Date

    public init(id: UUID = UUID(), content: String, role: String, timestamp: Date = Date()) {
        self.id = id
        self.content = content
        self.role = role
        self.timestamp = timestamp
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

public enum CloudSyncStatus: Sendable {
    case idle
    case syncing
    case error(String)
    case offline
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
