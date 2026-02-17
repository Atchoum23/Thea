//
//  AsanaIntegration+Coordinator.swift
//  Thea
//
//  Thea-specific Asana integration coordinator with convenience methods
//  for common workflows: today's tasks, overdue detection, batch creation, and webhooks
//

import Foundation

/// High-level Asana integration coordinator for Thea.
///
/// Wraps ``AsanaClient`` and ``AsanaMCPClient`` to provide convenience methods
/// for common task management workflows such as querying today's tasks,
/// detecting overdue items, batch-creating tasks, and setting up project webhooks.
public actor AsanaIntegration {
    private let client = AsanaClient()
    private let mcpClient = AsanaMCPClient()
    private var isConfigured = false

    public init() {}

    /// Configures the integration with API credentials.
    /// - Parameters:
    ///   - accessToken: A valid Asana Personal Access Token or OAuth token.
    ///   - workspaceGid: Optional default workspace GID for API calls that require one.
    public func configure(accessToken: String, workspaceGid: String? = nil) async {
        await client.configure(accessToken: accessToken, workspaceGid: workspaceGid)
        await mcpClient.configure(accessToken: accessToken)
        isConfigured = true
    }

    /// Queries Asana using natural language via the MCP server.
    /// - Parameter prompt: A natural language description of the desired query.
    /// - Returns: The MCP server's response as a string.
    public func queryNaturalLanguage(_ prompt: String) async throws -> String {
        try await mcpClient.query(prompt)
    }

    /// Retrieves all incomplete tasks due today from a project.
    /// - Parameter projectGid: The globally unique identifier of the project.
    /// - Returns: An array of ``AsanaTask`` objects that are due today and not yet completed.
    public func getTodaysTasks(projectGid: String) async throws -> [AsanaTask] {
        let allTasks = try await client.getTasks(projectGid: projectGid)
        let today = ISO8601DateFormatter().string(from: Date()).prefix(10)
        return allTasks.filter { $0.dueOn == String(today) && !$0.completed }
    }

    /// Retrieves all incomplete tasks that are past their due date from a project.
    /// - Parameter projectGid: The globally unique identifier of the project.
    /// - Returns: An array of ``AsanaTask`` objects that are overdue and not yet completed.
    public func getOverdueTasks(projectGid: String) async throws -> [AsanaTask] {
        let allTasks = try await client.getTasks(projectGid: projectGid)
        let today = ISO8601DateFormatter().string(from: Date()).prefix(10)
        return allTasks.filter { task in
            guard let dueOn = task.dueOn, !task.completed else { return false }
            return dueOn < String(today)
        }
    }

    /// Searches for tasks matching a query across the configured workspace.
    /// - Parameter query: The search text.
    /// - Returns: An array of matching ``AsanaTask`` objects.
    public func search(_ query: String) async throws -> [AsanaTask] {
        try await client.searchTasks(query: query)
    }

    /// Creates multiple tasks in batch, respecting the Asana API limit of 10 actions per batch.
    ///
    /// If more than 10 tasks are provided, they are automatically chunked into
    /// multiple batch requests executed sequentially.
    /// - Parameter tasks: An array of ``AsanaTaskCreate`` payloads.
    /// - Returns: An array of ``AsanaBatchResult`` objects, one per created task.
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

    /// Sets up a webhook to receive notifications for task changes in a project.
    ///
    /// Registers filters for task `added`, `changed`, and `deleted` events.
    /// - Parameters:
    ///   - projectGid: The GID of the project to monitor.
    ///   - targetUrl: The HTTPS URL to receive webhook POST requests.
    /// - Returns: The created ``AsanaWebhook``.
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
    /// Splits the array into sub-arrays of the specified size.
    /// - Parameter size: The maximum number of elements per chunk.
    /// - Returns: An array of arrays, each containing at most `size` elements.
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
