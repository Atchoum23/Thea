// swiftlint:disable file_length
//
//  AsanaModels.swift
//  Thea
//
//  Asana API data models, extracted from AsanaIntegration.swift
//

import Foundation
import OSLog

private let asanaLogger = Logger(subsystem: "ai.thea.app", category: "AsanaModels")

// MARK: - Data Models

public struct AsanaDataResponse<T: Decodable>: Decodable {
    public let data: T
}

public struct AsanaTask: Codable, Identifiable, Sendable {
    public let gid: String
    public let name: String
    public let completed: Bool
    public let dueOn: String?
    public let dueAt: String?
    public let notes: String?
    public let assignee: AsanaUserRef?
    public let tags: [AsanaTagRef]?
    public let customFields: [AsanaCustomField]?

    public var id: String { gid }

    enum CodingKeys: String, CodingKey {
        case gid, name, completed, notes, assignee, tags
        case dueOn = "due_on"
        case dueAt = "due_at"
        case customFields = "custom_fields"
    }
}

public struct AsanaTaskCreate: Sendable {
    public let name: String
    public let notes: String?
    public let projectGid: String?
    public let sectionGid: String?
    public let assigneeGid: String?
    public let dueOn: String?
    public let dueAt: String?
    public let tags: [String]?

    public init(
        name: String,
        notes: String? = nil,
        projectGid: String? = nil,
        sectionGid: String? = nil,
        assigneeGid: String? = nil,
        dueOn: String? = nil,
        dueAt: String? = nil,
        tags: [String]? = nil
    ) {
        self.name = name
        self.notes = notes
        self.projectGid = projectGid
        self.sectionGid = sectionGid
        self.assigneeGid = assigneeGid
        self.dueOn = dueOn
        self.dueAt = dueAt
        self.tags = tags
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["name": name]
        if let notes { dict["notes"] = notes }
        if let projectGid { dict["projects"] = [projectGid] }
        if let sectionGid { dict["memberships"] = [["section": sectionGid]] }
        if let assigneeGid { dict["assignee"] = assigneeGid }
        if let dueOn { dict["due_on"] = dueOn }
        if let dueAt { dict["due_at"] = dueAt }
        if let tags { dict["tags"] = tags }
        return dict
    }
}

public struct AsanaProject: Codable, Identifiable, Sendable {
    public let gid: String
    public let name: String
    public let notes: String?
    public let color: String?
    public let archived: Bool?
    public let dueOn: String?
    public let currentStatus: AsanaProjectStatus?

    public var id: String { gid }

    enum CodingKeys: String, CodingKey {
        case gid, name, notes, color, archived
        case dueOn = "due_on"
        case currentStatus = "current_status"
    }
}

public struct AsanaProjectStatus: Codable, Sendable {
    public let color: String
    public let text: String?
    public let author: AsanaUserRef?
}

public struct AsanaTaskCount: Codable, Sendable {
    public let numTasks: Int
    public let numCompletedTasks: Int
    public let numIncompleteTasks: Int
    public let numMilestoneTasks: Int

    enum CodingKeys: String, CodingKey {
        case numTasks = "num_tasks"
        case numCompletedTasks = "num_completed_tasks"
        case numIncompleteTasks = "num_incomplete_tasks"
        case numMilestoneTasks = "num_milestone_tasks"
    }
}

public struct AsanaSection: Codable, Identifiable, Sendable {
    public let gid: String
    public let name: String

    public var id: String { gid }
}

public struct AsanaPortfolio: Codable, Identifiable, Sendable {
    public let gid: String
    public let name: String
    public let color: String?
    public let createdAt: String?

    public var id: String { gid }

    enum CodingKeys: String, CodingKey {
        case gid, name, color
        case createdAt = "created_at"
    }
}

public struct AsanaGoal: Codable, Identifiable, Sendable {
    public let gid: String
    public let name: String
    public let notes: String?
    public let htmlNotes: String?
    public let dueOn: String?
    public let startOn: String?
    public let status: String?
    public let owner: AsanaUserRef?
    public let metric: AsanaGoalMetric?
    public let currentStatusUpdate: AsanaStatusUpdateRef?
    public let timePeriod: AsanaTimePeriodRef?
    public let isWorkspaceLevel: Bool?
    public let numLikes: Int?
    public let liked: Bool?

    public var id: String { gid }

    enum CodingKeys: String, CodingKey {
        case gid, name, notes, status, owner, metric, liked
        case htmlNotes = "html_notes"
        case dueOn = "due_on"
        case startOn = "start_on"
        case currentStatusUpdate = "current_status_update"
        case timePeriod = "time_period"
        case isWorkspaceLevel = "is_workspace_level"
        case numLikes = "num_likes"
    }
}

