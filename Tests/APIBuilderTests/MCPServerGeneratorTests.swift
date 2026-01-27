//
//  MCPServerGeneratorTests.swift
//  TheaTests
//
//  Created by Claude Code on 2026-01-20
//

@testable import TheaCore
import XCTest

final class MCPServerGeneratorTests: XCTestCase {
    // MARK: - MCPParameterType Tests

    func testParameterTypeSwiftTypes() {
        XCTAssertEqual(MCPParameterType.string.rawValue, "string")
        XCTAssertEqual(MCPParameterType.number.rawValue, "number")
        XCTAssertEqual(MCPParameterType.integer.rawValue, "integer")
        XCTAssertEqual(MCPParameterType.boolean.rawValue, "boolean")
        XCTAssertEqual(MCPParameterType.array.rawValue, "array")
        XCTAssertEqual(MCPParameterType.object.rawValue, "object")
    }

    // MARK: - MCPParameterSpec Tests

    func testParameterSpecSwiftType() {
        let stringParam = MCPParameterSpec(name: "name", type: .string, description: "A name", isRequired: true)
        XCTAssertEqual(stringParam.swiftType, "String")

        let optionalNumberParam = MCPParameterSpec(name: "count", type: .number, description: "Count", isRequired: false)
        XCTAssertEqual(optionalNumberParam.swiftType, "Double?")

        let intParam = MCPParameterSpec(name: "id", type: .integer, description: "ID", isRequired: true)
        XCTAssertEqual(intParam.swiftType, "Int")

        let boolParam = MCPParameterSpec(name: "active", type: .boolean, description: "Active", isRequired: true)
        XCTAssertEqual(boolParam.swiftType, "Bool")
    }

    func testParameterSpecJsonType() {
        let stringParam = MCPParameterSpec(name: "test", type: .string, description: "", isRequired: true)
        XCTAssertEqual(stringParam.jsonType, "string")

        let arrayParam = MCPParameterSpec(name: "items", type: .array, description: "", isRequired: true)
        XCTAssertEqual(arrayParam.jsonType, "array")
    }

    // MARK: - MCPToolSpec Tests

    func testToolSpecIdentifiable() {
        let tool = MCPToolSpec(name: "myTool", description: "A test tool", parameters: [])
        XCTAssertEqual(tool.id, "myTool")
    }

    func testToolSpecWithParameters() {
        let params = [
            MCPParameterSpec(name: "input", type: .string, description: "Input", isRequired: true),
            MCPParameterSpec(name: "options", type: .object, description: "Options", isRequired: false)
        ]
        let tool = MCPToolSpec(name: "process", description: "Process input", parameters: params)
        XCTAssertEqual(tool.parameters.count, 2)
    }

    // MARK: - MCPServerSpec Tests

    func testServerSpecCreation() {
        let spec = MCPServerSpec(
            name: "TestServer",
            version: "2.0.0",
            description: "Test server",
            tools: [],
            resources: [],
            prompts: []
        )
        XCTAssertEqual(spec.name, "TestServer")
        XCTAssertEqual(spec.version, "2.0.0")
        XCTAssertTrue(spec.tools.isEmpty)
    }

    func testServerSpecWithTools() {
        let tool = MCPToolSpec(name: "greet", description: "Say hello", parameters: [])
        var spec = MCPServerSpec(name: "GreetingServer")
        spec.tools.append(tool)
        XCTAssertEqual(spec.tools.count, 1)
    }

    // MARK: - MCPResourceSpec Tests

    func testResourceSpecCreation() {
        let resource = MCPResourceSpec(
            name: "config",
            description: "Configuration file",
            uriTemplate: "file:///config/{name}",
            mimeType: "application/json"
        )
        XCTAssertEqual(resource.id, "config")
        XCTAssertEqual(resource.mimeType, "application/json")
    }

    // MARK: - MCPPromptSpec Tests

    func testPromptSpecCreation() {
        let args = [
            MCPArgumentSpec(name: "topic", description: "Topic to discuss", isRequired: true)
        ]
        let prompt = MCPPromptSpec(name: "discuss", description: "Start discussion", arguments: args)
        XCTAssertEqual(prompt.id, "discuss")
        XCTAssertEqual(prompt.arguments.count, 1)
    }

    // MARK: - MCPTemplate Tests

    func testTemplateCreation() {
        let tools = [
            MCPToolSpec(name: "read", description: "Read file", parameters: [])
        ]
        let template = MCPTemplate(name: "file-ops", description: "File operations", defaultTools: tools)
        XCTAssertEqual(template.name, "file-ops")
        XCTAssertEqual(template.defaultTools.count, 1)
    }

    func testTemplateConfigCreation() {
        var config = MCPTemplateConfig(serverName: "MyServer")
        config.version = "1.5.0"
        config.includeDefaultTools = true
        XCTAssertEqual(config.serverName, "MyServer")
        XCTAssertEqual(config.version, "1.5.0")
    }

    // MARK: - MCPCapabilities Tests

    func testCapabilitiesDictionary() {
        let caps = MCPCapabilities(
            tools: MCPToolsCapability(),
            resources: nil,
            prompts: MCPPromptsCapability()
        )
        let dict = caps.dictionary
        XCTAssertNotNil(dict["tools"])
        XCTAssertNil(dict["resources"])
        XCTAssertNotNil(dict["prompts"])
    }

    // MARK: - MCPToolResult Tests

    func testToolResultDictionary() {
        let content = [MCPContent(type: "text", text: "Hello")]
        let result = MCPToolResult(content: content, isError: false)
        let dict = result.dictionary
        XCTAssertFalse(dict["isError"] as? Bool ?? true)
    }

    // MARK: - MCPError Tests

    func testMCPErrorDescriptions() {
        XCTAssertEqual(MCPError.methodNotFound("test").errorDescription, "Method not found: test")
        XCTAssertEqual(MCPError.toolNotFound("myTool").errorDescription, "Tool not found: myTool")
        XCTAssertEqual(MCPError.invalidParams("bad input").errorDescription, "Invalid parameters: bad input")
    }

    // MARK: - MCPGeneratorError Tests

    func testGeneratorErrorDescriptions() {
        XCTAssertEqual(MCPGeneratorError.templateNotFound("t1").errorDescription, "Template not found: t1")
        XCTAssertEqual(MCPGeneratorError.serverNotFound("s1").errorDescription, "Generated server not found: s1")
    }

    // MARK: - Generator Tests

    func testGetAvailableTemplates() async {
        await MCPServerGenerator.shared.initialize()
        let templates = await MCPServerGenerator.shared.getAvailableTemplates()
        XCTAssertGreaterThan(templates.count, 0, "Should have default templates after initialization")
    }

    func testGenerateServer() async throws {
        let spec = MCPServerSpec(
            name: "TestAPI",
            version: "1.0.0",
            description: "Test API server",
            tools: [
                MCPToolSpec(name: "echo", description: "Echo input", parameters: [
                    MCPParameterSpec(name: "message", type: .string, description: "Message", isRequired: true)
                ])
            ]
        )

        let server = try await MCPServerGenerator.shared.generateServer(from: spec)
        XCTAssertEqual(server.name, "TestAPI")
        XCTAssertFalse(server.generatedCode.isEmpty)
        XCTAssertTrue(server.generatedCode.contains("TestAPIMCPServer"))
    }
}
