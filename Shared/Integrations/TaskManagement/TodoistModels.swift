//
//  TodoistModels.swift
//  Thea
//
//  Todoist data models, UI extensions, and error types
//  Extracted from TodoistIntegration.swift
//

import Foundation
import CryptoKit

// MARK: - Data Models

public struct TodoistProject: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let color: String?
    public let parentId: String?
    public let order: Int
    public let commentCount: Int
    public let isShared: Bool
    public let isFavorite: Bool
    public let isInboxProject: Bool
    public let isTeamInbox: Bool
    public let viewStyle: String?
    public let url: String
}

public struct TodoistTask: Codable, Identifiable, Sendable {
    public let id: String
    public let content: String
    public let description: String?
    public let projectId: String
    public let sectionId: String?
    public let parentId: String?
    public let isCompleted: Bool
    public let labels: [String]
    public let priority: Int
    public let due: TodoistDue?
    public let duration: TodoistDuration?
    public let order: Int
    public let commentCount: Int
    public let createdAt: String
    public let creatorId: String
    public let assigneeId: String?
    public let assignerId: String?
    public let url: String
}

public struct TodoistTaskCreate: Sendable {
    public let content: String
    public let description: String?
    public let projectId: String?
    public let sectionId: String?
    public let parentId: String?
    public let labels: [String]?
    public let priority: Int?
    public let dueString: String?
    public let dueDate: String?
    public let dueDatetime: String?
    public let assigneeId: String?
    public let duration: Int?
    public let durationUnit: String?

    public init(
        content: String,
        description: String? = nil,
        projectId: String? = nil,
        sectionId: String? = nil,
        parentId: String? = nil,
        labels: [String]? = nil,
        priority: Int? = nil,
        dueString: String? = nil,
        dueDate: String? = nil,
        dueDatetime: String? = nil,
        assigneeId: String? = nil,
        duration: Int? = nil,
        durationUnit: String? = nil
    ) {
        self.content = content
        self.description = description
        self.projectId = projectId
        self.sectionId = sectionId
        self.parentId = parentId
        self.labels = labels
        self.priority = priority
        self.dueString = dueString
        self.dueDate = dueDate
        self.dueDatetime = dueDatetime
        self.assigneeId = assigneeId
        self.duration = duration
        self.durationUnit = durationUnit
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["content": content]
        if let description { dict["description"] = description }
        if let projectId { dict["project_id"] = projectId }
        if let sectionId { dict["section_id"] = sectionId }
        if let parentId { dict["parent_id"] = parentId }
        if let labels { dict["labels"] = labels }
        if let priority { dict["priority"] = priority }
        if let dueString { dict["due_string"] = dueString }
        if let dueDate { dict["due_date"] = dueDate }
        if let dueDatetime { dict["due_datetime"] = dueDatetime }
        if let assigneeId { dict["assignee_id"] = assigneeId }
        if let duration { dict["duration"] = duration }
        if let durationUnit { dict["duration_unit"] = durationUnit }
        return dict
    }
}

public struct TodoistDue: Codable, Sendable {
    public let date: String
    public let datetime: String?
    public let string: String
    public let timezone: String?
    public let isRecurring: Bool
}

public struct TodoistDuration: Codable, Sendable {
    public let amount: Int
    public let unit: String
}

public struct TodoistSection: Codable, Identifiable, Sendable {
    public let id: String
    public let projectId: String
    public let order: Int
    public let name: String
}

public struct TodoistLabel: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let color: String?
    public let order: Int
    public let isFavorite: Bool
}

public struct TodoistComment: Codable, Identifiable, Sendable {
    public let id: String
    public let content: String
    public let taskId: String?
    public let projectId: String?
    public let postedAt: String
    public let attachment: TodoistAttachment?
}

public struct TodoistAttachment: Codable, Sendable {
    public let fileName: String
    public let fileType: String
    public let fileUrl: String
    public let resourceType: String
}

// MARK: - API v1 Additional Models

public struct TodoistCompletedTask: Codable, Identifiable, Sendable {
    public let id: String
    public let taskId: String
    public let content: String
    public let projectId: String
    public let completedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case taskId = "task_id"
        case content
        case projectId = "project_id"
        case completedAt = "completed_at"
    }
}

public struct TodoistStats: Codable, Sendable {
    public let karmaLastUpdate: Double?
    public let karmaUpdateReasons: [String]?
    public let daysItems: [TodoistDayStats]?
    public let completedCount: Int?
    public let weekItems: [TodoistWeekStats]?
    public let goalsDaily: Int?
    public let goalsWeekly: Int?

    enum CodingKeys: String, CodingKey {
        case karmaLastUpdate = "karma_last_update"
        case karmaUpdateReasons = "karma_update_reasons"
        case daysItems = "days_items"
        case completedCount = "completed_count"
        case weekItems = "week_items"
        case goalsDaily = "goals_daily"
        case goalsWeekly = "goals_weekly"
    }
}

public struct TodoistDayStats: Codable, Sendable {
    public let date: String
    public let totalCompleted: Int

    enum CodingKeys: String, CodingKey {
        case date
        case totalCompleted = "total_completed"
    }
}

public struct TodoistWeekStats: Codable, Sendable {
    public let date: String
    public let totalCompleted: Int

    enum CodingKeys: String, CodingKey {
        case date
        case totalCompleted = "total_completed"
    }
}

