// SettingsConfigurationViewsExtras.swift
// Additional configuration detail views extracted from SettingsConfigurationViews.swift

import SwiftUI

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
