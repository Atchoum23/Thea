// swiftlint:disable file_length
//
//  AsanaIntegration.swift
//  Thea
//
//  Asana integration with MCP Server support
//  Based on: REST API, Webhooks, App Components, Script Actions, MCP Server
//  Updated Feb 2026 with Goal Relationships, Portfolio Memberships, Typeahead
//

import Foundation
import CryptoKit

// MARK: - Asana Client

/// Comprehensive Asana API client with MCP server integration
public actor AsanaClient {
    private let baseURL = "https://app.asana.com/api/1.0"
    private let mcpURL = "https://mcp.asana.com/v2/mcp"

    private var accessToken: String?
    private var workspaceGid: String?

    public init() {}

    // MARK: - Configuration

    public func configure(accessToken: String, workspaceGid: String? = nil) {
        self.accessToken = accessToken
        self.workspaceGid = workspaceGid
    }

    // MARK: - Tasks

    /// Get tasks from a project
    public func getTasks(projectGid: String, completedSince: Date? = nil) async throws -> [AsanaTask] {
        var params: [String: String] = ["opt_fields": "name,completed,due_on,due_at,assignee,notes,tags,custom_fields"]
        if let completedSince {
            params["completed_since"] = ISO8601DateFormatter().string(from: completedSince)
        }
        let response: AsanaDataResponse<[AsanaTask]> = try await request(
            endpoint: "/projects/\(projectGid)/tasks",
            queryParams: params
        )
        return response.data
    }

    /// Create a task
    public func createTask(_ task: AsanaTaskCreate) async throws -> AsanaTask {
        let response: AsanaDataResponse<AsanaTask> = try await request(
            endpoint: "/tasks",
            method: "POST",
            body: ["data": task.toDictionary()]
        )
        return response.data
    }

    /// Update a task
    public func updateTask(gid: String, updates: [String: Any]) async throws -> AsanaTask {
        let response: AsanaDataResponse<AsanaTask> = try await request(
            endpoint: "/tasks/\(gid)",
            method: "PUT",
            body: ["data": updates]
        )
        return response.data
    }

    /// Complete a task
    public func completeTask(gid: String) async throws -> AsanaTask {
        try await updateTask(gid: gid, updates: ["completed": true])
    }

    /// Delete a task
    public func deleteTask(gid: String) async throws {
        let _: AsanaEmptyResponse = try await request(
            endpoint: "/tasks/\(gid)",
            method: "DELETE"
        )
    }

    /// Add a subtask
    public func addSubtask(parentGid: String, name: String, notes: String? = nil) async throws -> AsanaTask {
        var data: [String: Any] = ["name": name]
        if let notes { data["notes"] = notes }
        let response: AsanaDataResponse<AsanaTask> = try await request(
            endpoint: "/tasks/\(parentGid)/subtasks",
            method: "POST",
            body: ["data": data]
        )
        return response.data
    }

    /// Get task dependencies
    public func getDependencies(taskGid: String) async throws -> [AsanaTask] {
        let response: AsanaDataResponse<[AsanaTask]> = try await request(
            endpoint: "/tasks/\(taskGid)/dependencies"
        )
        return response.data
    }

    /// Set task dependencies
    public func setDependencies(taskGid: String, dependencyGids: [String]) async throws {
        let _: AsanaEmptyResponse = try await request(
            endpoint: "/tasks/\(taskGid)/addDependencies",
            method: "POST",
            body: ["data": ["dependencies": dependencyGids]]
        )
    }

    /// Search tasks in workspace
    public func searchTasks(query: String, workspaceGid: String? = nil) async throws -> [AsanaTask] {
        let workspace = workspaceGid ?? self.workspaceGid
        guard let workspace else {
            throw AsanaError.workspaceRequired
        }

        let response: AsanaDataResponse<[AsanaTask]> = try await request(
            endpoint: "/workspaces/\(workspace)/tasks/search",
            queryParams: [
                "text": query,
                "opt_fields": "name,completed,due_on,assignee,notes"
            ]
        )
        return response.data
    }

    // MARK: - Projects

    /// Get all projects
    public func getProjects(workspaceGid: String? = nil, teamGid: String? = nil) async throws -> [AsanaProject] {
        var endpoint = "/projects"
        if let teamGid {
            endpoint = "/teams/\(teamGid)/projects"
        } else if let workspace = workspaceGid ?? self.workspaceGid {
            endpoint = "/workspaces/\(workspace)/projects"
        }

        let response: AsanaDataResponse<[AsanaProject]> = try await request(
            endpoint: endpoint,
            queryParams: ["opt_fields": "name,notes,color,archived,due_on,current_status"]
        )
        return response.data
    }

    /// Create a project
    public func createProject(name: String, workspaceGid: String? = nil, teamGid: String? = nil, notes: String? = nil) async throws -> AsanaProject {
        let workspace = workspaceGid ?? self.workspaceGid
        guard let workspace else {
            throw AsanaError.workspaceRequired
        }

        var data: [String: Any] = ["name": name, "workspace": workspace]
        if let teamGid { data["team"] = teamGid }
        if let notes { data["notes"] = notes }

        let response: AsanaDataResponse<AsanaProject> = try await request(
            endpoint: "/projects",
            method: "POST",
            body: ["data": data]
        )
        return response.data
    }

    /// Get project task count
    public func getProjectTaskCount(projectGid: String) async throws -> AsanaTaskCount {
        let response: AsanaDataResponse<AsanaTaskCount> = try await request(
            endpoint: "/projects/\(projectGid)/task_counts"
        )
        return response.data
    }

    // MARK: - Portfolios

    /// Get portfolios
    public func getPortfolios(workspaceGid: String? = nil, owner: String = "me") async throws -> [AsanaPortfolio] {
        let workspace = workspaceGid ?? self.workspaceGid
        guard let workspace else {
            throw AsanaError.workspaceRequired
        }

        let response: AsanaDataResponse<[AsanaPortfolio]> = try await request(
            endpoint: "/portfolios",
            queryParams: [
                "workspace": workspace,
                "owner": owner,
                "opt_fields": "name,color,created_at,created_by,custom_field_settings"
            ]
        )
        return response.data
    }

    /// Get a specific portfolio
    public func getPortfolio(gid: String) async throws -> AsanaPortfolio {
        let response: AsanaDataResponse<AsanaPortfolio> = try await request(
            endpoint: "/portfolios/\(gid)",
            queryParams: ["opt_fields": "name,color,created_at,created_by,custom_field_settings,members,owner"]
        )
        return response.data
    }

    /// Create a portfolio
    public func createPortfolio(
        name: String,
        workspaceGid: String? = nil,
        color: String? = nil,
        owner: String? = nil
    ) async throws -> AsanaPortfolio {
        let workspace = workspaceGid ?? self.workspaceGid
        guard let workspace else {
            throw AsanaError.workspaceRequired
        }

        var data: [String: Any] = ["name": name, "workspace": workspace]
        if let color { data["color"] = color }
        if let owner { data["owner"] = owner }

        let response: AsanaDataResponse<AsanaPortfolio> = try await request(
            endpoint: "/portfolios",
            method: "POST",
            body: ["data": data]
        )
        return response.data
    }

    /// Update a portfolio
    public func updatePortfolio(gid: String, updates: [String: Any]) async throws -> AsanaPortfolio {
        let response: AsanaDataResponse<AsanaPortfolio> = try await request(
            endpoint: "/portfolios/\(gid)",
            method: "PUT",
            body: ["data": updates]
        )
        return response.data
    }

    /// Delete a portfolio
    public func deletePortfolio(gid: String) async throws {
        let _: AsanaEmptyResponse = try await request(
            endpoint: "/portfolios/\(gid)",
            method: "DELETE"
        )
    }

    /// Get portfolio items (projects)
    public func getPortfolioItems(portfolioGid: String) async throws -> [AsanaProject] {
        let response: AsanaDataResponse<[AsanaProject]> = try await request(
            endpoint: "/portfolios/\(portfolioGid)/items",
            queryParams: ["opt_fields": "name,notes,color,archived,due_on,current_status"]
        )
        return response.data
    }

    /// Add item to portfolio
    public func addItemToPortfolio(portfolioGid: String, itemGid: String, insertBefore: String? = nil, insertAfter: String? = nil) async throws {
        var data: [String: Any] = ["item": itemGid]
        if let insertBefore { data["insert_before"] = insertBefore }
        if let insertAfter { data["insert_after"] = insertAfter }

        let _: AsanaEmptyResponse = try await request(
            endpoint: "/portfolios/\(portfolioGid)/addItem",
            method: "POST",
            body: ["data": data]
        )
    }

    /// Remove item from portfolio
    public func removeItemFromPortfolio(portfolioGid: String, itemGid: String) async throws {
        let _: AsanaEmptyResponse = try await request(
            endpoint: "/portfolios/\(portfolioGid)/removeItem",
            method: "POST",
            body: ["data": ["item": itemGid]]
        )
    }

    /// Add custom field to portfolio
    public func addCustomFieldToPortfolio(portfolioGid: String, customFieldGid: String, isImportant: Bool = false, insertBefore: String? = nil, insertAfter: String? = nil) async throws -> AsanaCustomFieldSetting {
        var data: [String: Any] = ["custom_field": customFieldGid, "is_important": isImportant]
        if let insertBefore { data["insert_before"] = insertBefore }
        if let insertAfter { data["insert_after"] = insertAfter }

        let response: AsanaDataResponse<AsanaCustomFieldSetting> = try await request(
            endpoint: "/portfolios/\(portfolioGid)/addCustomFieldSetting",
            method: "POST",
            body: ["data": data]
        )
        return response.data
    }

    /// Remove custom field from portfolio
    public func removeCustomFieldFromPortfolio(portfolioGid: String, customFieldGid: String) async throws {
        let _: AsanaEmptyResponse = try await request(
            endpoint: "/portfolios/\(portfolioGid)/removeCustomFieldSetting",
            method: "POST",
            body: ["data": ["custom_field": customFieldGid]]
        )
    }

    /// Add members to portfolio
    public func addMembersToPortfolio(portfolioGid: String, members: [String]) async throws -> AsanaPortfolio {
        let response: AsanaDataResponse<AsanaPortfolio> = try await request(
            endpoint: "/portfolios/\(portfolioGid)/addMembers",
            method: "POST",
            body: ["data": ["members": members]]
        )
        return response.data
    }

    /// Remove members from portfolio
    public func removeMembersFromPortfolio(portfolioGid: String, members: [String]) async throws -> AsanaPortfolio {
        let response: AsanaDataResponse<AsanaPortfolio> = try await request(
            endpoint: "/portfolios/\(portfolioGid)/removeMembers",
            method: "POST",
            body: ["data": ["members": members]]
        )
        return response.data
    }

    // MARK: - Portfolio Memberships

    /// Get portfolio memberships
    public func getPortfolioMemberships(portfolioGid: String) async throws -> [AsanaPortfolioMembership] {
        let response: AsanaDataResponse<[AsanaPortfolioMembership]> = try await request(
            endpoint: "/portfolios/\(portfolioGid)/portfolio_memberships",
            queryParams: ["opt_fields": "user,portfolio"]
        )
        return response.data
    }

    /// Get a specific portfolio membership
    public func getPortfolioMembership(gid: String) async throws -> AsanaPortfolioMembership {
        let response: AsanaDataResponse<AsanaPortfolioMembership> = try await request(
            endpoint: "/portfolio_memberships/\(gid)",
            queryParams: ["opt_fields": "user,portfolio"]
        )
        return response.data
    }

    // MARK: - Goals

    /// Get goals
    public func getGoals(
        workspaceGid: String? = nil,
        teamGid: String? = nil,
        projectGid: String? = nil,
        portfolioGid: String? = nil,
        timePeriods: [String]? = nil,
        isWorkspaceLevel: Bool? = nil
    ) async throws -> [AsanaGoal] {
        let workspace = workspaceGid ?? self.workspaceGid
        guard let workspace else {
            throw AsanaError.workspaceRequired
        }

        var params: [String: String] = [
            "workspace": workspace,
            "opt_fields": "name,notes,due_on,start_on,status,owner,html_notes,metric,current_status_update,time_period,is_workspace_level"
        ]
        if let teamGid { params["team"] = teamGid }
        if let projectGid { params["project"] = projectGid }
        if let portfolioGid { params["portfolio"] = portfolioGid }
        if let timePeriods { params["time_periods"] = timePeriods.joined(separator: ",") }
        if let isWorkspaceLevel { params["is_workspace_level"] = String(isWorkspaceLevel) }

        let response: AsanaDataResponse<[AsanaGoal]> = try await request(
            endpoint: "/goals",
            queryParams: params
        )
        return response.data
    }

    /// Get a specific goal
    public func getGoal(gid: String) async throws -> AsanaGoal {
        let response: AsanaDataResponse<AsanaGoal> = try await request(
            endpoint: "/goals/\(gid)",
            queryParams: ["opt_fields": "name,notes,due_on,start_on,status,owner,html_notes,metric,current_status_update,time_period,is_workspace_level,likes,num_likes,followers"]
        )
        return response.data
    }

    /// Create a goal
    public func createGoal(
        name: String,
        workspaceGid: String? = nil,
        teamGid: String? = nil,
        timePeriodGid: String? = nil,
        dueOn: String? = nil,
        startOn: String? = nil,
        notes: String? = nil,
        isWorkspaceLevel: Bool = false
    ) async throws -> AsanaGoal {
        let workspace = workspaceGid ?? self.workspaceGid
        guard let workspace else {
            throw AsanaError.workspaceRequired
        }

        var data: [String: Any] = [
            "name": name,
            "workspace": workspace,
            "is_workspace_level": isWorkspaceLevel
        ]
        if let teamGid { data["team"] = teamGid }
        if let timePeriodGid { data["time_period"] = timePeriodGid }
        if let dueOn { data["due_on"] = dueOn }
        if let startOn { data["start_on"] = startOn }
        if let notes { data["notes"] = notes }

        let response: AsanaDataResponse<AsanaGoal> = try await request(
            endpoint: "/goals",
            method: "POST",
            body: ["data": data]
        )
        return response.data
    }

    /// Update a goal
    public func updateGoal(gid: String, updates: [String: Any]) async throws -> AsanaGoal {
        let response: AsanaDataResponse<AsanaGoal> = try await request(
            endpoint: "/goals/\(gid)",
            method: "PUT",
            body: ["data": updates]
        )
        return response.data
    }

    /// Get parent goals for a goal
    public func getParentGoals(goalGid: String) async throws -> [AsanaGoal] {
        let response: AsanaDataResponse<[AsanaGoal]> = try await request(
            endpoint: "/goals/\(goalGid)/parentGoals"
        )
        return response.data
    }

    // MARK: - Goal Metrics

    /// Create a goal metric
    public func createGoalMetric(
        goalGid: String,
        unit: String,
        currentValue: Double,
        targetValue: Double,
        currencyCode: String? = nil,
        progressSource: String = "manual"
    ) async throws -> AsanaGoalMetric {
        var data: [String: Any] = [
            "unit": unit,
            "current_number_value": currentValue,
            "target_number_value": targetValue,
            "progress_source": progressSource
        ]
        if let currencyCode { data["currency_code"] = currencyCode }

        let response: AsanaDataResponse<AsanaGoalMetric> = try await request(
            endpoint: "/goals/\(goalGid)/setMetric",
            method: "POST",
            body: ["data": data]
        )
        return response.data
    }

    /// Update a goal metric
    public func updateGoalMetric(goalGid: String, currentValue: Double) async throws -> AsanaGoalMetric {
        let response: AsanaDataResponse<AsanaGoalMetric> = try await request(
            endpoint: "/goals/\(goalGid)/setMetricCurrentValue",
            method: "POST",
            body: ["data": ["current_number_value": currentValue]]
        )
        return response.data
    }

    // MARK: - Goal Relationships

    /// Get goal relationships
    public func getGoalRelationships(goalGid: String) async throws -> [AsanaGoalRelationship] {
        let response: AsanaDataResponse<[AsanaGoalRelationship]> = try await request(
            endpoint: "/goals/\(goalGid)/goalRelationships",
            queryParams: ["opt_fields": "relationship_type,resource,goal,created_at"]
        )
        return response.data
    }

    /// Add a supporting relationship to a goal
    public func addSupportingRelationship(
        goalGid: String,
        supportingResourceGid: String,
        contributionWeight: Double? = nil,
        insertBefore: String? = nil,
        insertAfter: String? = nil
    ) async throws -> AsanaGoalRelationship {
        var data: [String: Any] = ["supporting_resource": supportingResourceGid]
        if let contributionWeight { data["contribution_weight"] = contributionWeight }
        if let insertBefore { data["insert_before"] = insertBefore }
        if let insertAfter { data["insert_after"] = insertAfter }

        let response: AsanaDataResponse<AsanaGoalRelationship> = try await request(
            endpoint: "/goals/\(goalGid)/addSupportingRelationship",
            method: "POST",
            body: ["data": data]
        )
        return response.data
    }

    /// Remove a supporting relationship from a goal
    public func removeSupportingRelationship(goalGid: String, supportingResourceGid: String) async throws {
        let _: AsanaEmptyResponse = try await request(
            endpoint: "/goals/\(goalGid)/removeSupportingRelationship",
            method: "POST",
            body: ["data": ["supporting_resource": supportingResourceGid]]
        )
    }

    /// Get a specific goal relationship
    public func getGoalRelationship(gid: String) async throws -> AsanaGoalRelationship {
        let response: AsanaDataResponse<AsanaGoalRelationship> = try await request(
            endpoint: "/goal_relationships/\(gid)",
            queryParams: ["opt_fields": "relationship_type,resource,goal,created_at,contribution_weight"]
        )
        return response.data
    }

    /// Update a goal relationship
    public func updateGoalRelationship(gid: String, contributionWeight: Double) async throws -> AsanaGoalRelationship {
        let response: AsanaDataResponse<AsanaGoalRelationship> = try await request(
            endpoint: "/goal_relationships/\(gid)",
            method: "PUT",
            body: ["data": ["contribution_weight": contributionWeight]]
        )
        return response.data
    }

    // MARK: - Sections

    /// Get sections in a project
    public func getSections(projectGid: String) async throws -> [AsanaSection] {
        let response: AsanaDataResponse<[AsanaSection]> = try await request(
            endpoint: "/projects/\(projectGid)/sections"
        )
        return response.data
    }

    /// Create a section
    public func createSection(projectGid: String, name: String) async throws -> AsanaSection {
        let response: AsanaDataResponse<AsanaSection> = try await request(
            endpoint: "/projects/\(projectGid)/sections",
            method: "POST",
            body: ["data": ["name": name]]
        )
        return response.data
    }

    // MARK: - Batch API

    /// Execute batch requests (max 10 actions)
    public func batch(actions: [AsanaBatchAction]) async throws -> [AsanaBatchResult] {
        guard actions.count <= 10 else {
            throw AsanaError.batchLimitExceeded
        }
        guard !actions.isEmpty else {
            throw AsanaError.emptyBatchRequest
        }

        let response: AsanaDataResponse<[AsanaBatchResult]> = try await request(
            endpoint: "/batch",
            method: "POST",
            body: ["data": ["actions": actions.map { $0.toDictionary() }]]
        )
        return response.data
    }

    // MARK: - Webhooks

    /// Create a webhook
    public func createWebhook(resourceGid: String, targetUrl: String, filters: [AsanaWebhookFilter]? = nil) async throws -> AsanaWebhook {
        var data: [String: Any] = [
            "resource": resourceGid,
            "target": targetUrl
        ]
        if let filters {
            data["filters"] = filters.map { $0.toDictionary() }
        }

        let response: AsanaDataResponse<AsanaWebhook> = try await request(
            endpoint: "/webhooks",
            method: "POST",
            body: ["data": data]
        )
        return response.data
    }

    /// Get webhooks
    public func getWebhooks(workspaceGid: String? = nil, resourceGid: String? = nil) async throws -> [AsanaWebhook] {
        let workspace = workspaceGid ?? self.workspaceGid
        guard let workspace else {
            throw AsanaError.workspaceRequired
        }

        var params: [String: String] = ["workspace": workspace]
        if let resourceGid { params["resource"] = resourceGid }

        let response: AsanaDataResponse<[AsanaWebhook]> = try await request(
            endpoint: "/webhooks",
            queryParams: params
        )
        return response.data
    }

    /// Delete a webhook
    public func deleteWebhook(webhookGid: String) async throws {
        let _: AsanaEmptyResponse = try await request(
            endpoint: "/webhooks/\(webhookGid)",
            method: "DELETE"
        )
    }

    /// Verify webhook signature using HMAC-SHA256
    public static func verifyWebhookSignature(payload: Data, signature: String, secret: String) -> Bool {
        let key = SymmetricKey(data: Data(secret.utf8))
        let hmac = HMAC<SHA256>.authenticationCode(for: payload, using: key)
        let computedSignature = Data(hmac).map { String(format: "%02x", $0) }.joined()
        return computedSignature == signature
    }

    // MARK: - Users & Teams

    /// Get current user
    public func getMe() async throws -> AsanaUser {
        let response: AsanaDataResponse<AsanaUser> = try await request(
            endpoint: "/users/me",
            queryParams: ["opt_fields": "name,email,workspaces"]
        )
        return response.data
    }

    /// Get a user
    public func getUser(gid: String) async throws -> AsanaUser {
        let response: AsanaDataResponse<AsanaUser> = try await request(
            endpoint: "/users/\(gid)",
            queryParams: ["opt_fields": "name,email,workspaces,photo"]
        )
        return response.data
    }

    /// Get users in workspace
    public func getUsers(workspaceGid: String? = nil) async throws -> [AsanaUser] {
        let workspace = workspaceGid ?? self.workspaceGid
        guard let workspace else {
            throw AsanaError.workspaceRequired
        }

        let response: AsanaDataResponse<[AsanaUser]> = try await request(
            endpoint: "/workspaces/\(workspace)/users",
            queryParams: ["opt_fields": "name,email"]
        )
        return response.data
    }

    /// Get teams
    public func getTeams(workspaceGid: String? = nil) async throws -> [AsanaTeam] {
        let workspace = workspaceGid ?? self.workspaceGid

        var endpoint = "/teams"
        if let workspace {
            endpoint = "/workspaces/\(workspace)/teams"
        }

        let response: AsanaDataResponse<[AsanaTeam]> = try await request(endpoint: endpoint)
        return response.data
    }

    /// Get users in team
    public func getTeamUsers(teamGid: String) async throws -> [AsanaUser] {
        let response: AsanaDataResponse<[AsanaUser]> = try await request(
            endpoint: "/teams/\(teamGid)/users",
            queryParams: ["opt_fields": "name,email"]
        )
        return response.data
    }

    /// Get user favorites
    public func getUserFavorites(userGid: String, workspaceGid: String? = nil, resourceType: String? = nil) async throws -> [AsanaFavorite] {
        let workspace = workspaceGid ?? self.workspaceGid
        guard let workspace else {
            throw AsanaError.workspaceRequired
        }

        var params: [String: String] = ["workspace": workspace]
        if let resourceType { params["resource_type"] = resourceType }

        let response: AsanaDataResponse<[AsanaFavorite]> = try await request(
            endpoint: "/users/\(userGid)/favorites",
            queryParams: params
        )
        return response.data
    }

    // MARK: - Typeahead

    /// Typeahead search for resources
    public func typeahead(
        workspaceGid: String? = nil,
        resourceType: AsanaTypeaheadType,
        query: String,
        count: Int = 10
    ) async throws -> [AsanaTypeaheadResult] {
        let workspace = workspaceGid ?? self.workspaceGid
        guard let workspace else {
            throw AsanaError.workspaceRequired
        }

        let response: AsanaDataResponse<[AsanaTypeaheadResult]> = try await request(
            endpoint: "/workspaces/\(workspace)/typeahead",
            queryParams: [
                "resource_type": resourceType.rawValue,
                "query": query,
                "count": String(count)
            ]
        )
        return response.data
    }

    // MARK: - Time Periods

    /// Get time periods
    public func getTimePeriods(workspaceGid: String? = nil) async throws -> [AsanaTimePeriod] {
        let workspace = workspaceGid ?? self.workspaceGid
        guard let workspace else {
            throw AsanaError.workspaceRequired
        }

        let response: AsanaDataResponse<[AsanaTimePeriod]> = try await request(
            endpoint: "/time_periods",
            queryParams: [
                "workspace": workspace,
                "opt_fields": "display_name,period,start_on,end_on"
            ]
        )
        return response.data
    }

    /// Get a specific time period
    public func getTimePeriod(gid: String) async throws -> AsanaTimePeriod {
        let response: AsanaDataResponse<AsanaTimePeriod> = try await request(
            endpoint: "/time_periods/\(gid)",
            queryParams: ["opt_fields": "display_name,period,start_on,end_on,parent"]
        )
        return response.data
    }

    // MARK: - Memberships (General)

    /// Get memberships
    public func getMemberships(parent: String, member: String? = nil) async throws -> [AsanaMembership] {
        var params: [String: String] = ["parent": parent]
        if let member { params["member"] = member }

        let response: AsanaDataResponse<[AsanaMembership]> = try await request(
            endpoint: "/memberships",
            queryParams: params
        )
        return response.data
    }

    /// Create a membership
    public func createMembership(parent: String, member: String) async throws -> AsanaMembership {
        let response: AsanaDataResponse<AsanaMembership> = try await request(
            endpoint: "/memberships",
            method: "POST",
            body: ["data": ["parent": parent, "member": member]]
        )
        return response.data
    }

    /// Delete a membership
    public func deleteMembership(gid: String) async throws {
        let _: AsanaEmptyResponse = try await request(
            endpoint: "/memberships/\(gid)",
            method: "DELETE"
        )
    }

    // MARK: - Status Updates

    /// Get status updates for an object
    public func getStatusUpdates(parentGid: String) async throws -> [AsanaStatusUpdate] {
        let response: AsanaDataResponse<[AsanaStatusUpdate]> = try await request(
            endpoint: "/status_updates",
            queryParams: [
                "parent": parentGid,
                "opt_fields": "title,text,status_type,html_text,author,created_at"
            ]
        )
        return response.data
    }

    /// Create a status update
    public func createStatusUpdate(
        parentGid: String,
        text: String,
        statusType: String
    ) async throws -> AsanaStatusUpdate {
        let response: AsanaDataResponse<AsanaStatusUpdate> = try await request(
            endpoint: "/status_updates",
            method: "POST",
            body: ["data": [
                "parent": parentGid,
                "text": text,
                "status_type": statusType
            ]]
        )
        return response.data
    }

    // MARK: - Private Helpers

    private func request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        queryParams: [String: String] = [:],
        body: [String: Any]? = nil
    ) async throws -> T {
        guard let token = accessToken else {
            throw AsanaError.notAuthenticated
        }

        var urlString = baseURL + endpoint
        if !queryParams.isEmpty {
            let queryString = queryParams.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }.joined(separator: "&")
            urlString += "?\(queryString)"
        }

        guard let url = URL(string: urlString) else {
            throw AsanaError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AsanaError.invalidResponse
        }

        if httpResponse.statusCode == 429 {
            throw AsanaError.rateLimited
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw AsanaError.apiError(statusCode: httpResponse.statusCode, message: String(data: data, encoding: .utf8))
        }

        if data.isEmpty || T.self == AsanaEmptyResponse.self {
            return AsanaEmptyResponse() as! T
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}

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

