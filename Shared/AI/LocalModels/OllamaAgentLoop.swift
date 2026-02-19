import Foundation
import OSLog

// MARK: - Ollama 0.14 Agent Loop Support
// Implements the new --experimental agent loop from Ollama 0.14 (January 2026)
// Features: bash tool execution, web search, interactive approval

/// Agent loop for Ollama 0.14+ with tool execution capabilities
@MainActor
@Observable
final class OllamaAgentLoop {
    static let shared = OllamaAgentLoop()

    private let logger = Logger(subsystem: "ai.thea.app", category: "OllamaAgentLoop")

    // MARK: - Configuration

    struct Configuration: Sendable {
        var ollamaBaseURL: String = "http://localhost:11434"
        var enableBashTool: Bool = true
        var enableWebSearch: Bool = true
        var autoApproveCommands: Set<String> = [
            "pwd", "ls", "cat", "head", "tail", "echo", "date",
            "git status", "git diff", "git log", "git branch",
            "npm run", "npm test", "swift build", "swift test",
            "xcodebuild -version", "swiftlint lint"
        ]
        var requireApprovalForDestructive: Bool = true
        var maxToolIterations: Int = 10
        var timeoutSeconds: TimeInterval = 120
    }

    private(set) var configuration = Configuration()
    private(set) var isRunning = false
    private(set) var currentModel: String?
    // periphery:ignore - Reserved: shared static property reserved for future feature activation
    private(set) var toolHistory: [ToolExecution] = []
    // periphery:ignore - Reserved: logger property reserved for future feature activation
    private(set) var pendingApproval: ToolApprovalRequest?

    // MARK: - Tool Types

    enum ToolType: String, Codable, Sendable {
        case bash
        case webSearch = "web_search"
    }

    struct ToolCall: Codable, Sendable {
        let type: ToolType
        let command: String?
        let query: String?
    }

    struct ToolExecution: Identifiable, Sendable {
        let id = UUID()
        let timestamp: Date
        let tool: ToolType
        let input: String
        let output: String
        let approved: Bool
        let autoApproved: Bool
    }

    struct ToolApprovalRequest: Identifiable, Sendable {
        let id = UUID()
        let tool: ToolType
        let input: String
        let reason: String
        var continuation: CheckedContinuation<Bool, Never>?
    }

    // MARK: - Agent Loop Execution

    /// Run an agent loop with the specified model and prompt
    func run(
        model: String,
        prompt: String,
        // periphery:ignore - Reserved: timestamp property reserved for future feature activation
        // periphery:ignore - Reserved: tool property reserved for future feature activation
        // periphery:ignore - Reserved: input property reserved for future feature activation
        // periphery:ignore - Reserved: output property reserved for future feature activation
        // periphery:ignore - Reserved: approved property reserved for future feature activation
        // periphery:ignore - Reserved: autoApproved property reserved for future feature activation
        stream: Bool = true
    ) async throws -> AsyncThrowingStream<AgentLoopEvent, Error> {
        isRunning = true
        currentModel = model
        // periphery:ignore - Reserved: tool property reserved for future feature activation
        // periphery:ignore - Reserved: input property reserved for future feature activation
        // periphery:ignore - Reserved: reason property reserved for future feature activation
        toolHistory.removeAll()

        return AsyncThrowingStream { continuation in
            Task { @MainActor in
                defer {
                    self.isRunning = false
                    // periphery:ignore - Reserved: run(model:prompt:stream:) instance method reserved for future feature activation
                    self.currentModel = nil
                }

                do {
                    var messages: [[String: Any]] = [
                        ["role": "user", "content": prompt]
                    ]

                    var iterations = 0

                    while iterations < self.configuration.maxToolIterations {
                        iterations += 1

                        // Call Ollama with tools enabled
                        let response = try await self.callOllamaWithTools(
                            model: model,
                            messages: messages,
                            stream: stream,
                            continuation: continuation
                        )

                        // Check if model wants to use a tool
                        if let toolCalls = response.toolCalls, !toolCalls.isEmpty {
                            for toolCall in toolCalls {
                                let result = try await self.executeTool(
                                    toolCall,
                                    continuation: continuation
                                )

                                // Add tool result to messages
                                messages.append([
                                    "role": "tool",
                                    "content": result
                                ])

                                continuation.yield(.toolResult(toolCall.type, result))
                            }
                        } else {
                            // No more tool calls, agent loop complete
                            continuation.yield(.complete(response.content))
                            break
                        }
                    }

                    if iterations >= self.configuration.maxToolIterations {
                        continuation.yield(.maxIterationsReached)
                    }

                    continuation.finish()
                } catch {
                    continuation.yield(.error(error))
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Ollama API with Tools

    private struct OllamaResponse {
        let content: String
        let toolCalls: [ToolCall]?
    }

    private func callOllamaWithTools(
        model: String,
        messages: [[String: Any]],
        stream _: Bool,
        continuation: AsyncThrowingStream<AgentLoopEvent, Error>.Continuation
    ) async throws -> OllamaResponse {
        guard let url = URL(string: "\(configuration.ollamaBaseURL)/api/chat") else {
            // periphery:ignore - Reserved: OllamaResponse type reserved for future feature activation
            throw OllamaAgentError.invalidURL
        }

        var request = URLRequest(url: url)
        // periphery:ignore - Reserved: callOllamaWithTools(model:messages:stream:continuation:) instance method reserved for future feature activation
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = configuration.timeoutSeconds

        // Build tools array for Ollama 0.14+
        var tools: [[String: Any]] = []

        if configuration.enableBashTool {
            tools.append([
                "type": "function",
                "function": [
                    "name": "bash",
                    "description": "Execute a bash command on the system",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "command": [
                                "type": "string",
                                "description": "The bash command to execute"
                            ]
                        ],
                        "required": ["command"]
                    ]
                ]
            ])
        }

        if configuration.enableWebSearch {
            tools.append([
                "type": "function",
                "function": [
                    "name": "web_search",
                    "description": "Search the web for information",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "query": [
                                "type": "string",
                                "description": "The search query"
                            ]
                        ],
                        "required": ["query"]
                    ]
                ]
            ])
        }

        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "tools": tools,
            "stream": true
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, _) = try await URLSession.shared.bytes(for: request)

