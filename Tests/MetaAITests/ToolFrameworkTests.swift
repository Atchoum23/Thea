import XCTest

@testable import TheaCore

@MainActor
final class ToolFrameworkTests: XCTestCase {
  var toolFramework: ToolFramework!

  override func setUp() async throws {
    toolFramework = ToolFramework.shared
  }

  func testBuiltInTools() {
    let tools = toolFramework.registeredTools

    XCTAssertGreaterThanOrEqual(tools.count, 6, "Should have at least 6 built-in tools")

    let toolNames = tools.map { $0.name }
    XCTAssertTrue(toolNames.contains("read_file"))
    XCTAssertTrue(toolNames.contains("write_file"))
    XCTAssertTrue(toolNames.contains("list_directory"))
    XCTAssertTrue(toolNames.contains("fetch_url"))
    XCTAssertTrue(toolNames.contains("search_data"))
    XCTAssertTrue(toolNames.contains("execute_code"))
  }

  func testToolRegistration() {
    let initialCount = toolFramework.registeredTools.count

    toolFramework.registerTool(
      Tool(
        name: "custom_tool",
        description: "A custom tool",
        parameters: ["input": "string"],
        category: .data,
        handler: { _ in
          return "Custom result"
        }
      ))

    XCTAssertEqual(toolFramework.registeredTools.count, initialCount + 1)
  }

  func testToolCategories() {
    let categories: [ToolCategory] = [
      .fileSystem, .web, .data, .code, .api, .image, .audio, .video,
    ]

    XCTAssertEqual(categories.count, 8)

    for category in categories {
      XCTAssertFalse(category.rawValue.isEmpty)
    }
  }

  func testToolsByCategory() {
    let fileTools = toolFramework.toolsByCategory(.fileSystem)

    XCTAssertGreaterThan(fileTools.count, 0, "Should have file system tools")

    for tool in fileTools {
      XCTAssertEqual(tool.category, .fileSystem)
    }
  }

  func testToolSearch() {
    let results = toolFramework.searchTools("file")

    XCTAssertGreaterThan(results.count, 0, "Should find file-related tools")

    for tool in results {
      let matchesName = tool.name.localizedCaseInsensitiveContains("file")
      let matchesDescription = tool.description.localizedCaseInsensitiveContains("file")
      XCTAssertTrue(matchesName || matchesDescription)
    }
  }

  func testToolExecution() async throws {
    let tool = toolFramework.registeredTools.first(where: { $0.name == "search_data" })!

    let result = try await toolFramework.executeTool(
      tool,
      parameters: [
        "query": "test",
        "data": ["test1", "test2", "testing"],
      ])

    XCTAssertTrue(result.success)
    XCTAssertNotNil(result.output)
  }

  func testToolChaining() async throws {
    let tools = [
      toolFramework.registeredTools.first(where: { $0.name == "search_data" })!
    ]

    let chainResult = try await toolFramework.executeToolChain(
      tools,
      initialInput: ["query": "test", "data": ["test1", "test2"]]
    )

    XCTAssertEqual(chainResult.count, 1)
    XCTAssertTrue(chainResult[0].success)
  }
}
