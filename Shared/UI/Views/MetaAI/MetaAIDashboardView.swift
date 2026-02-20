// MetaAIDashboardView.swift
// Thea v3 — Meta-AI Intelligence Layer Dashboard
// Shows real-time data from all MetaAI intelligence subsystems
//
// Tabs: Overview · Routing · Confidence · Benchmarks · Reasoning ·
//       Agents · Workflows · Plugins · Self-Model · Self-Execution · Directives

import SwiftUI

// MARK: - Tab Definition

enum MetaAIDashboardTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case routing = "Routing"
    case confidence = "Confidence"
    case benchmarks = "Benchmarks"
    case reasoning = "Reasoning"
    case agents = "Agents"
    case workflows = "Workflows"
    case plugins = "Plugins"
    case selfModel = "Self-Model"
    case selfExecution = "Self-Execution"
    case directives = "Directives"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .overview: "brain.head.profile"
        case .routing: "arrow.triangle.branch"
        case .confidence: "checkmark.seal.fill"
        case .benchmarks: "chart.bar.xaxis"
        case .reasoning: "lightbulb.fill"
        case .agents: "person.2.circle"
        case .workflows: "flowchart.fill"
        case .plugins: "puzzlepiece.extension.fill"
        case .selfModel: "eye.fill"
        case .selfExecution: "bolt.fill"
        case .directives: "list.bullet.clipboard.fill"
        }
    }
}

// MARK: - Dashboard Root

struct MetaAIDashboardView: View {
    @State private var selectedTab: MetaAIDashboardTab = .overview

    var body: some View {
        NavigationSplitView {
            List(MetaAIDashboardTab.allCases, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
            }
            .listStyle(.sidebar)
            .navigationTitle("Meta-AI")
            .frame(minWidth: 180)
        } detail: {
            detailPanel(for: selectedTab)
                .navigationTitle(selectedTab.rawValue)
        }
        .navigationTitle("Meta-AI Dashboard")
    }

    @ViewBuilder
    private func detailPanel(for tab: MetaAIDashboardTab) -> some View {
        switch tab {
        case .overview:      MetaAIOverviewPanel()
        case .routing:       MetaAIRoutingPanel()
        case .confidence:    MetaAIConfidencePanel()
        case .benchmarks:    MetaAIBenchmarksPanel()
        case .reasoning:     MetaAIReasoningPanel()
        case .agents:        MetaAIAgentsPanel()
        case .workflows:     MetaAIWorkflowsPanel()
        case .plugins:       MetaAIPluginsPanel()
        case .selfModel:     MetaAISelfModelPanel()
        case .selfExecution: MetaAISelfExecutionPanel()
        case .directives:    MetaAIDirectivesPanel()
        }
    }
}

// MARK: - Shared Helper Views

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    var color: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.title2.bold())
                .foregroundColor(.primary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct MetaAISectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.primary)
    }
}

private struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text(title).font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 130, alignment: .leading)
            Text(value)
                .font(.caption)
                .foregroundColor(.primary)
            Spacer()
        }
    }
}

private struct ToggleStatCard: View {
    let title: String
    let icon: String
    let isOn: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(isOn ? .green : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption.bold())
                Text(isOn ? "Enabled" : "Disabled")
                    .font(.caption2)
                    .foregroundColor(isOn ? .green : .secondary)
            }
            Spacer()
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Flow Layout

struct MetaAIFlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Capability Chip

private struct CapabilityChip: View {
    let text: String
    var color: Color = .accentColor

    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .clipShape(Capsule())
    }
}

// MARK: - Overview Panel

struct MetaAIOverviewPanel: View {
    @State private var coordinator = MetaAICoordinator.shared
    @State private var intelligence = TheaIntelligenceOrchestrator.shared
    @State private var selfAwareness = THEASelfAwareness.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                MetaAISectionHeader(title:"System Status")

                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 12
                ) {
                    StatCard(
                        title: "Orchestrator",
                        value: coordinator.isProcessing ? "Processing" : "Ready",
                        icon: "brain.head.profile",
                        color: coordinator.isProcessing ? .orange : .green
                    )
                    StatCard(
                        title: "Intelligence Engine",
                        value: intelligence.isRunning ? "Running" : "Idle",
                        icon: "bolt.circle",
                        color: intelligence.isRunning ? .green : .secondary
                    )
                    StatCard(
                        title: "Total Processed",
                        value: "\(coordinator.orchestratorStats.totalProcessed)",
                        icon: "arrow.triangle.2.circlepath",
                        color: .blue
                    )
                    StatCard(
                        title: "Avg Latency",
                        value: String(format: "%.2fs", coordinator.orchestratorStats.averageLatency),
                        icon: "clock",
                        color: .purple
                    )
                    StatCard(
                        title: "Satisfaction",
                        value: String(format: "%.0f%%", coordinator.orchestratorStats.satisfactionRate * 100),
                        icon: "hand.thumbsup.fill",
                        color: .green
                    )
                    StatCard(
                        title: "System Status",
                        value: intelligence.systemStatus.rawValue.capitalized,
                        icon: "circle.fill",
                        color: intelligence.systemStatus == .active ? .green : .orange
                    )
                }

                Divider()

                MetaAISectionHeader(title:"Latest Decision")
                if let decision = coordinator.currentDecision {
                    DecisionSummaryCard(decision: decision)
                } else {
                    Text("No decision in progress — send a message to see orchestrator activity")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Divider()

                MetaAISectionHeader(title:"Identity")
                let identity = selfAwareness.identity
                VStack(alignment: .leading, spacing: 4) {
                    Text(identity.fullName)
                        .font(.headline)
                    Text("v\(identity.version) · build \(identity.buildNumber) · \(identity.architecture)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(20)
        }
    }
}

