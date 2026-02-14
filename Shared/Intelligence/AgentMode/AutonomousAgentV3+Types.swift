// AutonomousAgentV3+Types.swift
// Thea V2
//
// Supporting types for AutonomousAgentV3: Plan, Specification, Execution State.

import Foundation

// MARK: - Autonomous Execution Plan

/// A plan for autonomous execution
public struct AutonomousPlan: Identifiable, Sendable {
    public let id: UUID
    public let goal: String
    public let steps: [PlanStep]
    public let estimatedDuration: TimeInterval
    public let requiredCapabilities: Set<String>
    public let riskLevel: RiskLevel
    public let rollbackStrategy: RollbackStrategy?

    public init(
        id: UUID = UUID(),
        goal: String,
        steps: [PlanStep],
        estimatedDuration: TimeInterval,
        requiredCapabilities: Set<String> = [],
        riskLevel: RiskLevel = .low,
        rollbackStrategy: RollbackStrategy? = nil
    ) {
        self.id = id
        self.goal = goal
        self.steps = steps
        self.estimatedDuration = estimatedDuration
        self.requiredCapabilities = requiredCapabilities
        self.riskLevel = riskLevel
        self.rollbackStrategy = rollbackStrategy
    }

    public struct PlanStep: Identifiable, Sendable {
        public let id: UUID
        public let description: String
        public let action: StepAction
        public let dependencies: [UUID]
        public let verification: VerificationStrategy?
        public let estimatedDuration: TimeInterval

        public init(
            id: UUID = UUID(),
            description: String,
            action: StepAction,
            dependencies: [UUID] = [],
            verification: VerificationStrategy? = nil,
            estimatedDuration: TimeInterval = 30
        ) {
            self.id = id
            self.description = description
            self.action = action
            self.dependencies = dependencies
            self.verification = verification
            self.estimatedDuration = estimatedDuration
        }
    }

    public enum StepAction: Sendable {
        case generateCode(language: String, requirements: String)
        case modifyFile(path: String, changes: String)
        case createFile(path: String, content: String)
        case runCommand(command: String)
        case runTests(testSuite: String?)
        case verifyOutput(expectedPattern: String)
        case aiQuery(prompt: String)
        case createAgent(agentSpec: AgentSpecification)
    }

    public enum VerificationStrategy: Sendable {
        case compileCheck
        case testRun(testName: String?)
        case outputMatch(pattern: String)
        case fileExists(path: String)
        case aiReview
        case manual
    }

    public enum RiskLevel: String, Sendable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        case critical = "Critical"
    }

    public struct RollbackStrategy: Sendable {
        public let type: RollbackType
        public let checkpointId: UUID?

        public enum RollbackType: Sendable {
            case gitRevert
            case fileRestore
            case stateReset
            case manual
        }
    }
}

// MARK: - Agent Specification (for agents creating agents)

/// Specification for creating a new agent
public struct AgentSpecification: Sendable {
    public let name: String
    public let purpose: String
    public let systemPrompt: String
    public let capabilities: [String]
    public let triggers: [AgentTrigger]
    public let actions: [AgentAction]
    public let constraints: AgentConstraints

    public struct AgentConstraints: Sendable {
        public let maxRuntime: TimeInterval
        public let allowedDomains: [String]
        public let requiredApprovals: [String]
        public let resourceLimits: ResourceLimits

        public struct ResourceLimits: Sendable {
            public let maxMemoryMB: Int
            public let maxApiCalls: Int
            public let maxFileOperations: Int
        }
    }

    public init(
        name: String,
        purpose: String,
        systemPrompt: String,
        capabilities: [String] = [],
        triggers: [AgentTrigger] = [],
        actions: [AgentAction] = [],
        constraints: AgentConstraints? = nil
    ) {
        self.name = name
        self.purpose = purpose
        self.systemPrompt = systemPrompt
        self.capabilities = capabilities
        self.triggers = triggers
        self.actions = actions
        self.constraints = constraints ?? AgentConstraints(
            maxRuntime: 3600,
            allowedDomains: ["*"],
            requiredApprovals: [],
            resourceLimits: .init(maxMemoryMB: 1024, maxApiCalls: 1000, maxFileOperations: 100)
        )
    }
}

// MARK: - Execution State

/// Current state of autonomous execution
public struct AutonomousExecutionState: Sendable {
    public var planId: UUID
    public var currentStepIndex: Int
    public var status: ExecutionStatus
    public var startTime: Date
    public var completedSteps: [UUID]
    public var failedSteps: [UUID: ExecutionError]
    public var fixAttempts: [UUID: Int]
    public var auditLog: [AgentAuditEntry]

    public enum ExecutionStatus: String, Sendable {
        case planning
        case executing
        case verifying
        case fixing
        case paused
        case completed
        case failed
        case rolledBack
    }

    public struct ExecutionError: Sendable {
        public let stepId: UUID
        public let message: String
        public let errorType: ErrorType
        public let isRecoverable: Bool
        public let suggestedFix: String?

        public enum ErrorType: String, Sendable {
            case compilation
            case testFailure
            case timeout
            case resourceExhausted
            case permissionDenied
            case external
            case unknown
        }
    }

    public struct AgentAuditEntry: Identifiable, Sendable {
        public let id: UUID
        public let timestamp: Date
        public let action: String
        public let details: String
        public let outcome: AuditOutcome

        public enum AuditOutcome: String, Sendable {
            case success
            case failure
            case skipped
            case pending
        }
    }
}

// MARK: - Supporting Types

public struct AutonomousExecutionProgress: Sendable {
    public let phase: Phase
    public let stepIndex: Int
    public let totalSteps: Int
    public let message: String

    public enum Phase: String, Sendable {
        case started
        case planning
        case executing
        case verifying
        case fixing
        case completed
        case failed
    }
}

public struct AutonomousPlanResult: Sendable {
    public let planId: UUID
    public let success: Bool
    public let completedSteps: Int
    public let failedSteps: Int
    public let totalDuration: TimeInterval
    public let auditLog: [AutonomousExecutionState.AgentAuditEntry]
}

// MARK: - Errors

public enum AutonomousAgentError: LocalizedError {
    case noProviderAvailable
    case alreadyRunning
    case notPaused
    case verificationFailed(String)
    case stepFailed(String)
    case planCreationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .noProviderAvailable:
            "No AI provider available"
        case .alreadyRunning:
            "Agent is already running"
        case .notPaused:
            "Agent is not paused"
        case let .verificationFailed(step):
            "Verification failed for step: \(step)"
        case let .stepFailed(step):
            "Step failed: \(step)"
        case let .planCreationFailed(reason):
            "Plan creation failed: \(reason)"
        }
    }
}

// Helper to compare RiskLevel
extension AutonomousPlan.RiskLevel: Comparable {
    public static func < (lhs: AutonomousPlan.RiskLevel, rhs: AutonomousPlan.RiskLevel) -> Bool {
        let order: [AutonomousPlan.RiskLevel] = [.low, .medium, .high, .critical]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }
}
