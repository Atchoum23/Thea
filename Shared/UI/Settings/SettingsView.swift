// SettingsView.swift
// Comprehensive settings with scrollable sections and info popovers

import SwiftUI
import Combine

// MARK: - Settings View

/// Main settings view with scrollable sections
public struct SettingsView: View {
    @StateObject private var config = ConfigurationManager.shared
    @State private var searchText = ""
    @State private var selectedCategory: ConfigurationCategory?
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationSplitView {
            // Sidebar with categories
            List(selection: $selectedCategory) {
                ForEach(ConfigurationCategory.allCases) { category in
                    NavigationLink(value: category) {
                        Label(category.title, systemImage: category.icon)
                    }
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 200)
            .navigationTitle("Settings")
        } detail: {
            // Main content
            if let category = selectedCategory {
                SettingsCategoryView(category: category)
            } else {
                AllSettingsView()
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .searchable(text: $searchText, prompt: "Search settings...")
    }
}

// MARK: - All Settings View (Scrollable)

/// Displays all settings in scrollable sections
struct AllSettingsView: View {
    @StateObject private var config = ConfigurationManager.shared

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 32) {
                ForEach(ConfigurationCategory.allCases) { category in
                    SettingsSectionView(category: category)
                }
            }
            .padding(24)
        }
        .navigationTitle("All Settings")
        .toolbar {
            ToolbarItem {
                Button("Reset All") {
                    config.resetToDefaults()
                }
            }
        }
    }
}

// MARK: - Settings Category View

/// Displays settings for a specific category
struct SettingsCategoryView: View {
    let category: ConfigurationCategory
    @StateObject private var config = ConfigurationManager.shared

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                // Category header
                VStack(alignment: .leading, spacing: 8) {
                    Label(category.title, systemImage: category.icon)
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text(categoryDescription)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 16)

                // Settings for this category
                settingsContent
            }
            .padding(24)
        }
        .navigationTitle(category.title)
        .toolbar {
            ToolbarItem {
                Button("Reset \(category.title)") {
                    config.resetCategory(category)
                }
            }
        }
    }

    private var categoryDescription: String {
        switch category {
        case .general: return "General app behavior and preferences"
        case .ai: return "AI provider settings, models, and behavior"
        case .appearance: return "Customize the look and feel of Thea"
        case .keyboard: return "Keyboard shortcuts and input settings"
        case .privacy: return "Privacy, security, and data settings"
        case .sync: return "Cloud sync and backup configuration"
        case .notifications: return "Notification preferences"
        case .advanced: return "Advanced settings for power users"
        case .experimental: return "Experimental features (may be unstable)"
        }
    }

    @ViewBuilder
    private var settingsContent: some View {
        switch category {
        case .general:
            GeneralSettingsSection()
        case .ai:
            AISettingsSection()
        case .appearance:
            AppearanceSettingsSection()
        case .keyboard:
            KeyboardSettingsSection()
        case .privacy:
            PrivacySettingsSection()
        case .sync:
            SyncSettingsSection()
        case .notifications:
            NotificationSettingsSection()
        case .advanced:
            AdvancedSettingsSection()
        case .experimental:
            ExperimentalSettingsSection()
        }
    }
}

// MARK: - Settings Section View

/// Reusable section container
struct SettingsSectionView: View {
    let category: ConfigurationCategory
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Label(category.title, systemImage: category.icon)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()

                // Section content based on category
                sectionContent
            }
        }
        .padding(20)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch category {
        case .general:
            GeneralSettingsSection()
        case .ai:
            AISettingsSection()
        case .appearance:
            AppearanceSettingsSection()
        case .keyboard:
            KeyboardSettingsSection()
        case .privacy:
            PrivacySettingsSection()
        case .sync:
            SyncSettingsSection()
        case .notifications:
            NotificationSettingsSection()
        case .advanced:
            AdvancedSettingsSection()
        case .experimental:
            ExperimentalSettingsSection()
        }
    }
}

// MARK: - Setting Row

