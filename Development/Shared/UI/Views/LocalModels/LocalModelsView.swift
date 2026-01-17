import SwiftUI
#if os(macOS)
import AppKit
#endif

// MARK: - Local Models View
// Manage locally-run AI models (Ollama, MLX, GGUF)

struct LocalModelsView: View {
    @State private var modelManager = LocalModelManager.shared
    @State private var selectedModel: LocalModel?
    @State private var showingAddPath = false
    @State private var showingModelDownload = false

    var body: some View {
        NavigationSplitView {
            // Sidebar - Model list
            modelSidebar
                .navigationTitle("Local Models")
        } detail: {
            // Detail - Model info and controls
            if let model = selectedModel {
                modelDetail(model: model)
            } else {
                emptyState
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: { showingAddPath = true }) {
                        Label("Add Model Path", systemImage: "folder.badge.plus")
                    }

                    Button(action: { showingModelDownload = true }) {
                        Label("Download Model", systemImage: "arrow.down.circle")
                    }

                    Divider()

                    Button(action: { Task { await modelManager.discoverModels() } }) {
                        Label("Refresh Models", systemImage: "arrow.clockwise")
                    }
                } label: {
                    Label("Options", systemImage: "ellipsis.circle")
                }
            }
        }
        .fileImporter(
            isPresented: $showingAddPath,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handlePathSelection(result)
        }
        .sheet(isPresented: $showingModelDownload) {
            ModelDownloadSheet()
        }
    }

    // MARK: - Model Sidebar

    private var modelSidebar: some View {
        VStack(spacing: 0) {
            // Runtime status
            runtimeStatusBar

            Divider()

            // Model list
            List(selection: $selectedModel) {
                if !modelManager.availableModels.isEmpty {
                    ForEach(modelManager.availableModels) { model in
                        ModelRow(model: model, isRunning: modelManager.runningModels[model.id.uuidString] != nil)
                            .tag(model)
                    }
                }
            }
            .listStyle(.sidebar)
            .overlay {
                if modelManager.availableModels.isEmpty {
                    ContentUnavailableView(
                        "No Models Found",
                        systemImage: "cpu",
                        description: Text("Add a model path or download models to get started")
                    )
                }
            }

            Divider()

            // Custom paths
            customPathsSection
        }
    }

    private var runtimeStatusBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                RuntimeBadge(
                    name: "Ollama",
                    isInstalled: modelManager.isOllamaInstalled
                )

                RuntimeBadge(
                    name: "MLX",
                    isInstalled: modelManager.isMLXInstalled
                )

                Spacer()
            }
            .padding()

            if !modelManager.isOllamaInstalled && !modelManager.isMLXInstalled {
                Text("Install Ollama or MLX to run local models")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
            }
        }
        .background(Color.controlBackground)
    }

    private var customPathsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Model Paths")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 8)

            ForEach(modelManager.customModelPaths, id: \.self) { path in
                HStack {
                    Image(systemName: "folder")
                        .foregroundStyle(.secondary)
                        .font(.caption)

                    Text(path.lastPathComponent)
                        .font(.caption)
                        .lineLimit(1)

                    Spacer()

                    Button(action: { modelManager.removeCustomModelPath(path) }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }

            if modelManager.customModelPaths.isEmpty {
                Text("No custom paths added")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .italic()
                    .padding(.horizontal)
            }
        }
        .padding(.bottom, 8)
        .background(Color.windowBackground)
    }

    // MARK: - Model Detail

    private func modelDetail(model: LocalModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                modelHeader(model)

                Divider()

                // Info
                modelInfo(model)

                Divider()

                // Controls
                modelControls(model)

                Spacer()
            }
            .padding()
        }
    }

    private func modelHeader(_ model: LocalModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "cpu")
                    .font(.largeTitle)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text(model.name)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(model.path.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if modelManager.runningModels[model.id.uuidString] != nil {
                    Text("Running")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(12)
                }
            }
        }
    }

    private func modelInfo(_ model: LocalModel) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
            GridRow {
                Text("Type")
                    .foregroundStyle(.secondary)
                Text(modelTypeLabel(model.type))
            }

            GridRow {
                Text("Format")
                    .foregroundStyle(.secondary)
                Text(model.format)
            }

            if let size = model.sizeInBytes {
                GridRow {
                    Text("Size")
                        .foregroundStyle(.secondary)
                    Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
                }
            }

            GridRow {
                Text("Location")
                    .foregroundStyle(.secondary)
                Text(model.path.deletingLastPathComponent().lastPathComponent)
            }
        }
        .font(.caption)
    }

    private func modelControls(_ model: LocalModel) -> some View {
        VStack(spacing: 12) {
            if modelManager.runningModels[model.name] != nil {
                // Stop button
                Button(action: {
                    stopModel(model)
                }) {
                    Label("Stop Model", systemImage: "stop.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)

                // Instance info
                Text("Model is currently running")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                // Start button
                Button(action: {
                    Task {
                        _ = try? await modelManager.loadModel(model)
                    }
                }) {
                    Label("Start Model", systemImage: "play.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!modelManager.isOllamaInstalled && !modelManager.isMLXInstalled)
            }

            // Actions
            HStack(spacing: 12) {
                #if os(macOS)
                Button(action: {
                    NSWorkspace.shared.selectFile(model.path.path, inFileViewerRootedAtPath: "")
                }) {
                    Label("Show in Finder", systemImage: "arrow.right.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                #endif

                Button(action: {
                    testModel(model)
                }) {
                    Label("Test Model", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView(
            "Select a Model",
            systemImage: "cpu",
            description: Text("Choose a model to view details and controls")
        )
    }

    // MARK: - Helper Methods

    private func handlePathSelection(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            modelManager.addCustomModelPath(url)
        } catch {
            print("Failed to add path: \(error)")
        }
    }

    private func stopModel(_ model: LocalModel) {
        modelManager.unloadModel(model.name)
    }

    private func testModel(_ model: LocalModel) {
        Task {
            do {
                // Load model if not already running
                let instance = try await modelManager.loadModel(model)

                // Run a test prompt
                let stream = try await instance.generate(
                    prompt: "Hello! Please respond with a brief greeting.",
                    maxTokens: 50
                )

                var response = ""
                for try await text in stream {
                    response += text
                }

                print("✅ Model test successful!")
                print("Response: \(response)")

                #if os(macOS)
                // Show success alert on macOS
                let alert = NSAlert()
                alert.messageText = "Model Test Successful"
                alert.informativeText = "Model '\(model.name)' responded correctly.\n\nResponse: \(response.prefix(100))..."
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")
                alert.runModal()
                #endif

            } catch {
                print("❌ Model test failed: \(error)")

                #if os(macOS)
                // Show error alert on macOS
                let alert = NSAlert()
                alert.messageText = "Model Test Failed"
                alert.informativeText = "Failed to test model '\(model.name)'.\n\nError: \(error.localizedDescription)"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
                #endif
            }
        }
    }

    private func modelTypeLabel(_ type: LocalModelType) -> String {
        switch type {
        case .ollama: return "Ollama"
        case .mlx: return "MLX"
        case .gguf: return "GGUF"
        case .coreML: return "Core ML"
        case .unknown: return "Unknown"
        }
    }
}

// MARK: - Model Row

struct ModelRow: View {
    let model: LocalModel
    let isRunning: Bool

    var body: some View {
        HStack {
            Image(systemName: isRunning ? "circle.fill" : "circle")
                .foregroundStyle(isRunning ? .green : .secondary)
                .font(.caption)

            VStack(alignment: .leading, spacing: 4) {
                Text(model.name)
                    .font(.body)

                HStack(spacing: 8) {
                    Text(modelTypeLabel(model.type))
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(4)

                    if let size = model.sizeInBytes {
                        Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func modelTypeLabel(_ type: LocalModelType) -> String {
        switch type {
        case .ollama: return "Ollama"
        case .mlx: return "MLX"
        case .gguf: return "GGUF"
        case .coreML: return "Core ML"
        case .unknown: return "Unknown"
        }
    }
}

// MARK: - Runtime Badge

struct RuntimeBadge: View {
    let name: String
    let isInstalled: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isInstalled ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(isInstalled ? .green : .secondary)
                .font(.caption)

            Text(name)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Model Download Sheet

struct ModelDownloadSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Download Models")
                .font(.title2)
                .fontWeight(.bold)

            Text("Download models via Ollama or MLX")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                Text("Ollama Models:")
                    .font(.headline)

                Text("Run in Terminal:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("ollama pull llama3.2:3b")
                    .font(.system(.caption, design: .monospaced))
                    .padding(8)
                    .background(Color.controlBackground)
                    .cornerRadius(4)

                Text("ollama pull mistral:7b")
                    .font(.system(.caption, design: .monospaced))
                    .padding(8)
                    .background(Color.controlBackground)
                    .cornerRadius(4)
            }
            .padding()
            .background(Color.windowBackground)
            .cornerRadius(8)

            Spacer()

            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(width: 400, height: 350)
    }
}

#Preview {
    LocalModelsView()
}
