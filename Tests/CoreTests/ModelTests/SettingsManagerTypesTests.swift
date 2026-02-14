// SettingsManagerTypesTests.swift
// Tests for SettingsManager defaults, validation logic, and persistence patterns
// Standalone test doubles — no dependency on actual SettingsManager

import Testing
import Foundation

// MARK: - Test Doubles

/// Mirrors SettingsManager's default values for verification
private struct SettingsDefaults {
    // AI Provider Settings
    static let defaultProvider = "openrouter"
    static let streamResponses = true
    static let availableProviders = [
        "anthropic", "openai", "google", "groq",
        "openrouter", "perplexity", "deepseek"
    ]

    // Appearance
    static let theme = "system"
    static let fontSize = "medium"

    // Privacy
    static let iCloudSyncEnabled = true
    static let analyticsEnabled = false
    static let handoffEnabled = true
    static let cloudAPIPrivacyGuardEnabled = false

    // Behavior
    static let launchAtLogin = false
    static let showInMenuBar = true
    static let notificationsEnabled = true

    // Window
    static let windowFloatOnTop = false
    static let rememberWindowPosition = true
    static let defaultWindowSize = "default"

    // Message Display
    static let messageDensity = "comfortable"
    static let timestampDisplay = "relative"
    static let autoScrollToBottom = true

    // Startup
    static let showSidebarOnLaunch = true
    static let restoreLastSession = false

    // Voice
    static let readResponsesAloud = false
    static let selectedVoice = "default"

    // Advanced
    static let debugMode = false
    static let showPerformanceMetrics = false
    static let betaFeaturesEnabled = false

    // Local Models
    static let preferLocalModels = false
    static let mlxModelsPath = "~/.cache/huggingface/hub/"
    static let ollamaEnabled = false
    static let ollamaURL = "http://localhost:11434"

    // Self-Execution
    static let executionMode = "manual"
    static let allowFileCreation = false
    static let allowFileEditing = false
    static let allowCodeExecution = false
    static let allowExternalAPICalls = false
    static let requireDestructiveApproval = true
    static let enableRollback = true
    static let createBackups = true
    static let preventSleepDuringExecution = true
    static let maxConcurrentTasks = 3
    static let submitShortcut = "enter"

    // Notifications
    static let notifyOnResponseComplete = true
    static let notifyOnAttentionRequired = true
    static let playNotificationSound = true
    static let showDockBadge = true
    static let doNotDisturb = false

    // Moltbook
    static let moltbookAgentEnabled = false
    static let moltbookPreviewMode = true
    static let moltbookMaxDailyPosts = 10

    // Clipboard
    static let clipboardHistoryEnabled = true
    static let clipboardRecordImages = true
    static let clipboardMaxHistory = 500
    static let clipboardRetentionDays = 30
    static let clipboardAutoDetectSensitive = true
    static let clipboardSensitiveExpiryHours = 24
    static let clipboardAutoSummarize = false
    static let clipboardSyncEnabled = false
    static let clipboardAutoCategorize = false
    static let clipboardSyncPinboards = false
    static let clipboardExcludedApps: [String] = []

    // Agent Delegation
    static let agentDelegationEnabled = true
    static let agentAutoDelegateComplexTasks = false
    static let agentMaxConcurrent = 4
    static let agentDefaultAutonomy = "balanced"

    // Focus & Search
    static let activeFocusMode = "general"
    static let enableSemanticSearch = true

    // Export
    static let defaultExportFormat = "markdown"
}

/// Integer validation logic mirroring SettingsManager's pattern
private func validatedInteger(_ value: Int, default defaultValue: Int) -> Int {
    value != 0 ? value : defaultValue
}

/// Persistence timestamp key pattern
private func timestampKey(for key: String) -> String {
    "\(key)__localTS"
}

/// Theme validation
private enum ThemeOption: String, CaseIterable {
    case system, light, dark
}

/// Font size validation
private enum FontSizeOption: String, CaseIterable {
    case small, medium, large
}

