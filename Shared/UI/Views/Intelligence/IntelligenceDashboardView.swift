// IntelligenceDashboardView.swift
// Thea
//
// Real-time dashboard showing live decisions from all major AI subsystems.
// Displays Model Router, Confidence, Agent Teams, Memory, Skills, and Tool Use.

import SwiftUI

// MARK: - Intelligence Dashboard View

/// Dashboard showing real-time decisions from all major AI subsystems.
struct IntelligenceDashboardView: View {

    // Observed singletons
    @ObservedObject private var modelRouter = ModelRouter.shared
    @ObservedObject private var smartRouter = SmartModelRouter.shared
    @ObservedObject private var classifier = TaskClassifier.shared
    @ObservedObject private var agentOrchestrator = AgentTeamOrchestrator.shared
    @ObservedObject private var skillsRegistry = SkillsRegistryService.shared

    // Refresh timer for non-observable singletons (PKG, ConfidenceSystem)
    @State private var refreshToken = UUID()
    @State private var timer: Timer?

    private let columns = [GridItem(.adaptive(minimum: 280), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                    modelRouterCard
                    confidenceCard
                    agentTeamCard
                    memoryCard
                    skillsCard
                    toolUseCard
                    classifierCard
                    smartRouterBudgetCard
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("AI Intelligence Dashboard")
        .onAppear { startRefreshTimer() }
        .onDisappear { stopRefreshTimer() }
        .id(refreshToken)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("AI Intelligence Dashboard")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Live decisions from all active AI subsystems")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                refreshToken = UUID()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .help("Refresh dashboard")
        }
        .padding(.horizontal)
    }

    // MARK: - Model Router Card

