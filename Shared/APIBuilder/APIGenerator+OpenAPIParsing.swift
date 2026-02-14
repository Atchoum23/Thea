//
//  APIGenerator+OpenAPIParsing.swift
//  Thea
//
//  OpenAPI parsing methods extracted from APIGenerator
//

import Foundation

// MARK: - APIGenerator + OpenAPI Parsing

extension APIGenerator {
    func parseOpenAPISpec(_ data: Data) throws -> APISpec {
        // Parse OpenAPI JSON/YAML
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIGeneratorError.invalidOpenAPISpec("Unable to parse JSON")
        }

        let info = json["info"] as? [String: Any] ?? [:]
        let title = (info["title"] as? String ?? "API").replacingOccurrences(of: " ", with: "")
        let version = info["version"] as? String ?? "1.0.0"

        var spec = APISpec(
            name: title,
            version: version,
            baseURL: parseServers(json["servers"])
        )

        // Parse paths
        if let paths = json["paths"] as? [String: Any] {
            for (path, pathItem) in paths {
                if let methods = pathItem as? [String: Any] {
                    for (method, operation) in methods {
                        if let opDict = operation as? [String: Any],
                           let endpoint = parseEndpoint(path: path, method: method, operation: opDict)
                        {
                            spec.endpoints.append(endpoint)
                        }
                    }
                }
            }
        }

        // Parse components/schemas
        if let components = json["components"] as? [String: Any],
           let schemas = components["schemas"] as? [String: Any]
        {
            for (name, schema) in schemas {
                if let schemaDict = schema as? [String: Any],
                   let model = parseModel(name: name, schema: schemaDict)
                {
                    spec.models.append(model)
                }
            }
        }

        return spec
    }

    func parseServers(_ servers: Any?) -> String {
        guard let serverList = servers as? [[String: Any]],
              let firstServer = serverList.first,
              let url = firstServer["url"] as? String
        else {
            return "https://api.example.com"
        }
        return url
    }

    func parseEndpoint(path: String, method: String, operation: [String: Any]) -> APIEndpointSpec? {
        let operationId = operation["operationId"] as? String ?? "\(method)\(path.replacingOccurrences(of: "/", with: "_"))"
        let description = operation["summary"] as? String ?? operation["description"] as? String ?? ""

        var endpoint = APIEndpointSpec(
            path: path,
            method: method.uppercased(),
            operationId: operationId,
            description: description
        )

        // Parse parameters
        if let parameters = operation["parameters"] as? [[String: Any]] {
            for param in parameters {
                if let paramSpec = parseParameter(param) {
                    if param["in"] as? String == "path" {
                        endpoint.pathParameters.append(paramSpec)
                    } else if param["in"] as? String == "query" {
                        endpoint.queryParameters.append(paramSpec)
                    }
                }
            }
        }

        // Parse request body
        if let requestBody = operation["requestBody"] as? [String: Any],
           let content = requestBody["content"] as? [String: Any],
           let jsonContent = content["application/json"] as? [String: Any],
           let schema = jsonContent["schema"] as? [String: Any]
        {
            endpoint.requestBody = parseBodySpec(schema)
        }

        // Parse response
        if let responses = operation["responses"] as? [String: Any],
           let successResponse = responses["200"] as? [String: Any] ?? responses["201"] as? [String: Any],
           let content = successResponse["content"] as? [String: Any],
           let jsonContent = content["application/json"] as? [String: Any],
           let schema = jsonContent["schema"] as? [String: Any]
        {
            endpoint.responseType = parseTypeFromSchema(schema)
        }

        return endpoint
    }

    func parseParameter(_ param: [String: Any]) -> APIParameterSpec? {
        guard let name = param["name"] as? String else { return nil }

        let schema = param["schema"] as? [String: Any] ?? [:]
        _ = parseTypeFromSchema(schema)
        let isRequired = param["required"] as? Bool ?? false
        let description = param["description"] as? String ?? ""

        return APIParameterSpec(
            name: name,
            type: APIPropertyType(rawValue: schema["type"] as? String ?? "string") ?? .string,
            description: description,
            isRequired: isRequired
        )
    }

    func parseBodySpec(_ schema: [String: Any]) -> APIBodySpec? {
        let type = parseTypeFromSchema(schema)
        return APIBodySpec(swiftType: type)
    }

    func parseModel(name: String, schema: [String: Any]) -> APIModelSpec? {
        guard let properties = schema["properties"] as? [String: Any] else {
            return nil
        }

        let required = schema["required"] as? [String] ?? []
        var model = APIModelSpec(name: name)

        for (propName, propSchema) in properties {
            if let propDict = propSchema as? [String: Any] {
                let type = APIPropertyType(rawValue: propDict["type"] as? String ?? "string") ?? .string
                let description = propDict["description"] as? String ?? ""

                model.properties.append(APIPropertySpec(
                    name: propName,
                    jsonKey: propName,
                    type: type,
                    description: description,
                    isRequired: required.contains(propName)
                ))
            }
        }

        return model
    }

    func parseTypeFromSchema(_ schema: [String: Any]) -> String {
        if let ref = schema["$ref"] as? String {
            return ref.components(separatedBy: "/").last ?? "Any"
        }

        let type = schema["type"] as? String ?? "string"
        switch type {
        case "string": return "String"
        case "integer": return "Int"
        case "number": return "Double"
        case "boolean": return "Bool"
        case "array":
            if let items = schema["items"] as? [String: Any] {
                return "[\(parseTypeFromSchema(items))]"
            }
            return "[Any]"
        case "object": return "[String: Any]"
        default: return "Any"
        }
    }
}