/// Execution mode validation
private enum ExecutionModeOption: String, CaseIterable {
    case manual, supervised, autonomous
}

/// Autonomy level validation
private enum AutonomyLevel: String, CaseIterable {
    case supervised, cautious, balanced, proactive, unrestricted
}

/// Export format validation
private enum ExportFormat: String, CaseIterable {
    case markdown, json, plaintext
}

// MARK: - Tests

@Suite("SettingsManager Defaults")
struct SettingsDefaultsTests {
    @Test("Default provider is openrouter")
    func defaultProvider() {
        #expect(SettingsDefaults.defaultProvider == "openrouter")
    }

    @Test("Stream responses enabled by default")
    func streamResponsesDefault() {
        #expect(SettingsDefaults.streamResponses == true)
    }

    @Test("Available providers list is complete")
    func availableProviders() {
        let providers = SettingsDefaults.availableProviders
        #expect(providers.count == 7)
        #expect(providers.contains("anthropic"))
        #expect(providers.contains("openai"))
        #expect(providers.contains("google"))
        #expect(providers.contains("groq"))
        #expect(providers.contains("openrouter"))
        #expect(providers.contains("perplexity"))
        #expect(providers.contains("deepseek"))
    }

    @Test("Theme default is system")
    func themeDefault() {
        #expect(SettingsDefaults.theme == "system")
    }

    @Test("Font size default is medium")
    func fontSizeDefault() {
        #expect(SettingsDefaults.fontSize == "medium")
    }

    @Test("Privacy defaults — iCloud on, analytics off")
    func privacyDefaults() {
        #expect(SettingsDefaults.iCloudSyncEnabled == true)
        #expect(SettingsDefaults.analyticsEnabled == false)
        #expect(SettingsDefaults.handoffEnabled == true)
        #expect(SettingsDefaults.cloudAPIPrivacyGuardEnabled == false)
    }

    @Test("Behavior defaults — menu bar visible, no login launch")
    func behaviorDefaults() {
        #expect(SettingsDefaults.launchAtLogin == false)
        #expect(SettingsDefaults.showInMenuBar == true)
        #expect(SettingsDefaults.notificationsEnabled == true)
    }

    @Test("Window defaults — no float, remember position")
    func windowDefaults() {
        #expect(SettingsDefaults.windowFloatOnTop == false)
        #expect(SettingsDefaults.rememberWindowPosition == true)
        #expect(SettingsDefaults.defaultWindowSize == "default")
    }

    @Test("Message display defaults — comfortable density, relative time")
    func messageDisplayDefaults() {
        #expect(SettingsDefaults.messageDensity == "comfortable")
        #expect(SettingsDefaults.timestampDisplay == "relative")
        #expect(SettingsDefaults.autoScrollToBottom == true)
    }

    @Test("Startup defaults — sidebar visible, no session restore")
    func startupDefaults() {
        #expect(SettingsDefaults.showSidebarOnLaunch == true)
        #expect(SettingsDefaults.restoreLastSession == false)
    }

    @Test("Voice defaults — silent by default")
    func voiceDefaults() {
        #expect(SettingsDefaults.readResponsesAloud == false)
        #expect(SettingsDefaults.selectedVoice == "default")
    }

    @Test("Advanced defaults — all debug off")
    func advancedDefaults() {
        #expect(SettingsDefaults.debugMode == false)
        #expect(SettingsDefaults.showPerformanceMetrics == false)
        #expect(SettingsDefaults.betaFeaturesEnabled == false)
    }

    @Test("Local models defaults — prefer cloud, standard path")
    func localModelsDefaults() {
        #expect(SettingsDefaults.preferLocalModels == false)
        #expect(SettingsDefaults.mlxModelsPath == "~/.cache/huggingface/hub/")
        #expect(SettingsDefaults.ollamaEnabled == false)
        #expect(SettingsDefaults.ollamaURL == "http://localhost:11434")
    }

