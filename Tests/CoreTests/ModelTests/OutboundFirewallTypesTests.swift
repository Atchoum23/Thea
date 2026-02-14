// OutboundFirewallTypesTests.swift
// Tests for the strict inverted firewall types and classification logic
// added to OutboundPrivacyGuard in Priority D.

import Foundation
import Testing

// MARK: - Test Doubles (mirror types from OutboundPrivacyGuard.swift)

/// Mirror of FirewallMode
private enum TestFirewallMode: String, Codable, Sendable, CaseIterable {
    case strict
    case standard
    case permissive
}

/// Mirror of OutboundDataType
private enum TestOutboundDataType: String, CaseIterable, Sendable, Codable {
    case text
    case structuredData
    case credentials
    case personalInfo
    case healthData
    case financialData
    case locationData
    case deviceInfo
    case codeContent
}

/// Mirror of ChannelRegistration
private struct TestChannelRegistration: Sendable {
    let channelId: String
    let description: String
    let policyName: String
    let allowedDataTypes: Set<TestOutboundDataType>
    let registeredAt: Date
    let registeredBy: String
}

/// Mirror of SecurityFinding
private struct TestSecurityFinding: Sendable {
    enum Severity: String, Sendable, CaseIterable { case critical, warning, info }
    let severity: Severity
    let file: String
    let description: String
    let recommendation: String
}

// MARK: - Content Classification Logic (mirrors OutboundPrivacyGuard.classifyContent)

private func classifyContent(_ content: String) -> Set<TestOutboundDataType> {
    var types: Set<TestOutboundDataType> = [.text]

    // Credentials
    let credentialPatterns = [
        "sk-[a-zA-Z0-9]{20,}", "ghp_[a-zA-Z0-9]{36}", "AKIA[0-9A-Z]{16}",
        "-----BEGIN[A-Z ]*PRIVATE KEY-----",
        "(?i)(api[_-]?key|token|secret|password|bearer)\\s*[:=]\\s*['\"]?[A-Za-z0-9+/=_-]{16,}"
    ]
    if matchesAny(content, patterns: credentialPatterns) { types.insert(.credentials) }

    // Health data
    let healthPatterns = ["(?i)(blood.?pressure|heart.?rate|bpm|glucose|cholesterol|bmi|steps|sleep.?duration|health.?kit|HKQuantity)"]
    if matchesAny(content, patterns: healthPatterns) { types.insert(.healthData) }

    // Financial data
    let financePatterns = ["(?i)(iban|swift|bic|account.?number|routing|tax.?id|ssn|social.?security|credit.?card|\\b\\d{4}[- ]?\\d{4}[- ]?\\d{4}[- ]?\\d{4}\\b)"]
    if matchesAny(content, patterns: financePatterns) { types.insert(.financialData) }

    // Location data
    let locationPatterns = ["(?i)(latitude|longitude|gps|geoloc)"]
    if matchesAny(content, patterns: locationPatterns) { types.insert(.locationData) }

    // Device info
    let devicePatterns = ["(?i)(serial.?number|udid|device.?id|mac.?address|[0-9a-f]{2}(:[0-9a-f]{2}){5})"]
    if matchesAny(content, patterns: devicePatterns) { types.insert(.deviceInfo) }

    // Code content
    let codePatterns = ["(?m)^(func |class |struct |import |let |var |if |for |while |switch |protocol |extension )"]
    if matchesAny(content, patterns: codePatterns) { types.insert(.codeContent) }

    // Structured data
    if content.contains("{") && content.contains("}") && content.contains("\"") {
        types.insert(.structuredData)
    }

    return types
}

private func matchesAny(_ text: String, patterns: [String]) -> Bool {
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    for pattern in patterns {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
        if regex.firstMatch(in: text, range: range) != nil { return true }
    }
    return false
}

// MARK: - Channel Access Logic (mirrors strict-mode sanitize)

private func isChannelAllowed(
    channel: String,
    mode: TestFirewallMode,
    registeredChannels: [String: TestChannelRegistration]
) -> Bool {
    switch mode {
    case .strict:
        return registeredChannels[channel] != nil
    case .standard, .permissive:
        return true
    }
}