/// Individual setting row with info popover
struct SettingRow<Content: View>: View {
    let title: String
    let description: String
    let content: Content
    var requiresRestart: Bool = false

    @State private var showingInfo = false

    init(
        title: String,
        description: String,
        requiresRestart: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.description = description
        self.requiresRestart = requiresRestart
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Title and info button
            HStack(spacing: 4) {
                Text(title)
                    .font(.body)

                // Info button with popover
                Button(action: { showingInfo.toggle() }) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingInfo, arrowEdge: .trailing) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(title)
                            .font(.headline)

                        Text(description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if requiresRestart {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Requires restart")
                            }
                            .font(.caption)
                            .foregroundStyle(.orange)
                        }
                    }
                    .padding()
                    .frame(maxWidth: 300)
                }

                if requiresRestart {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            // Control
            content
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Section: General

struct GeneralSettingsSection: View {
    @StateObject private var config = ConfigurationManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // App Behavior
            GroupBox("App Behavior") {
                VStack(spacing: 12) {
                    SettingRow(
                        title: "Launch at Login",
                        description: "Automatically start Thea when you log in to your Mac. Thea will run in the background, ready for quick access."
                    ) {
                        Toggle("", isOn: $config.general.launchAtLogin)
                            .labelsHidden()
                    }

                    SettingRow(
                        title: "Show in Dock",
                        description: "Display Thea's icon in the Dock. Disable to run Thea as a menu bar only app."
                    ) {
                        Toggle("", isOn: $config.general.showInDock)
                            .labelsHidden()
                    }

                    SettingRow(
                        title: "Show in Menu Bar",
                        description: "Display a Thea icon in the menu bar for quick access to conversations and settings."
                    ) {
                        Toggle("", isOn: $config.general.showInMenuBar)
                            .labelsHidden()
                    }

                    SettingRow(
                        title: "New Conversation Opens In",
                        description: "Choose whether new conversations open in a new tab, new window, or replace the current content."
                    ) {
                        Picker("", selection: $config.general.defaultWindowBehavior) {
                            ForEach(GeneralConfiguration.WindowBehavior.allCases, id: \.self) { behavior in
                                Text(behavior.rawValue).tag(behavior)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 150)
                    }
                }
                .padding(8)
            }

            // Language
            GroupBox("Language & Region") {
                VStack(spacing: 12) {
                    SettingRow(
                        title: "Language",
                        description: "Choose the language for the Thea interface. Set to 'System' to use your Mac's language."
                    ) {
                        Picker("", selection: $config.general.language) {
                            Text("System").tag("system")
                            Text("English").tag("en")
                            Text("Spanish").tag("es")
                            Text("French").tag("fr")
                            Text("German").tag("de")
                            Text("Japanese").tag("ja")
                            Text("Chinese (Simplified)").tag("zh-Hans")
                        }
                        .labelsHidden()
                        .frame(width: 150)
                    }
                }
                .padding(8)
            }

            // Updates
            GroupBox("Updates") {
                VStack(spacing: 12) {
                    SettingRow(
                        title: "Check for Updates",
                        description: "Automatically check for new versions of Thea."
                    ) {
                        Toggle("", isOn: $config.general.checkForUpdates)
                            .labelsHidden()
                    }

                    SettingRow(
                        title: "Auto-install Updates",
                        description: "Automatically install updates when available. Updates are installed when Thea is restarted."
                    ) {
                        Toggle("", isOn: $config.general.autoInstallUpdates)
                            .labelsHidden()
                    }
                    .disabled(!config.general.checkForUpdates)

                    SettingRow(
                        title: "Update Channel",
                        description: "Choose which updates to receive. Beta and Nightly channels may have bugs."
                    ) {
                        Picker("", selection: $config.general.updateChannel) {
                            ForEach(GeneralConfiguration.UpdateChannel.allCases, id: \.self) { channel in
                                Text(channel.rawValue).tag(channel)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 120)
                    }
                }
                .padding(8)
            }
        }
    }
}

// MARK: - Section: AI

struct AISettingsSection: View {
    @StateObject private var config = ConfigurationManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Provider
            GroupBox("AI Provider") {
                VStack(spacing: 12) {
                    SettingRow(
                        title: "Default Provider",
                        description: "The AI provider to use by default. You can switch providers per-conversation if needed."
                    ) {
                        Picker("", selection: $config.ai.defaultProvider) {
                            Text("Anthropic").tag("anthropic")
                            Text("OpenAI").tag("openai")
                            Text("Google").tag("google")
                            Text("Local").tag("local")
                        }
                        .labelsHidden()
                        .frame(width: 150)
                    }

                    SettingRow(
                        title: "Default Model",
                        description: "The AI model to use. Different models have different capabilities and costs."
                    ) {
                        Picker("", selection: $config.ai.defaultModel) {
                            Text("Claude 3.5 Sonnet").tag("claude-3-5-sonnet")
                            Text("Claude 3 Opus").tag("claude-3-opus")
                            Text("GPT-4o").tag("gpt-4o")
                            Text("GPT-4 Turbo").tag("gpt-4-turbo")
                            Text("Gemini Pro").tag("gemini-pro")
                        }
                        .labelsHidden()
                        .frame(width: 180)
                    }
                }
                .padding(8)
            }

            // Behavior
            GroupBox("Response Behavior") {
                VStack(spacing: 12) {
                    SettingRow(
                        title: "Stream Responses",
                        description: "Show AI responses as they're being generated, word by word. Disable for complete responses only."
                    ) {
                        Toggle("", isOn: $config.ai.streamResponses)
                            .labelsHidden()
                    }

                    SettingRow(
                        title: "Auto-retry on Error",
                        description: "Automatically retry failed requests. Useful for handling temporary network issues."
                    ) {
                        Toggle("", isOn: $config.ai.autoRetryOnError)
                            .labelsHidden()
                    }

                    SettingRow(
                        title: "Request Timeout",
                        description: "Maximum time to wait for an AI response before timing out."
                    ) {
                        Picker("", selection: $config.ai.requestTimeout) {
                            Text("30 seconds").tag(TimeInterval(30))
                            Text("60 seconds").tag(TimeInterval(60))
                            Text("120 seconds").tag(TimeInterval(120))
                            Text("5 minutes").tag(TimeInterval(300))
                        }
                        .labelsHidden()
                        .frame(width: 120)
                    }
                }
                .padding(8)
            }

            // Context
            GroupBox("Context & Memory") {
                VStack(spacing: 12) {
                    SettingRow(
                        title: "Maximum Context Length",
                        description: "The maximum number of tokens to include in conversation context. Higher values provide more context but increase costs."
                    ) {
                        TextField("", value: $config.ai.maxContextLength, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                    }

                    SettingRow(
                        title: "Include Conversation History",
                        description: "Include previous messages from the conversation for context."
                    ) {
                        Toggle("", isOn: $config.ai.includeConversationHistory)
                            .labelsHidden()
                    }

                    SettingRow(
                        title: "Enable Long-term Memory",
                        description: "Allow Thea to remember important information across conversations. This creates a persistent knowledge base about you."
                    ) {
                        Toggle("", isOn: $config.ai.enableMemory)
                            .labelsHidden()
                    }
                }
                .padding(8)
            }

            // Tools
            GroupBox("Tools & Self-Execution") {
                VStack(spacing: 12) {
                    SettingRow(
                        title: "Enable MCP Tools",
                        description: "Allow Thea to use Model Context Protocol tools to interact with external services."
                    ) {
                        Toggle("", isOn: $config.ai.enableMCPTools)
                            .labelsHidden()
                    }

                    SettingRow(
                        title: "Tool Approval Mode",
                        description: "Control when Thea asks for permission before using tools."
                    ) {
                        Picker("", selection: $config.ai.toolApprovalMode) {
                            ForEach(AIConfiguration.ToolApprovalMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 160)
                    }

                    SettingRow(
                        title: "Enable Self-Execution",
                        description: "Allow Thea to autonomously execute code and system commands. Use with caution."
                    ) {
                        Toggle("", isOn: $config.ai.enableSelfExecution)
                            .labelsHidden()
                    }
                }
                .padding(8)
            }
        }
    }
}

// MARK: - Section: Appearance

struct AppearanceSettingsSection: View {
    @StateObject private var config = ConfigurationManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Theme
            GroupBox("Theme") {
                VStack(spacing: 12) {
                    SettingRow(
                        title: "Appearance",
                        description: "Choose between light, dark, or system-matched appearance."
                    ) {
                        Picker("", selection: $config.appearance.theme) {
                            ForEach(AppearanceConfiguration.Theme.allCases, id: \.self) { theme in
                                Text(theme.rawValue).tag(theme)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 200)
                    }

                    SettingRow(
                        title: "Accent Color",
                        description: "The accent color used throughout the app for buttons and highlights."
                    ) {
                        Picker("", selection: $config.appearance.accentColor) {
                            Text("Blue").tag("blue")
                            Text("Purple").tag("purple")
                            Text("Pink").tag("pink")
                            Text("Red").tag("red")
                            Text("Orange").tag("orange")
                            Text("Green").tag("green")
                        }
                        .labelsHidden()
                        .frame(width: 120)
                    }
                }
                .padding(8)
            }

            // Typography
            GroupBox("Typography") {
                VStack(spacing: 12) {
                    SettingRow(
                        title: "Font Size",
                        description: "Base font size for messages and content."
                    ) {
                        Picker("", selection: $config.appearance.fontSize) {
                            ForEach(AppearanceConfiguration.FontSize.allCases, id: \.self) { size in
                                Text(size.rawValue).tag(size)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 140)
                    }

                    SettingRow(
                        title: "Line Spacing",
                        description: "Space between lines of text. Higher values improve readability."
                    ) {
                        Slider(value: $config.appearance.lineSpacing, in: 1.0...2.0, step: 0.1)
                            .frame(width: 150)
                    }
                }
                .padding(8)
            }

            // Code
            GroupBox("Code Display") {
                VStack(spacing: 12) {
                    SettingRow(
                        title: "Code Theme",
                        description: "Syntax highlighting theme for code blocks."
                    ) {
                        Picker("", selection: $config.appearance.codeTheme) {
                            Text("Xcode").tag("xcode")
                            Text("GitHub").tag("github")
                            Text("Monokai").tag("monokai")
                            Text("Dracula").tag("dracula")
                            Text("One Dark").tag("onedark")
                        }
                        .labelsHidden()
                        .frame(width: 120)
                    }

                    SettingRow(
                        title: "Show Line Numbers",
                        description: "Display line numbers in code blocks."
                    ) {
                        Toggle("", isOn: $config.appearance.showLineNumbers)
                            .labelsHidden()
                    }
                }
                .padding(8)
            }

            // Animations
            GroupBox("Animations") {
                VStack(spacing: 12) {
                    SettingRow(
                        title: "Enable Animations",
                        description: "Show smooth animations for transitions and interactions."
                    ) {
                        Toggle("", isOn: $config.appearance.enableAnimations)
                            .labelsHidden()
                    }

                    SettingRow(
                        title: "Reduce Motion",
                        description: "Minimize animations for accessibility. Follows system setting if enabled."
                    ) {
                        Toggle("", isOn: $config.appearance.reduceMotion)
                            .labelsHidden()
                    }
                }
                .padding(8)
            }
        }
    }
}

// MARK: - Section: Keyboard

struct KeyboardSettingsSection: View {
    @StateObject private var config = ConfigurationManager.shared
    @State private var isRecordingShortcut = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Global Shortcut
            GroupBox("Global Quick Prompt") {
                VStack(spacing: 12) {
                    SettingRow(
                        title: "Enable Global Shortcut",
                        description: "Enable a system-wide keyboard shortcut to quickly open Thea's prompt overlay from any application."
                    ) {
                        Toggle("", isOn: $config.keyboard.globalShortcutEnabled)
                            .labelsHidden()
                    }

                    SettingRow(
                        title: "Shortcut",
                        description: "The keyboard shortcut to open the quick prompt overlay. Works system-wide, even when Thea is in the background."
                    ) {
                        ShortcutRecorderView(
                            key: $config.keyboard.globalShortcutKey,
                            modifiers: $config.keyboard.globalShortcutModifiers,
                            isRecording: $isRecordingShortcut
                        )
                    }
                    .disabled(!config.keyboard.globalShortcutEnabled)
                }
                .padding(8)
            }

            // Input
            GroupBox("Input Behavior") {
                VStack(spacing: 12) {
                    SettingRow(
                        title: "Send on Enter",
                        description: "Press Enter to send messages. Use Shift+Enter for new lines."
                    ) {
                        Toggle("", isOn: $config.keyboard.sendOnEnter)
                            .labelsHidden()
                    }

                    SettingRow(
                        title: "Markdown Shortcuts",
                        description: "Enable keyboard shortcuts for markdown formatting (bold, italic, code)."
                    ) {
                        Toggle("", isOn: $config.keyboard.enableMarkdownShortcuts)
                            .labelsHidden()
                    }

                    SettingRow(
                        title: "Vim Keybindings",
                        description: "Use Vim-style keyboard navigation throughout the app."
                    ) {
                        Toggle("", isOn: $config.keyboard.useVimKeybindings)
                            .labelsHidden()
                    }
                }
                .padding(8)
            }

            // Custom shortcuts link
            Button(action: {
                // Open keyboard shortcuts customization
            }) {
                HStack {
                    Text("Customize All Keyboard Shortcuts")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
            }
            .buttonStyle(.plain)
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Section: Privacy

struct PrivacySettingsSection: View {
    @StateObject private var config = ConfigurationManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Data Collection
            GroupBox("Data Collection") {
                VStack(spacing: 12) {
                    SettingRow(
                        title: "Share Analytics",
                        description: "Help improve Thea by sharing anonymous usage data. No conversation content is ever shared."
                    ) {
                        Toggle("", isOn: $config.privacy.analyticsEnabled)
                            .labelsHidden()
                    }

                    SettingRow(
                        title: "Crash Reporting",
                        description: "Automatically send crash reports to help fix bugs."
                    ) {
                        Toggle("", isOn: $config.privacy.crashReportingEnabled)
                            .labelsHidden()
                    }
                }
                .padding(8)
            }

            // Local Security
            GroupBox("Local Security") {
                VStack(spacing: 12) {
                    SettingRow(
                        title: "Encrypt Local Data",
                        description: "Encrypt all locally stored data using your device's secure enclave. May slightly impact performance.",
                        requiresRestart: true
                    ) {
                        Toggle("", isOn: $config.privacy.encryptLocalData)
                            .labelsHidden()
                    }

                    SettingRow(
                        title: "Biometric Unlock",
                        description: "Require Touch ID or Face ID to access Thea."
                    ) {
                        Toggle("", isOn: $config.privacy.biometricUnlock)
                            .labelsHidden()
                    }

                    SettingRow(
                        title: "Auto-lock Timeout",
                        description: "Automatically lock Thea after a period of inactivity."
                    ) {
                        Picker("", selection: $config.privacy.autoLockTimeout) {
                            Text("Never").tag(0)
                            Text("1 minute").tag(60)
                            Text("5 minutes").tag(300)
                            Text("15 minutes").tag(900)
                            Text("1 hour").tag(3600)
                        }
                        .labelsHidden()
                        .frame(width: 120)
                    }
                }
                .padding(8)
            }

            // Conversations
            GroupBox("Conversation Data") {
                VStack(spacing: 12) {
                    SettingRow(
                        title: "Save Conversation History",
                        description: "Keep a record of all conversations. Disable to not save any conversation data."
                    ) {
                        Toggle("", isOn: $config.privacy.saveConversationHistory)
                            .labelsHidden()
                    }

                    SettingRow(
                        title: "Auto-delete After",
                        description: "Automatically delete conversations older than this period."
                    ) {
                        Picker("", selection: $config.privacy.conversationRetentionDays) {
                            Text("Never").tag(0)
                            Text("30 days").tag(30)
                            Text("90 days").tag(90)
                            Text("1 year").tag(365)
                        }
                        .labelsHidden()
                        .frame(width: 120)
                    }
                }
                .padding(8)
            }
        }
    }
}

// MARK: - Section: Sync

struct SyncSettingsSection: View {
    @StateObject private var config = ConfigurationManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // iCloud Sync
            GroupBox("iCloud Sync") {
                VStack(spacing: 12) {
                    SettingRow(
                        title: "Enable iCloud Sync",
                        description: "Sync your data across all your Apple devices using iCloud."
                    ) {
                        Toggle("", isOn: $config.sync.iCloudSyncEnabled)
                            .labelsHidden()
                    }

                    if config.sync.iCloudSyncEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Sync:")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Toggle("Conversations", isOn: $config.sync.syncConversations)
                            Toggle("Agents", isOn: $config.sync.syncAgents)
                            Toggle("Artifacts", isOn: $config.sync.syncArtifacts)
                            Toggle("Memories", isOn: $config.sync.syncMemories)
                            Toggle("Settings", isOn: $config.sync.syncSettings)
                        }
                        .padding(.leading)
                    }
                }
                .padding(8)
            }

            // Backup
            GroupBox("Backup") {
                VStack(spacing: 12) {
                    SettingRow(
                        title: "Auto Backup",
                        description: "Automatically create backups of your data."
                    ) {
                        Toggle("", isOn: $config.sync.autoBackupEnabled)
                            .labelsHidden()
                    }

                    SettingRow(
                        title: "Backup Frequency",
                        description: "How often to create automatic backups."
                    ) {
                        Picker("", selection: $config.sync.backupFrequency) {
                            ForEach(SyncConfiguration.BackupFrequency.allCases, id: \.self) { freq in
                                Text(freq.rawValue).tag(freq)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 120)
                    }
                    .disabled(!config.sync.autoBackupEnabled)
                }
                .padding(8)
            }

            // Manual actions
            HStack(spacing: 12) {
                Button("Backup Now") {
                    Task {
                        try? await BackupManager.shared.createBackup()
                    }
                }

                Button("Restore from Backup...") {
                    // Show backup picker
                }
            }
        }
    }
}

