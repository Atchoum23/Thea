//
//  AsanaIntegration+Projects.swift
//  Thea
//
//  Project and section management Asana API endpoints
//

import Foundation

extension AsanaClient {

    // MARK: - Projects

    /// Retrieves all projects, optionally filtered by workspace or team.
    /// - Parameters:
    ///   - workspaceGid: Optional workspace GID filter; defaults to the configured workspace.
    ///   - teamGid: Optional team GID filter; takes precedence over workspace if provided.
    /// - Returns: An array of ``AsanaProject`` objects.
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

    /// Creates a new project in the specified workspace.
    /// - Parameters:
    ///   - name: The name for the new project.
    ///   - workspaceGid: Optional workspace GID; defaults to the configured workspace.
    ///   - teamGid: Optional team to associate the project with.
    ///   - notes: Optional description for the project.
    /// - Returns: The newly created ``AsanaProject``.
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

    /// Retrieves the task count breakdown for a project.
    /// - Parameter projectGid: The globally unique identifier of the project.
    /// - Returns: An ``AsanaTaskCount`` containing completed, incomplete, and total counts.
    public func getProjectTaskCount(projectGid: String) async throws -> AsanaTaskCount {
        let response: AsanaDataResponse<AsanaTaskCount> = try await request(
            endpoint: "/projects/\(projectGid)/task_counts"
        )
        return response.data
    }

    // MARK: - Sections

    /// Retrieves all sections within a project.
    /// - Parameter projectGid: The globally unique identifier of the project.
    /// - Returns: An array of ``AsanaSection`` objects.
    public func getSections(projectGid: String) async throws -> [AsanaSection] {
        let response: AsanaDataResponse<[AsanaSection]> = try await request(
            endpoint: "/projects/\(projectGid)/sections"
        )
        return response.data
    }

    /// Creates a new section in a project.
    /// - Parameters:
    ///   - projectGid: The globally unique identifier of the project.
    ///   - name: The name for the new section.
    /// - Returns: The newly created ``AsanaSection``.
    public func createSection(projectGid: String, name: String) async throws -> AsanaSection {
        let response: AsanaDataResponse<AsanaSection> = try await request(
            endpoint: "/projects/\(projectGid)/sections",
            method: "POST",
            body: ["data": ["name": name]]
        )
        return response.data
    }
}
