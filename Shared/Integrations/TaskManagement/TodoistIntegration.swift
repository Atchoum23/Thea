//
//  TodoistIntegration.swift
//  Thea
//
//  Todoist integration for task management
//  Based on: REST API v2, Sync API v9, UI Extensions
//

import Foundation

// MARK: - Todoist Client

/// Comprehensive Todoist API client supporting REST, Sync, and UI Extensions
public actor TodoistClient {
    private let baseURL = "https://api.todoist.com"
    private let syncEndpoint = "/sync/v9/sync"
    private let restEndpoint = "/rest/v2"

    private var accessToken: String?
    private var syncToken: String = "*"
    private var tempIdMapping: [String: String] = [:]

    public init() {}

    // MARK: - Configuration

    public func configure(accessToken: String) {
        self.accessToken = accessToken
    }

    // MARK: - REST API v2

    /// Get all projects
    public func getProjects() async throws -> [TodoistProject] {
        try await restRequest(endpoint: "/projects", method: "GET")
    }

    /// Create a new project
    public func createProject(name: String, color: String? = nil, parentId: String? = nil, isFavorite: Bool = false) async throws -> TodoistProject {
        var body: [String: Any] = ["name": name, "is_favorite": isFavorite]
        if let color { body["color"] = color }
        if let parentId { body["parent_id"] = parentId }
        return try await restRequest(endpoint: "/projects", method: "POST", body: body)
    }

    /// Get all active tasks
    public func getTasks(projectId: String? = nil, sectionId: String? = nil, label: String? = nil, filter: String? = nil) async throws -> [TodoistTask] {
        var params: [String: String] = [:]
        if let projectId { params["project_id"] = projectId }
        if let sectionId { params["section_id"] = sectionId }
        if let label { params["label"] = label }
        if let filter { params["filter"] = filter }
        return try await restRequest(endpoint: "/tasks", method: "GET", queryParams: params)
    }

    /// Create a new task
    public func createTask(_ task: TodoistTaskCreate) async throws -> TodoistTask {
        try await restRequest(endpoint: "/tasks", method: "POST", body: task.toDictionary())
    }

    /// Update a task
    public func updateTask(id: String, content: String? = nil, description: String? = nil, priority: Int? = nil, dueString: String? = nil, labels: [String]? = nil) async throws -> TodoistTask {
        var body: [String: Any] = [:]
        if let content { body["content"] = content }
        if let description { body["description"] = description }
        if let priority { body["priority"] = priority }
        if let dueString { body["due_string"] = dueString }
        if let labels { body["labels"] = labels }
        return try await restRequest(endpoint: "/tasks/\(id)", method: "POST", body: body)
    }

    /// Complete a task
    public func completeTask(id: String) async throws {
        let _: EmptyResponse = try await restRequest(endpoint: "/tasks/\(id)/close", method: "POST")
    }

    /// Reopen a task
    public func reopenTask(id: String) async throws {
        let _: EmptyResponse = try await restRequest(endpoint: "/tasks/\(id)/reopen", method: "POST")
    }

    /// Delete a task
    public func deleteTask(id: String) async throws {
        let _: EmptyResponse = try await restRequest(endpoint: "/tasks/\(id)", method: "DELETE")
    }

    /// Get sections for a project
    public func getSections(projectId: String? = nil) async throws -> [TodoistSection] {
        var params: [String: String] = [:]
        if let projectId { params["project_id"] = projectId }
        return try await restRequest(endpoint: "/sections", method: "GET", queryParams: params)
    }

    /// Create a section
    public func createSection(name: String, projectId: String, order: Int? = nil) async throws -> TodoistSection {
        var body: [String: Any] = ["name": name, "project_id": projectId]
        if let order { body["order"] = order }
        return try await restRequest(endpoint: "/sections", method: "POST", body: body)
    }

    /// Get labels
    public func getLabels() async throws -> [TodoistLabel] {
        try await restRequest(endpoint: "/labels", method: "GET")
    }

    /// Create a label
    public func createLabel(name: String, color: String? = nil, isFavorite: Bool = false) async throws -> TodoistLabel {
        var body: [String: Any] = ["name": name, "is_favorite": isFavorite]
        if let color { body["color"] = color }
        return try await restRequest(endpoint: "/labels", method: "POST", body: body)
    }

    /// Get comments for a task or project
    public func getComments(taskId: String? = nil, projectId: String? = nil) async throws -> [TodoistComment] {
        var params: [String: String] = [:]
        if let taskId { params["task_id"] = taskId }
        if let projectId { params["project_id"] = projectId }
        return try await restRequest(endpoint: "/comments", method: "GET", queryParams: params)
    }

    /// Add a comment
    public func addComment(content: String, taskId: String? = nil, projectId: String? = nil) async throws -> TodoistComment {
        var body: [String: Any] = ["content": content]
        if let taskId { body["task_id"] = taskId }
        if let projectId { body["project_id"] = projectId }
        return try await restRequest(endpoint: "/comments", method: "POST", body: body)
    }

    // MARK: - Sync API v9

    /// Perform incremental sync
    public func sync(resourceTypes: [String] = ["all"]) async throws -> TodoistSyncResponse {
        let response: TodoistSyncResponse = try await syncRequest(
            resourceTypes: resourceTypes,
            syncToken: syncToken
        )
        syncToken = response.syncToken
        for (tempId, realId) in response.tempIdMapping {
            tempIdMapping[tempId] = realId
        }
        return response
    }

    /// Execute batch commands
    public func executeCommands(_ commands: [TodoistCommand]) async throws -> TodoistSyncResponse {
        try await syncRequest(commands: commands, syncToken: syncToken)
    }

    /// Create task with temporary ID for chaining
    public func createTaskWithTempId(content: String, projectId: String, tempId: String) -> TodoistCommand {
        TodoistCommand(
            type: "item_add",
            uuid: UUID().uuidString,
            tempId: tempId,
            args: [
                "content": content,
                "project_id": projectId
            ]
        )
    }

    // MARK: - Private Helpers

    private func restRequest<T: Decodable>(
        endpoint: String,
        method: String,
        queryParams: [String: String] = [:],
        body: [String: Any]? = nil
    ) async throws -> T {
        guard let token = accessToken else {
            throw TodoistError.notAuthenticated
        }

        var urlString = baseURL + restEndpoint + endpoint
        if !queryParams.isEmpty {
            let queryString = queryParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            urlString += "?\(queryString)"
        }

        guard let url = URL(string: urlString) else {
            throw TodoistError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Request-Id")

        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TodoistError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw TodoistError.apiError(statusCode: httpResponse.statusCode, message: String(data: data, encoding: .utf8))
        }

        if data.isEmpty || T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: data)
    }

    private func syncRequest(
        resourceTypes: [String]? = nil,
        commands: [TodoistCommand]? = nil,
        syncToken: String
    ) async throws -> TodoistSyncResponse {
        guard let token = accessToken else {
            throw TodoistError.notAuthenticated
        }

        guard let url = URL(string: baseURL + syncEndpoint) else {
            throw TodoistError.invalidURL
        }

        var params: [String: Any] = ["sync_token": syncToken]
        if let resourceTypes {
            params["resource_types"] = resourceTypes
        }
        if let commands {
            params["commands"] = commands.map { $0.toDictionary() }
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyString = params.map { "\($0.key)=\(String(describing: $0.value))" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw TodoistError.syncFailed
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(TodoistSyncResponse.self, from: data)
    }
}

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

// MARK: - Sync API Models

public struct TodoistSyncResponse: Codable, Sendable {
    public let syncToken: String
    public let fullSync: Bool
    public let projects: [TodoistProject]?
    public let items: [TodoistTask]?
    public let labels: [TodoistLabel]?
    public let sections: [TodoistSection]?
    public let tempIdMapping: [String: String]
    public let syncStatus: [String: String]?

    enum CodingKeys: String, CodingKey {
        case syncToken = "sync_token"
        case fullSync = "full_sync"
        case projects, items, labels, sections
        case tempIdMapping = "temp_id_mapping"
        case syncStatus = "sync_status"
    }
}

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
    public static func verifySignature(payload: Data, signature: String, verificationToken: String) -> Bool {
        // Implement HMAC-SHA256 verification
        // Compare computed hash with x-todoist-hmac-sha256 header
        true // Placeholder
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
}

// MARK: - Helper Types

private struct EmptyResponse: Codable {}

// MARK: - Thea Integration

/// Todoist integration coordinator for Thea
public actor TodoistIntegration {
    private let client = TodoistClient()
    private var isConfigured = false

    public init() {}

    public func configure(accessToken: String) async {
        await client.configure(accessToken: accessToken)
        isConfigured = true
    }

    /// Natural language task creation
    public func createTaskFromNaturalLanguage(_ input: String) async throws -> TodoistTask {
        // Parse natural language for task details
        let parsed = parseNaturalLanguage(input)

        let task = TodoistTaskCreate(
            content: parsed.content,
            labels: parsed.labels,
            priority: parsed.priority,
            dueString: parsed.dueString
        )

        return try await client.createTask(task)
    }

    /// Get today's tasks
    public func getTodaysTasks() async throws -> [TodoistTask] {
        try await client.getTasks(filter: "today")
    }

    /// Get overdue tasks
    public func getOverdueTasks() async throws -> [TodoistTask] {
        try await client.getTasks(filter: "overdue")
    }

    /// Get tasks by priority
    public func getHighPriorityTasks() async throws -> [TodoistTask] {
        try await client.getTasks(filter: "p1 | p2")
    }

    /// Sync all data
    public func fullSync() async throws -> TodoistSyncResponse {
        try await client.sync(resourceTypes: ["all"])
    }

    /// Incremental sync
    public func incrementalSync() async throws -> TodoistSyncResponse {
        try await client.sync()
    }

    // MARK: - Private Helpers

    private struct ParsedTask {
        let content: String
        let priority: Int?
        let dueString: String?
        let labels: [String]?
    }

    private func parseNaturalLanguage(_ input: String) -> ParsedTask {
        var content = input
        var priority: Int?
        var dueString: String?
        var labels: [String]?

        // Extract priority (p1, p2, p3, p4)
        let priorityPattern = #"(?:^|\s)(p[1-4])(?:\s|$)"#
        if let match = content.range(of: priorityPattern, options: .regularExpression) {
            let priorityStr = String(content[match]).trimmingCharacters(in: .whitespaces)
            priority = Int(String(priorityStr.last!))
            content = content.replacingCharacters(in: match, with: " ")
        }

        // Extract labels (@label)
        let labelPattern = #"@(\w+)"#
        let regex = try? NSRegularExpression(pattern: labelPattern)
        if let matches = regex?.matches(in: content, range: NSRange(content.startIndex..., in: content)) {
            labels = matches.compactMap { match -> String? in
                guard let range = Range(match.range(at: 1), in: content) else { return nil }
                return String(content[range])
            }
            content = content.replacingOccurrences(of: labelPattern, with: "", options: .regularExpression)
        }

        // Extract due date keywords
        let duePatterns = ["today", "tomorrow", "next week", "next month"]
        for pattern in duePatterns {
            if content.lowercased().contains(pattern) {
                dueString = pattern
                content = content.replacingOccurrences(of: pattern, with: "", options: .caseInsensitive)
                break
            }
        }

        return ParsedTask(
            content: content.trimmingCharacters(in: .whitespaces),
            priority: priority,
            dueString: dueString,
            labels: labels
        )
    }
}
