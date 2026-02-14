//
//  APIGeneratorTests.swift
//  TheaTests
//
//  Created by Claude Code on 2026-01-20
//

@testable import TheaCore
import XCTest

final class APIGeneratorTests: XCTestCase {
    // MARK: - APIPropertyType Tests

    func testPropertyTypeSwiftTypes() {
        XCTAssertEqual(APIPropertyType.string.swiftType, "String")
        XCTAssertEqual(APIPropertyType.integer.swiftType, "Int")
        XCTAssertEqual(APIPropertyType.number.swiftType, "Double")
        XCTAssertEqual(APIPropertyType.boolean.swiftType, "Bool")
        XCTAssertEqual(APIPropertyType.array.swiftType, "[Any]")
        XCTAssertEqual(APIPropertyType.object.swiftType, "[String: Any]")
    }

    // MARK: - APIParameterSpec Tests

    func testParameterSpecSwiftType() {
        let requiredParam = APIParameterSpec(name: "id", type: .string, description: "ID", isRequired: true)
        XCTAssertEqual(requiredParam.swiftType, "String")

        let optionalParam = APIParameterSpec(name: "filter", type: .string, description: "Filter", isRequired: false)
        XCTAssertEqual(optionalParam.swiftType, "String")
    }

    // MARK: - APIPropertySpec Tests

    func testPropertySpecCreation() {
        let prop = APIPropertySpec(
            name: "userName",
            jsonKey: "user_name",
            type: .string,
            description: "User name",
            isRequired: true
        )
        XCTAssertEqual(prop.name, "userName")
        XCTAssertEqual(prop.jsonKey, "user_name")
        XCTAssertEqual(prop.swiftType, "String")
    }

    func testPropertySpecDefaultJsonKey() {
        let prop = APIPropertySpec(name: "email", type: .string)
        XCTAssertEqual(prop.jsonKey, "email", "Should default to property name")
    }

    // MARK: - APIModelSpec Tests

    func testModelSpecCreation() {
        var model = APIModelSpec(name: "User")
        model.properties.append(APIPropertySpec(name: "id", type: .integer, isRequired: true))
        model.properties.append(APIPropertySpec(name: "name", type: .string, isRequired: true))
        model.properties.append(APIPropertySpec(name: "email", type: .string, isRequired: false))

        XCTAssertEqual(model.id, "User")
        XCTAssertEqual(model.properties.count, 3)
    }

    // MARK: - APIEndpointSpec Tests

    func testEndpointSpecCreation() {
        let endpoint = APIEndpointSpec(
            path: "/users/{id}",
            method: "GET",
            operationId: "getUser",
            description: "Get user by ID",
            pathParameters: [
                APIParameterSpec(name: "id", type: .string, description: "User ID", isRequired: true)
            ],
            responseType: "User"
        )

        XCTAssertEqual(endpoint.id, "getUser")
        XCTAssertEqual(endpoint.method, "GET")
        XCTAssertEqual(endpoint.pathParameters.count, 1)
    }

    func testEndpointWithQueryParameters() {
        let endpoint = APIEndpointSpec(
            path: "/users",
            method: "GET",
            operationId: "listUsers",
            description: "List users",
            queryParameters: [
                APIParameterSpec(name: "page", type: .integer, description: "Page number", isRequired: false),
                APIParameterSpec(name: "limit", type: .integer, description: "Results per page", isRequired: false)
            ],
            responseType: "[User]"
        )

        XCTAssertEqual(endpoint.queryParameters.count, 2)
    }

    // MARK: - APISpec Tests

    func testAPISpecCreation() {
        let spec = APISpec(
            name: "UserAPI",
            version: "1.0.0",
            baseURL: "https://api.example.com/v1"
        )

        XCTAssertEqual(spec.name, "UserAPI")
        XCTAssertEqual(spec.version, "1.0.0")
        XCTAssertEqual(spec.baseURL, "https://api.example.com/v1")
    }

