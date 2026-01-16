import SwiftUI
#if os(macOS)
import AppKit
#endif

// MARK: - Local Models Settings View
// Configure MLX model paths, browse for model directories, and view installed models

struct LocalModelsSettingsView: View {
    @State private var settingsManager = SettingsManager.shared
    @State private var modelManager = MLXModelManager.shared
    @State private var showingDirectoryPicker = false
    @State private var showingDeleteConfirmation = false
    @State private var modelToDelete: ScannedModel?
    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        Form {
            modelDirectoriesSection
            ollamaConfigSection
            modelListSection
            statisticsSection
        }
        .formStyle(.grouped)
        .padding()
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
    }

    // MARK: - Model Directories Section

    private var modelDirectoriesSection: some View {
        Section("Model Directories") {
            VStack(alignment: .leading, spacing: 12) {
                Text("MLX models path")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    TextField("Path", text: $settingsManager.mlxModelsPath)
                        .textFieldStyle(.roundedBorder)

                    Button("Browse") {
                        browseForDirectory()
                    }
                    .buttonStyle(.bordered)
                }

                if modelManager.modelDirectories.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Text("No model directories configured")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Configured directories:")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ForEach(modelManager.modelDirectories, id: \.self) { directory in
                            HStack {
                                Image(systemName: "folder")
                                    .foregroundStyle(.secondary)
                                Text(directory.path)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Spacer()

                                Button {
                                    Task {
                                        await modelManager.removeModelDirectory(directory)
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Button {
                    Task {
                        await createDefaultDirectory()
                    }
                } label: {
                    Label("Create Default Directory", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.bordered)

                Button {
                    Task {
                        await modelManager.refreshModels()
                    }
                } label: {
                    HStack {
                        if modelManager.isScanning {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(modelManager.isScanning ? "Scanning..." : "Refresh Models")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(modelManager.isScanning)
            }
        }
    }

    // MARK: - Ollama Configuration Section

    private var ollamaConfigSection: some View {
        Section("Ollama Configuration") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Enable Ollama", isOn: $settingsManager.ollamaEnabled)

                if settingsManager.ollamaEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ollama URL")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextField("http://localhost:11434", text: $settingsManager.ollamaURL)
                            .textFieldStyle(.roundedBorder)

                        Text("Default: http://localhost:11434")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    // MARK: - Model List Section

    private var modelListSection: some View {
        Section("Installed Models") {
            if modelManager.scannedModels.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "cube.transparent")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)

                    Text("No models found")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text("Add a model directory or place models in the default location")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(modelManager.scannedModels) { model in
                            modelRow(model)
                        }
                    }
                }
                .frame(height: 300)
            }
        }
    }

    private func modelRow(_ model: ScannedModel) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconForFormat(model.format))
                .font(.title2)
                .foregroundStyle(colorForFormat(model.format))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(model.displayName)
                    .font(.headline)

                HStack(spacing: 12) {
                    Label(model.format.rawValue, systemImage: "doc")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Label(model.formattedSize, systemImage: "internaldrive")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let quant = model.quantization {
                        Label(quant, systemImage: "waveform")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(model.path.path)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            Menu {
                Button {
                    modelManager.openModelLocation(model)
                } label: {
                    Label("Show in Finder", systemImage: "folder")
                }

                Divider()

                Button(role: .destructive) {
                    modelToDelete = model
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - Statistics Section

    private var statisticsSection: some View {
        Section("Statistics") {
            let stats = modelManager.getStatistics()

            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                GridRow {
                    Text("Total Models:")
                        .foregroundStyle(.secondary)
                    Text("\(stats.totalModels)")
                        .fontWeight(.semibold)
                }

                GridRow {
                    Text("MLX Models:")
                        .foregroundStyle(.secondary)
                    Text("\(stats.mlxModels)")
                }

                GridRow {
                    Text("GGUF Models:")
                        .foregroundStyle(.secondary)
                    Text("\(stats.ggufModels)")
                }

                GridRow {
                    Text("Total Size:")
                        .foregroundStyle(.secondary)
                    Text(stats.formattedTotalSize)
                        .fontWeight(.semibold)
                }

                if let lastScan = stats.lastScanDate {
                    GridRow {
                        Text("Last Scan:")
                            .foregroundStyle(.secondary)
                        Text(lastScan, style: .relative)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    // MARK: - Helper Functions

    private func iconForFormat(_ format: ModelFormat) -> String {
        switch format {
        case .mlx:
            return "cpu"
        case .gguf:
            return "doc.text"
        case .safetensors:
            return "lock.doc"
        case .coreML:
            return "brain"
        case .unknown:
            return "questionmark.circle"
        }
    }

    private func colorForFormat(_ format: ModelFormat) -> Color {
        switch format {
        case .mlx:
            return .blue
        case .gguf:
            return .green
        case .safetensors:
            return .purple
        case .coreML:
            return .orange
        case .unknown:
            return .gray
        }
    }

    private func browseForDirectory() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Model Directory"
        panel.message = "Choose a directory containing MLX or GGUF models"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                settingsManager.mlxModelsPath = url.path
                Task {
                    await modelManager.addModelDirectory(url)
                }
            }
        }
        #endif
    }

    private func createDefaultDirectory() async {
        do {
            try await modelManager.createDefaultDirectoryIfNeeded()
            await modelManager.refreshModels()
        } catch {
            errorMessage = "Failed to create default directory: \(error.localizedDescription)"
            showingError = true
        }
    }

    private func deleteModel(_ model: ScannedModel) async {
        do {
            try await modelManager.deleteModel(model)
        } catch {
            errorMessage = "Failed to delete model: \(error.localizedDescription)"
            showingError = true
        }
        modelToDelete = nil
    }
}

#Preview {
    LocalModelsSettingsView()
        .frame(width: 600, height: 700)
}
