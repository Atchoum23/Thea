// ConfigurationManager.swift
// Centralized configuration management - no hardcoded values

import Foundation
import OSLog
import Combine

// MARK: - Configuration Manager

/// Centralized configuration with no hardcoded values - all configurable via Settings
@MainActor
public final class ConfigurationManager: ObservableObject {
    public static let shared = ConfigurationManager()

    private let logger = Logger(subsystem: "com.thea.app", category: "Configuration")
    private let defaults = UserDefaults.standard

    // MARK: - Configuration Categories

    @Published public var general = GeneralConfiguration()
    @Published public var ai = AIConfiguration()
    @Published public var appearance = AppearanceConfiguration()
    @Published public var keyboard = KeyboardConfiguration()
    @Published public var privacy = PrivacyConfiguration()
    @Published public var sync = SyncConfiguration()
    @Published public var notifications = NotificationConfiguration()
    @Published public var advanced = AdvancedConfiguration()
    @Published public var experimental = ExperimentalConfiguration()

    // MARK: - Initialization

    private init() {
        loadAllConfigurations()
        setupObservers()
    }

    // MARK: - Loading

    private func loadAllConfigurations() {
        general = load(GeneralConfiguration.self, key: "config.general") ?? GeneralConfiguration()
        ai = load(AIConfiguration.self, key: "config.ai") ?? AIConfiguration()
        appearance = load(AppearanceConfiguration.self, key: "config.appearance") ?? AppearanceConfiguration()
        keyboard = load(KeyboardConfiguration.self, key: "config.keyboard") ?? KeyboardConfiguration()
        privacy = load(PrivacyConfiguration.self, key: "config.privacy") ?? PrivacyConfiguration()
        sync = load(SyncConfiguration.self, key: "config.sync") ?? SyncConfiguration()
        notifications = load(NotificationConfiguration.self, key: "config.notifications") ?? NotificationConfiguration()
        advanced = load(AdvancedConfiguration.self, key: "config.advanced") ?? AdvancedConfiguration()
        experimental = load(ExperimentalConfiguration.self, key: "config.experimental") ?? ExperimentalConfiguration()

        logger.info("Loaded all configurations")
    }

    private func load<T: Codable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Saving

    public func save() {
        save(general, key: "config.general")
        save(ai, key: "config.ai")
        save(appearance, key: "config.appearance")
        save(keyboard, key: "config.keyboard")
        save(privacy, key: "config.privacy")
        save(sync, key: "config.sync")
        save(notifications, key: "config.notifications")
        save(advanced, key: "config.advanced")
        save(experimental, key: "config.experimental")

        logger.info("Saved all configurations")
    }

    private func save<T: Codable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }

    // MARK: - Auto-save

    private func setupObservers() {
        // Auto-save on changes
        Timer.publish(every: 5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.save()
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Reset

    public func resetToDefaults() {
        general = GeneralConfiguration()
        ai = AIConfiguration()
        appearance = AppearanceConfiguration()
        keyboard = KeyboardConfiguration()
        privacy = PrivacyConfiguration()
        sync = SyncConfiguration()
        notifications = NotificationConfiguration()
        advanced = AdvancedConfiguration()
        experimental = ExperimentalConfiguration()

        save()
        logger.info("Reset all configurations to defaults")
    }

    public func resetCategory(_ category: ConfigurationCategory) {
        switch category {
        case .general: general = GeneralConfiguration()
        case .ai: ai = AIConfiguration()
        case .appearance: appearance = AppearanceConfiguration()
        case .keyboard: keyboard = KeyboardConfiguration()
        case .privacy: privacy = PrivacyConfiguration()
        case .sync: sync = SyncConfiguration()
        case .notifications: notifications = NotificationConfiguration()
        case .advanced: advanced = AdvancedConfiguration()
        case .experimental: experimental = ExperimentalConfiguration()
        }
        save()
    }

    // MARK: - Export/Import

    public func exportConfiguration() throws -> Data {
        let export = ConfigurationExport(
            general: general,
            ai: ai,
            appearance: appearance,
            keyboard: keyboard,
            privacy: privacy,
            sync: sync,
            notifications: notifications,
            advanced: advanced,
            experimental: experimental,
            exportedAt: Date()
        )
        return try JSONEncoder().encode(export)
    }

    public func importConfiguration(from data: Data) throws {
        let imported = try JSONDecoder().decode(ConfigurationExport.self, from: data)

        general = imported.general
        ai = imported.ai
        appearance = imported.appearance
        keyboard = imported.keyboard
        privacy = imported.privacy
        sync = imported.sync
        notifications = imported.notifications
        advanced = imported.advanced
        experimental = imported.experimental

        save()
        logger.info("Imported configuration")
    }
}

// MARK: - Configuration Categories

public enum ConfigurationCategory: String, CaseIterable, Identifiable {
    case general, ai, appearance, keyboard, privacy, sync, notifications, advanced, experimental

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .general: return "General"
        case .ai: return "AI & Models"
        case .appearance: return "Appearance"
        case .keyboard: return "Keyboard"
        case .privacy: return "Privacy & Security"
        case .sync: return "Sync & Backup"
        case .notifications: return "Notifications"
        case .advanced: return "Advanced"
        case .experimental: return "Experimental"
        }
    }

    public var icon: String {
        switch self {
        case .general: return "gear"
        case .ai: return "brain"
        case .appearance: return "paintbrush"
        case .keyboard: return "keyboard"
        case .privacy: return "lock.shield"
        case .sync: return "arrow.triangle.2.circlepath"
        case .notifications: return "bell"
        case .advanced: return "slider.horizontal.3"
        case .experimental: return "flask"
        }
    }
}

