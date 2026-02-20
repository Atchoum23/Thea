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

        // Initialize MCP tool registry
        Task { @MainActor in
            _ = MCPToolRegistry.shared
        }
    }

    // MARK: - Tool Registration

    private func registerBuiltInTools() {
        // Use system tools from SystemToolBridge
        registerSystemTools()
    }

    func registerTool(_ tool: Tool) {
        registeredTools.append(tool)
    }

    // MARK: - Tool Discovery

    func discoverTools(for task: String) async throws -> [Tool] {
        guard let provider = ProviderRegistry.shared.getProvider(id: SettingsManager.shared.defaultProvider) else {
            throw MetaAIToolError.providerNotAvailable
        }

        let toolDescriptions = registeredTools.map { tool in
            "\(tool.name): \(tool.description)\nParameters: \(tool.parameters.map(\.name).joined(separator: ", "))"
        }.joined(separator: "\n")

        let prompt = """
        Given this task: \(task)

        Available tools:
        \(toolDescriptions)

        Which tools would be most useful for this task? Return only tool names, comma-separated.
        """

        let response = try await streamProviderResponse(provider: provider, prompt: prompt, model: "gpt-4o-mini")

        // Parse tool names from response
        let toolNames = response.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        return registeredTools.filter { tool in
            toolNames.contains { $0.lowercased().contains(tool.name.lowercased()) }
        }
    }

    // MARK: - Tool Execution

    func executeTool(_ tool: Tool, parameters: [String: Any]) async throws -> MetaAIToolResult {
        let startTime = Date()

        do {
            let result = try await tool.handler(parameters)

            return MetaAIToolResult(
                success: true,
                output: result,
                error: nil,
                executionTime: Date().timeIntervalSince(startTime)
            )
        } catch {
            return MetaAIToolResult(
                success: false,
                output: nil,
                error: error.localizedDescription,
                executionTime: Date().timeIntervalSince(startTime)
            )
        }
    }

    func executeToolChain(_ tools: [Tool], initialInput: [String: Any]) async throws -> [MetaAIToolResult] {
        var results: [MetaAIToolResult] = []
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

    // MARK: - Helper Methods

    private func streamProviderResponse(provider: AIProvider, prompt: String, model: String) async throws -> String {
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
            case let .delta(text):
                result += text
            case .complete:
                break
            case let .error(error):
                throw error
            }
        }

        return result
    }
}

// MARK: - Models

struct Tool: Identifiable, Codable, @unchecked Sendable {
    let id: UUID
    let name: String
    let description: String
    let parameters: [ToolParameter]
    let category: ToolCategory
    let handler: @MainActor ([String: Any]) async throws -> Any

    enum CodingKeys: String, CodingKey {
        case id, name, description, parameters, category
    }

    init(id: UUID, name: String, description: String, parameters: [ToolParameter], category: ToolCategory, handler: @escaping @MainActor ([String: Any]) async throws -> Any) {
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
        handler = { _ in throw MetaAIToolError.notImplemented }
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

struct MetaAIToolResult: @unchecked Sendable {
    let success: Bool
    let output: Any?
    let error: String?
    let executionTime: TimeInterval
}

enum MetaAIToolError: LocalizedError {
    case providerNotAvailable
    case invalidParameters
    case executionFailed
    case notImplemented
    case commandBlocked(String) // SECURITY FIX (FINDING-003): Added for command validation
    case pathBlocked(String) // SECURITY FIX (FINDING-007): Added for path validation
    case urlBlocked(String) // SECURITY FIX (SSRF): Added for URL validation

    var errorDescription: String? {
        switch self {
        case .providerNotAvailable:
            "AI provider not available"
        case .invalidParameters:
            "Invalid tool parameters"
        case .executionFailed:
            "Tool execution failed"
        case .notImplemented:
            "Tool handler not implemented"
        case let .commandBlocked(reason):
            "SECURITY: Command blocked - \(reason)"
        case let .pathBlocked(reason):
            "SECURITY: Path access blocked - \(reason)"
        case let .urlBlocked(reason):
            "SECURITY: URL access blocked - \(reason)"
        }
    }
}
