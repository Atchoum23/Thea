//
//  AsanaIntegration+Tasks.swift
//  Thea
//
//  Task-related Asana API endpoints (CRUD, subtasks, dependencies, search)
//

import Foundation

extension AsanaClient {

    // MARK: - Tasks

    /// Retrieves all tasks from a specific Asana project.
    /// - Parameters:
    ///   - projectGid: The globally unique identifier of the project.
    ///   - completedSince: Optional date filter; only returns tasks completed after this date.
    /// - Returns: An array of ``AsanaTask`` objects belonging to the project.
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

    /// Creates a new task in Asana.
    /// - Parameter task: The task creation payload.
    /// - Returns: The newly created ``AsanaTask``.
    public func createTask(_ task: AsanaTaskCreate) async throws -> AsanaTask {
        let response: AsanaDataResponse<AsanaTask> = try await request(
            endpoint: "/tasks",
            method: "POST",
            body: ["data": task.toDictionary()]
        )
        return response.data
    }

    /// Updates an existing task with the provided field values.
    /// - Parameters:
    ///   - gid: The globally unique identifier of the task to update.
    ///   - updates: A dictionary of field names to new values.
    /// - Returns: The updated ``AsanaTask``.
    public func updateTask(gid: String, updates: [String: Any]) async throws -> AsanaTask {
        let response: AsanaDataResponse<AsanaTask> = try await request(
            endpoint: "/tasks/\(gid)",
            method: "PUT",
            body: ["data": updates]
        )
        return response.data
    }

    /// Marks a task as completed.
    /// - Parameter gid: The globally unique identifier of the task to complete.
    /// - Returns: The updated ``AsanaTask`` with `completed` set to `true`.
    public func completeTask(gid: String) async throws -> AsanaTask {
        try await updateTask(gid: gid, updates: ["completed": true])
    }

    /// Permanently deletes a task from Asana.
    /// - Parameter gid: The globally unique identifier of the task to delete.
    public func deleteTask(gid: String) async throws {
        let _: AsanaEmptyResponse = try await request(
            endpoint: "/tasks/\(gid)",
            method: "DELETE"
        )
    }

    /// Adds a subtask under an existing parent task.
    /// - Parameters:
    ///   - parentGid: The globally unique identifier of the parent task.
    ///   - name: The name of the new subtask.
    ///   - notes: Optional description for the subtask.
    /// - Returns: The newly created subtask as an ``AsanaTask``.
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

    /// Retrieves the tasks that the specified task depends on.
    /// - Parameter taskGid: The globally unique identifier of the task.
    /// - Returns: An array of ``AsanaTask`` objects that are dependencies.
    public func getDependencies(taskGid: String) async throws -> [AsanaTask] {
        let response: AsanaDataResponse<[AsanaTask]> = try await request(
            endpoint: "/tasks/\(taskGid)/dependencies"
        )
        return response.data
    }

    /// Sets dependencies for a task, replacing any existing ones.
    /// - Parameters:
    ///   - taskGid: The globally unique identifier of the task.
    ///   - dependencyGids: An array of task GIDs that this task should depend on.
    public func setDependencies(taskGid: String, dependencyGids: [String]) async throws {
        let _: AsanaEmptyResponse = try await request(
            endpoint: "/tasks/\(taskGid)/addDependencies",
            method: "POST",
            body: ["data": ["dependencies": dependencyGids]]
        )
    }

    /// Searches for tasks matching a text query within a workspace.
    /// - Parameters:
    ///   - query: The search text to match against task names and descriptions.
    ///   - workspaceGid: Optional workspace GID; defaults to the configured workspace.
    /// - Returns: An array of matching ``AsanaTask`` objects.
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
}