// MARK: - General Configuration

public struct GeneralConfiguration: Codable {
    // App behavior
    public var launchAtLogin: Bool = false
    public var showInDock: Bool = true
    public var showInMenuBar: Bool = true
    public var defaultWindowBehavior: WindowBehavior = .newTab

    // Language
    public var language: String = "system"
    public var region: String = "system"

    // Updates
    public var checkForUpdates: Bool = true
    public var autoInstallUpdates: Bool = false
    public var updateChannel: UpdateChannel = .stable

    // Data
    public var storageLocation: StorageLocation = .default
    public var customStoragePath: String?

    public enum WindowBehavior: String, Codable, CaseIterable {
        case newTab = "New Tab"
        case newWindow = "New Window"
        case reuseCurrent = "Reuse Current"
    }

    public enum UpdateChannel: String, Codable, CaseIterable {
        case stable = "Stable"
        case beta = "Beta"
        case nightly = "Nightly"
    }

    public enum StorageLocation: String, Codable, CaseIterable {
        case `default` = "Default"
        case iCloud = "iCloud"
        case custom = "Custom"
    }
}

// MARK: - AI Configuration

public struct AIConfiguration: Codable {
    // Provider
    public var defaultProvider: String = "anthropic"
    public var defaultModel: String = "claude-3-5-sonnet"

    // API Keys (stored securely)
    public var anthropicKeyConfigured: Bool = false
    public var openAIKeyConfigured: Bool = false
    public var googleKeyConfigured: Bool = false
    public var localModelsEnabled: Bool = false

    // Behavior
    public var streamResponses: Bool = true
    public var autoRetryOnError: Bool = true
    public var maxRetries: Int = 3
    public var requestTimeout: TimeInterval = 60

    // Context
    public var maxContextLength: Int = 100000
    public var includeConversationHistory: Bool = true
    public var historyMessageLimit: Int = 50

    // Memory
    public var enableMemory: Bool = true
    public var memoryAutoSave: Bool = true
    public var memorySensitivity: Double = 0.7

    // Tools
    public var enableMCPTools: Bool = true
    public var toolApprovalMode: ToolApprovalMode = .askForSensitive
    public var maxConcurrentTools: Int = 5

    // Self-execution
    public var enableSelfExecution: Bool = false
    public var selfExecutionApproval: SelfExecutionApproval = .always
    public var allowedSelfExecutionActions: Set<String> = []

    public enum ToolApprovalMode: String, Codable, CaseIterable {
        case always = "Always Ask"
        case askForSensitive = "Ask for Sensitive"
        case never = "Never Ask"
    }

    public enum SelfExecutionApproval: String, Codable, CaseIterable {
        case always = "Always Require"
        case forDestructive = "For Destructive Actions"
        case never = "Never Require"
    }
}

// MARK: - Appearance Configuration

public struct AppearanceConfiguration: Codable {
    // Theme
    public var theme: Theme = .system
    public var accentColor: String = "blue"

    // Typography
    public var fontSize: FontSize = .medium
    public var fontFamily: String = "system"
    public var lineSpacing: Double = 1.4
    public var paragraphSpacing: Double = 1.0

    // Code
    public var codeTheme: String = "xcode"
    public var codeFontFamily: String = "SF Mono"
    public var codeFontSize: Int = 13
    public var showLineNumbers: Bool = true
    public var enableSyntaxHighlighting: Bool = true

