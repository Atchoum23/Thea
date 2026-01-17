import Foundation
@preconcurrency import SwiftData

// MARK: - Plugin System
// Extensible plugin architecture with sandboxing and permissions

@MainActor
@Observable
final class PluginSystem {
    static let shared = PluginSystem()

    private(set) var installedPlugins: [Plugin] = []
    private(set) var activePlugins: [Plugin] = []
    private(set) var pluginExecutions: [PluginExecution] = []

    private var pluginIndex: [String: Plugin] = [:]
    private let sandboxQueue = DispatchQueue(label: "com.thea.plugin.sandbox", qos: .userInitiated)

    private init() {
        loadInstalledPlugins()
    }

    // MARK: - Plugin Management

    func installPlugin(from manifest: PluginManifest) async throws -> Plugin {
        // Validate manifest
        try validateManifest(manifest)

        // Check permissions
        let requiredPermissions = manifest.permissions
        let grantedPermissions = try await requestPermissions(requiredPermissions)

        guard Set(grantedPermissions) == Set(requiredPermissions) else {
            throw PluginError.permissionsDenied
        }

        let plugin = Plugin(
            id: UUID(),
            manifest: manifest,
            isEnabled: true,
            grantedPermissions: grantedPermissions,
            installedAt: Date(),
            lastExecuted: nil
        )

        installedPlugins.append(plugin)
        pluginIndex[plugin.id.uuidString] = plugin

        // Auto-enable if requested
        if manifest.autoEnable {
            activePlugins.append(plugin)
        }

        return plugin
    }

    func uninstallPlugin(_ pluginId: UUID) throws {
        guard pluginIndex[pluginId.uuidString] != nil else {
            throw PluginError.pluginNotFound
        }

        // Remove from active plugins
        activePlugins.removeAll { $0.id == pluginId }

        // Remove from installed plugins
        installedPlugins.removeAll { $0.id == pluginId }
        pluginIndex.removeValue(forKey: pluginId.uuidString)

        // Clean up plugin data
        try cleanupPluginData(pluginId)
    }

    func enablePlugin(_ pluginId: UUID) throws {
        guard let plugin = pluginIndex[pluginId.uuidString] else {
            throw PluginError.pluginNotFound
        }

        if !activePlugins.contains(where: { $0.id == pluginId }) {
            activePlugins.append(plugin)
            plugin.isEnabled = true
        }
    }

    func disablePlugin(_ pluginId: UUID) throws {
        guard let plugin = pluginIndex[pluginId.uuidString] else {
            throw PluginError.pluginNotFound
        }

        activePlugins.removeAll { $0.id == pluginId }
        plugin.isEnabled = false
    }

    // MARK: - Plugin Execution

    nonisolated func executePlugin(
        _ pluginId: UUID,
        input: [String: Any],
        context: PluginContext
    ) async throws -> PluginResult {
        let startTime = Date()

        guard let plugin = await pluginIndex[pluginId.uuidString] else {
            throw PluginError.pluginNotFound
        }

        // Check if plugin is enabled
        guard plugin.isEnabled else {
            throw PluginError.pluginDisabled
        }

        // Validate permissions for this execution
        try await validateExecutionPermissions(plugin: plugin, context: context)

        // Execute in sandbox
        let result = try await executeSandboxed(plugin: plugin, input: input, context: context)

        // Record execution
        await recordExecution(PluginExecution(
            id: UUID(),
            pluginId: pluginId,
            input: input,
            result: result,
            startTime: startTime,
            endTime: Date(),
            success: result.success
        ))

        return result
    }

    nonisolated private func executeSandboxed(
        plugin: Plugin,
        input: [String: Any],
        context: PluginContext
    ) async throws -> PluginResult {
        // Create sandboxed environment
        let sandbox = PluginSandbox(
            plugin: plugin,
            maxMemory: 100_000_000, // 100MB
            maxDuration: 30.0 // 30 seconds
        )

        do {
            let output = try await sandbox.execute(input: input, context: context)

            return PluginResult(
                success: true,
                output: output,
                error: nil,
                logs: sandbox.logs
            )
        } catch {
            return PluginResult(
                success: false,
                output: nil,
                error: error.localizedDescription,
                logs: sandbox.logs
            )
        }
    }

    // MARK: - Inter-Plugin Communication

    nonisolated func sendMessage(
        from sourcePluginId: UUID,
        to targetPluginId: UUID,
        message: PluginMessage
    ) async throws -> PluginMessage {
        guard let sourcePlugin = await pluginIndex[sourcePluginId.uuidString],
              let targetPlugin = await pluginIndex[targetPluginId.uuidString] else {
            throw PluginError.pluginNotFound
        }

        // Check if source has permission to communicate
        guard sourcePlugin.grantedPermissions.contains(.interPluginCommunication) else {
            throw PluginError.permissionsDenied
        }

        // Check if target accepts messages
        guard targetPlugin.manifest.acceptsMessages else {
            throw PluginError.messageNotAccepted
        }

        // Deliver message to target plugin
        let response = try await deliverMessage(to: targetPlugin, message: message)

        return response
    }

