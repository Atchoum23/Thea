//
//  APIGenerator+Templates.swift
//  Thea
//
//  Template management methods extracted from APIGenerator
//

import Foundation

// MARK: - APIGenerator + Template Management

extension APIGenerator {
    func loadDefaultTemplates() {
        // REST CRUD template
        templates["crud"] = APITemplate(
            name: "crud",
            description: "Standard CRUD API",
            defaultEndpoints: [
                APIEndpointSpec(path: "/items", method: "GET", operationId: "listItems", description: "List all items"),
                APIEndpointSpec(path: "/items/{id}", method: "GET", operationId: "getItem", description: "Get item by ID",
                                pathParameters: [APIParameterSpec(name: "id", type: .string, description: "Item ID", isRequired: true)]),
                APIEndpointSpec(path: "/items", method: "POST", operationId: "createItem", description: "Create new item"),
                APIEndpointSpec(path: "/items/{id}", method: "PUT", operationId: "updateItem", description: "Update item",
                                pathParameters: [APIParameterSpec(name: "id", type: .string, description: "Item ID", isRequired: true)]),
                APIEndpointSpec(path: "/items/{id}", method: "DELETE", operationId: "deleteItem", description: "Delete item",
                                pathParameters: [APIParameterSpec(name: "id", type: .string, description: "Item ID", isRequired: true)])
            ]
        )

        // Auth API template
        templates["auth"] = APITemplate(
            name: "auth",
            description: "Authentication API",
            defaultEndpoints: [
                APIEndpointSpec(path: "/auth/login", method: "POST", operationId: "login", description: "User login"),
                APIEndpointSpec(path: "/auth/register", method: "POST", operationId: "register", description: "User registration"),
                APIEndpointSpec(path: "/auth/logout", method: "POST", operationId: "logout", description: "User logout"),
                APIEndpointSpec(path: "/auth/refresh", method: "POST", operationId: "refreshToken", description: "Refresh auth token"),
                APIEndpointSpec(path: "/auth/me", method: "GET", operationId: "getCurrentUser", description: "Get current user")
            ]
        )
    }

    // periphery:ignore - Reserved: exportAPI(_:to:) instance method reserved for future feature activation
    /// Export generated API to file
    func exportAPI(_ id: String, to directory: URL) async throws -> URL {
        guard let api = generatedAPIs[id] else {
            throw APIGeneratorError.apiNotFound(id)
        }

        let fileName = "\(api.name)API.swift"
        let fileURL = directory.appendingPathComponent(fileName)

        try api.generatedCode.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
}
