//
//  ServiceContainer.swift
//  Thea
//
//  Created by Claude Code on 2026-02-01
//  Dependency Injection Container for centralized service management
//

import Foundation
import SwiftUI

// MARK: - Service Container

/// Centralized container for managing app-wide services
/// Use @Environment(\.serviceContainer) in views to access services
@MainActor
final class ServiceContainer: ObservableObject {
    static let shared = ServiceContainer()

    // MARK: - Core Services

    /// Chat and conversation management
    private(set) lazy var chatManager: ChatManager = .shared

    /// Application settings
    private(set) lazy var settingsManager: SettingsManager = .shared

    /// AI provider registry
    private(set) lazy var providerRegistry: ProviderRegistry = .shared

    /// App configuration
    private(set) lazy var appConfiguration: AppConfiguration = .shared

    // MARK: - Integration Services

    #if os(macOS)
    /// MCP server management (macOS only)
    private(set) lazy var mcpServerManager: MCPServerManager = .shared
    #endif

    /// Backup management
    private(set) lazy var backupManager: BackupManager = .shared

    /// Activity logging
    private(set) lazy var activityLogger: ActivityLogger = .shared

    // MARK: - Initialization

    private init() {}

    /// Initialize with custom services (for testing)
    init(
        chatManager: ChatManager? = nil,
        settingsManager: SettingsManager? = nil,
        providerRegistry: ProviderRegistry? = nil
    ) {
        if let chatManager { self.chatManager = chatManager }
        if let settingsManager { self.settingsManager = settingsManager }
        if let providerRegistry { self.providerRegistry = providerRegistry }
    }
}

// MARK: - Environment Keys

/// Environment key for ServiceContainer using Swift 6 concurrency pattern
private struct ServiceContainerKey: @preconcurrency EnvironmentKey {
    @MainActor static var defaultValue: ServiceContainer { ServiceContainer.shared }
}

/// Environment key for ChatManager
private struct ChatManagerKey: @preconcurrency EnvironmentKey {
    @MainActor static var defaultValue: ChatManager { ChatManager.shared }
}

/// Environment key for SettingsManager
private struct SettingsManagerKey: @preconcurrency EnvironmentKey {
    @MainActor static var defaultValue: SettingsManager { SettingsManager.shared }
}

/// Environment key for ProviderRegistry
private struct ProviderRegistryKey: @preconcurrency EnvironmentKey {
    @MainActor static var defaultValue: ProviderRegistry { ProviderRegistry.shared }
}

/// Environment key for AppConfiguration
private struct AppConfigurationKey: @preconcurrency EnvironmentKey {
    @MainActor static var defaultValue: AppConfiguration { AppConfiguration.shared }
}

// MARK: - EnvironmentValues Extensions

extension EnvironmentValues {
    /// Access the service container via @Environment(\.serviceContainer)
    @MainActor
    var serviceContainer: ServiceContainer {
        get { self[ServiceContainerKey.self] }
        set { self[ServiceContainerKey.self] = newValue }
    }

    /// Access ChatManager via @Environment(\.chatManager)
    @MainActor
    var chatManager: ChatManager {
        get { self[ChatManagerKey.self] }
        set { self[ChatManagerKey.self] = newValue }
    }

    /// Access SettingsManager via @Environment(\.settingsManager)
    @MainActor
    var settingsManager: SettingsManager {
        get { self[SettingsManagerKey.self] }
        set { self[SettingsManagerKey.self] = newValue }
    }

    /// Access ProviderRegistry via @Environment(\.providerRegistry)
    @MainActor
    var providerRegistry: ProviderRegistry {
        get { self[ProviderRegistryKey.self] }
        set { self[ProviderRegistryKey.self] = newValue }
    }

    /// Access AppConfiguration via @Environment(\.appConfiguration)
    @MainActor
    var appConfiguration: AppConfiguration {
        get { self[AppConfigurationKey.self] }
        set { self[AppConfigurationKey.self] = newValue }
    }
}

// MARK: - View Extension for Easy Injection

extension View {
    /// Inject the service container into the view hierarchy
    /// Use at the root of your app to make services available to all child views
    @MainActor
    func withServiceContainer(_ container: ServiceContainer = .shared) -> some View {
        self.environment(\.serviceContainer, container)
            .environment(\.chatManager, container.chatManager)
            .environment(\.settingsManager, container.settingsManager)
            .environment(\.providerRegistry, container.providerRegistry)
            .environment(\.appConfiguration, container.appConfiguration)
    }
}
