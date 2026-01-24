// PolicyTests.swift
// Tests for AgentSec policy

import XCTest
@testable import thea_audit

final class PolicyTests: XCTestCase {

    // MARK: - Policy Template Tests

    func testStrictPolicyTemplate() {
        let policy = AgentSecPolicy.template(.strict)

        // Network
        XCTAssertFalse(policy.network.blockedHosts.isEmpty)
        XCTAssertTrue(policy.network.blockedHosts.contains("localhost"))
        XCTAssertTrue(policy.network.blockedHosts.contains("169.254.169.254"))

        // Filesystem
        XCTAssertFalse(policy.filesystem.blockedPaths.isEmpty)
        XCTAssertTrue(policy.filesystem.blockedPaths.contains("/System"))
        XCTAssertTrue(policy.filesystem.blockedPaths.contains(".ssh"))

        // Terminal
        XCTAssertFalse(policy.terminal.blockedPatterns.isEmpty)
        XCTAssertFalse(policy.terminal.allowSudo)

        // Approval
        XCTAssertFalse(policy.approval.requiredForTypes.isEmpty)
        XCTAssertFalse(policy.approval.autoApproveLowRisk)

        // Kill Switch
        XCTAssertTrue(policy.killSwitch.enabled)
        XCTAssertTrue(policy.killSwitch.triggerOnCritical)
    }

    func testPermissivePolicyTemplate() {
        let policy = AgentSecPolicy.template(.permissive)

        // Less restrictive
        XCTAssertTrue(policy.network.blockedHosts.count < AgentSecPolicy.template(.strict).network.blockedHosts.count)
        XCTAssertTrue(policy.approval.autoApproveLowRisk)
        XCTAssertTrue(policy.terminal.maxExecutionTime > 120)
    }

    // MARK: - Policy Validation Tests

    func testStrictPolicyValidation() {
        let policy = AgentSecPolicy.template(.strict)
        let issues = policy.validate()

        // Strict policy should have no validation issues
        XCTAssertTrue(issues.isEmpty, "Strict policy should have no issues: \(issues)")
    }

    func testEmptyPolicyValidation() {
        let policy = AgentSecPolicy(
            network: AgentSecPolicy.NetworkPolicy(
                blockedHosts: [],
                allowExternalRequests: true,
                maxRequestTimeout: 30
            ),
            filesystem: AgentSecPolicy.FilesystemPolicy(
                blockedPaths: [],
                allowedWritePaths: [],
                allowExternalReads: true
            ),
            terminal: AgentSecPolicy.TerminalPolicy(
                blockedPatterns: [],
                requireApprovalPatterns: [],
                maxExecutionTime: 120,
                allowSudo: true
            ),
            approval: AgentSecPolicy.ApprovalPolicy(
                requiredForTypes: [],
                autoApproveLowRisk: true,
                approvalTimeout: 300
            ),
            killSwitch: AgentSecPolicy.KillSwitchPolicy(
                enabled: false,
                triggerOnCritical: false,
                notifyUser: false,
                logToAudit: false
            )
        )

        let issues = policy.validate()

        // Empty/permissive policy should have multiple issues
        XCTAssertFalse(issues.isEmpty)
        XCTAssertTrue(issues.contains { $0.contains("Network") })
        XCTAssertTrue(issues.contains { $0.contains("Filesystem") })
        XCTAssertTrue(issues.contains { $0.contains("Terminal") })
        XCTAssertTrue(issues.contains { $0.contains("Approval") })
        XCTAssertTrue(issues.contains { $0.contains("KillSwitch") })
    }

    // MARK: - Policy Evaluation Tests

    func testPolicyEvaluatorCompliant() throws {
        let policy = AgentSecPolicy.template(.strict)
        let evaluator = PolicyEvaluator(policy: policy)

        // No findings = compliant
        let result = try evaluator.evaluate(findings: [])

        XCTAssertTrue(result.compliant)
        XCTAssertTrue(result.violations.isEmpty)
        XCTAssertFalse(result.checkedInvariants.isEmpty)
    }

    func testPolicyEvaluatorWithCriticalFindings() throws {
        let policy = AgentSecPolicy.template(.strict)
        let evaluator = PolicyEvaluator(policy: policy)

        let findings = [
            Finding(
                ruleID: "terminal-001",
                severity: .critical,
                title: "Command Injection",
                description: "Unsafe command execution",
                file: "test.swift",
                recommendation: "Sanitize input",
                category: .injection
            )
        ]

        let result = try evaluator.evaluate(findings: findings)

        XCTAssertFalse(result.compliant)
        XCTAssertFalse(result.violations.isEmpty)
        XCTAssertTrue(result.violations.contains { $0.contains("Kill switch") })
    }

    // MARK: - Policy Encoding Tests

    func testPolicyEncodeDecode() throws {
        let original = AgentSecPolicy.template(.strict)

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AgentSecPolicy.self, from: data)

        XCTAssertEqual(original.network.blockedHosts.count, decoded.network.blockedHosts.count)
        XCTAssertEqual(original.filesystem.blockedPaths.count, decoded.filesystem.blockedPaths.count)
        XCTAssertEqual(original.terminal.allowSudo, decoded.terminal.allowSudo)
        XCTAssertEqual(original.killSwitch.enabled, decoded.killSwitch.enabled)
    }
}
