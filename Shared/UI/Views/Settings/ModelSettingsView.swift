import SwiftUI

// MARK: - Model Settings View
// Configure default models, categories, and model catalog preferences

struct ModelSettingsView: View {
    @State private var config = AppConfiguration.shared.modelSelectionConfig
    @State private var providerConfig = AppConfiguration.shared.providerConfig
    @State private var catalogManager = ModelCatalogManager.shared
    @State private var showingAPIKeySetup = false
    @State private var openRouterAPIKey = ""
    @State private var showingSaveConfirmation = false

    var body: some View {
        Form {
            defaultModelsSection
            modelCategoriesSection
            catalogSection
            openRouterAPIKeySection
        }
        .formStyle(.grouped)
        .padding()
        .alert("API Key Saved", isPresented: $showingSaveConfirmation) {
            Button("OK") { showingSaveConfirmation = false }
        } message: {
            Text("Your OpenRouter API key has been saved securely.")
        }
    }

    // MARK: - Default Models Section

    private var defaultModelsSection: some View {
        Section("Default Models") {
            VStack(alignment: .leading, spacing: 12) {
                // Chat model
                VStack(alignment: .leading, spacing: 4) {
                    Text("Chat Model")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("", selection: $providerConfig.defaultModel) {
                        ForEach(config.allModels, id: \.self) { modelID in
                            Text(formatModelName(modelID))
                                .tag(modelID)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: providerConfig.defaultModel) { _, _ in
                        AppConfiguration.shared.providerConfig = providerConfig
                    }
                }

                Divider()

                // Reasoning model
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reasoning Model")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("", selection: $providerConfig.defaultReasoningModel) {
                        ForEach(config.powerfulModels, id: \.self) { modelID in
                            Text(formatModelName(modelID))
                                .tag(modelID)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: providerConfig.defaultReasoningModel) { _, _ in
                        AppConfiguration.shared.providerConfig = providerConfig
                    }
                }

                Divider()

                // Summarization model
                VStack(alignment: .leading, spacing: 4) {
                    Text("Summarization Model")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("", selection: $providerConfig.defaultSummarizationModel) {
                        ForEach(config.fastModels, id: \.self) { modelID in
                            Text(formatModelName(modelID))
                                .tag(modelID)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: providerConfig.defaultSummarizationModel) { _, _ in
                        AppConfiguration.shared.providerConfig = providerConfig
                    }
                }
            }
        }
    }

    // MARK: - Model Categories Section

    private var modelCategoriesSection: some View {
        Section("Model Categories") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Preferred Category")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("", selection: $config.preferredCategory) {
                    ForEach(ModelSelectionConfiguration.ModelCategory.allCases, id: \.self) { category in
                        Label {
                            VStack(alignment: .leading) {
                                Text(category.rawValue)
                                Text(category.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: category.icon)
                        }
                        .tag(category)
                    }
                }
                #if os(macOS)
                .pickerStyle(.radioGroup)
                #else
                .pickerStyle(.inline)
                #endif
                .onChange(of: config.preferredCategory) { _, _ in
                    AppConfiguration.shared.modelSelectionConfig = config
                }

                Divider()

                // Category model counts
                Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                    ForEach(ModelSelectionConfiguration.ModelCategory.allCases, id: \.self) { category in
                        GridRow {
                            Label(category.rawValue, systemImage: category.icon)
                                .foregroundStyle(.secondary)

                            Text("\(config.models(for: category).count) models")
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Catalog Section

    private var catalogSection: some View {
        Section("Model Catalog") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Available Models")
                            .font(.headline)

                        if catalogManager.isLoading {
                            Text("Loading...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else if let lastFetch = catalogManager.lastFetchDate {
                            Text("Last updated: \(lastFetch, style: .relative) ago")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Not loaded")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Button {
                        Task {
                            await catalogManager.fetchModels()
                        }
                    } label: {
                        HStack {
                            if catalogManager.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(catalogManager.isLoading ? "Loading..." : "Refresh")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(catalogManager.isLoading)
                }

                if !catalogManager.models.isEmpty {
                    Text("\(catalogManager.models.count) models available from OpenRouter")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                if let error = catalogManager.fetchError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Text("Error: \(error.localizedDescription)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - OpenRouter API Key Section

    private var openRouterAPIKeySection: some View {
        Section("OpenRouter API Key") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Required for model catalog and OpenRouter models")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                SecureField("Enter API key", text: $openRouterAPIKey)
                    .textFieldStyle(.roundedBorder)
                    .onAppear {
                        loadAPIKey()
                    }

                HStack {
                    if let url = URL(string: "https://openrouter.ai/keys") {
                        Link("Get API Key →", destination: url)
                            .font(.caption)
                    }

                    Spacer()

                    Button("Save") {
                        saveAPIKey()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(openRouterAPIKey.isEmpty)
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func formatModelName(_ modelID: String) -> String {
        let components = modelID.split(separator: "/")
        guard let modelName = components.last else { return modelID }
        return String(modelName)
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }

    private func loadAPIKey() {
        if let key = try? SecureStorage.shared.loadAPIKey(for: "openrouter") {
            openRouterAPIKey = key
        }
    }

    private func saveAPIKey() {
        do {
            try SecureStorage.shared.saveAPIKey(openRouterAPIKey, for: "openrouter")
            showingSaveConfirmation = true

            // Refresh catalog after saving key
            Task {
                await catalogManager.fetchModels()
            }
        } catch {
            print("⚠️ Failed to save API key: \(error)")
        }
    }
}

#Preview {
    ModelSettingsView()
        .frame(width: 600, height: 700)
}
