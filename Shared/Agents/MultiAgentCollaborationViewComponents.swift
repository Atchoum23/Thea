//
//  MultiAgentCollaborationViewComponents.swift
//  Thea
//
//  Subviews extracted from MultiAgentCollaborationView.swift
//  for file_length compliance.
//
//  Copyright 2026. All rights reserved.
//

import SwiftUI

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
