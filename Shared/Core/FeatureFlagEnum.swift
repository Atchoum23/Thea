//
//  FeatureFlags.swift
//  Thea
//
//  Unified feature flag system for runtime capability gating.
//  Backed by UserDefaults through SettingsManager for persistence.
//

import Foundation

// MARK: - Feature Flag Enum

/// Unified, discoverable enumeration of all feature flags in Thea.
///
/// Each case maps to a `@Published` property on SettingsManager and a
/// UserDefaults key. Services should query flags via
/// `SettingsManager.shared.isFeatureEnabled(.localModels)` rather than
/// directly accessing individual boolean properties, especially when
/// the flag is determined at runtime (e.g., from a configuration file).
///
/// **Adding a new flag:**
/// 1. Add a case here with a descriptive name
/// 2. Add a corresponding `@Published var` on SettingsManager
/// 3. Add the mapping in `SettingsManager.isFeatureEnabled(_:)`
/// 4. Add it to the FeatureFlag metadata (description, category, defaultValue)
enum TheaFeatureFlag: String, CaseIterable, Sendable {

// periphery:ignore - Reserved: TheaFeatureFlag type reserved for future feature activation

    // MARK: - AI & Models
    case localModels = "preferLocalModels"
    case ollama = "ollamaEnabled"
    case semanticSearch = "enableSemanticSearch"
    case streamingResponses = "streamResponses"

    // MARK: - Privacy & Sync
    case cloudSync = "iCloudSyncEnabled"
    case cloudPrivacyGuard = "cloudAPIPrivacyGuardEnabled"
    case analytics = "analyticsEnabled"
    case clipboardSync = "clipboardSyncEnabled"

    // MARK: - Agent & Autonomy
    case agentMode = "agentDelegationEnabled"
    case moltbookAgent = "moltbookAgentEnabled"

    // MARK: - Features
    case betaFeatures = "betaFeaturesEnabled"
    case clipboardHistory = "clipboardHistoryEnabled"
    case notifications = "notificationsEnabled"

    // MARK: - Execution Permissions
    case codeExecution = "allowCodeExecution"
    case fileCreation = "allowFileCreation"
    case fileEditing = "allowFileEditing"
    case externalAPICalls = "allowExternalAPICalls"
    case destructiveApproval = "requireDestructiveApproval"

    // MARK: - Debug
    case debugMode = "debugMode"
    case performanceMetrics = "showPerformanceMetrics"

    // MARK: - Metadata

    /// The UserDefaults key backing this flag
    var defaultsKey: String { rawValue }

    /// Human-readable description for settings UI
    var displayName: String {
        switch self {
        case .localModels: return "Local Models"
        case .ollama: return "Ollama Integration"
        case .semanticSearch: return "Semantic Search"
        case .streamingResponses: return "Streaming Responses"
        case .cloudSync: return "iCloud Sync"
        case .cloudPrivacyGuard: return "Cloud Privacy Guard"
        case .analytics: return "Analytics"
        case .clipboardSync: return "Clipboard Sync"
        case .agentMode: return "Agent Delegation"
        case .moltbookAgent: return "Moltbook Agent"
        case .betaFeatures: return "Beta Features"
        case .clipboardHistory: return "Clipboard History"
        case .notifications: return "Notifications"
        case .codeExecution: return "Code Execution"
        case .fileCreation: return "File Creation"
        case .fileEditing: return "File Editing"
        case .externalAPICalls: return "External API Calls"
        case .destructiveApproval: return "Destructive Action Approval"
        case .debugMode: return "Debug Mode"
        case .performanceMetrics: return "Performance Metrics"
        }
    }

    /// Category for grouping in UI
    var category: FlagCategory {
        switch self {
        case .localModels, .ollama, .semanticSearch, .streamingResponses:
            return .aiModels
        case .cloudSync, .cloudPrivacyGuard, .analytics, .clipboardSync:
            return .privacySync
        case .agentMode, .moltbookAgent:
            return .agentAutonomy
        case .betaFeatures, .clipboardHistory, .notifications:
            return .features
        case .codeExecution, .fileCreation, .fileEditing, .externalAPICalls, .destructiveApproval:
            return .execution
        case .debugMode, .performanceMetrics:
            return .debug
        }
    }

    /// Default value when not set in UserDefaults
    var defaultValue: Bool {
        switch self {
        case .streamingResponses, .cloudSync, .cloudPrivacyGuard, .notifications,
             .clipboardHistory, .destructiveApproval, .agentMode, .semanticSearch:
            return true
        case .localModels, .ollama, .analytics, .clipboardSync,
             .moltbookAgent, .betaFeatures, .codeExecution, .fileCreation,
             .fileEditing, .externalAPICalls, .debugMode, .performanceMetrics:
            return false
        }
    }

    /// Brief explanation shown in settings UI
    var helpText: String {
        switch self {
        case .localModels: return "Prefer on-device models over cloud providers"
        case .ollama: return "Enable Ollama for local model inference"
        case .semanticSearch: return "Use embedding-based search for conversations"
        case .streamingResponses: return "Stream AI responses token-by-token"
        case .cloudSync: return "Sync conversations and settings via iCloud"
        case .cloudPrivacyGuard: return "Sanitize outbound data before sending to cloud APIs"
        case .analytics: return "Collect anonymous usage analytics"
        case .clipboardSync: return "Sync clipboard history across devices"
        case .agentMode: return "Allow AI to delegate and execute complex tasks"
        case .moltbookAgent: return "Enable the Moltbook development discussion agent"
        case .betaFeatures: return "Enable experimental features (may be unstable)"
        case .clipboardHistory: return "Track and search clipboard history"
        case .notifications: return "Show system notifications for AI responses"
        case .codeExecution: return "Allow code snippet execution for verification"
        case .fileCreation: return "Allow AI to create new files"
        case .fileEditing: return "Allow AI to edit existing files"
        case .externalAPICalls: return "Allow outbound API calls to third-party services"
        case .destructiveApproval: return "Require approval before destructive actions"
        case .debugMode: return "Show debug information in the UI"
        case .performanceMetrics: return "Display performance metrics overlay"
        }
    }
}

// MARK: - Flag Category

// periphery:ignore - Reserved: FlagCategory type reserved for future feature activation
enum FlagCategory: String, CaseIterable, Sendable {
    case aiModels = "AI & Models"
    case privacySync = "Privacy & Sync"
    case agentAutonomy = "Agent & Autonomy"
    case features = "Features"
    case execution = "Execution Permissions"
    case debug = "Debug"

    /// All flags in this category
    var flags: [TheaFeatureFlag] {
        TheaFeatureFlag.allCases.filter { $0.category == self }
    }

    var icon: String {
        switch self {
        case .aiModels: return "cpu"
        case .privacySync: return "lock.shield"
        case .agentAutonomy: return "gearshape.2"
        case .features: return "star"
        case .execution: return "terminal"
        case .debug: return "ant"
        }
    }
}
