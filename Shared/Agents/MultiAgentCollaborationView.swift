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

// MARK: - Agent Network View

/// Visual network of agents and their connections
struct AgentNetworkView: View {
    let agents: [CollaborationAgent]
    let tasks: [AgentTask]
    @Binding var selectedAgent: CollaborationAgent?
    let size: CGSize

    var body: some View {
        ZStack {
            // Draw connections between agents
            ForEach(tasks) { task in
                if let fromAgent = agents.first(where: { $0.role == .coordinator }),
                   let toAgent = agents.first(where: { $0.id == task.assignedTo }) {
                    ConnectionLine(
                        from: positionForAgent(fromAgent),
                        to: positionForAgent(toAgent),
                        isActive: task.status == .inProgress
                    )
                }
            }

            // Draw agent nodes
            ForEach(agents) { agent in
                AgentNode(agent: agent, isSelected: selectedAgent?.id == agent.id)
                    .position(positionForAgent(agent))
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) {
                            if selectedAgent?.id == agent.id {
                                selectedAgent = nil
                            } else {
                                selectedAgent = agent
                            }
                        }
                    }
            }
        }
    }

    private func positionForAgent(_ agent: CollaborationAgent) -> CGPoint {
        let centerX = size.width / 2
        let centerY = size.height / 2

        // Coordinator in center, others in circle
        if agent.role == .coordinator {
            return CGPoint(x: centerX, y: centerY)
        }

        let radius = min(size.width, size.height) * 0.35
        let nonCoordinatorIndex = agents.filter { $0.role != .coordinator }.firstIndex { $0.id == agent.id } ?? 0
        let nonCoordinatorCount = agents.filter { $0.role != .coordinator }.count
        let angle = (2 * .pi / Double(nonCoordinatorCount)) * Double(nonCoordinatorIndex) - .pi / 2

        return CGPoint(
            x: centerX + radius * cos(angle),
            y: centerY + radius * sin(angle)
        )
    }
}

// MARK: - Agent Node

/// Visual representation of a single agent
struct AgentNode: View {
    let agent: CollaborationAgent
    let isSelected: Bool

    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Outer ring (status indicator)
                Circle()
                    .stroke(agent.role.color, lineWidth: 3)
                    .frame(width: 72, height: 72)
                    .scaleEffect(agent.status == .working ? pulseScale : 1.0)

                // Inner circle
                Circle()
                    .fill(agent.role.color.gradient)
                    .frame(width: 64, height: 64)
                    .shadow(color: agent.role.color.opacity(0.3), radius: 8)

                // Icon
                Image(systemName: agent.role.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(.white)

                // Progress ring
                if agent.progress > 0 && agent.progress < 1 {
                    Circle()
                        .trim(from: 0, to: agent.progress)
                        .stroke(Color.primary, lineWidth: 4)
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                }
            }

            VStack(spacing: 2) {
                Text(agent.name)
                    .font(.caption)
                    .fontWeight(.semibold)

                Text(agent.status.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .opacity(isSelected ? 1 : 0)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(agent.role.color, lineWidth: isSelected ? 2 : 0)
        )
        .onAppear {
            if agent.status == .working {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    pulseScale = 1.1
                }
            }
        }
    }
}

// MARK: - Connection Line

/// Animated line between agents
struct ConnectionLine: View {
    let from: CGPoint
    let to: CGPoint
    let isActive: Bool

    @State private var dashPhase: CGFloat = 0

    var body: some View {
        Path { path in
            path.move(to: from)
            path.addLine(to: to)
        }
        .stroke(
            isActive ? Color.accentColor : Color.secondary.opacity(0.3),
            style: StrokeStyle(
                lineWidth: isActive ? 2 : 1,
                dash: isActive ? [8, 4] : [],
                dashPhase: dashPhase
            )
        )
        .onAppear {
            if isActive {
                withAnimation(.linear(duration: 0.5).repeatForever(autoreverses: false)) {
                    dashPhase = -12
                }
            }
        }
    }
}

// MARK: - Message Stream View

/// Shows inter-agent messages
struct MessageStreamView: View {
    let messages: [AgentMessage]

    var body: some View {
        VStack {
            Spacer()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(messages.suffix(10)) { message in
                        MessageBubbleSmall(message: message)
                    }
                }
                .padding()
            }
            .frame(height: 80)
            .background(.ultraThinMaterial)
        }
    }
}

struct MessageBubbleSmall: View {
    let message: AgentMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: iconForType(message.messageType))
                    .font(.caption2)
                Text(message.messageType.rawValue.capitalized)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .foregroundStyle(colorForType(message.messageType))

            Text(message.content)
                .font(.caption)
                .lineLimit(2)
        }
        .padding(8)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 2)
    }

    private func iconForType(_ type: AgentMessage.MessageType) -> String {
        switch type {
        case .request: return "arrow.up.circle"
        case .response: return "arrow.down.circle"
        case .handoff: return "arrow.right.arrow.left.circle"
        case .status: return "info.circle"
        case .error: return "exclamationmark.circle"
        case .completion: return "checkmark.circle"
        }
    }

    private func colorForType(_ type: AgentMessage.MessageType) -> Color {
        switch type {
        case .request: return .blue
        case .response: return .green
        case .handoff: return .purple
        case .status: return .secondary
        case .error: return .red
        case .completion: return .green
        }
    }
}

// MARK: - Agent Detail Sheet

/// Detailed view of selected agent
struct AgentDetailSheet: View {
    let agent: CollaborationAgent

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: agent.role.icon)
                    .font(.title2)
                    .foregroundStyle(agent.role.color)
                    .frame(width: 44, height: 44)
                    .background(agent.role.color.opacity(0.1))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(agent.name)
                        .font(.headline)
                    Text(agent.role.rawValue.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Status badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(agent.status.displayName)
                        .font(.caption)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(statusColor.opacity(0.1))
                .clipShape(Capsule())
            }

            // Current task
            if let task = agent.currentTask {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundStyle(.secondary)
                    Text(task)
                        .font(.caption)
                    Spacer()
                }
                .padding(12)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Metrics
            HStack(spacing: 24) {
                MetricView(label: "Tokens", value: "\(agent.metrics.tokensUsed)")
                MetricView(label: "Tasks", value: "\(agent.metrics.tasksCompleted)")
                MetricView(label: "Avg Time", value: String(format: "%.1fs", agent.metrics.averageResponseTime))
                MetricView(label: "Errors", value: "\(agent.metrics.errorCount)")
            }

            // Progress
            if agent.progress > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Progress")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(agent.progress * 100))%")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    ProgressView(value: agent.progress)
                        .tint(agent.role.color)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(radius: 10)
        .padding()
    }

    private var statusColor: Color {
        switch agent.status {
        case .idle: return .secondary
        case .thinking: return .yellow
        case .working: return .green
        case .waiting: return .orange
        case .completed: return .blue
        case .error: return .red
        }
    }
}

private struct MetricView: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
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