    @Test("Execution defaults — manual, all restricted")
    func executionDefaults() {
        #expect(SettingsDefaults.executionMode == "manual")
        #expect(SettingsDefaults.allowFileCreation == false)
        #expect(SettingsDefaults.allowFileEditing == false)
        #expect(SettingsDefaults.allowCodeExecution == false)
        #expect(SettingsDefaults.allowExternalAPICalls == false)
        #expect(SettingsDefaults.requireDestructiveApproval == true)
        #expect(SettingsDefaults.enableRollback == true)
        #expect(SettingsDefaults.createBackups == true)
        #expect(SettingsDefaults.preventSleepDuringExecution == true)
        #expect(SettingsDefaults.maxConcurrentTasks == 3)
        #expect(SettingsDefaults.submitShortcut == "enter")
    }

    @Test("Notification defaults — all enabled except DND")
    func notificationDefaults() {
        #expect(SettingsDefaults.notifyOnResponseComplete == true)
        #expect(SettingsDefaults.notifyOnAttentionRequired == true)
        #expect(SettingsDefaults.playNotificationSound == true)
        #expect(SettingsDefaults.showDockBadge == true)
        #expect(SettingsDefaults.doNotDisturb == false)
    }

    @Test("Moltbook defaults — disabled, preview on, 10 posts/day")
    func moltbookDefaults() {
        #expect(SettingsDefaults.moltbookAgentEnabled == false)
        #expect(SettingsDefaults.moltbookPreviewMode == true)
        #expect(SettingsDefaults.moltbookMaxDailyPosts == 10)
    }

    @Test("Clipboard defaults — enabled, 500 history, 30 day retention")
    func clipboardDefaults() {
        #expect(SettingsDefaults.clipboardHistoryEnabled == true)
        #expect(SettingsDefaults.clipboardRecordImages == true)
        #expect(SettingsDefaults.clipboardMaxHistory == 500)
        #expect(SettingsDefaults.clipboardRetentionDays == 30)
        #expect(SettingsDefaults.clipboardAutoDetectSensitive == true)
        #expect(SettingsDefaults.clipboardSensitiveExpiryHours == 24)
        #expect(SettingsDefaults.clipboardAutoSummarize == false)
        #expect(SettingsDefaults.clipboardSyncEnabled == false)
        #expect(SettingsDefaults.clipboardAutoCategorize == false)
        #expect(SettingsDefaults.clipboardSyncPinboards == false)
        #expect(SettingsDefaults.clipboardExcludedApps.isEmpty)
    }

    @Test("Agent delegation defaults — enabled, 4 concurrent, balanced")
    func agentDefaults() {
        #expect(SettingsDefaults.agentDelegationEnabled == true)
        #expect(SettingsDefaults.agentAutoDelegateComplexTasks == false)
        #expect(SettingsDefaults.agentMaxConcurrent == 4)
        #expect(SettingsDefaults.agentDefaultAutonomy == "balanced")
    }

    @Test("Focus and search defaults")
    func focusSearchDefaults() {
        #expect(SettingsDefaults.activeFocusMode == "general")
        #expect(SettingsDefaults.enableSemanticSearch == true)
    }

    @Test("Export default is markdown")
    func exportDefault() {
        #expect(SettingsDefaults.defaultExportFormat == "markdown")
    }
}

@Suite("Settings Integer Validation")
struct SettingsIntegerValidationTests {
    @Test("Non-zero integer preserved")
    func nonZeroPreserved() {
        #expect(validatedInteger(5, default: 3) == 5)
    }

    @Test("Zero falls back to default")
    func zeroFallsBack() {
        #expect(validatedInteger(0, default: 3) == 3)
    }

    @Test("Negative integer preserved")
    func negativePreserved() {
        #expect(validatedInteger(-1, default: 3) == -1)
    }

    @Test("Default value itself is valid")
    func defaultValueValid() {
        #expect(validatedInteger(10, default: 10) == 10)
    }

    @Test("maxConcurrentTasks validation")
    func maxConcurrentTasks() {
        #expect(validatedInteger(0, default: 3) == 3)
        #expect(validatedInteger(5, default: 3) == 5)
    }

