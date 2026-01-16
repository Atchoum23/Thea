import Foundation

// MARK: - Dynamic Tool Use Framework
// Enables AI to discover, register, and execute various tools dynamically

@MainActor
@Observable
final class ToolFramework {
  static let shared = ToolFramework()

  private(set) var registeredTools: [Tool] = []
  private(set) var toolExecutionHistory: [ToolExecution] = []

  private init() {
    registerBuiltInTools()
  }

  // MARK: - Tool Registration

  private func registerBuiltInTools() {
    // File System Tools
    registerTool(
      Tool(
        id: UUID(),
        name: "read_file",
        description: "Read contents of a file",
        parameters: [
          ToolParameter(
            name: "path", type: .string, required: true, description: "File path to read")
        ],
        category: .fileSystem,
        handler: readFile
      ))

    registerTool(
      Tool(
        id: UUID(),
        name: "write_file",
        description: "Write content to a file",
        parameters: [
          ToolParameter(
            name: "path", type: .string, required: true, description: "File path to write"),
          ToolParameter(
            name: "content", type: .string, required: true, description: "Content to write"),
        ],
        category: .fileSystem,
        handler: writeFile
      ))

    registerTool(
      Tool(
        id: UUID(),
        name: "list_directory",
        description: "List files in a directory",
        parameters: [
          ToolParameter(name: "path", type: .string, required: true, description: "Directory path")
        ],
        category: .fileSystem,
        handler: listDirectory
      ))

    // Web Tools
    registerTool(
      Tool(
        id: UUID(),
        name: "fetch_url",
        description: "Fetch content from a URL",
        parameters: [
          ToolParameter(name: "url", type: .string, required: true, description: "URL to fetch")
        ],
        category: .web,
        handler: fetchURL
      ))

    // Data Tools
    registerTool(
      Tool(
        id: UUID(),
        name: "search_data",
        description: "Search through data with a query",
        parameters: [
          ToolParameter(name: "query", type: .string, required: true, description: "Search query"),
          ToolParameter(name: "source", type: .string, required: false, description: "Data source"),
        ],
        category: .data,
        handler: searchData
      ))

    // Code Tools
    registerTool(
      Tool(
        id: UUID(),
        name: "execute_code",
        description: "Execute code in a sandboxed environment",
        parameters: [
          ToolParameter(
            name: "code", type: .string, required: true, description: "Code to execute"),
          ToolParameter(
            name: "language", type: .string, required: true, description: "Programming language"),
        ],
        category: .code,
        handler: executeCode
      ))
  }

  func registerTool(_ tool: Tool) {
    registeredTools.append(tool)
  }

  // MARK: - Tool Discovery