// MARK: - Section: Notifications

struct NotificationSettingsSection: View {
    @StateObject private var config = ConfigurationManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox("General") {
                VStack(spacing: 12) {
                    SettingRow(
                        title: "Enable Notifications",
                        description: "Show notifications for important events."
                    ) {
                        Toggle("", isOn: $config.notifications.notificationsEnabled)
                            .labelsHidden()
                    }

                    SettingRow(
                        title: "Sound",
                        description: "Play a sound for notifications."
                    ) {
                        Toggle("", isOn: $config.notifications.soundEnabled)
                            .labelsHidden()
                    }
                    .disabled(!config.notifications.notificationsEnabled)
                }
                .padding(8)
            }

            GroupBox("Notification Types") {
                VStack(spacing: 12) {
                    Toggle("AI Response Complete", isOn: $config.notifications.notifyOnResponse)
                    Toggle("Task Complete", isOn: $config.notifications.notifyOnTaskComplete)
                    Toggle("Errors", isOn: $config.notifications.notifyOnError)
                    Toggle("Sync Complete", isOn: $config.notifications.notifyOnSync)
                }
                .padding(8)
            }
            .disabled(!config.notifications.notificationsEnabled)

            GroupBox("Quiet Hours") {
                VStack(spacing: 12) {
                    SettingRow(
                        title: "Enable Quiet Hours",
                        description: "Mute notifications during specified hours."
                    ) {
                        Toggle("", isOn: $config.notifications.quietHoursEnabled)
                            .labelsHidden()
                    }

                    if config.notifications.quietHoursEnabled {
                        HStack {
                            Text("From")
                            TextField("", text: $config.notifications.quietHoursStart)
                                .frame(width: 60)
                            Text("to")
                            TextField("", text: $config.notifications.quietHoursEnd)
                                .frame(width: 60)
                        }
                    }
                }
                .padding(8)
            }
        }
    }
}

