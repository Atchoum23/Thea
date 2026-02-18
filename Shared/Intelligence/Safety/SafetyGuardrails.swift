// SafetyGuardrails.swift
// Thea V2
//
// Comprehensive safety and guardrails system
// Includes action classification, rollback capability, human-in-the-loop, and audit trail

import Foundation
import OSLog

// MARK: - Action Classification

/// Classification of an action's risk level and type
public struct ActionClassification: Sendable {
    public let action: String
    public let category: SafetyActionCategory
    public let riskLevel: SafetyRiskLevel
    public let isReversible: Bool
    public let requiresConfirmation: Bool
    public let requiresAuthentication: Bool
    public let affectedResources: [AffectedResource]
    public let potentialImpact: String
    public let mitigations: [String]

    public init(
        action: String,
        category: SafetyActionCategory,
        riskLevel: SafetyRiskLevel,
        isReversible: Bool,
        requiresConfirmation: Bool = false,
        requiresAuthentication: Bool = false,
        affectedResources: [AffectedResource] = [],
        potentialImpact: String = "",
        mitigations: [String] = []
    ) {
        self.action = action
        self.category = category
        self.riskLevel = riskLevel
        self.isReversible = isReversible
        self.requiresConfirmation = requiresConfirmation
        self.requiresAuthentication = requiresAuthentication
        self.affectedResources = affectedResources
        self.potentialImpact = potentialImpact
        self.mitigations = mitigations
    }
}

/// High-level category of an action evaluated by the safety guardrail system.
public enum SafetyActionCategory: String, Codable, Sendable {
    case fileRead
    case fileWrite
    case fileDelete
    case codeExecution
    case systemCommand
    case networkRequest
    case databaseOperation
    case configurationChange
    case authentication
    case communication
    case dataExport
    case installation
    case other
}

/// Risk classification assigned to an action by the safety guardrails.
public enum SafetyRiskLevel: String, Codable, Sendable, Comparable {
    case safe       // No risk, fully reversible
    case low        // Minimal risk, easily reversible
    case medium     // Some risk, reversible with effort
    case high       // Significant risk, may be irreversible
    case critical   // Extreme risk, likely irreversible

    public static func < (lhs: SafetyRiskLevel, rhs: SafetyRiskLevel) -> Bool {
        let order: [SafetyRiskLevel] = [.safe, .low, .medium, .high, .critical]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}

/// A specific resource that would be affected if a risky action were executed.
public struct AffectedResource: Identifiable, Sendable {
    public let id: UUID
    public let type: ResourceType
    public let identifier: String
    public let changeType: ChangeType

    public init(id: UUID = UUID(), type: ResourceType, identifier: String, changeType: ChangeType) {
        self.id = id
        self.type = type
        self.identifier = identifier
        self.changeType = changeType
    }

    public enum ResourceType: String, Sendable {
        case file, directory, database, configuration, system, network, credential, process
    }

    public enum ChangeType: String, Sendable {
        case create, read, update, delete, execute
    }
}

// MARK: - Rollback Capability

/// A rollback point for reverting actions
public struct RollbackPoint: Identifiable, Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let description: String
    public let actionId: UUID
    public let snapshotData: [SnapshotItem]
    public let isValid: Bool
    public let expiresAt: Date?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        description: String,
        actionId: UUID,
        snapshotData: [SnapshotItem],
        isValid: Bool = true,
        expiresAt: Date? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.description = description
        self.actionId = actionId
        self.snapshotData = snapshotData
        self.isValid = isValid
        self.expiresAt = expiresAt
    }
}

public struct SnapshotItem: Identifiable, Codable, Sendable {
    public let id: UUID
    public let resourceType: String
    public let resourcePath: String
    public let originalContent: String?  // For file content
    public let originalMetadata: [String: String]
    public let snapshotPath: String?  // Path to backup file if large

    public init(
        id: UUID = UUID(),
        resourceType: String,
        resourcePath: String,
        originalContent: String? = nil,
        originalMetadata: [String: String] = [:],
        snapshotPath: String? = nil
    ) {
        self.id = id
        self.resourceType = resourceType
        self.resourcePath = resourcePath
        self.originalContent = originalContent
        self.originalMetadata = originalMetadata
        self.snapshotPath = snapshotPath
    }
}

/// Result of a rollback operation
public struct RollbackResult: Sendable {
    public let rollbackPointId: UUID
    public let success: Bool
    public let restoredItems: [String]
    public let failedItems: [(path: String, reason: String)]
    public let duration: TimeInterval

    public init(
        rollbackPointId: UUID,
        success: Bool,
        restoredItems: [String],
        failedItems: [(path: String, reason: String)],
        duration: TimeInterval
    ) {
        self.rollbackPointId = rollbackPointId
        self.success = success
        self.restoredItems = restoredItems
        self.failedItems = failedItems
        self.duration = duration
    }
}

// MARK: - Human-in-the-Loop