  func discoverTools(for task: String) async throws -> [Tool] {
    guard
      let provider = ProviderRegistry.shared.getProvider(id: SettingsManager.shared.defaultProvider)
    else {
      throw ToolError.providerNotAvailable
    }

    let toolDescriptions = registeredTools.map { tool in
      "\(tool.name): \(tool.description)\nParameters: \(tool.parameters.map { $0.name }.joined(separator: ", "))"
    }.joined(separator: "\n")

    let prompt = """
      Given this task: \(task)

      Available tools:
      \(toolDescriptions)

      Which tools would be most useful for this task? Return only tool names, comma-separated.
      """

    let response = try await streamProviderResponse(
      provider: provider, prompt: prompt, model: "gpt-4o-mini")

    // Parse tool names from response
    let toolNames = response.split(separator: ",").map {
      $0.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return registeredTools.filter { tool in
      toolNames.contains { $0.lowercased().contains(tool.name.lowercased()) }
    }
  }

  // MARK: - Tool Execution

  nonisolated func executeTool(_ tool: Tool, parameters: [String: Any]) async throws -> ToolResult {
    let startTime = Date()

    do {
      let result = try await tool.handler(parameters)

      return ToolResult(
        success: true,
        output: result,
        error: nil,
        executionTime: Date().timeIntervalSince(startTime)
      )
    } catch {
      return ToolResult(
        success: false,
        output: nil,
        error: error.localizedDescription,
        executionTime: Date().timeIntervalSince(startTime)
      )
    }
  }

  nonisolated func executeToolChain(_ tools: [Tool], initialInput: [String: Any]) async throws
    -> [ToolResult]
  {
    var results: [ToolResult] = []
    var currentInput = initialInput

    for tool in tools {
      let result = try await executeTool(tool, parameters: currentInput)
      results.append(result)

      // Use output as input for next tool
      if let output = result.output as? String {
        currentInput["input"] = output
      }
    }

    return results
  }

  // MARK: - Built-in Tool Handlers

  nonisolated private func readFile(parameters: [String: Any]) async throws -> Any {
    guard let path = parameters["path"] as? String else {
      throw ToolError.invalidParameters
    }

    let url = URL(fileURLWithPath: path)
    let content = try String(contentsOf: url, encoding: .utf8)
    return content
  }

  nonisolated private func writeFile(parameters: [String: Any]) async throws -> Any {
    guard let path = parameters["path"] as? String,
      let content = parameters["content"] as? String
    else {
      throw ToolError.invalidParameters
    }

    let url = URL(fileURLWithPath: path)
    try content.write(to: url, atomically: true, encoding: .utf8)
    return "File written successfully"
  }

  nonisolated private func listDirectory(parameters: [String: Any]) async throws -> Any {
    guard let path = parameters["path"] as? String else {
      throw ToolError.invalidParameters
    }

    let url = URL(fileURLWithPath: path)
    let contents = try FileManager.default.contentsOfDirectory(
      at: url, includingPropertiesForKeys: nil)
    return contents.map { $0.lastPathComponent }
  }

  nonisolated private func fetchURL(parameters: [String: Any]) async throws -> Any {
    guard let urlString = parameters["url"] as? String,
      let url = URL(string: urlString)
    else {
      throw ToolError.invalidParameters
    }

    let (data, _) = try await URLSession.shared.data(from: url)
    guard let content = String(data: data, encoding: .utf8) else {
      throw ToolError.executionFailed
    }

    return content
  }

  nonisolated private func searchData(parameters: [String: Any]) async throws -> Any {
    guard let query = parameters["query"] as? String else {
      throw ToolError.invalidParameters
    }

    // Simplified - would integrate with KnowledgeManager in production
    return "Search results for: \(query)"
  }

  nonisolated private func executeCode(parameters: [String: Any]) async throws -> Any {
    guard let code = parameters["code"] as? String,
      let language = parameters["language"] as? String
    else {
      throw ToolError.invalidParameters
    }

    // Delegate to CodeSandbox (will be implemented next)
    return "Code executed: \(language) - \(code.prefix(50))..."
  }

  // MARK: - Helper Methods

  private func streamProviderResponse(provider: AIProvider, prompt: String, model: String)
    async throws -> String
  {
    let message = AIMessage(
      id: UUID(),
      conversationID: UUID(),
      role: .user,
      content: .text(prompt),
      timestamp: Date(),
      model: model
    )

    var result = ""
    let stream = try await provider.chat(messages: [message], model: model, stream: true)

    for try await chunk in stream {
      switch chunk.type {
      case .delta(let text):
        result += text
      case .complete:
        break
      case .error(let error):
        throw error
      }
    }

    return result
  }
}

// MARK: - Models

struct Tool: Identifiable, Codable, Sendable {
  let id: UUID
  let name: String
  let description: String
  let parameters: [ToolParameter]
  let category: ToolCategory
  let handler: @Sendable ([String: Any]) async throws -> Any

  enum CodingKeys: String, CodingKey {
    case id, name, description, parameters, category
  }

  init(
    id: UUID, name: String, description: String, parameters: [ToolParameter],
    category: ToolCategory, handler: @escaping @Sendable ([String: Any]) async throws -> Any
  ) {
    self.id = id
    self.name = name
    self.description = description
    self.parameters = parameters
    self.category = category
    self.handler = handler
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    name = try container.decode(String.self, forKey: .name)
    description = try container.decode(String.self, forKey: .description)
    parameters = try container.decode([ToolParameter].self, forKey: .parameters)
    category = try container.decode(ToolCategory.self, forKey: .category)
    // Handler cannot be decoded - must be set manually
    handler = { _ in throw ToolError.notImplemented }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(name, forKey: .name)
    try container.encode(description, forKey: .description)
    try container.encode(parameters, forKey: .parameters)
    try container.encode(category, forKey: .category)
  }
}

struct ToolParameter: Codable, Sendable {
  let name: String
  let type: ParameterType
  let required: Bool
  let description: String

  enum ParameterType: String, Codable, Sendable {
    case string, number, boolean, array, object
  }
}

enum ToolCategory: String, Codable, Sendable {
  case fileSystem = "File System"
  case web = "Web"
  case data = "Data"
  case code = "Code"
  case api = "API"
  case image = "Image"
  case audio = "Audio"
  case video = "Video"
}

struct ToolExecution: Identifiable {
  let id: UUID
  let tool: Tool
  let parameters: [String: Any]
  let startTime: Date
  var endTime: Date?
  var status: ExecutionStatus
  var result: Any?
  var error: String?

  enum ExecutionStatus {
    case running, completed, failed
  }
}

struct ToolResult {
  let success: Bool
  let output: Any?
  let error: String?
  let executionTime: TimeInterval
}

enum ToolError: LocalizedError {
  case providerNotAvailable
  case invalidParameters
  case executionFailed
  case notImplemented

  var errorDescription: String? {
    switch self {
    case .providerNotAvailable:
      return "AI provider not available"
    case .invalidParameters:
      return "Invalid tool parameters"
    case .executionFailed:
      return "Tool execution failed"
    case .notImplemented:
      return "Tool handler not implemented"
    }
  }
}
