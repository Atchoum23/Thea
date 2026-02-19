//
//  CloudKitServiceTypes.swift
//  Thea
//
//  CloudKit record models, sync status, errors, and notification names
//

import CloudKit
import Foundation

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

    public init(id: UUID = UUID(), title: String, content: String, category: String = "",
                tags: [String] = [], source: String = "", createdAt: Date = Date()) {
        self.id = id; self.title = title; self.content = content; self.category = category
        self.tags = tags; self.source = source; self.createdAt = createdAt
    }

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

    public init(id: UUID = UUID(), name: String, description: String = "",
                path: String = "", tags: [String] = [], lastModified: Date = Date()) {
        self.id = id; self.name = name; self.description = description
        self.path = path; self.tags = tags; self.lastModified = lastModified
    }

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
