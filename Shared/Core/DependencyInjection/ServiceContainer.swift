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

}