private struct DecisionSummaryCard: View {
    let decision: THEADecision

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(decision.reasoning.taskTypeDescription)
                    .font(.headline)
                Spacer()
                Text(String(format: "%.0f%% confidence", decision.confidenceScore * 100))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            HStack(spacing: 8) {
                Label(decision.selectedModel, systemImage: "cpu")
                    .font(.caption)
                Text("via \(decision.selectedProvider)")
                    .font(.caption)
                    .foregroundColor(.blue)
                Spacer()
                Text(decision.strategy.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.2))
                    .clipShape(Capsule())
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Routing Panel

struct MetaAIRoutingPanel: View {
    @State private var router = SmartModelRouter.shared
    @State private var selectedModelId: String?

    private var selectedModel: RouterModelCapability? {
        router.availableModels.first { $0.modelId == selectedModelId }
    }

    var body: some View {
        HSplitView {
            // Model list
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Models (\(router.availableModels.count))")
                        .font(.caption).foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                Divider()

                if router.availableModels.isEmpty {
                    EmptyStateView(
                        icon: "arrow.triangle.branch",
                        title: "No Models Registered",
                        subtitle: "Models register automatically when providers are configured"
                    )
                } else {
                    List(router.availableModels, id: \.modelId, selection: $selectedModelId) { model in
                        ModelRowView(model: model, usage: router.usageByModel[model.modelId])
                            .tag(model.modelId)
                    }
                    .listStyle(.plain)
                }
            }
            .frame(minWidth: 240, maxWidth: 320)

            // Detail pane
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let model = selectedModel {
                        ModelDetailView(model: model, usage: router.usageByModel[model.modelId])
                    } else {
                        BudgetSummaryView(router: router)
                    }
                }
                .padding(16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct ModelRowView: View {
    let model: RouterModelCapability
    let usage: ModelUsage?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(model.modelId)
                    .font(.caption.bold()).lineLimit(1)
                Spacer()
                if model.isLocalModel {
                    Image(systemName: "internaldrive")
                        .foregroundColor(.green).font(.caption2)
                }
            }
            HStack {
                Text(model.provider).font(.caption2).foregroundColor(.secondary)
                Spacer()
                Text(String(format: "Q:%.0f%%", model.qualityScore * 100))
                    .font(.caption2).foregroundColor(.blue)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct ModelDetailView: View {
    let model: RouterModelCapability
    let usage: ModelUsage?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.modelId).font(.title3.bold())
            Text(model.provider).foregroundColor(.secondary)

            Divider()

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                StatCard(title: "Context", value: "\(model.contextWindow / 1000)K", icon: "doc.text")
                StatCard(
                    title: "Quality",
                    value: String(format: "%.0f%%", model.qualityScore * 100),
                    icon: "star.fill", color: .yellow
                )
                StatCard(
                    title: "Avg Latency",
                    value: String(format: "%.1fs", model.averageLatency),
                    icon: "clock"
                )
                StatCard(
                    title: "Input Cost",
                    value: String(format: "$%.3f/1M", model.costPerInputToken),
                    icon: "dollarsign.circle"
                )
            }

            if let usage {
                Divider()
                Text("Usage Statistics").font(.headline)
                InfoRow(label: "Requests", value: "\(usage.requestCount)")
                InfoRow(label: "Success Rate", value: String(format: "%.0f%%", usage.successRate * 100))
                InfoRow(label: "Avg Latency", value: String(format: "%.2fs", usage.averageLatency))
                InfoRow(label: "Total Cost", value: String(format: "$%.4f", usage.totalCost))
                InfoRow(label: "Input Tokens", value: "\(usage.totalInputTokens)")
                InfoRow(label: "Output Tokens", value: "\(usage.totalOutputTokens)")
            }

            Divider()
            Text("Capabilities").font(.headline)
            MetaAIFlowLayout(spacing: 4) {
                ForEach(Array(model.capabilities), id: \.rawValue) { cap in
                    CapabilityChip(text: cap.rawValue)
                }
            }
        }
    }
}

