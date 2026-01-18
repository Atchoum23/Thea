import SwiftUI

// MARK: - Model Selector View
// Compact dropdown for selecting AI models with category filtering

struct ModelSelectorView: View {
    @Binding var selectedModel: String
    @State private var catalogManager = ModelCatalogManager.shared
    @State private var config = AppConfiguration.shared.modelSelectionConfig
    @State private var selectedCategory: ModelSelectionConfiguration.ModelCategory
    @State private var showingCategoryPicker = false

    init(selectedModel: Binding<String>) {
        self._selectedModel = selectedModel
        let initialConfig = AppConfiguration.shared.modelSelectionConfig
        self._selectedCategory = State(initialValue: initialConfig.preferredCategory)
    }

    var body: some View {
        HStack(spacing: 8) {
            // Category selector
            Menu {
                ForEach(ModelSelectionConfiguration.ModelCategory.allCases, id: \.self) { category in
                    Button {
                        selectedCategory = category
                        config.preferredCategory = category
                        AppConfiguration.shared.modelSelectionConfig = config
                    } label: {
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
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: selectedCategory.icon)
                        .font(.caption)
                    Text(selectedCategory.rawValue)
                        .font(.caption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.15))
                .cornerRadius(6)
            }
            .help("Model category: \(selectedCategory.description)")

            // Model picker
            Picker("", selection: $selectedModel) {
                ForEach(availableModels, id: \.id) { model in
                    Text(model.displayName)
                        .tag(model.id)
                }
            }
            .pickerStyle(.menu)
            .frame(minWidth: 150)
            .help(modelHelpText)
        }
        .task {
            await catalogManager.refreshIfNeeded()
        }
    }

    private var availableModels: [OpenRouterModel] {
        let categoryModels = catalogManager.getModels(in: selectedCategory)
        if !categoryModels.isEmpty {
            return categoryModels
        }

        // Fallback to predefined models if catalog not loaded
        let predefinedIDs = config.models(for: selectedCategory)
        return predefinedIDs.map { id in
            OpenRouterModel(
                id: id,
                name: id,
                description: nil,
                contextLength: 128_000,
                pricing: OpenRouterPricing(prompt: "0", completion: "0"),
                topProvider: nil,
                architecture: nil
            )
        }
    }

    private var selectedModelInfo: OpenRouterModel? {
        catalogManager.getModel(byID: selectedModel)
    }

    private var modelHelpText: String {
        guard let model = selectedModelInfo else {
            return "Select a model"
        }

        var text = "\(model.providerName) · \(model.formattedContextLength)"

        if model.pricing.promptPrice > 0 {
            text += " · \(model.pricing.formattedPromptPrice) prompt"
        }

        if let description = model.description {
            text += "\n\(description)"
        }

        return text
    }
}

// MARK: - Compact Variant for Input Bar

struct CompactModelSelectorView: View {
    @Binding var selectedModel: String
    @State private var catalogManager = ModelCatalogManager.shared
    @State private var config = AppConfiguration.shared.modelSelectionConfig

    var body: some View {
        Menu {
            ForEach(ModelSelectionConfiguration.ModelCategory.allCases, id: \.self) { category in
                Section(category.rawValue) {
                    ForEach(modelsForCategory(category), id: \.id) { model in
                        Button {
                            selectedModel = model.id
                        } label: {
                            VStack(alignment: .leading) {
                                Text(model.displayName)
                                Text(model.providerName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "cpu")
                    .font(.caption)
                if let model = catalogManager.getModel(byID: selectedModel) {
                    Text(model.displayName)
                        .font(.caption)
                        .lineLimit(1)
                } else {
                    Text("Model")
                        .font(.caption)
                }
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.15))
            .cornerRadius(6)
        }
        .help("Select AI model")
        .task {
            await catalogManager.refreshIfNeeded()
        }
    }

    private func modelsForCategory(_ category: ModelSelectionConfiguration.ModelCategory) -> [OpenRouterModel] {
        let categoryModels = catalogManager.getModels(in: category)
        if !categoryModels.isEmpty {
            return categoryModels
        }

        // Fallback to predefined models
        let predefinedIDs = config.models(for: category)
        return predefinedIDs.map { id in
            OpenRouterModel(
                id: id,
                name: id,
                description: nil,
                contextLength: 128_000,
                pricing: OpenRouterPricing(prompt: "0", completion: "0"),
                topProvider: nil,
                architecture: nil
            )
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ModelSelectorView(selectedModel: .constant("openai/gpt-4o"))

        CompactModelSelectorView(selectedModel: .constant("anthropic/claude-3-5-sonnet"))
    }
    .padding()
    .frame(width: 400)
}
