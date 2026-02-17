// ModelSettingsViewSections.swift
// Supporting views and extension for ModelSettingsView

import SwiftUI

// MARK: - Detail Sheet, Comparison Sheet & Helpers

extension ModelSettingsView {

    // MARK: - Model Detail Sheet

    func modelDetailSheet(_ model: OpenRouterModel) -> some View {
        NavigationStack {
            Form {
                modelDetailOverviewSection(model)
                modelDetailSpecsSection(model)
                modelDetailPricingSection(model)
                modelDetailTechnicalSection(model)
                modelDetailActionsSection(model)
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

    @ViewBuilder
    func modelDetailOverviewSection(_ model: OpenRouterModel) -> some View {
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
    }

    @ViewBuilder
    func modelDetailSpecsSection(_ model: OpenRouterModel) -> some View {
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
    }

    @ViewBuilder
    func modelDetailPricingSection(_ model: OpenRouterModel) -> some View {
        Section("Pricing") {
            HStack {
                Text("Input")
                Spacer()
                Text(model.pricing.formattedPromptPrice)
                    .foregroundStyle(.theaInfo)
            }

            HStack {
                Text("Output")
                Spacer()
                Text(model.pricing.formattedCompletionPrice)
                    .foregroundStyle(.theaInfo)
            }

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
    }

    @ViewBuilder
    func modelDetailTechnicalSection(_ model: OpenRouterModel) -> some View {
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
    }

    @ViewBuilder
    func modelDetailActionsSection(_ model: OpenRouterModel) -> some View {
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

    // MARK: - Model Comparison Sheet

    var modelComparisonSheet: some View {
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

    // MARK: - Comparison Cells

    func comparisonHeaderCell(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .frame(height: 50)
            .frame(maxWidth: .infinity)
            .background(Color.secondary.opacity(0.15))
    }

    func comparisonRowCell(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(height: 40)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
    }

    func comparisonValueCell(_ text: String, highlight: Bool = false) -> some View {
        Text(text)
            .font(.caption)
            .fontWeight(highlight ? .bold : .regular)
            .foregroundStyle(highlight ? .theaSuccess : .primary)
            .frame(height: 40)
            .frame(maxWidth: .infinity)
            .background(highlight ? Color.theaSuccess.opacity(0.1) : Color.clear)
    }

    // MARK: - Price Comparison

    enum PriceType {
        case input, output
    }

    func isLowestPrice(_ model: OpenRouterModel, in models: [OpenRouterModel], type: PriceType) -> Bool {
        let price = type == .input ? model.pricing.promptPrice : model.pricing.completionPrice
        let lowestPrice = models.map { type == .input ? $0.pricing.promptPrice : $0.pricing.completionPrice }.min() ?? 0
        return price == lowestPrice && lowestPrice > 0
    }

    // MARK: - Helper Methods

    func formatModelName(_ modelID: String) -> String {
        let components = modelID.split(separator: "/")
        guard let modelName = components.last else { return modelID }
        return String(modelName)
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }

    func toggleFavorite(_ modelId: String) {
        var favorites = settingsManager.favoriteModels
        if favorites.contains(modelId) {
            favorites.remove(modelId)
        } else {
            favorites.insert(modelId)
        }
        settingsManager.favoriteModels = favorites
    }

    func toggleComparison(_ modelId: String) {
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
