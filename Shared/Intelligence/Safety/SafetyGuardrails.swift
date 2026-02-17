// SafetyGuardrails.swift
// Thea V2
//
// Comprehensive safety and guardrails system
// Includes action classification, rollback capability, human-in-the-loop, and audit trail

import Foundation
import OSLog

// MARK: - Action Classification

/// Classification of an action's risk level, reversibility, and required approvals.
public struct ActionClassification: Sendable {
    /// Human-readable description of the action.
    public let action: String
    /// Category of the action (file, network, code execution, etc.).
    public let category: SafetyActionCategory
    /// Risk level assessment.
    public let riskLevel: SafetyRiskLevel
    /// Whether the action can be undone via rollback.
    public let isReversible: Bool
    /// Whether the user must confirm before execution.
    public let requiresConfirmation: Bool
    /// Whether authentication is required before execution.
    public let requiresAuthentication: Bool
    /// Resources that will be affected by this action.
    public let affectedResources: [AffectedResource]
    /// Description of the potential impact if something goes wrong.
    public let potentialImpact: String
    /// Mitigation steps to reduce risk.
    public let mitigations: [String]

    /// Creates an action classification.
    /// - Parameters:
    ///   - action: Description of the action.
    ///   - category: Action category.
    ///   - riskLevel: Assessed risk level.
    ///   - isReversible: Whether rollback is possible.
    ///   - requiresConfirmation: Whether user confirmation is needed.
    ///   - requiresAuthentication: Whether authentication is needed.
    ///   - affectedResources: Resources that will be affected.
    ///   - potentialImpact: Impact description.
    ///   - mitigations: Risk mitigation steps.
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

/// Broad category of safety-relevant actions.
public enum SafetyActionCategory: String, Codable, Sendable {
    /// Reading a file from disk.
    case fileRead
    /// Writing or modifying a file.
    case fileWrite
    /// Deleting a file or directory.
    case fileDelete
    /// Executing code (script, binary, REPL).
    case codeExecution
    /// Running a system or shell command.
    case systemCommand
    /// Making an outbound network request.
    case networkRequest
    /// Database read, write, or migration.
    case databaseOperation
    /// Changing app or system configuration.
    case configurationChange
    /// Authentication or credential operation.
    case authentication
    /// Sending a message or email.
    case communication
    /// Exporting data outside the app.
    case dataExport
    /// Installing software or packages.
    case installation
    /// Action that does not fit other categories.
    case other
}

/// Risk level of an action, ordered from safest to most dangerous.
public enum SafetyRiskLevel: String, Codable, Sendable, Comparable {
    /// No risk, fully reversible.
    case safe
    /// Minimal risk, easily reversible.
    case low
    /// Some risk, reversible with effort.
    case medium
    /// Significant risk, may be irreversible.
    case high
    /// Extreme risk, likely irreversible.
    case critical

    public static func < (lhs: SafetyRiskLevel, rhs: SafetyRiskLevel) -> Bool {
        let order: [SafetyRiskLevel] = [.safe, .low, .medium, .high, .critical]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}

/// A resource that will be affected by an action.
public struct AffectedResource: Identifiable, Sendable {
    /// Unique resource identifier.
    public let id: UUID
    /// Type of resource (file, database, credential, etc.).
    public let type: ResourceType
    /// Path or identifier of the resource.
    public let identifier: String
    /// How the resource will be changed.
    public let changeType: ChangeType

    /// Creates an affected resource descriptor.
    /// - Parameters:
    ///   - id: Resource identifier.
    ///   - type: Resource type.
    ///   - identifier: Resource path or name.
    ///   - changeType: Type of change.
    public init(id: UUID = UUID(), type: ResourceType, identifier: String, changeType: ChangeType) {
        self.id = id
        self.type = type
        self.identifier = identifier
        self.changeType = changeType
    }

    /// Classification of resource types.
    public enum ResourceType: String, Sendable {
        /// A file on disk.
        case file
        /// A directory on disk.
        case directory
        /// A database or data store.
        case database
        /// Configuration or settings.
        case configuration
        /// System resource (process, daemon, etc.).
        case system
        /// Network endpoint or connection.
        case network
        /// Credential or secret.
        case credential
        /// Running process.
        case process
    }

    /// Type of change being made to a resource.
    public enum ChangeType: String, Sendable {
        /// Creating a new resource.
        case create
        /// Reading without modification.
        case read
        /// Modifying an existing resource.
        case update
        /// Deleting a resource.
        case delete
        /// Executing a resource (running code).
        case execute
    }
}

// MARK: - Rollback Capability

/// A checkpoint captured before an action, enabling rollback if needed.
public struct RollbackPoint: Identifiable, Codable, Sendable {
    /// Unique rollback point identifier.
    public let id: UUID
    /// When the checkpoint was created.
    public let timestamp: Date
    /// Human-readable description of what was checkpointed.
    public let description: String
    /// ID of the action this rollback point is for.
    public let actionId: UUID
    /// Snapshots of affected resources at checkpoint time.
    public let snapshotData: [SnapshotItem]
    /// Whether this rollback point is still usable.
    public let isValid: Bool
    /// When this rollback point expires and becomes unusable.
    public let expiresAt: Date?

