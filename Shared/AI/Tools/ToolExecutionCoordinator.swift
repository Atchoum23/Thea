// ToolExecutionCoordinator.swift
// Thea
//
// Orchestrates the Anthropic tool_use loop (B3)
// Makes non-streaming API calls with tools, executes each tool_use block,
// feeds tool_results back, and repeats until stop_reason ≠ "tool_use".
// Returns the final response as an AsyncThrowingStream<ChatResponse, Error>
// so existing ChatManager streaming code doesn't need to change.

import Foundation
import os.log

private let coordLogger = Logger(subsystem: "ai.thea.app", category: "ToolExecutionCoordinator")

/// Wraps [String: Any] to satisfy Swift 6 Sendable requirements for JSON-compatible dicts.
/// Safe: Dictionary is a value type; JSON primitives (String, Number, Bool, null) are all value types.
private struct _SendableDict: @unchecked Sendable {
    let dict: [String: Any]
    init(_ dict: [String: Any]) { self.dict = dict }
}

// MARK: - Coordinator

// Changed from `actor` to `@MainActor final class`: the coordinator has no mutable stored state,
// so actor isolation adds no safety benefit. `@MainActor` lets handler calls avoid
// actor-boundary `sending` checks on `[String: Any]` tool input dictionaries.
@MainActor
final class ToolExecutionCoordinator {
    static let shared = ToolExecutionCoordinator()

    private let maxSteps = 10  // Prevent infinite loops

    private init() {}

    // MARK: - Main Entry Point