public struct AsanaGoalMetric: Codable, Sendable {
    public let gid: String?
    public let unit: String?
    public let currentNumberValue: Double?
    public let targetNumberValue: Double?
    public let currencyCode: String?
    public let progressSource: String?

    enum CodingKeys: String, CodingKey {
        case gid, unit
        case currentNumberValue = "current_number_value"
        case targetNumberValue = "target_number_value"
        case currencyCode = "currency_code"
        case progressSource = "progress_source"
    }
}

public struct AsanaGoalRelationship: Codable, Identifiable, Sendable {
    public let gid: String
    public let relationshipType: String
    public let resource: AsanaResourceRef?
    public let goal: AsanaResourceRef?
    public let contributionWeight: Double?
    public let createdAt: String?

    public var id: String { gid }

    enum CodingKeys: String, CodingKey {
        case gid, resource, goal
        case relationshipType = "relationship_type"
        case contributionWeight = "contribution_weight"
        case createdAt = "created_at"
    }
}

public struct AsanaResourceRef: Codable, Sendable {
    public let gid: String
    public let resourceType: String?
    public let name: String?

    enum CodingKeys: String, CodingKey {
        case gid, name
        case resourceType = "resource_type"
    }
}

public struct AsanaStatusUpdateRef: Codable, Sendable {
    public let gid: String
    public let resourceSubtype: String?
    public let title: String?

    enum CodingKeys: String, CodingKey {
        case gid, title
        case resourceSubtype = "resource_subtype"
    }
}

public struct AsanaTimePeriodRef: Codable, Sendable {
    public let gid: String
    public let displayName: String?
    public let period: String?
    public let startOn: String?
    public let endOn: String?

    enum CodingKeys: String, CodingKey {
        case gid, period
        case displayName = "display_name"
        case startOn = "start_on"
        case endOn = "end_on"
    }
}

public struct AsanaTimePeriod: Codable, Identifiable, Sendable {
    public let gid: String
    public let displayName: String?
    public let period: String?
    public let startOn: String?
    public let endOn: String?
    public let parent: AsanaTimePeriodRef?

    public var id: String { gid }

    enum CodingKeys: String, CodingKey {
        case gid, period, parent
        case displayName = "display_name"
        case startOn = "start_on"
        case endOn = "end_on"
    }
}

public struct AsanaPortfolioMembership: Codable, Identifiable, Sendable {
    public let gid: String
    public let user: AsanaUserRef?
    public let portfolio: AsanaResourceRef?

    public var id: String { gid }
}

public struct AsanaCustomFieldSetting: Codable, Sendable {
    public let gid: String
    public let customField: AsanaCustomField?
    public let isImportant: Bool?
    public let project: AsanaResourceRef?
    public let portfolio: AsanaResourceRef?

    enum CodingKeys: String, CodingKey {
        case gid, project, portfolio
        case customField = "custom_field"
        case isImportant = "is_important"
    }
}

public struct AsanaTypeaheadResult: Codable, Identifiable, Sendable {
    public let gid: String
    public let name: String
    public let resourceType: String?

    public var id: String { gid }

    enum CodingKeys: String, CodingKey {
        case gid, name
        case resourceType = "resource_type"
    }
}

public enum AsanaTypeaheadType: String, Sendable {
    case user
    case project
    case portfolio
    case tag
    case task
    case customField = "custom_field"
    case team
    case goal
}

public struct AsanaFavorite: Codable, Identifiable, Sendable {
    public let gid: String
    public let name: String?
    public let resourceType: String?

    public var id: String { gid }

    enum CodingKeys: String, CodingKey {
        case gid, name
        case resourceType = "resource_type"
    }
}

public struct AsanaMembership: Codable, Identifiable, Sendable {
    public let gid: String
    public let parent: AsanaResourceRef?
    public let member: AsanaResourceRef?

    public var id: String { gid }
}

public struct AsanaStatusUpdate: Codable, Identifiable, Sendable {
    public let gid: String
    public let title: String?
    public let text: String?
    public let htmlText: String?
    public let statusType: String?
    public let author: AsanaUserRef?
    public let createdAt: String?

    public var id: String { gid }

    enum CodingKeys: String, CodingKey {
        case gid, title, text, author
        case htmlText = "html_text"
        case statusType = "status_type"
        case createdAt = "created_at"
    }
}

public struct AsanaUser: Codable, Identifiable, Sendable {
    public let gid: String
    public let name: String
    public let email: String?
    public let workspaces: [AsanaWorkspace]?

    public var id: String { gid }
}

public struct AsanaUserRef: Codable, Sendable {
    public let gid: String
    public let name: String?
}

public struct AsanaWorkspace: Codable, Identifiable, Sendable {
    public let gid: String
    public let name: String

