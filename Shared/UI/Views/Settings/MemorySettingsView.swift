// MemorySettingsView.swift
// Memory configuration and management for Thea

import SwiftUI

struct MemorySettingsView: View {
    @State private var config = TheaConfig.shared.memory
    @State private var stats: MemorySystemStats?
    @State private var showingClearConfirmation = false
    @State private var showingKeywordEditor = false
    @State private var newKeyword = ""

    var body: some View {
        Form {
            Section("Memory Statistics") {
                memoryStatsSection
            }

            Section("Capacity Limits") {
                capacitySettings
            }

            Section("Memory Decay") {
                decaySettings
            }

            Section("Retrieval") {
                retrievalSettings
            }

            Section("Important Keywords") {
                keywordSettings
            }

            Section("Memory Management") {
                memoryActions
            }

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
        .task {
            stats = await MemorySystem.shared.getStatistics()
        }
        .alert("Clear All Memories?", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) {
                Task {
                    await MemorySystem.shared.clearShortTermMemory()
                    stats = await MemorySystem.shared.getStatistics()
                }
            }
        } message: {
            Text("This will clear all short-term memories. This action cannot be undone.")
        }
        .sheet(isPresented: $showingKeywordEditor) {
            keywordEditorSheet
        }
    }

    // MARK: - Memory Stats Section

    private var memoryStatsSection: some View {
        Group {
            if let stats {
                LabeledContent("Short-Term Memories", value: "\(stats.shortTermCount) / \(stats.maxShortTerm)")
            } else {
                ProgressView("Loading statistics...")
            }

            Button("Refresh Statistics") {
                Task {
                    stats = await MemorySystem.shared.getStatistics()
                }
            }
        }
    }

    // MARK: - Capacity Settings

    private var capacitySettings: some View {
        Group {
            Stepper("Working Memory: \(config.workingCapacity)", value: $config.workingCapacity, in: 10...500, step: 10)
                .onChange(of: config.workingCapacity) { _, _ in saveConfig() }

            Stepper("Episodic Capacity: \(formatNumber(config.episodicCapacity))", value: $config.episodicCapacity, in: 1000...50000, step: 1000)
                .onChange(of: config.episodicCapacity) { _, _ in saveConfig() }

            Stepper("Semantic Capacity: \(formatNumber(config.semanticCapacity))", value: $config.semanticCapacity, in: 1000...100000, step: 5000)
                .onChange(of: config.semanticCapacity) { _, _ in saveConfig() }

            Stepper("Procedural Capacity: \(formatNumber(config.proceduralCapacity))", value: $config.proceduralCapacity, in: 100...5000, step: 100)
                .onChange(of: config.proceduralCapacity) { _, _ in saveConfig() }

            Text("Larger capacities use more memory but retain more context.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Decay Settings

    private var decaySettings: some View {
        Group {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Decay Rate")
                    Spacer()
                    Text("\(config.decayRate, specifier: "%.3f")")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $config.decayRate, in: 0.9...1.0, step: 0.005)
                    .onChange(of: config.decayRate) { _, _ in saveConfig() }
                Text("Applied periodically to reduce memory importance over time")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Min Importance")
                    Spacer()
                    Text("\(config.minImportance, specifier: "%.2f")")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $config.minImportance, in: 0.0...0.5, step: 0.05)
                    .onChange(of: config.minImportance) { _, _ in saveConfig() }
                Text("Memories below this threshold are forgotten")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Consolidation Interval")
                    Spacer()
                    Text(formatDuration(config.consolidationInterval))
                        .foregroundStyle(.secondary)
                }
                Slider(value: $config.consolidationInterval, in: 300...7200, step: 300)
                    .onChange(of: config.consolidationInterval) { _, _ in saveConfig() }
            }
        }
    }

    // MARK: - Retrieval Settings

    private var retrievalSettings: some View {
        Group {
            Stepper("Retrieval Limit: \(config.retrievalLimit)", value: $config.retrievalLimit, in: 1...50, step: 1)
                .onChange(of: config.retrievalLimit) { _, _ in saveConfig() }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Similarity Threshold")
                    Spacer()
                    Text("\(config.similarityThreshold, specifier: "%.2f")")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $config.similarityThreshold, in: 0.1...0.9, step: 0.05)
                    .onChange(of: config.similarityThreshold) { _, _ in saveConfig() }
                Text("Higher values return more relevant but fewer memories")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Toggle("Active Retrieval", isOn: $config.enableActiveRetrieval)
                .onChange(of: config.enableActiveRetrieval) { _, _ in saveConfig() }

            Toggle("Context Injection", isOn: $config.enableContextInjection)
                .onChange(of: config.enableContextInjection) { _, _ in saveConfig() }
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
            Button(role: .destructive) {
                showingClearConfirmation = true
            } label: {
                Label("Clear Short-Term Memories", systemImage: "trash")
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
        TheaConfig.shared.memory = config
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