    // Layout
    public var sidebarWidth: Double = 250
    public var sidebarPosition: SidebarPosition = .left
    public var compactMode: Bool = false
    public var showAvatars: Bool = true

    // Messages
    public var messageAlignment: MessageAlignment = .leading
    public var showTimestamps: Bool = true
    public var timestampFormat: String = "relative"
    public var groupConsecutiveMessages: Bool = true

    // Animations
    public var enableAnimations: Bool = true
    public var animationSpeed: AnimationSpeed = .normal
    public var reduceMotion: Bool = false

    public enum Theme: String, Codable, CaseIterable {
        case light = "Light"
        case dark = "Dark"
        case system = "System"
    }

    public enum FontSize: String, Codable, CaseIterable {
        case small = "Small"
        case medium = "Medium"
        case large = "Large"
        case extraLarge = "Extra Large"

        public var value: CGFloat {
            switch self {
            case .small: return 13
            case .medium: return 15
            case .large: return 17
            case .extraLarge: return 20
            }
        }
    }

    public enum SidebarPosition: String, Codable, CaseIterable {
        case left = "Left"
        case right = "Right"
    }

    public enum MessageAlignment: String, Codable, CaseIterable {
        case leading = "Leading"
        case alternating = "Alternating"
    }

    public enum AnimationSpeed: String, Codable, CaseIterable {
        case slow = "Slow"
        case normal = "Normal"
        case fast = "Fast"
    }
}

// MARK: - Keyboard Configuration

public struct KeyboardConfiguration: Codable {
    // Global shortcut
    public var globalShortcutEnabled: Bool = true
    public var globalShortcutKey: String = "Space"
    public var globalShortcutModifiers: [String] = ["option"]

    // Quick prompt
    public var quickPromptEnabled: Bool = true
    public var quickPromptKey: String = "Space"
    public var quickPromptModifiers: [String] = ["option", "shift"]

    // Input
    public var sendOnEnter: Bool = true
    public var newLineOnShiftEnter: Bool = true
    public var enableMarkdownShortcuts: Bool = true

    // Navigation
    public var useVimKeybindings: Bool = false
    public var focusInputOnLoad: Bool = true

    // Custom shortcuts
    public var customShortcuts: [String: CustomShortcut] = [:]

    public struct CustomShortcut: Codable {
        public var key: String
        public var modifiers: [String]
        public var action: String
    }
}

// MARK: - Privacy Configuration

public struct PrivacyConfiguration: Codable {
    // Data collection
    public var analyticsEnabled: Bool = true
    public var crashReportingEnabled: Bool = true
    public var usageDataEnabled: Bool = false

    // Local data
    public var encryptLocalData: Bool = false
    public var biometricUnlock: Bool = false
    public var autoLockTimeout: Int = 0 // 0 = never

    // Conversations
    public var saveConversationHistory: Bool = true
    public var conversationRetentionDays: Int = 0 // 0 = forever
    public var excludeFromSpotlight: Bool = false

    // AI data
    public var allowModelTraining: Bool = false
    public var redactSensitiveData: Bool = true
    public var sensitiveDataPatterns: [String] = ["email", "phone", "ssn", "credit_card"]

    // Network
    public var useProxyForAI: Bool = false
    public var proxyAddress: String = ""
    public var disableTelemetry: Bool = false
}

// MARK: - Sync Configuration

public struct SyncConfiguration: Codable {
    // iCloud sync
    public var iCloudSyncEnabled: Bool = true
    public var syncConversations: Bool = true
    public var syncAgents: Bool = true
    public var syncArtifacts: Bool = true
    public var syncMemories: Bool = true
    public var syncSettings: Bool = false

    // Sync behavior
    public var syncFrequency: SyncFrequency = .automatic
    public var syncOnCellular: Bool = false
    public var conflictResolution: ConflictResolution = .mostRecent

    // Backup
    public var autoBackupEnabled: Bool = true
    public var backupFrequency: BackupFrequency = .daily
    public var keepBackupCount: Int = 10
    public var backupToiCloud: Bool = true

    public enum SyncFrequency: String, Codable, CaseIterable {
        case automatic = "Automatic"
        case hourly = "Hourly"
        case daily = "Daily"
        case manual = "Manual"
    }

    public enum ConflictResolution: String, Codable, CaseIterable {
        case mostRecent = "Most Recent Wins"
        case local = "Local Wins"
        case remote = "Remote Wins"
        case ask = "Ask Each Time"
    }

    public enum BackupFrequency: String, Codable, CaseIterable {
        case hourly = "Hourly"
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"
    }
}