    public var id: String { gid }
}

public struct AsanaTeam: Codable, Identifiable, Sendable {
    public let gid: String
    public let name: String

    public var id: String { gid }
}

public struct AsanaTagRef: Codable, Sendable {
    public let gid: String
    public let name: String?
}

public struct AsanaCustomField: Codable, Sendable {
    public let gid: String
    public let name: String
    public let type: String
    public let textValue: String?
    public let numberValue: Double?

    enum CodingKeys: String, CodingKey {
        case gid, name, type
        case textValue = "text_value"
        case numberValue = "number_value"
    }
}

// MARK: - Batch API Models

// @unchecked Sendable: [String: Any]? data dict required for Asana batch API's dynamic payload;
// struct is value-typed, all fields are set at init and only read thereafter
public struct AsanaBatchAction: @unchecked Sendable {
    public let relativePath: String
    public let method: String
    public let data: [String: Any]?

    public init(relativePath: String, method: String, data: [String: Any]? = nil) {
        self.relativePath = relativePath
        self.method = method
        self.data = data
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "relative_path": relativePath,
            "method": method
        ]
        if let data {
            dict["data"] = data
        }
        return dict
    }
}

public struct AsanaBatchResult: Codable, Sendable {
    public let statusCode: Int
    public let body: AsanaAnyCodable?

    enum CodingKeys: String, CodingKey {
        case statusCode = "status_code"
        case body
    }
}

// MARK: - Webhook Models

public struct AsanaWebhook: Codable, Identifiable, Sendable {
    public let gid: String
    public let resourceGid: String
    public let target: String
    public let active: Bool
    public let createdAt: String?

    public var id: String { gid }

    enum CodingKeys: String, CodingKey {
        case gid, target, active
        case resourceGid = "resource"
        case createdAt = "created_at"
    }
}

public struct AsanaWebhookFilter: Sendable {
    public let resourceType: String
    public let action: String?
    public let fields: [String]?

    public init(resourceType: String, action: String? = nil, fields: [String]? = nil) {
        self.resourceType = resourceType
        self.action = action
        self.fields = fields
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["resource_type": resourceType]
        if let action { dict["action"] = action }
        if let fields { dict["fields"] = fields }
        return dict
    }
}

public struct AsanaWebhookEvent: Codable, Sendable {
    public let action: String
    public let resource: AsanaWebhookResource
    public let parent: AsanaWebhookResource?
    public let createdAt: String

    enum CodingKeys: String, CodingKey {
        case action, resource, parent
        case createdAt = "created_at"
    }
}

public struct AsanaWebhookResource: Codable, Sendable {
    public let gid: String
    public let resourceType: String

    enum CodingKeys: String, CodingKey {
        case gid
        case resourceType = "resource_type"
    }
}

// MARK: - Helper Types

// @unchecked Sendable: type-erased Any storage for Asana's heterogeneous JSON field values;
// values are Codable primitives (String, Int, Double, Bool, [String: Any], Array) in practice
public struct AsanaAnyCodable: Codable, @unchecked Sendable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = NSNull()
            return
        }
        do { value = try container.decode(String.self); return } catch {}
        do { value = try container.decode(Int.self); return } catch {}
        do { value = try container.decode(Double.self); return } catch {}
        do { value = try container.decode(Bool.self); return } catch {}
        do { value = (try container.decode([AsanaAnyCodable].self)).map { $0.value }; return } catch {}
        do {
            let keyedContainer = try decoder.container(keyedBy: DynamicCodingKey.self)
            var dict: [String: Any] = [:]
            for key in keyedContainer.allKeys {
                let nested = try keyedContainer.decode(AsanaAnyCodable.self, forKey: key)
                dict[key.stringValue] = nested.value
            }
            value = dict
            return
        } catch {
            asanaLogger.debug("AsanaAnyCodable: falling back to NSNull for unrecognised type: \(error.localizedDescription, privacy: .public)")
        }
        value = NSNull()
    }

    private struct DynamicCodingKey: CodingKey {
        var stringValue: String
        var intValue: Int?
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { self.stringValue = String(intValue); self.intValue = intValue }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let string as String:
            try container.encode(string)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let bool as Bool:
            try container.encode(bool)
        case let array as [Any]:
            try container.encode(array.map { AsanaAnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AsanaAnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

struct AsanaEmptyResponse: Codable {}

// MARK: - Errors

public enum AsanaError: Error, Sendable {
    case notAuthenticated
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int, message: String?)
    case rateLimited
    case workspaceRequired
    case batchLimitExceeded
    case emptyBatchRequest
    case mcpError
    case mcpRequestFailed(code: Int, message: String)
    case mcpNoResult
}
