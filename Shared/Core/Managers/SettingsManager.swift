import Combine
import Foundation
#if os(macOS)
import ServiceManagement
#endif

@MainActor
final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    // MARK: - Sync Engine

    private let syncEngine = PreferenceSyncEngine.shared
    private var syncObserver: AnyCancellable?

    /// Persist locally and push to iCloud via the sync engine.
    private func persist(_ value: Any, forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "\(key).__localTS")
        syncEngine.push(value, forKey: key)
    }

    // MARK: - AI Provider Settings

    @Published var defaultProvider: String {
        didSet { persist(defaultProvider, forKey: "defaultProvider") }
    }

    @Published var streamResponses: Bool {
        didSet { persist(streamResponses, forKey: "streamResponses") }
    }

    let availableProviders: [String] = ["openai", "anthropic", "google", "perplexity", "groq", "openrouter"]

    // MARK: - Appearance Settings

    @Published var theme: String {
        didSet { persist(theme, forKey: "theme") }
    }

    @Published var fontSize: String {
        didSet { persist(fontSize, forKey: "fontSize") }
    }

    // MARK: - Privacy Settings

    @Published var iCloudSyncEnabled: Bool {
        didSet { persist(iCloudSyncEnabled, forKey: "iCloudSyncEnabled") }
    }

    @Published var analyticsEnabled: Bool {
        didSet { persist(analyticsEnabled, forKey: "analyticsEnabled") }
    }

    @Published var handoffEnabled: Bool {
        didSet { persist(handoffEnabled, forKey: "handoffEnabled") }
    }

    /// When enabled, outbound messages to cloud AI providers pass through OutboundPrivacyGuard
    @Published var cloudAPIPrivacyGuardEnabled: Bool {
        didSet { persist(cloudAPIPrivacyGuardEnabled, forKey: "cloudAPIPrivacyGuardEnabled") }
    }

    // MARK: - Behavior Settings

    @Published var launchAtLogin: Bool {
        didSet {
            persist(launchAtLogin, forKey: "launchAtLogin")
            #if os(macOS)
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // Registration can fail if not properly entitled; log but don't crash
                print("Login item registration failed: \(error.localizedDescription)")
            }
            #endif
        }
    }

    @Published var showInMenuBar: Bool {
        didSet { persist(showInMenuBar, forKey: "showInMenuBar") }
    }

    @Published var notificationsEnabled: Bool {
        didSet { persist(notificationsEnabled, forKey: "notificationsEnabled") }
    }

    // MARK: - Window Behavior Settings

    @Published var windowFloatOnTop: Bool {
        didSet { persist(windowFloatOnTop, forKey: "windowFloatOnTop") }
    }

    @Published var rememberWindowPosition: Bool {
        didSet { persist(rememberWindowPosition, forKey: "rememberWindowPosition") }
    }

    @Published var defaultWindowSize: String {
        didSet { persist(defaultWindowSize, forKey: "defaultWindowSize") }
    }

    // MARK: - Message Display Settings

    @Published var messageDensity: String {
        didSet { persist(messageDensity, forKey: "messageDensity") }
    }

    @Published var timestampDisplay: String {
        didSet { persist(timestampDisplay, forKey: "timestampDisplay") }
    }

    @Published var autoScrollToBottom: Bool {
        didSet { persist(autoScrollToBottom, forKey: "autoScrollToBottom") }
    }

    // MARK: - Startup Settings

    @Published var showSidebarOnLaunch: Bool {
        didSet { persist(showSidebarOnLaunch, forKey: "showSidebarOnLaunch") }
    }

    @Published var restoreLastSession: Bool {
        didSet { persist(restoreLastSession, forKey: "restoreLastSession") }
    }

    // MARK: - Voice Settings

    @Published var readResponsesAloud: Bool {
        didSet { persist(readResponsesAloud, forKey: "readResponsesAloud") }
    }

    @Published var selectedVoice: String {
        didSet { persist(selectedVoice, forKey: "selectedVoice") }
    }

    // MARK: - Advanced Settings

    @Published var debugMode: Bool {
        didSet { persist(debugMode, forKey: "debugMode") }
    }

    @Published var showPerformanceMetrics: Bool {
        didSet { persist(showPerformanceMetrics, forKey: "showPerformanceMetrics") }
    }

    @Published var betaFeaturesEnabled: Bool {
        didSet { persist(betaFeaturesEnabled, forKey: "betaFeaturesEnabled") }
    }

    // MARK: - Local Models Settings

    @Published var preferLocalModels: Bool {
        didSet { persist(preferLocalModels, forKey: "preferLocalModels") }
    }

    @Published var mlxModelsPath: String {
        didSet { persist(mlxModelsPath, forKey: "mlxModelsPath") }
    }

    @Published var ollamaEnabled: Bool {
        didSet { persist(ollamaEnabled, forKey: "ollamaEnabled") }
    }

    @Published var ollamaURL: String {
        didSet { persist(ollamaURL, forKey: "ollamaURL") }
    }

    // MARK: - Self-Execution Settings

    @Published var executionMode: String {
        didSet { persist(executionMode, forKey: "executionMode") }
    }

    @Published var allowFileCreation: Bool {
        didSet { persist(allowFileCreation, forKey: "allowFileCreation") }
    }

    @Published var allowFileEditing: Bool {
        didSet { persist(allowFileEditing, forKey: "allowFileEditing") }
    }

    @Published var allowCodeExecution: Bool {
        didSet { persist(allowCodeExecution, forKey: "allowCodeExecution") }
    }

    @Published var allowExternalAPICalls: Bool {
        didSet { persist(allowExternalAPICalls, forKey: "allowExternalAPICalls") }
    }

    @Published var requireDestructiveApproval: Bool {
        didSet { persist(requireDestructiveApproval, forKey: "requireDestructiveApproval") }
    }

    @Published var enableRollback: Bool {
        didSet { persist(enableRollback, forKey: "enableRollback") }
    }

    @Published var createBackups: Bool {
        didSet { persist(createBackups, forKey: "createBackups") }
    }

    @Published var preventSleepDuringExecution: Bool {
        didSet { persist(preventSleepDuringExecution, forKey: "preventSleepDuringExecution") }
    }

    @Published var maxConcurrentTasks: Int {
        didSet { persist(maxConcurrentTasks, forKey: "maxConcurrentTasks") }
    }

    // MARK: - Input Settings

    @Published var submitShortcut: String {
        didSet { persist(submitShortcut, forKey: "submitShortcut") }
    }

    // MARK: - Notification Settings

    @Published var notifyOnResponseComplete: Bool {
        didSet { persist(notifyOnResponseComplete, forKey: "notifyOnResponseComplete") }
    }

    @Published var notifyOnAttentionRequired: Bool {
        didSet { persist(notifyOnAttentionRequired, forKey: "notifyOnAttentionRequired") }
    }

    @Published var playNotificationSound: Bool {
        didSet { persist(playNotificationSound, forKey: "playNotificationSound") }
    }

    @Published var showDockBadge: Bool {
        didSet { persist(showDockBadge, forKey: "showDockBadge") }
    }

    @Published var doNotDisturb: Bool {
        didSet { persist(doNotDisturb, forKey: "doNotDisturb") }
    }

    // MARK: - Moltbook Agent Settings

    @Published var moltbookAgentEnabled: Bool {
        didSet { persist(moltbookAgentEnabled, forKey: "moltbookAgentEnabled") }
    }

    @Published var moltbookPreviewMode: Bool {
        didSet { persist(moltbookPreviewMode, forKey: "moltbookPreviewMode") }
    }

    @Published var moltbookMaxDailyPosts: Int {
        didSet { persist(moltbookMaxDailyPosts, forKey: "moltbookMaxDailyPosts") }
    }

    // MARK: - Focus & Search Settings

    @Published var activeFocusMode: String {
        didSet { persist(activeFocusMode, forKey: "activeFocusMode") }
    }

    @Published var enableSemanticSearch: Bool {
        didSet { persist(enableSemanticSearch, forKey: "enableSemanticSearch") }
    }

    // MARK: - Export Settings

    @Published var defaultExportFormat: String {
        didSet { persist(defaultExportFormat, forKey: "defaultExportFormat") }
    }

    // MARK: - Favorite Models

    @Published var favoriteModels: Set<String> {
        didSet {
            let array = Array(favoriteModels)
            persist(array, forKey: "favoriteModels")
        }
    }

    // MARK: - Init

    private init() {
        defaultProvider = UserDefaults.standard.string(forKey: "defaultProvider") ?? "openrouter"
        streamResponses = UserDefaults.standard.object(forKey: "streamResponses") as? Bool ?? true
        theme = UserDefaults.standard.string(forKey: "theme") ?? "system"
        fontSize = UserDefaults.standard.string(forKey: "fontSize") ?? "medium"
        iCloudSyncEnabled = UserDefaults.standard.object(forKey: "iCloudSyncEnabled") as? Bool ?? true
        analyticsEnabled = UserDefaults.standard.bool(forKey: "analyticsEnabled")
        handoffEnabled = UserDefaults.standard.object(forKey: "handoffEnabled") as? Bool ?? true
        cloudAPIPrivacyGuardEnabled = UserDefaults.standard.bool(forKey: "cloudAPIPrivacyGuardEnabled")

        launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
        showInMenuBar = UserDefaults.standard.object(forKey: "showInMenuBar") as? Bool ?? true
        notificationsEnabled = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true

        windowFloatOnTop = UserDefaults.standard.bool(forKey: "windowFloatOnTop")
        rememberWindowPosition = UserDefaults.standard.object(forKey: "rememberWindowPosition") as? Bool ?? true
        defaultWindowSize = UserDefaults.standard.string(forKey: "defaultWindowSize") ?? "default"

        messageDensity = UserDefaults.standard.string(forKey: "messageDensity") ?? "comfortable"
        timestampDisplay = UserDefaults.standard.string(forKey: "timestampDisplay") ?? "relative"
        autoScrollToBottom = UserDefaults.standard.object(forKey: "autoScrollToBottom") as? Bool ?? true

        showSidebarOnLaunch = UserDefaults.standard.object(forKey: "showSidebarOnLaunch") as? Bool ?? true
        restoreLastSession = UserDefaults.standard.bool(forKey: "restoreLastSession")

        readResponsesAloud = UserDefaults.standard.bool(forKey: "readResponsesAloud")
        selectedVoice = UserDefaults.standard.string(forKey: "selectedVoice") ?? "default"

        debugMode = UserDefaults.standard.bool(forKey: "debugMode")
        showPerformanceMetrics = UserDefaults.standard.bool(forKey: "showPerformanceMetrics")
        betaFeaturesEnabled = UserDefaults.standard.bool(forKey: "betaFeaturesEnabled")

        preferLocalModels = UserDefaults.standard.bool(forKey: "preferLocalModels")
        mlxModelsPath = UserDefaults.standard.string(forKey: "mlxModelsPath") ?? "~/.cache/huggingface/hub/"
        ollamaEnabled = UserDefaults.standard.bool(forKey: "ollamaEnabled")
        ollamaURL = UserDefaults.standard.string(forKey: "ollamaURL") ?? "http://localhost:11434"

        executionMode = UserDefaults.standard.string(forKey: "executionMode") ?? "manual"
        allowFileCreation = UserDefaults.standard.bool(forKey: "allowFileCreation")
        allowFileEditing = UserDefaults.standard.bool(forKey: "allowFileEditing")
        allowCodeExecution = UserDefaults.standard.bool(forKey: "allowCodeExecution")
        allowExternalAPICalls = UserDefaults.standard.bool(forKey: "allowExternalAPICalls")
        requireDestructiveApproval = UserDefaults.standard.object(forKey: "requireDestructiveApproval") as? Bool ?? true
        enableRollback = UserDefaults.standard.object(forKey: "enableRollback") as? Bool ?? true
        createBackups = UserDefaults.standard.object(forKey: "createBackups") as? Bool ?? true
        preventSleepDuringExecution = UserDefaults.standard.object(forKey: "preventSleepDuringExecution") as? Bool ?? true
        maxConcurrentTasks = UserDefaults.standard.integer(forKey: "maxConcurrentTasks") != 0
            ? UserDefaults.standard.integer(forKey: "maxConcurrentTasks") : 3

        submitShortcut = UserDefaults.standard.string(forKey: "submitShortcut") ?? "enter"
        notifyOnResponseComplete = UserDefaults.standard.object(forKey: "notifyOnResponseComplete") as? Bool ?? true
        notifyOnAttentionRequired = UserDefaults.standard.object(forKey: "notifyOnAttentionRequired") as? Bool ?? true
        playNotificationSound = UserDefaults.standard.object(forKey: "playNotificationSound") as? Bool ?? true
        showDockBadge = UserDefaults.standard.object(forKey: "showDockBadge") as? Bool ?? true
        doNotDisturb = UserDefaults.standard.bool(forKey: "doNotDisturb")
        moltbookAgentEnabled = UserDefaults.standard.bool(forKey: "moltbookAgentEnabled")
        moltbookPreviewMode = UserDefaults.standard.object(forKey: "moltbookPreviewMode") as? Bool ?? true
        moltbookMaxDailyPosts = UserDefaults.standard.integer(forKey: "moltbookMaxDailyPosts") != 0
            ? UserDefaults.standard.integer(forKey: "moltbookMaxDailyPosts") : 10

        activeFocusMode = UserDefaults.standard.string(forKey: "activeFocusMode") ?? "general"
        enableSemanticSearch = UserDefaults.standard.object(forKey: "enableSemanticSearch") as? Bool ?? true
        defaultExportFormat = UserDefaults.standard.string(forKey: "defaultExportFormat") ?? "markdown"

        if let savedFavorites = UserDefaults.standard.array(forKey: "favoriteModels") as? [String] {
            favoriteModels = Set(savedFavorites)
        } else {
            favoriteModels = []
        }

        // Listen for sync engine pull events to reload values from UserDefaults
        syncObserver = NotificationCenter.default
            .publisher(for: .preferenceSyncDidPull)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.reloadFromDefaults()
            }
    }

    // MARK: - Reload from Defaults (after sync pull)

    /// Re-reads every @Published property from UserDefaults after the sync
    /// engine writes new cloud values into local storage.
    func reloadFromDefaults() {
        let d = UserDefaults.standard

        defaultProvider = d.string(forKey: "defaultProvider") ?? "openrouter"
        streamResponses = d.object(forKey: "streamResponses") as? Bool ?? true
        theme = d.string(forKey: "theme") ?? "system"
        fontSize = d.string(forKey: "fontSize") ?? "medium"
        iCloudSyncEnabled = d.object(forKey: "iCloudSyncEnabled") as? Bool ?? true
        analyticsEnabled = d.bool(forKey: "analyticsEnabled")
        handoffEnabled = d.object(forKey: "handoffEnabled") as? Bool ?? true
        cloudAPIPrivacyGuardEnabled = d.bool(forKey: "cloudAPIPrivacyGuardEnabled")
        launchAtLogin = d.bool(forKey: "launchAtLogin")
        showInMenuBar = d.object(forKey: "showInMenuBar") as? Bool ?? true
        notificationsEnabled = d.object(forKey: "notificationsEnabled") as? Bool ?? true
        windowFloatOnTop = d.bool(forKey: "windowFloatOnTop")
        rememberWindowPosition = d.object(forKey: "rememberWindowPosition") as? Bool ?? true
        defaultWindowSize = d.string(forKey: "defaultWindowSize") ?? "default"
        messageDensity = d.string(forKey: "messageDensity") ?? "comfortable"
        timestampDisplay = d.string(forKey: "timestampDisplay") ?? "relative"
        autoScrollToBottom = d.object(forKey: "autoScrollToBottom") as? Bool ?? true
        showSidebarOnLaunch = d.object(forKey: "showSidebarOnLaunch") as? Bool ?? true
        restoreLastSession = d.bool(forKey: "restoreLastSession")
        readResponsesAloud = d.bool(forKey: "readResponsesAloud")
        selectedVoice = d.string(forKey: "selectedVoice") ?? "default"
        debugMode = d.bool(forKey: "debugMode")
        showPerformanceMetrics = d.bool(forKey: "showPerformanceMetrics")
        betaFeaturesEnabled = d.bool(forKey: "betaFeaturesEnabled")
        preferLocalModels = d.bool(forKey: "preferLocalModels")
        mlxModelsPath = d.string(forKey: "mlxModelsPath") ?? "~/.cache/huggingface/hub/"
        ollamaEnabled = d.bool(forKey: "ollamaEnabled")
        ollamaURL = d.string(forKey: "ollamaURL") ?? "http://localhost:11434"
        executionMode = d.string(forKey: "executionMode") ?? "manual"
        allowFileCreation = d.bool(forKey: "allowFileCreation")
        allowFileEditing = d.bool(forKey: "allowFileEditing")
        allowCodeExecution = d.bool(forKey: "allowCodeExecution")
        allowExternalAPICalls = d.bool(forKey: "allowExternalAPICalls")
        requireDestructiveApproval = d.object(forKey: "requireDestructiveApproval") as? Bool ?? true
        enableRollback = d.object(forKey: "enableRollback") as? Bool ?? true
        createBackups = d.object(forKey: "createBackups") as? Bool ?? true
        preventSleepDuringExecution = d.object(forKey: "preventSleepDuringExecution") as? Bool ?? true
        maxConcurrentTasks = d.integer(forKey: "maxConcurrentTasks") != 0
            ? d.integer(forKey: "maxConcurrentTasks") : 3

        submitShortcut = d.string(forKey: "submitShortcut") ?? "enter"
        notifyOnResponseComplete = d.object(forKey: "notifyOnResponseComplete") as? Bool ?? true
        notifyOnAttentionRequired = d.object(forKey: "notifyOnAttentionRequired") as? Bool ?? true
        playNotificationSound = d.object(forKey: "playNotificationSound") as? Bool ?? true
        showDockBadge = d.object(forKey: "showDockBadge") as? Bool ?? true
        doNotDisturb = d.bool(forKey: "doNotDisturb")
        activeFocusMode = d.string(forKey: "activeFocusMode") ?? "general"
        enableSemanticSearch = d.object(forKey: "enableSemanticSearch") as? Bool ?? true
        defaultExportFormat = d.string(forKey: "defaultExportFormat") ?? "markdown"

        if let savedFavorites = d.array(forKey: "favoriteModels") as? [String] {
            favoriteModels = Set(savedFavorites)
        }

        // Re-apply font size after iCloud sync pull so AppConfiguration stays in sync
        AppConfiguration.applyFontSize(fontSize)
    }

    // MARK: - API Key Management (Keychain - NEVER synced to iCloud KVS)

    func getAPIKey(for provider: String) -> String? {
        if let key = try? SecureStorage.shared.loadAPIKey(for: provider), !key.isEmpty {
            return key
        }

        if let oldKey = UserDefaults.standard.string(forKey: "\(provider)_api_key"), !oldKey.isEmpty {
            try? SecureStorage.shared.saveAPIKey(oldKey, for: provider)
            UserDefaults.standard.removeObject(forKey: "\(provider)_api_key")
            return oldKey
        }

        if let legacyKey = UserDefaults.standard.string(forKey: "apiKey_\(provider)"), !legacyKey.isEmpty {
            try? SecureStorage.shared.saveAPIKey(legacyKey, for: provider)
            UserDefaults.standard.removeObject(forKey: "apiKey_\(provider)")
            return legacyKey
        }

        return nil
    }

    func setAPIKey(_ key: String, for provider: String) {
        do {
            try SecureStorage.shared.saveAPIKey(key, for: provider)
            UserDefaults.standard.removeObject(forKey: "\(provider)_api_key")
            UserDefaults.standard.removeObject(forKey: "apiKey_\(provider)")
        } catch {
            print("Failed to save API key for \(provider): \(error)")
        }
    }

    func deleteAPIKey(for provider: String) {
        do {
            try SecureStorage.shared.deleteAPIKey(for: provider)
            UserDefaults.standard.removeObject(forKey: "\(provider)_api_key")
            UserDefaults.standard.removeObject(forKey: "apiKey_\(provider)")
        } catch {
            print("Failed to delete API key for \(provider): \(error)")
        }
    }

    func hasAPIKey(for provider: String) -> Bool {
        if SecureStorage.shared.hasAPIKey(for: provider) {
            return true
        }
        return getAPIKey(for: provider) != nil
    }

    // MARK: - Reset

    func resetToDefaults() {
        defaultProvider = "openrouter"
        streamResponses = true
        theme = "system"
        fontSize = "medium"
        iCloudSyncEnabled = false
        analyticsEnabled = false
        handoffEnabled = true
        cloudAPIPrivacyGuardEnabled = false

        launchAtLogin = false
        showInMenuBar = true
        notificationsEnabled = true

        windowFloatOnTop = false
        rememberWindowPosition = true
        defaultWindowSize = "default"

        messageDensity = "comfortable"
        timestampDisplay = "relative"
        autoScrollToBottom = true

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

        submitShortcut = "enter"
        notifyOnResponseComplete = true
        notifyOnAttentionRequired = true
        playNotificationSound = true
        showDockBadge = true
        doNotDisturb = false
        activeFocusMode = "general"
        enableSemanticSearch = true
        defaultExportFormat = "markdown"

        for provider in availableProviders {
            deleteAPIKey(for: provider)
        }
    }
}
