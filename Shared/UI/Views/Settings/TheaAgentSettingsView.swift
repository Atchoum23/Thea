//
//  TheaAgentSettingsView.swift
//  Thea
//
//  Settings view for sub-agent delegation: config, cost tracking, feedback stats.
//

import SwiftUI

struct TheaAgentSettingsView: View {
    @StateObject private var settings = SettingsManager.shared

    var body: some View {
        Form {
            delegationSection
            concurrencySection
            autonomySection
            costTrackingSection
            feedbackStatsSection
        }
        .formStyle(.grouped)
        #if os(macOS)
        .frame(minWidth: 400)
        #endif
    }

    // MARK: - Delegation

    private var delegationSection: some View {
        Section {
            Toggle("Enable agent delegation", isOn: $settings.agentDelegationEnabled)
                .accessibilityLabel("Enable agent delegation")
                .accessibilityHint("Allows Thea to delegate tasks to specialized sub-agents")

            Toggle(
                "Auto-delegate complex tasks",
                isOn: $settings.agentAutoDelegateComplexTasks
            )
            .disabled(!settings.agentDelegationEnabled)
            .accessibilityLabel("Automatically delegate complex tasks")
            .accessibilityHint("Thea will automatically delegate multi-step tasks without asking")
        } header: {
            Text("Delegation")
        } footer: {
            Text("When enabled, use @agent prefix in chat to delegate tasks. Auto-delegation lets Thea decide when to use agents.")
        }
    }

    // MARK: - Concurrency

    private var concurrencySection: some View {
        Section("Concurrency") {
            HStack {
                Text("Max concurrent agents")
                Spacer()
                Picker("", selection: $settings.agentMaxConcurrent) {
                    ForEach([1, 2, 3, 4, 6, 8], id: \.self) { count in
                        Text("\(count)").tag(count)
                    }
                }
                .labelsHidden()
                .frame(width: 80)
            }
            .disabled(!settings.agentDelegationEnabled)
        }
    }

    // MARK: - Autonomy

    private var autonomySection: some View {
        Section {
            Picker("Autonomy level", selection: $settings.agentDefaultAutonomy) {
                Text("Disabled").tag("disabled")
                Text("Ask Always").tag("askAlways")
                Text("Balanced").tag("balanced")
                Text("Proactive").tag("proactive")
                Text("Full Auto").tag("fullAuto")
            }
            .disabled(!settings.agentDelegationEnabled)
            .accessibilityLabel("Default autonomy level for agents")
        } header: {
            Text("Default Autonomy")
        } footer: {
            Text("Controls how much freedom agents have to take actions. 'Balanced' asks for approval on risky operations.")
        }
    }

    // MARK: - Cost Tracking

    private var costTrackingSection: some View {
        Section {
            AgentCostSummaryView()
        } header: {
            Label("Cost Tracking", systemImage: "dollarsign.circle")
        }
    }

    // MARK: - Feedback Stats

    private var feedbackStatsSection: some View {
        Section {
            AgentFeedbackStatsView()
        } header: {
            Label("Agent Performance", systemImage: "chart.bar")
        }
    }
}

// MARK: - Cost Summary View

struct AgentCostSummaryView: View {
    private var orchestrator: TheaAgentOrchestrator { TheaAgentOrchestrator.shared }

    var body: some View {
        VStack(alignment: .leading, spacing: TheaSpacing.sm) {
            // Total cost
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Session total")
                        .font(.theaCaption2)
                        .foregroundStyle(.secondary)
                    Text(formatCost(orchestrator.totalSessionCost))
                        .font(.theaHeadline)
                        .monospacedDigit()
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Active agents")
                        .font(.theaCaption2)
                        .foregroundStyle(.secondary)
                    Text("\(orchestrator.activeSessions.count)")
                        .font(.theaHeadline)
                        .monospacedDigit()
                }
            }

            // Budget setting
            HStack {
                Text("Daily budget")
                    .font(.theaBody)
                Spacer()
                budgetPicker
            }

            // Budget warning
            if orchestrator.isBudgetExceeded {
                HStack(spacing: TheaSpacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Daily budget exceeded")
                        .font(.theaCaption1)
                        .foregroundStyle(.orange)
                }
            }

