// THEAMCPServer.swift
// Thea V2
//
// MCP Server implementation that exposes Thea's capabilities
// Allows Claude Desktop and other MCP clients to use Thea's tools

import Foundation
import OSLog

#if os(macOS)

// MARK: - Thea MCP Server

/// MCP Server that exposes Thea's capabilities
public actor THEAMCPServer {
    public static let shared = THEAMCPServer()

    private let logger = Logger(subsystem: "com.thea.mcp", category: "Server")

    private var isRunning = false
    private var inputHandle: FileHandle?
    private var outputHandle: FileHandle?

    private let serverInfo = THEAMCPProtocolInfo(name: "thea", version: "2.0.0")

    private init() {}

    // MARK: - Server Lifecycle

    /// Start the MCP server (stdio mode)
    public func start() async {
        guard !isRunning else {
            logger.warning("Server already running")
            return
        }

        isRunning = true
        inputHandle = FileHandle.standardInput
        outputHandle = FileHandle.standardOutput

        logger.info("THEA MCP Server started")

        // Process incoming messages
        await processMessages()
    }

    /// Stop the MCP server
    public func stop() {
        isRunning = false
        inputHandle = nil
        outputHandle = nil
        logger.info("THEA MCP Server stopped")
    }

    // MARK: - Message Processing

    private func processMessages() async {
        guard let inputHandle = inputHandle else { return }

        while isRunning {
            do {
                // Read line-delimited JSON
                if let data = try await readMessage(from: inputHandle),
                   !data.isEmpty {
                    let request = try JSONDecoder().decode(THEAMCPRequest.self, from: data)
                    let response = await handleRequest(request)

                    try await sendResponse(response)
                }
            } catch {
                logger.error("Message processing error: \(error.localizedDescription)")
            }
        }
    }

    private func readMessage(from handle: FileHandle) async throws -> Data? {
        // Read until newline
        var buffer = Data()
        while isRunning {
            let byte = handle.readData(ofLength: 1)
            if byte.isEmpty {
                try await Task.sleep(nanoseconds: 10_000_000)  // 10ms
                continue
            }
            if byte[0] == 0x0A {  // newline
                break
            }
            buffer.append(byte)
        }
        return buffer.isEmpty ? nil : buffer
    }

    private func sendResponse(_ response: THEAMCPResponse) async throws {
        guard let outputHandle = outputHandle else { return }

        let data = try JSONEncoder().encode(response)
        outputHandle.write(data)
        outputHandle.write(Data([0x0A]))  // newline
    }

    // MARK: - Request Handling

    private func handleRequest(_ request: THEAMCPRequest) async -> THEAMCPResponse {
        logger.debug("Handling request: \(request.method)")

        switch request.method {
        case "initialize":
            return handleInitialize(request)
        case "tools/list":
            return handleToolsList(request)
        case "tools/call":
            return await handleToolsCall(request)
        case "resources/list":
            return handleResourcesList(request)
        case "resources/read":
            return await handleResourcesRead(request)
        case "ping":
            return handlePing(request)
        default:
            return THEAMCPResponse(id: request.id, error: .methodNotFound)
        }
    }

    private func handleInitialize(_ request: THEAMCPRequest) -> THEAMCPResponse {
        var result = THEAMCPResult()
        result.protocolVersion = "2024-11-05"
        result.capabilities = THEAMCPCapabilities(
            tools: THEAMCPToolCapability(listChanged: true),
            resources: THEAMCPResourceCapability(subscribe: false, listChanged: true)
        )
        result.serverInfo = serverInfo
        return THEAMCPResponse(id: request.id, result: result)
    }

    private func handleToolsList(_ request: THEAMCPRequest) -> THEAMCPResponse {
        var result = THEAMCPResult()
        result.tools = getAvailableTools()
        return THEAMCPResponse(id: request.id, result: result)
    }

    private func handleToolsCall(_ request: THEAMCPRequest) async -> THEAMCPResponse {
        guard let params = request.params,
              let toolName = params.name else {
            return THEAMCPResponse(id: request.id, error: .invalidParams)
        }

        do {
            let content = try await executeTool(name: toolName, arguments: params.arguments ?? [:])

            // Sanitize tool responses through OutboundPrivacyGuard
            var sanitizedContent: [THEAMCPContent] = []
            for item in content {
                if let text = item.text {
                    let outcome = await OutboundPrivacyGuard.shared.sanitize(text, channel: "mcp")
                    if let sanitizedText = outcome.content {
                        sanitizedContent.append(.text(sanitizedText))
                    }
                } else {
                    sanitizedContent.append(item)
                }
            }

            var result = THEAMCPResult()
            result.content = sanitizedContent
            return THEAMCPResponse(id: request.id, result: result)
        } catch {
            var result = THEAMCPResult()
            result.content = [.text("Error: \(error.localizedDescription)")]
            result.isError = true
            return THEAMCPResponse(id: request.id, result: result)
        }
    }

    private func handleResourcesList(_ request: THEAMCPRequest) -> THEAMCPResponse {
        var result = THEAMCPResult()
        result.resources = getAvailableResources()
        return THEAMCPResponse(id: request.id, result: result)
    }

    private func handleResourcesRead(_ request: THEAMCPRequest) async -> THEAMCPResponse {
        guard let params = request.params,
              let uri = params.uri else {
            return THEAMCPResponse(id: request.id, error: .invalidParams)
        }

        do {
            let content = try await readResource(uri: uri)
            var result = THEAMCPResult()
            result.content = content
            return THEAMCPResponse(id: request.id, result: result)
        } catch {
            return THEAMCPResponse(id: request.id, error: THEAMCPError(code: -32000, message: error.localizedDescription))
        }
    }

    private func handlePing(_ request: THEAMCPRequest) -> THEAMCPResponse {
        let result = THEAMCPResult()
        return THEAMCPResponse(id: request.id, result: result)
    }

}

#endif
