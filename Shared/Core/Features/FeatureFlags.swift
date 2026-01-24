// FeatureFlags.swift
// Dynamic feature flag system for A/B testing and gradual rollout

import Foundation
import OSLog

// MARK: - Feature Flag System

/// Central feature flag manager with remote config support
@MainActor
public final class FeatureFlags: ObservableObject {
    public static let shared = FeatureFlags()

    private let logger = Logger(subsystem: "com.thea.app", category: "FeatureFlags")
    private let defaults = UserDefaults.standard
    private let flagsKey = "thea.feature.flags"

    // MARK: - Published Flags

    @Published public private(set) var flags: [String: FeatureFlag] = [:]
    @Published public private(set) var lastSyncDate: Date?

    // MARK: - Core Feature Flags

    /// AgentSec Strict Mode
    public var agentSecStrictMode: Bool {
        isEnabled("agentsec.strict_mode", default: true)
    }

    /// AI Vision capabilities
    public var aiVision: Bool {
        isEnabled("ai.vision", default: true)
    }

    /// AI Speech recognition
    public var aiSpeech: Bool {
        isEnabled("ai.speech", default: true)
    }

    /// Document Intelligence
    public var documentIntelligence: Bool {
        isEnabled("ai.document_intelligence", default: true)
    }

    /// Live Activities support
    public var liveActivities: Bool {
        isEnabled("ui.live_activities", default: true)
    }

    /// Widgets
    public var widgets: Bool {
        isEnabled("ui.widgets", default: true)
    }

    /// Browser automation
    public var browserAutomation: Bool {
        isEnabled("automation.browser", default: false)
    }

    /// Smart triggers
    public var smartTriggers: Bool {
        isEnabled("automation.smart_triggers", default: true)
    }

    /// Scheduled tasks
    public var scheduledTasks: Bool {
        isEnabled("automation.scheduled_tasks", default: true)
    }

    /// Spotlight integration
    public var spotlightIntegration: Bool {
        isEnabled("integration.spotlight", default: true)
    }

    /// Control Center widgets
    public var controlCenterWidgets: Bool {
        isEnabled("integration.control_center", default: true)
    }

    /// Focus filters
    public var focusFilters: Bool {
        isEnabled("integration.focus_filters", default: true)
    }

    /// Handoff support
    public var handoff: Bool {
        isEnabled("integration.handoff", default: true)
    }

    /// Universal clipboard
    public var universalClipboard: Bool {
        isEnabled("integration.universal_clipboard", default: true)
    }

    /// MCP servers
    public var mcpServers: Bool {
        isEnabled("ai.mcp_servers", default: true)
    }

    /// Custom agents (GPTs)
    public var customAgents: Bool {
        isEnabled("ai.custom_agents", default: true)
    }

    /// Multi-modal input
    public var multiModalInput: Bool {
        isEnabled("ai.multimodal_input", default: true)
    }

    /// Code execution sandbox
    public var codeExecutionSandbox: Bool {
        isEnabled("ai.code_execution", default: false)
    }

    /// Health tracking
    public var healthTracking: Bool {
        isEnabled("tracking.health", default: true)
    }

    /// Location tracking
    public var locationTracking: Bool {
        isEnabled("tracking.location", default: true)
    }

    /// Screen time tracking
    public var screenTimeTracking: Bool {
        isEnabled("tracking.screen_time", default: true)
    }

    // MARK: - Initialization

    private init() {
        loadFlags()
    }

    // MARK: - Flag Management

    public func isEnabled(_ key: String, default defaultValue: Bool = false) -> Bool {
        if let flag = flags[key] {
            return flag.isEnabled
        }
        return defaultValue
    }

    public func setFlag(_ key: String, enabled: Bool, source: FeatureFlagSource = .local) {
        flags[key] = FeatureFlag(
            key: key,
            isEnabled: enabled,
            source: source,
            lastUpdated: Date()
        )
        saveFlags()
    }

    public func resetToDefaults() {
        flags.removeAll()
        defaults.removeObject(forKey: flagsKey)
        logger.info("Feature flags reset to defaults")
    }

    // MARK: - Persistence

    private func loadFlags() {
        guard let data = defaults.data(forKey: flagsKey),
              let savedFlags = try? JSONDecoder().decode([String: FeatureFlag].self, from: data) else {
            return
        }
        flags = savedFlags
    }

    private func saveFlags() {
        guard let data = try? JSONEncoder().encode(flags) else { return }
        defaults.set(data, forKey: flagsKey)
    }

    // MARK: - Remote Config Sync

    public func syncWithRemote() async throws {
        // Placeholder for remote config sync
        // Could integrate with Firebase Remote Config, LaunchDarkly, etc.
        lastSyncDate = Date()
        logger.info("Feature flags synced")
    }
}

// MARK: - Feature Flag Model

public struct FeatureFlag: Codable, Sendable {
    public let key: String
    public var isEnabled: Bool
    public let source: FeatureFlagSource
    public let lastUpdated: Date

    public var description: String? = nil
    public var rolloutPercentage: Double? = nil
}

public enum FeatureFlagSource: String, Codable, Sendable {
    case local = "local"
    case remote = "remote"
    case override = "override"
    case abTest = "ab_test"
}
