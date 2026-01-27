// AgentSecPolicy.swift
// Central policy model for AgentSec Strict Mode
// Part of FINDING remediation from security audit

import Foundation
import OSLog

// MARK: - AgentSec Policy

/// Central policy configuration for AgentSec Strict Mode
/// This policy enforces security invariants across all agent operations
@MainActor
public final class AgentSecPolicy: ObservableObject {
    public static let shared = AgentSecPolicy()

    private let logger = Logger(subsystem: "com.thea.app", category: "AgentSecPolicy")

    // MARK: - Published State

    @Published public private(set) var isStrictModeEnabled: Bool = true
    @Published public private(set) var lastViolation: SecurityViolation?
    @Published public private(set) var violationCount: Int = 0

    // MARK: - Policy Configuration

    /// Network security policy
    public var network: NetworkPolicy = .strict

    /// Filesystem security policy
    public var filesystem: FilesystemPolicy = .strict

    /// Terminal command execution policy
    public var terminal: TerminalPolicy = .strict

    /// Human approval requirements
    public var approval: ApprovalPolicy = .strict

    /// Kill switch configuration
    public var killSwitch: KillSwitchPolicy = .strict

    // MARK: - Initialization

    private init() {
        loadPolicy()
    }

    // MARK: - Policy Management

    /// Enable strict mode (recommended for production)
    public func enableStrictMode() {
        isStrictModeEnabled = true
        network = .strict
        filesystem = .strict
        terminal = .strict
        approval = .strict
        killSwitch = .strict
        logger.info("AgentSec Strict Mode enabled")
    }

    /// Disable strict mode (for development only)
    public func disableStrictMode() {
        isStrictModeEnabled = false
        logger.warning("AgentSec Strict Mode disabled - security protections reduced")
    }

    /// Load policy from configuration file if available
    private func loadPolicy() {
        // Default to strict mode
        enableStrictMode()

        // Try to load custom policy from file
        #if os(macOS)
            let policyPath = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".thea")
                .appendingPathComponent("agentsec-policy.json")
        #else
            guard let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return
            }
            let policyPath = docDir
                .appendingPathComponent(".thea")
                .appendingPathComponent("agentsec-policy.json")
        #endif

        guard FileManager.default.fileExists(atPath: policyPath.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: policyPath)
            let decoder = JSONDecoder()
            let config = try decoder.decode(PolicyConfiguration.self, from: data)

            // Apply configuration
            network = config.network
            filesystem = config.filesystem
            terminal = config.terminal
            approval = config.approval
            killSwitch = config.killSwitch
            isStrictModeEnabled = config.strictModeEnabled

            logger.info("Loaded AgentSec policy from \(policyPath.path)")
        } catch {
            logger.error("Failed to load policy: \(error.localizedDescription)")
        }
    }

    /// Record a security violation
    public func recordViolation(_ violation: SecurityViolation) {
        lastViolation = violation
        violationCount += 1
        logger.warning("Security violation: \(violation.description)")

        // Check if kill switch should trigger
        if killSwitch.enabled, violation.severity == .critical, killSwitch.triggerOnCritical {
            AgentSecKillSwitch.shared.trigger(reason: violation.description)
        }
    }
}

// MARK: - Network Policy

/// Network security policy configuration
public struct NetworkPolicy: Codable, Sendable {
    /// Hosts that should be blocked
    public var blockedHosts: [String]

    /// Whether to allow external requests
    public var allowExternalRequests: Bool

    /// Maximum request timeout in seconds
    public var maxRequestTimeout: Int

    public static var strict: NetworkPolicy {
        NetworkPolicy(
            blockedHosts: [
                "localhost",
                "127.0.0.1",
                "::1",
                "0.0.0.0",
                "169.254.169.254", // AWS metadata
                "metadata.google.internal", // GCP metadata
                "169.254.170.2", // ECS metadata
                "[fd00:ec2::254]" // AWS IPv6 metadata
            ],
            allowExternalRequests: true,
            maxRequestTimeout: 30
        )
    }

