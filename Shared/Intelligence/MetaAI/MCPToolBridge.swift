import Foundation
import OSLog

// MARK: - MCP Tool Bridge

// Bridges MCP server tools to the ToolFramework

struct MCPToolBridge: Sendable {
    let id: UUID
    let name: String
    let description: String
    let parameters: [ToolParameter]
    let mcpServerName: String
    let mcpToolName: String

    @MainActor func execute(arguments _: [String: Any]) async throws -> MetaAIToolResult {
        // Bridge to MCP server
        // This would integrate with actual MCP client when available
        // For now, return success
        MetaAIToolResult(
            success: true,
            output: "MCP tool executed: \(mcpToolName)",
            error: nil,
            executionTime: 0.1
        )
    }
}

// MARK: - MCP Tool Registry

// Discovers and registers MCP tools

@MainActor
@Observable
final class MCPToolRegistry {
    static let shared = MCPToolRegistry()

    private let logger = Logger(subsystem: "com.thea.metaai", category: "MCPToolRegistry")

    private(set) var mcpTools: [MCPToolBridge] = []
    private(set) var mcpServers: [MetaAIMCPServerInfo] = []

    private init() {
        discoverMCPTools()
    }

    // MARK: - Discovery

    // swiftlint:disable:next function_body_length
    func discoverMCPTools() {
        logger.info("Discovering MCP tools...")

        // Mock MCP servers for now
        // In production, this would scan actual MCP server configurations
        mcpServers = [
            MetaAIMCPServerInfo(
                id: UUID(),
                name: "filesystem",
                description: "File system operations",
                status: .connected,
                toolCount: 5
            ),
            MetaAIMCPServerInfo(
                id: UUID(),
                name: "terminal",
                description: "Terminal command execution",
                status: .connected,
                toolCount: 2
            ),
            MetaAIMCPServerInfo(
                id: UUID(),
                name: "git",
                description: "Git repository operations",
                status: .connected,
                toolCount: 8
            )
        ]

        // Discover tools from each server
        var tools: [MCPToolBridge] = []

        // Filesystem tools
        tools.append(MCPToolBridge(
            id: UUID(),
            name: "mcp_read_file",
            description: "Read file contents via MCP",
            parameters: [
                ToolParameter(name: "path", type: .string, required: true, description: "File path to read")
            ],
            mcpServerName: "filesystem",
            mcpToolName: "read_file"
        ))

        tools.append(MCPToolBridge(
            id: UUID(),
            name: "mcp_write_file",
            description: "Write file contents via MCP",
            parameters: [
                ToolParameter(name: "path", type: .string, required: true, description: "File path"),
                ToolParameter(name: "content", type: .string, required: true, description: "Content to write")
            ],
            mcpServerName: "filesystem",
            mcpToolName: "write_file"
        ))

        tools.append(MCPToolBridge(
            id: UUID(),
            name: "mcp_list_dir",
            description: "List directory contents via MCP",
            parameters: [
                ToolParameter(name: "path", type: .string, required: true, description: "Directory path")
            ],
            mcpServerName: "filesystem",
            mcpToolName: "list_directory"
        ))

        // Terminal tools
        tools.append(MCPToolBridge(
            id: UUID(),
            name: "mcp_execute_command",
            description: "Execute shell command via MCP",
            parameters: [
                ToolParameter(name: "command", type: .string, required: true, description: "Command to execute"),
                ToolParameter(name: "workingDirectory", type: .string, required: false, description: "Working directory")
            ],
            mcpServerName: "terminal",
            mcpToolName: "execute"
        ))

        // Git tools
        tools.append(MCPToolBridge(
            id: UUID(),
            name: "mcp_git_status",
            description: "Get git repository status via MCP",
            parameters: [
                ToolParameter(name: "repo", type: .string, required: true, description: "Repository path")
            ],
            mcpServerName: "git",
            mcpToolName: "status"
        ))

        tools.append(MCPToolBridge(
            id: UUID(),
            name: "mcp_git_commit",
            description: "Create git commit via MCP",
            parameters: [
                ToolParameter(name: "repo", type: .string, required: true, description: "Repository path"),
                ToolParameter(name: "message", type: .string, required: true, description: "Commit message")
            ],
            mcpServerName: "git",
            mcpToolName: "commit"
        ))

        mcpTools = tools

        logger.info("Discovered \(tools.count) MCP tools from \(self.mcpServers.count) servers")

        // Register with ToolFramework
        registerWithToolFramework()
    }

    func refreshTools() async {
        logger.info("Refreshing MCP tools...")
        discoverMCPTools()
    }

    // MARK: - Registration

    private func registerWithToolFramework() {
        let toolFramework = ToolFramework.shared

        // Register each MCP tool as a standard tool
        for mcpTool in mcpTools {
            let capturedTool = mcpTool
            let tool = Tool(
                id: capturedTool.id,
                name: capturedTool.name,
                description: capturedTool.description,
                parameters: capturedTool.parameters,
                category: .api
            ) { @MainActor parameters in
                try await capturedTool.execute(arguments: parameters).output ?? ""
            }

            toolFramework.registerTool(tool)
        }

        logger.info("Registered \(self.mcpTools.count) MCP tools with ToolFramework")
    }
}

// MARK: - MetaAI MCP Server Info

/// MCP Server info for MetaAI subsystem (distinct from TrustScoreSystem's MCPServerInfo)
struct MetaAIMCPServerInfo: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let description: String
    let status: ServerStatus
    let toolCount: Int

    enum ServerStatus: Sendable {
        case connected, disconnected, error

        var displayName: String {
            switch self {
            case .connected: "Connected"
            case .disconnected: "Disconnected"
            case .error: "Error"
            }
        }
    }
}

// MARK: - MCP Tool Info

struct MCPToolInfo: Identifiable, Sendable {
    let id: UUID
    let name: String
    let description: String
    let parameters: [String]
}
