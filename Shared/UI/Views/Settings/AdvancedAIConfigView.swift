// AdvancedAIConfigView.swift
// Thea
//
// K3: Complete config UI — sliders for all continuous AI/verification values.
// Uses TheaConfig (canonical @Observable config) for persistence via UserDefaults.

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Advanced AI Configuration View

/// Full configuration panel for AI model routing weights, verification thresholds,
/// learning parameters, and verification verification source weights.
struct AdvancedAIConfigView: View {
    @Bindable private var config = TheaConfig.shared
    @State private var showingExportPanel = false
    @State private var showingImportPanel = false
    @State private var showingResetConfirm = false
    @State private var importError: String?
    @State private var showingImportError = false

    var body: some View {
        Form {
            // MARK: - AI Behavior
            Section("AI Behavior") {
                LabeledContent {
                    Slider(value: $config.ai.temperature, in: 0...2, step: 0.05) {
                        EmptyView()
                    }
                } label: {
                    Text("Temperature: \(config.ai.temperature, specifier: "%.2f")")
                }
                .help("Controls randomness. Lower = more focused, higher = more creative")

                LabeledContent {
                    Slider(value: Binding(
                        get: { Double(config.ai.maxTokens) },
                        set: { config.ai.maxTokens = Int($0) }
                    ), in: 256...65536, step: 256) {
                        EmptyView()
                    }
                } label: {
                    Text("Max Tokens: \(config.ai.maxTokens)")
                }
                .help("Maximum tokens per response")

                Toggle("Enable Task Classification", isOn: $config.ai.enableTaskClassification)
                    .help("Classify queries before routing to optimize model selection")
                Toggle("Enable Model Routing", isOn: $config.ai.enableModelRouting)
                    .help("Automatically route to optimal model based on task type")
                Toggle("Enable Query Decomposition", isOn: $config.ai.enableQueryDecomposition)
                    .help("Decompose complex queries into parallel sub-tasks")
                Toggle("Enable Multi-Agent Orchestration", isOn: $config.ai.enableMultiAgentOrchestration)
                    .help("Use multiple AI agents in parallel for complex tasks")
            }

            // MARK: - Learning Parameters
            Section("Learning & Adaptation") {
                LabeledContent {
                    Slider(value: $config.ai.learningRate, in: 0.01...0.5, step: 0.01) {
                        EmptyView()
                    }
                } label: {
                    Text("Learning Rate: \(config.ai.learningRate, specifier: "%.2f")")
                }
                .help("How quickly the model adapts to feedback. Higher = faster but less stable")

                LabeledContent {
                    Slider(value: $config.ai.feedbackDecayFactor, in: 0.1...1.0, step: 0.01) {
                        EmptyView()
                    }
                } label: {
                    Text("Feedback Decay: \(config.ai.feedbackDecayFactor, specifier: "%.2f")")
                }
                .help("How quickly older feedback loses influence. 1.0 = no decay")
            }

            // MARK: - Verification Features
            Section("Verification Features") {
                Toggle("Multi-Model Consensus", isOn: $config.verification.enableMultiModel)
                    .help("Cross-validate responses using multiple AI models")
                Toggle("Web Search Verification", isOn: $config.verification.enableWebSearch)
                    .help("Fact-check responses against web sources")
                Toggle("Code Execution Verification", isOn: $config.verification.enableCodeExecution)
                    .help("Verify code responses by executing them in a sandbox")
                Toggle("Static Analysis Verification", isOn: $config.verification.enableStaticAnalysis)
                    .help("Run static analysis tools on code responses")
                Toggle("Feedback Learning", isOn: $config.verification.enableFeedbackLearning)
                    .help("Learn confidence calibration from user feedback")
            }

            // MARK: - Confidence Thresholds
            Section("Confidence Thresholds") {
                LabeledContent {
                    Slider(value: $config.verification.highConfidenceThreshold, in: 0.5...1.0, step: 0.01) {
                        EmptyView()
                    }
                } label: {
                    Text("High Confidence: \(Int(config.verification.highConfidenceThreshold * 100))%")
                }
                .help("Threshold above which responses are marked as high confidence")

                LabeledContent {
                    Slider(value: $config.verification.mediumConfidenceThreshold, in: 0.2...0.9, step: 0.01) {
                        EmptyView()
                    }
                } label: {
                    Text("Medium Confidence: \(Int(config.verification.mediumConfidenceThreshold * 100))%")
                }
                .help("Threshold above which responses are marked as medium confidence")

                LabeledContent {
                    Slider(value: $config.verification.lowConfidenceThreshold, in: 0.05...0.6, step: 0.01) {
                        EmptyView()
                    }
                } label: {
                    Text("Low Confidence Warning: \(Int(config.verification.lowConfidenceThreshold * 100))%")
                }
                .help("Threshold below which responses show a low confidence warning")
            }

            // MARK: - Verification Weights
            Section("Verification Source Weights") {
                Text("Weights determine how much each verification source contributes to the overall confidence score. Total: \(Int((config.verification.consensusWeight + config.verification.webSearchWeight + config.verification.codeExecutionWeight + config.verification.staticAnalysisWeight + config.verification.feedbackWeight) * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LabeledContent {
                    Slider(value: $config.verification.consensusWeight, in: 0...1, step: 0.01) {
                        EmptyView()
                    }
                } label: {
                    Text("Multi-Model Consensus: \(Int(config.verification.consensusWeight * 100))%")
                }

                LabeledContent {
                    Slider(value: $config.verification.webSearchWeight, in: 0...1, step: 0.01) {
                        EmptyView()
                    }
                } label: {
                    Text("Web Search: \(Int(config.verification.webSearchWeight * 100))%")
                }

                LabeledContent {
                    Slider(value: $config.verification.codeExecutionWeight, in: 0...1, step: 0.01) {
                        EmptyView()
                    }
                } label: {
                    Text("Code Execution: \(Int(config.verification.codeExecutionWeight * 100))%")
                }

                LabeledContent {
                    Slider(value: $config.verification.staticAnalysisWeight, in: 0...1, step: 0.01) {
                        EmptyView()
                    }
                } label: {
                    Text("Static Analysis: \(Int(config.verification.staticAnalysisWeight * 100))%")
                }

                LabeledContent {
                    Slider(value: $config.verification.feedbackWeight, in: 0...1, step: 0.01) {
                        EmptyView()
                    }
                } label: {
                    Text("User Feedback: \(Int(config.verification.feedbackWeight * 100))%")
                }
            }

            // MARK: - Config Management
            Section("Configuration Management") {
                HStack {
                    Button("Export Config") {
                        showingExportPanel = true
                    }
                    .help("Save current configuration to a JSON file")

                    Button("Import Config") {
                        showingImportPanel = true
                    }
                    .help("Load configuration from a JSON file")

                    Spacer()

                    Button("Reset to Defaults", role: .destructive) {
                        showingResetConfirm = true
                    }
                    .help("Reset all AI and verification settings to defaults")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("AI Configuration")
        #if os(macOS)
        .padding()
        #endif
        .onChange(of: config.ai.temperature) { _, _ in config.save() }
        .onChange(of: config.ai.maxTokens) { _, _ in config.save() }
        .onChange(of: config.ai.learningRate) { _, _ in config.save() }
        .onChange(of: config.ai.feedbackDecayFactor) { _, _ in config.save() }
        .onChange(of: config.verification.highConfidenceThreshold) { _, _ in config.save() }
        .onChange(of: config.verification.consensusWeight) { _, _ in config.save() }
        .fileExporter(
            isPresented: $showingExportPanel,
            document: ConfigJSONDocument(config: config),
            contentType: .json,
            defaultFilename: "thea-config.json"
        ) { _ in }
        .fileImporter(
            isPresented: $showingImportPanel,
            allowedContentTypes: [.json]
        ) { result in
            if case .success(let url) = result {
                importConfig(from: url)
            }
        }
        .confirmationDialog("Reset AI Configuration?", isPresented: $showingResetConfirm) {
            Button("Reset to Defaults", role: .destructive) {
                config.reset()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will reset all AI model routing and verification settings to their default values.")
        }
        .alert("Import Failed", isPresented: $showingImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "Unknown error")
        }
    }

    private func importConfig(from url: URL) {
        do {
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            let data = try Data(contentsOf: url)
            let snapshot = try JSONDecoder().decode(ConfigSnapshot.self, from: data)
            config.ai = snapshot.ai
            config.verification = snapshot.verification
            config.save()
        } catch {
            importError = error.localizedDescription
            showingImportError = true
        }
    }
}

// MARK: - Config JSON Document

/// FileDocument wrapper for config export.
/// Captures a snapshot at init time (on the main actor) so fileWrapper() can
/// remain nonisolated as required by the FileDocument protocol.
struct ConfigJSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    private let jsonData: Data

    @MainActor
    init(config: TheaConfig) {
        let snapshot = ConfigSnapshot(
            ai: config.ai,
            memory: config.memory,
            verification: config.verification,
            providers: config.providers,
            ui: config.ui,
            tracking: config.tracking,
            security: config.security
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.jsonData = (try? encoder.encode(snapshot)) ?? Data()
    }

    init(configuration: ReadConfiguration) throws {
        self.jsonData = Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: jsonData)
    }
}
