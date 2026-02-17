// SettingsManager+SettingsProviding.swift
// Thea V4 — SettingsProviding protocol conformance
//
// Bridges SettingsManager to the SettingsProviding protocol, enabling
// dependency injection and testability for services that consume settings.
//
// DIP violation fix: services like ChatManager, PostResponsePipeline, and
// ProviderRegistry can now depend on `any SettingsProviding` instead of
// coupling directly to `SettingsManager.shared`.

import Foundation

// MARK: - Protocol Conformance

extension SettingsManager: SettingsProviding {

    /// Unified query for any feature flag by enum case.
    func isFeatureEnabled(_ flag: FeatureFlag) -> Bool {
        switch flag {
        // AI & Models
        case .localModels:
            preferLocalModels
        case .ollama:
            ollamaEnabled
        case .semanticSearch:
            enableSemanticSearch
        case .streamingResponses:
            streamResponses

        // Privacy & Sync
        case .cloudSync:
            iCloudSyncEnabled
        case .cloudPrivacyGuard:
            cloudAPIPrivacyGuardEnabled
        case .analytics:
            analyticsEnabled
        case .clipboardSync:
            clipboardSyncEnabled

        // Agent & Autonomy
        case .agentMode:
            agentDelegationEnabled
        case .moltbookAgent:
            moltbookAgentEnabled

        // Features
        case .betaFeatures:
            betaFeaturesEnabled
        case .clipboardHistory:
            clipboardHistoryEnabled
        case .notifications:
            notificationsEnabled

        // Execution Permissions
        case .codeExecution:
            allowCodeExecution
        case .fileCreation:
            allowFileCreation
        case .fileEditing:
            allowFileEditing
        case .externalAPICalls:
            allowExternalAPICalls
        case .destructiveApproval:
            requireDestructiveApproval

        // Debug
        case .debugMode:
            debugMode
        case .performanceMetrics:
            showPerformanceMetrics
        }
    }
}
