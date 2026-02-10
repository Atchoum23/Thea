//
//  TodoistIntegration.swift
//  Thea
//
//  Todoist integration for task management
//  Based on: API v1 (unified REST + Sync), UI Extensions
//  Updated Feb 2026 to support API v1 migration from REST v2/Sync v9
//

import Foundation
import CryptoKit

// MARK: - Todoist Client

/// Comprehensive Todoist API client supporting unified API v1, REST v2, Sync v9, and UI Extensions
public actor TodoistClient {
    private let baseURL = "https://api.todoist.com"
    private let apiV1Endpoint = "/api/v1"
    private let syncEndpoint = "/sync/v9/sync"  // Legacy, still supported
    private let restEndpoint = "/rest/v2"  // Legacy, still supported

    private var accessToken: String?
    private var syncToken: String = "*"
    private var tempIdMapping: [String: String] = [:]
    private var clientId: String?
    private var clientSecret: String?

    public init() {}

    // MARK: - Configuration

    public func configureOAuth(clientId: String, clientSecret: String) {
        self.clientId = clientId
        self.clientSecret = clientSecret
    }

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

    // MARK: - API v1 Endpoints (New unified API)

    /// Quick add task with natural language parsing
    public func quickAddTask(text: String) async throws -> TodoistTask {
        try await apiV1Request(
            endpoint: "/tasks/quick",
            method: "POST",
            body: ["text": text]
        )
    }

    /// Get completed tasks by completion date
    public func getCompletedTasks(
        projectId: String? = nil,
        since: Date? = nil,
        until: Date? = nil,
        limit: Int = 50
    ) async throws -> [TodoistCompletedTask] {
        var params: [String: String] = ["limit": String(limit)]
        if let projectId { params["project_id"] = projectId }
        if let since { params["since"] = ISO8601DateFormatter().string(from: since) }
        if let until { params["until"] = ISO8601DateFormatter().string(from: until) }
        return try await apiV1Request(endpoint: "/tasks/completed/by_completion_date", queryParams: params)
    }

    /// Get productivity stats
    public func getProductivityStats() async throws -> TodoistStats {
        try await apiV1Request(endpoint: "/tasks/completed/stats")
    }

    /// Get activity logs
    public func getActivities(
        objectType: String? = nil,
        objectId: String? = nil,
        eventType: String? = nil,
        limit: Int = 50
    ) async throws -> [TodoistActivity] {
        var params: [String: String] = ["limit": String(limit)]
        if let objectType { params["object_type"] = objectType }
        if let objectId { params["object_id"] = objectId }
        if let eventType { params["event_type"] = eventType }
        return try await apiV1Request(endpoint: "/activities", queryParams: params)
    }

    /// Get archived projects
    public func getArchivedProjects() async throws -> [TodoistProject] {
        try await apiV1Request(endpoint: "/projects/archived")
    }

    /// Get archived sections
    public func getArchivedSections(projectId: String? = nil) async throws -> [TodoistSection] {
        var params: [String: String] = [:]
        if let projectId { params["project_id"] = projectId }
        return try await apiV1Request(endpoint: "/sections/archived", queryParams: params)
    }

    /// Get backups
    public func getBackups() async throws -> [TodoistBackup] {
        try await apiV1Request(endpoint: "/backups")
    }

    /// Get or create email forwarding address
    public func getOrCreateEmail(projectId: String? = nil) async throws -> TodoistEmail {
        var body: [String: Any] = [:]
        if let projectId { body["project_id"] = projectId }
        return try await apiV1Request(endpoint: "/emails", method: "PUT", body: body)
    }

    /// Disable email forwarding
    public func disableEmail() async throws {
        let _: EmptyResponse = try await apiV1Request(endpoint: "/emails", method: "DELETE")
    }

    // MARK: - Workspaces (API v1)

    /// Get workspaces
    public func getWorkspaces() async throws -> [TodoistWorkspace] {
        let response = try await sync(resourceTypes: ["workspaces"])
        return response.workspaces ?? []
    }

    /// Create workspace
    public func createWorkspace(name: String, description: String? = nil) async throws -> TodoistSyncResponse {
        var args: [String: Any] = ["name": name]
        if let description { args["description"] = description }
        let command = TodoistCommand(
            type: "workspace_add",
            uuid: UUID().uuidString,
            tempId: UUID().uuidString,
            args: args
        )
        return try await executeCommands([command])
    }

    /// Update workspace
    public func updateWorkspace(id: String, name: String? = nil, description: String? = nil) async throws -> TodoistSyncResponse {
        var args: [String: Any] = ["id": id]
        if let name { args["name"] = name }
        if let description { args["description"] = description }
        let command = TodoistCommand(
            type: "workspace_update",
            uuid: UUID().uuidString,
            args: args
        )
        return try await executeCommands([command])
    }

    /// Invite users to workspace
    public func inviteToWorkspace(id: String, emails: [String], role: String = "MEMBER") async throws -> TodoistSyncResponse {
        let command = TodoistCommand(
            type: "workspace_invite",
            uuid: UUID().uuidString,
            args: [
                "id": id,
                "email_list": emails,
                "role": role
            ]
        )
        return try await executeCommands([command])
    }

    // MARK: - Workspace Filters (API v1)

    /// Add workspace filter
    public func addWorkspaceFilter(workspaceId: String, name: String, query: String, isFavorite: Bool = false) async throws -> TodoistSyncResponse {
        let command = TodoistCommand(
            type: "workspace_filter_add",
            uuid: UUID().uuidString,
            tempId: UUID().uuidString,
            args: [
                "workspace_id": workspaceId,
                "name": name,
                "query": query,
                "is_favorite": isFavorite
            ]
        )
        return try await executeCommands([command])
    }

    /// Update workspace filter
    public func updateWorkspaceFilter(id: String, name: String? = nil, query: String? = nil, isFavorite: Bool? = nil) async throws -> TodoistSyncResponse {
        var args: [String: Any] = ["id": id]
        if let name { args["name"] = name }
        if let query { args["query"] = query }
        if let isFavorite { args["is_favorite"] = isFavorite }
        let command = TodoistCommand(
            type: "workspace_filter_update",
            uuid: UUID().uuidString,
            args: args
        )
        return try await executeCommands([command])
    }

    /// Delete workspace filter
    public func deleteWorkspaceFilter(id: String) async throws -> TodoistSyncResponse {
        let command = TodoistCommand(
            type: "workspace_filter_delete",
            uuid: UUID().uuidString,
            args: ["id": id]
        )
        return try await executeCommands([command])
    }

    // MARK: - Notifications (API v1)

    /// Mark notifications as read
    public func markNotificationsRead(ids: [String]) async throws -> TodoistSyncResponse {
        let command = TodoistCommand(
            type: "live_notifications_mark_read",
            uuid: UUID().uuidString,
            args: ["ids": ids]
        )
        return try await executeCommands([command])
    }

    /// Mark notifications as unread
    public func markNotificationsUnread(ids: [String]) async throws -> TodoistSyncResponse {
        let command = TodoistCommand(
            type: "live_notifications_mark_unread",
            uuid: UUID().uuidString,
            args: ["ids": ids]
        )
        return try await executeCommands([command])
    }

    /// Mark all notifications as read
    public func markAllNotificationsRead() async throws -> TodoistSyncResponse {
        let command = TodoistCommand(
            type: "live_notifications_mark_read_all",
            uuid: UUID().uuidString,
            args: [:]
        )
        return try await executeCommands([command])
    }

    // MARK: - Karma & Goals

    /// Update karma goals (e.g., vacation mode)
    public func updateKarmaGoals(vacationMode: Bool? = nil, dailyGoal: Int? = nil, weeklyGoal: Int? = nil) async throws -> TodoistSyncResponse {
        var args: [String: Any] = [:]
        if let vacationMode { args["vacation_mode"] = vacationMode ? 1 : 0 }
        if let dailyGoal { args["daily_goal"] = dailyGoal }
        if let weeklyGoal { args["weekly_goal"] = weeklyGoal }
        let command = TodoistCommand(
            type: "update_goals",
            uuid: UUID().uuidString,
            args: args
        )
        return try await executeCommands([command])
    }

    // MARK: - Templates (API v1)

    /// Export project as template file
    public func exportTemplateFile(projectId: String) async throws -> Data {
        try await apiV1RawRequest(endpoint: "/templates/file", queryParams: ["project_id": projectId])
    }

    /// Export project as template URL
    public func exportTemplateURL(projectId: String) async throws -> TodoistTemplateURL {
        try await apiV1Request(endpoint: "/templates/url", queryParams: ["project_id": projectId])
    }

    // MARK: - OAuth & Token Management (API v1)

    /// Migrate personal token to OAuth token
    public func migratePersonalToken(personalToken: String, scope: String) async throws -> TodoistOAuthToken {
        guard let clientId, let clientSecret else {
            throw TodoistError.oauthNotConfigured
        }
        return try await apiV1Request(
            endpoint: "/access_tokens/migrate_personal_token",
            method: "POST",
            body: [
                "client_id": clientId,
                "client_secret": clientSecret,
                "personal_token": personalToken,
                "scope": scope
            ]
        )
    }

    /// Revoke access token (RFC 7009 compliant)
    public func revokeToken(token: String) async throws {
        guard let clientId, let clientSecret else {
            throw TodoistError.oauthNotConfigured
        }

        guard let url = URL(string: baseURL + apiV1Endpoint + "/revoke") else {
            throw TodoistError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        // HTTP Basic Auth with client credentials
        let credentials = "\(clientId):\(clientSecret)"
        if let credentialsData = credentials.data(using: .utf8) {
            let base64Credentials = credentialsData.base64EncodedString()
            request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["token": token])

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw TodoistError.tokenRevocationFailed
        }
    }

    /// Delete/revoke access token (legacy endpoint)
    public func deleteAccessToken(token: String) async throws {
        guard let clientId, let clientSecret else {
            throw TodoistError.oauthNotConfigured
        }
        let _: EmptyResponse = try await apiV1Request(
            endpoint: "/access_tokens",
            method: "DELETE",
            queryParams: [
                "client_id": clientId,
                "client_secret": clientSecret,
                "access_token": token
            ]
        )
    }

    // MARK: - ID Translation (API v1)

    /// Translate between old (numeric) and new (string) IDs
    public func translateIds(objectType: String, ids: [String]) async throws -> TodoistIdMapping {
        let idsString = ids.joined(separator: ",")
        return try await apiV1Request(endpoint: "/ids_mapping/\(objectType)/\(idsString)")
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

    private func apiV1Request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        queryParams: [String: String] = [:],
        body: [String: Any]? = nil
    ) async throws -> T {
        guard let token = accessToken else {
            throw TodoistError.notAuthenticated
        }

        var urlString = baseURL + apiV1Endpoint + endpoint
        if !queryParams.isEmpty {
            let queryString = queryParams.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }.joined(separator: "&")
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

    private func apiV1RawRequest(
        endpoint: String,
        method: String = "GET",
        queryParams: [String: String] = [:]
    ) async throws -> Data {
        guard let token = accessToken else {
            throw TodoistError.notAuthenticated
        }

        var urlString = baseURL + apiV1Endpoint + endpoint
        if !queryParams.isEmpty {
            let queryString = queryParams.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }.joined(separator: "&")
            urlString += "?\(queryString)"
        }

        guard let url = URL(string: urlString) else {
            throw TodoistError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw TodoistError.invalidResponse
        }

        return data
    }

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

public struct TodoistCommand: Sendable {
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