    /// Creates a rollback point.
    /// - Parameters:
    ///   - id: Rollback point identifier.
    ///   - timestamp: Creation time.
    ///   - description: Checkpoint description.
    ///   - actionId: Associated action ID.
    ///   - snapshotData: Resource snapshots.
    ///   - isValid: Whether still usable.
    ///   - expiresAt: Expiration time.
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

/// A snapshot of a single resource's state at a rollback point.
public struct SnapshotItem: Identifiable, Codable, Sendable {
    /// Unique snapshot item identifier.
    public let id: UUID
    /// Type of the snapshotted resource (e.g. "file", "config").
    public let resourceType: String
    /// Path or identifier of the snapshotted resource.
    public let resourcePath: String
    /// Original content of the resource, if small enough to inline.
    public let originalContent: String?
    /// Original metadata as key-value pairs.
    public let originalMetadata: [String: String]
    /// Path to an external backup file, for large resources.
    public let snapshotPath: String?

    /// Creates a snapshot item.
    /// - Parameters:
    ///   - id: Snapshot identifier.
    ///   - resourceType: Type of resource.
    ///   - resourcePath: Resource path.
    ///   - originalContent: Inline content backup.
    ///   - originalMetadata: Metadata backup.
    ///   - snapshotPath: External backup file path.
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

/// Result of attempting to rollback to a previous state.
public struct RollbackResult: Sendable {
    /// ID of the rollback point that was used.
    public let rollbackPointId: UUID
    /// Whether the rollback succeeded overall.
    public let success: Bool
    /// Paths of resources that were successfully restored.
    public let restoredItems: [String]
    /// Resources that failed to restore, with reasons.
    public let failedItems: [(path: String, reason: String)]
    /// How long the rollback operation took.
    public let duration: TimeInterval

    /// Creates a rollback result.
    /// - Parameters:
    ///   - rollbackPointId: Rollback point used.
    ///   - success: Whether rollback succeeded.
    ///   - restoredItems: Successfully restored paths.
    ///   - failedItems: Failed restorations with reasons.
    ///   - duration: Rollback duration.
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

/// A request for the user to review and approve or reject an action.
public struct HumanInterventionRequest: Identifiable, Sendable {
    /// Unique request identifier.
    public let id: UUID
    /// When the request was created.
    public let timestamp: Date
    /// The action requiring approval.
    public let action: ActionClassification
    /// Why human intervention is needed.
    public let reason: InterventionReason
    /// How urgently the user should respond.
    public let urgency: InterventionUrgency
    /// Contextual description of the situation.
    public let context: String
    /// Available response options for the user.
    public let options: [InterventionOption]
    /// Maximum time to wait for a response before timing out.
    public let timeout: TimeInterval?
    /// ID of the option to use if the user does not respond in time.
    public let defaultAction: UUID?

    /// Creates a human intervention request.
    /// - Parameters:
    ///   - id: Request identifier.
    ///   - timestamp: Creation time.
    ///   - action: Action requiring approval.
    ///   - reason: Reason for intervention.
    ///   - urgency: Response urgency.
    ///   - context: Situation description.
    ///   - options: Available response options.
    ///   - timeout: Response timeout.
    ///   - defaultAction: Default option on timeout.
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

    /// Why human intervention is required.
    public enum InterventionReason: String, Sendable {
        /// The action is classified as high risk.
        case highRiskAction
        /// The user's request is ambiguous.
        case ambiguousRequest
        /// The action would violate a safety policy.
        case policyViolation
        /// Multiple processes are competing for the same resource.
        case resourceConflict
        /// Authentication credentials are needed.
        case authenticationRequired
        /// Explicit user confirmation is required by policy.
        case confirmationRequired
        /// Unusual or anomalous behavior was detected.
        case anomalyDetected
        /// Token or cost budget would be exceeded.
        case budgetExceeded
    }

    /// How urgently the user should respond to an intervention request.
    public enum InterventionUrgency: String, Sendable {
        /// Can wait indefinitely.
        case low
        /// Should respond within hours.
        case normal
        /// Should respond within minutes.
        case high
        /// Needs immediate response.
        case critical
    }
}

/// An option presented to the user in a human intervention request.
public struct InterventionOption: Identifiable, Sendable {
    /// Unique option identifier.
    public let id: UUID
    /// Short label for the option button.
    public let label: String
    /// Detailed description of what this option does.
    public let description: String
    /// Action to take if this option is selected.
    public let action: InterventionAction
    /// Whether this is the recommended option.
    public let isRecommended: Bool
    /// Risk level of choosing this option.
    public let riskLevel: SafetyRiskLevel

    /// Creates an intervention option.
    /// - Parameters:
    ///   - id: Option identifier.
    ///   - label: Button label.
    ///   - description: Option description.
    ///   - action: Action on selection.
    ///   - isRecommended: Whether recommended.
    ///   - riskLevel: Risk of this option.
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