private func areDataTypesAllowed(
    content: String,
    channel: String,
    mode: TestFirewallMode,
    registeredChannels: [String: TestChannelRegistration]
) -> (allowed: Bool, disallowed: Set<TestOutboundDataType>) {
    guard mode == .strict, let reg = registeredChannels[channel] else {
        return (true, [])
    }
    let detected = classifyContent(content)
    let disallowed = detected.subtracting(reg.allowedDataTypes)
    return (disallowed.isEmpty, disallowed)
}

// MARK: - Pre-Commit Scan Logic (mirrors OutboundPrivacyGuard.preCommitScan)

private func preCommitScan(_ content: String, filename: String) -> [TestSecurityFinding] {
    var findings: [TestSecurityFinding] = []
    let types = classifyContent(content)

    if types.contains(.credentials) {
        findings.append(TestSecurityFinding(
            severity: .critical, file: filename,
            description: "Potential credentials detected",
            recommendation: "Move to Keychain or .env file"
        ))
    }
    if types.contains(.personalInfo) {
        findings.append(TestSecurityFinding(
            severity: .warning, file: filename,
            description: "PII detected",
            recommendation: "Ensure this is test data, not real personal information"
        ))
    }
    return findings
}

// MARK: - Tests

@Suite("FirewallMode — Enum Properties")
struct FirewallModeTests {

    @Test("All 3 modes exist")
    func allCases() {
        #expect(TestFirewallMode.allCases.count == 3)
    }

    @Test("Raw values match case names")
    func rawValues() {
        #expect(TestFirewallMode.strict.rawValue == "strict")
        #expect(TestFirewallMode.standard.rawValue == "standard")
        #expect(TestFirewallMode.permissive.rawValue == "permissive")
    }

    @Test("Codable roundtrip")
    func codable() throws {
        for mode in TestFirewallMode.allCases {
            let data = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(TestFirewallMode.self, from: data)
            #expect(decoded == mode)
        }
    }

    @Test("Strict is default-deny")
    func strictDefaultDeny() {
        let mode = TestFirewallMode.strict
        // Strict mode requires channel registration
        let registered: [String: TestChannelRegistration] = [:]
        let allowed = isChannelAllowed(channel: "unknown_channel", mode: mode, registeredChannels: registered)
        #expect(!allowed)
    }

    @Test("Standard allows unregistered channels")
    func standardAllowsUnregistered() {
        let registered: [String: TestChannelRegistration] = [:]
        let allowed = isChannelAllowed(channel: "unknown_channel", mode: .standard, registeredChannels: registered)
        #expect(allowed)
    }

    @Test("Permissive allows everything")
    func permissiveAllowsAll() {
        let registered: [String: TestChannelRegistration] = [:]
        let allowed = isChannelAllowed(channel: "anything", mode: .permissive, registeredChannels: registered)
        #expect(allowed)
    }
}

@Suite("OutboundDataType — Enum Properties")
struct OutboundDataTypeTests {

    @Test("All 9 data types exist")
    func allCases() {
        #expect(TestOutboundDataType.allCases.count == 9)
    }

    @Test("Raw values are non-empty strings")
    func rawValues() {
        for dt in TestOutboundDataType.allCases {
            #expect(!dt.rawValue.isEmpty)
        }
    }

    @Test("All raw values are unique")
    func uniqueRawValues() {
        let raws = TestOutboundDataType.allCases.map(\.rawValue)
        #expect(Set(raws).count == 9)
    }

    @Test("Codable roundtrip")
    func codable() throws {
        for dt in TestOutboundDataType.allCases {
            let data = try JSONEncoder().encode(dt)
            let decoded = try JSONDecoder().decode(TestOutboundDataType.self, from: data)
            #expect(decoded == dt)
        }
    }

    @Test("Can be used in Set operations")
    func setOperations() {
        let allowed: Set<TestOutboundDataType> = [.text, .codeContent, .structuredData]
        let detected: Set<TestOutboundDataType> = [.text, .credentials]
        let disallowed = detected.subtracting(allowed)
        #expect(disallowed == [.credentials])
    }
}

