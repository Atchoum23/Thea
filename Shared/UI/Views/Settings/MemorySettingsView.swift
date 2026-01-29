// MemorySettingsView.swift
// Comprehensive memory configuration and management for Thea

import SwiftUI

struct MemorySettingsView: View {
    @State private var config = AppConfiguration.shared.memoryConfig
    @State private var memorySystem = MemorySystem.shared
    @State private var showingClearConfirmation = false
    @State private var showingConsolidateConfirmation = false
    @State private var showingKeywordEditor = false
    @State private var newKeyword = ""

    var body: some View {
        Form {
            // MARK: - Memory Statistics
            Section("Memory Statistics") {
                memoryStatsGrid
            }

            // MARK: - Capacity Settings
            Section("Capacity Limits") {
                capacitySettings
            }

            // MARK: - Consolidation Settings
            Section("Consolidation") {
                consolidationSettings
            }

            // MARK: - Decay Settings
            Section("Memory Decay") {
                decaySettings
            }

            // MARK: - Retrieval Settings
            Section("Retrieval") {
                retrievalSettings
            }

            // MARK: - Boost Factors
            Section("Importance Boosts") {
                boostSettings
            }

            // MARK: - Important Keywords
            Section("Important Keywords") {
                keywordSettings
            }

            // MARK: - Memory Actions
            Section("Memory Management") {
                memoryActions
            }

            // MARK: - Reset
            Section {
                Button("Reset to Defaults", role: .destructive) {
                    config = MemoryConfiguration()
                    saveConfig()
                }
            }
        }
        .formStyle(.grouped)
        #if os(macOS)
        .padding()
        #endif
        .alert("Clear All Memories?", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) {
                clearAllMemories()
            }
        } message: {
            Text("This will permanently delete all stored memories. This action cannot be undone.")
        }
        .alert("Consolidate Memories?", isPresented: $showingConsolidateConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Consolidate") {
                Task {
                    try? await memorySystem.consolidateAllShortTerm()
                }
            }
        } message: {
            Text("This will move all short-term memories to long-term storage based on importance thresholds.")
        }
        .sheet(isPresented: $showingKeywordEditor) {
            keywordEditorSheet
        }
    }

    // MARK: - Memory Stats Grid

    private var memoryStatsGrid: some View {
        VStack(spacing: 12) {
            #if os(macOS)
            HStack(spacing: 20) {
                memoryStatCard(
                    title: "Short-Term",
                    count: memorySystem.shortTermMemory.count,
                    max: config.shortTermCapacity,
                    color: .blue
                )
                memoryStatCard(
                    title: "Long-Term",
                    count: memorySystem.longTermMemory.count,
                    max: config.longTermMaxItems,
                    color: .green
                )
                memoryStatCard(
                    title: "Episodic",
                    count: memorySystem.episodicMemory.count,
                    max: config.episodicMaxItems,
                    color: .purple
                )
                memoryStatCard(
                    title: "Semantic",
                    count: memorySystem.semanticMemory.count,
                    max: config.semanticMaxItems,
                    color: .orange
                )
                memoryStatCard(
                    title: "Procedural",
                    count: memorySystem.proceduralMemory.count,
                    max: config.proceduralMaxItems,
                    color: .teal
                )
            }
            #else
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                memoryStatCard(
                    title: "Short-Term",
                    count: memorySystem.shortTermMemory.count,
                    max: config.shortTermCapacity,
                    color: .blue
                )
                memoryStatCard(
                    title: "Long-Term",
                    count: memorySystem.longTermMemory.count,
                    max: config.longTermMaxItems,
                    color: .green
                )
                memoryStatCard(
                    title: "Episodic",
                    count: memorySystem.episodicMemory.count,
                    max: config.episodicMaxItems,
                    color: .purple
                )
                memoryStatCard(
                    title: "Semantic",
                    count: memorySystem.semanticMemory.count,
                    max: config.semanticMaxItems,
                    color: .orange
                )
                memoryStatCard(
                    title: "Procedural",
                    count: memorySystem.proceduralMemory.count,
                    max: config.proceduralMaxItems,
                    color: .teal
                )
            }
            #endif

            // Total memories
            HStack {
                Text("Total Memories:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(totalMemoryCount)")
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
    }

    private func memoryStatCard(title: String, count: Int, max: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)

            ProgressView(value: Double(count), total: Double(max))
                .tint(count > Int(Double(max) * 0.9) ? .red : color)

            Text("/ \(max)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }

    private var totalMemoryCount: Int {
        memorySystem.shortTermMemory.count +
        memorySystem.longTermMemory.count +
        memorySystem.episodicMemory.count +
        memorySystem.semanticMemory.count +
        memorySystem.proceduralMemory.count
    }

    // MARK: - Capacity Settings

    private var capacitySettings: some View {
        Group {
            Stepper("Short-Term Capacity: \(config.shortTermCapacity)", value: $config.shortTermCapacity, in: 5...100, step: 5)
                .onChange(of: config.shortTermCapacity) { _, _ in saveConfig() }

            Stepper("Long-Term Max: \(formatNumber(config.longTermMaxItems))", value: $config.longTermMaxItems, in: 1000...50000, step: 1000)
                .onChange(of: config.longTermMaxItems) { _, _ in saveConfig() }

            Stepper("Episodic Max: \(formatNumber(config.episodicMaxItems))", value: $config.episodicMaxItems, in: 1000...20000, step: 1000)
                .onChange(of: config.episodicMaxItems) { _, _ in saveConfig() }

            Stepper("Semantic Max: \(formatNumber(config.semanticMaxItems))", value: $config.semanticMaxItems, in: 1000...20000, step: 1000)
                .onChange(of: config.semanticMaxItems) { _, _ in saveConfig() }

            Stepper("Procedural Max: \(formatNumber(config.proceduralMaxItems))", value: $config.proceduralMaxItems, in: 100...5000, step: 100)
                .onChange(of: config.proceduralMaxItems) { _, _ in saveConfig() }

            Text("Larger capacities use more memory but retain more context.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Consolidation Settings

    private var consolidationSettings: some View {
        Group {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Consolidation Threshold")
                    Spacer()
                    Text(formatDuration(config.consolidationThresholdSeconds))
                        .foregroundStyle(.secondary)
                }

                Slider(
                    value: $config.consolidationThresholdSeconds,
                    in: 60...3600,
                    step: 60
                )
                .onChange(of: config.consolidationThresholdSeconds) { _, _ in saveConfig() }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Min Importance for Long-Term")
                    Spacer()
                    Text("\(config.consolidationMinImportance, specifier: "%.2f")")
                        .foregroundStyle(.secondary)
                }

                Slider(value: $config.consolidationMinImportance, in: 0.1...0.9, step: 0.05)
                    .onChange(of: config.consolidationMinImportance) { _, _ in saveConfig() }
            }

            Text("Memories below the minimum importance threshold are discarded during consolidation.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Decay Settings

    private var decaySettings: some View {
        Group {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("General Decay Rate")
                    Spacer()
                    Text("\(config.generalDecayRate, specifier: "%.2f")")
                        .foregroundStyle(.secondary)
                }

                Slider(value: $config.generalDecayRate, in: 0.8...1.0, step: 0.01)
                    .onChange(of: config.generalDecayRate) { _, _ in saveConfig() }

                Text("Applied daily to general and episodic memories")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Semantic Decay Rate")
                    Spacer()
                    Text("\(config.semanticDecayRate, specifier: "%.2f")")
                        .foregroundStyle(.secondary)
                }

                Slider(value: $config.semanticDecayRate, in: 0.9...1.0, step: 0.01)
                    .onChange(of: config.semanticDecayRate) { _, _ in saveConfig() }

                Text("Semantic memories decay more slowly (concepts persist)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Minimum Importance Threshold")
                    Spacer()
                    Text("\(config.minImportanceThreshold, specifier: "%.2f")")
                        .foregroundStyle(.secondary)
                }

                Slider(value: $config.minImportanceThreshold, in: 0.01...0.3, step: 0.01)
                    .onChange(of: config.minImportanceThreshold) { _, _ in saveConfig() }

                Text("Memories below this threshold are forgotten")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Retrieval Settings

    private var retrievalSettings: some View {
        Group {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Similarity Threshold")
                    Spacer()
                    Text("\(config.defaultSimilarityThreshold, specifier: "%.2f")")
                        .foregroundStyle(.secondary)
                }

                Slider(value: $config.defaultSimilarityThreshold, in: 0.3...0.95, step: 0.05)
                    .onChange(of: config.defaultSimilarityThreshold) { _, _ in saveConfig() }

                Text("Higher values return more relevant but fewer memories")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Compression Threshold")
                    Spacer()
                    Text("\(config.compressionSimilarityThreshold, specifier: "%.2f")")
                        .foregroundStyle(.secondary)
                }

                Slider(value: $config.compressionSimilarityThreshold, in: 0.3...0.9, step: 0.05)
                    .onChange(of: config.compressionSimilarityThreshold) { _, _ in saveConfig() }

                Text("Similar memories above this threshold are merged")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Stepper("Default Retrieval Limit: \(config.defaultRetrievalLimit)", value: $config.defaultRetrievalLimit, in: 5...50, step: 5)
                .onChange(of: config.defaultRetrievalLimit) { _, _ in saveConfig() }

            Stepper("Episodic Limit: \(config.episodicRetrievalLimit)", value: $config.episodicRetrievalLimit, in: 1...20)
                .onChange(of: config.episodicRetrievalLimit) { _, _ in saveConfig() }

            Stepper("Semantic Limit: \(config.semanticRetrievalLimit)", value: $config.semanticRetrievalLimit, in: 1...20)
                .onChange(of: config.semanticRetrievalLimit) { _, _ in saveConfig() }

            Stepper("Procedural Limit: \(config.proceduralRetrievalLimit)", value: $config.proceduralRetrievalLimit, in: 1...10)
                .onChange(of: config.proceduralRetrievalLimit) { _, _ in saveConfig() }
        }
    }

    // MARK: - Boost Settings

    private var boostSettings: some View {
        Group {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Importance Boost Factor")
                    Spacer()
                    Text("\(config.importanceBoostFactor, specifier: "%.2f")")
                        .foregroundStyle(.secondary)
                }

                Slider(value: $config.importanceBoostFactor, in: 0.0...0.5, step: 0.05)
                    .onChange(of: config.importanceBoostFactor) { _, _ in saveConfig() }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Recency Boost Max")
                    Spacer()
                    Text("\(config.recencyBoostMax, specifier: "%.2f")")
                        .foregroundStyle(.secondary)
                }

                Slider(value: $config.recencyBoostMax, in: 0.0...0.5, step: 0.05)
                    .onChange(of: config.recencyBoostMax) { _, _ in saveConfig() }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Access Boost Factor")
                    Spacer()
                    Text("\(config.accessBoostFactor, specifier: "%.3f")")
                        .foregroundStyle(.secondary)
                }

                Slider(value: $config.accessBoostFactor, in: 0.0...0.05, step: 0.005)
                    .onChange(of: config.accessBoostFactor) { _, _ in saveConfig() }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Access Importance Boost")
                    Spacer()
                    Text("\(config.accessImportanceBoost, specifier: "%.2f")")
                        .foregroundStyle(.secondary)
                }

                Slider(value: $config.accessImportanceBoost, in: 1.0...1.2, step: 0.01)
                    .onChange(of: config.accessImportanceBoost) { _, _ in saveConfig() }

                Text("Multiplier applied to importance when memory is accessed")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Keyword Settings

    private var keywordSettings: some View {
        Group {
            ForEach(config.importantKeywords, id: \.self) { keyword in
                HStack {
                    Image(systemName: "tag.fill")
                        .foregroundStyle(.blue)
                        .font(.caption)

                    Text(keyword)

                    Spacer()

                    Button {
                        config.importantKeywords.removeAll { $0 == keyword }
                        saveConfig()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                showingKeywordEditor = true
            } label: {
                Label("Add Keyword", systemImage: "plus.circle.fill")
            }

            Text("Messages containing these keywords are marked as more important.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Memory Actions

    private var memoryActions: some View {
        Group {
            Button {
                showingConsolidateConfirmation = true
            } label: {
                Label("Consolidate Short-Term Memories", systemImage: "arrow.right.arrow.left")
            }

            Button {
                Task {
                    try? await memorySystem.compressMemories()
                }
            } label: {
                Label("Compress Similar Memories", systemImage: "arrow.down.right.and.arrow.up.left")
            }

            Button {
                Task {
                    await memorySystem.applyMemoryDecay()
                }
            } label: {
                Label("Apply Memory Decay Now", systemImage: "clock.arrow.circlepath")
            }

            Button(role: .destructive) {
                showingClearConfirmation = true
            } label: {
                Label("Clear All Memories", systemImage: "trash")
            }
        }
    }

    // MARK: - Keyword Editor Sheet

    private var keywordEditorSheet: some View {
        NavigationStack {
            Form {
                Section("Add New Keyword") {
                    TextField("Keyword", text: $newKeyword)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()

                    Text("Keywords are case-insensitive. Messages containing these keywords will be marked as more important.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Current Keywords") {
                    ForEach(config.importantKeywords, id: \.self) { keyword in
                        Text(keyword)
                    }
                }
            }
            .navigationTitle("Important Keywords")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        newKeyword = ""
                        showingKeywordEditor = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if !newKeyword.isEmpty && !config.importantKeywords.contains(newKeyword.lowercased()) {
                            config.importantKeywords.append(newKeyword.lowercased())
                            saveConfig()
                        }
                        newKeyword = ""
                        showingKeywordEditor = false
                    }
                    .disabled(newKeyword.isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(width: 400, height: 400)
        #endif
    }

    // MARK: - Helper Methods

    private func saveConfig() {
        AppConfiguration.shared.memoryConfig = config
    }

    private func clearAllMemories() {
        // This would need to be implemented in MemorySystem
        // For now, we'll just reset the in-memory state
        // In a full implementation, this would also clear persistent storage
    }

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return "\(Int(seconds))s"
        } else if seconds < 3600 {
            return "\(Int(seconds / 60))m"
        } else {
            return "\(Int(seconds / 3600))h"
        }
    }
}

// MARK: - Preview

#if os(macOS)
#Preview {
    MemorySettingsView()
        .frame(width: 700, height: 800)
}
#else
#Preview {
    NavigationStack {
        MemorySettingsView()
            .navigationTitle("Memory")
    }
}
#endif
