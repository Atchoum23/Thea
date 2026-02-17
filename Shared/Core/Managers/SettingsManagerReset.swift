// MARK: - Reset

extension SettingsManager {
    func resetToDefaults() {
        defaultProvider = "openrouter"
        streamResponses = true
        theme = "system"
        fontSize = "medium"
        iCloudSyncEnabled = false
        analyticsEnabled = false
        handoffEnabled = true
        cloudAPIPrivacyGuardEnabled = true

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
        agentDelegationEnabled = true
        agentAutoDelegateComplexTasks = false
        agentMaxConcurrent = 4
        agentDefaultAutonomy = "balanced"
        activeFocusMode = "general"
        enableSemanticSearch = true
        defaultExportFormat = "markdown"

        for provider in availableProviders {
            deleteAPIKey(for: provider)
        }
    }
}