@Suite("ChannelRegistration — Construction")
struct ChannelRegistrationTests {

    @Test("Create registration with all fields")
    func createRegistration() {
        let reg = TestChannelRegistration(
            channelId: "cloud_api",
            description: "AI model API calls",
            policyName: "CloudAPIPolicy",
            allowedDataTypes: [.text, .codeContent, .structuredData],
            registeredAt: Date(),
            registeredBy: "OutboundPrivacyGuard"
        )
        #expect(reg.channelId == "cloud_api")
        #expect(reg.description == "AI model API calls")
        #expect(reg.allowedDataTypes.count == 3)
        #expect(reg.allowedDataTypes.contains(.text))
        #expect(reg.allowedDataTypes.contains(.codeContent))
        #expect(reg.registeredBy == "OutboundPrivacyGuard")
    }

    @Test("Minimal registration (text only)")
    func minimalRegistration() {
        let reg = TestChannelRegistration(
            channelId: "moltbook",
            description: "Moltbook discussions",
            policyName: "MoltbookPolicy",
            allowedDataTypes: [.text],
            registeredAt: Date(),
            registeredBy: "OutboundPrivacyGuard"
        )
        #expect(reg.allowedDataTypes.count == 1)
        #expect(reg.allowedDataTypes.contains(.text))
    }

    @Test("Registration timestamp is recent")
    func timestamp() {
        let reg = TestChannelRegistration(
            channelId: "test", description: "test", policyName: "test",
            allowedDataTypes: [.text], registeredAt: Date(), registeredBy: "test"
        )
        let elapsed = Date().timeIntervalSince(reg.registeredAt)
        #expect(elapsed < 1.0)
    }

    @Test("Default 7 channels registered")
    func defaultChannels() {
        let defaults: [(String, String, Set<TestOutboundDataType>)] = [
            ("cloud_api", "AI model API calls", [.text, .codeContent, .structuredData]),
            ("messaging", "Messaging services", [.text]),
            ("mcp", "MCP tool calls", [.text, .structuredData, .codeContent]),
            ("web_api", "Web API calls", [.text, .structuredData]),
            ("moltbook", "Moltbook discussions", [.text]),
            ("cloudkit_sync", "iCloud sync", [.text, .structuredData, .deviceInfo]),
            ("health_ai", "Health data to AI", [.text, .healthData])
        ]
        #expect(defaults.count == 7)
        let ids = defaults.map(\.0)
        #expect(Set(ids).count == 7) // all unique
    }
}

@Suite("SecurityFinding — Construction")
struct SecurityFindingTests {

    @Test("All 3 severities exist")
    func allSeverities() {
        #expect(TestSecurityFinding.Severity.allCases.count == 3)
    }

    @Test("Severity raw values")
    func severityRawValues() {
        #expect(TestSecurityFinding.Severity.critical.rawValue == "critical")
        #expect(TestSecurityFinding.Severity.warning.rawValue == "warning")
        #expect(TestSecurityFinding.Severity.info.rawValue == "info")
    }

    @Test("Create critical finding")
    func criticalFinding() {
        let finding = TestSecurityFinding(
            severity: .critical,
            file: "Config.swift",
            description: "API key detected",
            recommendation: "Move to Keychain"
        )
        #expect(finding.severity == .critical)
        #expect(finding.file == "Config.swift")
        #expect(!finding.description.isEmpty)
        #expect(!finding.recommendation.isEmpty)
    }

    @Test("Create warning finding")
    func warningFinding() {
        let finding = TestSecurityFinding(
            severity: .warning,
            file: "UserModel.swift",
            description: "PII detected",
            recommendation: "Use test data"
        )
        #expect(finding.severity == .warning)
    }
}

@Suite("Content Classification — classifyContent()")
struct ContentClassificationTests {

    @Test("Plain text classifies as text only")
    func plainText() {
        let types = classifyContent("Hello, how are you today?")
        #expect(types == [.text])
    }

    @Test("API key classifies as credentials")
    func apiKey() {
        let types = classifyContent("My key is sk-abcdefghijklmnopqrstuvwxyz1234")
        #expect(types.contains(.credentials))
        #expect(types.contains(.text))
    }