private struct BudgetSummaryView: View {
    let router: SmartModelRouter

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Budget").font(.title3.bold())
            let pct = router.dailyBudget > 0 ? router.dailySpent / router.dailyBudget : 0
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: min(pct, 1.0))
                    .tint(pct > 0.85 ? .red : pct > 0.6 ? .orange : .green)
                HStack {
                    Text(String(format: "$%.4f spent", router.dailySpent)).font(.caption)
                    Spacer()
                    Text(String(format: "/ $%.2f limit", router.dailyBudget))
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            InfoRow(label: "Default Strategy", value: router.defaultStrategy.rawValue)
            Spacer()
            EmptyStateView(
                icon: "arrow.triangle.branch",
                title: "Select a Model",
                subtitle: "Pick a model from the list to view details and usage stats"
            )
        }
    }
}

// MARK: - Confidence Panel

struct MetaAIConfidencePanel: View {
    @State private var system = ConfidenceSystem.shared

    private let sortedSources: [ConfidenceSource.SourceType] = {
        ConfidenceSource.SourceType.allCases.sorted { $0.rawValue < $1.rawValue }
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                MetaAISectionHeader(title:"Verification Sources")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ToggleStatCard(
                        title: "Multi-Model Consensus",
                        icon: "square.stack.3d.up",
                        isOn: system.enableMultiModel
                    )
                    ToggleStatCard(
                        title: "Web Verification",
                        icon: "globe",
                        isOn: system.enableWebVerification
                    )
                    ToggleStatCard(
                        title: "Code Execution",
                        icon: "chevron.left.forwardslash.chevron.right",
                        isOn: system.enableCodeExecution
                    )
                    ToggleStatCard(
                        title: "Static Analysis",
                        icon: "magnifyingglass",
                        isOn: system.enableStaticAnalysis
                    )
                    ToggleStatCard(
                        title: "Feedback Learning",
                        icon: "brain",
                        isOn: system.enableFeedbackLearning
                    )
                }

                Divider()

                MetaAISectionHeader(title:"Source Weights")
                ForEach(sortedSources, id: \.rawValue) { source in
                    let weight = system.sourceWeights[source] ?? 0
                    HStack {
                        Text(source.rawValue)
                            .font(.caption)
                            .frame(width: 180, alignment: .leading)
                        ProgressView(value: weight)
                            .frame(maxWidth: .infinity)
                        Text(String(format: "%.0f%%", weight * 100))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 36, alignment: .trailing)
                    }
                }

                Divider()

                MetaAISectionHeader(title:"Confidence Levels")
                ForEach(ConfidenceLevel.allCases, id: \.rawValue) { level in
                    HStack {
                        Image(systemName: level.icon)
                            .foregroundColor(levelColor(level))
                        Text(level.rawValue).font(.caption)
                        Spacer()
                        Text(levelRange(level))
                            .font(.caption).foregroundColor(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(20)
        }
    }

    private func levelColor(_ level: ConfidenceLevel) -> Color {
        switch level.color {
        case "green": .green
        case "orange": .orange
        case "red": .red
        default: .gray
        }
    }

    private func levelRange(_ level: ConfidenceLevel) -> String {
        switch level {
        case .high: "85–100%"
        case .medium: "60–84%"
        case .low: "30–59%"
        case .unverified: "0–29%"
        }
    }
}

// MARK: - Benchmarks Panel

struct MetaAIBenchmarksPanel: View {
    @State private var service = ModelBenchmarkService.shared
    @State private var sortOrder: BenchmarkSort = .qualityDesc

    enum BenchmarkSort: String, CaseIterable {
        case qualityDesc = "Quality ↓"
        case speedDesc = "Speed ↓"
        case costAsc = "Cost ↑"
        case nameAsc = "Name ↑"
    }

    private var sorted: [ModelBenchmark] {
        let all = Array(service.benchmarks.values)
        switch sortOrder {
        case .qualityDesc: return all.sorted { $0.qualityScore > $1.qualityScore }
        case .speedDesc:   return all.sorted { $0.speedScore > $1.speedScore }
        case .costAsc:     return all.sorted { $0.estimatedCostPer1K < $1.estimatedCostPer1K }
        case .nameAsc:     return all.sorted { $0.modelID < $1.modelID }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Group {
                    if service.isUpdating {
                        ProgressView().scaleEffect(0.8)
                        Text("Updating…").font(.caption).foregroundColor(.secondary)
                    } else if let date = service.lastUpdateDate {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green).font(.caption)
                        Text("Updated \(date, style: .relative) ago").font(.caption).foregroundColor(.secondary)
                    } else {
                        Text("Benchmarks not loaded").font(.caption).foregroundColor(.secondary)
                    }
                }
                Spacer()
                Picker("Sort", selection: $sortOrder) {
                    ForEach(BenchmarkSort.allCases, id: \.self) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.menu).frame(width: 140)
                Button("Refresh") { Task { await service.updateBenchmarks() } }
                    .buttonStyle(.bordered).controlSize(.small)
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            if sorted.isEmpty {
                EmptyStateView(
                    icon: "chart.bar.xaxis",
                    title: "No Benchmarks",
                    subtitle: "Click Refresh to fetch the latest model benchmark data"
                )
            } else {
                List(sorted) { benchmark in
                    BenchmarkRowView(benchmark: benchmark)
                }
                .listStyle(.plain)
            }
        }
    }
}

