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

    // MARK: - Clipboard History Settings

    @Published var clipboardHistoryEnabled: Bool {
        didSet { persist(clipboardHistoryEnabled, forKey: "clipboardHistoryEnabled") }
    }

    @Published var clipboardRecordImages: Bool {
        didSet { persist(clipboardRecordImages, forKey: "clipboardRecordImages") }
    }

    @Published var clipboardMaxHistory: Int {
        didSet { persist(clipboardMaxHistory, forKey: "clipboardMaxHistory") }
    }

    @Published var clipboardRetentionDays: Int {
        didSet { persist(clipboardRetentionDays, forKey: "clipboardRetentionDays") }
    }

    @Published var clipboardAutoDetectSensitive: Bool {
        didSet { persist(clipboardAutoDetectSensitive, forKey: "clipboardAutoDetectSensitive") }
    }

    @Published var clipboardSensitiveExpiryHours: Int {
        didSet { persist(clipboardSensitiveExpiryHours, forKey: "clipboardSensitiveExpiryHours") }
    }

    @Published var clipboardAutoSummarize: Bool {
        didSet { persist(clipboardAutoSummarize, forKey: "clipboardAutoSummarize") }
    }

    @Published var clipboardSyncEnabled: Bool {
        didSet { persist(clipboardSyncEnabled, forKey: "clipboardSyncEnabled") }
    }

    @Published var clipboardAutoCategorize: Bool {
        didSet { persist(clipboardAutoCategorize, forKey: "clipboardAutoCategorize") }
    }

    @Published var clipboardSyncPinboards: Bool {
        didSet { persist(clipboardSyncPinboards, forKey: "clipboardSyncPinboards") }
    }

    @Published var clipboardExcludedApps: [String] {
        didSet { persist(clipboardExcludedApps, forKey: "clipboardExcludedApps") }
    }

    // MARK: - Agent Delegation Settings

    @Published var agentDelegationEnabled: Bool {
        didSet { persist(agentDelegationEnabled, forKey: "agentDelegationEnabled") }
    }

    @Published var agentAutoDelegateComplexTasks: Bool {
        didSet { persist(agentAutoDelegateComplexTasks, forKey: "agentAutoDelegateComplexTasks") }
    }

    @Published var agentMaxConcurrent: Int {
        didSet { persist(agentMaxConcurrent, forKey: "agentMaxConcurrent") }
    }

    @Published var agentDefaultAutonomy: String {
        didSet { persist(agentDefaultAutonomy, forKey: "agentDefaultAutonomy") }
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
        let d = UserDefaults.standard
        defaultProvider = d.string(forKey: "defaultProvider") ?? "openrouter"
        streamResponses = d.object(forKey: "streamResponses") as? Bool ?? true
        theme = d.string(forKey: "theme") ?? "system"
        fontSize = d.string(forKey: "fontSize") ?? "medium"
        iCloudSyncEnabled = d.object(forKey: "iCloudSyncEnabled") as? Bool ?? true
        analyticsEnabled = d.bool(forKey: "analyticsEnabled")
        handoffEnabled = d.object(forKey: "handoffEnabled") as? Bool ?? true
        cloudAPIPrivacyGuardEnabled = d.object(forKey: "cloudAPIPrivacyGuardEnabled") as? Bool ?? true
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
        // Execution settings
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
        // Notification settings
        notifyOnResponseComplete = d.object(forKey: "notifyOnResponseComplete") as? Bool ?? true
        notifyOnAttentionRequired = d.object(forKey: "notifyOnAttentionRequired") as? Bool ?? true
        playNotificationSound = d.object(forKey: "playNotificationSound") as? Bool ?? true
        showDockBadge = d.object(forKey: "showDockBadge") as? Bool ?? true
        doNotDisturb = d.bool(forKey: "doNotDisturb")
        // Moltbook settings
        moltbookAgentEnabled = d.bool(forKey: "moltbookAgentEnabled")
        moltbookPreviewMode = d.object(forKey: "moltbookPreviewMode") as? Bool ?? true
        moltbookMaxDailyPosts = d.integer(forKey: "moltbookMaxDailyPosts") != 0
            ? d.integer(forKey: "moltbookMaxDailyPosts") : 10
        // Clipboard settings
        clipboardHistoryEnabled = d.object(forKey: "clipboardHistoryEnabled") as? Bool ?? true
        clipboardRecordImages = d.object(forKey: "clipboardRecordImages") as? Bool ?? true
        clipboardMaxHistory = d.integer(forKey: "clipboardMaxHistory") != 0
            ? d.integer(forKey: "clipboardMaxHistory") : 500
        clipboardRetentionDays = d.integer(forKey: "clipboardRetentionDays") != 0
            ? d.integer(forKey: "clipboardRetentionDays") : 30
        clipboardAutoDetectSensitive = d.object(forKey: "clipboardAutoDetectSensitive") as? Bool ?? true
        clipboardSensitiveExpiryHours = d.integer(forKey: "clipboardSensitiveExpiryHours") != 0
            ? d.integer(forKey: "clipboardSensitiveExpiryHours") : 24
        clipboardAutoSummarize = d.bool(forKey: "clipboardAutoSummarize")
        clipboardSyncEnabled = d.bool(forKey: "clipboardSyncEnabled")
        clipboardAutoCategorize = d.bool(forKey: "clipboardAutoCategorize")
        clipboardSyncPinboards = d.bool(forKey: "clipboardSyncPinboards")
        clipboardExcludedApps = d.stringArray(forKey: "clipboardExcludedApps") ?? []
        // Agent settings
        agentDelegationEnabled = d.object(forKey: "agentDelegationEnabled") as? Bool ?? true
        agentAutoDelegateComplexTasks = d.bool(forKey: "agentAutoDelegateComplexTasks")
        agentMaxConcurrent = d.integer(forKey: "agentMaxConcurrent") != 0
            ? d.integer(forKey: "agentMaxConcurrent") : 4
        agentDefaultAutonomy = d.string(forKey: "agentDefaultAutonomy") ?? "balanced"
        // Remaining settings
        activeFocusMode = d.string(forKey: "activeFocusMode") ?? "general"
        enableSemanticSearch = d.object(forKey: "enableSemanticSearch") as? Bool ?? true
        defaultExportFormat = d.string(forKey: "defaultExportFormat") ?? "markdown"
        favoriteModels = Set(d.array(forKey: "favoriteModels") as? [String] ?? [])
        syncObserver = NotificationCenter.default
            .publisher(for: .preferenceSyncDidPull)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.reloadFromDefaults()
            }
    }

}

