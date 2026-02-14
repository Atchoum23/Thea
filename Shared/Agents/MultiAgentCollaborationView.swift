//
//  MultiAgentCollaborationView.swift
//  Thea
//
//  Multi-Agent Collaboration UI - visualizes agent orchestration,
//  task delegation, and collaborative problem-solving.
//
//  Based on 2026 agentic AI visualization best practices.
//
//  Copyright 2026. All rights reserved.
//

import Foundation
import SwiftUI
import os.log

// Model types (CollaborationAgent, AgentTask, AgentMessage, CollaborationSession) are in MultiAgentCollaborationTypes.swift
// Subviews (AgentNetworkView, AgentNode, ConnectionLine, MessageStreamView, AgentDetailSheet) are in MultiAgentCollaborationViewComponents.swift

// MARK: - Multi-Agent Orchestrator

/// Manages multi-agent collaboration sessions
@MainActor
public final class CollaborationOrchestrator: ObservableObject {
    public static let shared = CollaborationOrchestrator()

    private let logger = Logger(subsystem: "ai.thea.app", category: "MultiAgent")

    @Published public private(set) var activeSessions: [CollaborationSession] = []
    @Published public private(set) var currentSession: CollaborationSession?

    private init() {
        logger.info("CollaborationOrchestrator initialized")
    }

    // MARK: - Session Management

    /// Create a new collaboration session
    public func createSession(name: String, problem: String) -> CollaborationSession {
        var session = CollaborationSession(name: name)

        // Create default agent team
        session.agents = [
            CollaborationAgent(name: "THEA Coordinator", role: .coordinator, modelId: "anthropic/claude-4-opus"),
            CollaborationAgent(name: "Researcher", role: .researcher, modelId: "openai/gpt-4o"),
            CollaborationAgent(name: "Coder", role: .coder, modelId: "anthropic/claude-4-sonnet"),
            CollaborationAgent(name: "Reviewer", role: .reviewer, modelId: "anthropic/claude-4-opus")
        ]

        activeSessions.append(session)
        currentSession = session
        logger.info("Created session: \(name)")
        return session
    }

    /// Add an agent to the current session
    public func addAgent(_ agent: CollaborationAgent) {
        guard var session = currentSession else { return }
        session.agents.append(agent)
        updateSession(session)
    }

    /// Assign a task to an agent
    public func assignTask(_ task: AgentTask) {
        guard var session = currentSession else { return }
        session.tasks.append(task)
        updateSession(session)
    }

    /// Send a message between agents
    public func sendMessage(_ message: AgentMessage) {
        guard var session = currentSession else { return }
        session.messages.append(message)
        updateSession(session)
    }

    /// Update agent status
    public func updateAgentStatus(_ agentId: UUID, status: CollaborationAgent.AgentStatus, task: String? = nil) {
        guard var session = currentSession,
              let index = session.agents.firstIndex(where: { $0.id == agentId }) else { return }

        session.agents[index].status = status
        session.agents[index].currentTask = task
        updateSession(session)
    }

    /// Update agent progress
    public func updateAgentProgress(_ agentId: UUID, progress: Double) {
        guard var session = currentSession,
              let index = session.agents.firstIndex(where: { $0.id == agentId }) else { return }

        session.agents[index].progress = progress
        updateSession(session)
    }

    /// End the current session
    public func endSession(success: Bool) {
        guard var session = currentSession else { return }
        session.status = success ? .completed : .failed
        session.completedAt = Date()
        updateSession(session)
        currentSession = nil
    }

    private func updateSession(_ session: CollaborationSession) {
        if let index = activeSessions.firstIndex(where: { $0.id == session.id }) {
            activeSessions[index] = session
        }
        if currentSession?.id == session.id {
            currentSession = session
        }
    }
}

// MARK: - Multi-Agent Collaboration View

/// Main view for visualizing agent collaboration
public struct MultiAgentCollaborationView: View {
    @ObservedObject var orchestrator = CollaborationOrchestrator.shared
    @State private var selectedAgent: CollaborationAgent?
    @State private var showingMessages = false

    public init() {}

    public var body: some View {
        GeometryReader { geometry in
            if let session = orchestrator.currentSession {
                ZStack {
                    // Background
                    backgroundGrid

                    // Agent nodes
                    AgentNetworkView(
                        agents: session.agents,
                        tasks: session.tasks,
                        selectedAgent: $selectedAgent,
                        size: geometry.size
                    )

                    // Message overlay
                    if showingMessages {
                        MessageStreamView(messages: session.messages)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    sessionControls(session: session)
                }
                .overlay(alignment: .bottom) {
                    if let agent = selectedAgent {
                        AgentDetailSheet(agent: agent)
                            .transition(.move(edge: .bottom))
                    }
                }
            } else {
                emptyState
            }
        }
    }

    private var backgroundGrid: some View {
        Canvas { context, size in
            let gridSize: CGFloat = 40

            // Draw grid
            var path = Path()
            for x in stride(from: 0, to: size.width, by: gridSize) {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            for y in stride(from: 0, to: size.height, by: gridSize) {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(path, with: .color(.secondary.opacity(0.1)), lineWidth: 1)
        }
    }

    private func sessionControls(session: CollaborationSession) -> some View {
        HStack(spacing: 12) {
            // Session status
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor(session.status))
                    .frame(width: 8, height: 8)
                Text(session.status.rawValue.capitalized)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())

            // Toggle messages
            Button {
                withAnimation {
                    showingMessages.toggle()
                }
            } label: {
                Image(systemName: showingMessages ? "bubble.left.and.bubble.right.fill" : "bubble.left.and.bubble.right")
            }
            .buttonStyle(.bordered)

            // End session
            Button {
                orchestrator.endSession(success: true)
            } label: {
                Image(systemName: "xmark.circle")
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .padding()
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Active Session",
            systemImage: "person.3",
            description: Text("Start a multi-agent collaboration to see agents working together")
        )
    }

    private func statusColor(_ status: CollaborationSession.SessionStatus) -> Color {
        switch status {
        case .preparing: return .yellow
        case .active: return .green
        case .paused: return .orange
        case .completed: return .blue
        case .failed: return .red
        }
    }
}

// MARK: - Agent Team Picker

/// Picker for selecting agents for a collaboration
public struct AgentTeamPicker: View {
    @Binding var selectedRoles: Set<CollaborationAgent.AgentRole>

    public init(selectedRoles: Binding<Set<CollaborationAgent.AgentRole>>) {
        self._selectedRoles = selectedRoles
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Agent Team")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(CollaborationAgent.AgentRole.allCases, id: \.self) { role in
                    AgentRoleCard(
                        role: role,
                        isSelected: selectedRoles.contains(role)
                    ) {
                        if selectedRoles.contains(role) {
                            selectedRoles.remove(role)
                        } else {
                            selectedRoles.insert(role)
                        }
                    }
                }
            }
        }
    }
}

private struct AgentRoleCard: View {
    let role: CollaborationAgent.AgentRole
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: role.icon)
                    .font(.title2)
                    .foregroundStyle(role.color)

                Text(role.rawValue.capitalized)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? role.color.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? role.color : Color.secondary.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Multi-Agent View") {
    MultiAgentCollaborationView()
}

#Preview("Agent Team Picker") {
    @Previewable @State var selected: Set<CollaborationAgent.AgentRole> = [.coordinator, .coder]
    AgentTeamPicker(selectedRoles: $selected)
        .padding()
}
