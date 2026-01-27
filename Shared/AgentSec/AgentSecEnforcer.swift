// AgentSecEnforcer.swift
// Runtime enforcement for AgentSec Strict Mode
// Integrates with tool execution choke points

import Foundation
import OSLog

// MARK: - AgentSec Enforcer

/// Runtime enforcer for AgentSec policies
/// Validates operations against policy before allowing execution
@MainActor
public final class AgentSecEnforcer: ObservableObject {
    public static let shared = AgentSecEnforcer()

    private let logger = Logger(subsystem: "com.thea.app", category: "AgentSecEnforcer")

    // MARK: - Published State

    @Published public private(set) var isEnforcementActive: Bool = true
    @Published public private(set) var lastEnforcementResult: EnforcementResult?

    // MARK: - Dependencies

    private var policy: AgentSecPolicy { AgentSecPolicy.shared }

    // MARK: - Initialization

    private init() {}

    // MARK: - Network Enforcement

    /// Validate a network request before execution
    /// - Parameters:
    ///   - url: The URL being requested
    ///   - method: HTTP method
    /// - Returns: EnforcementResult indicating if request is allowed
    public func validateNetworkRequest(url: URL, method: String = "GET") -> EnforcementResult {
        guard isEnforcementActive, policy.isStrictModeEnabled else {
            return .allowed
        }

        // Extract host from URL
        guard let host = url.host else {
            return .denied(reason: "Invalid URL: missing host")
        }

        // Check if host is blocked
        if policy.network.isHostBlocked(host) {
            let violation = SecurityViolation(
                type: .networkBlocked,
                severity: .critical,
                description: "Blocked network request to \(host)",
                context: ["url": url.absoluteString, "method": method]
            )
            policy.recordViolation(violation)

            logger.warning("BLOCKED: Network request to \(host)")
            lastEnforcementResult = .denied(reason: "Host '\(host)' is blocked by AgentSec policy")
            return lastEnforcementResult!
        }

        // Check for localhost variants
        if isLocalhostVariant(host) {
            let violation = SecurityViolation(
                type: .networkBlocked,
                severity: .critical,
                description: "Blocked request to localhost variant: \(host)",
                context: ["url": url.absoluteString]
            )
            policy.recordViolation(violation)

            logger.warning("BLOCKED: Request to localhost variant \(host)")
            lastEnforcementResult = .denied(reason: "Localhost requests are blocked by AgentSec policy")
            return lastEnforcementResult!
        }

        lastEnforcementResult = .allowed
        return .allowed
    }

    /// Check if a host is a localhost variant
    private func isLocalhostVariant(_ host: String) -> Bool {
        let localhostVariants = [
            "localhost",
            "127.0.0.1",
            "0.0.0.0",
            "::1",
            "[::1]",
            "localhost.localdomain",
            "local"
        ]

        return localhostVariants.contains { host.lowercased() == $0.lowercased() }
    }

    // MARK: - Filesystem Enforcement

    /// Validate a file write operation before execution
    /// - Parameters:
    ///   - path: The file path being written to
    ///   - workspace: Optional workspace directory for validation
    /// - Returns: EnforcementResult indicating if write is allowed
    public func validateFileWrite(path: String, workspace: String? = nil) -> EnforcementResult {
        guard isEnforcementActive, policy.isStrictModeEnabled else {
            return .allowed
        }

        let expandedPath = NSString(string: path).expandingTildeInPath

        // Check if path is blocked
        if policy.filesystem.isPathBlocked(expandedPath) {
            let violation = SecurityViolation(
                type: .pathBlocked,
                severity: .critical,
                description: "Blocked write to protected path: \(path)",
                context: ["path": expandedPath]
            )
            policy.recordViolation(violation)

            logger.warning("BLOCKED: File write to \(expandedPath)")
            lastEnforcementResult = .denied(reason: "Path '\(path)' is blocked by AgentSec policy")
            return lastEnforcementResult!
        }

        // Check if write is within allowed paths
        if !policy.filesystem.isWriteAllowed(expandedPath, workspace: workspace) {
            let violation = SecurityViolation(
                type: .pathBlocked,
                severity: .high,
                description: "File write outside allowed paths: \(path)",
                context: ["path": expandedPath, "workspace": workspace ?? "none"]
            )
            policy.recordViolation(violation)

            logger.warning("BLOCKED: File write outside workspace")
            lastEnforcementResult = .denied(reason: "File write outside workspace is blocked by AgentSec policy")
            return lastEnforcementResult!
        }

        lastEnforcementResult = .allowed
        return .allowed
    }

