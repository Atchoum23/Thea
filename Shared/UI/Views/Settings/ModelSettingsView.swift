import SwiftUI

// MARK: - Model Settings View

// Configure default models, categories, model catalog preferences, favorites, and comparison

struct ModelSettingsView: View {
    @State var config = AppConfiguration.shared.modelSelectionConfig
    @State var providerConfig = AppConfiguration.shared.providerConfig
    @State var catalogManager = ModelCatalogManager.shared
    @State var settingsManager = SettingsManager.shared

    // UI State
    @State var showingModelDetail: OpenRouterModel?
    @State var showingComparison = false
    @State var selectedForComparison: Set<String> = []
    @State private var searchText = ""
    @State private var selectedCategory: ModelSelectionConfiguration.ModelCategory?

    var body: some View {
        Form {
            orchestratorInfoSection
            favoritesSection
            defaultModelsSection
            modelCategoriesSection
            catalogSection
            modelListSection
        }
        .formStyle(.grouped)
        #if os(macOS)
        .padding()
        #endif
        .sheet(item: $showingModelDetail) { model in
            modelDetailSheet(model)
        }
        .sheet(isPresented: $showingComparison) {
            modelComparisonSheet
        }
    }

    // MARK: - Orchestrator Info Section

    private var orchestratorInfoSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .font(.title2)
                        .foregroundStyle(.purple)
                        .accessibilityHidden(true)
                    Text("AI Orchestrator Active")
                        .font(.headline)
                }

                Text("The AI orchestrator automatically routes queries to optimal models based on task type, complexity, and model capabilities. Default models below serve as fallbacks when orchestration is disabled or cannot determine the best model.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Image(systemName: "arrow.right.circle")
                        .foregroundStyle(.theaInfo)
                        .accessibilityHidden(true)
                    Text("Configure orchestration in the **Orchestrator** tab")
                        .font(.caption)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Intelligent Routing")
        }
    }

    // MARK: - Favorites Section

    private var favoritesSection: some View {
        Section("Favorite Models") {
            if favoriteModels.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "star")
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        Text("No favorite models")
                            .foregroundStyle(.secondary)
                    }

                    Text("Star models from the catalog below to add them to your favorites for quick access.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            } else {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 150), spacing: 12)
                ], spacing: 12) {
                    ForEach(favoriteModels, id: \.id) { model in
                        favoriteModelCard(model)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func favoriteModelCard(_ model: OpenRouterModel) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(model.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Spacer()

                Button {
                    toggleFavorite(model.id)
                } label: {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove from favorites")
            }

            Text(model.providerName)
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                Text(model.formattedContextLength)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer()

                Text(model.pricing.formattedPromptPrice)
                    .font(.caption2)
                    .foregroundStyle(.theaInfo)
            }
        }
        .padding(8)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
        .onTapGesture {
            showingModelDetail = model
        }
    }

    private var favoriteModels: [OpenRouterModel] {
        let favoriteIds = settingsManager.favoriteModels
        return catalogManager.models.filter { favoriteIds.contains($0.id) }
    }

    // MARK: - Default Models Section

    private var defaultModelsSection: some View {
        Section("Fallback Models") {
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

                    HStack(spacing: 8) {
                        if selectedForComparison.count >= 2 {
                            Button("Compare (\(selectedForComparison.count))") {
                                showingComparison = true
                            }
                            .buttonStyle(.bordered)
                        }

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
                }

                if !catalogManager.models.isEmpty {
                    Text("\(catalogManager.models.count) models available from OpenRouter")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                if let error = catalogManager.fetchError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.theaWarning)
                            .accessibilityHidden(true)
                        Text("Error: \(error.localizedDescription)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Model List Section

    private var modelListSection: some View {
        Section("Browse Models") {
            // Search and filter
            VStack(spacing: 12) {
                TextField("Search models...", text: $searchText)
                    .textFieldStyle(.roundedBorder)

                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        categoryChip(nil, label: "All")

                        ForEach(ModelSelectionConfiguration.ModelCategory.allCases, id: \.self) { category in
                            categoryChip(category, label: category.rawValue)
                        }
                    }
                }
            }

            // Model list
            if filteredModels.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.title)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)

                    Text("No models found")
                        .foregroundStyle(.secondary)

                    if !searchText.isEmpty {
                        Button("Clear Search") {
                            searchText = ""
                        }
                        .font(.caption)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ForEach(filteredModels.prefix(20), id: \.id) { model in
                    modelRow(model)
                }

                if filteredModels.count > 20 {
                    Text("Showing first 20 of \(filteredModels.count) models. Use search to find specific models.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 4)
                }
            }
        }
    }

}

// MARK: - Model List Helpers

extension ModelSettingsView {

    func categoryChip(_ category: ModelSelectionConfiguration.ModelCategory?, label: String) -> some View {
        Button {
            selectedCategory = category
        } label: {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selectedCategory == category ? Color.theaPrimaryDefault : Color.secondary.opacity(0.2))
                .foregroundStyle(selectedCategory == category ? .white : .primary)
                .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }

    func modelRow(_ model: OpenRouterModel) -> some View {
        HStack(spacing: 12) {
            Button {
                toggleComparison(model.id)
            } label: {
                Image(systemName: selectedForComparison.contains(model.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedForComparison.contains(model.id) ? .theaInfo : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(selectedForComparison.contains(model.id) ? "Remove from comparison" : "Add to comparison")

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(model.displayName)
                        .font(.body)
                        .fontWeight(.medium)

                    if settingsManager.favoriteModels.contains(model.id) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption2)
                            .accessibilityHidden(true)
                    }
                }

                HStack(spacing: 12) {
                    Text(model.providerName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(model.formattedContextLength)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(model.pricing.formattedPromptPrice)
                    .font(.caption)
                    .foregroundStyle(.theaInfo)

                Text("input")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Button {
                toggleFavorite(model.id)
            } label: {
                Image(systemName: settingsManager.favoriteModels.contains(model.id) ? "star.fill" : "star")
                    .foregroundStyle(settingsManager.favoriteModels.contains(model.id) ? .yellow : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(settingsManager.favoriteModels.contains(model.id) ? "Remove from favorites" : "Add to favorites")

            Button {
                showingModelDetail = model
            } label: {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Details for \(model.displayName)")
        }
        .padding(.vertical, 4)
    }

    var filteredModels: [OpenRouterModel] {
        var models = catalogManager.models

        if !searchText.isEmpty {
            models = models.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.id.localizedCaseInsensitiveContains(searchText) ||
                ($0.description?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        if let category = selectedCategory {
            let categoryModelIds = config.models(for: category)
            models = models.filter { categoryModelIds.contains($0.id) }
        }

        return models
    }
}
