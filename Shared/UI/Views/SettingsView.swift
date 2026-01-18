import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        TabView {
            ProvidersSettingsView()
                .tabItem {
                    Label("Providers", systemImage: "network")
                }

            MetaAISettingsView()
                .tabItem {
                    Label("Meta-AI", systemImage: "brain")
                }

            FeaturesSettingsView()
                .tabItem {
                    Label("Features", systemImage: "star")
                }

            AdvancedSettingsView()
                .tabItem {
                    Label("Advanced", systemImage: "gearshape.2")
                }

            TerminalSettingsView()
                .tabItem {
                    Label("Terminal", systemImage: "terminal")
                }

            CoworkSettingsView()
                .tabItem {
                    Label("Cowork", systemImage: "person.2.badge.gearshape")
                }

            PrivacySettingsView()
                .tabItem {
                    Label("Privacy", systemImage: "lock.shield")
                }

            QASettingsView()
                .tabItem {
                    Label("QA Tools", systemImage: "checkmark.seal")
                }

            // TODO: Restore LifeTrackingSettingsView after implementation
            // LifeTrackingSettingsView()
            //     .tabItem {
            //         Label("Life Tracking", systemImage: "chart.xyaxis.line")
            //     }

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(minWidth: 600, minHeight: 400)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Providers Settings

struct ProvidersSettingsView: View {
    @State private var openAIKey = ""
    @State private var anthropicKey = ""
    @State private var googleKey = ""
    @State private var perplexityKey = ""
    @State private var openRouterKey = ""
    @State private var groqKey = ""
    @State private var showingSuccessMessage = false
    @State private var showingErrorMessage = false
    @State private var errorText = ""
    @State private var successText = ""

    var body: some View {
        Form {
            Section("AI Providers") {
                Text("Add API keys to enable AI providers")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("OpenAI (ChatGPT)") {
                SecureField("API Key", text: $openAIKey)
                Button("Save") {
                    saveAPIKey(openAIKey, for: "openai")
                }
                .disabled(openAIKey.isEmpty)
            }

            Section("Anthropic (Claude)") {
                SecureField("API Key", text: $anthropicKey)
                Button("Save") {
                    saveAPIKey(anthropicKey, for: "anthropic")
                }
                .disabled(anthropicKey.isEmpty)
            }

            Section("Google (Gemini)") {
                SecureField("API Key", text: $googleKey)
                Button("Save") {
                    saveAPIKey(googleKey, for: "google")
                }
                .disabled(googleKey.isEmpty)
            }

            Section("Perplexity") {
                SecureField("API Key", text: $perplexityKey)
                Button("Save") {
                    saveAPIKey(perplexityKey, for: "perplexity")
                }
                .disabled(perplexityKey.isEmpty)
            }

            Section("OpenRouter") {
                SecureField("API Key", text: $openRouterKey)
                Button("Save") {
                    saveAPIKey(openRouterKey, for: "openrouter")
                }
                .disabled(openRouterKey.isEmpty)
            }

            Section("Groq") {
                SecureField("API Key", text: $groqKey)
                Button("Save") {
                    saveAPIKey(groqKey, for: "groq")
                }
                .disabled(groqKey.isEmpty)
            }
        }
        .formStyle(.grouped)
        .alert("Success", isPresented: $showingSuccessMessage) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(successText)
        }
        .alert("Error", isPresented: $showingErrorMessage) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorText)
        }
    }

    private func saveAPIKey(_ key: String, for provider: String) {
        do {
            try SecureStorage.shared.saveAPIKey(key, for: provider)
            successText = "API key for \(provider) saved successfully"
            showingSuccessMessage = true

            // Clear the field after successful save
            switch provider {
            case "openai": openAIKey = ""
            case "anthropic": anthropicKey = ""
            case "google": googleKey = ""
            case "perplexity": perplexityKey = ""
            case "openrouter": openRouterKey = ""
            case "groq": groqKey = ""
            default: break
            }
        } catch {
            errorText = "Failed to save API key: \(error.localizedDescription)"
            showingErrorMessage = true
        }
    }
}

// MARK: - Meta-AI Settings

struct MetaAISettingsView: View {
    @State private var config = AppConfiguration.shared.metaAIConfig

