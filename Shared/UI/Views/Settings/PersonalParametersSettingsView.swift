// PersonalParametersSettingsView.swift
// Thea — AN3: PersonalParameters Settings UI — "Adaptive System" tab
//
// 24 sliders with research defaults, outcome signals, and per-parameter reset.
// Live readiness gauge, interrupt budget bar, and data freshness grid.
// Wired into MacSettingsView sidebar as "Adaptive System".

import SwiftUI

// MARK: - PersonalParametersSettingsView

struct PersonalParametersSettingsView: View {
    @State private var params = PersonalParameters.shared
    @State private var readiness = HumanReadinessEngine.shared
    @State private var budget = InterruptBudgetManager.shared
    @State private var freshness = DataFreshnessOrchestrator.shared
    @State private var orchestrator = ResourceOrchestrator.shared

    var body: some View {
        Form {
            // MARK: Live Status Header
            Section {
                liveStatusCard
            }

            // MARK: Interrupt Management
            Section("Interrupt Management") {
                parameterRow(
                    label: "Daily Interrupt Budget",
                    description: "Max interrupts per day (research: 4). SelfTuning: engagement rate.",
                    value: Binding(
                        get: { Double(params.interruptBudget) },
                        set: { params.interruptBudget = Int($0) }
                    ),
                    range: 1...12,
                    step: 1,
                    format: "%.0f interrupts",
                    defaultValue: 4
                )
                parameterRow(
                    label: "Idle Breakpoint",
                    description: "Idle duration before user is considered in break (research: 3 min).",
                    value: $params.idleBreakpointMinutes,
                    range: 1...15,
                    step: 0.5,
                    format: "%.1f min",
                    defaultValue: 3.0
                )
            }

            // MARK: Flow State
            Section("Flow State") {
                parameterRow(
                    label: "Flow Ramp Time",
                    description: "Sustained focus before flow threshold reachable (research: 17.5 min).",
                    value: $params.flowRampMinutes,
                    range: 5...40,
                    step: 2.5,
                    format: "%.1f min",
                    defaultValue: 17.5
                )
                parameterRow(
                    label: "Flow Threshold",
                    description: "Readiness score to enter flow-protection (research: 85%).",
                    value: $params.flowThreshold,
                    range: 0.5...1.0,
                    step: 0.05,
                    format: "%.0f%%",
                    displayMultiplier: 100,
                    defaultValue: 0.85
                )
            }

            // MARK: Ultradian Rhythm
            Section("Ultradian Rhythm") {
                parameterRow(
                    label: "Work Block",
                    description: "Target work block duration (research: 75 min). SelfTuning: task completion rate.",
                    value: $params.workBlockMinutes,
                    range: 30...120,
                    step: 5,
                    format: "%.0f min",
                    defaultValue: 75
                )
                parameterRow(
                    label: "Break Duration",
                    description: "Target break after work block (research: 33 min).",
                    value: $params.breakMinutes,
                    range: 10...60,
                    step: 5,
                    format: "%.0f min",
                    defaultValue: 33
                )
                parameterRow(
                    label: "Ultradian Cycle",
                    description: "Full cycle duration (work + break; research: 100 min).",
                    value: $params.ultradianCycleMinutes,
                    range: 60...150,
                    step: 5,
                    format: "%.0f min",
                    defaultValue: 100
                )
            }

            // MARK: HRV / Physiology
            Section("HRV & Physiology") {
                parameterRow(
                    label: "HRV Trough Threshold",
                    description: "% below baseline to declare trough (research: ±10%). SelfTuning: HRV outcome.",
                    value: $params.hrvTroughPercent,
                    range: 0.05...0.30,
                    step: 0.01,
                    format: "±%.0f%%",
                    displayMultiplier: 100,
                    defaultValue: 0.10
                )
                parameterRow(
                    label: "HRV Baseline Window",
                    description: "Rolling baseline calibration window (research: 30 days).",
                    value: Binding(
                        get: { Double(params.hrvBaselineDays) },
                        set: { params.hrvBaselineDays = Int($0) }
                    ),
                    range: 7...90,
                    step: 7,
                    format: "%.0f days",
                    defaultValue: 30
                )
            }

            // MARK: Morning Readiness Weights
            Section("Morning Readiness Weights") {
                Text("Weights must sum to 1.0 — SelfTuning adjusts based on predictive accuracy.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                parameterRow(label: "HRV Weight",   description: "HRV contribution (research: 40%).",   value: $params.morningWeightHRV,         range: 0.1...0.6, step: 0.05, format: "%.0f%%", displayMultiplier: 100, defaultValue: 0.40)
                parameterRow(label: "Sleep Weight",  description: "Sleep quality (research: 25%).",       value: $params.morningWeightSleep,       range: 0.1...0.5, step: 0.05, format: "%.0f%%", displayMultiplier: 100, defaultValue: 0.25)
                parameterRow(label: "Deep Weight",   description: "Deep sleep % (research: 15%).",        value: $params.morningWeightDeep,        range: 0.05...0.4, step: 0.05, format: "%.0f%%", displayMultiplier: 100, defaultValue: 0.15)
                parameterRow(label: "Temp Weight",   description: "Wrist temp proxy (research: 10%).",    value: $params.morningWeightTemperature, range: 0.05...0.3, step: 0.05, format: "%.0f%%", displayMultiplier: 100, defaultValue: 0.10)
                parameterRow(label: "REM Weight",    description: "REM sleep % (research: 10%).",         value: $params.morningWeightREM,         range: 0.05...0.3, step: 0.05, format: "%.0f%%", displayMultiplier: 100, defaultValue: 0.10)
            }

            // MARK: Readiness Thresholds
            Section("Readiness State Thresholds") {
                parameterRow(label: "Active Threshold",  description: "Min readiness → ACTIVE state (research: 65%).", value: $params.stateActiveThreshold, range: 0.4...0.8, step: 0.05, format: "%.0f%%", displayMultiplier: 100, defaultValue: 0.65)
                parameterRow(label: "High Threshold",    description: "Min readiness → HIGH state (research: 90%).",   value: $params.stateHighThreshold,   range: 0.7...1.0, step: 0.05, format: "%.0f%%", displayMultiplier: 100, defaultValue: 0.90)
                parameterRow(label: "Satisfice Target",  description: "Below this → satisfice not optimize (research: 70%).", value: $params.satisficeTarget, range: 0.3...0.8, step: 0.05, format: "%.0f%%", displayMultiplier: 100, defaultValue: 0.70)
            }

            // MARK: Claude Session
            Section("Claude Session Management") {
                parameterRow(
                    label: "Compact At",
                    description: "Context % triggering compaction (research: 70%).",
                    value: $params.claudeCompactAt,
                    range: 0.5...0.9,
                    step: 0.05,
                    format: "%.0f%%",
                    displayMultiplier: 100,
                    defaultValue: 0.70
                )
                parameterRow(
                    label: "Circuit Breaker",
                    description: "Consecutive failures before 15-min pause (research: 3).",
                    value: Binding(
                        get: { Double(params.claudeCircuitBreakerAttempts) },
                        set: { params.claudeCircuitBreakerAttempts = Int($0) }
                    ),
                    range: 1...10,
                    step: 1,
                    format: "%.0f attempts",
                    defaultValue: 3
                )
                parameterRow(
                    label: "Session Budget",
                    description: "Max Claude API spend per session (research: $2.00).",
                    value: $params.claudeBudgetPerSession,
                    range: 0.50...20.0,
                    step: 0.50,
                    format: "$%.2f",
                    defaultValue: 2.00
                )
            }

            // MARK: Data Freshness Grid
            Section("Data Freshness") {
                freshnessGrid
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .navigationTitle("Adaptive System")
    }

    // MARK: - Live Status Card

    private var liveStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 28))
                    .foregroundStyle(.purple)
                VStack(alignment: .leading) {
                    Text("Adaptive System")
                        .font(.title2.bold())
                    Text("Real-time readiness · Interrupt gating · fullAuto guardrails")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Readiness Gauge
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Readiness Score")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(readiness.readinessScore * 100))%")
                        .font(.caption.bold())
                        .foregroundStyle(readinessColor)
                    Text("· \(orchestrator.currentState.rawValue.capitalized)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: readiness.readinessScore)
                    .tint(readinessColor)
            }

            // Interrupt Budget Bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Interrupt Budget Today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(budget.usedToday)/\(params.interruptBudget)")
                        .font(.caption.bold())
                        .foregroundStyle(budget.budgetExhausted ? .red : .primary)
                }
                ProgressView(value: Double(budget.usedToday), total: Double(params.interruptBudget))
                    .tint(budget.budgetExhausted ? .red : .orange)
            }

            // Ultradian Phase
            HStack {
                Label(readiness.ultradianPhase.rawValue.capitalized, systemImage: phaseIcon)
                    .font(.caption)
                    .foregroundStyle(phaseColor)
                Spacer()
                Text("Recommended: \(Int(orchestrator.recommendedWorkBlockMinutes))min block")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Data Freshness Grid

    private var freshnessGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(DataCategory.allCases, id: \.self) { category in
                HStack {
                    Circle()
                        .fill(freshness.isFresh(category) ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.displayName)
                            .font(.caption.bold())
                        if let last = freshness.lastRefresh(category) {
                            Text(last.formatted(.relative(presentation: .named)))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Never refreshed")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }
                    Spacer()
                }
                .padding(6)
                .background(Color.primary.opacity(0.04))
                .cornerRadius(6)
            }
        }
    }

    // MARK: - Parameter Row Helper

    private func parameterRow(
        label: String,
        description: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        format: String,
        displayMultiplier: Double = 1.0,
        defaultValue: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                Text(String(format: format, value.wrappedValue * displayMultiplier))
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(width: 70, alignment: .trailing)
                Button("Reset") {
                    value.wrappedValue = defaultValue
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
            Slider(value: value, in: range, step: step)
            Text(description)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Colors & Icons

    private var readinessColor: Color {
        switch readiness.readinessScore {
        case 0.9...: return .green
        case 0.65...: return .blue
        default: return .orange
        }
    }

    private var phaseIcon: String {
        switch readiness.ultradianPhase {
        case .peak:    return "arrow.up.circle.fill"
        case .trough:  return "arrow.down.circle.fill"
        case .unknown: return "circle.dashed"
        }
    }

    private var phaseColor: Color {
        switch readiness.ultradianPhase {
        case .peak:    return .green
        case .trough:  return .orange
        case .unknown: return .secondary
        }
    }
}

#Preview {
    PersonalParametersSettingsView()
        .frame(width: 600, height: 900)
}