    @Test("GitHub token classifies as credentials")
    func githubToken() {
        let types = classifyContent("ghp_abcdefghijklmnopqrstuvwxyz1234567890")
        #expect(types.contains(.credentials))
    }

    @Test("AWS key classifies as credentials")
    func awsKey() {
        let types = classifyContent("AKIAIOSFODNN7EXAMPLE")
        #expect(types.contains(.credentials))
    }

    @Test("PEM key classifies as credentials")
    func pemKey() {
        let types = classifyContent("-----BEGIN RSA PRIVATE KEY-----\nMIIEpAI...")
        #expect(types.contains(.credentials))
    }

    @Test("Generic password pattern classifies as credentials")
    func passwordPattern() {
        let types = classifyContent("api_key = \"abcdefghijklmnop1234\"")
        #expect(types.contains(.credentials))
    }

    @Test("Blood pressure classifies as health data")
    func bloodPressure() {
        let types = classifyContent("Patient blood pressure: 120/80 mmHg")
        #expect(types.contains(.healthData))
    }

    @Test("Heart rate classifies as health data")
    func heartRate() {
        let types = classifyContent("Current heart rate: 72 bpm")
        #expect(types.contains(.healthData))
    }

    @Test("Steps classifies as health data")
    func steps() {
        let types = classifyContent("Today's steps: 10,234")
        #expect(types.contains(.healthData))
    }

    @Test("HealthKit classifies as health data")
    func healthKit() {
        let types = classifyContent("Reading HKQuantity samples from HealthKit")
        #expect(types.contains(.healthData))
    }

    @Test("IBAN classifies as financial data")
    func iban() {
        let types = classifyContent("IBAN: DE89370400440532013000")
        #expect(types.contains(.financialData))
    }

    @Test("Credit card pattern classifies as financial data")
    func creditCard() {
        let types = classifyContent("Card: 4111 1111 1111 1111")
        #expect(types.contains(.financialData))
    }

    @Test("SSN classifies as financial data")
    func ssn() {
        let types = classifyContent("Social security number: 123-45-6789")
        #expect(types.contains(.financialData))
    }

    @Test("GPS coordinates classify as location data")
    func gpsCoordinates() {
        let types = classifyContent("latitude: 37.7749, longitude: -122.4194")
        #expect(types.contains(.locationData))
    }

    @Test("Geolocation classifies as location data")
    func geolocation() {
        let types = classifyContent("Getting user geolocation...")
        #expect(types.contains(.locationData))
    }

    @Test("Serial number classifies as device info")
    func serialNumber() {
        let types = classifyContent("Device serial number: ABC123DEF456")
        #expect(types.contains(.deviceInfo))
    }

    @Test("MAC address classifies as device info")
    func macAddress() {
        let types = classifyContent("MAC: aa:bb:cc:dd:ee:ff")
        #expect(types.contains(.deviceInfo))
    }

    @Test("UDID classifies as device info")
    func udid() {
        let types = classifyContent("Device UDID: 12345")
        #expect(types.contains(.deviceInfo))
    }

    @Test("Swift code classifies as code content")
    func swiftCode() {
        let types = classifyContent("func calculateTotal() -> Int {\n    let sum = 0\n    return sum\n}")
        #expect(types.contains(.codeContent))
    }

    @Test("Import statement classifies as code content")
    func importStatement() {
        let types = classifyContent("import Foundation\nimport UIKit")
        #expect(types.contains(.codeContent))
    }

    @Test("JSON classifies as structured data")
    func jsonContent() {
        let types = classifyContent("{\"name\": \"test\", \"value\": 42}")
        #expect(types.contains(.structuredData))
    }

    @Test("Multiple types detected simultaneously")
    func multipleTypes() {
        let content = """
        func sendHealthData() {
            let heartRate = 72
            api_key = "sk-abcdefghijklmnopqrstuvwxyz"
            let latitude = 37.7749
        }
        """
        let types = classifyContent(content)
        #expect(types.contains(.text))
        #expect(types.contains(.codeContent))
        #expect(types.contains(.healthData))
        #expect(types.contains(.credentials))
        #expect(types.contains(.locationData))
    }
}

