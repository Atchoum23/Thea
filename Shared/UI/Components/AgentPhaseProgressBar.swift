//
//  AgentPhaseProgressBar.swift
//  Thea
//
//  Displays the active agent execution phase and progress inline in the chat view.
//  Shown only while the agent is actively executing a task (currentTask != nil
//  and phase != .done and phase != .userIntervention).
//

import SwiftUI

// MARK: - Agent Phase Progress Bar

/// Compact progress bar showing the current agent execution phase and overall completion.
/// Rendered below the message list and above the input bar while the agent is active.
struct AgentPhaseProgressBar: View {
    @ObservedObject var agentState: AgentExecutionState

    /// The bar is considered "active" when there is a running task that is not yet done.
    var isAgentActive: Bool {
        guard let task = agentState.currentTask else { return false }
        return task.status == .running && agentState.phase != .done
    }

    var body: some View {
        if isAgentActive {
            VStack(spacing: TheaSpacing.xs) {
                HStack(spacing: TheaSpacing.sm) {
                    // Animated phase icon
                    Image(systemName: phaseIcon)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(phaseColor)
                        .symbolEffect(.pulse, options: .repeating, value: agentState.phase)

                    // Phase label
                    Text(agentState.phase.displayName)
                        .font(.theaCaption2)
                        .foregroundStyle(.secondary)

                    // Status message (if any)
                    if !agentState.statusMessage.isEmpty {
                        Text("·")
                            .font(.theaCaption2)
                            .foregroundStyle(.tertiary)
                        Text(agentState.statusMessage)
                            .font(.theaCaption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Progress percentage
                    if agentState.progress > 0 {
                        Text("\(Int(agentState.progress * 100))%")
                            .font(.theaCaption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    // Interrupt button
                    if agentState.canInterrupt {
                        Button {
                            agentState.transition(to: .userIntervention)
                        } label: {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Interrupt agent")
                        .accessibilityLabel("Interrupt agent execution")
                    }
                }

                // Phase step indicators + animated progress bar
                VStack(spacing: TheaSpacing.xs) {
                    // Step pills (Gather → Act → Verify)
                    HStack(spacing: TheaSpacing.xs) {
                        ForEach(AgentPhase.allCases.filter { $0 != .done && $0 != .userIntervention }, id: \.self) { phase in
                            PhaseStepPill(
                                phase: phase,
                                currentPhase: agentState.phase
                            )
                        }
                        Spacer()
                    }

                    // Continuous progress bar
                    if agentState.progress > 0 {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.secondary.opacity(0.15))
                                    .frame(height: 3)

                                RoundedRectangle(cornerRadius: 2)
                                    .fill(phaseColor)
                                    .frame(width: geo.size.width * agentState.progress, height: 3)
                                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: agentState.progress)
                            }
                        }
                        .frame(height: 3)
                    }
                }
            }
            .padding(.horizontal, TheaSpacing.lg)
            .padding(.vertical, TheaSpacing.sm)
            .background(.ultraThinMaterial)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .top)),
                removal: .opacity.combined(with: .move(edge: .top))
            ))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Agent \(agentState.phase.displayName): \(Int(agentState.progress * 100))% complete")
        }
    }

    // MARK: - Phase Styling

    private var phaseIcon: String {
        switch agentState.phase {
        case .gatherContext: return "magnifyingglass"
        case .takeAction:    return "bolt.fill"
        case .verifyResults: return "checkmark.shield"
        case .done:          return "checkmark.circle.fill"
        case .userIntervention: return "hand.raised.fill"
        }
    }

    private var phaseColor: Color {
        switch agentState.phase {
        case .gatherContext: return .blue
        case .takeAction:    return .orange
        case .verifyResults: return .green
        case .done:          return .green
        case .userIntervention: return .yellow
        }
    }
}

// MARK: - Phase Step Pill

/// Small pill showing one phase step, filled when active or past, outlined when pending.
private struct PhaseStepPill: View {
    let phase: AgentPhase
    let currentPhase: AgentPhase

    private var state: PillState {
        let order: [AgentPhase] = [.gatherContext, .takeAction, .verifyResults]
        guard let myIdx = order.firstIndex(of: phase),
              let currentIdx = order.firstIndex(of: currentPhase) else {
            return .pending
        }
        if myIdx < currentIdx { return .completed }
        if myIdx == currentIdx { return .active }
        return .pending
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: phaseIcon(for: phase))
                .font(.system(size: 8, weight: .semibold))
            Text(phase.displayName)
                .font(.system(size: 9, weight: .medium))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(pillBackground)
        .foregroundStyle(pillForeground)
        .clipShape(Capsule())
        .accessibilityLabel("\(phase.displayName): \(state.label)")
    }

    private var pillBackground: Color {
        switch state {
        case .completed: return .green.opacity(0.25)
        case .active:    return .blue.opacity(0.25)
        case .pending:   return .secondary.opacity(0.1)
        }
    }

    private var pillForeground: Color {
        switch state {
        case .completed: return .green
        case .active:    return .blue
        case .pending:   return .secondary
        }
    }

    private func phaseIcon(for phase: AgentPhase) -> String {
        switch phase {
        case .gatherContext: return "magnifyingglass"
        case .takeAction:    return "bolt.fill"
        case .verifyResults: return "checkmark.shield"
        case .done:          return "checkmark.circle"
        case .userIntervention: return "hand.raised"
        }
    }

    private enum PillState {
        case completed, active, pending
        var label: String {
            switch self {
            case .completed: return "completed"
            case .active:    return "in progress"
            case .pending:   return "pending"
            }
        }
    }
}

// MARK: - AgentPhase + CaseIterable

extension AgentPhase: CaseIterable {
    public static var allCases: [AgentPhase] {
        [.gatherContext, .takeAction, .verifyResults, .done, .userIntervention]
    }
}

// MARK: - Preview

#Preview {
    let state = AgentExecutionState()

    VStack {
        Button("Set active (gatherContext)") {
            state.currentTask = AgentModeTask(
                title: "Analyze codebase",
                userQuery: "Find all async methods",
                taskType: .codeAnalysis
            )
            state.transition(to: .gatherContext)
            state.updateProgress(0.2, message: "Scanning 47 files...")
        }

        Button("takeAction") {
            state.transition(to: .takeAction)
            state.updateProgress(0.6, message: "Refactoring 3 files...")
        }

        Button("verifyResults") {
            state.transition(to: .verifyResults)
            state.updateProgress(0.9, message: "Running tests...")
        }

        Button("Done") {
            state.transition(to: .done)
        }

        Spacer().frame(height: 40)

        AgentPhaseProgressBar(agentState: state)
    }
    .padding()
    .frame(width: 500)
}
