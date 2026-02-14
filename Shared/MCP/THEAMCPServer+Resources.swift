// THEAMCPServer+Resources.swift
// Thea V2
//
// Resource definitions and reading for the MCP server
// Extracted from THEAMCPServer.swift

import Foundation

#if os(macOS)

// MARK: - Resource Definitions & Reading

extension THEAMCPServer {
    func getAvailableResources() -> [THEAMCPResourceDefinition] {
        [
            THEAMCPResourceDefinition(
                uri: "thea://system/info",
                name: "System Information",
                description: "Current system status and capabilities",
                mimeType: "application/json"
            ),
            THEAMCPResourceDefinition(
                uri: "thea://models/local",
                name: "Local Models",
                description: "Available local ML models",
                mimeType: "application/json"
            ),
            THEAMCPResourceDefinition(
                uri: "thea://context/current",
                name: "Current Context",
                description: "Current user context including calendar, location, etc.",
                mimeType: "application/json"
            )
        ]
    }

    func readResource(uri: String) async throws -> [THEAMCPContent] {
        switch uri {
        case "thea://system/info":
            let info = """
            {
                "name": "Thea",
                "version": "2.0.0",
                "platform": "macOS",
                "capabilities": ["contacts", "reminders", "notes", "maps", "voice", "automation"]
            }
            """
            return [.text(info)]

        case "thea://models/local":
            let models = await MLXModelManager.shared.scannedModels
            let modelList = models.map { "- \($0.name) (\($0.format))" }.joined(separator: "\n")
            return [.text("Local models:\n\(modelList)")]

        case "thea://context/current":
            let context = """
            {
                "timestamp": "\(ISO8601DateFormatter().string(from: Date()))",
                "platform": "macOS"
            }
            """
            return [.text(context)]

        default:
            throw THEAMCPToolError.executionFailed("Unknown resource: \(uri)")
        }
    }
}

#endif