            // Provider breakdown
            let breakdown = orchestrator.costByProvider
            if !breakdown.isEmpty {
                Divider()
                Text("Cost by Provider")
                    .font(.theaCaption2)
                    .foregroundStyle(.secondary)

                ForEach(breakdown, id: \.provider) { item in
                    HStack {
                        Text(item.provider.capitalized)
                            .font(.theaCaption1)
                        Spacer()
                        Text(formatCost(item.cost))
                            .font(.theaCaption1)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var budgetPicker: some View {
        Picker("", selection: Binding(
            get: { orchestrator.dailyCostBudget },
            set: { orchestrator.dailyCostBudget = $0 }
        )) {
            Text("No limit").tag(0.0)
            Text("$1").tag(1.0)
            Text("$5").tag(5.0)
            Text("$10").tag(10.0)
            Text("$25").tag(25.0)
            Text("$50").tag(50.0)
        }
        .labelsHidden()
        .frame(width: 100)
        .accessibilityLabel("Daily cost budget")
    }

    private func formatCost(_ cost: Double) -> String {
        if cost == 0 { return "Free" }
        if cost < 0.01 { return "<$0.01" }
        return String(format: "$%.2f", cost)
    }
}

// MARK: - Feedback Stats View

struct AgentFeedbackStatsView: View {
    private var orchestrator: TheaAgentOrchestrator { TheaAgentOrchestrator.shared }

    var body: some View {
        VStack(alignment: .leading, spacing: TheaSpacing.sm) {
            // Overall stats
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total sessions")
                        .font(.theaCaption2)
                        .foregroundStyle(.secondary)
                    Text("\(orchestrator.completedSessions.count)")
                        .font(.theaHeadline)
                        .monospacedDigit()
                }

                Spacer()

                let rated = orchestrator.completedSessions.filter { $0.userRating != nil }
                let positive = rated.filter { $0.userRating == .positive }
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Feedback rate")
                        .font(.theaCaption2)
                        .foregroundStyle(.secondary)
                    if rated.isEmpty {
                        Text("—")
                            .font(.theaHeadline)
                    } else {
                        let pct = Double(positive.count) / Double(rated.count) * 100
                        Text(String(format: "%.0f%%", pct))
                            .font(.theaHeadline)
                            .foregroundStyle(pct >= 70 ? .green : (pct >= 40 ? .orange : .red))
                    }
                }
            }

            // Per-agent-type breakdown
            let typesWithFeedback = agentTypeStats()
            if !typesWithFeedback.isEmpty {
                Divider()
                Text("Success by Agent Type")
                    .font(.theaCaption2)
                    .foregroundStyle(.secondary)

                ForEach(typesWithFeedback, id: \.type) { stat in
                    HStack {
                        Image(systemName: stat.type.sfSymbol)
                            .foregroundStyle(.secondary)
                            .frame(width: 16)
                        Text(stat.type.displayName)
                            .font(.theaCaption1)
                        Spacer()
                        if let rate = stat.successRate {
                            Text(String(format: "%.0f%%", rate * 100))
                                .font(.theaCaption1)
                                .monospacedDigit()
                                .foregroundStyle(rate >= 0.7 ? .green : (rate >= 0.4 ? .orange : .red))
                        } else {
                            Text("—")
                                .font(.theaCaption1)
                                .foregroundStyle(.tertiary)
                        }
                        Text("(\(stat.total))")
                            .font(.theaCaption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    private func agentTypeStats() -> [AgentTypeStat] {
        var stats: [SpecializedAgentType: (positive: Int, total: Int)] = [:]
        for session in orchestrator.completedSessions where session.userRating != nil {
            var current = stats[session.agentType] ?? (positive: 0, total: 0)
            current.total += 1
            if session.userRating == .positive { current.positive += 1 }
            stats[session.agentType] = current
        }
        return stats.map { type, counts in
            AgentTypeStat(
                type: type,
                successRate: counts.total > 0 ? Double(counts.positive) / Double(counts.total) : nil,
                total: counts.total
            )
        }
        .sorted { $0.total > $1.total }
    }
}

private struct AgentTypeStat {
    let type: SpecializedAgentType
    let successRate: Double?
    let total: Int
}
