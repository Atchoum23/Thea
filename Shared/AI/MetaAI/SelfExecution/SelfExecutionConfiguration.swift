// SelfExecutionConfiguration.swift
import Foundation
import SwiftUI

/// Configuration for Thea's self-execution engine.
/// All settings are persisted to UserDefaults and can be changed in Settings.
public struct SelfExecutionConfiguration: Codable, Sendable {
    // MARK: - Provider Configuration

    /// Ordered list of AI providers to try (first available is used)
    public var providerPriority: [AIProvider] = [.openRouter, .anthropic, .openAI, .local]

    /// Preferred model for code generation (per provider)
    public var preferredModels: [AIProvider: String] = [
        .anthropic: "claude-sonnet-4-20250514",
        .openAI: "gpt-4o",
        .openRouter: "anthropic/claude-sonnet-4",
        .local: "deepseek-coder-v2"
    ]

    public enum AIProvider: String, Codable, CaseIterable, Sendable {
        case anthropic = "Anthropic (Claude)"
        case openAI = "OpenAI (GPT-4)"
        case openRouter = "OpenRouter"
        case local = "Local MLX"

        public var keyName: String {
            switch self {
            case .anthropic: return "anthropic_api_key"
            case .openAI: return "openai_api_key"
            case .openRouter: return "openrouter_api_key"
            case .local: return "local_models_path"
            }
        }
    }

    // MARK: - Approval Configuration

    /// Approval mode for phase execution
    public var approvalMode: ApprovalMode = .supervised

    public enum ApprovalMode: String, Codable, CaseIterable, Sendable {
        case supervised = "Supervised"
        case alwaysAllow = "Always Allow"
        case dryRun = "Dry Run"

        public var description: String {
            switch self {
            case .supervised:
                return "Approval required at phase start/end and for risky operations"
            case .alwaysAllow:
                return "Execute all phases without interruption (⚠️ Use with caution)"
            case .dryRun:
                return "Simulate execution without making changes"
            }
        }
    }

    /// Specific permissions that can be individually granted
    public var grantedPermissions: Set<Permission> = []

    public enum Permission: String, Codable, CaseIterable, Sendable {
        case createFiles = "Create new files"
        case editFiles = "Edit existing files"
        case deleteFiles = "Delete files"
        case runBuild = "Run xcodebuild"
        case applyFixes = "Apply AI-generated fixes"
        case createDMG = "Create DMG releases"
        case modifySpec = "Update THEA_MASTER_SPEC.md"
        case gitOperations = "Git commit/rollback"
        case preventSleep = "Prevent system sleep"
        case executeNextPhase = "Auto-start next phase"
    }

    /// Grant all permissions at once ("Always Allow" helper)
    public mutating func grantAllPermissions() {
        grantedPermissions = Set(Permission.allCases)
        approvalMode = .alwaysAllow
    }

    /// Revoke all permissions (return to supervised mode)
    public mutating func revokeAllPermissions() {
        grantedPermissions = []
        approvalMode = .supervised
    }

    // MARK: - Execution Configuration

    /// Prevent system/display sleep during phase execution
    public var preventSleepDuringExecution: Bool = true

    /// Maximum iterations for autonomous build loop
    public var maxBuildIterations: Int = 15

    /// Auto-continue to next phase after successful completion
    public var autoContinueToNextPhase: Bool = false

    /// Phases to execute in batch (when autoContinue is enabled)
    public var batchPhaseRange: ClosedRange<Int>?

    // MARK: - Progress Tracking Configuration

    /// Update THEA_MASTER_SPEC.md with progress (recommended)
    public var updateSpecFileWithProgress: Bool = true

    /// Also track progress in SwiftData (for UI and crash recovery)
    public var trackProgressInSwiftData: Bool = true

    /// Backup progress to JSON file (belt and suspenders)
    public var backupProgressToJSON: Bool = true

    // MARK: - Persistence

    private static let storageKey = "com.thea.selfexecution.configuration"

    public static func load() -> SelfExecutionConfiguration {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let config = try? JSONDecoder().decode(SelfExecutionConfiguration.self, from: data) else {
            return SelfExecutionConfiguration()
        }
        return config
    }

    public func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    // MARK: - Convenience

    public func hasPermission(_ permission: Permission) -> Bool {
        approvalMode == .alwaysAllow || grantedPermissions.contains(permission)
    }

    public func getConfiguredProviders() -> [AIProvider] {
        providerPriority.filter { provider in
            let key = UserDefaults.standard.string(forKey: provider.keyName) ?? ""
            return !key.isEmpty
        }
    }

    public func getPrimaryProvider() -> AIProvider? {
        getConfiguredProviders().first
    }
}
