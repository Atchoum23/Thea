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

// MARK: - Safety Guardrails Manager

/// Main manager for safety guardrails
@MainActor
public final class SafetyGuardrailsManager: ObservableObject {
    public static let shared = SafetyGuardrailsManager()

    private let logger = Logger(subsystem: "com.thea.safety", category: "Guardrails")
    private let auditStorageURL: URL
    private let rollbackStorageURL: URL

    @Published public private(set) var policies: [SafetyPolicy] = []
    @Published public private(set) var pendingInterventions: [HumanInterventionRequest] = []
    @Published public private(set) var recentAuditEntries: [SafetyAuditEntry] = []
    @Published public private(set) var rollbackPoints: [RollbackPoint] = []

    // Configuration
    public var maxRollbackAge: TimeInterval = 7 * 24 * 60 * 60  // 7 days
    public var maxRollbackPoints: Int = 100
    public var auditRetentionDays: Int = 90
    public var isEnabled: Bool = true

    private var currentSessionId = UUID()

    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.auditStorageURL = documentsPath.appendingPathComponent("thea_audit_log.json")
        self.rollbackStorageURL = documentsPath.appendingPathComponent("thea_rollback_points.json")
        loadState()
        setupDefaultPolicies()
    }

    // MARK: - Action Classification

    /// Classify an action
    public func classifyAction(_ action: String, context: [String: String] = [:]) -> ActionClassification {
        // Determine category
        let category = determineCategory(action)

        // Determine risk level
        let riskLevel = determineRiskLevel(action, category: category)

        // Check reversibility
        let isReversible = checkReversibility(action, category: category)

        // Identify affected resources
        let resources = identifyAffectedResources(action, context: context)

        // Determine if confirmation needed
        let requiresConfirmation = riskLevel >= .medium || !isReversible

        return ActionClassification(
            action: action,
            category: category,
            riskLevel: riskLevel,
            isReversible: isReversible,
            requiresConfirmation: requiresConfirmation,
            affectedResources: resources,
            potentialImpact: describePotentialImpact(category, riskLevel: riskLevel),
            mitigations: suggestMitigations(category, riskLevel: riskLevel)
        )
    }

    // MARK: - Policy Evaluation

    /// Evaluate action against policies
    public func evaluateAction(_ classification: ActionClassification) -> PolicyEvaluationResult {
        var shouldBlock = false
        var warnings: [String] = []
        var requiresConfirmation = classification.requiresConfirmation

        for policy in policies.filter({ $0.isEnabled }).sorted(by: { $0.priority > $1.priority }) {
            for rule in policy.rules {
                if matchesCondition(rule.condition, classification: classification) {
                    switch rule.action {
                    case .block:
                        shouldBlock = true
                        warnings.append("Blocked by policy '\(policy.name)': \(rule.message)")
                    case .warn:
                        warnings.append("Warning from policy '\(policy.name)': \(rule.message)")
                    case .requireConfirmation:
                        requiresConfirmation = true
                        warnings.append("Confirmation required by policy '\(policy.name)': \(rule.message)")
                    case .escalate:
                        requiresConfirmation = true
                        warnings.append("Escalation required by policy '\(policy.name)': \(rule.message)")
                    case .allow:
                        break
                    }
                }
            }
        }

        return PolicyEvaluationResult(
            allowed: !shouldBlock,
            requiresConfirmation: requiresConfirmation,
            warnings: warnings
        )
    }

    // MARK: - Rollback Management

    /// Create a rollback point before an action
    public func createRollbackPoint(
        description: String,
        actionId: UUID,
        resources: [AffectedResource]
    ) async -> RollbackPoint? {
        var snapshots: [SnapshotItem] = []

        for resource in resources {
            if let snapshot = await captureSnapshot(resource) {
                snapshots.append(snapshot)
            }
        }

        guard !snapshots.isEmpty else { return nil }

        let rollbackPoint = RollbackPoint(
            description: description,
            actionId: actionId,
            snapshotData: snapshots,
            expiresAt: Date().addingTimeInterval(maxRollbackAge)
        )

        rollbackPoints.append(rollbackPoint)

        // Trim old rollback points
        cleanupRollbackPoints()

        saveState()
        logger.info("Created rollback point: \(description)")

        return rollbackPoint
    }

    /// Rollback to a specific point
    public func rollback(to rollbackPointId: UUID) async -> RollbackResult {
        let startTime = Date()

        guard let rollbackPoint = rollbackPoints.first(where: { $0.id == rollbackPointId }),
              rollbackPoint.isValid else {
            return RollbackResult(
                rollbackPointId: rollbackPointId,
                success: false,
                restoredItems: [],
                failedItems: [("N/A", "Rollback point not found or invalid")],
                duration: 0
            )
        }

        var restoredItems: [String] = []
        var failedItems: [(String, String)] = []

        for snapshot in rollbackPoint.snapshotData {
            do {
                try await restoreSnapshot(snapshot)
                restoredItems.append(snapshot.resourcePath)
            } catch {
                failedItems.append((snapshot.resourcePath, error.localizedDescription))
            }
        }

        let duration = Date().timeIntervalSince(startTime)
        let success = failedItems.isEmpty

        // Log rollback
        await recordAudit(
            action: "rollback",
            category: .other,
            riskLevel: .medium,
            resources: restoredItems,
            outcome: success ? .rolledBack : .failure
        )

        logger.info("Rollback \(success ? "completed" : "partially failed"): \(restoredItems.count) restored, \(failedItems.count) failed")

        return RollbackResult(
            rollbackPointId: rollbackPointId,
            success: success,
            restoredItems: restoredItems,
            failedItems: failedItems,
            duration: duration
        )
    }

    // MARK: - Human-in-the-Loop

    /// Request human intervention
    public func requestIntervention(
        action: ActionClassification,
        reason: HumanInterventionRequest.InterventionReason,
        context: String
    ) -> HumanInterventionRequest {
        let options: [InterventionOption] = [
            InterventionOption(
                label: "Proceed",
                description: "Allow the action to proceed",
                action: .proceed,
                riskLevel: action.riskLevel
            ),
            InterventionOption(
                label: "Cancel",
                description: "Cancel the action",
                action: .cancel,
                isRecommended: action.riskLevel >= .high,
                riskLevel: .safe
            ),
            InterventionOption(
                label: "Defer",
                description: "Delay the action for review",
                action: .postpone(3600),
                riskLevel: .safe
            )
        ]

        let request = HumanInterventionRequest(
            action: action,
            reason: reason,
            urgency: action.riskLevel >= .high ? .high : .normal,
            context: context,
            options: options,
            timeout: 300,  // 5 minutes
            defaultAction: options.first { $0.action.isCancel }?.id
        )

        pendingInterventions.append(request)
        logger.info("Requested human intervention: \(reason.rawValue)")

        return request
    }

    /// Process intervention response
    public func processIntervention(_ response: HumanInterventionResponse) -> Bool {
        guard let index = pendingInterventions.firstIndex(where: { $0.id == response.requestId }) else {
            return false
        }

        let request = pendingInterventions[index]
        pendingInterventions.remove(at: index)

        guard let option = request.options.first(where: { $0.id == response.selectedOptionId }) else {
            return false
        }

        switch option.action {
        case .proceed:
            logger.info("Intervention: proceeding with action")
            return true
        case .cancel:
            logger.info("Intervention: action cancelled")
            return false
        case .postpone(let interval):
            logger.info("Intervention: action postponed for \(interval) seconds")
            return false
        case .escalate:
            logger.info("Intervention: action escalated")
            return false
        case .proceedWithModification, .custom:
            logger.info("Intervention: custom action taken")
            return true
        }
    }

    // MARK: - Audit Trail

    /// Record an action in the audit trail
    public func recordAudit(
        action: String,
        category: SafetyActionCategory,
        riskLevel: SafetyRiskLevel,
        resources: [String],
        outcome: SafetyAuditEntry.AuditOutcome,
        details: [String: String] = [:],
        rollbackPointId: UUID? = nil
    ) async {
        let entry = SafetyAuditEntry(
            sessionId: currentSessionId,
            action: action,
            category: category.rawValue,
            riskLevel: riskLevel.rawValue,
            resources: resources,
            outcome: outcome,
            details: details,
            rollbackPointId: rollbackPointId
        )

        recentAuditEntries.append(entry)

        // Keep only recent entries in memory
        if recentAuditEntries.count > 1000 {
            recentAuditEntries = Array(recentAuditEntries.suffix(1000))
        }

        saveSafetyAuditEntry(entry)
    }

    /// Query audit trail
    public func queryAudit(
        startDate: Date? = nil,
        endDate: Date? = nil,
        categories: [SafetyActionCategory]? = nil,
        outcomes: [SafetyAuditEntry.AuditOutcome]? = nil,
        limit: Int = 100
    ) -> [SafetyAuditEntry] {
        var results = recentAuditEntries

        if let start = startDate {
            results = results.filter { $0.timestamp >= start }
        }
        if let end = endDate {
            results = results.filter { $0.timestamp <= end }
        }
        if let cats = categories {
            let catStrings = cats.map { $0.rawValue }
            results = results.filter { catStrings.contains($0.category) }
        }
        if let outs = outcomes {
            results = results.filter { outs.contains($0.outcome) }
        }

        return Array(results.suffix(limit))
    }

    // MARK: - Session Management

    public func startNewSession() {
        currentSessionId = UUID()
        logger.info("Started new safety session: \(self.currentSessionId)")
    }

    // MARK: - Private Helpers

    private func determineCategory(_ action: String) -> SafetyActionCategory {
        let lowercased = action.lowercased()

        if lowercased.contains("read") || lowercased.contains("get") || lowercased.contains("fetch") {
            return .fileRead
        }
        if lowercased.contains("write") || lowercased.contains("save") || lowercased.contains("create") {
            return .fileWrite
        }
        if lowercased.contains("delete") || lowercased.contains("remove") {
            return .fileDelete
        }
        if lowercased.contains("execute") || lowercased.contains("run") {
            return .codeExecution
        }
        if lowercased.contains("command") || lowercased.contains("shell") || lowercased.contains("bash") {
            return .systemCommand
        }
        if lowercased.contains("http") || lowercased.contains("api") || lowercased.contains("request") {
            return .networkRequest
        }
        if lowercased.contains("database") || lowercased.contains("sql") || lowercased.contains("query") {
            return .databaseOperation
        }

        return .other
    }

    private func determineRiskLevel(_ action: String, category: SafetyActionCategory) -> SafetyRiskLevel {
        let lowercased = action.lowercased()

        // Critical indicators
        if lowercased.contains("drop") || lowercased.contains("truncate") ||
           lowercased.contains("rm -rf") || lowercased.contains("force") {
            return .critical
        }

        // High risk indicators
        if lowercased.contains("delete all") || lowercased.contains("overwrite") ||
           lowercased.contains("production") || lowercased.contains("credentials") {
            return .high
        }

        // Category-based risk
        switch category {
        case .fileDelete, .databaseOperation:
            return .high
        case .systemCommand, .codeExecution:
            return .medium
        case .fileWrite, .configurationChange:
            return .medium
        case .networkRequest:
            return .low
        case .fileRead:
            return .safe
        default:
            return .low
        }
    }

    private func checkReversibility(_ action: String, category: SafetyActionCategory) -> Bool {
        switch category {
        case .fileRead:
            return true  // Read-only
        case .fileWrite:
            return true  // Can restore from backup
        case .fileDelete:
            return false  // May not be recoverable
        case .codeExecution, .systemCommand:
            return false  // Side effects unknown
        case .databaseOperation:
            return false  // May cause data loss
        default:
            return true
        }
    }

    private func identifyAffectedResources(_ action: String, context: [String: String]) -> [AffectedResource] {
        var resources: [AffectedResource] = []

        // Extract file paths from context
        if let path = context["path"] {
            resources.append(AffectedResource(
                type: .file,
                identifier: path,
                changeType: .update
            ))
        }

        return resources
    }

    private func describePotentialImpact(_ category: SafetyActionCategory, riskLevel: SafetyRiskLevel) -> String {
        switch (category, riskLevel) {
        case (.fileDelete, .high), (.fileDelete, .critical):
            return "Files will be permanently deleted and may not be recoverable"
        case (.databaseOperation, .high), (.databaseOperation, .critical):
            return "Database changes may cause data loss or corruption"
        case (.systemCommand, .medium), (.systemCommand, .high):
            return "System commands may have side effects on the environment"
        default:
            return "Action will modify system state"
        }
    }

    private func suggestMitigations(_ category: SafetyActionCategory, riskLevel: SafetyRiskLevel) -> [String] {
        var mitigations: [String] = []

        if riskLevel >= .medium {
            mitigations.append("Create a backup before proceeding")
        }
        if category == .fileDelete {
            mitigations.append("Move to trash instead of permanent delete")
        }
        if category == .databaseOperation {
            mitigations.append("Run in transaction with rollback capability")
        }

        return mitigations
    }

    private func matchesCondition(_ condition: SafetyRule.RuleCondition, classification: ActionClassification) -> Bool {
        switch condition {
        case .actionCategory(let category):
            return classification.category.rawValue == category
        case .riskLevel(let level):
            return classification.riskLevel.rawValue == level
        case .resourcePattern(let pattern):
            return classification.affectedResources.contains { $0.identifier.contains(pattern) }
        case .timeOfDay(let start, let end):
            let hour = Calendar.current.component(.hour, from: Date())
            return hour >= start && hour < end
        case .custom:
            return false  // Would need expression evaluator
        }
    }

    private func captureSnapshot(_ resource: AffectedResource) async -> SnapshotItem? {
        // In production, would actually read file content
        SnapshotItem(
            resourceType: resource.type.rawValue,
            resourcePath: resource.identifier,
            originalContent: nil,
            originalMetadata: [:]
        )
    }

    private func restoreSnapshot(_ snapshot: SnapshotItem) async throws {
        // In production, would actually restore the file
        logger.debug("Would restore: \(snapshot.resourcePath)")
    }

    private func cleanupRollbackPoints() {
        let now = Date()

        // Remove expired
        rollbackPoints.removeAll { point in
            if let expiry = point.expiresAt {
                return now > expiry
            }
            return false
        }

        // Keep only most recent if exceeds max
        if rollbackPoints.count > maxRollbackPoints {
            rollbackPoints = Array(rollbackPoints.suffix(maxRollbackPoints))
        }
    }

    private func setupDefaultPolicies() {
        // Block dangerous patterns
        let dangerousActionsPolicy = SafetyPolicy(
            name: "Block Dangerous Actions",
            rules: [
                SafetyRule(
                    name: "Block rm -rf",
                    condition: .resourcePattern("rm -rf"),
                    action: .block,
                    message: "Recursive force delete is blocked for safety"
                ),
                SafetyRule(
                    name: "Block production database",
                    condition: .resourcePattern("production"),
                    action: .requireConfirmation,
                    message: "Production resources require explicit confirmation"
                )
            ],
            priority: 100
        )

        // Require confirmation for high-risk
        let confirmationPolicy = SafetyPolicy(
            name: "High-Risk Confirmation",
            rules: [
                SafetyRule(
                    name: "Confirm high-risk actions",
                    condition: .riskLevel("high"),
                    action: .requireConfirmation,
                    message: "High-risk actions require confirmation"
                ),
                SafetyRule(
                    name: "Confirm critical actions",
                    condition: .riskLevel("critical"),
                    action: .requireConfirmation,
                    message: "Critical actions require confirmation"
                )
            ],
            priority: 90
        )

        policies = [dangerousActionsPolicy, confirmationPolicy]
    }

    // MARK: - Persistence

    private func loadState() {
        // Load rollback points
        if FileManager.default.fileExists(atPath: rollbackStorageURL.path) {
            do {
                let data = try Data(contentsOf: rollbackStorageURL)
                rollbackPoints = try JSONDecoder().decode([RollbackPoint].self, from: data)
                logger.info("Loaded \(self.rollbackPoints.count) rollback points")
            } catch {
                logger.error("Failed to load rollback points: \(error.localizedDescription)")
            }
        }
    }

    private func saveState() {
        // Save rollback points
        do {
            let data = try JSONEncoder().encode(rollbackPoints)
            try data.write(to: rollbackStorageURL)
        } catch {
            logger.error("Failed to save rollback points: \(error.localizedDescription)")
        }
    }

    private func saveSafetyAuditEntry(_ entry: SafetyAuditEntry) {
        // In production, would append to audit log file
        logger.debug("Audit: \(entry.action) - \(entry.outcome.rawValue)")
    }
}

// MARK: - Supporting Types

public struct PolicyEvaluationResult: Sendable {
    public let allowed: Bool
    public let requiresConfirmation: Bool
    public let warnings: [String]
}

private extension InterventionOption.InterventionAction {
    var isCancel: Bool {
        if case .cancel = self {
            return true
        }
        return false
    }
}
