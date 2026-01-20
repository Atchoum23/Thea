//
//  AppIntegrationModule.swift
//  Thea
//
//  Created by Claude Code on 2026-01-20
//  Copyright © 2026. All rights reserved.
//

import Foundation

// MARK: - Integration Module Protocol

/// Protocol for all integration modules
public protocol AppIntegrationModule: Actor {
    /// Unique module identifier
    var moduleId: String { get }

    /// Display name for UI
    var displayName: String { get }

    /// Bundle identifier of the integrated app
    var bundleIdentifier: String { get }

    /// SF Symbol icon name
    var icon: String { get }

    /// Connect to the integrated application
    func connect() async throws

    /// Disconnect from the integrated application
    func disconnect() async

    /// Check if the integration is available
    func isAvailable() async -> Bool
}

// MARK: - Integration Module Error

public enum AppIntegrationModuleError: Error, LocalizedError, Sendable {
    case notSupported
    case appNotRunning(String)
    case appNotInstalled(String)
    case permissionDenied(String)
    case connectionFailed(String)
    case scriptError(String)
    case operationFailed(String)
    case timeout
    case invalidInput(String)

    public var errorDescription: String? {
        switch self {
        case .notSupported:
            return "This integration is not supported on this platform"
        case .appNotRunning(let app):
            return "\(app) is not running"
        case .appNotInstalled(let app):
            return "\(app) is not installed"
        case .permissionDenied(let reason):
            return "Permission denied: \(reason)"
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        case .scriptError(let reason):
            return "Script error: \(reason)"
        case .operationFailed(let reason):
            return "Operation failed: \(reason)"
        case .timeout:
            return "Operation timed out"
        case .invalidInput(let reason):
            return "Invalid input: \(reason)"
        }
    }
}

// MARK: - Integration Registry

/// Central registry for all integration modules
public actor IntegrationRegistry {
    public static let shared = IntegrationRegistry()

    // MARK: - State

    private var modules: [String: any AppIntegrationModule] = [:]
    private var activeConnections: Set<String> = []

    // MARK: - Initialization

    private init() {
        // Default modules are registered lazily on first access
    }

    /// Initialize and register default modules
    public func initializeDefaultModules() async {
        // Register built-in modules
        await registerModule(SafariIntegration.shared)
        await registerModule(FinderIntegration.shared)
        await registerModule(MailIntegration.shared)
        await registerModule(CalendarIntegration.shared)
        await registerModule(NotesIntegration.shared)
        await registerModule(RemindersIntegration.shared)
        await registerModule(MessagesIntegration.shared)
        await registerModule(MusicIntegration.shared)
        await registerModule(TerminalIntegration.shared)
        await registerModule(XcodeIntegration.shared)
        await registerModule(SystemIntegration.shared)
        await registerModule(ShortcutsIntegration.shared)
    }

    private func registerModule(_ module: any AppIntegrationModule) async {
        let moduleId = await module.moduleId
        modules[moduleId] = module
    }

    // MARK: - Registration

    /// Register an integration module
    public func register(_ module: any AppIntegrationModule) async {
        let moduleId = await module.moduleId
        modules[moduleId] = module
    }

    /// Unregister an integration module
    public func unregister(_ moduleId: String) {
        modules.removeValue(forKey: moduleId)
        activeConnections.remove(moduleId)
    }

    // MARK: - Module Access

    /// Get a module by ID
    public func getModule(_ moduleId: String) -> (any AppIntegrationModule)? {
        modules[moduleId]
    }

    /// Get all registered modules
    public func getAllModules() -> [any AppIntegrationModule] {
        Array(modules.values)
    }

    /// Get available modules
    public func getAvailableModules() async -> [any AppIntegrationModule] {
        var available: [any AppIntegrationModule] = []
        for module in modules.values {
            if await module.isAvailable() {
                available.append(module)
            }
        }
        return available
    }

    // MARK: - Connection Management

    /// Connect to a module
    public func connect(_ moduleId: String) async throws {
        guard let module = modules[moduleId] else {
            throw AppIntegrationModuleError.operationFailed("Module not found: \(moduleId)")
        }

        try await module.connect()
        activeConnections.insert(moduleId)
    }

    /// Disconnect from a module
    public func disconnect(_ moduleId: String) async {
        guard let module = modules[moduleId] else { return }
        await module.disconnect()
        activeConnections.remove(moduleId)
    }

    /// Disconnect all modules
    public func disconnectAll() async {
        for moduleId in activeConnections {
            await disconnect(moduleId)
        }
    }

    /// Check if a module is connected
    public func isConnected(_ moduleId: String) -> Bool {
        activeConnections.contains(moduleId)
    }

    /// Get active connections
    public func getActiveConnections() -> Set<String> {
        activeConnections
    }
}

// MARK: - Integration Manager

/// High-level manager for orchestrating integrations
@MainActor
@Observable
public final class IntegrationManager {
    public static let shared = IntegrationManager()

    // MARK: - State

    public private(set) var availableModules: [ModuleInfo] = []
    public private(set) var activeModules: Set<String> = []
    public private(set) var isRefreshing = false

    // MARK: - Initialization

    private init() {}

    // MARK: - Refresh

    /// Refresh available modules
    public func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        let registry = IntegrationRegistry.shared
        let modules = await registry.getAllModules()

        var infos: [ModuleInfo] = []
        for module in modules {
            let moduleId = await module.moduleId
            let displayName = await module.displayName
            let icon = await module.icon
            let isAvailable = await module.isAvailable()
            let isConnected = await registry.isConnected(moduleId)

            infos.append(ModuleInfo(
                id: moduleId,
                displayName: displayName,
                icon: icon,
                isAvailable: isAvailable,
                isConnected: isConnected
            ))
        }

        availableModules = infos.sorted { $0.displayName < $1.displayName }
        activeModules = await registry.getActiveConnections()
    }

    /// Toggle module connection
    public func toggleModule(_ moduleId: String) async throws {
        let registry = IntegrationRegistry.shared

        if await registry.isConnected(moduleId) {
            await registry.disconnect(moduleId)
            activeModules.remove(moduleId)
        } else {
            try await registry.connect(moduleId)
            activeModules.insert(moduleId)
        }

        await refresh()
    }
}

// MARK: - Module Info

public struct ModuleInfo: Identifiable, Sendable {
    public let id: String
    public let displayName: String
    public let icon: String
    public let isAvailable: Bool
    public let isConnected: Bool
}
