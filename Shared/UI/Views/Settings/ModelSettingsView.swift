import SwiftUI

// MARK: - Model Settings View

// Configure default models, categories, model catalog preferences, favorites, and comparison

struct ModelSettingsView: View {
    @State private var config = AppConfiguration.shared.modelSelectionConfig
    @State private var providerConfig = AppConfiguration.shared.providerConfig
    @State private var catalogManager = ModelCatalogManager.shared
    @State private var settingsManager = SettingsManager.shared

    // UI State
    @State private var showingModelDetail: OpenRouterModel?
    @State private var showingComparison = false
    @State private var selectedForComparison: Set<String> = []
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
                        .foregroundStyle(.blue)
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
                    .foregroundStyle(.blue)
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
                            .foregroundStyle(.orange)
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

    private func categoryChip(_ category: ModelSelectionConfiguration.ModelCategory?, label: String) -> some View {
        Button {
            selectedCategory = category
        } label: {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selectedCategory == category ? Color.blue : Color.secondary.opacity(0.2))
                .foregroundStyle(selectedCategory == category ? .white : .primary)
                .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }

    private func modelRow(_ model: OpenRouterModel) -> some View {
        HStack(spacing: 12) {
            // Selection for comparison
            Button {
                toggleComparison(model.id)
            } label: {
                Image(systemName: selectedForComparison.contains(model.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedForComparison.contains(model.id) ? .blue : .secondary)
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
                    .foregroundStyle(.blue)

                Text("input")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Favorite button
            Button {
                toggleFavorite(model.id)
            } label: {
                Image(systemName: settingsManager.favoriteModels.contains(model.id) ? "star.fill" : "star")
                    .foregroundStyle(settingsManager.favoriteModels.contains(model.id) ? .yellow : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(settingsManager.favoriteModels.contains(model.id) ? "Remove from favorites" : "Add to favorites")

            // Info button
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

    private var filteredModels: [OpenRouterModel] {
        var models = catalogManager.models

        // Filter by search
        if !searchText.isEmpty {
            models = models.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.id.localizedCaseInsensitiveContains(searchText) ||
                ($0.description?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        // Filter by category
        if let category = selectedCategory {
            let categoryModelIds = config.models(for: category)
            models = models.filter { categoryModelIds.contains($0.id) }
        }

        return models
    }

    // MARK: - Model Detail Sheet

    private func modelDetailSheet(_ model: OpenRouterModel) -> some View {
        NavigationStack {
            Form {
                // Overview
                Section("Overview") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(model.displayName)
                                    .font(.title2)
                                    .fontWeight(.bold)

                                Text(model.providerName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button {
                                toggleFavorite(model.id)
                            } label: {
                                Image(systemName: settingsManager.favoriteModels.contains(model.id) ? "star.fill" : "star")
                                    .font(.title2)
                                    .foregroundStyle(settingsManager.favoriteModels.contains(model.id) ? .yellow : .secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(settingsManager.favoriteModels.contains(model.id) ? "Remove from favorites" : "Add to favorites")
                        }

                        if let description = model.description {
                            Text(description)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Specifications
                Section("Specifications") {
                    HStack {
                        Text("Context Window")
                        Spacer()
                        Text(model.formattedContextLength)
                            .foregroundStyle(.secondary)
                    }

                    if let maxTokens = model.topProvider?.maxCompletionTokens {
                        HStack {
                            Text("Max Output")
                            Spacer()
                            Text("\(maxTokens) tokens")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let modality = model.architecture?.modality {
                        HStack {
                            Text("Modality")
                            Spacer()
                            Text(modality.capitalized)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let tokenizer = model.architecture?.tokenizer {
                        HStack {
                            Text("Tokenizer")
                            Spacer()
                            Text(tokenizer)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Pricing
                Section("Pricing") {
                    HStack {
                        Text("Input")
                        Spacer()
                        Text(model.pricing.formattedPromptPrice)
                            .foregroundStyle(.blue)
                    }

                    HStack {
                        Text("Output")
                        Spacer()
                        Text(model.pricing.formattedCompletionPrice)
                            .foregroundStyle(.blue)
                    }

                    // Cost estimate
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Cost Estimate")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        let inputCost = model.pricing.promptPrice * 1000
                        let outputCost = model.pricing.completionPrice * 500

                        Text("~$\(String(format: "%.4f", inputCost + outputCost)) per typical conversation (1K in, 500 out)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                }

                // Model ID
                Section("Technical") {
                    HStack {
                        Text("Model ID")
                        Spacer()
                        Text(model.id)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }

                // Actions
                Section {
                    Button("Set as Default Chat Model") {
                        providerConfig.defaultModel = model.id
                        AppConfiguration.shared.providerConfig = providerConfig
                        showingModelDetail = nil
                    }

                    Button {
                        toggleComparison(model.id)
                    } label: {
                        HStack {
                            Text(selectedForComparison.contains(model.id) ? "Remove from Comparison" : "Add to Comparison")
                            Spacer()
                            Image(systemName: selectedForComparison.contains(model.id) ? "checkmark" : "plus")
                        }
                    }
                }
            }
            .navigationTitle(model.displayName)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingModelDetail = nil
                    }
                }
            }
        }
        #if os(macOS)
        .frame(width: 500, height: 600)
        #endif
    }

    // MARK: - Model Comparison Sheet

    private var modelComparisonSheet: some View {
        NavigationStack {
            let modelsToCompare = catalogManager.models.filter { selectedForComparison.contains($0.id) }

            ScrollView(.horizontal, showsIndicators: true) {
                HStack(spacing: 0) {
                    // Row headers
                    VStack(alignment: .leading, spacing: 0) {
                        comparisonHeaderCell("")
                        comparisonRowCell("Provider")
                        comparisonRowCell("Context")
                        comparisonRowCell("Input Price")
                        comparisonRowCell("Output Price")
                        comparisonRowCell("Modality")
                    }
                    .frame(width: 120)
                    .background(Color.secondary.opacity(0.1))

                    // Model columns
                    ForEach(modelsToCompare, id: \.id) { model in
                        VStack(alignment: .center, spacing: 0) {
                            comparisonHeaderCell(model.displayName)
                            comparisonValueCell(model.providerName)
                            comparisonValueCell(model.formattedContextLength)
                            comparisonValueCell(model.pricing.formattedPromptPrice, highlight: isLowestPrice(model, in: modelsToCompare, type: .input))
                            comparisonValueCell(model.pricing.formattedCompletionPrice, highlight: isLowestPrice(model, in: modelsToCompare, type: .output))
                            comparisonValueCell(model.architecture?.modality?.capitalized ?? "Text")
                        }
                        .frame(width: 150)
                    }
                }
            }
            .navigationTitle("Model Comparison")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear") {
                        selectedForComparison.removeAll()
                        showingComparison = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingComparison = false
                    }
                }
            }
        }
        #if os(macOS)
        .frame(width: 700, height: 400)
        #endif
    }

    private func comparisonHeaderCell(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .frame(height: 50)
            .frame(maxWidth: .infinity)
            .background(Color.secondary.opacity(0.15))
    }

    private func comparisonRowCell(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(height: 40)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
    }

    private func comparisonValueCell(_ text: String, highlight: Bool = false) -> some View {
        Text(text)
            .font(.caption)
            .fontWeight(highlight ? .bold : .regular)
            .foregroundStyle(highlight ? .green : .primary)
            .frame(height: 40)
            .frame(maxWidth: .infinity)
            .background(highlight ? Color.green.opacity(0.1) : Color.clear)
    }

    private enum PriceType {
        case input, output
    }

    private func isLowestPrice(_ model: OpenRouterModel, in models: [OpenRouterModel], type: PriceType) -> Bool {
        let price = type == .input ? model.pricing.promptPrice : model.pricing.completionPrice
        let lowestPrice = models.map { type == .input ? $0.pricing.promptPrice : $0.pricing.completionPrice }.min() ?? 0
        return price == lowestPrice && lowestPrice > 0
    }

    // MARK: - Helper Methods

    private func formatModelName(_ modelID: String) -> String {
        let components = modelID.split(separator: "/")
        guard let modelName = components.last else { return modelID }
        return String(modelName)
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }

    private func toggleFavorite(_ modelId: String) {
        var favorites = settingsManager.favoriteModels
        if favorites.contains(modelId) {
            favorites.remove(modelId)
        } else {
            favorites.insert(modelId)
        }
        settingsManager.favoriteModels = favorites
    }

    private func toggleComparison(_ modelId: String) {
        if selectedForComparison.contains(modelId) {
            selectedForComparison.remove(modelId)
        } else if selectedForComparison.count < 5 {
            selectedForComparison.insert(modelId)
        }
    }
}

// MARK: - Preview

#if os(macOS)
#Preview {
    ModelSettingsView()
        .frame(width: 700, height: 800)
}
#else
#Preview {
    NavigationStack {
        ModelSettingsView()
            .navigationTitle("Models")
    }
}
#endif
