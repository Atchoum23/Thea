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

// MARK: - Resource Bar

struct ResourceBar: View {
    let label: String
    let icon: String
    let value: Double
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(color)

            Text(label)

            Spacer()

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * value, height: 6)
                }
            }
            .frame(width: 100, height: 6)

            Text("\(Int(value * 100))%")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
        }
    }
}

// MARK: - Autonomous Stat Row

private struct AutonomousStatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Consent Request View

struct ConsentRequestView: View {
    @Binding var isPresented: Bool
    @State private var governor = AIModelGovernor.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue)

                        Text("Enable Autonomous Intelligence")
                            .font(.title)
                            .fontWeight(.bold)

                        Text("Let Thea proactively optimize your AI experience")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top)

                    Divider()

                    // Features
                    VStack(alignment: .leading, spacing: 16) {
                        AutonomousFeatureRow(
                            icon: "arrow.down.circle",
                            title: "Smart Model Downloads",
                            description: "Automatically download optimal models for your tasks based on AI analysis"
                        )

                        AutonomousFeatureRow(
                            icon: "trash.circle",
                            title: "Intelligent Cleanup",
                            description: "Remove low-value models based on actual usage, not arbitrary time limits"
                        )

                        AutonomousFeatureRow(
                            icon: "gauge.high",
                            title: "Dynamic Resources",
                            description: "AI-optimized GPU, CPU, and memory allocation based on current workload"
                        )

                        AutonomousFeatureRow(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "Continuous Learning",
                            description: "Proactivity increases over time based on your feedback"
                        )
                    }
                    .padding(.horizontal)

                    Divider()

                    // Privacy Note
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Privacy & Control", systemImage: "lock.shield")
                            .font(.headline)

                        Text("• All decisions are made locally on your device\n• You can override any action\n• Revoke consent at any time in Settings\n• No data is sent externally")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                }
                .padding()
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Enable") {
                        governor.hasAutonomousConsent = true
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}

struct AutonomousFeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Proactivity Details View

struct ProactivityDetailsView: View {
    @State private var governor = AIModelGovernor.shared

    private var recentEvents: [ProactivityEvent] {
        Array(governor.proactivityHistory.suffix(20).reversed())
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Recent Actions") {
                    ForEach(Array(recentEvents.enumerated()), id: \.offset) { _, event in
                        HStack {
                            Image(systemName: event.wasHelpful ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(event.wasHelpful ? .green : .red)

                            VStack(alignment: .leading) {
                                Text(event.action)
                                    .font(.subheadline)
                                Text(event.timestamp, style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if event.userOverrode {
                                Text("Overridden")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Proactivity History")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}

// MARK: - Resource Monitor View

struct ResourceMonitorView: View {
    @State private var governor = AIModelGovernor.shared
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            List {
                Section("Current Allocation") {
                    let allocation = governor.getOptimalResourceAllocation()

                    ResourceBar(label: "GPU", icon: "gpu", value: allocation.gpuPercentage, color: .green)
                    ResourceBar(label: "CPU", icon: "cpu", value: allocation.cpuPercentage, color: .blue)
                    ResourceBar(label: "Memory", icon: "memorychip", value: allocation.memoryPercentage, color: .orange)

                    Text(allocation.reasoning)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("System State") {
                    HStack {
                        Text("Thermal State")
                        Spacer()
                        Text(governor.systemState.thermalState.rawValue.capitalized)
                            .foregroundStyle(thermalColor(governor.systemState.thermalState))
                    }

                    HStack {
                        Text("Active Inferences")
                        Spacer()
                        Text("\(governor.systemState.activeInferenceCount)")
                    }

                    HStack {
                        Text("Pending Tasks")
                        Spacer()
                        Text("\(governor.systemState.pendingTasks)")
                    }
                }
            }
            .navigationTitle("Resource Monitor")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .onReceive(timer) { _ in
                // Refresh view
            }
        }
    }

    private func thermalColor(_ state: GovernorThermalState) -> Color {
        switch state {
        case .nominal: return .green
        case .fair: return .yellow
        case .serious: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AutonomousSettingsView()
    }
}