    /// Check if a host is blocked
    public func isHostBlocked(_ host: String) -> Bool {
        let lowercaseHost = host.lowercased()

        for blocked in blockedHosts {
            if blocked.contains("*") {
                // Wildcard matching
                let pattern = blocked.replacingOccurrences(of: "*", with: ".*")
                if let regex = try? NSRegularExpression(pattern: "^\(pattern)$", options: []) {
                    let range = NSRange(lowercaseHost.startIndex..., in: lowercaseHost)
                    if regex.firstMatch(in: lowercaseHost, options: [], range: range) != nil {
                        return true
                    }
                }
            } else if lowercaseHost == blocked.lowercased() || lowercaseHost.contains(blocked.lowercased()) {
                return true
            }
        }

        // Block private IP ranges
        if isPrivateIP(host) {
            return true
        }

        return false
    }

    /// Check if an IP address is in a private range
    private func isPrivateIP(_ host: String) -> Bool {
        // Check for private IPv4 ranges
        if host.hasPrefix("10.") ||
            host.hasPrefix("192.168.") ||
            host.starts(with: "172.")
        {
            // Check 172.16-31.x.x range
            if host.hasPrefix("172.") {
                let components = host.split(separator: ".")
                if components.count >= 2,
                   let second = Int(components[1]),
                   second >= 16, second <= 31
                {
                    return true
                }
            }
            return true
        }

        return false
    }
}

// MARK: - Filesystem Policy

/// Filesystem security policy configuration
public struct FilesystemPolicy: Codable, Sendable {
    /// Paths that should never be written to
    public var blockedPaths: [String]

    /// Paths that are allowed for writing (empty = workspace only)
    public var allowedWritePaths: [String]

    /// Whether to allow reading outside workspace
    public var allowExternalReads: Bool

    public static var strict: FilesystemPolicy {
        FilesystemPolicy(
            blockedPaths: [
                "/System",
                "/Library",
                "/private",
                "/var",
                "/etc",
                "/bin",
                "/sbin",
                "/usr",
                ".ssh",
                ".gnupg",
                ".aws",
                ".kube",
                ".config/gcloud",
                "Keychain",
                ".git/config",
                ".gitconfig"
            ],
            allowedWritePaths: [],
            allowExternalReads: false
        )
    }

    /// Check if a path is blocked for write operations
    public func isPathBlocked(_ path: String) -> Bool {
        let expandedPath = NSString(string: path).expandingTildeInPath

        for blocked in blockedPaths {
            if expandedPath.contains(blocked) {
                return true
            }
        }

        return false
    }

    /// Check if a path is within allowed write paths
    public func isWriteAllowed(_ path: String, workspace: String?) -> Bool {
        let expandedPath = NSString(string: path).expandingTildeInPath

        // Always block sensitive paths
        if isPathBlocked(expandedPath) {
            return false
        }

        // If we have a workspace, check if path is within it
        if let workspace {
            let expandedWorkspace = NSString(string: workspace).expandingTildeInPath
            return expandedPath.hasPrefix(expandedWorkspace)
        }

        // Check against allowed paths
        if allowedWritePaths.isEmpty {
            return false // No allowed paths = deny all external writes
        }

        for allowed in allowedWritePaths {
            let expandedAllowed = NSString(string: allowed).expandingTildeInPath
            if expandedPath.hasPrefix(expandedAllowed) {
                return true
            }
        }

        return false
    }
}

// MARK: - Terminal Policy

/// Terminal command execution policy configuration
public struct TerminalPolicy: Codable, Sendable {
    /// Command patterns that should be blocked
    public var blockedPatterns: [String]

    /// Commands that require explicit approval
    public var requireApprovalPatterns: [String]

    /// Maximum execution time in seconds
    public var maxExecutionTime: Int

    /// Whether to allow sudo commands
    public var allowSudo: Bool