        var content = ""
        var toolCalls: [ToolCall] = []

        for try await line in bytes.lines {
            guard let data = line.data(using: .utf8) else { continue }
            let json: [String: Any]
            do {
                guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                json = parsed
            } catch {
                logger.error("Failed to parse streaming JSON line: \(error.localizedDescription)")
                continue
            }

            // Parse streaming response
            if let message = json["message"] as? [String: Any] {
                if let text = message["content"] as? String {
                    content += text
                    continuation.yield(.text(text))
                }

                // Check for tool calls
                if let calls = message["tool_calls"] as? [[String: Any]] {
                    for call in calls {
                        if let function = call["function"] as? [String: Any],
                           let name = function["name"] as? String,
                           let args = function["arguments"] as? [String: Any]
                        {
                            let toolCall = ToolCall(
                                type: ToolType(rawValue: name) ?? .bash,
                                command: args["command"] as? String,
                                query: args["query"] as? String
                            )
                            toolCalls.append(toolCall)
                        }
                    }
                }
            }
        }

        return OllamaResponse(content: content, toolCalls: toolCalls.isEmpty ? nil : toolCalls)
    }

    // MARK: - Tool Execution

    private func executeTool(
        _ toolCall: ToolCall,
        continuation: AsyncThrowingStream<AgentLoopEvent, Error>.Continuation
    ) async throws -> String {
        let input: String
        switch toolCall.type {
        case .bash:
            input = toolCall.command ?? ""
        case .webSearch:
            input = toolCall.query ?? ""
        // periphery:ignore - Reserved: executeTool(_:continuation:) instance method reserved for future feature activation
        }

        continuation.yield(.toolCall(toolCall.type, input))

        // Check if approval is needed
        let needsApproval = !isAutoApproved(toolCall)

        var approved = true
        var autoApproved = false

        if needsApproval, configuration.requireApprovalForDestructive {
            // Request user approval
            approved = await requestApproval(for: toolCall)

            if !approved {
                let result = "[Tool execution denied by user]"
                toolHistory.append(ToolExecution(
                    timestamp: Date(),
                    tool: toolCall.type,
                    input: input,
                    output: result,
                    approved: false,
                    autoApproved: false
                ))
                return result
            }
        } else {
            autoApproved = true
        }

        // Execute the tool
        let result: String
        switch toolCall.type {
        case .bash:
            result = try await executeBash(toolCall.command ?? "")
        case .webSearch:
            result = try await executeWebSearch(toolCall.query ?? "")
        }

        toolHistory.append(ToolExecution(
            timestamp: Date(),
            tool: toolCall.type,
            input: input,
            output: result,
            approved: approved,
            autoApproved: autoApproved
        ))

        return result
    }

    private func isAutoApproved(_ toolCall: ToolCall) -> Bool {
        guard toolCall.type == .bash else { return false }
        guard let command = toolCall.command else { return false }

        // Check against auto-approve list
        for safeCommand in configuration.autoApproveCommands {
            if command.hasPrefix(safeCommand) {
                return true
            }
        // periphery:ignore - Reserved: isAutoApproved(_:) instance method reserved for future feature activation
        }

        // Check for destructive commands
        let destructivePatterns = [
            "rm ", "rm -", "rmdir", "mv ", "dd ",
            "sudo ", "chmod ", "chown ",
            "> /", ">> /", "| sudo"
        ]

        for pattern in destructivePatterns {
            if command.contains(pattern) {
                return false
            }
        }

        return false
    }

    private func requestApproval(for toolCall: ToolCall) async -> Bool {
        await withCheckedContinuation { cont in
            let input = toolCall.command ?? toolCall.query ?? ""
            pendingApproval = ToolApprovalRequest(
                tool: toolCall.type,
                input: input,
                reason: "This command requires your approval",
                continuation: cont
            // periphery:ignore - Reserved: requestApproval(for:) instance method reserved for future feature activation
            )
        }
    }

    /// Call this from UI to approve/deny pending tool execution
    func respondToApproval(_ approved: Bool) {
        guard let request = pendingApproval else { return }
        request.continuation?.resume(returning: approved)
        pendingApproval = nil
    }

    // MARK: - Tool Implementations

