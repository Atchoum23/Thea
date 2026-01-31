import SwiftUI
#if os(macOS)
    import AppKit
#endif

// MARK: - Local Models Settings View

// Configure MLX model paths, browse for model directories, download models, and manage resources
// Now includes AI-powered model recommendations based on usage patterns

struct LocalModelsSettingsView: View {
    @State private var settingsManager = SettingsManager.shared
    @State private var modelManager = MLXModelManager.shared
    @State private var recommendationEngine = LocalModelRecommendationEngine.shared
    @State private var showingDirectoryPicker = false
    @State private var showingDeleteConfirmation = false
    @State private var modelToDelete: ScannedModel?
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingModelConfig: ScannedModel?
    @State private var showingDownloadManager = false
    @State private var showingRecommendationSettings = false

    // Model configuration state
    @State private var selectedQuantization: String = "Q4_K_M"
    @State private var gpuLayers: Int = 32
    @State private var contextSize: Int = 4096

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

    // MARK: - AI Recommendations Section

    private var aiRecommendationsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "brain.head.profile")
                                .foregroundStyle(.purple)
                            Text("AI Model Advisor")
                                .font(.headline)
                        }

                        Text("Personalized recommendations based on your usage patterns")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        showingRecommendationSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .buttonStyle(.borderless)
                }

                if recommendationEngine.isScanning {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Analyzing models...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if recommendationEngine.recommendations.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(.green)
                        Text("No new recommendations - you have great models installed!")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recommended for You")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(recommendationEngine.recommendations) { rec in
                                    recommendationCard(rec)
                                }
                            }
                        }
                    }
                }

                // Last scan info
                if let lastScan = recommendationEngine.lastScanDate {
                    HStack {
                        Text("Last updated:")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(lastScan, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        Spacer()

                        Button("Refresh") {
                            Task {
                                await recommendationEngine.scanInstalledModels()
                                await recommendationEngine.discoverAvailableModels()
                                await recommendationEngine.generateRecommendations()
                            }
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .disabled(recommendationEngine.isScanning)
                    }
                }
            }
        } header: {
            HStack {
                Text("Smart Recommendations")
                Spacer()
                if recommendationEngine.configuration.enableProactiveRecommendations {
                    Text("Active")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .foregroundStyle(.green)
                        .cornerRadius(4)
                }
            }
        }
    }

    private func recommendationCard(_ recommendation: ModelRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                priorityBadge(recommendation.priority)
                Spacer()
                Text(String(format: "%.0f%% match", recommendation.score * 100))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(recommendation.model.name)
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(1)

            Text(recommendation.model.author)
                .font(.caption2)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(recommendation.reasons.prefix(2), id: \.self) { reason in
                    HStack(alignment: .top, spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.caption2)
                            .foregroundStyle(.green)
                        Text(reason)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }

            HStack {
                Text(String(format: "%.1f GB", recommendation.model.estimatedSizeGB))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer()

                Button("Install") {
                    installRecommendedModel(recommendation.model)
                }
                .font(.caption2)
                .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .frame(width: 180, height: 180)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }

    private func priorityBadge(_ priority: RecommendationPriority) -> some View {
        HStack(spacing: 4) {
            Image(systemName: priorityIcon(priority))
                .font(.caption2)
            Text(priority.rawValue.capitalized)
                .font(.caption2)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(priorityColor(priority).opacity(0.2))
        .foregroundStyle(priorityColor(priority))
        .cornerRadius(4)
    }

    private func priorityIcon(_ priority: RecommendationPriority) -> String {
        switch priority {
        case .high: "star.fill"
        case .medium: "star.leadinghalf.filled"
        case .low: "star"
        }
    }

    private func priorityColor(_ priority: RecommendationPriority) -> Color {
        switch priority {
        case .high: .orange
        case .medium: .blue
        case .low: .secondary
        }
    }

    private func installRecommendedModel(_ model: DiscoveredModel) {
        // Trigger download based on source
        if model.source == .ollamaLibrary {
            // Install via Ollama
            Task {
                await installOllamaModel(model.id)
            }
        } else {
            // Download from HuggingFace
            downloadModel(model.downloadURL)
        }
    }

    private func installOllamaModel(_ modelId: String) async {
        guard settingsManager.ollamaEnabled else {
            errorMessage = "Please enable Ollama first"
            showingError = true
            return
        }

        let ollamaURL = settingsManager.ollamaURL.isEmpty
            ? "http://localhost:11434"
            : settingsManager.ollamaURL

        guard let url = URL(string: "\(ollamaURL)/api/pull") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["name": modelId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            _ = try await URLSession.shared.data(for: request)
            // Refresh models after install
            await recommendationEngine.scanInstalledModels()
        } catch {
            errorMessage = "Failed to install model: \(error.localizedDescription)"
            showingError = true
        }
    }

    // MARK: - Recommendation Settings Sheet

    private var recommendationSettingsSheet: some View {
        NavigationStack {
            Form {
                Section("Discovery Settings") {
                    Toggle("Enable Auto-Discovery", isOn: Binding(
                        get: { recommendationEngine.configuration.enableAutoDiscovery },
                        set: { newValue in
                            var config = recommendationEngine.configuration
                            config.enableAutoDiscovery = newValue
                            recommendationEngine.updateConfiguration(config)
                        }
                    ))

                    Toggle("Proactive Recommendations", isOn: Binding(
                        get: { recommendationEngine.configuration.enableProactiveRecommendations },
                        set: { newValue in
                            var config = recommendationEngine.configuration
                            config.enableProactiveRecommendations = newValue
                            recommendationEngine.updateConfiguration(config)
                        }
                    ))

                    Stepper(
                        "Scan Interval: \(recommendationEngine.configuration.scanIntervalHours)h",
                        value: Binding(
                            get: { recommendationEngine.configuration.scanIntervalHours },
                            set: { newValue in
                                var config = recommendationEngine.configuration
                                config.scanIntervalHours = newValue
                                recommendationEngine.updateConfiguration(config)
                            }
                        ),
                        in: 1...168
                    )
                }

                Section("Model Preferences") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Max Model Size")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Picker("", selection: Binding(
                            get: { recommendationEngine.configuration.maxModelSizeGB },
                            set: { newValue in
                                var config = recommendationEngine.configuration
                                config.maxModelSizeGB = newValue
                                recommendationEngine.updateConfiguration(config)
                            }
                        )) {
                            Text("4 GB").tag(4.0)
                            Text("8 GB").tag(8.0)
                            Text("16 GB").tag(16.0)
                            Text("32 GB").tag(32.0)
                        }
                        .pickerStyle(.segmented)
                    }

                    Picker("Preferred Quantization", selection: Binding(
                        get: { recommendationEngine.configuration.preferredQuantization },
                        set: { newValue in
                            var config = recommendationEngine.configuration
                            config.preferredQuantization = newValue
                            recommendationEngine.updateConfiguration(config)
                        }
                    )) {
                        Text("4-bit (Smaller)").tag("4bit")
                        Text("8-bit (Better Quality)").tag("8bit")
                        Text("FP16 (Full Precision)").tag("fp16")
                    }

                    Stepper(
                        "Max Recommendations: \(recommendationEngine.configuration.maxRecommendations)",
                        value: Binding(
                            get: { recommendationEngine.configuration.maxRecommendations },
                            set: { newValue in
                                var config = recommendationEngine.configuration
                                config.maxRecommendations = newValue
                                recommendationEngine.updateConfiguration(config)
                            }
                        ),
                        in: 1...10
                    )
                }

                Section("Usage Profile") {
                    let profile = recommendationEngine.userProfile

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your task distribution")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if profile.taskDistribution.isEmpty {
                            Text("No usage data yet. Use Thea more to get personalized recommendations!")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        } else {
                            ForEach(Array(profile.taskDistribution.sorted { $0.value > $1.value }.prefix(5)), id: \.key) { task, weight in
                                HStack {
                                    Text(task.displayName)
                                        .font(.caption)

                                    Spacer()

                                    Text(String(format: "%.0f%%", weight * 100))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    if !profile.taskDistribution.isEmpty {
                        Button("Reset Usage Data") {
                            // Would reset the profile
                        }
                        .foregroundStyle(.red)
                    }
                }

                Section("Installed Models") {
                    Text("\(recommendationEngine.installedModels.count) models detected")
                        .font(.caption)

                    ForEach(recommendationEngine.installedModels) { model in
                        HStack {
                            Image(systemName: model.source == .mlx ? "cpu" : "server.rack")
                                .foregroundStyle(model.source == .mlx ? .blue : .green)

                            VStack(alignment: .leading) {
                                Text(model.name)
                                    .font(.caption)
                                Text(model.formattedSize)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Recommendation Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingRecommendationSettings = false
                    }
                }
            }
        }
        #if os(macOS)
        .frame(width: 500, height: 600)
        #endif
    }

    // MARK: - System Resources Section

    private var systemResourcesSection: some View {
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

    // MARK: - Download Manager Section

    private var downloadManagerSection: some View {
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

    private func quickDownloadCard(name: String, size: String, modelId: String) -> some View {
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

    // MARK: - Model Configuration Section

    private var modelConfigurationSection: some View {
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

    // MARK: - Model Config Sheet

    private func modelConfigSheet(_ model: ScannedModel) -> some View {
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

    // MARK: - Download Manager Sheet

    private var downloadManagerSheet: some View {
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

    private func filterChip(_ label: String, selected: Bool) -> some View {
        Text(label)
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(selected ? Color.blue : Color.secondary.opacity(0.2))
            .foregroundStyle(selected ? .white : .primary)
            .cornerRadius(16)
    }

    private func downloadableModelRow(name: String, author: String, size: String, downloads: String) -> some View {
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

    // MARK: - Helper Functions

    private func iconForFormat(_ format: ModelFormat) -> String {
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

    private func colorForFormat(_ format: ModelFormat) -> Color {
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

    private func browseForDirectory() {
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

    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }

    private func estimatedVRAM() -> String {
        // Rough estimate based on system memory
        let memory = ProcessInfo.processInfo.physicalMemory
        let estimatedVram = memory / 2 // Unified memory can share ~50% for GPU
        return formatBytes(estimatedVram)
    }

    private func downloadModel(_ modelId: String) {
        // TODO: Implement actual download
        print("Downloading model: \(modelId)")
    }

    func testOllamaConnection() {
        // TODO: Implement connection test
        print("Testing Ollama connection to: \(settingsManager.ollamaURL)")
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
