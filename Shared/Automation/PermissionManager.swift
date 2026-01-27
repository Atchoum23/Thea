import Foundation

/// Permission manager for automation safety
/// Implements a consequence-based permission system for automation actions
public actor PermissionManager {
    // MARK: - Properties

    private var permissionCache: [String: PermissionDecision] = [:]
    private var userPreferences: UserPermissionPreferences

    // MARK: - Initialization

    public init(preferences: UserPermissionPreferences = .default) {
        userPreferences = preferences
    }

    // MARK: - Permission Requests

    /// Request permission for an automation action
    public func requestPermission(for action: PermissionAutomationAction) async throws -> PermissionDecision {
        let actionKey = action.identifier

        // Check cache first
        if let cached = permissionCache[actionKey] {
            return cached
        }

        // Classify the action's consequence level
        let consequence = classifyConsequence(action)

        // Determine if permission is required based on user preferences
        let decision: PermissionDecision = switch consequence {
        case .safe:
            // Safe actions don't require permission
            .allowed(reason: "Safe read-only operation")

        case .moderate:
            if userPreferences.autoApproveModerate {
                .allowed(reason: "Auto-approved moderate action")
            } else {
                .requiresConfirmation(
                    action: action,
                    consequence: consequence,
                    reason: "Non-destructive write operation"
                )
            }

        case .high:
            .requiresConfirmation(
                action: action,
                consequence: consequence,
                reason: "High-impact operation (file changes, payments)"
            )

        case .critical:
            .requiresConfirmation(
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
    public func classifyConsequence(_ action: PermissionAutomationAction) -> ConsequenceLevel {
        switch action {
        // Safe operations (read-only)
        case .screenshot, .readText, .getTitle, .getCurrentURL, .extractLinks, .extractText:
            .safe

        // Moderate operations (non-destructive writes)
        case .navigate, .click, .scroll, .fillField:
            .moderate

        // High-impact operations (file operations, payments)
        case .submitForm, .uploadFile, .downloadFile:
            .high

        // Critical operations (system changes, deletions)
        case .deleteFile, .modifySystemSettings, .executeScript:
            .critical

        // Custom actions evaluated by pattern matching
        case let .custom(name, parameters):
            evaluateCustomAction(name: name, parameters: parameters)
        }
    }

    /// Evaluate custom action consequence level
    private func evaluateCustomAction(name: String, parameters _: [String: String]) -> ConsequenceLevel {
        let lowercaseName = name.lowercased()

        // Critical patterns
        if lowercaseName.contains("delete") ||
            lowercaseName.contains("remove") ||
            lowercaseName.contains("destroy") ||
            lowercaseName.contains("system")
        {
            return .critical
        }

        // High patterns
        if lowercaseName.contains("payment") ||
            lowercaseName.contains("purchase") ||
            lowercaseName.contains("transfer") ||
            lowercaseName.contains("file")
        {
            return .high
        }

        // Moderate patterns
        if lowercaseName.contains("write") ||
            lowercaseName.contains("update") ||
            lowercaseName.contains("modify")
        {
            return .moderate
        }

        // Default to safe
        return .safe
    }

    // MARK: - Permission Management

    /// Grant permission for a specific action
    public func grantPermission(for action: PermissionAutomationAction) {
        permissionCache[action.identifier] = .allowed(reason: "User granted permission")
    }

    /// Deny permission for a specific action
    public func denyPermission(for action: PermissionAutomationAction) {
        permissionCache[action.identifier] = .denied(reason: "User denied permission")
    }

    /// Revoke all cached permissions
    public func revokeAllPermissions() {
        permissionCache.removeAll()
    }

    /// Update user preferences
    public func updatePreferences(_ preferences: UserPermissionPreferences) {
        userPreferences = preferences
        // Clear cache when preferences change
        permissionCache.removeAll()
    }

    // MARK: - Permission History

    /// Get all cached permission decisions
    public func getPermissionHistory() -> [String: PermissionDecision] {
        permissionCache
    }
}

// MARK: - Supporting Types

/// Automation action types
public enum PermissionAutomationAction: Sendable {
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
        case let .navigate(url):
            "navigate:\(url)"
        case .screenshot:
            "screenshot"
        case .getCurrentURL:
            "getCurrentURL"
        case let .readText(selector):
            "readText:\(selector)"
        case let .extractText(selector):
            "extractText:\(selector)"
        case .extractLinks:
            "extractLinks"
        case .getTitle:
            "getTitle"
        case let .click(selector):
            "click:\(selector)"
        case let .scroll(direction):
            "scroll:\(direction)"
        case let .fillField(selector, _):
            "fillField:\(selector)"
        case let .submitForm(selector):
            "submitForm:\(selector)"
        case let .uploadFile(path):
            "uploadFile:\(path)"
        case let .downloadFile(url):
            "downloadFile:\(url)"
        case let .deleteFile(path):
            "deleteFile:\(path)"
        case let .modifySystemSettings(setting):
            "modifySystemSettings:\(setting)"
        case .executeScript:
            "executeScript"
        case let .custom(name, _):
            "custom:\(name)"
        }
    }
}

/// Consequence level of an automation action
public enum ConsequenceLevel: Int, Sendable, Comparable {
    case safe = 0 // Read-only operations
    case moderate = 1 // Non-destructive writes
    case high = 2 // File operations, payments
    case critical = 3 // System changes, deletions

    public static func < (lhs: ConsequenceLevel, rhs: ConsequenceLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var description: String {
        switch self {
        case .safe:
            "Safe (read-only)"
        case .moderate:
            "Moderate (non-destructive)"
        case .high:
            "High (file operations, payments)"
        case .critical:
            "Critical (system changes, deletions)"
        }
    }

    public var icon: String {
        switch self {
        case .safe:
            "checkmark.shield.fill"
        case .moderate:
            "exclamationmark.shield.fill"
        case .high:
            "exclamationmark.triangle.fill"
        case .critical:
            "xmark.octagon.fill"
        }
    }
}

/// Permission decision
public enum PermissionDecision: Sendable {
    case allowed(reason: String)
    case denied(reason: String)
    case requiresConfirmation(action: PermissionAutomationAction, consequence: ConsequenceLevel, reason: String)

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
        case let .permissionDenied(action, reason):
            "Permission denied for \(action): \(reason)"
        case let .requiresUserConfirmation(action, consequence):
            "User confirmation required for \(action) (\(consequence.description))"
        }
    }
}