private struct BenchmarkRowView: View {
    let benchmark: ModelBenchmark

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(benchmark.modelID).font(.caption.bold())
                    Text(benchmark.provider).font(.caption2).foregroundColor(.secondary)
                }
                Spacer()
                if benchmark.isLocal {
                    Label("Local", systemImage: "internaldrive")
                        .font(.caption2).foregroundColor(.green)
                } else {
                    Text(String(format: "$%.3f/1K", benchmark.estimatedCostPer1K))
                        .font(.caption2).foregroundColor(.secondary)
                }
            }

            HStack(spacing: 12) {
                MiniBar(label: "Quality", value: benchmark.qualityScore, color: .blue)
                MiniBar(label: "Speed", value: benchmark.speedScore, color: .green)
                Text("\(benchmark.contextLength / 1000)K ctx")
                    .font(.caption2).foregroundColor(.secondary)
            }

            if !benchmark.capabilities.isEmpty {
                MetaAIFlowLayout(spacing: 4) {
                    ForEach(Array(benchmark.capabilities), id: \.rawValue) { cap in
                        CapabilityChip(text: cap.rawValue)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct MiniBar: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(label).font(.caption2).foregroundColor(.secondary).frame(width: 42, alignment: .trailing)
            ProgressView(value: value).frame(width: 60).tint(color)
            Text(String(format: "%.0f%%", value * 100)).font(.caption2).foregroundColor(color).frame(width: 28, alignment: .leading)
        }
    }
}

// MARK: - Reasoning Panel

struct MetaAIReasoningPanel: View {
    @State private var coordinator = MetaAICoordinator.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Live Reasoning Trace").font(.headline)
                Spacer()
                if coordinator.isProcessing {
                    ProgressView().scaleEffect(0.8)
                    Text("Reasoning in progress…").font(.caption).foregroundColor(.orange)
                } else {
                    Text("Awaiting next request").font(.caption).foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            if let decision = coordinator.currentDecision {
                List {
                    Section("Current Decision") {
                        ReasoningTraceView(decision: decision)
                    }
                }
                .listStyle(.inset)
            } else {
                EmptyStateView(
                    icon: "lightbulb",
                    title: "No Active Reasoning",
                    subtitle: "Send a message to see the full reasoning trace appear here"
                )
            }
        }
    }
}

