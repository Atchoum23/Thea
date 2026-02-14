//
//  AsanaMCPClient.swift
//  Thea
//
//  Asana MCP Server client, extracted from AsanaIntegration.swift
//

import Foundation

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
