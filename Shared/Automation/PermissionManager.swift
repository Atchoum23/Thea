import Foundation

/// Permission manager for automation safety
/// Implements a consequence-based permission system for automation actions
public actor PermissionManager {

    // MARK: - Properties

    private var permissionCache: [String: PermissionDecision] = [:]
    private var userPreferences: UserPermissionPreferences

    // MARK: - Initialization

    public init(preferences: UserPermissionPreferences = .default) {
        self.userPreferences = preferences
    }

    // MARK: - Permission Requests

    /// Request permission for an automation action
    public func requestPermission(for action: AutomationAction) async throws -> PermissionDecision {
        let actionKey = action.identifier

        // Check cache first
        if let cached = permissionCache[actionKey] {
            return cached
        }

        // Classify the action's consequence level
        let consequence = classifyConsequence(action)

        // Determine if permission is required based on user preferences
        let decision: PermissionDecision
        switch consequence {
        case .safe:
            // Safe actions don't require permission
            decision = .allowed(reason: "Safe read-only operation")

        case .moderate:
            if userPreferences.autoApproveModerate {
                decision = .allowed(reason: "Auto-approved moderate action")
            } else {
                decision = .requiresConfirmation(
                    action: action,
                    consequence: consequence,
                    reason: "Non-destructive write operation"
                )
            }

        case .high:
            decision = .requiresConfirmation(
                action: action,
                consequence: consequence,
                reason: "High-impact operation (file changes, payments)"
            )

        case .critical:
            decision = .requiresConfirmation(
                action: action,
                consequence: consequence,
                reason: "Critical operation (system changes, deletions)"
            )
        }

        // Cache the decision
        permissionCache[actionKey] = decision
        return decision
    }

    /// Classify the consequence level of an action
    public func classifyConsequence(_ action: AutomationAction) -> ConsequenceLevel {
        switch action {
        // Safe operations (read-only)
        case .screenshot, .readText, .getTitle, .getCurrentURL, .extractLinks, .extractText:
            return .safe

        // Moderate operations (non-destructive writes)
        case .navigate, .click, .scroll, .fillField:
            return .moderate

        // High-impact operations (file operations, payments)
        case .submitForm, .uploadFile, .downloadFile:
            return .high

        // Critical operations (system changes, deletions)
        case .deleteFile, .modifySystemSettings, .executeScript:
            return .critical

        // Custom actions evaluated by pattern matching
        case .custom(let name, let parameters):
            return evaluateCustomAction(name: name, parameters: parameters)
        }
    }

    /// Evaluate custom action consequence level
    private func evaluateCustomAction(name: String, parameters: [String: String]) -> ConsequenceLevel {
        let lowercaseName = name.lowercased()

        // Critical patterns
        if lowercaseName.contains("delete") ||
           lowercaseName.contains("remove") ||
           lowercaseName.contains("destroy") ||
           lowercaseName.contains("system") {
            return .critical
        }

        // High patterns
        if lowercaseName.contains("payment") ||
           lowercaseName.contains("purchase") ||
           lowercaseName.contains("transfer") ||
           lowercaseName.contains("file") {
            return .high
        }

        // Moderate patterns
        if lowercaseName.contains("write") ||
           lowercaseName.contains("update") ||
           lowercaseName.contains("modify") {
            return .moderate
        }

        // Default to safe
        return .safe
    }

    // MARK: - Permission Management

    /// Grant permission for a specific action
    public func grantPermission(for action: AutomationAction) {
        permissionCache[action.identifier] = .allowed(reason: "User granted permission")
    }

    /// Deny permission for a specific action
    public func denyPermission(for action: AutomationAction) {
        permissionCache[action.identifier] = .denied(reason: "User denied permission")
    }

    /// Revoke all cached permissions
    public func revokeAllPermissions() {
        permissionCache.removeAll()
    }

    /// Update user preferences
    public func updatePreferences(_ preferences: UserPermissionPreferences) {
        self.userPreferences = preferences
        // Clear cache when preferences change
        permissionCache.removeAll()
    }

    // MARK: - Permission History

    /// Get all cached permission decisions
    public func getPermissionHistory() -> [String: PermissionDecision] {
        return permissionCache
    }
}

// MARK: - Supporting Types

/// Automation action types
public enum AutomationAction: Sendable {
    // Navigation
    case navigate(url: String)
    case screenshot
    case getCurrentURL

    // Reading
    case readText(selector: String)
    case extractText(selector: String)
    case extractLinks
    case getTitle

    // Interaction
    case click(selector: String)
    case scroll(direction: String)
    case fillField(selector: String, value: String)
    case submitForm(selector: String)