// MARK: - Notification Configuration

public struct NotificationConfiguration: Codable {
    // General
    public var notificationsEnabled: Bool = true
    public var soundEnabled: Bool = true
    public var badgeEnabled: Bool = true

    // Types
    public var notifyOnResponse: Bool = true
    public var notifyOnMention: Bool = true
    public var notifyOnTaskComplete: Bool = true
    public var notifyOnError: Bool = true
    public var notifyOnSync: Bool = false

    // Schedule
    public var quietHoursEnabled: Bool = false
    public var quietHoursStart: String = "22:00"
    public var quietHoursEnd: String = "08:00"

    // Sound
    public var notificationSound: String = "default"
    public var customSoundPath: String?
}

// MARK: - Advanced Configuration

public struct AdvancedConfiguration: Codable {
    // Performance
    public var maxMemoryUsageMB: Int = 2048
    public var cacheSize: CacheSize = .medium
    public var preloadConversations: Bool = true
    public var lazyLoadImages: Bool = true

    // Debugging
    public var debugModeEnabled: Bool = false
    public var verboseLogging: Bool = false
    public var logToFile: Bool = false
    public var logRetentionDays: Int = 7

    // Network
    public var connectionTimeout: Int = 30
    public var maxConcurrentRequests: Int = 10
    public var useHTTP2: Bool = true
    public var enableRequestCompression: Bool = true

    // Database
    public var vacuumOnStartup: Bool = false
    public var checkIntegrity: Bool = true

    // Rendering
    public var useMetalRendering: Bool = true
    public var maxRenderFPS: Int = 60

    public enum CacheSize: String, Codable, CaseIterable {
        case small = "Small (100MB)"
        case medium = "Medium (500MB)"
        case large = "Large (1GB)"
        case unlimited = "Unlimited"

        public var bytes: Int {
            switch self {
            case .small: return 100 * 1024 * 1024
            case .medium: return 500 * 1024 * 1024
            case .large: return 1024 * 1024 * 1024
            case .unlimited: return Int.max
            }
        }
    }
}

// MARK: - Experimental Configuration

public struct ExperimentalConfiguration: Codable {
    // Features
    public var enableSelfEvolution: Bool = false
    public var enableMissionOrchestrator: Bool = false
    public var enableAgentAutonomy: Bool = false

    // AI
    public var useSpeculativeDecoding: Bool = false
    public var enableMultiModelRouting: Bool = false
    public var enableContextCompression: Bool = false

    // UI
    public var enableNewEditor: Bool = false
    public var enableSpatialUI: Bool = false
    public var enableVoiceUI: Bool = false

    // System
    public var enableBrowserAutomation: Bool = false
    public var enableSystemIntegration: Bool = false

    // Developer
    public var showInternalMetrics: Bool = false
    public var enableAPIPlayground: Bool = false
}

// MARK: - Export

private struct ConfigurationExport: Codable {
    let general: GeneralConfiguration
    let ai: AIConfiguration
    let appearance: AppearanceConfiguration
    let keyboard: KeyboardConfiguration
    let privacy: PrivacyConfiguration
    let sync: SyncConfiguration
    let notifications: NotificationConfiguration
    let advanced: AdvancedConfiguration
    let experimental: ExperimentalConfiguration
    let exportedAt: Date
}

// MARK: - Setting Metadata

/// Metadata for settings including descriptions for info popovers
public struct SettingMetadata {
    public let key: String
    public let title: String
    public let description: String
    public let category: ConfigurationCategory
    public let type: SettingType
    public let defaultValue: Any?
    public let options: [String]?
    public let range: ClosedRange<Double>?
    public let requiresRestart: Bool
    public let isAdvanced: Bool

    public enum SettingType {
        case toggle
        case picker
        case slider
        case text
        case number
        case shortcut
        case color
    }
}

