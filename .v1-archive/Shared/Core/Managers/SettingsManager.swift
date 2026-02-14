import Combine
import Foundation

@MainActor
final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    // AI Provider Settings
    @Published var defaultProvider: String {
        didSet { UserDefaults.standard.set(defaultProvider, forKey: "defaultProvider") }
    }

    @Published var streamResponses: Bool {
        didSet { UserDefaults.standard.set(streamResponses, forKey: "streamResponses") }
    }

    let availableProviders: [String] = ["openai", "anthropic", "google", "perplexity", "groq", "openrouter"]

    // Appearance Settings
    @Published var theme: String {
        didSet { UserDefaults.standard.set(theme, forKey: "theme") }
    }

    @Published var fontSize: String {
        didSet { UserDefaults.standard.set(fontSize, forKey: "fontSize") }
    }

    // Privacy Settings
    @Published var iCloudSyncEnabled: Bool {
        didSet { UserDefaults.standard.set(iCloudSyncEnabled, forKey: "iCloudSyncEnabled") }
    }

    @Published var analyticsEnabled: Bool {
        didSet { UserDefaults.standard.set(analyticsEnabled, forKey: "analyticsEnabled") }
    }

    @Published var handoffEnabled: Bool {
        didSet { UserDefaults.standard.set(handoffEnabled, forKey: "handoffEnabled") }
    }

    // Behavior Settings
    @Published var launchAtLogin: Bool {
        didSet { UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin") }
    }

    @Published var showInMenuBar: Bool {
        didSet { UserDefaults.standard.set(showInMenuBar, forKey: "showInMenuBar") }
    }

    @Published var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled") }
    }

    // Window Behavior Settings
    @Published var windowFloatOnTop: Bool {
        didSet { UserDefaults.standard.set(windowFloatOnTop, forKey: "windowFloatOnTop") }
    }

    @Published var rememberWindowPosition: Bool {
        didSet { UserDefaults.standard.set(rememberWindowPosition, forKey: "rememberWindowPosition") }
    }

    @Published var defaultWindowSize: String {
        didSet { UserDefaults.standard.set(defaultWindowSize, forKey: "defaultWindowSize") }
    }

    // Message Display Settings
    @Published var messageDensity: String {
        didSet { UserDefaults.standard.set(messageDensity, forKey: "messageDensity") }
    }

    @Published var timestampDisplay: String {
        didSet { UserDefaults.standard.set(timestampDisplay, forKey: "timestampDisplay") }
    }

    @Published var autoScrollToBottom: Bool {
        didSet { UserDefaults.standard.set(autoScrollToBottom, forKey: "autoScrollToBottom") }
    }

    // Startup Settings
    @Published var showSidebarOnLaunch: Bool {
        didSet { UserDefaults.standard.set(showSidebarOnLaunch, forKey: "showSidebarOnLaunch") }
    }

    @Published var restoreLastSession: Bool {
        didSet { UserDefaults.standard.set(restoreLastSession, forKey: "restoreLastSession") }
    }

    // Voice Settings
    @Published var readResponsesAloud: Bool {
        didSet { UserDefaults.standard.set(readResponsesAloud, forKey: "readResponsesAloud") }
    }

    @Published var selectedVoice: String {
        didSet { UserDefaults.standard.set(selectedVoice, forKey: "selectedVoice") }
    }

    // Advanced Settings
    @Published var debugMode: Bool {
        didSet { UserDefaults.standard.set(debugMode, forKey: "debugMode") }
    }

    @Published var showPerformanceMetrics: Bool {
        didSet { UserDefaults.standard.set(showPerformanceMetrics, forKey: "showPerformanceMetrics") }
    }

    @Published var betaFeaturesEnabled: Bool {
        didSet { UserDefaults.standard.set(betaFeaturesEnabled, forKey: "betaFeaturesEnabled") }
    }

    // Local Models Settings
    @Published var mlxModelsPath: String {
        didSet { UserDefaults.standard.set(mlxModelsPath, forKey: "mlxModelsPath") }
    }

    @Published var ollamaEnabled: Bool {
        didSet { UserDefaults.standard.set(ollamaEnabled, forKey: "ollamaEnabled") }
    }

    @Published var ollamaURL: String {
        didSet { UserDefaults.standard.set(ollamaURL, forKey: "ollamaURL") }
    }

    // Self-Execution Settings
    @Published var executionMode: String {
        didSet { UserDefaults.standard.set(executionMode, forKey: "executionMode") }
    }

    @Published var allowFileCreation: Bool {
        didSet { UserDefaults.standard.set(allowFileCreation, forKey: "allowFileCreation") }
    }

    @Published var allowFileEditing: Bool {
        didSet { UserDefaults.standard.set(allowFileEditing, forKey: "allowFileEditing") }
    }

    @Published var allowCodeExecution: Bool {
        didSet { UserDefaults.standard.set(allowCodeExecution, forKey: "allowCodeExecution") }
    }

    @Published var allowExternalAPICalls: Bool {
        didSet { UserDefaults.standard.set(allowExternalAPICalls, forKey: "allowExternalAPICalls") }
    }

    @Published var requireDestructiveApproval: Bool {
        didSet { UserDefaults.standard.set(requireDestructiveApproval, forKey: "requireDestructiveApproval") }
    }

    @Published var enableRollback: Bool {
        didSet { UserDefaults.standard.set(enableRollback, forKey: "enableRollback") }
    }

    @Published var createBackups: Bool {
        didSet { UserDefaults.standard.set(createBackups, forKey: "createBackups") }
    }

    @Published var preventSleepDuringExecution: Bool {
        didSet { UserDefaults.standard.set(preventSleepDuringExecution, forKey: "preventSleepDuringExecution") }
    }

    @Published var maxConcurrentTasks: Int {
        didSet { UserDefaults.standard.set(maxConcurrentTasks, forKey: "maxConcurrentTasks") }
    }

    // Favorite Models
    @Published var favoriteModels: Set<String> {
        didSet {
            let array = Array(favoriteModels)
            UserDefaults.standard.set(array, forKey: "favoriteModels")
        }
    }

    private init() {
        defaultProvider = UserDefaults.standard.string(forKey: "defaultProvider") ?? "openrouter"
        // Use object(forKey:) to distinguish between "never set" (nil) and "set to false"
        streamResponses = UserDefaults.standard.object(forKey: "streamResponses") as? Bool ?? true
        theme = UserDefaults.standard.string(forKey: "theme") ?? "system"
        fontSize = UserDefaults.standard.string(forKey: "fontSize") ?? "medium"
        iCloudSyncEnabled = UserDefaults.standard.object(forKey: "iCloudSyncEnabled") as? Bool ?? true
        analyticsEnabled = UserDefaults.standard.bool(forKey: "analyticsEnabled")
        handoffEnabled = UserDefaults.standard.object(forKey: "handoffEnabled") as? Bool ?? true

        // Behavior
        launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
        showInMenuBar = UserDefaults.standard.object(forKey: "showInMenuBar") as? Bool ?? true
        notificationsEnabled = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true

        // Window Behavior
        windowFloatOnTop = UserDefaults.standard.bool(forKey: "windowFloatOnTop")
        rememberWindowPosition = UserDefaults.standard.object(forKey: "rememberWindowPosition") as? Bool ?? true
        defaultWindowSize = UserDefaults.standard.string(forKey: "defaultWindowSize") ?? "default"

        // Message Display
        messageDensity = UserDefaults.standard.string(forKey: "messageDensity") ?? "comfortable"
        timestampDisplay = UserDefaults.standard.string(forKey: "timestampDisplay") ?? "relative"
        autoScrollToBottom = UserDefaults.standard.object(forKey: "autoScrollToBottom") as? Bool ?? true

        // Startup
        showSidebarOnLaunch = UserDefaults.standard.object(forKey: "showSidebarOnLaunch") as? Bool ?? true
        restoreLastSession = UserDefaults.standard.bool(forKey: "restoreLastSession")

        // Voice
        readResponsesAloud = UserDefaults.standard.bool(forKey: "readResponsesAloud")
        selectedVoice = UserDefaults.standard.string(forKey: "selectedVoice") ?? "default"

        // Advanced
        debugMode = UserDefaults.standard.bool(forKey: "debugMode")
        showPerformanceMetrics = UserDefaults.standard.bool(forKey: "showPerformanceMetrics")
        betaFeaturesEnabled = UserDefaults.standard.bool(forKey: "betaFeaturesEnabled")

        // Local Models
        mlxModelsPath = UserDefaults.standard.string(forKey: "mlxModelsPath") ?? "~/.cache/huggingface/hub/"
        ollamaEnabled = UserDefaults.standard.bool(forKey: "ollamaEnabled")
        ollamaURL = UserDefaults.standard.string(forKey: "ollamaURL") ?? "http://localhost:11434"

        // Self-Execution
        executionMode = UserDefaults.standard.string(forKey: "executionMode") ?? "manual"
        allowFileCreation = UserDefaults.standard.bool(forKey: "allowFileCreation")
        allowFileEditing = UserDefaults.standard.bool(forKey: "allowFileEditing")
        allowCodeExecution = UserDefaults.standard.bool(forKey: "allowCodeExecution")
        allowExternalAPICalls = UserDefaults.standard.bool(forKey: "allowExternalAPICalls")
        requireDestructiveApproval = UserDefaults.standard.object(forKey: "requireDestructiveApproval") as? Bool ?? true
        enableRollback = UserDefaults.standard.object(forKey: "enableRollback") as? Bool ?? true
        createBackups = UserDefaults.standard.object(forKey: "createBackups") as? Bool ?? true
        preventSleepDuringExecution = UserDefaults.standard.object(forKey: "preventSleepDuringExecution") as? Bool ?? true
        maxConcurrentTasks = UserDefaults.standard.integer(forKey: "maxConcurrentTasks") != 0 ? UserDefaults.standard.integer(forKey: "maxConcurrentTasks") : 3

        // Favorite Models
        if let savedFavorites = UserDefaults.standard.array(forKey: "favoriteModels") as? [String] {
            favoriteModels = Set(savedFavorites)
        } else {
            favoriteModels = []
        }
    }

    // API Key Management - SECURITY: Uses Keychain via SecureStorage
    // Format: "apikey.\(provider)" stored in Keychain
    func getAPIKey(for provider: String) -> String? {
        // SECURITY: Always use Keychain for API keys
        if let key = try? SecureStorage.shared.loadAPIKey(for: provider), !key.isEmpty {
            return key
        }

        // Migration: check old UserDefaults format and migrate to Keychain
        if let oldKey = UserDefaults.standard.string(forKey: "\(provider)_api_key"), !oldKey.isEmpty {
            // Migrate to Keychain
            try? SecureStorage.shared.saveAPIKey(oldKey, for: provider)
            UserDefaults.standard.removeObject(forKey: "\(provider)_api_key")
            print("✅ Migrated API key for \(provider) from UserDefaults to Keychain")
            return oldKey
        }

        // Also check legacy format
        if let legacyKey = UserDefaults.standard.string(forKey: "apiKey_\(provider)"), !legacyKey.isEmpty {
            // Migrate to Keychain
            try? SecureStorage.shared.saveAPIKey(legacyKey, for: provider)
            UserDefaults.standard.removeObject(forKey: "apiKey_\(provider)")
            print("✅ Migrated legacy API key for \(provider) from UserDefaults to Keychain")
            return legacyKey
        }

        return nil
    }

    func setAPIKey(_ key: String, for provider: String) {
        do {
            // SECURITY: Store in Keychain, not UserDefaults
            try SecureStorage.shared.saveAPIKey(key, for: provider)
            // Clean up any legacy UserDefaults entries
            UserDefaults.standard.removeObject(forKey: "\(provider)_api_key")
            UserDefaults.standard.removeObject(forKey: "apiKey_\(provider)")
            print("✅ API key saved securely for \(provider)")
        } catch {
            print("❌ Failed to save API key for \(provider): \(error)")
        }
    }

    func deleteAPIKey(for provider: String) {
        do {
            // SECURITY: Remove from Keychain
            try SecureStorage.shared.deleteAPIKey(for: provider)
            // Also clean up legacy UserDefaults entries
            UserDefaults.standard.removeObject(forKey: "\(provider)_api_key")
            UserDefaults.standard.removeObject(forKey: "apiKey_\(provider)")
            print("✅ API key deleted for \(provider)")
        } catch {
            print("❌ Failed to delete API key for \(provider): \(error)")
        }
    }

    func hasAPIKey(for provider: String) -> Bool {
        // Check Keychain first
        if SecureStorage.shared.hasAPIKey(for: provider) {
            return true
        }
        // Also check if migration is needed from UserDefaults
        return getAPIKey(for: provider) != nil
    }

    func resetToDefaults() {
        // Reset all settings to defaults
        defaultProvider = "openrouter"
        streamResponses = true
        theme = "system"
        fontSize = "medium"
        iCloudSyncEnabled = false
        analyticsEnabled = false
        handoffEnabled = true

        launchAtLogin = false
        showInMenuBar = true
        notificationsEnabled = true

        // Window Behavior
        windowFloatOnTop = false
        rememberWindowPosition = true
        defaultWindowSize = "default"

        // Message Display
        messageDensity = "comfortable"
        timestampDisplay = "relative"
        autoScrollToBottom = true

        // Startup
        showSidebarOnLaunch = true
        restoreLastSession = false

        readResponsesAloud = false
        selectedVoice = "default"

        debugMode = false
        showPerformanceMetrics = false
        betaFeaturesEnabled = false

        mlxModelsPath = "~/.cache/huggingface/hub/"
        ollamaEnabled = false
        ollamaURL = "http://localhost:11434"

        executionMode = "manual"
        allowFileCreation = false
        allowFileEditing = false
        allowCodeExecution = false
        allowExternalAPICalls = false
        requireDestructiveApproval = true
        enableRollback = true
        createBackups = true
        preventSleepDuringExecution = true
        maxConcurrentTasks = 3

        // Clear API keys
        for provider in availableProviders {
            deleteAPIKey(for: provider)
        }
    }
}
