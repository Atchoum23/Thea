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