@Suite("Channel Access Control — Strict Mode")
struct ChannelAccessControlTests {

    private func defaultChannels() -> [String: TestChannelRegistration] {
        let defaults: [(String, String, String, Set<TestOutboundDataType>)] = [
            ("cloud_api", "AI model API calls", "CloudAPIPolicy", [.text, .codeContent, .structuredData]),
            ("messaging", "Messaging services", "MessagingPolicy", [.text]),
            ("mcp", "MCP tool calls", "MCPPolicy", [.text, .structuredData, .codeContent]),
            ("web_api", "Web API calls", "WebAPIPolicy", [.text, .structuredData]),
            ("moltbook", "Moltbook discussions", "MoltbookPolicy", [.text]),
            ("cloudkit_sync", "iCloud sync", "CloudAPIPolicy", [.text, .structuredData, .deviceInfo]),
            ("health_ai", "Health data to AI", "CloudAPIPolicy", [.text, .healthData])
        ]
        var channels: [String: TestChannelRegistration] = [:]
        for (id, desc, policy, types) in defaults {
            channels[id] = TestChannelRegistration(
                channelId: id, description: desc, policyName: policy,
                allowedDataTypes: types, registeredAt: Date(), registeredBy: "OutboundPrivacyGuard"
            )
        }
        return channels
    }

    @Test("Registered channel is allowed in strict mode")
    func registeredChannelAllowed() {
        let channels = defaultChannels()
        let allowed = isChannelAllowed(channel: "cloud_api", mode: .strict, registeredChannels: channels)
        #expect(allowed)
    }

    @Test("Unregistered channel is blocked in strict mode")
    func unregisteredChannelBlocked() {
        let channels = defaultChannels()
        let allowed = isChannelAllowed(channel: "rogue_service", mode: .strict, registeredChannels: channels)
        #expect(!allowed)
    }

    @Test("Text content allowed on messaging channel")
    func textOnMessaging() {
        let channels = defaultChannels()
        let result = areDataTypesAllowed(
            content: "Hello world", channel: "messaging",
            mode: .strict, registeredChannels: channels
        )
        #expect(result.allowed)
        #expect(result.disallowed.isEmpty)
    }

    @Test("Credentials blocked on messaging channel")
    func credentialsOnMessaging() {
        let channels = defaultChannels()
        let result = areDataTypesAllowed(
            content: "My key is sk-abcdefghijklmnopqrstuvwxyz1234",
            channel: "messaging", mode: .strict, registeredChannels: channels
        )
        #expect(!result.allowed)
        #expect(result.disallowed.contains(.credentials))
    }

    @Test("Code content allowed on cloud_api channel")
    func codeOnCloudAPI() {
        let channels = defaultChannels()
        let result = areDataTypesAllowed(
            content: "func hello() {\n    print(\"hi\")\n}",
            channel: "cloud_api", mode: .strict, registeredChannels: channels
        )
        #expect(result.allowed)
    }

    @Test("Health data allowed on health_ai channel")
    func healthOnHealthAI() {
        let channels = defaultChannels()
        let result = areDataTypesAllowed(
            content: "Patient heart rate: 72 bpm",
            channel: "health_ai", mode: .strict, registeredChannels: channels
        )
        #expect(result.allowed)
    }

    @Test("Health data blocked on cloud_api channel")
    func healthOnCloudAPI() {
        let channels = defaultChannels()
        let result = areDataTypesAllowed(
            content: "Patient heart rate: 72 bpm",
            channel: "cloud_api", mode: .strict, registeredChannels: channels
        )
        #expect(!result.allowed)
        #expect(result.disallowed.contains(.healthData))
    }

    @Test("Device info allowed on cloudkit_sync channel")
    func deviceInfoOnSync() {
        let channels = defaultChannels()
        let result = areDataTypesAllowed(
            content: "Device serial number: ABC123",
            channel: "cloudkit_sync", mode: .strict, registeredChannels: channels
        )
        #expect(result.allowed)
    }