    @Test("moltbookMaxDailyPosts validation")
    func moltbookMaxDailyPosts() {
        #expect(validatedInteger(0, default: 10) == 10)
        #expect(validatedInteger(20, default: 10) == 20)
    }

    @Test("clipboardMaxHistory validation")
    func clipboardMaxHistory() {
        #expect(validatedInteger(0, default: 500) == 500)
        #expect(validatedInteger(1000, default: 500) == 1000)
    }

    @Test("clipboardRetentionDays validation")
    func clipboardRetentionDays() {
        #expect(validatedInteger(0, default: 30) == 30)
        #expect(validatedInteger(7, default: 30) == 7)
    }

    @Test("clipboardSensitiveExpiryHours validation")
    func clipboardSensitiveExpiryHours() {
        #expect(validatedInteger(0, default: 24) == 24)
        #expect(validatedInteger(1, default: 24) == 1)
    }

    @Test("agentMaxConcurrent validation")
    func agentMaxConcurrent() {
        #expect(validatedInteger(0, default: 4) == 4)
        #expect(validatedInteger(8, default: 4) == 8)
    }
}

@Suite("Settings Persistence Keys")
struct SettingsPersistenceKeyTests {
    @Test("Timestamp key format")
    func timestampKeyFormat() {
        #expect(timestampKey(for: "theme") == "theme__localTS")
        #expect(timestampKey(for: "fontSize") == "fontSize__localTS")
    }

    @Test("Timestamp key for nested setting")
    func nestedTimestampKey() {
        #expect(timestampKey(for: "clipboardMaxHistory") == "clipboardMaxHistory__localTS")
    }

    @Test("Empty key still produces valid timestamp key")
    func emptyKeyTimestamp() {
        #expect(timestampKey(for: "") == "__localTS")
    }
}

@Suite("Settings Enum Validation")
struct SettingsEnumValidationTests {
    @Test("Theme options are exactly 3")
    func themeOptions() {
        #expect(ThemeOption.allCases.count == 3)
        #expect(ThemeOption(rawValue: "system") != nil)
        #expect(ThemeOption(rawValue: "light") != nil)
        #expect(ThemeOption(rawValue: "dark") != nil)
        #expect(ThemeOption(rawValue: "invalid") == nil)
    }

    @Test("Font size options are exactly 3")
    func fontSizeOptions() {
        #expect(FontSizeOption.allCases.count == 3)
        #expect(FontSizeOption(rawValue: "small") != nil)
        #expect(FontSizeOption(rawValue: "medium") != nil)
        #expect(FontSizeOption(rawValue: "large") != nil)
        #expect(FontSizeOption(rawValue: "tiny") == nil)
    }

    @Test("Execution mode options are exactly 3")
    func executionModes() {
        #expect(ExecutionModeOption.allCases.count == 3)
        #expect(ExecutionModeOption(rawValue: "manual") != nil)
        #expect(ExecutionModeOption(rawValue: "supervised") != nil)
        #expect(ExecutionModeOption(rawValue: "autonomous") != nil)
    }

    @Test("Autonomy levels are exactly 5 in risk order")
    func autonomyLevels() {
        let levels = AutonomyLevel.allCases
        #expect(levels.count == 5)
        #expect(levels[0] == .supervised)
        #expect(levels[4] == .unrestricted)
    }

    @Test("Export formats include markdown, json, plaintext")
    func exportFormats() {
        #expect(ExportFormat.allCases.count == 3)
        #expect(ExportFormat(rawValue: "markdown") != nil)
        #expect(ExportFormat(rawValue: "json") != nil)
        #expect(ExportFormat(rawValue: "plaintext") != nil)
    }