    /// Validate a file read operation
    public func validateFileRead(path: String, workspace _: String? = nil) -> EnforcementResult {
        guard isEnforcementActive, policy.isStrictModeEnabled else {
            return .allowed
        }

        let expandedPath = NSString(string: path).expandingTildeInPath

        // Check sensitive paths for read
        let sensitiveReadPaths = [".ssh", ".gnupg", ".aws", "Keychain"]
        for sensitive in sensitiveReadPaths {
            if expandedPath.contains(sensitive) {
                let violation = SecurityViolation(
                    type: .pathBlocked,
                    severity: .high,
                    description: "Blocked read from sensitive path: \(path)",
                    context: ["path": expandedPath]
                )
                policy.recordViolation(violation)

                logger.warning("BLOCKED: File read from sensitive path")
                lastEnforcementResult = .denied(reason: "Reading from sensitive paths is blocked")
                return lastEnforcementResult!
            }
        }

        lastEnforcementResult = .allowed
        return .allowed
    }

    // MARK: - Terminal Enforcement

    /// Validate a terminal command before execution
    /// - Parameter command: The command to validate
    /// - Returns: EnforcementResult indicating if command is allowed
    public func validateTerminalCommand(_ command: String) -> EnforcementResult {
        guard isEnforcementActive, policy.isStrictModeEnabled else {
            return .allowed
        }

        // Check if command is blocked
        let (blocked, reason) = policy.terminal.isCommandBlocked(command)
        if blocked {
            let violation = SecurityViolation(
                type: .commandBlocked,
                severity: .critical,
                description: reason ?? "Command blocked by policy",
                context: ["command": command]
            )
            policy.recordViolation(violation)

            logger.warning("BLOCKED: Terminal command")
            lastEnforcementResult = .denied(reason: reason ?? "Command blocked by AgentSec policy")
            return lastEnforcementResult!
        }

        // Check if command requires approval
        if policy.terminal.requiresApproval(command) {
            lastEnforcementResult = .requiresApproval(reason: "Command requires human approval")
            return lastEnforcementResult!
        }

        lastEnforcementResult = .allowed
        return .allowed
    }

    // MARK: - Approval Enforcement

    /// Check if an operation type requires approval
    public func requiresApproval(for operationType: String) -> Bool {
        guard policy.isStrictModeEnabled else {
            return false
        }

        return policy.approval.isApprovalRequired(for: operationType)
    }

    /// Validate that approval was obtained for an operation
    public func validateApproval(for operationType: String, wasApproved: Bool) -> EnforcementResult {
        guard isEnforcementActive, policy.isStrictModeEnabled else {
            return .allowed
        }

        if policy.approval.isApprovalRequired(for: operationType), !wasApproved {
            let violation = SecurityViolation(
                type: .approvalBypassed,
                severity: .high,
                description: "Operation executed without required approval: \(operationType)",
                context: ["operationType": operationType]
            )
            policy.recordViolation(violation)

            logger.warning("BLOCKED: Operation without approval")
            lastEnforcementResult = .denied(reason: "Human approval required for \(operationType)")
            return lastEnforcementResult!
        }

        lastEnforcementResult = .allowed
        return .allowed
    }

    // MARK: - Control Methods

    /// Temporarily suspend enforcement (for testing only)
    public func suspendEnforcement() {
        logger.warning("AgentSec enforcement suspended - use with caution")
        isEnforcementActive = false
    }

    /// Resume enforcement
    public func resumeEnforcement() {
        logger.info("AgentSec enforcement resumed")
        isEnforcementActive = true
    }
}

// MARK: - Enforcement Result

/// Result of an enforcement check
public enum EnforcementResult: Sendable, Equatable {
    case allowed
    case denied(reason: String)
    case requiresApproval(reason: String)

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

    public var requiresUserApproval: Bool {
        if case .requiresApproval = self {
            return true
        }
        return false
    }

    public var reason: String? {
        switch self {
        case .allowed:
            nil
        case let .denied(reason), let .requiresApproval(reason):
            reason
        }
    }
}