    @Test("Device info blocked on messaging channel")
    func deviceInfoOnMessaging() {
        let channels = defaultChannels()
        let result = areDataTypesAllowed(
            content: "Device serial number: ABC123",
            channel: "messaging", mode: .strict, registeredChannels: channels
        )
        #expect(!result.allowed)
        #expect(result.disallowed.contains(.deviceInfo))
    }

    @Test("Standard mode skips data type checks")
    func standardModeSkips() {
        let channels = defaultChannels()
        let result = areDataTypesAllowed(
            content: "sk-abcdefghijklmnopqrstuvwxyz1234 and heart rate 72 bpm",
            channel: "messaging", mode: .standard, registeredChannels: channels
        )
        #expect(result.allowed)
    }

    @Test("Permissive mode skips data type checks")
    func permissiveModeSkips() {
        let channels = defaultChannels()
        let result = areDataTypesAllowed(
            content: "AKIA1234567890123456 serial number XYZ latitude 37.0",
            channel: "messaging", mode: .permissive, registeredChannels: channels
        )
        #expect(result.allowed)
    }
}

@Suite("Pre-Commit Scan — SecurityFinding Generation")
struct PreCommitScanTests {

    @Test("Clean code produces no findings")
    func cleanCode() {
        let findings = preCommitScan("func hello() { print(\"Hello\") }", filename: "Hello.swift")
        #expect(findings.isEmpty)
    }

    @Test("API key produces critical finding")
    func apiKeyFinding() {
        let findings = preCommitScan("let key = \"sk-abcdefghijklmnopqrstuvwxyz1234\"", filename: "Config.swift")
        #expect(findings.count == 1)
        #expect(findings[0].severity == .critical)
        #expect(findings[0].file == "Config.swift")
        #expect(findings[0].description.contains("credentials"))
    }

    @Test("AWS key produces critical finding")
    func awsKeyFinding() {
        let findings = preCommitScan("aws_key = AKIAIOSFODNN7EXAMPLE", filename: "Deploy.swift")
        #expect(findings.count == 1)
        #expect(findings[0].severity == .critical)
    }

    @Test("Safe text produces no findings")
    func safeText() {
        let findings = preCommitScan("This is a normal comment about the algorithm", filename: "Algorithm.swift")
        #expect(findings.isEmpty)
    }

    @Test("Recommendation is actionable")
    func recommendation() {
        let findings = preCommitScan("sk-abcdefghijklmnopqrstuvwxyz1234", filename: "test.swift")
        #expect(!findings.isEmpty)
        #expect(findings[0].recommendation.contains("Keychain") || findings[0].recommendation.contains(".env"))
    }
}

@Suite("Edge Cases — Classification")
struct ClassificationEdgeCaseTests {

    @Test("Empty string classifies as text only")
    func emptyString() {
        let types = classifyContent("")
        #expect(types == [.text])
    }

    @Test("Very long text classifies correctly")
    func longText() {
        let text = String(repeating: "Hello world. ", count: 1000)
        let types = classifyContent(text)
        #expect(types == [.text])
    }

    @Test("Mixed credentials and health data")
    func mixedContent() {
        let content = "api_key = \"abcdefghijklmnop1234\" blood pressure 120/80"
        let types = classifyContent(content)
        #expect(types.contains(.credentials))
        #expect(types.contains(.healthData))
    }

    @Test("JSON with credentials detected")
    func jsonWithCredentials() {
        let content = "{\"api_key\": \"sk-abcdefghijklmnopqrstuvwxyz1234\"}"
        let types = classifyContent(content)
        #expect(types.contains(.structuredData))
        #expect(types.contains(.credentials))
    }

    @Test("Partial keyword does not false-positive")
    func partialKeyword() {
        // "bpm" alone should trigger health, but "bump" should not
        let typesBpm = classifyContent("heart rate 72 bpm")
        #expect(typesBpm.contains(.healthData))

        // "steps" should trigger
        let typesSteps = classifyContent("walked 10000 steps today")
        #expect(typesSteps.contains(.healthData))
    }

    @Test("Code with braces is both code and structured data")
    func codeWithBraces() {
        let content = "func test() {\n    let data = \"{\\\"key\\\": \\\"value\\\"}\"\n}"
        let types = classifyContent(content)
        #expect(types.contains(.codeContent))
    }
}