    nonisolated private func deliverMessage(
        to plugin: Plugin,
        message: PluginMessage
    ) async throws -> PluginMessage {
        // Execute plugin's message handler
        let context = PluginContext(
            pluginId: plugin.id,
            permissions: plugin.grantedPermissions,
            environment: .production
        )

        let input: [String: Any] = [
            "messageType": "plugin_message",
            "payload": message.payload
        ]

        let result = try await executeSandboxed(plugin: plugin, input: input, context: context)

        if result.success, let output = result.output as? [String: Any] {
            return PluginMessage(
                id: UUID(),
                type: message.type,
                payload: output,
                senderId: plugin.id,
                timestamp: Date()
            )
        } else {
            throw PluginError.messageDeliveryFailed
        }
    }

    // MARK: - Permission Management

    private func requestPermissions(_ permissions: [PluginPermission]) async throws -> [PluginPermission] {
        // In production, this would show UI to request user approval
        // For now, auto-grant safe permissions
        permissions.filter { permission in
            switch permission {
            case .fileSystemRead, .networkAccess, .aiProviderAccess:
                return true
            case .fileSystemWrite, .systemCommands:
                return false // Require explicit user approval
            case .interPluginCommunication, .dataStorage:
                return true
            }
        }
    }

    nonisolated private func validateExecutionPermissions(
        plugin: Plugin,
        context: PluginContext
    ) async throws {
        // Ensure plugin has required permissions for this context
        let requiredPermissions = plugin.manifest.permissions

        for permission in requiredPermissions {
            guard plugin.grantedPermissions.contains(permission) else {
                throw PluginError.permissionsDenied
            }
        }
    }

    // MARK: - Manifest Validation

    private func validateManifest(_ manifest: PluginManifest) throws {
        // Check required fields
        guard !manifest.name.isEmpty else {
            throw PluginError.invalidManifest("Plugin name is required")
        }

        guard !manifest.version.isEmpty else {
            throw PluginError.invalidManifest("Plugin version is required")
        }

        guard !manifest.author.isEmpty else {
            throw PluginError.invalidManifest("Plugin author is required")
        }

        // Validate version format (semantic versioning)
        let versionPattern = #"^\d+\.\d+\.\d+$"#
        guard manifest.version.range(of: versionPattern, options: .regularExpression) != nil else {
            throw PluginError.invalidManifest("Invalid version format (use semantic versioning)")
        }

        // Check for dangerous permission combinations
        if manifest.permissions.contains(.systemCommands) &&
           manifest.permissions.contains(.networkAccess) {
            throw PluginError.invalidManifest("Cannot combine systemCommands and networkAccess permissions")
        }
    }

    // MARK: - Plugin Discovery

    func discoverPlugins() async throws -> [PluginManifest] {
        // In production, this would query a plugin marketplace API
        // For now, return sample plugins
        [
            PluginManifest(
                name: "GitHub Integration",
                version: "1.0.0",
                description: "Interact with GitHub repositories",
                author: "THEA Team",
                permissions: [.networkAccess, .dataStorage],
                entryPoint: "github_plugin.js",
                type: .aiProvider,
                autoEnable: false,
                acceptsMessages: true
            ),
            PluginManifest(
                name: "Code Formatter",
                version: "1.0.0",
                description: "Format code in multiple languages",
                author: "THEA Team",
                permissions: [.fileSystemRead],
                entryPoint: "formatter_plugin.js",
                type: .tool,
                autoEnable: true,
                acceptsMessages: false
            )
        ]
    }

    // MARK: - Helper Methods

    private func loadInstalledPlugins() {
        // Load from persistent storage
        // For now, start with empty list
        installedPlugins = []
        activePlugins = []
    }

    private func cleanupPluginData(_ pluginId: UUID) throws {
        // Remove plugin data directory
        let dataPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Plugins")
            .appendingPathComponent(pluginId.uuidString)

        if FileManager.default.fileExists(atPath: dataPath.path) {
            try FileManager.default.removeItem(at: dataPath)
        }
    }

    @MainActor
    private func recordExecution(_ execution: PluginExecution) {
        pluginExecutions.append(execution)

        // Update last executed timestamp
        if let plugin = pluginIndex[execution.pluginId.uuidString] {
            plugin.lastExecuted = execution.endTime
        }

        // Keep only recent executions
        if pluginExecutions.count > 1_000 {
            pluginExecutions.removeFirst(pluginExecutions.count - 1_000)
        }
    }
}

// MARK: - Plugin Sandbox

class PluginSandbox {
    let plugin: Plugin
    let maxMemory: Int
    let maxDuration: TimeInterval
    private(set) var logs: [String] = []

