//
//  TheaAgentDetailView.swift
//  Thea
//
//  Inspector panel showing detailed view of a selected agent session.
//  Shows messages, artifacts, progress, and action controls.
//

import SwiftUI

#if os(macOS)
struct TheaAgentDetailView: View {
    let session: TheaAgentSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: TheaSpacing.lg) {
                    if session.state.isActive {
                        progressSection
                    }
                    if !session.messages.isEmpty {
                        messagesSection
                    }
                    if !session.artifacts.isEmpty {
                        artifactsSection
                    }
                    if let error = session.error {
                        errorSection(error)
                    }
                    metricsSection
                }
                .padding(TheaSpacing.lg)
            }
            Divider()
            actionBar
        }
        .frame(minWidth: 300)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: TheaSpacing.sm) {
            HStack {
                Image(systemName: session.agentType.sfSymbol)
                    .foregroundStyle(.secondary)
                Text(session.name)
                    .font(.theaHeadline)
                Spacer()
                stateBadge
            }

            Text(session.taskDescription)
                .font(.theaCaption1)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            HStack(spacing: TheaSpacing.md) {
                Label(session.agentType.rawValue.capitalized, systemImage: "tag")
                    .font(.theaCaption2)
                    .foregroundStyle(.secondary)

                Label(elapsedFormatted, systemImage: "clock")
                    .font(.theaCaption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(TheaSpacing.lg)
    }

    private var stateBadge: some View {
        Text(session.state.displayName)
            .font(.theaCaption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(stateColor.opacity(0.15))
            .foregroundStyle(stateColor)
            .clipShape(Capsule())
    }

    private var stateColor: Color {
        switch session.state {
        case .idle: .gray
        case .planning: .orange
        case .working: .green
        case .awaitingApproval, .paused: .yellow
        case .completed: .blue
        case .failed: .red
        case .cancelled: .gray
        }
    }

    // MARK: - Progress

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: TheaSpacing.xs) {
            if let progress = session.progress {
                ProgressView(value: progress) {
                    Text(session.statusMessage.isEmpty ? "Working..." : session.statusMessage)
                        .font(.theaCaption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing: TheaSpacing.sm) {
                    ProgressView()
                        .controlSize(.small)
                    Text(session.statusMessage.isEmpty ? "Working..." : session.statusMessage)
                        .font(.theaCaption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Messages

    private var messagesSection: some View {
        VStack(alignment: .leading, spacing: TheaSpacing.sm) {
            sectionTitle("Output", count: session.messages.count)

            ForEach(session.messages) { message in
                HStack(alignment: .top, spacing: TheaSpacing.sm) {
                    Image(systemName: message.role == .agent ? "cpu" : "person")
                        .font(.theaCaption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 16)

                    Text(message.content)
                        .font(.theaBody)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(TheaSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: TheaCornerRadius.sm)
                        .fill(message.role == .agent ? Color.accentColor.opacity(0.05) : .clear)
                )
            }
        }
    }

    // MARK: - Artifacts

    private var artifactsSection: some View {
        VStack(alignment: .leading, spacing: TheaSpacing.sm) {
            sectionTitle("Artifacts", count: session.artifacts.count)

            ForEach(session.artifacts) { artifact in
                DisclosureGroup {
                    Text(artifact.content)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(TheaSpacing.sm)
                } label: {
                    HStack {
                        Image(systemName: artifactIcon(artifact.type))
                            .foregroundStyle(.secondary)
                        Text(artifact.title)
                            .font(.theaSubhead)
                        Spacer()
                        Text(artifact.type.rawValue)
                            .font(.theaCaption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    // MARK: - Error

    private func errorSection(_ error: String) -> some View {
        HStack(spacing: TheaSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(error)
                .font(.theaCaption1)
                .foregroundStyle(.red)
        }
        .padding(TheaSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: TheaCornerRadius.sm)
                .fill(Color.red.opacity(0.08))
        )
    }

    // MARK: - Metrics

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: TheaSpacing.xs) {
            sectionTitle("Metrics")
            HStack(spacing: TheaSpacing.lg) {
                metricItem("Tokens", value: "\(session.tokensUsed)")
                metricItem("Budget", value: "\(session.tokenBudget)")
                metricItem("Pressure", value: session.contextPressure.rawValue.capitalized)
                if session.confidence > 0 {
                    metricItem("Confidence", value: String(format: "%.0f%%", session.confidence * 100))
                }
            }
        }
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

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: TheaSpacing.md) {
            if session.state.isActive {
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

                Button(role: .destructive) {
                    TheaAgentOrchestrator.shared.cancelSession(session)
                } label: {
                    Label("Cancel", systemImage: "xmark")
                }
            }

            Spacer()

            if session.state == .completed {
                Button {
                    let output = session.messages.map(\.content).joined(separator: "\n")
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(output, forType: .string)
                } label: {
                    Label("Copy Output", systemImage: "doc.on.doc")
                }
            }
        }
        .padding(TheaSpacing.md)
    }

    // MARK: - Helpers

    private func sectionTitle(_ title: String, count: Int? = nil) -> some View {
        HStack {
            Text(title)
                .font(.theaSubhead)
                .foregroundStyle(.secondary)
            if let count {
                Text("(\(count))")
                    .font(.theaCaption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func artifactIcon(_ type: TheaAgentArtifact.ArtifactType) -> String {
        switch type {
        case .code: "chevron.left.forwardslash.chevron.right"
        case .text: "doc.text"
        case .markdown: "text.badge.checkmark"
        case .json: "curlybraces"
        case .plan: "list.bullet.clipboard"
        case .summary: "doc.plaintext"
        }
    }

    private var elapsedFormatted: String {
        let elapsed = session.elapsed
        if elapsed < 60 {
            return "\(Int(elapsed))s"
        } else if elapsed < 3600 {
            let mins = Int(elapsed / 60)
            let secs = Int(elapsed.truncatingRemainder(dividingBy: 60))
            return "\(mins)m \(secs)s"
        } else {
            return "\(Int(elapsed / 3600))h \(Int((elapsed / 60).truncatingRemainder(dividingBy: 60)))m"
        }
    }
}
#endif
