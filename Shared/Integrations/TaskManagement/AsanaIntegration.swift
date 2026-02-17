//
//  AsanaIntegration.swift
//  Thea
//
//  Core Asana API client actor with authentication, configuration, and HTTP transport.
//  Based on: REST API, Webhooks, App Components, Script Actions, MCP Server
//  Updated Feb 2026 with Goal Relationships, Portfolio Memberships, Typeahead
//
//  Endpoint extensions are organized into separate files:
//  - AsanaIntegration+Tasks.swift       — Task CRUD, subtasks, dependencies, search
//  - AsanaIntegration+Projects.swift    — Project CRUD, sections
//  - AsanaIntegration+Portfolios.swift  — Portfolio CRUD, items, members, custom fields, memberships
//  - AsanaIntegration+Goals.swift       — Goal CRUD, metrics, relationships
//  - AsanaIntegration+Webhooks.swift    — Webhook CRUD, HMAC signature verification
//  - AsanaIntegration+Users.swift       — Users, teams, typeahead, time periods, memberships, status updates
//  - AsanaIntegration+Coordinator.swift — Thea integration coordinator (AsanaIntegration actor)
//

import Foundation

// MARK: - Asana Client

/// Core Asana REST API client providing authenticated HTTP transport.
///
/// `AsanaClient` is an actor that manages authentication state and provides
/// a generic `request()` method used by all endpoint extensions. Configure it
/// with an access token before making any API calls.
///
/// All domain-specific endpoints (tasks, projects, goals, etc.) are defined
/// in `AsanaClient` extensions in their respective `AsanaIntegration+*.swift` files.
public actor AsanaClient {
    private let baseURL = "https://app.asana.com/api/1.0"
    private let mcpURL = "https://mcp.asana.com/v2/mcp"

    var accessToken: String?
    var workspaceGid: String?

    public init() {}

    // MARK: - Configuration

    /// Configures the client with authentication credentials.
    /// - Parameters:
    ///   - accessToken: A valid Asana Personal Access Token or OAuth token.
    ///   - workspaceGid: Optional default workspace GID used by endpoints that require a workspace.
    public func configure(accessToken: String, workspaceGid: String? = nil) {
        self.accessToken = accessToken
        self.workspaceGid = workspaceGid
    }

    // MARK: - Batch API

    /// Executes up to 10 API actions in a single batch request.
    ///
    /// The Asana Batch API allows combining multiple operations into one HTTP call,
    /// reducing latency for bulk operations.
    /// - Parameter actions: An array of ``AsanaBatchAction`` (maximum 10).
    /// - Throws: ``AsanaError/batchLimitExceeded`` if more than 10 actions are provided.
    /// - Throws: ``AsanaError/emptyBatchRequest`` if the actions array is empty.
    /// - Returns: An array of ``AsanaBatchResult`` objects, one per action.
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

    // MARK: - HTTP Transport

    /// Sends an authenticated HTTP request to the Asana REST API and decodes the response.
    ///
    /// This is the shared transport layer used by all endpoint extensions. It handles:
    /// - Bearer token authentication
    /// - Query parameter encoding
    /// - JSON body serialization
    /// - HTTP status code validation (including rate limit detection)
    /// - Response deserialization
    ///
    /// - Parameters:
    ///   - endpoint: The API path relative to `https://app.asana.com/api/1.0` (e.g., `"/tasks"`).
    ///   - method: The HTTP method; defaults to `"GET"`.
    ///   - queryParams: Optional query parameters to append to the URL.
    ///   - body: Optional request body as a dictionary, serialized to JSON.
    /// - Returns: The decoded response of type `T`.
    /// - Throws: ``AsanaError/notAuthenticated`` if no access token is configured.
    /// - Throws: ``AsanaError/rateLimited`` if the API returns HTTP 429.
    /// - Throws: ``AsanaError/apiError(statusCode:message:)`` for other non-2xx responses.
    func request<T: Decodable>(
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
