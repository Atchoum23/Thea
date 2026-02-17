//
//  AsanaIntegration+Users.swift
//  Thea
//
//  User, team, typeahead, time period, membership, and status update endpoints
//

import Foundation

extension AsanaClient {

    // MARK: - Users & Teams

    /// Retrieves the currently authenticated user's profile.
    /// - Returns: The ``AsanaUser`` for the authenticated user, including name, email, and workspaces.
    public func getMe() async throws -> AsanaUser {
        let response: AsanaDataResponse<AsanaUser> = try await request(
            endpoint: "/users/me",
            queryParams: ["opt_fields": "name,email,workspaces"]
        )
        return response.data
    }

    /// Retrieves a specific user by their GID.
    /// - Parameter gid: The globally unique identifier of the user.
    /// - Returns: The ``AsanaUser`` with name, email, workspaces, and photo.
    public func getUser(gid: String) async throws -> AsanaUser {
        let response: AsanaDataResponse<AsanaUser> = try await request(
            endpoint: "/users/\(gid)",
            queryParams: ["opt_fields": "name,email,workspaces,photo"]
        )
        return response.data
    }

    /// Retrieves all users in a workspace.
    /// - Parameter workspaceGid: Optional workspace GID; defaults to the configured workspace.
    /// - Returns: An array of ``AsanaUser`` objects with name and email.
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

    /// Retrieves all teams in a workspace.
    /// - Parameter workspaceGid: Optional workspace GID; defaults to the configured workspace.
    /// - Returns: An array of ``AsanaTeam`` objects.
    public func getTeams(workspaceGid: String? = nil) async throws -> [AsanaTeam] {
        let workspace = workspaceGid ?? self.workspaceGid

        var endpoint = "/teams"
        if let workspace {
            endpoint = "/workspaces/\(workspace)/teams"
        }

        let response: AsanaDataResponse<[AsanaTeam]> = try await request(endpoint: endpoint)
        return response.data
    }

    /// Retrieves all users belonging to a specific team.
    /// - Parameter teamGid: The globally unique identifier of the team.
    /// - Returns: An array of ``AsanaUser`` objects with name and email.
    public func getTeamUsers(teamGid: String) async throws -> [AsanaUser] {
        let response: AsanaDataResponse<[AsanaUser]> = try await request(
            endpoint: "/teams/\(teamGid)/users",
            queryParams: ["opt_fields": "name,email"]
        )
        return response.data
    }

    /// Retrieves a user's favorite (starred) resources in a workspace.
    /// - Parameters:
    ///   - userGid: The globally unique identifier of the user.
    ///   - workspaceGid: Optional workspace GID; defaults to the configured workspace.
    ///   - resourceType: Optional filter by resource type (e.g., `"project"`, `"portfolio"`, `"task"`).
    /// - Returns: An array of ``AsanaFavorite`` objects.
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

    /// Performs a typeahead search for resources in a workspace.
    ///
    /// Typeahead provides fast, prefix-based search results suitable for auto-complete UIs.
    /// - Parameters:
    ///   - workspaceGid: Optional workspace GID; defaults to the configured workspace.
    ///   - resourceType: The type of resource to search for (e.g., `.task`, `.project`, `.user`).
    ///   - query: The search prefix string.
    ///   - count: Maximum number of results to return; defaults to 10.
    /// - Returns: An array of ``AsanaTypeaheadResult`` objects matching the query.
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

    /// Retrieves all time periods in a workspace (e.g., quarters, fiscal years).
    /// - Parameter workspaceGid: Optional workspace GID; defaults to the configured workspace.
    /// - Returns: An array of ``AsanaTimePeriod`` objects with display name, period, and date range.
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

    /// Retrieves a specific time period by its GID.
    /// - Parameter gid: The globally unique identifier of the time period.
    /// - Returns: The ``AsanaTimePeriod`` with display name, period, dates, and parent.
    public func getTimePeriod(gid: String) async throws -> AsanaTimePeriod {
        let response: AsanaDataResponse<AsanaTimePeriod> = try await request(
            endpoint: "/time_periods/\(gid)",
            queryParams: ["opt_fields": "display_name,period,start_on,end_on,parent"]
        )
        return response.data
    }

    // MARK: - Memberships (General)

    /// Retrieves memberships for a parent resource (project, portfolio, goal, etc.).
    /// - Parameters:
    ///   - parent: The GID of the parent resource.
    ///   - member: Optional GID to filter for a specific member's membership.
    /// - Returns: An array of ``AsanaMembership`` objects.
    public func getMemberships(parent: String, member: String? = nil) async throws -> [AsanaMembership] {
        var params: [String: String] = ["parent": parent]
        if let member { params["member"] = member }

        let response: AsanaDataResponse<[AsanaMembership]> = try await request(
            endpoint: "/memberships",
            queryParams: params
        )
        return response.data
    }

    /// Creates a membership linking a member to a parent resource.
    /// - Parameters:
    ///   - parent: The GID of the parent resource (project, portfolio, goal, etc.).
    ///   - member: The GID of the user or team to add as a member.
    /// - Returns: The created ``AsanaMembership``.
    public func createMembership(parent: String, member: String) async throws -> AsanaMembership {
        let response: AsanaDataResponse<AsanaMembership> = try await request(
            endpoint: "/memberships",
            method: "POST",
            body: ["data": ["parent": parent, "member": member]]
        )
        return response.data
    }

    /// Deletes a membership, removing the member from the parent resource.
    /// - Parameter gid: The globally unique identifier of the membership to delete.
    public func deleteMembership(gid: String) async throws {
        let _: AsanaEmptyResponse = try await request(
            endpoint: "/memberships/\(gid)",
            method: "DELETE"
        )
    }

    // MARK: - Status Updates

    /// Retrieves status updates for a parent resource (project, goal, portfolio).
    /// - Parameter parentGid: The GID of the parent resource.
    /// - Returns: An array of ``AsanaStatusUpdate`` objects with title, text, type, and author.
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

    /// Creates a status update on a parent resource.
    /// - Parameters:
    ///   - parentGid: The GID of the parent resource (project, goal, portfolio).
    ///   - text: The plain text content of the status update.
    ///   - statusType: The status type (e.g., `"on_track"`, `"at_risk"`, `"off_track"`, `"on_hold"`).
    /// - Returns: The created ``AsanaStatusUpdate``.
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
}
