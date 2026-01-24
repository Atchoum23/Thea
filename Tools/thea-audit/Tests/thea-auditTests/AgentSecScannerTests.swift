// AgentSecScannerTests.swift
// Tests for AgentSec Strict Mode scanner and invariant rules

import XCTest
@testable import thea_audit

final class AgentSecScannerTests: XCTestCase {

    // MARK: - Network Blocklist Tests

    func testNetworkBlocklistRule_MissingLocalhost() {
        let rule = NetworkBlocklistRule()
        let content = """
        let blockedHosts = [
            "127.0.0.1",
            "::1",
            "169.254.169.254"
        ]
        """

        let findings = rule.check(file: "test.swift", content: content)

        XCTAssertTrue(findings.contains { $0.evidence?.contains("localhost") == true },
                      "Should detect missing localhost")
    }

    func testNetworkBlocklistRule_MissingMetadataEndpoint() {
        let rule = NetworkBlocklistRule()
        let content = """
        let blockedHosts = [
            "localhost",
            "127.0.0.1",
            "::1"
        ]
        """

        let findings = rule.check(file: "test.swift", content: content)

        XCTAssertTrue(findings.contains { $0.evidence?.contains("169.254.169.254") == true },
                      "Should detect missing metadata endpoint")
    }

    func testNetworkBlocklistRule_HTTPWithoutValidation() {
        let rule = NetworkBlocklistRule()
        let content = """
        func makeRequest() {
            let session = URLSession.shared
            let request = URLRequest(url: url)
            session.dataTask(with: request)
        }
        """

        let findings = rule.check(file: "test.swift", content: content)

        XCTAssertTrue(findings.contains { $0.title.contains("Missing Network Validation") },
                      "Should detect HTTP code without validation")
    }

    func testNetworkBlocklistRule_HTTPWithValidation() {
        let rule = NetworkBlocklistRule()
        let content = """
        func makeRequest() {
            guard !AgentSecEnforcer.shared.validateNetworkRequest(url).isBlocked else { return }
            let session = URLSession.shared
            session.dataTask(with: request)
        }
        """

        let findings = rule.check(file: "test.swift", content: content)

        XCTAssertFalse(findings.contains { $0.title.contains("Missing Network Validation") },
                       "Should not flag when validation is present")
    }

    // MARK: - Filesystem Blocklist Tests

    func testFilesystemBlocklistRule_MissingSystemPaths() {
        let rule = FilesystemBlocklistRule()
        let content = """
        let blockedPaths = [
            ".ssh",
            ".gnupg"
        ]
        """

        let findings = rule.check(file: "test.swift", content: content)

        XCTAssertTrue(findings.contains { $0.evidence?.contains("/System") == true },
                      "Should detect missing /System path")
        XCTAssertTrue(findings.contains { $0.evidence?.contains("/Library") == true },
                      "Should detect missing /Library path")
    }

    func testFilesystemBlocklistRule_FileWriteWithoutValidation() {
        let rule = FilesystemBlocklistRule()
        let content = """
        func saveFile() {
            let data = "content".data(using: .utf8)
            try data?.write(toFile: path)
        }
        """

        let findings = rule.check(file: "test.swift", content: content)

        XCTAssertTrue(findings.contains { $0.title.contains("Missing Filesystem Validation") },
                      "Should detect file write without validation")
    }

    // MARK: - Terminal Blocklist Tests

    func testTerminalBlocklistRule_MissingDangerousPatterns() {
        let rule = TerminalBlocklistRule()
        let content = """
        let blockedPatterns = [
            "rm -rf /",
            "sudo"
        ]
        """

        let findings = rule.check(file: "test.swift", content: content)

        // Should detect missing fork bomb pattern
        XCTAssertTrue(findings.contains { $0.evidence?.contains(":(){ :|:& };:") == true },
                      "Should detect missing fork bomb pattern")
    }