// periphery:ignore - Reserved: respondToApproval(_:) instance method reserved for future feature activation

    private func executeBash(_ command: String) async throws -> String {
        #if os(macOS)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]

        // periphery:ignore - Reserved: executeBash(_:) instance method reserved for future feature activation
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        let output = String(data: outputData, encoding: .utf8) ?? ""
        let error = String(data: errorData, encoding: .utf8) ?? ""

        if process.terminationStatus != 0, !error.isEmpty {
            return "Error (exit \(process.terminationStatus)):\n\(error)"
        }

        return output.isEmpty ? "(no output)" : output
        #else
        return "[Bash execution not available on this platform]"
        #endif
    }

    private func executeWebSearch(_ query: String) async throws -> String {
        // Use Ollama's web search API endpoint
        guard let url = URL(string: "\(configuration.ollamaBaseURL)/api/search") else {
            throw OllamaAgentError.invalidURL
        }

// periphery:ignore - Reserved: executeWebSearch(_:) instance method reserved for future feature activation

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["query": query]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)

        let parsedJSON: [String: Any]?
        do {
            parsedJSON = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        } catch {
            logger.error("Failed to parse web search response JSON: \(error.localizedDescription)")
            parsedJSON = nil
        }
        if let json = parsedJSON,
           let results = json["results"] as? [[String: Any]]
        {
            var searchResults = "Web search results for '\(query)':\n\n"
            for (index, result) in results.prefix(5).enumerated() {
                let title = result["title"] as? String ?? "Untitled"
                let snippet = result["snippet"] as? String ?? ""
                let resultURL = result["url"] as? String ?? ""
                searchResults += "\(index + 1). \(title)\n   \(snippet)\n   URL: \(resultURL)\n\n"
            }
            return searchResults
        }

        return "No results found for '\(query)'"
    }

    // MARK: - Configuration

    func updateConfiguration(_ config: Configuration) {
        configuration = config
    }

    // periphery:ignore - Reserved: updateConfiguration(_:) instance method reserved for future feature activation
    func addAutoApproveCommand(_ command: String) {
        configuration.autoApproveCommands.insert(command)
    }

// periphery:ignore - Reserved: addAutoApproveCommand(_:) instance method reserved for future feature activation

    func removeAutoApproveCommand(_ command: String) {
        configuration.autoApproveCommands.remove(command)
    // periphery:ignore - Reserved: removeAutoApproveCommand(_:) instance method reserved for future feature activation
    }
}

// MARK: - Agent Loop Events

enum AgentLoopEvent: Sendable {
    // periphery:ignore - Reserved: AgentLoopEvent type reserved for future feature activation
    case text(String)
    case toolCall(OllamaAgentLoop.ToolType, String)
    case toolResult(OllamaAgentLoop.ToolType, String)
    case complete(String)
    case maxIterationsReached
    case error(Error)
}

// MARK: - Errors

// periphery:ignore - Reserved: OllamaAgentError type reserved for future feature activation
enum OllamaAgentError: LocalizedError {
    case invalidURL
    case ollamaNotRunning
    case toolExecutionFailed(String)
    case approvalDenied

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Ollama URL"
        case .ollamaNotRunning:
            return "Ollama is not running. Start it with 'ollama serve'"
        case let .toolExecutionFailed(reason):
            return "Tool execution failed: \(reason)"
        case .approvalDenied:
            return "Tool execution denied by user"
        }
    }
}