    // File operations
    case uploadFile(path: String)
    case downloadFile(url: String)
    case deleteFile(path: String)

    // System operations
    case modifySystemSettings(setting: String)
    case executeScript(script: String)

    // Custom actions
    case custom(name: String, parameters: [String: String])

    var identifier: String {
        switch self {
        case .navigate(let url):
            return "navigate:\(url)"
        case .screenshot:
            return "screenshot"
        case .getCurrentURL:
            return "getCurrentURL"
        case .readText(let selector):
            return "readText:\(selector)"
        case .extractText(let selector):
            return "extractText:\(selector)"
        case .extractLinks:
            return "extractLinks"
        case .getTitle:
            return "getTitle"
        case .click(let selector):
            return "click:\(selector)"
        case .scroll(let direction):
            return "scroll:\(direction)"
        case .fillField(let selector, _):
            return "fillField:\(selector)"
        case .submitForm(let selector):
            return "submitForm:\(selector)"
        case .uploadFile(let path):
            return "uploadFile:\(path)"
        case .downloadFile(let url):
            return "downloadFile:\(url)"
        case .deleteFile(let path):
            return "deleteFile:\(path)"
        case .modifySystemSettings(let setting):
            return "modifySystemSettings:\(setting)"
        case .executeScript:
            return "executeScript"
        case .custom(let name, _):
            return "custom:\(name)"
        }
    }
}

/// Consequence level of an automation action
public enum ConsequenceLevel: Int, Sendable, Comparable {
    case safe = 0          // Read-only operations
    case moderate = 1      // Non-destructive writes
    case high = 2          // File operations, payments
    case critical = 3      // System changes, deletions

    public static func < (lhs: ConsequenceLevel, rhs: ConsequenceLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var description: String {
        switch self {
        case .safe:
            return "Safe (read-only)"
        case .moderate:
            return "Moderate (non-destructive)"
        case .high:
            return "High (file operations, payments)"
        case .critical:
            return "Critical (system changes, deletions)"
        }
    }

    public var icon: String {
        switch self {
        case .safe:
            return "checkmark.shield.fill"
        case .moderate:
            return "exclamationmark.shield.fill"
        case .high:
            return "exclamationmark.triangle.fill"
        case .critical:
            return "xmark.octagon.fill"
        }
    }
}

/// Permission decision
public enum PermissionDecision: Sendable {
    case allowed(reason: String)
    case denied(reason: String)
    case requiresConfirmation(action: AutomationAction, consequence: ConsequenceLevel, reason: String)

    public var isAllowed: Bool {
        if case .allowed = self {
            return true
        }
        return false
    }

    public var isDenied: Bool {
        if case .denied = self {
            return true
        }
        return false
    }

    public var requiresUserConfirmation: Bool {
        if case .requiresConfirmation = self {
            return true
        }
        return false
    }
}

/// User permission preferences
public struct UserPermissionPreferences: Sendable, Codable {
    /// Automatically approve moderate-consequence actions
    public var autoApproveModerate: Bool

    /// Automatically approve high-consequence actions (not recommended)
    public var autoApproveHigh: Bool

    /// Require confirmation for safe actions (paranoid mode)
    public var requireConfirmationForSafe: Bool

    /// Log all permission requests
    public var logAllRequests: Bool

    public init(
        autoApproveModerate: Bool = false,
        autoApproveHigh: Bool = false,
        requireConfirmationForSafe: Bool = false,
        logAllRequests: Bool = true
    ) {
        self.autoApproveModerate = autoApproveModerate
        self.autoApproveHigh = autoApproveHigh
        self.requireConfirmationForSafe = requireConfirmationForSafe
        self.logAllRequests = logAllRequests
    }

    public static let `default` = UserPermissionPreferences()

    /// Paranoid mode (require confirmation for everything)
    public static let paranoid = UserPermissionPreferences(
        autoApproveModerate: false,
        autoApproveHigh: false,
        requireConfirmationForSafe: true,
        logAllRequests: true
    )

    /// Relaxed mode (auto-approve moderate actions)
    public static let relaxed = UserPermissionPreferences(
        autoApproveModerate: true,
        autoApproveHigh: false,
        requireConfirmationForSafe: false,
        logAllRequests: true
    )
}

// MARK: - Permission Errors

public enum PermissionError: Error, LocalizedError, Sendable {
    case permissionDenied(action: String, reason: String)
    case requiresUserConfirmation(action: String, consequence: ConsequenceLevel)

    public var errorDescription: String? {
        switch self {
        case .permissionDenied(let action, let reason):
            return "Permission denied for \(action): \(reason)"
        case .requiresUserConfirmation(let action, let consequence):
            return "User confirmation required for \(action) (\(consequence.description))"
        }
    }
}
