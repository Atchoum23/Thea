//
//  TheaAgentSidebarView.swift
//  Thea
//
//  Compact right-side panel showing all active agent sessions.
//  Part of the sub-agent delegation UI (macOS only).
//

import SwiftUI

#if os(macOS)
struct TheaAgentSidebarView: View {
    @State private var orchestrator = TheaAgentOrchestrator.shared
    @Binding var selectedSession: TheaAgentSession?

    private var activeSessions: [TheaAgentSession] {
        orchestrator.sessions.filter { $0.state.isActive }
    }

    private var terminalSessions: [TheaAgentSession] {
        orchestrator.sessions.filter { $0.state.isTerminal }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            sessionList
        }
        .frame(width: 260)
        .background(.background)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Label("Agents", systemImage: "person.3.fill")
                .font(.theaHeadline)
            Spacer()
            if !activeSessions.isEmpty {
                Text("\(activeSessions.count)")
                    .font(.theaCaption1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.fill.tertiary)
                    .clipShape(Capsule())
            }
        }
        .padding()
    }

    // MARK: - Session List

    private var sessionList: some View {
        ScrollView {
            LazyVStack(spacing: TheaSpacing.xs) {
                if orchestrator.sessions.isEmpty {
                    emptyState
                } else {
                    if !activeSessions.isEmpty {
                        sectionHeader("Active")
                        ForEach(activeSessions) { session in
                            TheaAgentRowView(
                                session: session,
                                isSelected: selectedSession?.id == session.id
                            )
                            .onTapGesture { selectedSession = session }
                        }
                    }

                    if !terminalSessions.isEmpty {
                        sectionHeader("Completed")
                        ForEach(terminalSessions.suffix(10)) { session in
                            TheaAgentRowView(
                                session: session,
                                isSelected: selectedSession?.id == session.id
                            )
                            .onTapGesture { selectedSession = session }
                        }
                    }
                }
            }
            .padding(.horizontal, TheaSpacing.sm)
            .padding(.vertical, TheaSpacing.sm)
        }
    }

    private var emptyState: some View {
        VStack(spacing: TheaSpacing.md) {
            Image(systemName: "person.3")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("No agents running")
                .font(.theaCaption1)
                .foregroundStyle(.secondary)
            Text("Use @agent prefix to delegate tasks")
                .font(.theaCaption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, TheaSpacing.xxl)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.theaCaption1)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, TheaSpacing.sm)
            .padding(.leading, TheaSpacing.xs)
    }
}
#endif
