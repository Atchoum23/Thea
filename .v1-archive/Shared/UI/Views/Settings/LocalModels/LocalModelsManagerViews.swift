//
//  LocalModelsManagerViews.swift
//  Thea
//
//  Model directory, download, and Ollama configuration UI components
//  Extracted from LocalModelsSettingsView.swift for better code organization
//

import SwiftUI
#if os(macOS)
    import AppKit
#endif

// MARK: - System Resources Section

extension LocalModelsSettingsView {
    var systemResourcesSection: some View {
        Section("System Resources") {
            VStack(alignment: .leading, spacing: 12) {
                // Memory usage
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Available Memory")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(formatBytes(ProcessInfo.processInfo.physicalMemory))
                            .font(.headline)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Estimated VRAM")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(estimatedVRAM())
                            .font(.headline)
                            .foregroundStyle(.blue)
                    }
                }

                Divider()

                // Resource limits
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Memory Limit")
                        Spacer()
                        Picker("", selection: .constant("auto")) {
                            Text("Auto").tag("auto")
                            Text("4 GB").tag("4")
                            Text("8 GB").tag("8")
                            Text("16 GB").tag("16")
                            Text("32 GB").tag("32")
                        }
                        .frame(width: 120)
                    }

                    Text("Maximum memory allocation for local model inference.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Toggle("Preload Default Model", isOn: .constant(false))

                Text("Keep the default local model loaded in memory for faster responses.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - Model Directories Section

extension LocalModelsSettingsView {
    var modelDirectoriesSection: some View {
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

                HStack(spacing: 12) {
                    Button {
                        Task {
                            await createDefaultDirectory()
                        }
                    } label: {
                        Label("Create Default", systemImage: "folder.badge.plus")
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
                            Text(modelManager.isScanning ? "Scanning..." : "Refresh")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(modelManager.isScanning)
                }
            }
        }
    }

    func browseForDirectory() {
        #if os(macOS)
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.prompt = "Select"
            panel.message = "Choose a directory containing MLX or GGUF models"
            panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser

            let response = panel.runModal()
            if response == .OK, let url = panel.url {
                settingsManager.mlxModelsPath = url.path
                Task {
                    await modelManager.addModelDirectory(url)
                }
            }
        #endif
    }

    func createDefaultDirectory() async {
        do {
            try await modelManager.createDefaultDirectoryIfNeeded()
            await modelManager.refreshModels()
        } catch {
            errorMessage = "Failed to create default directory: \(error.localizedDescription)"
            showingError = true
        }
    }
}

// MARK: - Download Manager Section

extension LocalModelsSettingsView {
    var downloadManagerSection: some View {
        Section("Download Models") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("HuggingFace Integration")
                            .font(.headline)

                        Text("Download optimized MLX models from HuggingFace Hub")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Browse Models") {
                        showingDownloadManager = true
                    }
                    .buttonStyle(.bordered)
                }

                // Quick download suggestions
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recommended Models")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            quickDownloadCard(
                                name: "Llama 3.2 1B",
                                size: "2.3 GB",
                                modelId: "mlx-community/Llama-3.2-1B-Instruct-4bit"
                            )

                            quickDownloadCard(
                                name: "Qwen2.5 3B",
                                size: "4.1 GB",
                                modelId: "mlx-community/Qwen2.5-3B-Instruct-4bit"
                            )

                            quickDownloadCard(
                                name: "Phi-3 Mini",
                                size: "2.0 GB",
                                modelId: "mlx-community/Phi-3.5-mini-instruct-4bit"
                            )

                            quickDownloadCard(
                                name: "Mistral 7B",
                                size: "4.4 GB",
                                modelId: "mlx-community/Mistral-7B-Instruct-v0.3-4bit"
                            )
                        }
                    }
                }
            }
        }
    }

    func quickDownloadCard(name: String, size: String, modelId: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.caption)
                .fontWeight(.medium)

            Text(size)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button("Download") {
                downloadModel(modelId)
            }
            .font(.caption2)
            .buttonStyle(.bordered)
        }
        .padding(8)
        .frame(width: 120)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Ollama Configuration Section

extension LocalModelsSettingsView {
    var ollamaConfigSection: some View {
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

                        HStack {
                            Text("Default: http://localhost:11434")
                                .font(.caption)
                                .foregroundStyle(.tertiary)

                            Spacer()

                            Button("Test Connection") {
                                testOllamaConnection()
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
    }

    func testOllamaConnection() {
        // TODO: Implement connection test
        print("Testing Ollama connection to: \(settingsManager.ollamaURL)")
    }
}

// MARK: - Download Manager Sheet

extension LocalModelsSettingsView {
    var downloadManagerSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                TextField("Search HuggingFace models...", text: .constant(""))
                    .textFieldStyle(.roundedBorder)
                    .padding()

                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterChip("All", selected: true)
                        filterChip("MLX", selected: false)
                        filterChip("4-bit", selected: false)
                        filterChip("8-bit", selected: false)
                        filterChip("< 4GB", selected: false)
                    }
                    .padding(.horizontal)
                }

                Divider()
                    .padding(.top, 8)

                // Model list
                List {
                    downloadableModelRow(
                        name: "Llama 3.2 1B Instruct",
                        author: "mlx-community",
                        size: "2.3 GB",
                        downloads: "10.2K"
                    )

                    downloadableModelRow(
                        name: "Qwen2.5 3B Instruct",
                        author: "mlx-community",
                        size: "4.1 GB",
                        downloads: "8.5K"
                    )

                    downloadableModelRow(
                        name: "Phi-3.5 Mini Instruct",
                        author: "mlx-community",
                        size: "2.0 GB",
                        downloads: "15.3K"
                    )

                    downloadableModelRow(
                        name: "Mistral 7B Instruct v0.3",
                        author: "mlx-community",
                        size: "4.4 GB",
                        downloads: "22.1K"
                    )

                    downloadableModelRow(
                        name: "Gemma 2 2B Instruct",
                        author: "mlx-community",
                        size: "2.8 GB",
                        downloads: "6.7K"
                    )
                }
            }
            .navigationTitle("Download Models")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingDownloadManager = false
                    }
                }
            }
        }
        #if os(macOS)
        .frame(width: 600, height: 500)
        #endif
    }

    func filterChip(_ label: String, selected: Bool) -> some View {
        Text(label)
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(selected ? Color.blue : Color.secondary.opacity(0.2))
            .foregroundStyle(selected ? .white : .primary)
            .cornerRadius(16)
    }

    func downloadableModelRow(name: String, author: String, size: String, downloads: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.body)
                    .fontWeight(.medium)

                HStack(spacing: 12) {
                    Text(author)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Label(size, systemImage: "internaldrive")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Label(downloads, systemImage: "arrow.down.circle")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Button("Download") {
                // Trigger download
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
    }
}