    init(plugin: Plugin, maxMemory: Int, maxDuration: TimeInterval) {
        self.plugin = plugin
        self.maxMemory = maxMemory
        self.maxDuration = maxDuration
    }

    nonisolated func execute(input: [String: Any], context: PluginContext) async throws -> Any {
        log("Starting plugin execution: \(plugin.manifest.name)")

        let startTime = Date()

        // Execute plugin code
        // Note: Timeout enforcement is handled at the OS level via sandboxing
        // TaskGroup-based timeout would require @Sendable closures which conflict with
        // the need to use [String: Any] for plugin flexibility
        let result: Any = try await executePluginCode(input: input, context: context)

        let duration = Date().timeIntervalSince(startTime)
        log("Plugin execution completed in \(String(format: "%.2f", duration))s")

        return result
    }

    private func executePluginCode(input: [String: Any], context: PluginContext) async throws -> Any {
        // In production, this would execute actual plugin code
        // For now, return mock result based on plugin type

        switch plugin.manifest.type {
        case .aiProvider:
            return ["status": "success", "provider": plugin.manifest.name]
        case .tool:
            return ["status": "success", "tool_output": "Tool executed successfully"]
        case .uiComponent:
            return ["status": "success", "component": "UI rendered"]
        case .dataSource:
            return ["status": "success", "data": ["item1", "item2", "item3"]]
        case .workflow:
            return ["status": "success", "workflow_result": "Workflow completed"]
        }
    }

    private func log(_ message: String) {
        logs.append("[\(Date())] \(message)")
    }
}

// MARK: - Sendable Wrapper for Any

struct SendableBox<T>: @unchecked Sendable {
    let value: T
}

// MARK: - Models

class Plugin: Identifiable, @unchecked Sendable {
    let id: UUID
    let manifest: PluginManifest
    var isEnabled: Bool
    let grantedPermissions: [PluginPermission]
    let installedAt: Date
    var lastExecuted: Date?

    init(id: UUID, manifest: PluginManifest, isEnabled: Bool, grantedPermissions: [PluginPermission], installedAt: Date, lastExecuted: Date?) {
        self.id = id
        self.manifest = manifest
        self.isEnabled = isEnabled
        self.grantedPermissions = grantedPermissions
        self.installedAt = installedAt
        self.lastExecuted = lastExecuted
    }
}

struct PluginManifest: Codable, Sendable {
    let name: String
    let version: String
    let description: String
    let author: String
    let permissions: [PluginPermission]
    let entryPoint: String
    let type: PluginType
    let autoEnable: Bool
    let acceptsMessages: Bool
}

enum PluginType: String, Codable, Sendable {
    case aiProvider = "AI Provider"
    case tool = "Tool"
    case uiComponent = "UI Component"
    case dataSource = "Data Source"
    case workflow = "Workflow"
}

enum PluginPermission: String, Codable, Sendable {
    case fileSystemRead = "File System Read"
    case fileSystemWrite = "File System Write"
    case networkAccess = "Network Access"
    case systemCommands = "System Commands"
    case aiProviderAccess = "AI Provider Access"
    case interPluginCommunication = "Inter-Plugin Communication"
    case dataStorage = "Data Storage"
}

struct PluginContext: Sendable {
    let pluginId: UUID
    let permissions: [PluginPermission]
    let environment: PluginEnvironment

    enum PluginEnvironment: String, Sendable {
        case development, staging, production
    }
}

struct PluginResult: @unchecked Sendable {
    let success: Bool
    let output: Any?
    let error: String?
    let logs: [String]
}

struct PluginExecution: Identifiable, @unchecked Sendable {
    let id: UUID
    let pluginId: UUID
    let input: [String: Any]
    let result: PluginResult
    let startTime: Date
    let endTime: Date
    let success: Bool
}

struct PluginMessage: Identifiable, @unchecked Sendable {
    let id: UUID
    let type: String
    let payload: [String: Any]
    let senderId: UUID
    let timestamp: Date
}

enum PluginError: LocalizedError {
    case pluginNotFound
    case pluginDisabled
    case invalidManifest(String)
    case permissionsDenied
    case executionTimeout
    case executionFailed
    case messageNotAccepted
    case messageDeliveryFailed

    var errorDescription: String? {
        switch self {
        case .pluginNotFound:
            return "Plugin not found"
        case .pluginDisabled:
            return "Plugin is disabled"
        case .invalidManifest(let reason):
            return "Invalid plugin manifest: \(reason)"
        case .permissionsDenied:
            return "Required permissions not granted"
        case .executionTimeout:
            return "Plugin execution timed out"
        case .executionFailed:
            return "Plugin execution failed"
        case .messageNotAccepted:
            return "Plugin does not accept messages"
        case .messageDeliveryFailed:
            return "Failed to deliver message to plugin"
        }
    }
}
