@preconcurrency import SwiftData
import SwiftUI

// MARK: - MacSettingsView Detail Sections

extension MacSettingsView {
    // MARK: - General Settings

    var generalSettings: some View {
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
                        AppConfiguration.applyFontSize(newSize)
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
                Toggle("Auto-Scroll to Latest", isOn: $settingsManager.autoScrollToBottom)
                Toggle("Show Sidebar on Launch", isOn: $settingsManager.showSidebarOnLaunch)
                Toggle("Restore Last Session", isOn: $settingsManager.restoreLastSession)
            }

            Section("Notifications") {
                Toggle("Enable Notifications", isOn: $settingsManager.notificationsEnabled)

                if settingsManager.notificationsEnabled {
                    Toggle("Notify When Response Complete", isOn: $settingsManager.notifyOnResponseComplete)
                    Toggle("Notify When Attention Required", isOn: $settingsManager.notifyOnAttentionRequired)
                    Toggle("Play Notification Sound", isOn: $settingsManager.playNotificationSound)
                    Toggle("Show Dock Badge", isOn: $settingsManager.showDockBadge)
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - AI & Models Settings

    var aiSettings: some View {
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
                Toggle("Prefer Local Models", isOn: $settingsManager.preferLocalModels)
                    .help("Prioritize local MLX/Ollama models over cloud providers when capable")

                Toggle("Enable Ollama", isOn: $settingsManager.ollamaEnabled)

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
                        .help("Choose Folder...")
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
        .onAppear { loadAPIKeysIfNeeded() }
    }

    // MARK: - Providers Settings

    var providersSettings: some View {
        NavigationStack {
            Form {
                Section("AI Providers") {
                    NavigationLink("API Endpoints & Timeouts") {
                        ProviderConfigurationView()
                    }

                    NavigationLink("API Key Validation Models") {
                        APIValidationConfigurationView()
                    }

                    NavigationLink("External APIs") {
                        ExternalAPIsConfigurationView()
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Providers")
        }
    }

    // MARK: - Voice & Input Settings

    var voiceInputSettings: some View {
        NavigationStack {
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
                                .foregroundStyle(.theaError)
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

                Section("Advanced Voice Configuration") {
                    NavigationLink("Recognition & Synthesis Settings") {
                        VoiceConfigurationView()
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Voice & Input")
        }
    }

    // MARK: - Advanced Settings

    var advancedSettings: some View {
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

            Section("Execution") {
                Toggle("Prevent Sleep During Execution", isOn: $settingsManager.preventSleepDuringExecution)
                    .help("Keep your Mac awake during long-running AI tasks")

                Toggle("Enable Semantic Search", isOn: $settingsManager.enableSemanticSearch)
                    .help("Use embedding-based search across conversations")

                LabeledContent("Default Export Format") {
                    Picker("Format", selection: $settingsManager.defaultExportFormat) {
                        Text("Markdown").tag("markdown")
                        Text("JSON").tag("json")
                        Text("Plain Text").tag("plaintext")
                    }
                    .labelsHidden()
                    .frame(width: 200)
                }
            }

            Section("Development") {
                Toggle("Enable Debug Mode", isOn: $settingsManager.debugMode)
                Toggle("Show Performance Metrics", isOn: $settingsManager.showPerformanceMetrics)
                Toggle("Beta Features", isOn: $settingsManager.betaFeaturesEnabled)
                    .help("Enable experimental features that may be unstable")
            }

            Section("Cache") {
                HStack {
                    Text("Cache Size")
                    Spacer()
                    Text(cacheSize)
                        .font(.theaCaption1)
                        .foregroundStyle(.secondary)
                }
                Button("Clear Cache") {
                    clearCache()
                    Task { cacheSize = await calculateCacheSize() }
                }
            }
            .task { cacheSize = await calculateCacheSize() }

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

            Section("Reset") {
                Button("Reset All Settings to Defaults", role: .destructive) {
                    settingsManager.resetToDefaults()
                }
                Button("Reset All Configuration to Defaults", role: .destructive) {
                    AppConfiguration.shared.resetAllToDefaults()
                }
            }
        }
        .formStyle(.grouped)
    }
}
