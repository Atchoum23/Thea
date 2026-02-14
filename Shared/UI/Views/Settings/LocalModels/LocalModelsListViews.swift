//
//  LocalModelsListViews.swift
//  Thea
//
//  Model list, configuration, and statistics UI components
//  Extracted from LocalModelsSettingsView.swift for better code organization
//

import SwiftUI

// MARK: - Model List Section

extension LocalModelsSettingsView {
    var modelListSection: some View {
        Section("Installed Models") {
            if modelManager.scannedModels.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "cube.transparent")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)

                    Text("No models found")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text("Add a model directory or download models from HuggingFace")
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

    func modelRow(_ model: ScannedModel) -> some View {
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

            HStack(spacing: 8) {
                Button {
                    showingModelConfig = model
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Menu {
                    Button {
                        modelManager.openModelLocation(model)
                    } label: {
                        Label("Show in Finder", systemImage: "folder")
                    }

                    Button {
                        showingModelConfig = model
                    } label: {
                        Label("Configure", systemImage: "gearshape")
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
                #if os(macOS)
                .menuStyle(.borderlessButton)
                #endif
            }
        }
        .padding()
        #if os(macOS)
        .background(Color(.controlBackgroundColor))
        #else
        .background(Color.secondary.opacity(0.1))
        #endif
        .cornerRadius(8)
    }
}

// MARK: - Model Configuration Section

extension LocalModelsSettingsView {
    var modelConfigurationSection: some View {
        Section("Default Configuration") {
            VStack(alignment: .leading, spacing: 12) {
                // Quantization
                VStack(alignment: .leading, spacing: 4) {
                    Text("Default Quantization")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("", selection: $selectedQuantization) {
                        Text("Q4_K_M (Recommended)").tag("Q4_K_M")
                        Text("Q4_K_S (Smaller)").tag("Q4_K_S")
                        Text("Q5_K_M (Better quality)").tag("Q5_K_M")
                        Text("Q8_0 (High quality)").tag("Q8_0")
                        Text("FP16 (Full precision)").tag("FP16")
                    }
                    .pickerStyle(.menu)
                }

                Divider()

                // GPU Layers
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("GPU Layers")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text("\(gpuLayers)")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }

                    Slider(value: Binding(
                        get: { Double(gpuLayers) },
                        set: { gpuLayers = Int($0) }
                    ), in: 0...64, step: 1)

                    Text("More GPU layers = faster inference but more VRAM usage")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Divider()

                // Context size
                VStack(alignment: .leading, spacing: 4) {
                    Text("Default Context Size")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("", selection: $contextSize) {
                        Text("2048 tokens").tag(2048)
                        Text("4096 tokens").tag(4096)
                        Text("8192 tokens").tag(8192)
                        Text("16384 tokens").tag(16384)
                        Text("32768 tokens").tag(32768)
                    }
                    .pickerStyle(.menu)

                    Text("Larger contexts use more memory but support longer conversations")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}

// MARK: - Statistics Section

extension LocalModelsSettingsView {
    var statisticsSection: some View {
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
}

// MARK: - Model Config Sheet

extension LocalModelsSettingsView {
    func modelConfigSheet(_ model: ScannedModel) -> some View {
        NavigationStack {
            Form {
                Section("Model Information") {
                    HStack {
                        Text("Name")
                        Spacer()
                        Text(model.displayName)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Format")
                        Spacer()
                        Text(model.format.rawValue)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Size")
                        Spacer()
                        Text(model.formattedSize)
                            .foregroundStyle(.secondary)
                    }

                    if let quant = model.quantization {
                        HStack {
                            Text("Quantization")
                            Spacer()
                            Text(quant)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Path") {
                    Text(model.path.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                Section("Custom Configuration") {
                    Text("Per-model configuration coming soon")
                        .foregroundStyle(.tertiary)
                }
            }
            .navigationTitle("Model Configuration")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingModelConfig = nil
                    }
                }
            }
        }
        #if os(macOS)
        .frame(width: 450, height: 400)
        #endif
    }
}

// MARK: - Helper Functions

extension LocalModelsSettingsView {
    func iconForFormat(_ format: ModelFormat) -> String {
        switch format {
        case .mlx:
            "cpu"
        case .gguf:
            "doc.text"
        case .safetensors:
            "lock.doc"
        case .coreML:
            "brain"
        case .unknown:
            "questionmark.circle"
        }
    }

    func colorForFormat(_ format: ModelFormat) -> Color {
        switch format {
        case .mlx:
            .blue
        case .gguf:
            .green
        case .safetensors:
            .purple
        case .coreML:
            .orange
        case .unknown:
            .gray
        }
    }

    func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }

    func estimatedVRAM() -> String {
        // Rough estimate based on system memory
        let memory = ProcessInfo.processInfo.physicalMemory
        let estimatedVram = memory / 2 // Unified memory can share ~50% for GPU
        return formatBytes(estimatedVram)
    }

    func downloadModel(_ modelId: String) {
        Task {
            do {
                _ = try await modelManager.downloadModel(modelId: modelId)
            } catch {
                await MainActor.run {
                    errorMessage = "Download failed: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }

    func deleteModel(_ model: ScannedModel) async {
        do {
            try await modelManager.deleteModel(model)
        } catch {
            errorMessage = "Failed to delete model: \(error.localizedDescription)"
            showingError = true
        }
        modelToDelete = nil
    }
}