// MARK: - Section: Advanced

struct AdvancedSettingsSection: View {
    @StateObject private var config = ConfigurationManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox("Performance") {
                VStack(spacing: 12) {
                    SettingRow(
                        title: "Cache Size",
                        description: "Amount of disk space to use for caching."
                    ) {
                        Picker("", selection: $config.advanced.cacheSize) {
                            ForEach(AdvancedConfiguration.CacheSize.allCases, id: \.self) { size in
                                Text(size.rawValue).tag(size)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 150)
                    }

                    SettingRow(
                        title: "Preload Conversations",
                        description: "Load recent conversations in the background for faster access."
                    ) {
                        Toggle("", isOn: $config.advanced.preloadConversations)
                            .labelsHidden()
                    }
                }
                .padding(8)
            }

            GroupBox("Debugging") {
                VStack(spacing: 12) {
                    SettingRow(
                        title: "Debug Mode",
                        description: "Show additional debugging information."
                    ) {
                        Toggle("", isOn: $config.advanced.debugModeEnabled)
                            .labelsHidden()
                    }

                    SettingRow(
                        title: "Verbose Logging",
                        description: "Log detailed information for troubleshooting."
                    ) {
                        Toggle("", isOn: $config.advanced.verboseLogging)
                            .labelsHidden()
                    }
                }
                .padding(8)
            }
        }
    }
}

