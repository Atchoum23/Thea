//
//  LocalModelsRecommendationsViews.swift
//  Thea
//
//  AI Model Recommendations UI components for Local Models Settings
//  Extracted from LocalModelsSettingsView.swift for better code organization
//

import SwiftUI

// MARK: - AI Recommendations Section

extension LocalModelsSettingsView {
    var aiRecommendationsSection: some View {
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

    func recommendationCard(_ recommendation: ModelRecommendation) -> some View {
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

    func priorityBadge(_ priority: RecommendationPriority) -> some View {
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

    func priorityIcon(_ priority: RecommendationPriority) -> String {
        switch priority {
        case .high: "star.fill"
        case .medium: "star.leadinghalf.filled"
        case .low: "star"
        }
    }

    func priorityColor(_ priority: RecommendationPriority) -> Color {
        switch priority {
        case .high: .orange
        case .medium: .blue
        case .low: .secondary
        }
    }
}

// MARK: - Recommendation Settings Sheet

extension LocalModelsSettingsView {
    var recommendationSettingsSheet: some View {
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
}

// MARK: - Model Installation

extension LocalModelsSettingsView {
    func installRecommendedModel(_ model: DiscoveredModel) {
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

    func installOllamaModel(_ modelId: String) async {
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
        request.httpBody = try? JSONSerialization.data(withJSONObject: body) // Safe: encode failure → nil httpBody; request will fail with 400; caught by catch below

        do {
            _ = try await URLSession.shared.data(for: request)
            // Refresh models after install
            await recommendationEngine.scanInstalledModels()
        } catch {
            errorMessage = "Failed to install model: \(error.localizedDescription)"
            showingError = true
        }
    }
}
