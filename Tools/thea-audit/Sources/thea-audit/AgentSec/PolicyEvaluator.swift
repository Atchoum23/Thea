// PolicyEvaluator.swift
// Evaluates audit findings against AgentSec policy

import Foundation

/// Evaluates findings against an AgentSec policy
struct PolicyEvaluator {
    let policy: AgentSecPolicy

    init(policyPath: String) throws {
        let url = URL(fileURLWithPath: policyPath)
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        policy = try decoder.decode(AgentSecPolicy.self, from: data)
    }

    init(policy: AgentSecPolicy) {
        self.policy = policy
    }

    /// Evaluate findings against the policy
    func evaluate(findings: [Finding]) throws -> PolicyEvaluationResult {
        var violations: [String] = []
        var checkedInvariants: [String] = []

        // Check for network policy violations
        checkedInvariants.append("Network: Blocked hosts enforcement")
        let networkFindings = findings.filter { $0.category == .agentSecurity && $0.ruleID.contains("network") }
        for finding in networkFindings {
            if finding.severity >= .high {
                violations.append("Network policy violation: \(finding.title)")
            }
        }

        // Check for filesystem policy violations
        checkedInvariants.append("Filesystem: Blocked paths enforcement")
        let filesystemFindings = findings.filter { $0.category == .accessControl || $0.ruleID.contains("path") }
        for finding in filesystemFindings {
            if finding.severity >= .high {
                violations.append("Filesystem policy violation: \(finding.title)")
            }
        }

        // Check for terminal policy violations
        checkedInvariants.append("Terminal: Blocked patterns enforcement")
        let terminalFindings = findings.filter { $0.category == .injection || $0.ruleID.contains("terminal") }
        for finding in terminalFindings {
            if finding.severity >= .high {
                violations.append("Terminal policy violation: \(finding.title)")
            }
        }

        // Check for approval policy violations
        checkedInvariants.append("Approval: Human gate enforcement")
        let approvalFindings = findings.filter { $0.ruleID.contains("approval") }
        for finding in approvalFindings {
            if finding.severity >= .medium {
                violations.append("Approval policy violation: \(finding.title)")
            }
        }

        // Check for kill switch violations
        if policy.killSwitch.enabled, policy.killSwitch.triggerOnCritical {
            checkedInvariants.append("KillSwitch: Critical violation halt")
            let criticalFindings = findings.filter { $0.severity == .critical }
            if !criticalFindings.isEmpty {
                violations.append("Kill switch would trigger: \(criticalFindings.count) critical findings")
            }
        }

        // Determine compliance
        let compliant = violations.isEmpty

        return PolicyEvaluationResult(
            compliant: compliant,
            violations: violations,
            checkedInvariants: checkedInvariants,
            policy: policy
        )
    }
}

/// Result of policy evaluation
struct PolicyEvaluationResult: Codable, Sendable {
    let compliant: Bool
    let violations: [String]
    let checkedInvariants: [String]
    let policy: AgentSecPolicy
}
