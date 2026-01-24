// AgentSecPolicy.swift
// AgentSec Strict Mode policy model

import Foundation

/// Policy templates
enum PolicyTemplate: String, Codable, CaseIterable {
    case strict
    case standard
    case permissive
}

/// AgentSec Strict Mode policy configuration
struct AgentSecPolicy: Codable, Sendable {
    var network: NetworkPolicy
    var filesystem: FilesystemPolicy
    var terminal: TerminalPolicy
    var approval: ApprovalPolicy
    var killSwitch: KillSwitchPolicy

    /// Network security policy
    struct NetworkPolicy: Codable, Sendable {
        /// Hosts that should be blocked (localhost, metadata endpoints, internal IPs)
        var blockedHosts: [String]

        /// Whether to allow all external requests
        var allowExternalRequests: Bool

        /// Maximum request timeout in seconds
        var maxRequestTimeout: Int

        static var strict: NetworkPolicy {
            NetworkPolicy(
                blockedHosts: [
                    "localhost",
                    "127.0.0.1",
                    "::1",
                    "0.0.0.0",
                    "169.254.169.254",           // AWS metadata
                    "metadata.google.internal",   // GCP metadata
                    "169.254.170.2",             // ECS metadata
                    "10.*",                      // Private Class A
                    "172.16.*",                  // Private Class B
                    "172.17.*",
                    "172.18.*",
                    "172.19.*",
                    "172.20.*",
                    "172.21.*",
                    "172.22.*",
                    "172.23.*",
                    "172.24.*",
                    "172.25.*",
                    "172.26.*",
                    "172.27.*",
                    "172.28.*",
                    "172.29.*",
                    "172.30.*",
                    "172.31.*",
                    "192.168.*"                  // Private Class C
                ],
                allowExternalRequests: true,
                maxRequestTimeout: 30
            )
        }
    }

    /// Filesystem security policy
    struct FilesystemPolicy: Codable, Sendable {
        /// Paths that should never be written to
        var blockedPaths: [String]

        /// Paths that are allowed for writing (empty = workspace only)
        var allowedWritePaths: [String]

        /// Whether to allow reading outside workspace
        var allowExternalReads: Bool

        static var strict: FilesystemPolicy {
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
                    ".config",
                    "Keychain",
                    ".git/config",
                    ".gitconfig"
                ],
                allowedWritePaths: [],
                allowExternalReads: false
            )
        }
    }

    /// Terminal command execution policy
    struct TerminalPolicy: Codable, Sendable {
        /// Command patterns that should be blocked
        var blockedPatterns: [String]

        /// Commands that require explicit approval
        var requireApprovalPatterns: [String]

        /// Maximum execution time in seconds
        var maxExecutionTime: Int

        /// Whether to allow sudo commands
        var allowSudo: Bool

        static var strict: TerminalPolicy {
            TerminalPolicy(
                blockedPatterns: [
                    "rm -rf /",
                    "rm -rf /*",
                    "rm -rf ~",
                    ":(){ :|:& };:",              // Fork bomb
                    "dd if=/dev/zero of=/dev/",
                    "mkfs",
                    "> /dev/sda",
                    "chmod -R 777 /",
                    "chown -R nobody /",
                    "curl.*\\|.*sh",              // Remote code execution
                    "wget.*\\|.*bash",
                    "curl.*\\|.*python",
                    "\\|\\s*base64\\s+-d\\s*\\|",
                    "eval\\s*\\(",
                    "nc\\s+-e",                   // Netcat reverse shell
                    "bash\\s+-i.*>&",             // Bash reverse shell
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
                    "reboot"
                ],
                maxExecutionTime: 120,
                allowSudo: false
            )
        }
    }

    /// Human approval requirements
    struct ApprovalPolicy: Codable, Sendable {
        /// Types of operations that require approval
        var requiredForTypes: [String]

        /// Whether to auto-approve low-risk operations
        var autoApproveLowRisk: Bool

        /// Timeout for approval requests in seconds
        var approvalTimeout: Int

        static var strict: ApprovalPolicy {
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
    }

    /// Emergency kill switch settings
    struct KillSwitchPolicy: Codable, Sendable {
        /// Whether kill switch is enabled
        var enabled: Bool

        /// Whether to trigger on critical findings
        var triggerOnCritical: Bool

        /// Whether to notify user on trigger
        var notifyUser: Bool

        /// Whether to log to audit trail
        var logToAudit: Bool

        static var strict: KillSwitchPolicy {
            KillSwitchPolicy(
                enabled: true,
                triggerOnCritical: true,
                notifyUser: true,
                logToAudit: true
            )
        }
    }

    /// Validate the policy and return any issues
    func validate() -> [String] {
        var issues: [String] = []

        // Network validation
        if network.blockedHosts.isEmpty {
            issues.append("Network: No blocked hosts configured - metadata endpoints may be accessible")
        }

        // Filesystem validation
        if filesystem.blockedPaths.isEmpty {
            issues.append("Filesystem: No blocked paths configured - system files may be writable")
        }

        // Terminal validation
        if terminal.blockedPatterns.isEmpty {
            issues.append("Terminal: No blocked patterns configured - dangerous commands may execute")
        }

        if terminal.allowSudo {
            issues.append("Terminal: Sudo is allowed - elevated privileges may be exploited")
        }

        // Approval validation
        if approval.requiredForTypes.isEmpty {
            issues.append("Approval: No approval requirements configured - all operations auto-approved")
        }

        // Kill switch validation
        if !killSwitch.enabled {
            issues.append("KillSwitch: Kill switch is disabled - critical violations won't halt execution")
        }

        return issues
    }

    /// Create a policy from a template
    static func template(_ template: PolicyTemplate) -> AgentSecPolicy {
        switch template {
        case .strict:
            return AgentSecPolicy(
                network: .strict,
                filesystem: .strict,
                terminal: .strict,
                approval: .strict,
                killSwitch: .strict
            )

        case .standard:
            var policy = AgentSecPolicy(
                network: .strict,
                filesystem: .strict,
                terminal: .strict,
                approval: .strict,
                killSwitch: .strict
            )
            policy.approval.autoApproveLowRisk = true
            policy.terminal.maxExecutionTime = 300
            return policy

        case .permissive:
            return AgentSecPolicy(
                network: NetworkPolicy(
                    blockedHosts: ["169.254.169.254", "metadata.google.internal"],
                    allowExternalRequests: true,
                    maxRequestTimeout: 60
                ),
                filesystem: FilesystemPolicy(
                    blockedPaths: ["/System", "/Library", ".ssh", ".gnupg"],
                    allowedWritePaths: [],
                    allowExternalReads: true
                ),
                terminal: TerminalPolicy(
                    blockedPatterns: [":(){ :|:& };:", "rm -rf /"],
                    requireApprovalPatterns: ["sudo"],
                    maxExecutionTime: 600,
                    allowSudo: false
                ),
                approval: ApprovalPolicy(
                    requiredForTypes: ["systemConfig", "credentialAccess"],
                    autoApproveLowRisk: true,
                    approvalTimeout: 60
                ),
                killSwitch: KillSwitchPolicy(
                    enabled: true,
                    triggerOnCritical: true,
                    notifyUser: true,
                    logToAudit: true
                )
            )
        }
    }
}
