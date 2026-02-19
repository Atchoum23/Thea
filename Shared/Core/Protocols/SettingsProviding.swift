//
//  SettingsProviding.swift
//  Thea
//
//  Protocol abstraction for SettingsManager, enabling testability
//  and dependency injection across 53+ call sites.
//

import Foundation

// MARK: - Settings Providing Protocol

/// Abstracts the read-only query surface of SettingsManager for testability.
///
/// This protocol captures the feature-flag and configuration properties
/// that services read from SettingsManager. It intentionally does NOT
/// include setters — those are UI-driven and remain on SettingsManager directly.
///
/// **What this enables:**
/// - Services can accept `any SettingsProviding` instead of coupling to
///   `SettingsManager.shared`, making them unit-testable with mock settings
/// - Feature flag state can be overridden in tests without touching UserDefaults
/// - The FeatureFlag enum provides a unified, discoverable API for all flags
// periphery:ignore - Reserved: SettingsProviding protocol — reserved for future feature activation
@MainActor
protocol SettingsProviding: AnyObject {

    // MARK: - AI Provider Settings

    var defaultProvider: String { get }
    var streamResponses: Bool { get }
    var preferLocalModels: Bool { get }
    var ollamaEnabled: Bool { get }
    var ollamaURL: String { get }

    // MARK: - Privacy Settings

    var iCloudSyncEnabled: Bool { get }
    var cloudAPIPrivacyGuardEnabled: Bool { get }
    var analyticsEnabled: Bool { get }

    // MARK: - Feature Flags

    var betaFeaturesEnabled: Bool { get }
    var moltbookAgentEnabled: Bool { get }
    var agentDelegationEnabled: Bool { get }
    var clipboardHistoryEnabled: Bool { get }
    var clipboardSyncEnabled: Bool { get }
    var enableSemanticSearch: Bool { get }
    var notificationsEnabled: Bool { get }

    // MARK: - Execution Settings

    var allowCodeExecution: Bool { get }
    var allowFileCreation: Bool { get }
    var allowFileEditing: Bool { get }
    var allowExternalAPICalls: Bool { get }
    var requireDestructiveApproval: Bool { get }

    // MARK: - Debug

    var debugMode: Bool { get }
    var showPerformanceMetrics: Bool { get }

    // MARK: - Feature Flag Query

    /// Unified query for any feature flag by enum case.
    /// Preferred over accessing individual properties when the flag
    /// name is determined at runtime.
    func isFeatureEnabled(_ flag: TheaFeatureFlag) -> Bool
}