    public static var strict: TerminalPolicy {
        TerminalPolicy(
            blockedPatterns: [
                "rm -rf /",
                "rm -rf /*",
                ":(){ :|:& };:", // Fork bomb
                "dd if=/dev/zero of=/dev/",
                "mkfs",
                "> /dev/sda",
                "chmod -R 777 /",
                "chown -R nobody /",
                "curl.*\\|.*sh",
                "curl.*\\|.*bash",
                "wget.*\\|.*bash",
                "wget.*\\|.*sh",
                "eval\\s*\\(",
                "nc\\s+-e",
                "bash\\s+-i.*>&",
                "/dev/tcp/"
            ],
            requireApprovalPatterns: [
                "sudo",
                "rm -r",
                "chmod",
                "chown",
                "kill",
                "pkill",
                "killall",
                "osascript",
                "shutdown",
                "reboot",
                "launchctl"
            ],
            maxExecutionTime: 120,
            allowSudo: false
        )
    }

    /// Check if a command is blocked
    public func isCommandBlocked(_ command: String) -> (blocked: Bool, reason: String?) {
        let lowercaseCommand = command.lowercased()

        // Check sudo first
        if !allowSudo, lowercaseCommand.hasPrefix("sudo ") {
            return (true, "Sudo commands are blocked by AgentSec policy")
        }

        // Check blocked patterns
        for pattern in blockedPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(command.startIndex..., in: command)
                if regex.firstMatch(in: command, options: [], range: range) != nil {
                    return (true, "Command matches blocked pattern: \(pattern)")
                }
            } else if lowercaseCommand.contains(pattern.lowercased()) {
                return (true, "Command contains blocked pattern: \(pattern)")
            }
        }

        return (false, nil)
    }

    /// Check if a command requires approval
    public func requiresApproval(_ command: String) -> Bool {
        let lowercaseCommand = command.lowercased()

        for pattern in requireApprovalPatterns {
            if lowercaseCommand.contains(pattern.lowercased()) {
                return true
            }
        }

        return false
    }
}

// MARK: - Approval Policy

/// Human approval requirements configuration
public struct ApprovalPolicy: Codable, Sendable {
    /// Types of operations that require approval
    public var requiredForTypes: [String]

    /// Whether to auto-approve low-risk operations
    public var autoApproveLowRisk: Bool

    /// Timeout for approval requests in seconds
    public var approvalTimeout: Int

    public static var strict: ApprovalPolicy {
        ApprovalPolicy(
            requiredForTypes: [
                "fileWrite",
                "fileDelete",
                "terminalExec",
                "networkRequest",
                "systemConfig",
                "processKill",
                "credentialAccess"
            ],
            autoApproveLowRisk: false,
            approvalTimeout: 300
        )
    }

    /// Check if approval is required for an operation type
    public func isApprovalRequired(for operationType: String) -> Bool {
        requiredForTypes.contains(operationType)
    }
}

// MARK: - Kill Switch Policy

/// Emergency kill switch configuration
public struct KillSwitchPolicy: Codable, Sendable {
    /// Whether kill switch is enabled
    public var enabled: Bool

    /// Whether to trigger on critical findings
    public var triggerOnCritical: Bool

    /// Whether to notify user on trigger
    public var notifyUser: Bool

    /// Whether to log to audit trail
    public var logToAudit: Bool

    public static var strict: KillSwitchPolicy {
        KillSwitchPolicy(
            enabled: true,
            triggerOnCritical: true,
            notifyUser: true,
            logToAudit: true
        )
    }
}

// MARK: - Policy Configuration (for file loading)

struct PolicyConfiguration: Codable {
    var strictModeEnabled: Bool
    var network: NetworkPolicy
    var filesystem: FilesystemPolicy
    var terminal: TerminalPolicy
    var approval: ApprovalPolicy
    var killSwitch: KillSwitchPolicy
}

// MARK: - Security Violation

/// Represents a security violation detected by AgentSec
public struct SecurityViolation: Sendable {
    public enum Severity: String, Sendable {
        case critical
        case high
        case medium
        case low
    }

    public enum ViolationType: String, Sendable {
        case networkBlocked
        case pathBlocked
        case commandBlocked
        case approvalBypassed
        case killSwitchTriggered
    }

    public let id: UUID
    public let type: ViolationType
    public let severity: Severity
    public let description: String
    public let timestamp: Date
    public let context: [String: String]

    public init(
        type: ViolationType,
        severity: Severity,
        description: String,
        context: [String: String] = [:]
    ) {
        id = UUID()
        self.type = type
        self.severity = severity
        self.description = description
        timestamp = Date()
        self.context = context
    }
}