    /// Execute a conversation with tool use support, returning a streaming response.
    /// - Parameters:
    ///   - messages: Full conversation history
    ///   - model: Anthropic model ID
    ///   - apiKey: Anthropic API key
    ///   - tools: Tool definitions from AnthropicToolCatalog
    ///   - onToolStep: Callback when a tool step is created/updated (for UI updates)
    func executeWithTools(
        messages: [AIMessage],
        model: String,
        apiKey: String,
        tools: [[String: Any]],
        onToolStep: @Sendable @escaping (ToolUseStep) async -> Void
    ) -> AsyncThrowingStream<ChatResponse, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let result = try await self.runToolLoop(
                        messages: messages,
                        model: model,
                        apiKey: apiKey,
                        tools: tools,
                        onToolStep: onToolStep
                    )
                    // Emit accumulated text as delta chunks, then complete
                    let words = result.text.components(separatedBy: " ")
                    var accumulated = ""
                    for word in words {
                        let chunk = accumulated.isEmpty ? word : " " + word
                        accumulated += chunk
                        continuation.yield(.delta(chunk))
                    }
                    let finalMsg = AIMessage(
                        id: UUID(),
                        conversationID: messages.first?.conversationID ?? UUID(),
                        role: .assistant,
                        content: .text(result.text),
                        timestamp: Date(),
                        model: model
                    )
                    continuation.yield(.complete(finalMsg))
                    continuation.finish()
                } catch {
                    continuation.yield(.error(error))
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Tool Loop

    private struct LoopResult {
        let text: String
        let toolSteps: [ToolUseStep]
    }

    private func runToolLoop(
        messages: [AIMessage],
        model: String,
        apiKey: String,
        tools: [[String: Any]],
        onToolStep: @Sendable @escaping (ToolUseStep) async -> Void
    ) async throws -> LoopResult {
        var conversationMessages = buildAnthropicMessages(from: messages)
        var toolSteps: [ToolUseStep] = []
        var finalText = ""

        for step in 0..<maxSteps {
            coordLogger.debug("Tool loop step \(step + 1)/\(self.maxSteps)")
            let response = try await callAnthropicNonStreaming(
                messages: conversationMessages,
                model: model,
                apiKey: apiKey,
                tools: tools
            )

            let stopReason = response["stop_reason"] as? String ?? "end_turn"
            let content = response["content"] as? [[String: Any]] ?? []

            // Collect all text from this response
            let textBlocks = content.compactMap { block -> String? in
                guard block["type"] as? String == "text" else { return nil }
                return block["text"] as? String
            }
            finalText = textBlocks.joined(separator: "\n")

            // Add assistant's response to history
            conversationMessages.append(["role": "assistant", "content": content])

            guard stopReason == "tool_use" else {
                // No more tool use — we're done
                coordLogger.debug("Tool loop complete: stop_reason=\(stopReason)")
                break
            }

            // Process all tool_use blocks
            let toolUseBlocks = content.filter { ($0["type"] as? String) == "tool_use" }
            guard !toolUseBlocks.isEmpty else { break }

            var toolResults: [[String: Any]] = []

            for block in toolUseBlocks {
                guard let toolId = block["id"] as? String,
                      let toolName = block["name"] as? String,
                      let rawInput = block["input"] as? [String: Any]
                else { continue }

                var toolStep = ToolUseStep(call: AnthropicToolCall(id: toolId, name: toolName, input: rawInput))
                // Create input as a fresh region (not derived from rawInput which is captured by onToolStep)
                var inputDict = (block["input"] as? [String: Any]) ?? [:] 
                inputDict["_tool_use_id"] = toolId
                let sendableInput = _SendableDict(inputDict)
                coordLogger.debug("Executing tool: \(toolName)")
                await onToolStep(toolStep)

                let result = await executeToolCall(name: toolName, input: sendableInput.dict)

                toolStep.result = String(result.content.prefix(300))
                toolStep.isRunning = false
                toolStep.errorMessage = result.isError ? result.content : nil
                toolSteps.append(toolStep)
                await onToolStep(toolStep)

                toolResults.append([
                    "type": "tool_result",
                    "tool_use_id": toolId,
                    "content": result.content,
                    "is_error": result.isError
                ])
            }

            // Append tool_results as user turn for next iteration
            conversationMessages.append(["role": "user", "content": toolResults])
        }

        return LoopResult(text: finalText, toolSteps: toolSteps)
    }

    // MARK: - Tool Dispatcher

    // Class is @MainActor so no `nonisolated`/`sending` needed — all runs on MainActor.
    // @MainActor handler methods (SystemToolHandler, MacOSToolHandler) are called directly.
    private func executeToolCall(name: String, input: [String: Any]) async -> AnthropicToolResult {
        switch name {
        // Memory tools
        case "search_memory", "search_knowledge_graph":
            return await MemoryToolHandler.search(input)
        case "add_memory", "add_knowledge":
            return await MemoryToolHandler.add(input)
        case "list_memories":
            return await MemoryToolHandler.list(input)
        case "update_memory":
            return await MemoryToolHandler.update(input)

        // File tools
        case "read_file":
            return FileToolHandler.read(input)
        case "write_file":
            return FileToolHandler.write(input)
        case "list_directory":
            return FileToolHandler.listDirectory(input)
        case "search_files":
            return FileToolHandler.searchFiles(input)

        // Web tools
        case "web_search":
            return await WebToolHandler.search(input)
        case "fetch_url":
            return await WebToolHandler.fetchURL(input)

        // Code tools
        case "run_code":
            return await CodeToolHandler.execute(input)
        case "analyze_code":
            return CodeToolHandler.analyze(input)

        // System tools (cross-platform)
        case "get_system_info":
            return SystemToolHandler.getSystemInfo(input)

        #if os(macOS)
        // System tools (macOS) — called directly; class is @MainActor
        case "system_notification":
            return await SystemToolHandler.sendNotification(input)
        case "system_clipboard_get":
            return SystemToolHandler.getClipboard(input)
        case "system_clipboard_set":
            return SystemToolHandler.setClipboard(input)
        case "run_command", "terminal_execute":
            return await SystemToolHandler.runCommand(input)
        case "open_application":
            return SystemToolHandler.openApplication(input)

        // macOS integration tools
        case "calendar_list_events":
            return await MacOSToolHandler.calendarListEvents(input)
        case "calendar_create_event":
            return await MacOSToolHandler.calendarCreateEvent(input)
        case "reminders_list":
            return await MacOSToolHandler.remindersList(input)
        case "reminders_create":
            return await MacOSToolHandler.remindersCreate(input)
        case "mail_compose":
            return await MacOSToolHandler.mailCompose(input)
        case "mail_check_unread":
            return await MacOSToolHandler.mailCheckUnread(input)
        case "finder_reveal":
            return MacOSToolHandler.finderReveal(input)
        case "finder_search":
            return MacOSToolHandler.finderSearch(input)
        case "safari_open_url":
            return MacOSToolHandler.safariOpenURL(input)
        case "safari_get_current_url":
            return await MacOSToolHandler.safariGetCurrentURL(input)
        case "music_play":
            return await MacOSToolHandler.musicPlay(input)
        case "shortcuts_run":
            return await MacOSToolHandler.shortcutsRun(input)
        case "shortcuts_list":
            return await MacOSToolHandler.shortcutsList(input)
        case "notes_create":
            return await MacOSToolHandler.notesCreate(input)
        case "notes_search":
            return await MacOSToolHandler.notesSearch(input)
        #endif

        default:
            coordLogger.warning("Unhandled tool: \(name)")
            let id = input["_tool_use_id"] as? String ?? ""
            return AnthropicToolResult(
                toolUseId: id,
                content: "Tool '\(name)' is not yet implemented.",
                isError: false
            )
        }
    }

    // MARK: - Anthropic API Call (non-streaming)

    private func callAnthropicNonStreaming(
        messages: [[String: Any]],
        model: String,
        apiKey: String,
        tools: [[String: Any]]
    ) async throws -> [String: Any] {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw ChatError.providerNotAvailable
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.timeoutInterval = 90

        var body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "messages": messages,
            "stream": false
        ]
        if !tools.isEmpty {
            body["tools"] = tools
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            coordLogger.error("Anthropic API error \(statusCode): \(errorBody.prefix(200))")
            throw AnthropicError.serverError(status: statusCode, message: errorBody)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AnthropicError.invalidResponse
        }
        return json
    }

    // MARK: - Message Conversion

    private func buildAnthropicMessages(from aiMessages: [AIMessage]) -> [[String: Any]] {
        aiMessages.compactMap { msg -> [String: Any]? in
            guard msg.role != .system else { return nil }
            let role = msg.role == .user ? "user" : "assistant"
            return ["role": role, "content": msg.content.textValue]
        }
    }
}

// MARK: - Tool Definition Helper

extension AnthropicToolCatalog {
    /// Convert ToolDefinitions to the [String: Any] format expected by Anthropic API
    func buildToolsForAPI() -> [[String: Any]] {
        buildToolCatalog().map { tool in
            [
                "name": tool.name,
                "description": tool.description,
                "input_schema": tool.parameters
            ] as [String: Any]
        }
    }
}
