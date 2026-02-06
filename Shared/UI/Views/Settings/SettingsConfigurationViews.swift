//
//  SettingsConfigurationViews.swift
//  Thea
//
//  Configuration detail views for Settings
//  Extracted from SettingsView.swift for better code organization
//

import SwiftUI

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
                Stepper("Max Tokens: \(config.defaultMaxTokens)", value: $config.defaultMaxTokens, in: 256 ... 32768, step: 256)

                VStack(alignment: .leading) {
                    Text("Temperature: \(config.defaultTemperature, specifier: "%.2f")")
                    Slider(value: $config.defaultTemperature, in: 0 ... 2, step: 0.1)
                }

                VStack(alignment: .leading) {
                    Text("Top P: \(config.defaultTopP, specifier: "%.2f")")
                    Slider(value: $config.defaultTopP, in: 0 ... 1, step: 0.1)
                }

                Toggle("Stream Responses", isOn: $config.streamResponses)
            }

            Section("Model Defaults") {
                TextField("Default Model", text: $config.defaultModel)
                TextField("Summarization Model", text: $config.defaultSummarizationModel)
                TextField("Reasoning Model", text: $config.defaultReasoningModel)
                TextField("Embedding Model", text: $config.defaultEmbeddingModel)
                Stepper("Embedding Dimensions: \(config.embeddingDimensions)", value: $config.embeddingDimensions, in: 256 ... 4096, step: 256)
            }

            Section("Request Settings") {
                Stepper("Timeout (seconds): \(Int(config.requestTimeoutSeconds))", value: $config.requestTimeoutSeconds, in: 10 ... 300, step: 10)
                Stepper("Max Retries: \(config.maxRetries)", value: $config.maxRetries, in: 0 ... 10)
                Stepper("Retry Delay (seconds): \(Int(config.retryDelaySeconds))", value: $config.retryDelaySeconds, in: 0 ... 10, step: 1)
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
                Stepper("Audio Buffer Size: \(config.audioBufferSize)", value: $config.audioBufferSize, in: 256 ... 4096, step: 256)
            }

            Section("Speech Synthesis") {
                TextField("Speech Language", text: $config.speechLanguage)

                VStack(alignment: .leading) {
                    Text("Speech Rate: \(config.speechRate, specifier: "%.2f")")
                    Slider(value: $config.speechRate, in: 0.1 ... 1.0, step: 0.05)
                }

                VStack(alignment: .leading) {
                    Text("Pitch: \(config.pitchMultiplier, specifier: "%.2f")")
                    Slider(value: $config.pitchMultiplier, in: 0.5 ... 2.0, step: 0.1)
                }

                VStack(alignment: .leading) {
                    Text("Volume: \(config.volume, specifier: "%.2f")")
                    Slider(value: $config.volume, in: 0 ... 1, step: 0.1)
                }
            }

            Section("Conversation Mode") {
                VStack(alignment: .leading) {
                    Text("Silence Threshold: \(config.silenceThresholdSeconds, specifier: "%.1f")s")
                    Slider(value: $config.silenceThresholdSeconds, in: 1 ... 10, step: 0.5)
                }

                VStack(alignment: .leading) {
                    Text("Conversation Timeout: \(Int(config.conversationTimeoutSeconds))s")
                    Slider(value: $config.conversationTimeoutSeconds, in: 10 ... 120, step: 10)
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
                        in: 1 ... 100,
                        step: 1
                    )
                }

                Stepper("Batch Size: \(config.indexingBatchSize)", value: $config.indexingBatchSize, in: 10 ... 500, step: 10)
            }

            Section("Embedding") {
                Stepper("Embedding Dimension: \(config.embeddingDimension)", value: $config.embeddingDimension, in: 128 ... 1536, step: 128)
            }

            Section("Search") {
                Stepper("Default Top K: \(config.defaultSearchTopK)", value: $config.defaultSearchTopK, in: 5 ... 50, step: 5)
                Stepper("Full-Text Top K: \(config.fullTextSearchTopK)", value: $config.fullTextSearchTopK, in: 5 ... 50, step: 5)
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
                        if !cleaned.isEmpty, !extensions.contains(cleaned) {
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
                Stepper("Working Memory: \(config.workingCapacity)", value: $config.workingCapacity, in: 10 ... 500, step: 10)
                Stepper("Episodic Max: \(config.episodicCapacity)", value: $config.episodicCapacity, in: 1000 ... 50000, step: 1000)
                Stepper("Semantic Max: \(config.semanticCapacity)", value: $config.semanticCapacity, in: 1000 ... 100000, step: 5000)
                Stepper("Procedural Max: \(config.proceduralCapacity)", value: $config.proceduralCapacity, in: 100 ... 5000, step: 100)
            }

            Section("Memory Decay") {
                VStack(alignment: .leading) {
                    Text("Decay Rate: \(config.decayRate, specifier: "%.3f")")
                    Slider(value: $config.decayRate, in: 0.9 ... 1.0, step: 0.005)
                }

                VStack(alignment: .leading) {
                    Text("Min Importance: \(config.minImportance, specifier: "%.2f")")
                    Slider(value: $config.minImportance, in: 0 ... 0.5, step: 0.05)
                }

                VStack(alignment: .leading) {
                    Text("Consolidation Interval: \(Int(config.consolidationInterval / 60)) min")
                    Slider(value: $config.consolidationInterval, in: 300 ... 7200, step: 300)
                }
            }

            Section("Retrieval") {
                Stepper("Retrieval Limit: \(config.retrievalLimit)", value: $config.retrievalLimit, in: 1 ... 50, step: 1)

                VStack(alignment: .leading) {
                    Text("Similarity Threshold: \(config.similarityThreshold, specifier: "%.2f")")
                    Slider(value: $config.similarityThreshold, in: 0.1 ... 0.9, step: 0.05)
                }
            }

            Section("Features") {
                Toggle("Active Retrieval", isOn: $config.enableActiveRetrieval)
                Toggle("Context Injection", isOn: $config.enableContextInjection)
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
                Stepper("Max Retries: \(config.maxRetryCount)", value: $config.maxRetryCount, in: 0 ... 10)
                Stepper("Base Task Duration: \(Int(config.baseTaskDurationSeconds))s", value: $config.baseTaskDurationSeconds, in: 10 ... 120, step: 10)
            }

            Section("Sub-Agents") {
                Stepper("Max Concurrent: \(config.maxConcurrentAgents)", value: $config.maxConcurrentAgents, in: 1 ... 20)
                Stepper("Timeout: \(Int(config.agentTimeoutSeconds))s", value: $config.agentTimeoutSeconds, in: 60 ... 600, step: 60)
            }

            Section("Reasoning") {
                Stepper("Chain of Thought Steps: \(config.chainOfThoughtSteps)", value: $config.chainOfThoughtSteps, in: 2 ... 10)
                Stepper("Max Decomposition: \(config.maxDecompositionSteps)", value: $config.maxDecompositionSteps, in: 5 ... 20)

                VStack(alignment: .leading) {
                    Text("Reasoning Temperature: \(config.reasoningTemperature, specifier: "%.1f")")
                    Slider(value: $config.reasoningTemperature, in: 0 ... 1, step: 0.1)
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
                Stepper("Context Tokens: \(config.defaultContextTokens)", value: $config.defaultContextTokens, in: 1024 ... 32768, step: 1024)
                Stepper("Max Output Tokens: \(config.defaultMaxOutputTokens)", value: $config.defaultMaxOutputTokens, in: 256 ... 8192, step: 256)
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
                    Slider(value: $config.bodySize, in: 12 ... 24, step: 1)
                }

                VStack(alignment: .leading) {
                    Text("Code Size: \(Int(config.codeSize))pt")
                    Slider(value: $config.codeSize, in: 10 ... 20, step: 1)
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
                        if !cleaned.isEmpty, !config.codeFileExtensions.contains(cleaned) {
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