    func testAPISpecWithEndpoints() {
        var spec = APISpec(name: "TestAPI")
        spec.endpoints.append(APIEndpointSpec(
            path: "/items",
            method: "GET",
            operationId: "listItems",
            description: "List items"
        ))
        spec.endpoints.append(APIEndpointSpec(
            path: "/items",
            method: "POST",
            operationId: "createItem",
            description: "Create item"
        ))

        XCTAssertEqual(spec.endpoints.count, 2)
    }

    // MARK: - APIBodySpec Tests

    func testBodySpecCreation() {
        let body = APIBodySpec(swiftType: "CreateUserRequest")
        XCTAssertEqual(body.swiftType, "CreateUserRequest")
    }

    // MARK: - APITemplate Tests

    func testTemplateCreation() {
        let endpoints = [
            APIEndpointSpec(path: "/items", method: "GET", operationId: "list", description: "List")
        ]
        let template = APITemplate(name: "crud", description: "CRUD operations", defaultEndpoints: endpoints)
        XCTAssertEqual(template.name, "crud")
        XCTAssertEqual(template.defaultEndpoints.count, 1)
    }

    func testTemplateConfigCreation() {
        var config = APITemplateConfig(apiName: "MyAPI")
        config.baseURL = "https://my-api.com"
        config.version = "2.0.0"
        XCTAssertEqual(config.apiName, "MyAPI")
        XCTAssertEqual(config.baseURL, "https://my-api.com")
    }

    // MARK: - HTTPMethod Tests

    func testHTTPMethodRawValues() {
        XCTAssertEqual(HTTPMethod.get.rawValue, "GET")
        XCTAssertEqual(HTTPMethod.post.rawValue, "POST")
        XCTAssertEqual(HTTPMethod.put.rawValue, "PUT")
        XCTAssertEqual(HTTPMethod.patch.rawValue, "PATCH")
        XCTAssertEqual(HTTPMethod.delete.rawValue, "DELETE")
    }

    // MARK: - GeneratedAPIError Tests

    func testGeneratedAPIErrorDescriptions() {
        XCTAssertEqual(GeneratedAPIError.invalidURL("/bad").errorDescription, "Invalid URL: /bad")
        XCTAssertEqual(GeneratedAPIError.invalidResponse.errorDescription, "Invalid response from server")
        XCTAssertEqual(GeneratedAPIError.httpError(statusCode: 404, data: Data()).errorDescription, "HTTP error: 404")
    }

    // MARK: - APIGeneratorError Tests

    func testGeneratorErrorDescriptions() {
        XCTAssertEqual(APIGeneratorError.templateNotFound("test").errorDescription, "Template not found: test")
        XCTAssertEqual(APIGeneratorError.apiNotFound("api1").errorDescription, "Generated API not found: api1")
        XCTAssertEqual(APIGeneratorError.invalidOpenAPISpec("bad json").errorDescription, "Invalid OpenAPI specification: bad json")
    }

    // MARK: - Generator Tests

    func testGetAvailableTemplates() async {
        await APIGenerator.shared.initialize()
        let templates = await APIGenerator.shared.getAvailableTemplates()
        XCTAssertGreaterThan(templates.count, 0, "Should have default templates after initialization")
    }

    func testGenerateAPI() async throws {
        let spec = APISpec(
            name: "TestAPI",
            version: "1.0.0",
            baseURL: "https://api.test.com",
            endpoints: [
                APIEndpointSpec(
                    path: "/items",
                    method: "GET",
                    operationId: "listItems",
                    description: "List all items",
                    responseType: "[Item]"
                )
            ],
            models: [
                APIModelSpec(name: "Item", properties: [
                    APIPropertySpec(name: "id", type: .string, isRequired: true),
                    APIPropertySpec(name: "name", type: .string, isRequired: true)
                ])
            ]
        )

        let api = try await APIGenerator.shared.generateAPI(from: spec)
        XCTAssertEqual(api.name, "TestAPI")
        XCTAssertFalse(api.generatedCode.isEmpty)
        XCTAssertTrue(api.generatedCode.contains("TestAPIAPIClient"))
        XCTAssertTrue(api.generatedCode.contains("struct Item"))
    }
}
