//
//  TheaAgentListView.swift
//  Thea
//
//  iOS list view for browsing agent sessions.
//  Presented as a sheet or navigation destination.
//

import SwiftUI

#if os(iOS)
struct TheaAgentListView: View {
    @State private var orchestrator = TheaAgentOrchestrator.shared
    @State private var selectedSession: TheaAgentSession?
    @Environment(\.dismiss) private var dismiss

    private var activeSessions: [TheaAgentSession] {
        orchestrator.sessions.filter { $0.state.isActive }
    }

    private var completedSessions: [TheaAgentSession] {
        orchestrator.sessions.filter { $0.state.isTerminal }
    }

    var body: some View {
        NavigationStack {
            Group {
                if orchestrator.sessions.isEmpty {
                    emptyState
                } else {
                    sessionList
                }
            }
            .navigationTitle("Agents")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Agents", systemImage: "person.3")
        } description: {
            Text("Use the @agent prefix in chat to delegate tasks to specialized agents.")
        }
    }

    // MARK: - Session List

    private var sessionList: some View {
        List {
            if !activeSessions.isEmpty {
                Section("Active") {
                    ForEach(activeSessions) { session in
                        agentRow(session)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    TheaAgentOrchestrator.shared.cancelSession(session)
                                } label: {
                                    Label("Cancel", systemImage: "xmark")
                                }

                                Button {
                                    if session.state == .paused {
                                        Task { await TheaAgentOrchestrator.shared.resumeSession(session) }
                                    } else {
                                        TheaAgentOrchestrator.shared.pauseSession(session)
                                    }
                                } label: {
                                    Label(
                                        session.state == .paused ? "Resume" : "Pause",
                                        systemImage: session.state == .paused ? "play.fill" : "pause.fill"
                                    )
                                }
                                .tint(.orange)
                            }
                    }
                }
            }

            if !completedSessions.isEmpty {
                Section("Completed") {
                    ForEach(completedSessions.suffix(20)) { session in
                        agentRow(session)
                    }
                }
            }
        }
        .sheet(item: $selectedSession) { session in
            IOSAgentDetailView(session: session)
        }
    }

    // MARK: - Row

    private func agentRow(_ session: TheaAgentSession) -> some View {
        Button {
            selectedSession = session
        } label: {
            HStack(spacing: TheaSpacing.md) {
                Circle()
                    .fill(stateColor(session.state))
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.name)
                        .font(.theaSubhead)
                    Text(session.taskDescription)
                        .font(.theaCaption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(session.state.displayName)
                        .font(.theaCaption2)
                        .foregroundStyle(.secondary)
                    Text(elapsedText(session.elapsed))
                        .font(.theaCaption2)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func stateColor(_ state: TheaAgentState) -> Color {
        switch state {
        case .idle: .gray
        case .planning: .orange
        case .working: .green
        case .awaitingApproval, .paused: .yellow
        case .completed: .blue
        case .failed: .red
        case .cancelled: .gray
        }
    }

    private func elapsedText(_ elapsed: TimeInterval) -> String {
        if elapsed < 60 {
            return "\(Int(elapsed))s"
        } else if elapsed < 3600 {
            return "\(Int(elapsed / 60))m"
        } else {
            return "\(Int(elapsed / 3600))h"
        }
    }
}

// MARK: - iOS Agent Detail

private struct IOSAgentDetailView: View {
    let session: TheaAgentSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: TheaSpacing.lg) {
                    // Status
                    HStack {
                        Label(session.state.displayName, systemImage: session.state.sfSymbol)
                            .font(.theaSubhead)
                        Spacer()
                        Text(session.agentType.rawValue.capitalized)
                            .font(.theaCaption1)
                            .foregroundStyle(.secondary)
                    }

                    // Task description
                    Text(session.taskDescription)
                        .font(.theaBody)

                    // Progress
                    if session.state.isActive {
                        if let progress = session.progress {
                            ProgressView(value: progress)
                        } else {
                            ProgressView()
                        }
                        if !session.statusMessage.isEmpty {
                            Text(session.statusMessage)
                                .font(.theaCaption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Messages
                    if !session.messages.isEmpty {
                        sectionHeader("Output")
                        ForEach(session.messages) { message in
                            Text(message.content)
                                .font(.theaBody)
                                .textSelection(.enabled)
                                .padding(TheaSpacing.sm)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: TheaCornerRadius.sm)
                                        .fill(.fill.tertiary)
                                )
                        }
                    }

                    // Artifacts
                    if !session.artifacts.isEmpty {
                        sectionHeader("Artifacts")
                        ForEach(session.artifacts) { artifact in
                            DisclosureGroup(artifact.title) {
                                Text(artifact.content)
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                            }
                        }
                    }

                    // Error
                    if let error = session.error {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(error)
                                .font(.theaCaption1)
                                .foregroundStyle(.red)
                        }
                        .padding(TheaSpacing.sm)
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: TheaCornerRadius.sm))
                    }

                    // Metrics
                    sectionHeader("Metrics")
                    HStack(spacing: TheaSpacing.lg) {
                        metricItem("Tokens", value: "\(session.tokensUsed)/\(session.tokenBudget)")
                        metricItem("Cost", value: session.formattedCost)
                        metricItem("Pressure", value: session.contextPressure.rawValue.capitalized)
                        if session.confidence > 0 {
                            metricItem("Confidence", value: String(format: "%.0f%%", session.confidence * 100))
                        }
                    }
                    if let model = session.modelId {
                        HStack(spacing: TheaSpacing.sm) {
                            metricItem("Model", value: model)
                            if let provider = session.providerId {
                                metricItem("Provider", value: provider)
                            }
                        }
                    }

                    // Feedback
                    if session.state == .completed {
                        sectionHeader("Rate this result")
                        if let rating = session.userRating {
                            HStack(spacing: TheaSpacing.sm) {
                                Image(systemName: rating.sfSymbol)
                                    .foregroundStyle(rating == .positive ? .green : .red)
                                Text(rating == .positive ? "Helpful" : "Not helpful")
                                    .font(.theaCaption1)
                            }
                        } else {
                            HStack(spacing: TheaSpacing.md) {
                                Button {
                                    TheaAgentOrchestrator.shared.submitFeedback(for: session, rating: .positive)
                                } label: {
                                    Label("Helpful", systemImage: "hand.thumbsup")
                                }
                                .buttonStyle(.bordered)

                                Button {
                                    TheaAgentOrchestrator.shared.submitFeedback(for: session, rating: .negative)
                                } label: {
                                    Label("Not helpful", systemImage: "hand.thumbsdown")
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
                .padding(TheaSpacing.lg)
            }
            .navigationTitle(session.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                if session.state.isActive {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Cancel Agent", role: .destructive) {
                            TheaAgentOrchestrator.shared.cancelSession(session)
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.theaSubhead)
            .foregroundStyle(.secondary)
    }

    private func metricItem(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.theaCaption2)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.theaCaption1)
                .monospacedDigit()
        }
    }
}
#endif
