//
//  LocalModelsSettingsView.swift
//  Thea
//
//  Configure MLX model paths, browse for model directories, download models, and manage resources
//  Now includes AI-powered model recommendations based on usage patterns
//
//  UI components are split across:
//  - LocalModelsRecommendationsViews.swift (AI recommendations)
//  - LocalModelsManagerViews.swift (directories, downloads, Ollama)
//  - LocalModelsListViews.swift (model list, config, statistics)
//

import SwiftUI
#if os(macOS)
    import AppKit
#endif

// MARK: - Local Models Settings View

struct LocalModelsSettingsView: View {
    @State var settingsManager = SettingsManager.shared
    @State var modelManager = MLXModelManager.shared
    @State var recommendationEngine = LocalModelRecommendationEngine.shared
    @State var showingDirectoryPicker = false
    @State var showingDeleteConfirmation = false
    @State var modelToDelete: ScannedModel?
    @State var showingError = false
    @State var errorMessage = ""
    @State var showingModelConfig: ScannedModel?
    @State var showingDownloadManager = false
    @State var showingRecommendationSettings = false

    // Model configuration state
    @State var selectedQuantization: String = "Q4_K_M"
    @State var gpuLayers: Int = 32
    @State var contextSize: Int = 4096

    var body: some View {
        Form {
            systemResourcesSection
            aiRecommendationsSection
            modelDirectoriesSection
            downloadManagerSection
            ollamaConfigSection
            modelListSection
            modelConfigurationSection
            statisticsSection
        }
        .formStyle(.grouped)
        #if os(macOS)
        .padding()
        #endif
        .alert("Error", isPresented: $showingError) {
            Button("OK") { showingError = false }
        } message: {
            Text(errorMessage)
        }
        .confirmationDialog(
            "Delete Model",
            isPresented: $showingDeleteConfirmation,
            presenting: modelToDelete
        ) { model in
            Button("Delete", role: .destructive) {
                Task {
                    await deleteModel(model)
                }
            }
            Button("Cancel", role: .cancel) {
                modelToDelete = nil
            }
        } message: { model in
            Text("Are you sure you want to delete '\(model.name)'? This cannot be undone.")
        }
        .sheet(item: $showingModelConfig) { model in
            modelConfigSheet(model)
        }
        .sheet(isPresented: $showingDownloadManager) {
            downloadManagerSheet
        }
        .sheet(isPresented: $showingRecommendationSettings) {
            recommendationSettingsSheet
        }
    }
}

// MARK: - Preview

#if os(macOS)
#Preview {
    LocalModelsSettingsView()
        .frame(width: 700, height: 800)
}
#else
#Preview {
    NavigationStack {
        LocalModelsSettingsView()
            .navigationTitle("Local Models")
    }
}
#endif