private struct ReasoningTraceView: View {
    let decision: THEADecision
    @State private var expanded = true

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 10) {
                InfoRow(label: "Task Type", value: decision.reasoning.taskTypeDescription)
                InfoRow(label: "Classification", value: decision.reasoning.classificationMethod.rawValue)
                InfoRow(label: "Task Confidence", value: String(format: "%.0f%%", decision.reasoning.taskConfidence * 100))
                InfoRow(label: "Model", value: decision.selectedModel)
                InfoRow(label: "Provider", value: decision.selectedProvider)
                InfoRow(label: "Strategy", value: decision.strategy.rawValue)
                InfoRow(label: "Overall Confidence", value: String(format: "%.0f%%", decision.confidenceScore * 100))

                Divider()

                Group {
                    Text("Why this model?").font(.caption.bold())
                    Text(decision.reasoning.whyThisModel).font(.caption).foregroundColor(.secondary)
                    Text("Why this strategy?").font(.caption.bold())
                    Text(decision.reasoning.whyThisStrategy).font(.caption).foregroundColor(.secondary)
                }

                if !decision.reasoning.alternativesConsidered.isEmpty {
                    Divider()
                    Text("Alternatives Considered").font(.caption.bold())
                    ForEach(decision.reasoning.alternativesConsidered, id: \.model) { alt in
                        HStack(alignment: .top, spacing: 4) {
                            Text("•")
                            VStack(alignment: .leading) {
                                Text(alt.model).font(.caption.bold())
                                Text(alt.reason).font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                }

                if !decision.contextFactors.isEmpty {
                    Divider()
                    Text("Context Factors").font(.caption.bold())
                    ForEach(decision.contextFactors) { factor in
                        HStack {
                            Circle()
                                .fill(influenceColor(factor.influence))
                                .frame(width: 6, height: 6)
                            Text(factor.name).font(.caption.bold())
                            Text("= \(factor.value)").font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(.leading, 4)
        } label: {
            HStack {
                Image(systemName: "lightbulb.fill").foregroundColor(.yellow)
                Text("Decision — \(decision.timestamp, style: .time)").font(.caption.bold())
                Spacer()
                Text(decision.reasoning.taskType.rawValue).font(.caption2).foregroundColor(.secondary)
            }
        }
    }

    private func influenceColor(_ inf: ContextFactor.InfluenceLevel) -> Color {
        switch inf {
        case .critical: .red
        case .high: .orange
        case .medium: .yellow
        case .low: .green
        }
    }
}

// MARK: - Agents Panel

struct MetaAIAgentsPanel: View {
    @State private var orchestrator = MultiAgentOrchestrator.shared

    var body: some View {
        HSplitView {
            // Agent list
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Agents (\(orchestrator.agents.count))")
                        .font(.caption).foregroundColor(.secondary)
                    Spacer()
                    if orchestrator.isOrchestrating {
                        ProgressView().scaleEffect(0.7)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                Divider()

                List(orchestrator.agents, id: \.id) { agent in
                    AgentSnapshotRow(agentName: agent.name, agentType: agent.type.rawValue)
                }
                .listStyle(.plain)
            }
            .frame(minWidth: 200, maxWidth: 280)

            // Stats pane
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        StatCard(
                            title: "Running Tasks",
                            value: "\(orchestrator.runningTasks.count)",
                            icon: "bolt.fill", color: .orange
                        )
                        StatCard(
                            title: "Pending Tasks",
                            value: "\(orchestrator.pendingTasks.count)",
                            icon: "clock.arrow.circlepath", color: .blue
                        )
                        StatCard(
                            title: "Completed",
                            value: "\(orchestrator.completedResults.count)",
                            icon: "checkmark.circle.fill", color: .green
                        )
                        StatCard(
                            title: "Conflicts",
                            value: "\(orchestrator.activeConflicts.count)",
                            icon: "exclamationmark.triangle.fill",
                            color: orchestrator.activeConflicts.isEmpty ? .secondary : .red
                        )
                    }

                    if !orchestrator.activeConflicts.isEmpty {
                        Divider()
                        Text("Active Conflicts").font(.headline)
                        ForEach(orchestrator.activeConflicts) { conflict in
                            ConflictRowView(conflict: conflict)
                        }
                    }

                    if !orchestrator.completedResults.isEmpty {
                        Divider()
                        Text("Recent Results (last 5)").font(.headline)
                        ForEach(Array(orchestrator.completedResults.suffix(5)), id: \.taskId) { result in
                            ResultRowView(result: result)
                        }
                    }
                }
                .padding(16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// A simple row that doesn't need to await any async agent state
private struct AgentSnapshotRow: View {
    let agentName: String
    let agentType: String

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(Color.green).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(agentName).font(.caption.bold())
                Text(agentType).font(.caption2).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

private struct ConflictRowView: View {
    let conflict: AgentConflict

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red).font(.caption)
            Text(conflict.type.rawValue).font(.caption.bold())
            Spacer()
            Text(conflict.severity == .critical ? "Critical" : conflict.severity == .high ? "High" : "Medium")
                .font(.caption2).foregroundColor(.secondary)
        }
        .padding(8)
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

private struct ResultRowView: View {
    let result: MultiAgentResult

    var body: some View {
        HStack {
            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(result.success ? .green : .red).font(.caption)
            Text(result.output.prefix(60))
                .font(.caption).lineLimit(1)
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Workflows Panel

struct MetaAIWorkflowsPanel: View {
    @State private var builder = WorkflowBuilder.shared
    @State private var selectedId: UUID?

    private var selected: Workflow? { builder.workflows.first { $0.id == selectedId } }

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Workflows (\(builder.workflows.count))")
                        .font(.caption).foregroundColor(.secondary)
                    Spacer()
                    if !builder.activeExecutions.isEmpty {
                        Text("Active: \(builder.activeExecutions.count)")
                            .font(.caption2).foregroundColor(.orange)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                Divider()

                if builder.workflows.isEmpty {
                    EmptyStateView(
                        icon: "flowchart",
                        title: "No Workflows",
                        subtitle: "Create workflows in the Workflow Builder"
                    )
                } else {
                    List(builder.workflows, id: \.id, selection: $selectedId) { wf in
                        MetaAIDashWorkflowRow(workflow: wf).tag(wf.id)
                    }
                    .listStyle(.plain)
                }
            }
            .frame(minWidth: 220, maxWidth: 300)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let wf = selected {
                        MetaAIDashWorkflowDetail(workflow: wf)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Active Executions").font(.headline)
                            if builder.activeExecutions.isEmpty {
                                Text("No workflows running").font(.caption).foregroundColor(.secondary)
                            } else {
                                ForEach(builder.activeExecutions, id: \.id) { exec in
                                    WorkflowExecutionRowView(execution: exec)
                                }
                            }
                        }
                    }
                    Spacer()
                }
                .padding(16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct MetaAIDashWorkflowRow: View {
    let workflow: Workflow
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(workflow.name).font(.caption.bold())
                Text(workflow.description.isEmpty ? "\(workflow.nodes.count) nodes" : workflow.description)
                    .font(.caption2).foregroundColor(.secondary).lineLimit(1)
            }
            Spacer()
            if workflow.isActive {
                Circle().fill(Color.green).frame(width: 6, height: 6)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct MetaAIDashWorkflowDetail: View {
    let workflow: Workflow
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(workflow.name).font(.title3.bold())
            if !workflow.description.isEmpty {
                Text(workflow.description).font(.caption).foregroundColor(.secondary)
            }
            Divider()
            HStack {
                StatCard(title: "Nodes", value: "\(workflow.nodes.count)", icon: "circle.grid.cross")
                StatCard(title: "Edges", value: "\(workflow.edges.count)", icon: "arrow.right")
            }
            InfoRow(label: "Active", value: workflow.isActive ? "Yes" : "No")
            InfoRow(label: "Created", value: workflow.createdAt.formatted(date: .abbreviated, time: .omitted))
            InfoRow(label: "Modified", value: workflow.modifiedAt.formatted(date: .abbreviated, time: .shortened))
        }
    }
}

private struct WorkflowExecutionRowView: View {
    let execution: WorkflowExecution
    var body: some View {
        HStack {
            Image(systemName: "bolt.fill").foregroundColor(.orange).font(.caption)
            Text(execution.workflowId.uuidString.prefix(8))
                .font(.caption.monospaced())
            Spacer()
            switch execution.status {
            case .running:    Text("Running").font(.caption2).foregroundColor(.orange)
            case .completed:  Text("Done").font(.caption2).foregroundColor(.green)
            case .failed:     Text("Failed").font(.caption2).foregroundColor(.red)
            }
            Text(execution.startTime, style: .time).font(.caption2).foregroundColor(.secondary)
        }
        .padding(8)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Plugins Panel

struct MetaAIPluginsPanel: View {
    @State private var system = PluginSystem.shared
    @State private var selectedId: UUID?

    private var selected: Plugin? { system.installedPlugins.first { $0.id == selectedId } }

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Installed (\(system.installedPlugins.count))")
                        .font(.caption).foregroundColor(.secondary)
                    Spacer()
                    Text("Active: \(system.activePlugins.count)")
                        .font(.caption2)
                        .foregroundColor(system.activePlugins.isEmpty ? .secondary : .green)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                Divider()

                if system.installedPlugins.isEmpty {
                    EmptyStateView(
                        icon: "puzzlepiece.extension",
                        title: "No Plugins Installed",
                        subtitle: "Install plugins to extend Thea's capabilities"
                    )
                } else {
                    List(system.installedPlugins, id: \.id) { plugin in
                        MetaAIDashPluginRow(
                            plugin: plugin,
                            isActive: system.activePlugins.contains { $0.id == plugin.id }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { selectedId = plugin.id }
                    }
                    .listStyle(.plain)
                }
            }
            .frame(minWidth: 220, maxWidth: 300)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let plugin = selected {
                        PluginDetailView(
                            plugin: plugin,
                            isActive: system.activePlugins.contains { $0.id == plugin.id },
                            executions: system.pluginExecutions.filter { $0.pluginId == plugin.id }
                        )
                    } else {
                        EmptyStateView(
                            icon: "puzzlepiece.extension",
                            title: "Select a Plugin",
                            subtitle: "Choose a plugin from the list to view details"
                        )
                    }
                    Spacer()
                }
                .padding(16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct MetaAIDashPluginRow: View {
    let plugin: Plugin
    let isActive: Bool
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(plugin.manifest.name).font(.caption.bold())
                Text(plugin.manifest.type.rawValue).font(.caption2).foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: isActive ? "circle.fill" : "circle")
                .foregroundColor(isActive ? .green : .secondary).font(.caption2)
        }
        .padding(.vertical, 2)
    }
}

private struct PluginDetailView: View {
    let plugin: Plugin
    let isActive: Bool
    let executions: [PluginExecution]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading) {
                    Text(plugin.manifest.name).font(.title3.bold())
                    Text("v\(plugin.manifest.version) by \(plugin.manifest.author)")
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Label(isActive ? "Active" : "Inactive", systemImage: isActive ? "circle.fill" : "circle")
                    .font(.caption).foregroundColor(isActive ? .green : .secondary)
            }
            Text(plugin.manifest.description).font(.caption).foregroundColor(.secondary)
            Divider()
            InfoRow(label: "Type", value: plugin.manifest.type.rawValue)
            InfoRow(label: "Installed", value: plugin.installedAt.formatted(date: .abbreviated, time: .omitted))
            if let last = plugin.lastExecuted {
                InfoRow(label: "Last Run", value: last.formatted(date: .abbreviated, time: .shortened))
            }
            if !plugin.grantedPermissions.isEmpty {
                Divider()
                Text("Permissions").font(.caption.bold())
                MetaAIFlowLayout(spacing: 4) {
                    ForEach(plugin.grantedPermissions, id: \.rawValue) { perm in
                        CapabilityChip(text: perm.rawValue, color: .orange)
                    }
                }
            }
            if !executions.isEmpty {
                Divider()
                Text("Recent Executions (\(executions.count))").font(.caption.bold())
                ForEach(executions.suffix(5), id: \.id) { exec in
                    HStack {
                        Image(systemName: exec.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(exec.success ? .green : .red).font(.caption)
                        Text(exec.startTime, style: .time).font(.caption)
                        Spacer()
                        let dur = exec.endTime.timeIntervalSince(exec.startTime)
                        Text(String(format: "%.2fs", dur)).font(.caption2).foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Self-Model Panel

struct MetaAISelfModelPanel: View {
    @State private var awareness = THEASelfAwareness.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                MetaAISectionHeader(title:"Identity")
                let identity = awareness.identity
                VStack(alignment: .leading, spacing: 6) {
                    InfoRow(label: "Name", value: identity.name)
                    InfoRow(label: "Full Name", value: identity.fullName)
                    InfoRow(label: "Version", value: identity.version)
                    InfoRow(label: "Build", value: identity.buildNumber)
                    InfoRow(label: "Architecture", value: identity.architecture)
                }
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Divider()

                MetaAISectionHeader(title:"System Context")
                let ctx = awareness.systemContext
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 10
                ) {
                    StatCard(title: "Platform", value: ctx.platform, icon: "display")
                    StatCard(title: "Device", value: ctx.deviceModel, icon: "desktopcomputer")
                    StatCard(title: "Device Name", value: ctx.deviceName, icon: "tag")
                    StatCard(
                        title: "Memory",
                        value: String(format: "%.1f GB", ctx.totalMemoryGB),
                        icon: "memorychip"
                    )
                    StatCard(
                        title: "Free Storage",
                        value: String(format: "%.0f GB", ctx.availableStorageGB),
                        icon: "internaldrive"
                    )
                    StatCard(
                        title: "Neural Engine",
                        value: ctx.hasNeuralEngine ? "Present" : "N/A",
                        icon: "cpu",
                        color: ctx.hasNeuralEngine ? .green : .secondary
                    )
                }
                InfoRow(label: "OS Version", value: ctx.osVersion)
                InfoRow(label: "Time Zone", value: ctx.timeZone)
                InfoRow(label: "Locale", value: ctx.locale)

                Divider()

                MetaAISectionHeader(title:"Self-Reported Capabilities")
                MetaAIFlowLayout(spacing: 6) {
                    ForEach(identity.capabilities, id: \.self) { cap in
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark").font(.caption2).foregroundColor(.green)
                            Text(cap).font(.caption)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }

                Divider()

                MetaAISectionHeader(title:"Personality Statement")
                Text(identity.personality)
                    .font(.caption).foregroundColor(.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(20)
        }
    }
}

// MARK: - Self-Execution Panel

struct MetaAISelfExecutionPanel: View {
    #if os(macOS)
    @State private var phaseNumber: Int = 1
    @State private var mode: SelfExecutionService.ExecutionMode = .supervised
    @State private var isExecuting = false
    @State private var lastSummary: SelfExecutionService.ExecutionSummary?
    @State private var errorMessage: String?
    @State private var isCheckingReadiness = false
    @State private var readinessResult: (ready: Bool, missingRequirements: [String])?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                MetaAISectionHeader(title:"Self-Execution Service")
                Text("Enables Thea to autonomously execute phases from THEA_MASTER_SPEC.md. All operations require appropriate approvals.")
                    .font(.caption).foregroundColor(.secondary)

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Phase Number").font(.caption.bold()).frame(width: 130, alignment: .leading)
                        Stepper("Phase \(phaseNumber)", value: $phaseNumber, in: 1...20)
                    }
                    HStack {
                        Text("Execution Mode").font(.caption.bold()).frame(width: 130, alignment: .leading)
                        Picker("Mode", selection: $mode) {
                            Text("Supervised").tag(SelfExecutionService.ExecutionMode.supervised)
                            Text("Automatic").tag(SelfExecutionService.ExecutionMode.automatic)
                            Text("Dry Run").tag(SelfExecutionService.ExecutionMode.dryRun)
                        }
                        .pickerStyle(.segmented)
                    }
                    HStack(spacing: 10) {
                        Button(isExecuting ? "Executing…" : "Execute Phase \(phaseNumber)") {
                            runPhase()
                        }
                        .disabled(isExecuting)
                        .buttonStyle(.borderedProminent)

                        Button(isCheckingReadiness ? "Checking…" : "Check Readiness") {
                            runReadinessCheck()
                        }
                        .disabled(isCheckingReadiness)
                        .buttonStyle(.bordered)
                    }
                    if isExecuting {
                        ProgressView("Executing Phase \(phaseNumber) — \(mode.rawValue) mode…")
                    }
                }
                .padding(14)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                if let readiness = readinessResult {
                    Divider()
                    MetaAISectionHeader(title:"Readiness Check")
                    HStack {
                        Image(systemName: readiness.ready ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(readiness.ready ? .green : .orange)
                        Text(readiness.ready ? "Ready to execute" : "Requirements not met")
                            .font(.caption.bold())
                    }
                    ForEach(readiness.missingRequirements, id: \.self) { req in
                        HStack {
                            Image(systemName: "xmark.circle").foregroundColor(.red).font(.caption)
                            Text(req).font(.caption)
                        }
                    }
                }

                if let err = errorMessage {
                    Divider()
                    HStack(alignment: .top) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
                        Text(err).font(.caption).foregroundColor(.red)
                    }
                    .padding(10)
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                if let summary = lastSummary {
                    Divider()
                    MetaAISectionHeader(title:"Last Execution Summary")
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        StatCard(title: "Files Created", value: "\(summary.totalFilesCreated)", icon: "doc.badge.plus", color: .green)
                        StatCard(title: "Errors Fixed", value: "\(summary.totalErrorsFixed)", icon: "wrench.fill", color: .orange)
                        StatCard(title: "Duration", value: String(format: "%.1fs", summary.totalDuration), icon: "clock")
                    }
                    if !summary.errors.isEmpty {
                        Text("Errors").font(.caption.bold())
                        ForEach(summary.errors, id: \.self) { errMsg in
                            Text("• \(errMsg)").font(.caption).foregroundColor(.red)
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    private func runPhase() {
        isExecuting = true
        errorMessage = nil
        Task {
            do {
                let summary = try await SelfExecutionService.shared.executePhases(
                    from: phaseNumber, to: phaseNumber, mode: mode
                )
                await MainActor.run { lastSummary = summary; isExecuting = false }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription; isExecuting = false }
            }
        }
    }

    private func runReadinessCheck() {
        isCheckingReadiness = true
        Task {
            let result = await SelfExecutionService.shared.checkReadiness()
            await MainActor.run { readinessResult = result; isCheckingReadiness = false }
        }
    }
    #else
    var body: some View {
        EmptyStateView(
            icon: "bolt.slash",
            title: "macOS Only",
            subtitle: "Self-Execution is only available on macOS"
        )
    }
    #endif
}

// MARK: - Directives Panel

struct MetaAIDirectivesPanel: View {
    @State private var config = UserDirectivesConfiguration.shared
    @State private var filterCategory: DirectiveCategory?
    @State private var showingAdd = false
    @State private var newText: String = ""
    @State private var newCategory: DirectiveCategory = .behavior

    private var filtered: [UserDirective] {
        guard let cat = filterCategory else { return config.directives }
        return config.directives.filter { $0.category == cat }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("Category", selection: $filterCategory) {
                    Text("All").tag(Optional<DirectiveCategory>.none)
                    ForEach(DirectiveCategory.allCases, id: \.self) { cat in
                        Label(cat.rawValue, systemImage: cat.icon).tag(Optional(cat))
                    }
                }
                .pickerStyle(.menu).frame(width: 180)
                Spacer()
                Text("\(filtered.filter(\.isEnabled).count)/\(filtered.count) active")
                    .font(.caption).foregroundColor(.secondary)
                Button { showingAdd = true } label: { Label("Add", systemImage: "plus") }
                    .buttonStyle(.bordered).controlSize(.small)
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            if filtered.isEmpty {
                EmptyStateView(
                    icon: "list.bullet.clipboard",
                    title: "No Directives",
                    subtitle: "Add behavioral directives to guide Thea's responses"
                )
            } else {
                List {
                    ForEach(DirectiveCategory.allCases, id: \.self) { cat in
                        let inCat = filtered.filter { $0.category == cat }
                        if !inCat.isEmpty {
                            Section {
                                ForEach(inCat) { directive in
                                    DirectiveRowView(
                                        directive: directive,
                                        onToggle: { config.toggleDirective(id: directive.id) },
                                        onDelete: { config.deleteDirective(id: directive.id) }
                                    )
                                }
                            } header: {
                                Label(cat.rawValue, systemImage: cat.icon).font(.caption.bold())
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddDirectiveSheet(text: $newText, category: $newCategory) {
                let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                config.addDirective(UserDirective(directive: trimmed, isEnabled: true, category: newCategory))
                newText = ""
                showingAdd = false
            } onCancel: {
                showingAdd = false
            }
        }
    }
}

private struct DirectiveRowView: View {
    let directive: UserDirective
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Toggle("", isOn: Binding(get: { directive.isEnabled }, set: { _ in onToggle() }))
                .labelsHidden().frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(directive.directive)
                    .font(.caption)
                    .foregroundColor(directive.isEnabled ? .primary : .secondary)
                Text("Modified \(directive.lastModified, style: .relative) ago")
                    .font(.caption2).foregroundColor(.secondary)
            }

            Spacer()

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash").font(.caption)
            }
            .buttonStyle(.plain).foregroundColor(.red)
        }
        .padding(.vertical, 2)
    }
}

private struct AddDirectiveSheet: View {
    @Binding var text: String
    @Binding var category: DirectiveCategory
    let onAdd: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Directive").font(.headline)
            TextEditor(text: $text)
                .frame(height: 100)
                .border(Color(nsColor: .separatorColor))
            Picker("Category", selection: $category) {
                ForEach(DirectiveCategory.allCases, id: \.self) { cat in
                    Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                }
            }
            .pickerStyle(.menu)
            HStack {
                Button("Cancel", action: onCancel).buttonStyle(.bordered)
                Spacer()
                Button("Add Directive", action: onAdd)
                    .buttonStyle(.borderedProminent)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 400)
    }
}
