//
//  TheaAgentStatusBar.swift
//  Thea
//
//  Compact horizontal bar showing active agent chips above the chat input.
//  Tappable chips reveal agent details. Shows summary count.
//

import SwiftUI

struct TheaAgentStatusBar: View {
    let sessions: [TheaAgentSession]
    var onSelectAgent: ((TheaAgentSession) -> Void)?

    private var activeSessions: [TheaAgentSession] {
        sessions.filter { $0.state.isActive }
    }

    var body: some View {
        HStack(spacing: TheaSpacing.sm) {
            Image(systemName: "person.3.fill")
                .font(.theaCaption2)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: TheaSpacing.xs) {
                    ForEach(activeSessions) { session in
                        agentChip(session)
                    }
                }
            }

            Spacer(minLength: 0)

            Text("\(activeSessions.count) agent\(activeSessions.count == 1 ? "" : "s") working")
                .font(.theaCaption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, TheaSpacing.lg)
        .padding(.vertical, TheaSpacing.xs)
        .background(.bar)
    }

    private func agentChip(_ session: TheaAgentSession) -> some View {
        Button {
            onSelectAgent?(session)
        } label: {
            HStack(spacing: 4) {
                Circle()
                    .fill(chipColor(for: session.state))
                    .frame(width: 6, height: 6)
                Text(session.name)
                    .font(.theaCaption2)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(.fill.tertiary)
            )
        }
        .buttonStyle(.plain)
    }

    private func chipColor(for state: TheaAgentState) -> Color {
        switch state {
        case .working: .green
        case .planning: .orange
        case .awaitingApproval, .paused: .yellow
        default: .gray
        }
    }
}