    private var modelRouterCard: some View {
        DashboardCard(
            title: "Model Router",
            systemImage: "arrow.triangle.branch",
            color: .blue
        ) {
            let history = modelRouter.routingHistory
            if let last = history.last {
                MetricRow(label: "Last Model", value: last.model.id)
                MetricRow(label: "Task Type", value: last.taskType.rawValue.capitalized)
                MetricRow(label: "Provider", value: last.provider)
                MetricRow(
                    label: "Confidence",
                    value: String(format: "%.0f%%", last.confidence * 100)
                )
                MetricRow(label: "Reason", value: last.reason, isMultiline: true)
            } else {
                Text("No routing decisions yet")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            Divider()
            MetricRow(label: "Total Decisions", value: "\(history.count)")
            MetricRow(label: "Learned Patterns", value: "\(modelRouter.learnedPreferences.count)")
        }
    }

    // MARK: - Confidence Card

    private var confidenceCard: some View {
        DashboardCard(
            title: "Response Confidence",
            systemImage: "checkmark.seal",
            color: .green
        ) {
            // ConfidenceSystem is not an ObservableObject — read state directly
            let system = ConfidenceSystem.shared
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Subsystems Enabled")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                EnabledSubsystemBadges(
                    multiModel: system.enableMultiModel,
                    webVerification: system.enableWebVerification,
                    codeExecution: system.enableCodeExecution,
                    staticAnalysis: system.enableStaticAnalysis,
                    feedbackLearning: system.enableFeedbackLearning
                )
                Divider()
                MetricRow(
                    label: "Multi-Model Consensus",
                    value: system.enableMultiModel ? "Active" : "Off"
                )
                MetricRow(
                    label: "Web Verification",
                    value: system.enableWebVerification ? "Active" : "Off"
                )
                MetricRow(
                    label: "Code Execution",
                    value: system.enableCodeExecution ? "Active" : "Off"
                )
                MetricRow(
                    label: "Static Analysis",
                    value: system.enableStaticAnalysis ? "Active" : "Off"
                )
                MetricRow(
                    label: "Feedback Learning",
                    value: system.enableFeedbackLearning ? "Active" : "Off"
                )
            }
        }
    }

    // MARK: - Agent Team Card

    private var agentTeamCard: some View {
        DashboardCard(
            title: "Agent Teams",
            systemImage: "person.3.sequence.fill",
            color: .purple
        ) {
            let teams = agentOrchestrator.activeTeams
            MetricRow(label: "Active Teams", value: "\(teams.count)")
            MetricRow(
                label: "Orchestrating",
                value: agentOrchestrator.isOrchestrating ? "Yes" : "No"
            )
            if teams.isEmpty {
                Text("No active agent teams")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                Divider()
                ForEach(teams.prefix(3)) { team in
                    HStack {
                        Circle()
                            .fill(team.status == .running ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)
                        Text(team.objective)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text(team.status == .running ? "Running" : "Done")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                if teams.count > 3 {
                    Text("+ \(teams.count - 3) more")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Memory Card

    private var memoryCard: some View {
        DashboardCard(
            title: "Personal Knowledge Graph",
            systemImage: "brain",
            color: .orange
        ) {
            let pkg = PersonalKnowledgeGraph.shared
            MetricRow(label: "Entities", value: "\(pkg.entityCount)")
            MetricRow(label: "Relationships", value: "\(pkg.edgeCount)")
            let density: String = pkg.entityCount > 0
                ? String(format: "%.1f avg", Double(pkg.edgeCount) / Double(pkg.entityCount))
                : "—"
            MetricRow(label: "Avg Connections", value: density)
            Divider()
            Text("Graph updates automatically as you chat")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Skills Card

    private var skillsCard: some View {
        DashboardCard(
            title: "Skills",
            systemImage: "bolt.badge.clock",
            color: .yellow
        ) {
            MetricRow(label: "Installed Skills", value: "\(skillsRegistry.installedSkills.count)")
            MetricRow(label: "Marketplace Skills", value: "\(skillsRegistry.marketplaceSkills.count)")
            MetricRow(label: "Suggested", value: "\(skillsRegistry.suggestedSkills.count)")
            if let syncedAt = skillsRegistry.lastSyncedAt {
                MetricRow(
                    label: "Last Sync",
                    value: syncedAt.formatted(date: .omitted, time: .shortened)
                )
            } else {
                MetricRow(label: "Last Sync", value: "Never")
            }
            Divider()
            if skillsRegistry.installedSkills.isEmpty {
                Text("No skills installed")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                ForEach(skillsRegistry.installedSkills.prefix(3)) { skill in
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                        Text(skill.name)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text("v\(skill.version)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                if skillsRegistry.installedSkills.count > 3 {
                    Text("+ \(skillsRegistry.installedSkills.count - 3) more")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Tool Use Card

    private var toolUseCard: some View {
        DashboardCard(
            title: "Tool Use",
            systemImage: "wrench.and.screwdriver",
            color: .teal
        ) {
            let catalog = AnthropicToolCatalog.shared
            let tools = catalog.buildToolCatalog()
            MetricRow(label: "Available Tools", value: "\(tools.count)")
            Divider()
            Text("Top tools available:")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(tools.prefix(5), id: \.name) { tool in
                HStack {
                    Image(systemName: "hammer.fill")
                        .foregroundStyle(.teal)
                        .font(.caption2)
                    Text(tool.name)
                        .font(.caption)
                        .lineLimit(1)
                }
            }
            if tools.count > 5 {
                Text("+ \(tools.count - 5) more tools")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Task Classifier Card

    private var classifierCard: some View {
        DashboardCard(
            title: "Task Classifier",
            systemImage: "tag.fill",
            color: .indigo
        ) {
            let history = classifier.classificationHistory
            if let last = history.last {
                MetricRow(
                    label: "Last Task Type",
                    value: last.taskType.rawValue.capitalized
                )
                MetricRow(
                    label: "Confidence",
                    value: String(format: "%.0f%%", last.confidence * 100)
                )
                MetricRow(
                    label: "Query",
                    value: String(last.query.prefix(50)),
                    isMultiline: true
                )
            } else {
                Text("No classifications yet")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            Divider()
            MetricRow(label: "History Size", value: "\(history.count)")
            MetricRow(label: "Learned Patterns", value: "\(classifier.learnedPatterns.count)")
            MetricRow(label: "Semantic Enabled", value: classifier.useSemanticClassification ? "Yes" : "No")
        }
    }

    // MARK: - Smart Router Budget Card

    private var smartRouterBudgetCard: some View {
        DashboardCard(
            title: "Smart Router Budget",
            systemImage: "dollarsign.circle",
            color: .red
        ) {
            MetricRow(
                label: "Daily Budget",
                value: String(format: "$%.2f", smartRouter.dailyBudget)
            )
            MetricRow(
                label: "Daily Spent",
                value: String(format: "$%.4f", smartRouter.dailySpent)
            )
            MetricRow(
                label: "Total Spent",
                value: String(format: "$%.4f", smartRouter.totalSpent)
            )
            MetricRow(
                label: "Total Tokens",
                value: "\(smartRouter.totalTokensUsed.formatted())"
            )
            MetricRow(
                label: "Success Rate",
                value: String(format: "%.0f%%", smartRouter.averageSuccessRate * 100)
            )
            MetricRow(
                label: "Strategy",
                value: smartRouter.defaultStrategy.rawValue.capitalized
            )
            Divider()
            let budgetUsed = smartRouter.dailyBudget > 0
                ? smartRouter.dailySpent / smartRouter.dailyBudget
                : 0
            ProgressView(value: min(budgetUsed, 1.0))
                .tint(budgetUsed > 0.8 ? .red : budgetUsed > 0.5 ? .orange : .green)
            Text(String(format: "%.0f%% of daily budget used", budgetUsed * 100))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Timer

    private func startRefreshTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            refreshToken = UUID()
        }
    }

    private func stopRefreshTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Dashboard Card

/// Reusable card container for dashboard metrics.
private struct DashboardCard<Content: View>: View {
    let title: String
    let systemImage: String
    let color: Color
    @ViewBuilder let content: Content

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                content
            }
        } label: {
            Label(title, systemImage: systemImage)
                .foregroundStyle(color)
                .font(.headline)
        }
    }
}

// MARK: - Metric Row

/// A single key-value metric row within a card.
private struct MetricRow: View {
    let label: String
    let value: String
    var isMultiline: Bool = false

    var body: some View {
        HStack(alignment: isMultiline ? .top : .center) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(minWidth: 80, alignment: .leading)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
                .lineLimit(isMultiline ? 3 : 1)
        }
    }
}

// MARK: - Enabled Subsystem Badges

/// Compact badge row for enabled/disabled confidence subsystems.
private struct EnabledSubsystemBadges: View {
    let multiModel: Bool
    let webVerification: Bool
    let codeExecution: Bool
    let staticAnalysis: Bool
    let feedbackLearning: Bool

    private var badges: [(name: String, enabled: Bool)] {
        [
            ("Multi", multiModel),
            ("Web", webVerification),
            ("Code", codeExecution),
            ("Static", staticAnalysis),
            ("Feedback", feedbackLearning)
        ]
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(badges, id: \.name) { badge in
                Text(badge.name)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(badge.enabled ? Color.green.opacity(0.2) : Color.gray.opacity(0.15))
                    .foregroundStyle(badge.enabled ? Color.green : Color.gray)
                    .clipShape(Capsule())
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    IntelligenceDashboardView()
        .frame(width: 900, height: 700)
}
#endif