// MARK: - Reload from Defaults (after sync pull)

extension SettingsManager {
    /// Re-reads every @Published property from UserDefaults after the sync
    /// engine writes new cloud values into local storage.
    func reloadFromDefaults() {
        let d = UserDefaults.standard

        reloadCoreSettings(from: d)
        reloadUISettings(from: d)
        reloadExecutionSettings(from: d)
        reloadNotificationSettings(from: d)
        reloadClipboardSettings(from: d)
        reloadAgentAndMiscSettings(from: d)

        if let savedFavorites = d.array(forKey: "favoriteModels") as? [String] {
            favoriteModels = Set(savedFavorites)
        }

        AppConfiguration.applyFontSize(fontSize)
    }

    private func reloadCoreSettings(from d: UserDefaults) {
        defaultProvider = d.string(forKey: "defaultProvider") ?? "openrouter"
        streamResponses = d.object(forKey: "streamResponses") as? Bool ?? true
        theme = d.string(forKey: "theme") ?? "system"
        fontSize = d.string(forKey: "fontSize") ?? "medium"
        iCloudSyncEnabled = d.object(forKey: "iCloudSyncEnabled") as? Bool ?? true
        analyticsEnabled = d.bool(forKey: "analyticsEnabled")
        handoffEnabled = d.object(forKey: "handoffEnabled") as? Bool ?? true
        cloudAPIPrivacyGuardEnabled = d.object(forKey: "cloudAPIPrivacyGuardEnabled") as? Bool ?? true
        launchAtLogin = d.bool(forKey: "launchAtLogin")
        showInMenuBar = d.object(forKey: "showInMenuBar") as? Bool ?? true
        notificationsEnabled = d.object(forKey: "notificationsEnabled") as? Bool ?? true
    }