    func testTerminalBlocklistRule_ProcessWithoutValidation() {
        let rule = TerminalBlocklistRule()
        let content = """
        func runCommand() {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.run()
        }
        """

        let findings = rule.check(file: "test.swift", content: content)

        XCTAssertTrue(findings.contains { $0.title.contains("Missing Terminal Validation") },
                      "Should detect process execution without validation")
    }

    func testTerminalBlocklistRule_ProcessWithValidation() {
        let rule = TerminalBlocklistRule()
        let content = """
        func runCommand() {
            guard TerminalSecurityPolicy.shared.isAllowed(command) else { return }
            let process = Process()
            process.run()
        }
        """

        let findings = rule.check(file: "test.swift", content: content)

        XCTAssertFalse(findings.contains { $0.title.contains("Missing Terminal Validation") },
                       "Should not flag when validation is present")
    }

    // MARK: - Approval Requirement Tests

    func testApprovalRequirementRule_AutoApproveDetection() {
        let rule = ApprovalRequirementRule()
        let content = """
        if !verboseMode {
            return ApprovalResponse(approved: true)
        }
        """

        let findings = rule.check(file: "test.swift", content: content)

        XCTAssertTrue(findings.contains { $0.title.contains("Auto-Approve") },
                      "Should detect auto-approve pattern")
    }

    func testApprovalRequirementRule_MissingRequiredTypes() {
        let rule = ApprovalRequirementRule()
        let content = """
        let requiredForTypes = [
            "fileWrite"
        ]
        """

        let findings = rule.check(file: "test.swift", content: content)

        XCTAssertTrue(findings.contains { $0.evidence?.contains("terminalExec") == true },
                      "Should detect missing terminalExec type")
        XCTAssertTrue(findings.contains { $0.evidence?.contains("networkRequest") == true },
                      "Should detect missing networkRequest type")
    }

    // MARK: - Kill Switch Tests

    func testKillSwitchRule_DisabledKillSwitch() {
        let rule = KillSwitchInvariantRule()
        let content = """
        struct KillSwitchPolicy {
            var enabled = false
        }
        """

        let findings = rule.check(file: "test.swift", content: content)

        XCTAssertTrue(findings.contains { $0.title.contains("Kill Switch Disabled") },
                      "Should detect disabled kill switch")
    }

    func testKillSwitchRule_DisabledTriggerOnCritical() {
        let rule = KillSwitchInvariantRule()
        let content = """
        let killSwitch = KillSwitchPolicy(
            enabled: true,
            triggerOnCritical = false
        )
        """

        let findings = rule.check(file: "test.swift", content: content)

        XCTAssertTrue(findings.contains { $0.title.contains("Won't Trigger on Critical") },
                      "Should detect disabled triggerOnCritical")
    }

    // MARK: - Scanner Integration Tests

    func testAgentSecScanner_FilePatternMatching() {
        let scanner = AgentSecScanner()

        // Should match AgentSec files
        XCTAssertTrue(scanner.filePatterns.contains { pattern in
            pattern.contains("AgentSec")
        })

        // Should match security policy files
        XCTAssertTrue(scanner.filePatterns.contains { pattern in
            pattern.contains("Security")
        })
    }

    func testAgentSecScanner_HasAllInvariantRules() {
        let scanner = AgentSecScanner()

        XCTAssertTrue(scanner.rules.contains { $0.id.contains("NET") },
                      "Should have network rule")
        XCTAssertTrue(scanner.rules.contains { $0.id.contains("FS") },
                      "Should have filesystem rule")
        XCTAssertTrue(scanner.rules.contains { $0.id.contains("TERM") },
                      "Should have terminal rule")
        XCTAssertTrue(scanner.rules.contains { $0.id.contains("APPROVE") },
                      "Should have approval rule")
        XCTAssertTrue(scanner.rules.contains { $0.id.contains("KILL") },
                      "Should have kill switch rule")
    }
}
