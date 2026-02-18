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
            guard let empty = AsanaEmptyResponse() as? T else {
                throw AsanaError.apiError(statusCode: httpResponse.statusCode, message: "Unexpected response type")
            }
            return empty
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}