/// A request for human intervention
public struct HumanInterventionRequest: Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let action: ActionClassification
    public let reason: InterventionReason
    public let urgency: InterventionUrgency
    public let context: String
    public let options: [InterventionOption]
    public let timeout: TimeInterval?
    public let defaultAction: UUID?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        action: ActionClassification,
        reason: InterventionReason,
        urgency: InterventionUrgency = .normal,
        context: String,
        options: [InterventionOption],
        timeout: TimeInterval? = nil,
        defaultAction: UUID? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.action = action
        self.reason = reason
        self.urgency = urgency
        self.context = context
        self.options = options
        self.timeout = timeout
        self.defaultAction = defaultAction
    }

    public enum InterventionReason: String, Sendable {
        case highRiskAction
        case ambiguousRequest
        case policyViolation
        case resourceConflict
        case authenticationRequired
        case confirmationRequired
        case anomalyDetected
        case budgetExceeded
    }

    public enum InterventionUrgency: String, Sendable {
        case low       // Can wait indefinitely
        case normal    // Should respond within hours
        case high      // Should respond within minutes
        case critical  // Needs immediate response
    }
}

public struct InterventionOption: Identifiable, Sendable {
    public let id: UUID
    public let label: String
    public let description: String
    public let action: InterventionAction
    public let isRecommended: Bool
    public let riskLevel: SafetyRiskLevel

    public init(
        id: UUID = UUID(),
        label: String,
        description: String,
        action: InterventionAction,
        isRecommended: Bool = false,
        riskLevel: SafetyRiskLevel = .low
    ) {
        self.id = id
        self.label = label
        self.description = description
        self.action = action
        self.isRecommended = isRecommended
        self.riskLevel = riskLevel
    }

    public enum InterventionAction: Sendable {
        case proceed
        case proceedWithModification(String)
        case cancel
        case postpone(TimeInterval)
        case escalate
        case custom(String)
    }
}

public struct HumanInterventionResponse: Sendable {
    public let requestId: UUID
    public let selectedOptionId: UUID
    public let respondedAt: Date
    public let respondedBy: String?
    public let additionalNotes: String?

    public init(
        requestId: UUID,
        selectedOptionId: UUID,
        respondedAt: Date = Date(),
        respondedBy: String? = nil,
        additionalNotes: String? = nil
    ) {
        self.requestId = requestId
        self.selectedOptionId = selectedOptionId
        self.respondedAt = respondedAt
        self.respondedBy = respondedBy
        self.additionalNotes = additionalNotes
    }
}

// MARK: - Audit Trail

/// An audit log entry
public struct SafetyAuditEntry: Identifiable, Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let sessionId: UUID
    public let agentId: UUID?
    public let userId: String?
    public let action: String
    public let category: String
    public let riskLevel: String
    public let resources: [String]
    public let outcome: AuditOutcome
    public let details: [String: String]
    public let rollbackPointId: UUID?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        sessionId: UUID,
        agentId: UUID? = nil,
        userId: String? = nil,
        action: String,
        category: String,
        riskLevel: String,
        resources: [String] = [],
        outcome: AuditOutcome,
        details: [String: String] = [:],
        rollbackPointId: UUID? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.agentId = agentId
        self.userId = userId
        self.action = action
        self.category = category
        self.riskLevel = riskLevel
        self.resources = resources
        self.outcome = outcome
        self.details = details
        self.rollbackPointId = rollbackPointId
    }

    public enum AuditOutcome: String, Codable, Sendable {
        case success
        case failure
        case blocked
        case pending
        case rolledBack
    }
}

// MARK: - Safety Policy

/// Policy for safety enforcement
public struct SafetyPolicy: Codable, Sendable {
    public let id: UUID
    public let name: String
    public let rules: [SafetyRule]
    public let isEnabled: Bool
    public let priority: Int

    public init(
        id: UUID = UUID(),
        name: String,
        rules: [SafetyRule],
        isEnabled: Bool = true,
        priority: Int = 0
    ) {
        self.id = id
        self.name = name
        self.rules = rules
        self.isEnabled = isEnabled
        self.priority = priority
    }
}

public struct SafetyRule: Identifiable, Codable, Sendable {
    public let id: UUID
    public let name: String
    public let condition: RuleCondition
    public let action: RuleAction
    public let message: String

    public init(
        id: UUID = UUID(),
        name: String,
        condition: RuleCondition,
        action: RuleAction,
        message: String
    ) {
        self.id = id
        self.name = name
        self.condition = condition
        self.action = action
        self.message = message
    }

    public enum RuleCondition: Codable, Sendable {
        case actionCategory(String)
        case riskLevel(String)
        case resourcePattern(String)
        case timeOfDay(Int, Int)  // start hour, end hour
        case custom(String)
    }

    public enum RuleAction: String, Codable, Sendable {
        case allow
        case warn
        case requireConfirmation
        case block
        case escalate
    }
}
