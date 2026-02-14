//
//  MultiAgentCollaborationTypes.swift
//  Thea
//
//  Supporting types for MultiAgentCollaborationView
//

import Foundation
import SwiftUI

// MARK: - Agent Types

/// Represents a specialized AI agent
public struct CollaborationAgent: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let role: AgentRole
    public let modelId: String
    public var status: AgentStatus
    public var currentTask: String?
    public var progress: Double
    public var metrics: AgentMetrics

    public enum AgentRole: String, Codable, Sendable, CaseIterable {
        case coordinator    // Orchestrates other agents
        case researcher     // Gathers information
        case coder          // Writes code
        case reviewer       // Reviews and validates
        case tester         // Creates and runs tests
        case documenter     // Writes documentation
        case optimizer      // Optimizes performance
        case designer       // UI/UX design
        case analyst        // Data analysis
        case communicator   // User interaction

        var icon: String {
            switch self {
            case .coordinator: return "person.3.fill"
            case .researcher: return "magnifyingglass"
            case .coder: return "chevron.left.forwardslash.chevron.right"
            case .reviewer: return "eye.fill"
            case .tester: return "checkmark.seal.fill"
            case .documenter: return "doc.text.fill"
            case .optimizer: return "gauge.with.needle.fill"
            case .designer: return "paintpalette.fill"
            case .analyst: return "chart.bar.xaxis"
            case .communicator: return "bubble.left.and.bubble.right.fill"
            }
        }

        var color: Color {
            switch self {
            case .coordinator: return .purple
            case .researcher: return .blue
            case .coder: return .green
            case .reviewer: return .orange
            case .tester: return .teal
            case .documenter: return .brown
            case .optimizer: return .red
            case .designer: return .pink
            case .analyst: return .indigo
            case .communicator: return .cyan
            }
        }
    }

    public enum AgentStatus: String, Sendable {
        case idle
        case thinking
        case working
        case waiting
        case completed
        case error

        var displayName: String {
            rawValue.capitalized
        }
    }

    public struct AgentMetrics: Sendable {
        public var tokensUsed: Int = 0
        public var tasksCompleted: Int = 0
        public var averageResponseTime: TimeInterval = 0
        public var errorCount: Int = 0
    }

    public init(
        id: UUID = UUID(),
        name: String,
        role: AgentRole,
        modelId: String
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.modelId = modelId
        self.status = .idle
        self.progress = 0
        self.metrics = AgentMetrics()
    }
}

// MARK: - Agent Task

/// A task assigned to an agent
public struct AgentTask: Identifiable, Sendable {
    public let id: UUID
    public let description: String
    public let assignedTo: UUID // Agent ID
    public var status: TaskStatus
    public var dependencies: [UUID] // Other task IDs
    public var result: String?
    public let createdAt: Date
    public var completedAt: Date?

    public enum TaskStatus: String, Sendable {
        case pending
        case inProgress
        case completed
        case failed
        case blocked
    }

    public init(
        id: UUID = UUID(),
        description: String,
        assignedTo: UUID,
        dependencies: [UUID] = []
    ) {
        self.id = id
        self.description = description
        self.assignedTo = assignedTo
        self.status = .pending
        self.dependencies = dependencies
        self.createdAt = Date()
    }
}

// MARK: - Agent Message

/// Inter-agent communication message
public struct AgentMessage: Identifiable, Sendable {
    public let id: UUID
    public let fromAgent: UUID
    public let toAgent: UUID?  // nil = broadcast
    public let content: String
    public let messageType: MessageType
    public let timestamp: Date

    public enum MessageType: String, Sendable {
        case request
        case response
        case handoff
        case status
        case error
        case completion
    }

    public init(
        id: UUID = UUID(),
        from: UUID,
        to: UUID? = nil,
        content: String,
        type: MessageType
    ) {
        self.id = id
        self.fromAgent = from
        self.toAgent = to
        self.content = content
        self.messageType = type
        self.timestamp = Date()
    }
}

// MARK: - Collaboration Session

/// A multi-agent collaboration session
public struct CollaborationSession: Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var agents: [CollaborationAgent]
    public var tasks: [AgentTask]
    public var messages: [AgentMessage]
    public var status: SessionStatus
    public let startedAt: Date
    public var completedAt: Date?

    public enum SessionStatus: String, Sendable {
        case preparing
        case active
        case paused
        case completed
        case failed
    }

    public init(
        id: UUID = UUID(),
        name: String,
        agents: [CollaborationAgent] = []
    ) {
        self.id = id
        self.name = name
        self.agents = agents
        self.tasks = []
        self.messages = []
        self.status = .preparing
        self.startedAt = Date()
    }
}