    private func reloadUISettings(from d: UserDefaults) {
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
    }

    private func reloadExecutionSettings(from d: UserDefaults) {
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
    }

    private func reloadNotificationSettings(from d: UserDefaults) {
        notifyOnResponseComplete = d.object(forKey: "notifyOnResponseComplete") as? Bool ?? true
        notifyOnAttentionRequired = d.object(forKey: "notifyOnAttentionRequired") as? Bool ?? true
        playNotificationSound = d.object(forKey: "playNotificationSound") as? Bool ?? true
        showDockBadge = d.object(forKey: "showDockBadge") as? Bool ?? true
        doNotDisturb = d.bool(forKey: "doNotDisturb")
        moltbookAgentEnabled = d.bool(forKey: "moltbookAgentEnabled")
        moltbookPreviewMode = d.object(forKey: "moltbookPreviewMode") as? Bool ?? true
        moltbookMaxDailyPosts = d.integer(forKey: "moltbookMaxDailyPosts") != 0
            ? d.integer(forKey: "moltbookMaxDailyPosts") : 10
    }

    private func reloadClipboardSettings(from d: UserDefaults) {
        clipboardHistoryEnabled = d.object(forKey: "clipboardHistoryEnabled") as? Bool ?? true
        clipboardRecordImages = d.object(forKey: "clipboardRecordImages") as? Bool ?? true
        clipboardMaxHistory = d.integer(forKey: "clipboardMaxHistory") != 0
            ? d.integer(forKey: "clipboardMaxHistory") : 500
        clipboardRetentionDays = d.integer(forKey: "clipboardRetentionDays") != 0
            ? d.integer(forKey: "clipboardRetentionDays") : 30
        clipboardAutoDetectSensitive = d.object(forKey: "clipboardAutoDetectSensitive") as? Bool ?? true
        clipboardSensitiveExpiryHours = d.integer(forKey: "clipboardSensitiveExpiryHours") != 0
            ? d.integer(forKey: "clipboardSensitiveExpiryHours") : 24
        clipboardAutoSummarize = d.bool(forKey: "clipboardAutoSummarize")
        clipboardSyncEnabled = d.bool(forKey: "clipboardSyncEnabled")
        clipboardExcludedApps = d.stringArray(forKey: "clipboardExcludedApps") ?? []
    }

    private func reloadAgentAndMiscSettings(from d: UserDefaults) {
        agentDelegationEnabled = d.object(forKey: "agentDelegationEnabled") as? Bool ?? true
        agentAutoDelegateComplexTasks = d.bool(forKey: "agentAutoDelegateComplexTasks")
        agentMaxConcurrent = d.integer(forKey: "agentMaxConcurrent") != 0
            ? d.integer(forKey: "agentMaxConcurrent") : 4
        agentDefaultAutonomy = d.string(forKey: "agentDefaultAutonomy") ?? "balanced"
        activeFocusMode = d.string(forKey: "activeFocusMode") ?? "general"
        enableSemanticSearch = d.object(forKey: "enableSemanticSearch") as? Bool ?? true
        defaultExportFormat = d.string(forKey: "defaultExportFormat") ?? "markdown"
    }
}

// MARK: - API Key Management (Keychain - NEVER synced to iCloud KVS)

extension SettingsManager {
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
}
