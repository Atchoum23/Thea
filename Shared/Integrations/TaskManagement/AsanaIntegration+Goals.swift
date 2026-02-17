//
//  AsanaIntegration+Goals.swift
//  Thea
//
//  Goal CRUD, goal metrics, and goal relationship management
//

import Foundation

extension AsanaClient {

    // MARK: - Goals

    /// Retrieves goals with optional filters for workspace, team, project, portfolio, or time period.
    /// - Parameters:
    ///   - workspaceGid: Optional workspace GID; defaults to the configured workspace.
    ///   - teamGid: Optional team GID filter.
    ///   - projectGid: Optional project GID filter.
    ///   - portfolioGid: Optional portfolio GID filter.
    ///   - timePeriods: Optional array of time period GIDs to filter by.
    ///   - isWorkspaceLevel: Optional filter for workspace-level vs team-level goals.
    /// - Returns: An array of ``AsanaGoal`` objects matching the filters.
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

    /// Retrieves a specific goal with full details.
    /// - Parameter gid: The globally unique identifier of the goal.
    /// - Returns: The ``AsanaGoal`` with all opt_fields including likes and followers.
    public func getGoal(gid: String) async throws -> AsanaGoal {
        let response: AsanaDataResponse<AsanaGoal> = try await request(
            endpoint: "/goals/\(gid)",
            queryParams: ["opt_fields": "name,notes,due_on,start_on,status,owner,html_notes,metric,current_status_update,time_period,is_workspace_level,likes,num_likes,followers"]
        )
        return response.data
    }

    /// Creates a new goal in the specified workspace.
    /// - Parameters:
    ///   - name: The name for the new goal.
    ///   - workspaceGid: Optional workspace GID; defaults to the configured workspace.
    ///   - teamGid: Optional team to associate the goal with.
    ///   - timePeriodGid: Optional time period GID for the goal.
    ///   - dueOn: Optional due date in `YYYY-MM-DD` format.
    ///   - startOn: Optional start date in `YYYY-MM-DD` format.
    ///   - notes: Optional description for the goal.
    ///   - isWorkspaceLevel: Whether this is a workspace-level goal; defaults to `false`.
    /// - Returns: The newly created ``AsanaGoal``.
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

    /// Updates an existing goal with the provided field values.
    /// - Parameters:
    ///   - gid: The globally unique identifier of the goal to update.
    ///   - updates: A dictionary of field names to new values.
    /// - Returns: The updated ``AsanaGoal``.
    public func updateGoal(gid: String, updates: [String: Any]) async throws -> AsanaGoal {
        let response: AsanaDataResponse<AsanaGoal> = try await request(
            endpoint: "/goals/\(gid)",
            method: "PUT",
            body: ["data": updates]
        )
        return response.data
    }

    /// Retrieves the parent goals of a given goal.
    /// - Parameter goalGid: The globally unique identifier of the goal.
    /// - Returns: An array of ``AsanaGoal`` objects that are parents of the specified goal.
    public func getParentGoals(goalGid: String) async throws -> [AsanaGoal] {
        let response: AsanaDataResponse<[AsanaGoal]> = try await request(
            endpoint: "/goals/\(goalGid)/parentGoals"
        )
        return response.data
    }

    // MARK: - Goal Metrics

    /// Creates or sets a metric on a goal for tracking numeric progress.
    /// - Parameters:
    ///   - goalGid: The globally unique identifier of the goal.
    ///   - unit: The unit of measurement (e.g., `"number"`, `"percentage"`, `"currency"`).
    ///   - currentValue: The current numeric value of the metric.
    ///   - targetValue: The target numeric value to achieve.
    ///   - currencyCode: Optional ISO 4217 currency code (required when unit is `"currency"`).
    ///   - progressSource: How progress is tracked; defaults to `"manual"`.
    /// - Returns: The created ``AsanaGoalMetric``.
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

    /// Updates the current value of a goal's metric.
    /// - Parameters:
    ///   - goalGid: The globally unique identifier of the goal.
    ///   - currentValue: The new current numeric value.
    /// - Returns: The updated ``AsanaGoalMetric``.
    public func updateGoalMetric(goalGid: String, currentValue: Double) async throws -> AsanaGoalMetric {
        let response: AsanaDataResponse<AsanaGoalMetric> = try await request(
            endpoint: "/goals/\(goalGid)/setMetricCurrentValue",
            method: "POST",
            body: ["data": ["current_number_value": currentValue]]
        )
        return response.data
    }

    // MARK: - Goal Relationships

    /// Retrieves all relationships (supporting resources) for a goal.
    /// - Parameter goalGid: The globally unique identifier of the goal.
    /// - Returns: An array of ``AsanaGoalRelationship`` objects.
    public func getGoalRelationships(goalGid: String) async throws -> [AsanaGoalRelationship] {
        let response: AsanaDataResponse<[AsanaGoalRelationship]> = try await request(
            endpoint: "/goals/\(goalGid)/goalRelationships",
            queryParams: ["opt_fields": "relationship_type,resource,goal,created_at"]
        )
        return response.data
    }

    /// Adds a supporting relationship (sub-goal, project, or portfolio) to a goal.
    /// - Parameters:
    ///   - goalGid: The globally unique identifier of the parent goal.
    ///   - supportingResourceGid: The GID of the resource to add as a supporter.
    ///   - contributionWeight: Optional weight (0.0 to 1.0) for this resource's contribution.
    ///   - insertBefore: Optional GID to position the relationship before.
    ///   - insertAfter: Optional GID to position the relationship after.
    /// - Returns: The created ``AsanaGoalRelationship``.
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

    /// Removes a supporting relationship from a goal.
    /// - Parameters:
    ///   - goalGid: The globally unique identifier of the parent goal.
    ///   - supportingResourceGid: The GID of the supporting resource to remove.
    public func removeSupportingRelationship(goalGid: String, supportingResourceGid: String) async throws {
        let _: AsanaEmptyResponse = try await request(
            endpoint: "/goals/\(goalGid)/removeSupportingRelationship",
            method: "POST",
            body: ["data": ["supporting_resource": supportingResourceGid]]
        )
    }

    /// Retrieves a specific goal relationship by its GID.
    /// - Parameter gid: The globally unique identifier of the goal relationship.
    /// - Returns: The ``AsanaGoalRelationship`` with full details including contribution weight.
    public func getGoalRelationship(gid: String) async throws -> AsanaGoalRelationship {
        let response: AsanaDataResponse<AsanaGoalRelationship> = try await request(
            endpoint: "/goal_relationships/\(gid)",
            queryParams: ["opt_fields": "relationship_type,resource,goal,created_at,contribution_weight"]
        )
        return response.data
    }

    /// Updates the contribution weight of a goal relationship.
    /// - Parameters:
    ///   - gid: The globally unique identifier of the goal relationship.
    ///   - contributionWeight: The new contribution weight (0.0 to 1.0).
    /// - Returns: The updated ``AsanaGoalRelationship``.
    public func updateGoalRelationship(gid: String, contributionWeight: Double) async throws -> AsanaGoalRelationship {
        let response: AsanaDataResponse<AsanaGoalRelationship> = try await request(
            endpoint: "/goal_relationships/\(gid)",
            method: "PUT",
            body: ["data": ["contribution_weight": contributionWeight]]
        )
        return response.data
    }
}
