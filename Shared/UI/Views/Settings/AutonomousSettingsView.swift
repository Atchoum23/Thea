// AutonomousSettingsView.swift
// Thea V2
//
// Comprehensive Settings UI for all autonomous features
// AI-powered, dynamic, continuously learning
//
// CREATED: February 2, 2026

import SwiftUI

// MARK: - Autonomous Settings View

struct AutonomousSettingsView: View {
    @State private var governor = AIModelGovernor.shared
    @State private var proactiveManager = ProactiveModelManager.shared
    @State private var orchestrator = UnifiedLocalModelOrchestrator.shared

    @State private var showingConsentSheet = false
    @State private var showingProactivityDetails = false
    @State private var showingResourceMonitor = false

    var body: some View {
        Form {
            // MARK: - Consent & Master Toggle
            consentSection

            if governor.hasAutonomousConsent {
                // MARK: - Proactivity
                proactivitySection

                // MARK: - Model Management
                modelManagementSection

                // MARK: - Resource Allocation
                resourceAllocationSection

                // MARK: - Local Model Runtimes
                runtimesSection

                // MARK: - Statistics
                statisticsSection
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Autonomous Intelligence")
        .sheet(isPresented: $showingConsentSheet) {
            ConsentRequestView(isPresented: $showingConsentSheet)
        }
        .sheet(isPresented: $showingProactivityDetails) {
            ProactivityDetailsView()
        }
        .sheet(isPresented: $showingResourceMonitor) {
            ResourceMonitorView()
        }
    }

    // MARK: - Consent Section

    private var consentSection: some View {
        Section {
            if governor.hasAutonomousConsent {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .font(.title2)

                    VStack(alignment: .leading) {
                        Text("Autonomous Mode Enabled")
                            .font(.headline)
                        Text("Thea can proactively manage models and resources")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Revoke") {
                        governor.hasAutonomousConsent = false
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            } else {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundStyle(.blue)
                        .font(.title2)

                    VStack(alignment: .leading) {
                        Text("Enable Autonomous Mode")
                            .font(.headline)
                        Text("Let Thea proactively optimize your experience")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Enable") {
                        showingConsentSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        } header: {
            Text("Autonomous Intelligence")
        } footer: {
            Text("When enabled, Thea uses AI to make intelligent decisions about model downloads, cleanup, and resource allocation. All decisions are based on actual value analysis, not arbitrary thresholds.")
        }
    }

    // MARK: - Proactivity Section

    private var proactivitySection: some View {
        Section {
            let level = governor.getProactivityLevel()

            // Proactivity Level
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Proactivity Level")
                    Spacer()
                    Text(level.level.rawValue)
                        .foregroundStyle(proactivityColor(for: level.score))
                        .fontWeight(.semibold)
                }

                // Visual indicator
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(proactivityGradient)
                            .frame(width: geo.size.width * level.score, height: 8)
                    }
                }
                .frame(height: 8)

                Text(level.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)

            // Success Rate
            HStack {
                Label("Success Rate", systemImage: "chart.line.uptrend.xyaxis")
                Spacer()
                Text("\(Int(level.successRate * 100))%")
                    .foregroundStyle(level.successRate > 0.7 ? .green : .orange)
            }

            // View Details
            Button {
                showingProactivityDetails = true
            } label: {
                HStack {
                    Text("View Learning History")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Label("Proactivity", systemImage: "brain")
        } footer: {
            Text("Thea's proactivity naturally increases over time as actions prove helpful. It decreases when you override decisions.")
        }
    }

    // MARK: - Model Management Section

    private var modelManagementSection: some View {
        Section {
            // Auto Download
            Toggle(isOn: Binding(
                get: { proactiveManager.enableAutoDownload },
                set: { proactiveManager.enableAutoDownload = $0 }
            )) {
                VStack(alignment: .leading) {
                    Text("Auto-Download Models")
                    Text("Download optimal models when needed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Auto Cleanup
            Toggle(isOn: Binding(
                get: { proactiveManager.enableAutoCleanup },
                set: { proactiveManager.enableAutoCleanup = $0 }
            )) {
                VStack(alignment: .leading) {
                    Text("Auto-Cleanup Models")
                    Text("Remove low-value models when space is needed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Pending Downloads
            if !proactiveManager.pendingDownloads.isEmpty {
                DisclosureGroup {
                    ForEach(proactiveManager.pendingDownloads) { pending in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(pending.recommendation.modelName)
                                    .font(.subheadline)
                                Text("\(String(format: "%.1f", pending.recommendation.estimatedSizeGB)) GB")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button("Download") {
                                Task {
                                    await proactiveManager.startModelDownload(pending.recommendation)
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                } label: {
                    HStack {
                        Text("Pending Downloads")
                        Spacer()
                        Text("\(proactiveManager.pendingDownloads.count)")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Active Downloads
            if !proactiveManager.activeDownloads.isEmpty {
                ForEach(Array(proactiveManager.activeDownloads.values), id: \.modelId) { progress in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(progress.modelName)
                                .font(.subheadline)
                            Spacer()
                            Text("\(Int(progress.percentage * 100))%")
                                .foregroundStyle(.secondary)
                        }

                        ProgressView(value: progress.percentage)
                            .tint(.blue)
                    }
                }
            }

            // Cleanup Candidates
            if !proactiveManager.cleanupCandidates.isEmpty {
                DisclosureGroup {
                    ForEach(proactiveManager.cleanupCandidates) { candidate in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(candidate.model.name)
                                    .font(.subheadline)
                                Text("Last used: \(formatDate(candidate.lastUsed))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text("\(String(format: "%.1f", candidate.sizeGB)) GB")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Button(role: .destructive) {
                                Task {
                                    await proactiveManager.deleteModel(candidate.model)
                                }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                } label: {
                    HStack {
                        Text("Cleanup Candidates")
                        Spacer()
                        Text("\(proactiveManager.cleanupCandidates.count)")
                            .foregroundStyle(.orange)
                    }
                }
            }
        } header: {
            Label("Model Management", systemImage: "square.stack.3d.up")
        } footer: {
            Text("AI determines which models to download or remove based on actual usage patterns and value analysis—not arbitrary time limits.")
        }
    }

    // MARK: - Resource Allocation Section

    private var resourceAllocationSection: some View {
        Section {
            let allocation = governor.getOptimalResourceAllocation()

            // GPU
            ResourceBar(
                label: "GPU",
                icon: "gpu",
                value: allocation.gpuPercentage,
                color: .green
            )

            // CPU
            ResourceBar(
                label: "CPU",
                icon: "cpu",
                value: allocation.cpuPercentage,
                color: .blue
            )

            // Memory
            ResourceBar(
                label: "Memory",
                icon: "memorychip",
                value: allocation.memoryPercentage,
                color: .orange
            )

            // Reasoning
            Text(allocation.reasoning)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                showingResourceMonitor = true
            } label: {
                HStack {
                    Text("Open Resource Monitor")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Label("Live Resource Allocation", systemImage: "gauge.with.dots.needle.33percent")
        } footer: {
            Text("Resources are dynamically allocated based on current workload, thermal state, and task priority.")
        }
    }

    // MARK: - Runtimes Section

    private var runtimesSection: some View {
        Section {
            ForEach(LocalRuntime.allCases, id: \.self) { runtime in
                HStack {
                    Image(systemName: runtimeIcon(for: runtime))
                        .foregroundStyle(orchestrator.availableRuntimes.contains(runtime) ? .green : .secondary)

                    VStack(alignment: .leading) {
                        Text(runtime.displayName)
                        Text("\(runtime.expectedThroughput) tok/s expected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if orchestrator.availableRuntimes.contains(runtime) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Text("Not Available")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Preferred Runtime
            Picker("Preferred Runtime", selection: Binding(
                get: { orchestrator.preferredRuntime },
                set: { orchestrator.preferredRuntime = $0 }
            )) {
                ForEach(LocalRuntime.allCases, id: \.self) { runtime in
                    Text(runtime.displayName).tag(runtime)
                }
            }

            // Auto Fallback
            Toggle("Automatic Fallback", isOn: Binding(
                get: { orchestrator.enableAutomaticFallback },
                set: { orchestrator.enableAutomaticFallback = $0 }
            ))
        } header: {
            Label("Local Model Runtimes", systemImage: "gearshape.2")
        }
    }

    // MARK: - Statistics Section

    private var statisticsSection: some View {
        Section {
            AutonomousStatRow(label: "Models Installed", value: "\(LocalModelManager.shared.availableModels.count)")
            AutonomousStatRow(label: "Total Storage Used", value: formatBytes(totalModelStorage()))
            AutonomousStatRow(label: "Proactivity Events", value: "\(governor.proactivityHistory.count)")
            AutonomousStatRow(label: "Download Queue", value: "\(proactiveManager.downloadQueue.count)")
        } header: {
            Label("Statistics", systemImage: "chart.bar")
        }
    }

    // MARK: - Helpers

    private func proactivityColor(for score: Double) -> Color {
        if score < 0.3 { return .orange }
        if score < 0.6 { return .yellow }
        if score < 0.8 { return .green }
        return .mint
    }

    private var proactivityGradient: LinearGradient {
        LinearGradient(
            colors: [.orange, .yellow, .green, .mint],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func runtimeIcon(for runtime: LocalRuntime) -> String {
        switch runtime {
        case .mlx: return "apple.logo"
        case .ollama: return "server.rack"
        case .gguf: return "doc.zipper"
        case .coreML: return "cpu"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func totalModelStorage() -> Int64 {
        LocalModelManager.shared.availableModels.reduce(0) { $0 + $1.size }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
