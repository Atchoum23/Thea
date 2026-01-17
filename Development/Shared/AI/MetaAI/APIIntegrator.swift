import Foundation

// MARK: - API Integration Framework
// Dynamic API discovery, client generation, and execution

@MainActor
@Observable
final class APIIntegrator {
    static let shared = APIIntegrator()

    private(set) var registeredAPIs: [APIEndpoint] = []
    private(set) var apiCallHistory: [APICall] = []

    private init() {
        registerBuiltInAPIs()
    }

    // MARK: - API Registration

    private func registerBuiltInAPIs() {
        let externalConfig = AppConfiguration.shared.externalAPIsConfig
        
        // GitHub API
        registerAPI(APIEndpoint(
            id: UUID(),
            name: "GitHub - Get Repository",
            baseURL: externalConfig.githubAPIBaseURL,
            path: "/repos/{owner}/{repo}",
            method: .get,
            authType: .bearer,
            parameters: [
                APIParameter(name: "owner", location: .path, required: true),
                APIParameter(name: "repo", location: .path, required: true)
            ]
        ))

        // Weather API
        registerAPI(APIEndpoint(
            id: UUID(),
            name: "Weather - Current",
            baseURL: externalConfig.openWeatherMapBaseURL,
            path: "/data/2.5/weather",
            method: .get,
            authType: .apiKey,
            parameters: [
                APIParameter(name: "q", location: .query, required: true),
                APIParameter(name: "appid", location: .query, required: true)
            ]
        ))
    }

    func registerAPI(_ endpoint: APIEndpoint) {
        registeredAPIs.append(endpoint)
    }

    // MARK: - API Discovery

    func discoverAPI(from openAPISpec: String) async throws -> [APIEndpoint] {
        // Parse OpenAPI/Swagger spec and generate endpoints
        // Simplified - would use proper OpenAPI parser in production
        return []
    }

    // MARK: - API Execution

    nonisolated func callAPI(
        _ endpoint: APIEndpoint,
        parameters: [String: String],
        authToken: String? = nil
    ) async throws -> APIResponse {
        let startTime = Date()

        // Build URL
        var urlString = endpoint.baseURL + endpoint.path
        var queryItems: [URLQueryItem] = []

        // Replace path parameters
        for param in endpoint.parameters where param.location == .path {
            if let value = parameters[param.name] {
                urlString = urlString.replacingOccurrences(of: "{\(param.name)}", with: value)
            }
        }

        // Add query parameters
        for param in endpoint.parameters where param.location == .query {
            if let value = parameters[param.name] {
                queryItems.append(URLQueryItem(name: param.name, value: value))
            }
        }

        guard var urlComponents = URLComponents(string: urlString) else {
            throw APIError.invalidURL
        }

        if !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }

        guard let url = urlComponents.url else {
            throw APIError.invalidURL
        }

        // Build request
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue

        // Add authentication
        if let token = authToken {
            switch endpoint.authType {
            case .bearer:
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            case .apiKey:
                break // API key usually in query params
            case .basic:
                request.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")
            case .none:
                break
            }
        }

        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Execute request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        let responseBody = String(data: data, encoding: .utf8) ?? ""

        return APIResponse(
            statusCode: httpResponse.statusCode,
            body: responseBody,
            headers: httpResponse.allHeaderFields as? [String: String] ?? [:],
            executionTime: Date().timeIntervalSince(startTime)
        )
    }

    // MARK: - Rate Limiting

    private var rateLimiters: [String: RateLimiter] = [:]

    nonisolated func checkRateLimit(for endpoint: APIEndpoint) async -> Bool {
        // Simplified rate limiting
        return true
    }
}

// MARK: - Models

struct APIEndpoint: Identifiable, Codable, Sendable {
    let id: UUID
    let name: String
    let baseURL: String
    let path: String
    let method: HTTPMethod
    let authType: AuthType
    let parameters: [APIParameter]

    enum HTTPMethod: String, Codable, Sendable {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
        case patch = "PATCH"
    }

    enum AuthType: String, Codable, Sendable {
        case bearer, apiKey, basic, none
    }
}

struct APIParameter: Codable, Sendable {
    let name: String
    let location: ParameterLocation
    let required: Bool

    enum ParameterLocation: String, Codable, Sendable {
        case path, query, header, body
    }
}

struct APICall: Identifiable {
    let id: UUID
    let endpoint: APIEndpoint
    let parameters: [String: String]
    let timestamp: Date
    var response: APIResponse?
}

struct APIResponse: Sendable {
    let statusCode: Int
    let body: String
    let headers: [String: String]
    let executionTime: TimeInterval
}

struct RateLimiter {
    var requestsPerMinute: Int
    var currentCount: Int
    var resetTime: Date
}

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case rateLimitExceeded
    case authenticationRequired

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid API response"
        case .rateLimitExceeded:
            return "Rate limit exceeded"
        case .authenticationRequired:
            return "Authentication required"
        }
    }
}