// MARK: - Section: Experimental

struct ExperimentalSettingsSection: View {
    @StateObject private var config = ConfigurationManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Warning
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Experimental features may be unstable and could cause issues.")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            GroupBox("Autonomous Features") {
                VStack(spacing: 12) {
                    SettingRow(
                        title: "Self-Evolution Engine",
                        description: "Allow Thea to implement new features to its own codebase. Requires approval before changes are applied."
                    ) {
                        Toggle("", isOn: $config.experimental.enableSelfEvolution)
                            .labelsHidden()
                    }

                    SettingRow(
                        title: "Mission Orchestrator",
                        description: "Enable autonomous execution of complex, multi-phase tasks. Thea will plan and execute lengthy missions with checkpoints."
                    ) {
                        Toggle("", isOn: $config.experimental.enableMissionOrchestrator)
                            .labelsHidden()
                    }

                    SettingRow(
                        title: "Agent Autonomy",
                        description: "Allow agents to operate with greater independence. Agents may take actions without explicit approval."
                    ) {
                        Toggle("", isOn: $config.experimental.enableAgentAutonomy)
                            .labelsHidden()
                    }
                }
                .padding(8)
            }

            GroupBox("UI Experiments") {
                VStack(spacing: 12) {
                    SettingRow(
                        title: "New Editor",
                        description: "Try the experimental new message editor with enhanced features."
                    ) {
                        Toggle("", isOn: $config.experimental.enableNewEditor)
                            .labelsHidden()
                    }

                    SettingRow(
                        title: "Voice UI",
                        description: "Enable voice-first user interface elements."
                    ) {
                        Toggle("", isOn: $config.experimental.enableVoiceUI)
                            .labelsHidden()
                    }
                }
                .padding(8)
            }
        }
    }
}

// MARK: - Shortcut Recorder

struct ShortcutRecorderView: View {
    @Binding var key: String
    @Binding var modifiers: [String]
    @Binding var isRecording: Bool

    var body: some View {
        Button(action: { isRecording.toggle() }) {
            HStack {
                if isRecording {
                    Text("Press shortcut...")
                        .foregroundStyle(.blue)
                } else {
                    Text(displayString)
                        .font(.system(.body, design: .monospaced))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private var displayString: String {
        var parts: [String] = []
        if modifiers.contains("control") { parts.append("⌃") }
        if modifiers.contains("option") { parts.append("⌥") }
        if modifiers.contains("shift") { parts.append("⇧") }
        if modifiers.contains("command") { parts.append("⌘") }
        parts.append(key == "Space" ? "Space" : key.uppercased())
        return parts.joined()
    }
}
