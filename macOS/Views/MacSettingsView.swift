import AVFoundation
import Contacts
import CoreLocation
import Speech
import SwiftUI
import UserNotifications

// MARK: - Permission State

private enum MacPermissionState {
    case granted
    case denied
    case notDetermined
    case unknown

    var label: String {
        switch self {
        case .granted: "Granted"
        case .denied: "Denied"
        case .notDetermined: "Not Set"
        case .unknown: "Unknown"
        }
    }

    var color: Color {
        switch self {
        case .granted: .green
        case .denied: .red
        case .notDetermined: .gray
        case .unknown: .gray
        }
    }
}

// MARK: - Window Resizable Helper

/// Invisible NSView that forces its host NSWindow to accept the `.resizable` style mask.
/// SwiftUI's `Settings` scene actively strips `.resizable` — we use KVO to re-inject
/// it every time the system removes it, ensuring the resize handle always appears.
private struct WindowResizableHelper: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSView {
        ResizableInjectorView()
    }

    func updateNSView(_: NSView, context _: Context) {}

    private class ResizableInjectorView: NSView {
        private var observation: NSKeyValueObservation?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else {
                observation = nil
                return
            }
            window.styleMask.insert(.resizable)

            observation = window.observe(\.styleMask, options: [.new]) { win, _ in
                if !win.styleMask.contains(.resizable) {
                    DispatchQueue.main.async {
                        win.styleMask.insert(.resizable)
                    }
                }
            }
        }

        deinit {
            observation?.invalidate()
        }
    }
}

// MARK: - macOS Settings View