public struct AsanaBatchAction: Sendable {
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

// MARK: - MCP Server Integration

/// Asana MCP Server client for AI assistant integration
public actor AsanaMCPClient {
    private let mcpURL = "https://mcp.asana.com/v2/mcp"
    private var accessToken: String?

    public init() {}

    public func configure(accessToken: String) {
        self.accessToken = accessToken
    }

    /// List available tools from MCP server
    public func listTools() async throws -> [AsanaMCPTool] {
        try await mcpRequest(method: "tools/list")
    }

    /// Call an MCP tool
    public func callTool(name: String, arguments: [String: Any]) async throws -> AsanaMCPToolResult {
        try await mcpRequest(method: "tools/call", params: [
            "name": name,
            "arguments": arguments
        ])
    }

    /// Natural language query via MCP
    public func query(_ prompt: String) async throws -> String {
        let result: AsanaMCPQueryResult = try await mcpRequest(
            method: "query",
            params: ["prompt": prompt]
        )
        return result.response
    }

    private func mcpRequest<T: Decodable>(method: String, params: [String: Any]? = nil) async throws -> T {
        guard let token = accessToken else {
            throw AsanaError.notAuthenticated
        }

        guard let url = URL(string: mcpURL) else {
            throw AsanaError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "jsonrpc": "2.0",
            "id": UUID().uuidString,
            "method": method
        ]
        if let params {
            body["params"] = params
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AsanaError.mcpError
        }

        let mcpResponse = try JSONDecoder().decode(AsanaMCPResponse<T>.self, from: data)

        if let error = mcpResponse.error {
            throw AsanaError.mcpRequestFailed(code: error.code, message: error.message)
        }

        guard let result = mcpResponse.result else {
            throw AsanaError.mcpNoResult
        }

        return result
    }
}

public struct AsanaMCPResponse<T: Decodable>: Decodable {
    public let jsonrpc: String
    public let id: String
    public let result: T?
    public let error: AsanaMCPError?
}

public struct AsanaMCPError: Decodable, Sendable {
    public let code: Int
    public let message: String
}

public struct AsanaMCPTool: Codable, Sendable {
    public let name: String
    public let description: String
    public let inputSchema: AsanaAnyCodable?
}

public struct AsanaMCPToolResult: Codable, Sendable {
    public let content: [AsanaMCPContent]
}

public struct AsanaMCPContent: Codable, Sendable {
    public let type: String
    public let text: String?
}

public struct AsanaMCPQueryResult: Codable, Sendable {
    public let response: String
}

// MARK: - Helper Types

public struct AsanaAnyCodable: Codable, Sendable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = NSNull()
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let array = try? container.decode([AsanaAnyCodable].self) {
            value = array.map { $0.value }
        } else if let keyedContainer = try? decoder.container(keyedBy: DynamicCodingKey.self) {
            var dict: [String: Any] = [:]
            for key in keyedContainer.allKeys {
                let nested = try keyedContainer.decode(AsanaAnyCodable.self, forKey: key)
                dict[key.stringValue] = nested.value
            }
            value = dict
        } else {
            value = NSNull()
        }
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

private struct AsanaEmptyResponse: Codable {}

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

// MARK: - Thea Integration

/// Asana integration coordinator for Thea
public actor AsanaIntegration {
    private let client = AsanaClient()
    private let mcpClient = AsanaMCPClient()
    private var isConfigured = false

    public init() {}

    public func configure(accessToken: String, workspaceGid: String? = nil) async {
        await client.configure(accessToken: accessToken, workspaceGid: workspaceGid)
        await mcpClient.configure(accessToken: accessToken)
        isConfigured = true
    }

    /// Natural language task query via MCP
    public func queryNaturalLanguage(_ prompt: String) async throws -> String {
        try await mcpClient.query(prompt)
    }

    /// Get tasks due today
    public func getTodaysTasks(projectGid: String) async throws -> [AsanaTask] {
        let allTasks = try await client.getTasks(projectGid: projectGid)
        let today = ISO8601DateFormatter().string(from: Date()).prefix(10)
        return allTasks.filter { $0.dueOn == String(today) && !$0.completed }
    }

    /// Get overdue tasks
    public func getOverdueTasks(projectGid: String) async throws -> [AsanaTask] {
        let allTasks = try await client.getTasks(projectGid: projectGid)
        let today = ISO8601DateFormatter().string(from: Date()).prefix(10)
        return allTasks.filter { task in
            guard let dueOn = task.dueOn, !task.completed else { return false }
            return dueOn < String(today)
        }
    }

    /// Search across workspace
    public func search(_ query: String) async throws -> [AsanaTask] {
        try await client.searchTasks(query: query)
    }

    /// Batch create multiple tasks
    public func batchCreateTasks(_ tasks: [AsanaTaskCreate]) async throws -> [AsanaBatchResult] {
        let actions = tasks.map { task in
            AsanaBatchAction(
                relativePath: "/tasks",
                method: "POST",
                data: ["data": task.toDictionary()]
            )
        }

        // Split into chunks of 10 (API limit)
        var results: [AsanaBatchResult] = []
        for chunk in actions.chunked(into: 10) {
            let chunkResults = try await client.batch(actions: chunk)
            results.append(contentsOf: chunkResults)
        }
        return results
    }

    /// Setup webhook for project updates
    public func setupProjectWebhook(projectGid: String, targetUrl: String) async throws -> AsanaWebhook {
        let filters = [
            AsanaWebhookFilter(resourceType: "task", action: "added"),
            AsanaWebhookFilter(resourceType: "task", action: "changed"),
            AsanaWebhookFilter(resourceType: "task", action: "deleted")
        ]
        return try await client.createWebhook(resourceGid: projectGid, targetUrl: targetUrl, filters: filters)
    }
}

// MARK: - Array Extension

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