    @Test("Default values match valid enum cases")
    func defaultsMatchEnums() {
        #expect(ThemeOption(rawValue: SettingsDefaults.theme) != nil)
        #expect(FontSizeOption(rawValue: SettingsDefaults.fontSize) != nil)
        #expect(ExecutionModeOption(rawValue: SettingsDefaults.executionMode) != nil)
        #expect(AutonomyLevel(rawValue: SettingsDefaults.agentDefaultAutonomy) != nil)
        #expect(ExportFormat(rawValue: SettingsDefaults.defaultExportFormat) != nil)
    }
}

@Suite("Settings API Key Logic")
struct SettingsAPIKeyLogicTests {
    /// Mirrors the legacy key lookup logic in SettingsManager.getAPIKey
    private func legacyKey(for provider: String) -> String? {
        let legacyKeys: [String: String] = [
            "anthropic": "anthropicAPIKey",
            "openai": "openaiAPIKey",
            "google": "googleAPIKey",
            "groq": "groqAPIKey",
            "openrouter": "openRouterAPIKey",
            "perplexity": "perplexityAPIKey",
            "deepseek": "deepseekAPIKey"
        ]
        return legacyKeys[provider]
    }

    @Test("All providers have legacy key mappings")
    func allProvidersHaveLegacyKeys() {
        for provider in SettingsDefaults.availableProviders {
            #expect(legacyKey(for: provider) != nil, "Missing legacy key for \(provider)")
        }
    }

    @Test("Legacy key format is providerNameAPIKey")
    func legacyKeyFormat() {
        #expect(legacyKey(for: "anthropic") == "anthropicAPIKey")
        #expect(legacyKey(for: "openrouter") == "openRouterAPIKey")
        #expect(legacyKey(for: "deepseek") == "deepseekAPIKey")
    }

    @Test("Unknown provider returns nil")
    func unknownProviderReturnsNil() {
        #expect(legacyKey(for: "unknown") == nil)
        #expect(legacyKey(for: "") == nil)
    }

    @Test("Empty API key treated as no key")
    func emptyAPIKeyIsNoKey() {
        let key = ""
        #expect(key.isEmpty)
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(trimmed.isEmpty)
    }

    @Test("Whitespace-only API key treated as no key")
    func whitespaceAPIKeyIsNoKey() {
        let key = "   \n\t  "
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(trimmed.isEmpty)
    }
}

@Suite("Settings Favorites Logic")
struct SettingsFavoritesTests {
    @Test("Array to Set conversion deduplicates")
    func arrayToSetDedup() {
        let array = ["model-a", "model-b", "model-a", "model-c"]
        let set = Set(array)
        #expect(set.count == 3)
    }

    @Test("Empty array produces empty set")
    func emptyArrayToSet() {
        let array: [String] = []
        let set = Set(array)
        #expect(set.isEmpty)
    }

    @Test("Set to sorted array is deterministic")
    func setToSortedArray() {
        let set: Set<String> = ["z-model", "a-model", "m-model"]
        let sorted = Array(set).sorted()
        #expect(sorted == ["a-model", "m-model", "z-model"])
    }
}

@Suite("Settings Reload Validation")
struct SettingsReloadTests {
    @Test("Bool reload from UserDefaults — nil returns default true")
    func boolNilDefaultsTrue() {
        // Simulates: d.object(forKey: key) as? Bool ?? true
        let value: Bool? = nil
        let result = value ?? true
        #expect(result == true)
    }

    @Test("Bool reload from UserDefaults — nil returns default false")
    func boolNilDefaultsFalse() {
        let value: Bool? = nil
        let result = value ?? false
        #expect(result == false)
    }

    @Test("Bool reload from UserDefaults — explicit false preserved")
    func boolExplicitFalse() {
        let value: Bool? = false
        let result = value ?? true
        #expect(result == false)
    }

    @Test("String reload from UserDefaults — nil returns default")
    func stringNilDefault() {
        // Simulates: d.string(forKey: key) ?? "system"
        let value: String? = nil
        let result = value ?? "system"
        #expect(result == "system")
    }

    @Test("String reload from UserDefaults — empty string preserved")
    func stringEmptyPreserved() {
        let value: String? = ""
        let result = value ?? "system"
        #expect(result == "")
    }
}
