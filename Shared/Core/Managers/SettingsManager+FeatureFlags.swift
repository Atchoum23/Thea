//
//  SettingsManager+TheaFeatureFlags.swift
//  Thea
//
//  Extension adding unified TheaFeatureFlag query support to SettingsManager.
//  Maps TheaFeatureFlag enum cases to their corresponding @Published properties.
//

import Foundation

extension SettingsManager {

    /// Query whether a feature flag is enabled.
    ///
    /// Provides a unified API for runtime feature-flag queries, mapping each
    /// `TheaFeatureFlag` case to its corresponding `@Published` property.
    ///
    /// Usage:
    /// ```swift
    /// if SettingsManager.shared.isFeatureEnabled(.localModels) {
    ///     // Use local model inference
    /// }
    /// ```
    func isFeatureEnabled(_ flag: TheaFeatureFlag) -> Bool {
        switch flag {
        // AI & Models
        case .localModels: return preferLocalModels
        case .ollama: return ollamaEnabled
        case .semanticSearch: return enableSemanticSearch
        case .streamingResponses: return streamResponses

        // Privacy & Sync
        case .cloudSync: return iCloudSyncEnabled
        case .cloudPrivacyGuard: return cloudAPIPrivacyGuardEnabled
        case .analytics: return analyticsEnabled
        case .clipboardSync: return clipboardSyncEnabled

        // Agent & Autonomy
        case .agentMode: return agentDelegationEnabled
        case .moltbookAgent: return moltbookAgentEnabled

        // Features
        case .betaFeatures: return betaFeaturesEnabled
        case .clipboardHistory: return clipboardHistoryEnabled
        case .notifications: return notificationsEnabled

        // Execution Permissions
        case .codeExecution: return allowCodeExecution
        case .fileCreation: return allowFileCreation
        case .fileEditing: return allowFileEditing
        case .externalAPICalls: return allowExternalAPICalls
        case .destructiveApproval: return requireDestructiveApproval

        // Debug
        case .debugMode: return debugMode
        case .performanceMetrics: return showPerformanceMetrics
        }
    }

    /// Set a feature flag's value programmatically.
    ///
    /// Useful for bulk operations, test setup, or applying feature flag
    /// configurations from a remote source.
    func setFeatureEnabled(_ flag: TheaFeatureFlag, enabled: Bool) {
        switch flag {
        case .localModels: preferLocalModels = enabled
        case .ollama: ollamaEnabled = enabled
        case .semanticSearch: enableSemanticSearch = enabled
        case .streamingResponses: streamResponses = enabled
        case .cloudSync: iCloudSyncEnabled = enabled
        case .cloudPrivacyGuard: cloudAPIPrivacyGuardEnabled = enabled
        case .analytics: analyticsEnabled = enabled
        case .clipboardSync: clipboardSyncEnabled = enabled
        case .agentMode: agentDelegationEnabled = enabled
        case .moltbookAgent: moltbookAgentEnabled = enabled
        case .betaFeatures: betaFeaturesEnabled = enabled
        case .clipboardHistory: clipboardHistoryEnabled = enabled
        case .notifications: notificationsEnabled = enabled
        case .codeExecution: allowCodeExecution = enabled
        case .fileCreation: allowFileCreation = enabled
        case .fileEditing: allowFileEditing = enabled
        case .externalAPICalls: allowExternalAPICalls = enabled
        case .destructiveApproval: requireDestructiveApproval = enabled
        case .debugMode: debugMode = enabled
        case .performanceMetrics: showPerformanceMetrics = enabled
        }
    }

    /// Returns a snapshot of all feature flag states for diagnostics.
    var featureFlagSnapshot: [TheaFeatureFlag: Bool] {
        var snapshot: [TheaFeatureFlag: Bool] = [:]
        for flag in TheaFeatureFlag.allCases {
            snapshot[flag] = isFeatureEnabled(flag)
        }
        return snapshot
    }

    /// Returns all enabled feature flags.
    var enabledTheaFeatureFlags: [TheaFeatureFlag] {
        TheaFeatureFlag.allCases.filter { isFeatureEnabled($0) }
    }

    /// Reset a feature flag to its default value.
    func resetTheaFeatureFlag(_ flag: TheaFeatureFlag) {
        setFeatureEnabled(flag, enabled: flag.defaultValue)
    }

    /// Reset all feature flags to their default values.
    func resetAllTheaFeatureFlags() {
        for flag in TheaFeatureFlag.allCases {
            resetTheaFeatureFlag(flag)
        }
    }
}
