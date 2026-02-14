//
//  APIGenerator+CodeGeneration.swift
//  Thea
//
//  Code generation helpers extracted from APIGenerator
//

import Foundation

// MARK: - APIGenerator + Code Generation

extension APIGenerator {
    func generateModel(_ model: APIModelSpec) -> String {
        var code = """

        // MARK: - \(model.name)

        public struct \(model.name): Codable, Sendable {

        """

        for property in model.properties {
            let type = property.isRequired ? property.swiftType : "\(property.swiftType)?"
            code += "    public var \(property.name): \(type)\n"
        }

        // Generate initializer
        code += "\n    public init(\n"
        let initParams = model.properties.map { prop in
            let defaultValue = prop.isRequired ? "" : " = nil"
            return "        \(prop.name): \(prop.isRequired ? prop.swiftType : "\(prop.swiftType)?")\(defaultValue)"
        }.joined(separator: ",\n")
        code += initParams
        code += "\n    ) {\n"

        for property in model.properties {
            code += "        self.\(property.name) = \(property.name)\n"
        }

        code += "    }\n"

        // Generate CodingKeys if needed
        let needsCodingKeys = model.properties.contains { $0.jsonKey != $0.name }
        if needsCodingKeys {
            code += "\n    private enum CodingKeys: String, CodingKey {\n"
            for property in model.properties {
                if property.jsonKey != property.name {
                    code += "        case \(property.name) = \"\(property.jsonKey)\"\n"
                } else {
                    code += "        case \(property.name)\n"
                }
            }
            code += "    }\n"
        }

        code += "}\n"
        return code
    }

    func generateAPIClient(for spec: APISpec) -> String {
        var code = generateAPIClientHeader(for: spec)
        code += generateAPIClientRequestBuilder()
        code += generateAPIClientRequestExecutor()
        return code
    }

    func generateEndpoint(_ endpoint: APIEndpointSpec, apiName _: String) -> String {
        var code = """

            /// \(endpoint.description)
            public func \(endpoint.operationId)(

        """

        // Parameters
        var params: [String] = []

        for param in endpoint.pathParameters {
            params.append("\(param.name): \(param.swiftType)")
        }

        for param in endpoint.queryParameters {
            let type = param.isRequired ? param.swiftType : "\(param.swiftType)?"
            let defaultValue = param.isRequired ? "" : " = nil"
            params.append("\(param.name): \(type)\(defaultValue)")
        }

        if let body = endpoint.requestBody {
            params.append("body: \(body.swiftType)")
        }

        code += params.map { "        \($0)" }.joined(separator: ",\n")
        code += "\n    ) async throws"

        // Return type
        if let response = endpoint.responseType {
            code += " -> \(response)"
        }

        code += " {\n"

        // Build path with parameters
        var path = endpoint.path
        for param in endpoint.pathParameters {
            path = path.replacingOccurrences(of: "{\(param.name)}", with: "\\(\(param.name))")
        }

        code += "        let path = \"\(path)\"\n"

        // Query items
        if !endpoint.queryParameters.isEmpty {
            code += "        var queryItems: [URLQueryItem] = []\n"
            for param in endpoint.queryParameters {
                if param.isRequired {
                    code += "        queryItems.append(URLQueryItem(name: \"\(param.name)\", value: String(describing: \(param.name))))\n"
                } else {
                    code += "        if let \(param.name) = \(param.name) {\n"
                    code += "            queryItems.append(URLQueryItem(name: \"\(param.name)\", value: String(describing: \(param.name))))\n"
                    code += "        }\n"
                }
            }
        }

        // Body encoding
        if endpoint.requestBody != nil {
            code += "        let encoder = JSONEncoder()\n"
            code += "        encoder.dateEncodingStrategy = .iso8601\n"
            code += "        let bodyData = try encoder.encode(body)\n"
        }

        // Build and execute request
        let queryParam = endpoint.queryParameters.isEmpty ? "nil" : "queryItems"
        let bodyParam = endpoint.requestBody != nil ? "bodyData" : "nil"

        code += "        let request = try buildRequest(\n"
        code += "            path: path,\n"
        code += "            method: .\(endpoint.method.lowercased()),\n"
        code += "            queryItems: \(queryParam),\n"
        code += "            body: \(bodyParam)\n"
        code += "        )\n"

        if let response = endpoint.responseType {
            code += "        return try await execute(request) as \(response)\n"
        } else {
            code += "        try await executeVoid(request)\n"
        }

        code += "    }\n"
        return code
    }
}

// MARK: - API Client Code Generation Helpers

extension APIGenerator {
    private func generateAPIClientHeader(for spec: APISpec) -> String {
        """

        // MARK: - \(spec.name) API Client

        public actor \(spec.name)APIClient {
            // MARK: - Configuration

            private let baseURL: URL
            private let session: URLSession
            private var headers: [String: String]

            // MARK: - Initialization

            public init(
                baseURL: URL,
                session: URLSession = .shared,
                headers: [String: String] = [:]
            ) {
                self.baseURL = baseURL
                self.session = session
                self.headers = headers
            }

            // MARK: - Configuration

            public func setHeader(_ value: String, forKey key: String) {
                headers[key] = value
            }

            public func removeHeader(forKey key: String) {
                headers.removeValue(forKey: key)
            }

            public func setAuthToken(_ token: String) {
                headers["Authorization"] = "Bearer \\(token)"
            }


        """
    }

    private func generateAPIClientRequestBuilder() -> String {
        """
            // MARK: - Request Building

            private func buildRequest(
                path: String,
                method: HTTPMethod,
                queryItems: [URLQueryItem]? = nil,
                body: Data? = nil
            ) throws -> URLRequest {
                var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: true)
                components?.queryItems = queryItems

                guard let url = components?.url else {
                    throw APIError.invalidURL(path)
                }

                var request = URLRequest(url: url)
                request.httpMethod = method.rawValue
                request.httpBody = body

                // Add default headers
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("application/json", forHTTPHeaderField: "Accept")

                // Add custom headers
                for (key, value) in headers {
                    request.setValue(value, forHTTPHeaderField: key)
                }

                return request
            }


        """
    }

    private func generateAPIClientRequestExecutor() -> String {
        """
            // MARK: - Request Execution

            private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    throw APIError.httpError(statusCode: httpResponse.statusCode, data: data)
                }

                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return try decoder.decode(T.self, from: data)
            }

            private func executeVoid(_ request: URLRequest) async throws {
                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    throw APIError.httpError(statusCode: httpResponse.statusCode, data: data)
                }
            }

            // MARK: - Endpoints


        """
    }
}
