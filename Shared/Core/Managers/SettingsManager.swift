import Foundation
import Combine

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

    private init() {
        self.defaultProvider = UserDefaults.standard.string(forKey: "defaultProvider") ?? "openrouter"
        self.streamResponses = UserDefaults.standard.bool(forKey: "streamResponses")
        self.theme = UserDefaults.standard.string(forKey: "theme") ?? "system"
        self.fontSize = UserDefaults.standard.string(forKey: "fontSize") ?? "medium"
        self.iCloudSyncEnabled = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
        self.analyticsEnabled = UserDefaults.standard.bool(forKey: "analyticsEnabled")
        self.handoffEnabled = UserDefaults.standard.bool(forKey: "handoffEnabled")

        // Behavior
        self.launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
        self.showInMenuBar = UserDefaults.standard.bool(forKey: "showInMenuBar")
        self.notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")

        // Voice
        self.readResponsesAloud = UserDefaults.standard.bool(forKey: "readResponsesAloud")
        self.selectedVoice = UserDefaults.standard.string(forKey: "selectedVoice") ?? "default"

        // Advanced
        self.debugMode = UserDefaults.standard.bool(forKey: "debugMode")
        self.showPerformanceMetrics = UserDefaults.standard.bool(forKey: "showPerformanceMetrics")
        self.betaFeaturesEnabled = UserDefaults.standard.bool(forKey: "betaFeaturesEnabled")

        // Local Models
        self.mlxModelsPath = UserDefaults.standard.string(forKey: "mlxModelsPath") ?? "~/.cache/huggingface/hub/"
        self.ollamaEnabled = UserDefaults.standard.bool(forKey: "ollamaEnabled")
        self.ollamaURL = UserDefaults.standard.string(forKey: "ollamaURL") ?? "http://localhost:11434"

        // Self-Execution
        self.executionMode = UserDefaults.standard.string(forKey: "executionMode") ?? "manual"
        self.allowFileCreation = UserDefaults.standard.bool(forKey: "allowFileCreation")
        self.allowFileEditing = UserDefaults.standard.bool(forKey: "allowFileEditing")
        self.allowCodeExecution = UserDefaults.standard.bool(forKey: "allowCodeExecution")
        self.allowExternalAPICalls = UserDefaults.standard.bool(forKey: "allowExternalAPICalls")
        self.requireDestructiveApproval = UserDefaults.standard.bool(forKey: "requireDestructiveApproval")
        self.enableRollback = UserDefaults.standard.bool(forKey: "enableRollback")
        self.createBackups = UserDefaults.standard.bool(forKey: "createBackups")
        self.preventSleepDuringExecution = UserDefaults.standard.bool(forKey: "preventSleepDuringExecution")
        self.maxConcurrentTasks = UserDefaults.standard.integer(forKey: "maxConcurrentTasks") != 0 ? UserDefaults.standard.integer(forKey: "maxConcurrentTasks") : 3
    }

    // API Key Management - Using consistent key naming for compatibility with SelfExecutionConfiguration
    // Format: "\(provider)_api_key" (e.g., "openrouter_api_key", "anthropic_api_key")
    func getAPIKey(for provider: String) -> String? {
        // Try new format first, then old format for backwards compatibility
        if let key = UserDefaults.standard.string(forKey: "\(provider)_api_key"), !key.isEmpty {
            return key
        }
        // Migration: check old format
        if let oldKey = UserDefaults.standard.string(forKey: "apiKey_\(provider)"), !oldKey.isEmpty {
            // Migrate to new format
            UserDefaults.standard.set(oldKey, forKey: "\(provider)_api_key")
            UserDefaults.standard.removeObject(forKey: "apiKey_\(provider)")
            print("✅ Migrated API key for \(provider) to new format")
            return oldKey
        }
        return nil
    }

    func setAPIKey(_ key: String, for provider: String) {
        UserDefaults.standard.set(key, forKey: "\(provider)_api_key")
        UserDefaults.standard.synchronize()
        print("✅ API key saved for \(provider)")
    }

    func deleteAPIKey(for provider: String) {
        UserDefaults.standard.removeObject(forKey: "\(provider)_api_key")
        UserDefaults.standard.removeObject(forKey: "apiKey_\(provider)") // Clean old format too
        UserDefaults.standard.synchronize()
        print("✅ API key deleted for \(provider)")
    }

    func hasAPIKey(for provider: String) -> Bool {
        guard let key = getAPIKey(for: provider) else { return false }
        return !key.isEmpty
    }
}