/// Registry of all settings with their metadata
public struct SettingsRegistry {
    public static let all: [SettingMetadata] = [
        // General
        SettingMetadata(
            key: "general.launchAtLogin",
            title: "Launch at Login",
            description: "Automatically start Thea when you log in to your Mac. Thea will run in the background, ready for quick access.",
            category: .general,
            type: .toggle,
            defaultValue: false,
            options: nil,
            range: nil,
            requiresRestart: false,
            isAdvanced: false
        ),
        SettingMetadata(
            key: "general.showInMenuBar",
            title: "Show in Menu Bar",
            description: "Display a Thea icon in the menu bar for quick access to conversations and settings.",
            category: .general,
            type: .toggle,
            defaultValue: true,
            options: nil,
            range: nil,
            requiresRestart: false,
            isAdvanced: false
        ),
        SettingMetadata(
            key: "general.defaultWindowBehavior",
            title: "New Conversation Opens In",
            description: "Choose whether new conversations open in a new tab, new window, or replace the current content.",
            category: .general,
            type: .picker,
            defaultValue: "newTab",
            options: ["New Tab", "New Window", "Reuse Current"],
            range: nil,
            requiresRestart: false,
            isAdvanced: false
        ),

        // AI
        SettingMetadata(
            key: "ai.defaultProvider",
            title: "Default AI Provider",
            description: "The AI provider to use by default. You can switch providers per-conversation if needed.",
            category: .ai,
            type: .picker,
            defaultValue: "anthropic",
            options: ["Anthropic", "OpenAI", "Google", "Local"],
            range: nil,
            requiresRestart: false,
            isAdvanced: false
        ),
        SettingMetadata(
            key: "ai.streamResponses",
            title: "Stream Responses",
            description: "Show AI responses as they're being generated, word by word. Disable for complete responses only.",
            category: .ai,
            type: .toggle,
            defaultValue: true,
            options: nil,
            range: nil,
            requiresRestart: false,
            isAdvanced: false
        ),
        SettingMetadata(
            key: "ai.maxContextLength",
            title: "Maximum Context Length",
            description: "The maximum number of tokens to include in the conversation context. Higher values provide more context but increase costs.",
            category: .ai,
            type: .number,
            defaultValue: 100000,
            options: nil,
            range: 1000...200000,
            requiresRestart: false,
            isAdvanced: true
        ),
        SettingMetadata(
            key: "ai.enableMemory",
            title: "Enable Long-term Memory",
            description: "Allow Thea to remember important information across conversations. This creates a persistent knowledge base about you.",
            category: .ai,
            type: .toggle,
            defaultValue: true,
            options: nil,
            range: nil,
            requiresRestart: false,
            isAdvanced: false
        ),

        // Keyboard
        SettingMetadata(
            key: "keyboard.globalShortcutEnabled",
            title: "Global Quick Prompt",
            description: "Enable a system-wide keyboard shortcut to quickly open Thea's prompt overlay from any application.",
            category: .keyboard,
            type: .toggle,
            defaultValue: true,
            options: nil,
            range: nil,
            requiresRestart: false,
            isAdvanced: false
        ),
        SettingMetadata(
            key: "keyboard.globalShortcut",
            title: "Quick Prompt Shortcut",
            description: "The keyboard shortcut to open the quick prompt overlay. Works system-wide, even when Thea is in the background.",
            category: .keyboard,
            type: .shortcut,
            defaultValue: "⌥Space",
            options: nil,
            range: nil,
            requiresRestart: false,
            isAdvanced: false
        ),

        // Privacy
        SettingMetadata(
            key: "privacy.analyticsEnabled",
            title: "Share Analytics",
            description: "Help improve Thea by sharing anonymous usage data. No conversation content is ever shared.",
            category: .privacy,
            type: .toggle,
            defaultValue: true,
            options: nil,
            range: nil,
            requiresRestart: false,
            isAdvanced: false
        ),
        SettingMetadata(
            key: "privacy.encryptLocalData",
            title: "Encrypt Local Data",
            description: "Encrypt all locally stored data using your device's secure enclave. May slightly impact performance.",
            category: .privacy,
            type: .toggle,
            defaultValue: false,
            options: nil,
            range: nil,
            requiresRestart: true,
            isAdvanced: true
        ),

        // Experimental
        SettingMetadata(
            key: "experimental.enableSelfEvolution",
            title: "Self-Evolution Engine",
            description: "Allow Thea to implement new features to its own codebase. Requires approval before changes are applied.",
            category: .experimental,
            type: .toggle,
            defaultValue: false,
            options: nil,
            range: nil,
            requiresRestart: false,
            isAdvanced: true
        ),
        SettingMetadata(
            key: "experimental.enableMissionOrchestrator",
            title: "Mission Orchestrator",
            description: "Enable autonomous execution of complex, multi-phase tasks. Thea will plan and execute lengthy missions with checkpoints.",
            category: .experimental,
            type: .toggle,
            defaultValue: false,
            options: nil,
            range: nil,
            requiresRestart: false,
            isAdvanced: true
        )
    ]

    public static func metadata(for key: String) -> SettingMetadata? {
        all.first { $0.key == key }
    }

    public static func settings(in category: ConfigurationCategory) -> [SettingMetadata] {
        all.filter { $0.category == category }
    }
}