/// Consolidated settings for macOS with progressive disclosure.
/// Tabs: General, AI & Models, Voice & Input, Permissions, Sync & Privacy, Advanced
struct MacSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var cloudKitService = CloudKitService.shared
    @State private var voiceManager = VoiceActivationManager.shared
    @State private var handoffService = HandoffService.shared

    @State private var selectedTab: SettingsTab = .general

    enum SettingsTab: String, CaseIterable {
        case general = "General"
        case ai = "AI & Models"
        case voice = "Voice & Input"
        case permissions = "Permissions"
        case syncPrivacy = "Sync & Privacy"
        case advanced = "Advanced"

        var icon: String {
            switch self {
            case .general: "gear"
            case .ai: "brain.head.profile"
            case .voice: "mic.fill"
            case .permissions: "hand.raised.fill"
            case .syncPrivacy: "lock.icloud.fill"
            case .advanced: "slider.horizontal.3"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                viewForTab(tab)
                    .tabItem {
                        Label(tab.rawValue, systemImage: tab.icon)
                    }
                    .tag(tab)
            }
        }
        .frame(minWidth: 560, idealWidth: 700, maxWidth: .infinity, minHeight: 440, idealHeight: 580, maxHeight: .infinity)
        .background(WindowResizableHelper())
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func viewForTab(_ tab: SettingsTab) -> some View {
        switch tab {
        case .general:
            generalSettings
        case .ai:
            aiSettings
        case .voice:
            voiceSettings
        case .permissions:
            permissionsSettings
        case .syncPrivacy:
            syncPrivacySettings
        case .advanced:
            advancedSettings
        }
    }

    // MARK: - General Settings

    private var generalSettings: some View {
        Form {
            Section("Appearance") {
                let pickerWidth: CGFloat = 280

                LabeledContent("Theme") {
                    Picker("Theme", selection: $settingsManager.theme) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: pickerWidth)
                }

                LabeledContent("Font Size") {
                    Picker("Font Size", selection: $settingsManager.fontSize) {
                        Text("Small").tag("small")
                        Text("Medium").tag("medium")
                        Text("Large").tag("large")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: pickerWidth)
                    .onChange(of: settingsManager.fontSize) { _, newSize in
                        applyFontSizeToThemeConfig(newSize)
                    }
                }

                LabeledContent("Message Density") {
                    Picker("Density", selection: $settingsManager.messageDensity) {
                        Text("Compact").tag("compact")
                        Text("Comfortable").tag("comfortable")
                        Text("Spacious").tag("spacious")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: pickerWidth)
                }

                LabeledContent("Timestamps") {
                    Picker("Timestamps", selection: $settingsManager.timestampDisplay) {
                        Text("Relative").tag("relative")
                        Text("Absolute").tag("absolute")
                        Text("Hidden").tag("hidden")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: pickerWidth)
                }
            }

            Section("Window") {
                Toggle("Float Window on Top", isOn: $settingsManager.windowFloatOnTop)
                Toggle("Remember Window Position", isOn: $settingsManager.rememberWindowPosition)
            }

            Section("Behavior") {
                Toggle("Launch at Login", isOn: $settingsManager.launchAtLogin)
                Toggle("Show in Menu Bar", isOn: $settingsManager.showInMenuBar)
                Toggle("Enable Notifications", isOn: $settingsManager.notificationsEnabled)
                Toggle("Auto-Scroll to Latest", isOn: $settingsManager.autoScrollToBottom)
                Toggle("Show Sidebar on Launch", isOn: $settingsManager.showSidebarOnLaunch)
                Toggle("Restore Last Session", isOn: $settingsManager.restoreLastSession)
            }

            settingsFooter
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - AI & Models Settings

    @State private var openAIKey: String = ""
    @State private var anthropicKey: String = ""
    @State private var googleKey: String = ""
    @State private var perplexityKey: String = ""
    @State private var groqKey: String = ""
    @State private var openRouterKey: String = ""
    @State private var apiKeysLoaded: Bool = false

    @State private var localModelConfig = AppConfiguration.shared.localModelConfig

    private var aiSettings: some View {
        Form {
            Section("Provider & Routing") {
                Picker("Default Provider", selection: $settingsManager.defaultProvider) {
                    ForEach(settingsManager.availableProviders, id: \.self) { provider in
                        Text(provider.capitalized).tag(provider)
                    }
                }

                Toggle("Stream Responses", isOn: $settingsManager.streamResponses)

                Text("Model selection, temperature, tokens, and timeout are managed automatically by the Meta-AI orchestrator.")
                    .font(.theaCaption2)
                    .foregroundStyle(.tertiary)
            }

            Section("Local Models") {
                LabeledContent("Ollama URL") {
                    TextField("http://localhost:11434", text: $localModelConfig.ollamaBaseURL)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 320)
                }

                LabeledContent("MLX Models Dir") {
                    HStack(spacing: 6) {
                        TextField("~/.cache/huggingface/hub", text: $localModelConfig.mlxModelsDirectory)
                            .textFieldStyle(.roundedBorder)
                            .truncationMode(.head)
                            .help(localModelConfig.mlxModelsDirectory)

                        Button {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = false
                            panel.canChooseDirectories = true
                            panel.allowsMultipleSelection = false
                            panel.directoryURL = URL(
                                fileURLWithPath: (localModelConfig.mlxModelsDirectory as NSString)
                                    .expandingTildeInPath
                            )
                            if panel.runModal() == .OK, let url = panel.url {
                                localModelConfig.mlxModelsDirectory = url.path
                            }
                        } label: {
                            Image(systemName: "folder")
                        }
                        .help("Choose Folder…")
                    }
                    .frame(maxWidth: 320)
                }

                let localCount = ProviderRegistry.shared.getAvailableLocalModels().count
                LabeledContent("Discovered Models", value: "\(localCount)")
            }
            .onChange(of: localModelConfig) { _, newValue in
                AppConfiguration.shared.localModelConfig = newValue
            }

            Section("API Keys") {
                apiKeyField(label: "OpenAI", key: $openAIKey, provider: "openai")
                apiKeyField(label: "Anthropic", key: $anthropicKey, provider: "anthropic")
                apiKeyField(label: "Google AI", key: $googleKey, provider: "google")
                apiKeyField(label: "Perplexity", key: $perplexityKey, provider: "perplexity")
                apiKeyField(label: "Groq", key: $groqKey, provider: "groq")
                apiKeyField(label: "OpenRouter", key: $openRouterKey, provider: "openrouter")

                Text("Stored securely in your Keychain.")
                    .font(.theaCaption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear { loadAPIKeysIfNeeded() }
    }

    // MARK: - Voice & Input Settings

    private var voiceSettings: some View {
        Form {
            Section("Voice Activation") {
                Toggle("Enable Voice Activation", isOn: $voiceManager.isEnabled)
                    .onChange(of: voiceManager.isEnabled) { _, newValue in
                        if !newValue {
                            voiceManager.stopVoiceCommand()
                            voiceManager.stopWakeWordDetection()
                        }
                    }

                if voiceManager.isEnabled {
                    HStack {
                        Text("Wake Word")
                        TextField("Wake Word", text: $voiceManager.wakeWord)
                            .textFieldStyle(.roundedBorder)
                    }

                    Toggle("Conversation Mode", isOn: $voiceManager.conversationMode)

                    HStack {
                        Button("Test Wake Word") {
                            try? voiceManager.startWakeWordDetection()
                        }

                        if voiceManager.isListening {
                            Button("Stop") {
                                voiceManager.stopWakeWordDetection()
                            }
                            .foregroundStyle(.red)
                        }
                    }

                    if voiceManager.isListening {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Listening for '\(voiceManager.wakeWord)'...")
                                .font(.theaCaption1)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Text("Voice features require microphone permission.")
                    .font(.theaCaption2)
                    .foregroundStyle(.secondary)
            }

            Section("Text-to-Speech") {
                Toggle("Read Responses Aloud", isOn: $settingsManager.readResponsesAloud)

                if settingsManager.readResponsesAloud {
                    Picker("Voice", selection: $settingsManager.selectedVoice) {
                        Text("Default").tag("default")
                        Text("Samantha").tag("samantha")
                        Text("Alex").tag("alex")
                    }
                }
            }

            settingsFooter
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Permissions Settings

    @State private var permissionStates: [String: MacPermissionState] = [:]
    @State private var isRefreshingPermissions = false

    private var permissionsSettings: some View {
        Form {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("System Permissions")
                            .font(.theaHeadline)
                        Text("Thea needs certain permissions to function fully. Grant or check status below.")
                            .font(.theaCaption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        refreshMacPermissions()
                    } label: {
                        HStack(spacing: 4) {
                            if isRefreshingPermissions {
                                ProgressView().scaleEffect(0.7)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text("Refresh")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isRefreshingPermissions)
                }
            }

            Section("Core Permissions") {
                permissionRow(
                    key: "microphone", label: "Microphone", icon: "mic.fill",
                    description: "Required for voice activation and speech input.",
                    settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
                )
                permissionRow(
                    key: "speechRecognition", label: "Speech Recognition", icon: "waveform",
                    description: "Required for voice-to-text and wake word detection.",
                    settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition"
                )
                permissionRow(
                    key: "contacts", label: "Contacts", icon: "person.crop.circle",
                    description: "Allows Thea to reference and manage your contacts.",
                    settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Contacts"
                )
                permissionRow(
                    key: "location", label: "Location", icon: "location.fill",
                    description: "Enables location-aware suggestions and context.",
                    settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices"
                )
                permissionRow(
                    key: "notifications", label: "Notifications", icon: "bell.fill",
                    description: "Alerts for completed tasks, updates, and reminders.",
                    settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Notifications"
                )
            }

            Section("macOS System Access") {
                permissionRow(
                    key: "accessibility", label: "Accessibility", icon: "accessibility",
                    description: "Needed for reading screen content and UI automation.",
                    settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                )
                permissionRow(
                    key: "screenRecording", label: "Screen Recording", icon: "rectangle.dashed.badge.record",
                    description: "Required for capturing screen context.",
                    settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
                )
                permissionRow(
                    key: "fullDiskAccess", label: "Full Disk Access", icon: "internaldrive",
                    description: "Required for reading files across your system.",
                    settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
                )
                permissionRow(
                    key: "automation", label: "Automation", icon: "gearshape.2",
                    description: "Allows Thea to control other apps via AppleScript.",
                    settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
                )
            }

            Section("Quick Actions") {
                HStack(spacing: 12) {
                    quickActionButton("Privacy Settings", icon: "hand.raised.fill") {
                        NSWorkspace.shared.open(
                            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy")!
                        )
                    }
                    quickActionButton("Accessibility", icon: "accessibility") {
                        NSWorkspace.shared.open(
                            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                        )
                    }
                    quickActionButton("Screen Recording", icon: "rectangle.dashed.badge.record") {
                        CGRequestScreenCaptureAccess()
                        refreshMacPermissions()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear { refreshMacPermissions() }
    }

    private func permissionRow(
        key: String, label: String, icon: String,
        description: String, settingsURL: String
    ) -> some View {
        let state = permissionStates[key] ?? .unknown
        return HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(state.color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.theaSubhead)
                Text(description)
                    .font(.theaCaption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Text(state.label)
                .font(.theaCaption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(state.color.opacity(0.15))
                .foregroundStyle(state.color)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            Button {
                if let url = URL(string: settingsURL) {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Image(systemName: "gear")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 2)
    }

    private func quickActionButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.title2)
                Text(title).font(.theaCaption2).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.bordered)
    }

    private func refreshMacPermissions() {
        isRefreshingPermissions = true
        Task {
            var states: [String: MacPermissionState] = [:]

            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .authorized: states["microphone"] = .granted
            case .denied, .restricted: states["microphone"] = .denied
            case .notDetermined: states["microphone"] = .notDetermined
            @unknown default: states["microphone"] = .unknown
            }

            switch SFSpeechRecognizer.authorizationStatus() {
            case .authorized: states["speechRecognition"] = .granted
            case .denied, .restricted: states["speechRecognition"] = .denied
            case .notDetermined: states["speechRecognition"] = .notDetermined
            @unknown default: states["speechRecognition"] = .unknown
            }

            switch CNContactStore.authorizationStatus(for: .contacts) {
            case .authorized: states["contacts"] = .granted
            case .denied, .restricted: states["contacts"] = .denied
            case .notDetermined: states["contacts"] = .notDetermined
            @unknown default: states["contacts"] = .unknown
            }

            let locStatus = CLLocationManager().authorizationStatus
            switch locStatus {
            case .authorizedAlways, .authorized: states["location"] = .granted
            case .denied: states["location"] = .denied
            case .notDetermined: states["location"] = .notDetermined
            case .restricted: states["location"] = .denied
            @unknown default: states["location"] = .unknown
            }

            let notifSettings = await UNUserNotificationCenter.current().notificationSettings()
            switch notifSettings.authorizationStatus {
            case .authorized, .provisional: states["notifications"] = .granted
            case .denied: states["notifications"] = .denied
            case .notDetermined: states["notifications"] = .notDetermined
            @unknown default: states["notifications"] = .unknown
            }

            states["accessibility"] = AXIsProcessTrusted() ? .granted : .denied
            states["screenRecording"] = CGPreflightScreenCaptureAccess() ? .granted : .denied

            let testPath = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Mail").path
            states["fullDiskAccess"] = FileManager.default.isReadableFile(atPath: testPath) ? .granted : .denied
            states["automation"] = AXIsProcessTrusted() ? .granted : .unknown

            await MainActor.run {
                permissionStates = states
                isRefreshingPermissions = false
            }
        }
    }

    // MARK: - Sync & Privacy Settings

    private var syncPrivacySettings: some View {
        Form {
            Section("iCloud Sync") {
                Toggle("Enable iCloud Sync", isOn: $settingsManager.iCloudSyncEnabled)

                if settingsManager.iCloudSyncEnabled {
                    syncStatusRow("iCloud Status",
                                  isActive: cloudKitService.iCloudAvailable,
                                  activeText: "Connected",
                                  activeIcon: "checkmark.circle.fill",
                                  inactiveText: "Not Available",
                                  inactiveIcon: "exclamationmark.triangle.fill")

                    HStack {
                        Text("Sync Status:")
                            .font(.theaCaption1)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(cloudKitService.syncStatus.description)
                            .font(.theaCaption1)
                            .foregroundStyle(.tertiary)
                    }

                    if let lastSync = cloudKitService.lastSyncDate {
                        HStack {
                            Text("Last Sync:")
                                .font(.theaCaption1)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(lastSync, style: .relative)
                                .font(.theaCaption1)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Button("Sync Now") {
                        Task { try? await cloudKitService.syncAll() }
                    }
                    .buttonStyle(.bordered)
                    .disabled(!cloudKitService.iCloudAvailable
                        || cloudKitService.syncStatus == .syncing)
                }
            }

            Section("Handoff") {
                Toggle("Enable Handoff", isOn: $settingsManager.handoffEnabled)

                syncStatusRow("Handoff Status",
                              isActive: handoffService.isEnabled,
                              activeText: "Active",
                              activeIcon: "hand.raised.fill",
                              inactiveText: "Disabled",
                              inactiveIcon: "hand.raised.slash")

                Text("Continue conversations seamlessly across Apple devices.")
                    .font(.theaCaption2)
                    .foregroundStyle(.secondary)
            }

            Section("Privacy") {
                Toggle("Analytics", isOn: $settingsManager.analyticsEnabled)
                Text("Help improve THEA by sharing anonymous usage data.")
                    .font(.theaCaption2)
                    .foregroundStyle(.secondary)
            }

            Section("Data Management") {
                Button("Export All Data") { exportAllData() }
                Button("Clear All Data", role: .destructive) { clearAllData() }
            }

            settingsFooter
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Advanced Settings

    private var advancedSettings: some View {
        Form {
            Section("Execution Safety") {
                Toggle("Allow File Creation", isOn: $settingsManager.allowFileCreation)
                Toggle("Allow File Editing", isOn: $settingsManager.allowFileEditing)
                Toggle("Allow Code Execution", isOn: $settingsManager.allowCodeExecution)
                Toggle("Allow External API Calls", isOn: $settingsManager.allowExternalAPICalls)
                Toggle("Require Approval for Destructive Actions", isOn: $settingsManager.requireDestructiveApproval)
                Toggle("Enable Rollback", isOn: $settingsManager.enableRollback)
                Toggle("Create Backups Before Changes", isOn: $settingsManager.createBackups)
                Stepper("Max Concurrent Tasks: \(settingsManager.maxConcurrentTasks)",
                        value: $settingsManager.maxConcurrentTasks, in: 1 ... 10)
            }

            Section("Development") {
                Toggle("Enable Debug Mode", isOn: $settingsManager.debugMode)
                Toggle("Show Performance Metrics", isOn: $settingsManager.showPerformanceMetrics)
            }

            Section("Cache") {
                HStack {
                    Text("Cache Size")
                    Spacer()
                    Text("~50 MB")
                        .font(.theaCaption1)
                        .foregroundStyle(.secondary)
                }
                Button("Clear Cache") { clearCache() }
            }

            Section("Reset") {
                Button("Reset All Settings to Defaults", role: .destructive) {
                    settingsManager.resetToDefaults()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Shared Components

    private var settingsFooter: some View {
        EmptyView()
    }

    private func syncStatusRow(
        _ label: String,
        isActive: Bool,
        activeText: String,
        activeIcon: String,
        inactiveText: String,
        inactiveIcon: String
    ) -> some View {
        HStack {
            Text(label)
                .font(.theaCaption1)
                .foregroundStyle(.secondary)
            Spacer()
            Label(
                isActive ? activeText : inactiveText,
                systemImage: isActive ? activeIcon : inactiveIcon
            )
            .font(.theaCaption1)
            .foregroundStyle(isActive ? .green : .secondary)
        }
    }

    // MARK: - API Key Helpers

    private func loadAPIKeysIfNeeded() {
        guard !apiKeysLoaded else { return }
        apiKeysLoaded = true
        openAIKey = settingsManager.getAPIKey(for: "openai") ?? ""
        anthropicKey = settingsManager.getAPIKey(for: "anthropic") ?? ""
        googleKey = settingsManager.getAPIKey(for: "google") ?? ""
        perplexityKey = settingsManager.getAPIKey(for: "perplexity") ?? ""
        groqKey = settingsManager.getAPIKey(for: "groq") ?? ""
        openRouterKey = settingsManager.getAPIKey(for: "openrouter") ?? ""
    }

    private func apiKeyField(label: String, key: Binding<String>, provider: String) -> some View {
        HStack {
            Text(label)
                .frame(width: 100, alignment: .leading)

            SecureField("API Key", text: key)
                .textFieldStyle(.roundedBorder)
                .onChange(of: key.wrappedValue) { _, newValue in
                    if !newValue.isEmpty {
                        settingsManager.setAPIKey(newValue, for: provider)
                    }
                }

            if !key.wrappedValue.isEmpty {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
    }

    // MARK: - Actions

    private func exportAllData() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "thea-export-\(Date().ISO8601Format()).json"
        panel.allowedContentTypes = [.json]

        panel.begin { response in
            if response == .OK, let url = panel.url {
                print("Exporting data to: \(url)")
            }
        }
    }

    private func clearAllData() {
        let alert = NSAlert()
        alert.messageText = "Clear All Data?"
        alert.informativeText = "This will permanently delete all conversations, projects, and settings. This action cannot be undone."
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Clear All Data")

        if alert.runModal() == .alertSecondButtonReturn {
            print("Clearing all data")
        }
    }

    private func clearCache() {
        print("Clearing cache")
    }

    // MARK: - Font Size Scaling

    private func applyFontSizeToThemeConfig(_ size: String) {
        var config = AppConfiguration.shared.themeConfig
        let scale: CGFloat = switch size {
        case "small": 0.85
        case "large": 1.25
        default: 1.0
        }

        config.displaySize = round(34 * scale)
        config.title1Size = round(28 * scale)
        config.title2Size = round(22 * scale)
        config.title3Size = round(20 * scale)
        config.headlineSize = round(17 * scale)
        config.bodySize = round(17 * scale)
        config.calloutSize = round(16 * scale)
        config.subheadSize = round(15 * scale)
        config.footnoteSize = round(13 * scale)
        config.caption1Size = round(12 * scale)
        config.caption2Size = round(11 * scale)
        config.codeSize = round(14 * scale)
        config.codeInlineSize = round(16 * scale)

        AppConfiguration.shared.themeConfig = config
    }
}