    /// Action to take when a user selects an intervention option.
    public enum InterventionAction: Sendable {
        /// Proceed with the original action.
        case proceed
        /// Proceed with a modified version of the action.
        case proceedWithModification(String)
        /// Cancel the action entirely.
        case cancel
        /// Postpone the action for a specified duration.
        case postpone(TimeInterval)
        /// Escalate to a higher authority or more capable system.
        case escalate
        /// Custom action with a descriptive string.
        case custom(String)
    }
}

/// The user's response to a human intervention request.
public struct HumanInterventionResponse: Sendable {
    /// ID of the request being responded to.
    public let requestId: UUID
    /// ID of the selected option.
    public let selectedOptionId: UUID
    /// When the user responded.
    public let respondedAt: Date
    /// Who responded (user name or device ID).
    public let respondedBy: String?
    /// Additional notes from the user.
    public let additionalNotes: String?

    /// Creates an intervention response.
    /// - Parameters:
    ///   - requestId: Request being responded to.
    ///   - selectedOptionId: Selected option ID.
    ///   - respondedAt: Response timestamp.
    ///   - respondedBy: Responder identity.
    ///   - additionalNotes: User notes.
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

/// An immutable audit log entry recording an action and its outcome.
public struct SafetyAuditEntry: Identifiable, Codable, Sendable {
    /// Unique audit entry identifier.
    public let id: UUID
    /// When the action occurred.
    public let timestamp: Date
    /// Session in which the action occurred.
    public let sessionId: UUID
    /// Agent that performed the action, if applicable.
    public let agentId: UUID?
    /// User who initiated or approved the action.
    public let userId: String?
    /// Description of the action taken.
    public let action: String
    /// Category of the action.
    public let category: String
    /// Risk level of the action.
    public let riskLevel: String
    /// Paths or identifiers of affected resources.
    public let resources: [String]
    /// Outcome of the action.
    public let outcome: AuditOutcome
    /// Additional details as key-value pairs.
    public let details: [String: String]
    /// ID of the rollback point created for this action, if any.
    public let rollbackPointId: UUID?

    /// Creates an audit entry.
    /// - Parameters:
    ///   - id: Entry identifier.
    ///   - timestamp: Action timestamp.
    ///   - sessionId: Session ID.
    ///   - agentId: Agent ID.
    ///   - userId: User ID.
    ///   - action: Action description.
    ///   - category: Action category.
    ///   - riskLevel: Risk level.
    ///   - resources: Affected resources.
    ///   - outcome: Action outcome.
    ///   - details: Additional details.
    ///   - rollbackPointId: Associated rollback point.
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

    /// Possible outcomes of an audited action.
    public enum AuditOutcome: String, Codable, Sendable {
        /// Action completed successfully.
        case success
        /// Action failed.
        case failure
        /// Action was blocked by a safety rule.
        case blocked
        /// Action is awaiting approval.
        case pending
        /// Action was rolled back after execution.
        case rolledBack
    }
}

// MARK: - Safety Policy

/// A named set of safety rules that govern action approval.
public struct SafetyPolicy: Codable, Sendable {
    /// Unique policy identifier.
    public let id: UUID
    /// Human-readable policy name.
    public let name: String
    /// Rules that compose this policy.
    public let rules: [SafetyRule]
    /// Whether this policy is currently active.
    public let isEnabled: Bool
    /// Evaluation priority (higher = evaluated first).
    public let priority: Int

    /// Creates a safety policy.
    /// - Parameters:
    ///   - id: Policy identifier.
    ///   - name: Policy name.
    ///   - rules: Safety rules.
    ///   - isEnabled: Whether enabled.
    ///   - priority: Evaluation priority.
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

/// A single safety rule within a policy, matching a condition to an enforcement action.
public struct SafetyRule: Identifiable, Codable, Sendable {
    /// Unique rule identifier.
    public let id: UUID
    /// Human-readable rule name.
    public let name: String
    /// Condition that triggers this rule.
    public let condition: RuleCondition
    /// Enforcement action when the condition matches.
    public let action: RuleAction
    /// Message to display when the rule triggers.
    public let message: String

    /// Creates a safety rule.
    /// - Parameters:
    ///   - id: Rule identifier.
    ///   - name: Rule name.
    ///   - condition: Trigger condition.
    ///   - action: Enforcement action.
    ///   - message: Display message.
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

    /// Conditions that can trigger a safety rule.
    public enum RuleCondition: Codable, Sendable {
        /// Matches a specific action category.
        case actionCategory(String)
        /// Matches a specific risk level.
        case riskLevel(String)
        /// Matches a resource path pattern.
        case resourcePattern(String)
        /// Matches a time-of-day range (start hour, end hour).
        case timeOfDay(Int, Int)
        /// Custom condition identified by a string key.
        case custom(String)
    }

    /// Enforcement actions when a safety rule is triggered.
    public enum RuleAction: String, Codable, Sendable {
        /// Allow the action to proceed.
        case allow
        /// Warn the user but allow proceeding.
        case warn
        /// Require explicit user confirmation.
        case requireConfirmation
        /// Block the action entirely.
        case block
        /// Escalate to a higher authority.
        case escalate
    }
}
