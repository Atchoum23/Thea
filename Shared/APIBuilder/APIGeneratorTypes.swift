//
//  APIGeneratorTypes.swift
//  Thea
//
//  Supporting types for APIGenerator
//

import Foundation

// MARK: - API Spec

public struct APISpec: Codable, Sendable {
    public let name: String
    public let version: String
    public let baseURL: String
    public var endpoints: [APIEndpointSpec]
    public var models: [APIModelSpec]

    public init(
        name: String,
        version: String = "1.0.0",
        baseURL: String = "https://api.example.com",
        endpoints: [APIEndpointSpec] = [],
        models: [APIModelSpec] = []
    ) {
        self.name = name
        self.version = version
        self.baseURL = baseURL
        self.endpoints = endpoints
        self.models = models
    }
}

// MARK: - API Endpoint Spec

public struct APIEndpointSpec: Codable, Sendable, Identifiable {
    public var id: String { operationId }
    public let path: String
    public let method: String
    public let operationId: String
    public let description: String
    public var pathParameters: [APIParameterSpec]
    public var queryParameters: [APIParameterSpec]
    public var requestBody: APIBodySpec?
    public var responseType: String?

    public init(
        path: String,
        method: String,
        operationId: String,
        description: String,
        pathParameters: [APIParameterSpec] = [],
        queryParameters: [APIParameterSpec] = [],
        requestBody: APIBodySpec? = nil,
        responseType: String? = nil
    ) {
        self.path = path
        self.method = method
        self.operationId = operationId
        self.description = description
        self.pathParameters = pathParameters
        self.queryParameters = queryParameters
        self.requestBody = requestBody
        self.responseType = responseType
    }
}

// MARK: - API Parameter Spec

public struct APIParameterSpec: Codable, Sendable {
    public let name: String
    public let type: APIPropertyType
    public let description: String
    public let isRequired: Bool

    public var swiftType: String {
        type.swiftType
    }

    public init(name: String, type: APIPropertyType, description: String, isRequired: Bool = true) {
        self.name = name
        self.type = type
        self.description = description
        self.isRequired = isRequired
    }
}

// MARK: - API Body Spec

public struct APIBodySpec: Codable, Sendable {
    public let swiftType: String

    public init(swiftType: String) {
        self.swiftType = swiftType
    }
}

// MARK: - API Model Spec

public struct APIModelSpec: Codable, Sendable, Identifiable {
    public var id: String { name }
    public let name: String
    public var properties: [APIPropertySpec]

    public init(name: String, properties: [APIPropertySpec] = []) {
        self.name = name
        self.properties = properties
    }
}

// MARK: - API Property Spec

public struct APIPropertySpec: Codable, Sendable {
    public let name: String
    public let jsonKey: String
    public let type: APIPropertyType
    public let description: String
    public let isRequired: Bool

    public var swiftType: String {
        type.swiftType
    }

    public init(name: String, jsonKey: String? = nil, type: APIPropertyType, description: String = "", isRequired: Bool = true) {
        self.name = name
        self.jsonKey = jsonKey ?? name
        self.type = type
        self.description = description
        self.isRequired = isRequired
    }
}

// MARK: - API Property Type

public enum APIPropertyType: String, Codable, Sendable {
    case string
    case integer
    case number
    case boolean
    case array
    case object

    public var swiftType: String {
        switch self {
        case .string: "String"
        case .integer: "Int"
        case .number: "Double"
        case .boolean: "Bool"
        case .array: "[Any]"
        case .object: "[String: Any]"
        }
    }
}

// MARK: - Generated API

public struct GeneratedAPI: Sendable, Identifiable {
    public let id: String
    public let name: String
    public let spec: APISpec
    public let generatedCode: String
    public let generatedAt: Date
}

// MARK: - API Template

public struct APITemplate: Sendable {
    public let name: String
    public let description: String
    public let defaultEndpoints: [APIEndpointSpec]
    public var defaultModels: [APIModelSpec] = []

    public func createSpec(with config: APITemplateConfig) -> APISpec {
        APISpec(
            name: config.apiName,
            version: config.version,
            baseURL: config.baseURL,
            endpoints: config.includeDefaultEndpoints ? defaultEndpoints : [],
            models: config.includeDefaultModels ? defaultModels : []
        )
    }
}

// MARK: - API Template Config

public struct APITemplateConfig: Sendable {
    public let apiName: String
    public var version: String = "1.0.0"
    public var baseURL: String = "https://api.example.com"
    public var includeDefaultEndpoints: Bool = true
    public var includeDefaultModels: Bool = true

    public init(apiName: String) {
        self.apiName = apiName
    }
}

// MARK: - HTTP Method

public enum HTTPMethod: String, Codable, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
    case head = "HEAD"
    case options = "OPTIONS"
}

// MARK: - Generated API Error

public enum GeneratedAPIError: Error, LocalizedError, Sendable {
    case invalidURL(String)
    case invalidResponse
    case httpError(statusCode: Int, data: Data)
    case decodingError(Error)
    case encodingError(Error)
    case networkError(Error)

    public var errorDescription: String? {
        switch self {
        case let .invalidURL(path):
            "Invalid URL: \(path)"
        case .invalidResponse:
            "Invalid response from server"
        case let .httpError(statusCode, _):
            "HTTP error: \(statusCode)"
        case let .decodingError(error):
            "Decoding error: \(error.localizedDescription)"
        case let .encodingError(error):
            "Encoding error: \(error.localizedDescription)"
        case let .networkError(error):
            "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - API Generator Error

public enum APIGeneratorError: Error, LocalizedError, Sendable {
    case templateNotFound(String)
    case apiNotFound(String)
    case invalidOpenAPISpec(String)
    case generationFailed(String)

    public var errorDescription: String? {
        switch self {
        case let .templateNotFound(name):
            "Template not found: \(name)"
        case let .apiNotFound(id):
            "Generated API not found: \(id)"
        case let .invalidOpenAPISpec(reason):
            "Invalid OpenAPI specification: \(reason)"
        case let .generationFailed(reason):
            "Code generation failed: \(reason)"
        }
    }
}