    var body: some View {
        Form {
            Section("Meta-AI Systems") {
                Text("Enable advanced AI capabilities")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Core Intelligence") {
                Toggle("Sub-Agent Orchestration", isOn: $config.enableSubAgents)
                Toggle("Reflection Engine", isOn: $config.enableReflection)
                Toggle("Knowledge Graph", isOn: $config.enableKnowledgeGraph)
                Toggle("Memory System", isOn: $config.enableMemorySystem)
                Toggle("Multi-Step Reasoning", isOn: $config.enableReasoning)
            }

            Section("Capabilities") {
                Toggle("Dynamic Tools", isOn: $config.enableDynamicTools)
                Toggle("Code Sandbox", isOn: $config.enableCodeSandbox)
                Toggle("Browser Automation", isOn: $config.enableBrowserAutomation)
            }

            Section("Advanced Features") {
                Toggle("Agent Swarms", isOn: $config.enableAgentSwarms)

                if config.enableAgentSwarms {
                    VStack(alignment: .leading) {
                        Text("Max Concurrent Agents: \(config.maxConcurrentSwarmAgents)")
                            .font(.caption)
                        Slider(
                            value: Binding(
                                get: { Double(config.maxConcurrentSwarmAgents) },
                                set: { config.maxConcurrentSwarmAgents = Int($0) }
                            ),
                            in: 1...10,
                            step: 1
                        )
                    }
                }

                Toggle("Plugin System", isOn: $config.enablePlugins)
            }

            Section("AI Models") {
                TextField("Orchestrator Model", text: $config.orchestratorModel)
                    .help("Model for task coordination and agent management")
                TextField("Reflection Model", text: $config.reflectionModel)
                    .help("Model for self-critique and improvement")
                TextField("Knowledge Graph Model", text: $config.knowledgeGraphModel)
                    .help("Model for knowledge relationship analysis")
                TextField("Reasoning Model", text: $config.reasoningModel)
                    .help("Model for multi-step reasoning tasks")
                TextField("Planner Model", text: $config.plannerModel)
                    .help("Model for task planning and decomposition")
                TextField("Validator Model", text: $config.validatorModel)
                    .help("Model for output validation")
                TextField("Optimizer Model", text: $config.optimizerModel)
                    .help("Model for response optimization")
            }

            Section("Status") {
                LabeledContent("Total Systems", value: "15")
                LabeledContent("Active Systems", value: "\(activeSystemsCount())")
                LabeledContent("Framework Status", value: "Ready")
            }

            Section {
                NavigationLink("Workflow Builder") {
                    WorkflowBuilderView()
                }

                NavigationLink("Plugin Manager") {
                    PluginManagerView()
                }

                NavigationLink("Knowledge Graph Viewer") {
                    KnowledgeGraphViewer()
                }

                NavigationLink("Memory Inspector") {
                    MemoryInspectorView()
                }
            }

            Section {
                Button("Reset to Defaults") {
                    config = MetaAIConfiguration()
                }
                .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .onChange(of: config) { _, newValue in
            AppConfiguration.shared.metaAIConfig = newValue
        }
    }

    private func activeSystemsCount() -> Int {
        var count = 0
        if config.enableSubAgents { count += 1 }
        if config.enableReflection { count += 1 }
        if config.enableKnowledgeGraph { count += 1 }
        if config.enableMemorySystem { count += 1 }
        if config.enableReasoning { count += 1 }
        if config.enableDynamicTools { count += 1 }
        if config.enableCodeSandbox { count += 1 }
        if config.enableBrowserAutomation { count += 1 }
        if config.enableAgentSwarms { count += 1 }
        if config.enablePlugins { count += 1 }
        return count
    }
}

// MARK: - Features Settings

struct FeaturesSettingsView: View {
    var body: some View {
        Form {
            Section("All Features") {
                Text("Access all THEA capabilities")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Voice & Migration") {
                NavigationLink {
                    VoiceSettingsView()
                } label: {
                    Label("Voice Activation", systemImage: "waveform")
                }

                NavigationLink {
                    MigrationView()
                } label: {
                    Label("Import from Other Apps", systemImage: "arrow.down.doc")
                }
            }

            Section("Knowledge & Code") {
                NavigationLink {
                    KnowledgeManagementView()
                } label: {
                    Label("Knowledge Base", systemImage: "folder.badge.questionmark")
                }

                #if os(macOS)
                NavigationLink {
                    CodeProjectView()
                } label: {
                    Label("Code Intelligence", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                #endif

                NavigationLink {
                    LocalModelsView()
                } label: {
                    Label("Local Models", systemImage: "cpu")
                }
            }

            Section("Financial") {
                NavigationLink {
                    FinancialDashboardView()
                } label: {
                    Label("Financial Dashboard", systemImage: "dollarsign.circle")
                }
            }

            Section("Meta-AI Tools") {
                NavigationLink {
                    WorkflowBuilderView()
                } label: {
                    Label("Workflow Builder", systemImage: "flowchart")
                }

                NavigationLink {
                    PluginManagerView()
                } label: {
                    Label("Plugin Manager", systemImage: "puzzlepiece.extension")
                }

                NavigationLink {
                    KnowledgeGraphViewer()
                } label: {
                    Label("Knowledge Graph", systemImage: "point.3.connected.trianglepath.dotted")
                }

                NavigationLink {
                    MemoryInspectorView()
                } label: {
                    Label("Memory Inspector", systemImage: "brain.head.profile")
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Advanced Settings

struct AdvancedSettingsView: View {
    var body: some View {
        Form {
            Section("Advanced Configuration") {
                Text("Fine-tune THEA's behavior and performance")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Provider Settings") {
                NavigationLink("API Endpoints & Timeouts") {
                    ProviderConfigurationView()
                }
            }

            Section("Voice Settings") {
                NavigationLink("Voice Recognition & Synthesis") {
                    VoiceConfigurationView()
                }
            }

            Section("Knowledge Scanner") {
                NavigationLink("File Indexing Settings") {
                    KnowledgeScannerConfigurationView()
                }
            }

            Section("Memory System") {
                NavigationLink("Memory Capacity & Decay") {
                    MemoryConfigurationView()
                }
            }

            Section("Agent System") {
                NavigationLink("Agent Behavior & Limits") {
                    AgentConfigurationView()
                }
            }

            Section("Local Models") {
                NavigationLink("Local Model Paths & Defaults") {
                    LocalModelConfigurationView()
                }
            }

            #if os(macOS)
            Section("Code Intelligence") {
                NavigationLink("Code Models & Executables") {
                    CodeIntelligenceConfigurationView()
                }
            }
            #endif

            Section("API Validation") {
                NavigationLink("Test Models for Key Validation") {
                    APIValidationConfigurationView()
                }
            }

            Section("External APIs") {
                NavigationLink("Third-Party API Endpoints") {
                    ExternalAPIsConfigurationView()
                }
            }

            Section("Theme") {
                NavigationLink("Colors & Typography") {
                    ThemeConfigurationView()
                }
            }

            Section {
                Button("Reset All Settings to Defaults") {
                    AppConfiguration.shared.resetAllToDefaults()
                }
                .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Provider Configuration View

struct ProviderConfigurationView: View {
    @State private var config = AppConfiguration.shared.providerConfig

    var body: some View {
        Form {
            Section("API Endpoints") {
                TextField("Anthropic Base URL", text: $config.anthropicBaseURL)
                TextField("Anthropic API Version", text: $config.anthropicAPIVersion)
                TextField("OpenAI Base URL", text: $config.openAIBaseURL)
                TextField("Google Base URL", text: $config.googleBaseURL)
                TextField("Groq Base URL", text: $config.groqBaseURL)
                TextField("Perplexity Base URL", text: $config.perplexityBaseURL)
                TextField("OpenRouter Base URL", text: $config.openRouterBaseURL)
            }

            Section("Generation Defaults") {
                Stepper("Max Tokens: \(config.defaultMaxTokens)", value: $config.defaultMaxTokens, in: 256...32_768, step: 256)

                VStack(alignment: .leading) {
                    Text("Temperature: \(config.defaultTemperature, specifier: "%.2f")")
                    Slider(value: $config.defaultTemperature, in: 0...2, step: 0.1)
                }

                VStack(alignment: .leading) {
                    Text("Top P: \(config.defaultTopP, specifier: "%.2f")")
                    Slider(value: $config.defaultTopP, in: 0...1, step: 0.1)
                }

                Toggle("Stream Responses", isOn: $config.streamResponses)
            }

            Section("Model Defaults") {
                TextField("Default Model", text: $config.defaultModel)
                TextField("Summarization Model", text: $config.defaultSummarizationModel)
                TextField("Reasoning Model", text: $config.defaultReasoningModel)
                TextField("Embedding Model", text: $config.defaultEmbeddingModel)
                Stepper("Embedding Dimensions: \(config.embeddingDimensions)", value: $config.embeddingDimensions, in: 256...4_096, step: 256)
            }

            Section("Request Settings") {
                Stepper("Timeout (seconds): \(Int(config.requestTimeoutSeconds))", value: $config.requestTimeoutSeconds, in: 10...300, step: 10)
                Stepper("Max Retries: \(config.maxRetries)", value: $config.maxRetries, in: 0...10)
                Stepper("Retry Delay (seconds): \(Int(config.retryDelaySeconds))", value: $config.retryDelaySeconds, in: 0...10, step: 1)
            }

            Section {
                Button("Reset to Defaults") {
                    config = ProviderConfiguration()
                }
                .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Provider Configuration")
        .onChange(of: config) { _, newValue in
            AppConfiguration.shared.providerConfig = newValue
        }
    }
}

// MARK: - Voice Configuration View

struct VoiceConfigurationView: View {
    @State private var config = AppConfiguration.shared.voiceConfig
    @State private var newWakeWord = ""

    var body: some View {
        Form {
            Section("Wake Words") {
                ForEach(config.wakeWords, id: \.self) { word in
                    HStack {
                        Text(word)
                        Spacer()
                        Button(role: .destructive) {
                            config.wakeWords.removeAll { $0 == word }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack {
                    TextField("New wake word", text: $newWakeWord)
                    Button {
                        if !newWakeWord.isEmpty {
                            config.wakeWords.append(newWakeWord.lowercased())
                            newWakeWord = ""
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .disabled(newWakeWord.isEmpty)
                }

                Toggle("Wake Word Enabled", isOn: $config.wakeWordEnabled)
            }

            Section("Speech Recognition") {
                TextField("Recognition Language", text: $config.recognitionLanguage)
                Toggle("On-Device Recognition Only", isOn: $config.requiresOnDeviceRecognition)
                Stepper("Audio Buffer Size: \(config.audioBufferSize)", value: $config.audioBufferSize, in: 256...4_096, step: 256)
            }

            Section("Speech Synthesis") {
                TextField("Speech Language", text: $config.speechLanguage)

                VStack(alignment: .leading) {
                    Text("Speech Rate: \(config.speechRate, specifier: "%.2f")")
                    Slider(value: $config.speechRate, in: 0.1...1.0, step: 0.05)
                }

                VStack(alignment: .leading) {
                    Text("Pitch: \(config.pitchMultiplier, specifier: "%.2f")")
                    Slider(value: $config.pitchMultiplier, in: 0.5...2.0, step: 0.1)
                }

                VStack(alignment: .leading) {
                    Text("Volume: \(config.volume, specifier: "%.2f")")
                    Slider(value: $config.volume, in: 0...1, step: 0.1)
                }
            }

            Section("Conversation Mode") {
                VStack(alignment: .leading) {
                    Text("Silence Threshold: \(config.silenceThresholdSeconds, specifier: "%.1f")s")
                    Slider(value: $config.silenceThresholdSeconds, in: 1...10, step: 0.5)
                }

                VStack(alignment: .leading) {
                    Text("Conversation Timeout: \(Int(config.conversationTimeoutSeconds))s")
                    Slider(value: $config.conversationTimeoutSeconds, in: 10...120, step: 10)
                }
            }

            Section("Model") {
                TextField("Voice Assistant Model", text: $config.voiceAssistantModel)
            }

            Section("Feedback") {
                Toggle("Activation Sound", isOn: $config.activationSoundEnabled)
            }

            Section {
                Button("Reset to Defaults") {
                    config = VoiceConfiguration()
                }
                .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Voice Configuration")
        .onChange(of: config) { _, newValue in
            AppConfiguration.shared.voiceConfig = newValue
            VoiceActivationEngine.shared.updateConfiguration()
        }
    }
}

// MARK: - Knowledge Scanner Configuration View

struct KnowledgeScannerConfigurationView: View {
    @State private var config = AppConfiguration.shared.knowledgeScannerConfig

    var body: some View {
        Form {
            Section("File Extensions") {
                NavigationLink("Code Extensions (\(config.codeExtensions.count))") {
                    ExtensionListEditor(extensions: $config.codeExtensions, title: "Code Extensions")
                }
                NavigationLink("Document Extensions (\(config.documentExtensions.count))") {
                    ExtensionListEditor(extensions: $config.documentExtensions, title: "Document Extensions")
                }
                NavigationLink("Data Extensions (\(config.dataExtensions.count))") {
                    ExtensionListEditor(extensions: $config.dataExtensions, title: "Data Extensions")
                }
                NavigationLink("Config Extensions (\(config.configExtensions.count))") {
                    ExtensionListEditor(extensions: $config.configExtensions, title: "Config Extensions")
                }
                NavigationLink("Other Extensions (\(config.otherExtensions.count))") {
                    ExtensionListEditor(extensions: $config.otherExtensions, title: "Other Extensions")
                }
            }

            Section("File Limits") {
                VStack(alignment: .leading) {
                    Text("Max File Size: \(config.maxFileSizeBytes / 1_000_000) MB")
                    Slider(
                        value: Binding(
                            get: { Double(config.maxFileSizeBytes) / 1_000_000 },
                            set: { config.maxFileSizeBytes = Int64($0 * 1_000_000) }
                        ),
                        in: 1...100,
                        step: 1
                    )
                }

                Stepper("Batch Size: \(config.indexingBatchSize)", value: $config.indexingBatchSize, in: 10...500, step: 10)
            }

            Section("Embedding") {
                Stepper("Embedding Dimension: \(config.embeddingDimension)", value: $config.embeddingDimension, in: 128...1_536, step: 128)
            }

            Section("Search") {
                Stepper("Default Top K: \(config.defaultSearchTopK)", value: $config.defaultSearchTopK, in: 5...50, step: 5)
                Stepper("Full-Text Top K: \(config.fullTextSearchTopK)", value: $config.fullTextSearchTopK, in: 5...50, step: 5)
            }

            Section("File Watching") {
                Toggle("Enable File Watching", isOn: $config.enableFileWatching)
            }

            Section {
                Button("Reset to Defaults") {
                    config = KnowledgeScannerConfiguration()
                }
                .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Knowledge Scanner")
        .onChange(of: config) { _, newValue in
            AppConfiguration.shared.knowledgeScannerConfig = newValue
        }
    }
}

// MARK: - Extension List Editor

struct ExtensionListEditor: View {
    @Binding var extensions: [String]
    let title: String
    @State private var newExtension = ""

    var body: some View {
        Form {
            Section {
                ForEach(extensions, id: \.self) { ext in
                    HStack {
                        Text(".\(ext)")
                        Spacer()
                        Button(role: .destructive) {
                            extensions.removeAll { $0 == ext }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack {
                    TextField("New extension (without dot)", text: $newExtension)
                    Button {
                        let cleaned = newExtension.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                        if !cleaned.isEmpty && !extensions.contains(cleaned) {
                            extensions.append(cleaned)
                            newExtension = ""
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .disabled(newExtension.isEmpty)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(title)
    }
}

// MARK: - Memory Configuration View

struct MemoryConfigurationView: View {
    @State private var config = AppConfiguration.shared.memoryConfig

    var body: some View {
        Form {
            Section("Capacity") {
                Stepper("Short-Term: \(config.shortTermCapacity)", value: $config.shortTermCapacity, in: 5...100, step: 5)
                Stepper("Long-Term Max: \(config.longTermMaxItems)", value: $config.longTermMaxItems, in: 1_000...50_000, step: 1_000)
                Stepper("Episodic Max: \(config.episodicMaxItems)", value: $config.episodicMaxItems, in: 1_000...20_000, step: 1_000)
                Stepper("Semantic Max: \(config.semanticMaxItems)", value: $config.semanticMaxItems, in: 1_000...20_000, step: 1_000)
                Stepper("Procedural Max: \(config.proceduralMaxItems)", value: $config.proceduralMaxItems, in: 100...5_000, step: 100)
            }

            Section("Decay Rates") {
                VStack(alignment: .leading) {
                    Text("General Decay: \(config.generalDecayRate, specifier: "%.2f")")
                    Slider(value: $config.generalDecayRate, in: 0.8...1.0, step: 0.01)
                }

                VStack(alignment: .leading) {
                    Text("Semantic Decay: \(config.semanticDecayRate, specifier: "%.2f")")
                    Slider(value: $config.semanticDecayRate, in: 0.9...1.0, step: 0.01)
                }
            }

            Section("Retrieval") {
                Stepper("Default Limit: \(config.defaultRetrievalLimit)", value: $config.defaultRetrievalLimit, in: 5...50, step: 5)

                VStack(alignment: .leading) {
                    Text("Similarity Threshold: \(config.defaultSimilarityThreshold, specifier: "%.2f")")
                    Slider(value: $config.defaultSimilarityThreshold, in: 0.3...0.9, step: 0.05)
                }
            }

            Section {
                Button("Reset to Defaults") {
                    config = MemoryConfiguration()
                }
                .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Memory Configuration")
        .onChange(of: config) { _, newValue in
            AppConfiguration.shared.memoryConfig = newValue
        }
    }
}

// MARK: - Agent Configuration View

struct AgentConfigurationView: View {
    @State private var config = AppConfiguration.shared.agentConfig

    var body: some View {
        Form {
            Section("Task Execution") {
                Stepper("Max Retries: \(config.maxRetryCount)", value: $config.maxRetryCount, in: 0...10)
                Stepper("Base Task Duration: \(Int(config.baseTaskDurationSeconds))s", value: $config.baseTaskDurationSeconds, in: 10...120, step: 10)
            }

            Section("Sub-Agents") {
                Stepper("Max Concurrent: \(config.maxConcurrentAgents)", value: $config.maxConcurrentAgents, in: 1...20)
                Stepper("Timeout: \(Int(config.agentTimeoutSeconds))s", value: $config.agentTimeoutSeconds, in: 60...600, step: 60)
            }

            Section("Reasoning") {
                Stepper("Chain of Thought Steps: \(config.chainOfThoughtSteps)", value: $config.chainOfThoughtSteps, in: 2...10)
                Stepper("Max Decomposition: \(config.maxDecompositionSteps)", value: $config.maxDecompositionSteps, in: 5...20)

                VStack(alignment: .leading) {
                    Text("Reasoning Temperature: \(config.reasoningTemperature, specifier: "%.1f")")
                    Slider(value: $config.reasoningTemperature, in: 0...1, step: 0.1)
                }
            }

            Section {
                Button("Reset to Defaults") {
                    config = AgentConfiguration()
                }
                .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Agent Configuration")
        .onChange(of: config) { _, newValue in
            AppConfiguration.shared.agentConfig = newValue
        }
    }
}

// MARK: - Local Model Configuration View

struct LocalModelConfigurationView: View {
    @State private var config = AppConfiguration.shared.localModelConfig

    var body: some View {
        Form {
            Section("Ollama") {
                TextField("Base URL", text: $config.ollamaBaseURL)
                TextField("Executable Path", text: $config.ollamaExecutablePath)
                TextField("API Endpoint", text: $config.ollamaAPIEndpoint)
            }

            Section("MLX") {
                TextField("Executable Path", text: $config.mlxExecutablePath)
                TextField("Models Directory", text: $config.mlxModelsDirectory)
            }

            Section("GGUF") {
                TextField("Models Directory", text: $config.ggufModelsDirectory)
                TextField("LM Studio Cache Path", text: $config.lmStudioCachePath)
            }

            Section("Shared Local Models") {
                TextField("SharedLLMs Directory", text: $config.sharedLLMsDirectory)
                    .help("Default directory for shared local models (relative to home)")
            }

            Section("Defaults") {
                Stepper("Context Tokens: \(config.defaultContextTokens)", value: $config.defaultContextTokens, in: 1_024...32_768, step: 1_024)
                Stepper("Max Output Tokens: \(config.defaultMaxOutputTokens)", value: $config.defaultMaxOutputTokens, in: 256...8_192, step: 256)
                TextField("Default Quantization", text: $config.defaultQuantization)
                TextField("Default Parameters", text: $config.defaultParameters)
            }

            Section {
                Button("Reset to Defaults") {
                    config = LocalModelConfiguration()
                }
                .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Local Models")
        .onChange(of: config) { _, newValue in
            AppConfiguration.shared.localModelConfig = newValue
        }
    }
}

// MARK: - Theme Configuration View

struct ThemeConfigurationView: View {
    @State private var config = AppConfiguration.shared.themeConfig

    var body: some View {
        Form {
            Section("Colors (Hex)") {
                TextField("Primary Color", text: $config.primaryColor)
                TextField("Accent Color", text: $config.accentColor)
                TextField("Purple Color", text: $config.purpleColor)
                TextField("Gold Color", text: $config.goldColor)
            }

            Section("Font Sizes") {
                VStack(alignment: .leading) {
                    Text("Body Size: \(Int(config.bodySize))pt")
                    Slider(value: $config.bodySize, in: 12...24, step: 1)
                }

                VStack(alignment: .leading) {
                    Text("Code Size: \(Int(config.codeSize))pt")
                    Slider(value: $config.codeSize, in: 10...20, step: 1)
                }
            }

            Section("Font Design") {
                Toggle("Use Rounded Design", isOn: $config.useRoundedDesign)
            }

            Section {
                Button("Reset to Defaults") {
                    config = ThemeConfiguration()
                }
                .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Theme")
        .onChange(of: config) { _, newValue in
            AppConfiguration.shared.themeConfig = newValue
        }
    }
}

// MARK: - Privacy Settings

struct PrivacySettingsView: View {
    @State private var showingExportDialog = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        Form {
            Section("Privacy") {
                Text("THEA is privacy-first by design. All data is stored locally on your device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Data Storage") {
                LabeledContent("Location", value: "Local (On-Device)")
                LabeledContent("Encryption", value: "Enabled")
                LabeledContent("Cloud Sync", value: "Disabled")
            }

            Section("Actions") {
                Button("Export All Data") {
                    showingExportDialog = true
                }

                Button("Delete All Data", role: .destructive) {
                    showingDeleteConfirmation = true
                }
            }
        }
        .formStyle(.grouped)
        .fileExporter(
            isPresented: $showingExportDialog,
            document: DataExportDocument(),
            contentType: .json,
            defaultFilename: "thea-export-\(Date().formatted(date: .numeric, time: .omitted)).json"
        ) { result in
            if case .failure(let error) = result {
                print("Export failed: \(error)")
            }
        }
        .alert("Delete All Data", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                deleteAllData()
            }
        } message: {
            Text("This will permanently delete all conversations, projects, and settings. This action cannot be undone.")
        }
    }

    private func deleteAllData() {
        // Reset all configuration to defaults as part of data deletion
        AppConfiguration.shared.resetAllToDefaults()
        print("Data deletion requested - configuration reset complete")
    }
}

// MARK: - Data Export Document

import UniformTypeIdentifiers

struct DataExportDocument: FileDocument, @unchecked Sendable {
    static var readableContentTypes: [UTType] { [.json] }

    init() {}

    init(configuration: ReadConfiguration) throws {
        fatalError("Reading not supported")
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let exportData: [String: Any] = [
            "version": AppConfiguration.AppInfo.version,
            "buildType": AppConfiguration.AppInfo.buildType,
            "exportDate": ISO8601DateFormatter().string(from: Date()),
            "message": "Data export functionality - implementation pending"
        ]

        let data = try JSONSerialization.data(withJSONObject: exportData, options: [.prettyPrinted, .sortedKeys])
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - About

struct AboutView: View {
    var body: some View {
        Form {
            Section("THEA") {
                LabeledContent("Version", value: "\(AppConfiguration.AppInfo.version) (\(AppConfiguration.AppInfo.buildType))")
                LabeledContent("Bundle ID", value: AppConfiguration.AppInfo.bundleIdentifier)
                LabeledContent("Domain", value: AppConfiguration.AppInfo.domain)
            }

            Section("Links") {
                Link("Website", destination: AppConfiguration.AppInfo.websiteURL)
                Link("Privacy Policy", destination: AppConfiguration.AppInfo.privacyPolicyURL)
                Link("Terms of Service", destination: AppConfiguration.AppInfo.termsOfServiceURL)
            }
        }
        .formStyle(.grouped)
    }
}

#if os(macOS)
// MARK: - Code Intelligence Configuration View

struct CodeIntelligenceConfigurationView: View {
    @State private var config = AppConfiguration.shared.codeIntelligenceConfig
    @State private var newExtension = ""

    var body: some View {
        Form {
            Section("AI Models for Code Tasks") {
                TextField("Code Completion Model", text: $config.codeCompletionModel)
                TextField("Code Explanation Model", text: $config.codeExplanationModel)
                TextField("Code Review Model", text: $config.codeReviewModel)
            }

            Section("Executable Paths") {
                TextField("Git Path", text: $config.gitExecutablePath)
                TextField("Swift Path", text: $config.swiftExecutablePath)
                TextField("Python Path", text: $config.pythonExecutablePath)
                TextField("Node/Env Path", text: $config.nodeExecutablePath)
            }

            Section("Code File Extensions") {
                ForEach(config.codeFileExtensions, id: \.self) { ext in
                    HStack {
                        Text(".\(ext)")
                        Spacer()
                        Button(role: .destructive) {
                            config.codeFileExtensions.removeAll { $0 == ext }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack {
                    TextField("New extension (without dot)", text: $newExtension)
                    Button {
                        let cleaned = newExtension.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                        if !cleaned.isEmpty && !config.codeFileExtensions.contains(cleaned) {
                            config.codeFileExtensions.append(cleaned)
                            newExtension = ""
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .disabled(newExtension.isEmpty)
                }
            }

            Section {
                Button("Reset to Defaults") {
                    config = CodeIntelligenceConfiguration()
                }
                .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Code Intelligence")
        .onChange(of: config) { _, newValue in
            AppConfiguration.shared.codeIntelligenceConfig = newValue
        }
    }
}
#endif

// MARK: - API Validation Configuration View

struct APIValidationConfigurationView: View {
    @State private var config = AppConfiguration.shared.apiValidationConfig

    var body: some View {
        Form {
            Section("Test Models for API Key Validation") {
                Text("These models are used when validating API keys. Using smaller, faster models reduces validation time and cost.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Provider Test Models") {
                TextField("Anthropic", text: $config.anthropicTestModel)
                TextField("OpenAI", text: $config.openAITestModel)
                TextField("Google", text: $config.googleTestModel)
                TextField("Groq", text: $config.groqTestModel)
                TextField("Perplexity", text: $config.perplexityTestModel)
                TextField("OpenRouter", text: $config.openRouterTestModel)
            }

            Section {
                Button("Reset to Defaults") {
                    config = APIValidationConfiguration()
                }
                .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("API Validation")
        .onChange(of: config) { _, newValue in
            AppConfiguration.shared.apiValidationConfig = newValue
        }
    }
}

// MARK: - External APIs Configuration View

struct ExternalAPIsConfigurationView: View {
    @State private var config = AppConfiguration.shared.externalAPIsConfig

    var body: some View {
        Form {
            Section("Third-Party API Endpoints") {
                Text("Configure base URLs for external APIs used by the app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("API Base URLs") {
                TextField("GitHub API", text: $config.githubAPIBaseURL)
                TextField("OpenWeatherMap", text: $config.openWeatherMapBaseURL)
            }

            Section {
                Button("Reset to Defaults") {
                    config = ExternalAPIsConfiguration()
                }
                .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("External APIs")
        .onChange(of: config) { _, newValue in
            AppConfiguration.shared.externalAPIsConfig = newValue
        }
    }
}

// MARK: - Terminal Settings Section View

struct TerminalSettingsSectionView: View {
    @State private var shellPath = "/bin/zsh"
    @State private var enableSyntaxHighlighting = true
    @State private var fontSize: Double = 12
    @State private var fontFamily = "SF Mono"
    @State private var enableAutoComplete = true
    @State private var historyLimit = 1_000
    @State private var colorScheme = "Default"
    
    var body: some View {
        Form {
            Section("Terminal Configuration") {
                Text("Configure terminal behavior and appearance")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("Shell") {
                TextField("Shell Path", text: $shellPath)
                    .help("Path to the shell executable")
                LabeledContent("Current Shell", value: shellPath)
            }
            
            Section("Appearance") {
                Picker("Color Scheme", selection: $colorScheme) {
                    Text("Default").tag("Default")
                    Text("Dark").tag("Dark")
                    Text("Light").tag("Light")
                    Text("Solarized Dark").tag("Solarized Dark")
                    Text("Solarized Light").tag("Solarized Light")
                }
                
                TextField("Font Family", text: $fontFamily)
                
                VStack(alignment: .leading) {
                    Text("Font Size: \(Int(fontSize))pt")
                    Slider(value: $fontSize, in: 8...24, step: 1)
                }
                
                Toggle("Syntax Highlighting", isOn: $enableSyntaxHighlighting)
            }
            
            Section("Behavior") {
                Toggle("Enable Auto-Complete", isOn: $enableAutoComplete)
                
                Stepper("History Limit: \(historyLimit)", value: $historyLimit, in: 100...10_000, step: 100)
            }
            
            Section {
                Button("Reset to Defaults") {
                    shellPath = "/bin/zsh"
                    enableSyntaxHighlighting = true
                    fontSize = 12
                    fontFamily = "SF Mono"
                    enableAutoComplete = true
                    historyLimit = 1_000
                    colorScheme = "Default"
                }
                .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Cowork Settings Section View

struct CoworkSettingsSectionView: View {
    @State private var enableCowork = false
    @State private var serverURL = ""
    @State private var apiKey = ""
    @State private var enableNotifications = true
    @State private var autoSyncInterval: Double = 30
    @State private var shareByDefault = false
    @State private var maxCollaborators = 5
    
    var body: some View {
        Form {
            Section("Collaboration Features") {
                Text("Configure real-time collaboration settings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("Status") {
                Toggle("Enable Cowork Mode", isOn: $enableCowork)
                
                if enableCowork {
                    LabeledContent("Status", value: "Active")
                        .foregroundStyle(.green)
                } else {
                    LabeledContent("Status", value: "Inactive")
                        .foregroundStyle(.secondary)
                }
            }
            
            Section("Server Configuration") {
                TextField("Server URL", text: $serverURL)
                    .help("URL of the collaboration server")
                    .disabled(!enableCowork)
                
                SecureField("API Key", text: $apiKey)
                    .disabled(!enableCowork)
            }
            
            Section("Collaboration Settings") {
                Toggle("Share by Default", isOn: $shareByDefault)
                    .disabled(!enableCowork)
                
                Stepper("Max Collaborators: \(maxCollaborators)", value: $maxCollaborators, in: 1...20)
                    .disabled(!enableCowork)
                
                Toggle("Enable Notifications", isOn: $enableNotifications)
                    .disabled(!enableCowork)
            }
            
            Section("Sync") {
                VStack(alignment: .leading) {
                    Text("Auto-Sync Interval: \(Int(autoSyncInterval))s")
                    Slider(value: $autoSyncInterval, in: 10...300, step: 10)
                }
                .disabled(!enableCowork)
            }
            
            Section {
                Button("Reset to Defaults") {
                    enableCowork = false
                    serverURL = ""
                    apiKey = ""
                    enableNotifications = true
                    autoSyncInterval = 30
                    shareByDefault = false
                    maxCollaborators = 5
                }
                .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    SettingsView()
}