public struct TodoistActivity: Codable, Identifiable, Sendable {
    public let id: String
    public let objectType: String
    public let objectId: String
    public let eventType: String
    public let eventDate: String
    public let initiatorId: String?
    public let extraData: [String: String]?

    enum CodingKeys: String, CodingKey {
        case id
        case objectType = "object_type"
        case objectId = "object_id"
        case eventType = "event_type"
        case eventDate = "event_date"
        case initiatorId = "initiator_id"
        case extraData = "extra_data"
    }
}

public struct TodoistBackup: Codable, Sendable {
    public let version: String
    public let url: String
}

public struct TodoistEmail: Codable, Sendable {
    public let email: String
    public let projectId: String?

    enum CodingKeys: String, CodingKey {
        case email
        case projectId = "project_id"
    }
}

public struct TodoistWorkspace: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let description: String?
    public let createdAt: String?
    public let ownerId: String?

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case createdAt = "created_at"
        case ownerId = "owner_id"
    }
}

public struct TodoistTemplateURL: Codable, Sendable {
    public let exportedUrl: String

    enum CodingKeys: String, CodingKey {
        case exportedUrl = "exported_url"
    }
}

public struct TodoistOAuthToken: Codable, Sendable {
    public let accessToken: String
    public let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
    }
}

public struct TodoistIdMapping: Codable, Sendable {
    public let oldToNew: [String: String]
    public let newToOld: [String: String]

    enum CodingKeys: String, CodingKey {
        case oldToNew = "old_to_new"
        case newToOld = "new_to_old"
    }
}

// MARK: - Sync API Models

public struct TodoistSyncResponse: Codable, Sendable {
    public let syncToken: String
    public let fullSync: Bool
    public let fullSyncDateUtc: String?
    public let projects: [TodoistProject]?
    public let items: [TodoistTask]?
    public let labels: [TodoistLabel]?
    public let sections: [TodoistSection]?
    public let workspaces: [TodoistWorkspace]?
    public let liveNotifications: [TodoistNotification]?
    public let tempIdMapping: [String: String]
    public let syncStatus: [String: String]?

    enum CodingKeys: String, CodingKey {
        case syncToken = "sync_token"
        case fullSync = "full_sync"
        case fullSyncDateUtc = "full_sync_date_utc"
        case projects, items, labels, sections, workspaces
        case liveNotifications = "live_notifications"
        case tempIdMapping = "temp_id_mapping"
        case syncStatus = "sync_status"
    }
}

public struct TodoistNotification: Codable, Identifiable, Sendable {
    public let id: String
    public let type: String
    public let isRead: Bool?
    public let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, type
        case isRead = "is_read"
        case createdAt = "created_at"
    }
}

// @unchecked Sendable: args is [String: Any] for Todoist Sync API flexibility; values are JSON primitives
public struct TodoistCommand: @unchecked Sendable {
    public let type: String
    public let uuid: String
    public let tempId: String?
    public let args: [String: Any]

    public init(type: String, uuid: String, tempId: String? = nil, args: [String: Any]) {
        self.type = type
        self.uuid = uuid
        self.tempId = tempId
        self.args = args
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "type": type,
            "uuid": uuid,
            "args": args
        ]
        if let tempId {
            dict["temp_id"] = tempId
        }
        return dict
    }
}

// MARK: - UI Extensions

/// Todoist UI Extension handler for Doist Cards
public struct TodoistUIExtension: Sendable {
    public enum ExtensionType: String, Sendable {
        case contextMenu = "context-menu"
        case composer = "composer"
        case settings = "settings"
    }

    public struct Request: Codable, Sendable {
        public let extensionType: String
        public let action: String
        public let context: RequestContext
        public let maxCardVersion: String

        enum CodingKeys: String, CodingKey {
            case extensionType = "extension_type"
            case action
            case context
            case maxCardVersion = "max_card_version"
        }
    }

    public struct RequestContext: Codable, Sendable {
        public let user: UserContext
        public let theme: String
        public let platform: String
        public let todoist: TodoistContext?
    }

    public struct UserContext: Codable, Sendable {
        public let id: String
        public let email: String
        public let fullName: String
        public let timezone: String
    }

    public struct TodoistContext: Codable, Sendable {
        public let projectId: String?
        public let taskId: String?
        public let labelId: String?
        public let filterId: String?
    }

    /// Verify HMAC signature from Todoist
    public static func verifySignature(payload: Data, signature: String, clientSecret: String) -> Bool {
        let key = SymmetricKey(data: Data(clientSecret.utf8))
        let hmac = HMAC<SHA256>.authenticationCode(for: payload, using: key)
        let computedSignature = Data(hmac).base64EncodedString()
        return computedSignature == signature
    }
}

// MARK: - Bridge Actions

public enum TodoistBridge: Sendable {
    case displayNotification(message: String, actionUrl: String?)
    case composerAppend(text: String)
    case requestSync
    case finished

    public func toJSON() -> [String: Any] {
        switch self {
        case let .displayNotification(message, actionUrl):
            var bridge: [String: Any] = ["type": "display.notification", "message": message]
            if let actionUrl { bridge["action_url"] = actionUrl }
            return bridge
        case let .composerAppend(text):
            return ["type": "composer.append", "text": text]
        case .requestSync:
            return ["type": "request.sync"]
        case .finished:
            return ["type": "finished"]
        }
    }
}

// MARK: - Errors

public enum TodoistError: Error, Sendable {
    case notAuthenticated
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int, message: String?)
    case syncFailed
    case rateLimited
    case oauthNotConfigured
    case tokenRevocationFailed
}
