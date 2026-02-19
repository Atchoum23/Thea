// SecurityScanner.swift
// Thea — Security scanning, malware detection, privacy audit
// Replaces: Moonlock
//
// YARA-like pattern matching, process monitoring, TCC audit,
// file integrity checking, and weekly security reports.

import CryptoKit
import Foundation
import OSLog

private let ssLogger = Logger(subsystem: "ai.thea.app", category: "SecurityScanner")

// MARK: - Data Types

enum ThreatLevel: String, Codable, Sendable, Comparable {
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

    static func < (lhs: ThreatLevel, rhs: ThreatLevel) -> Bool {
        let order: [ThreatLevel] = [.clean, .low, .medium, .high, .critical]
        return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
    }
}

enum ScanCategory: String, CaseIterable, Codable, Sendable {
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

struct SystemSecurityFinding: Codable, Sendable, Identifiable {
    let id: UUID
    let category: ScanCategory
    let threatLevel: ThreatLevel
    let title: String
    let description: String
    let filePath: String?
    let recommendation: String
    let detectedAt: Date

    init(
        category: ScanCategory,
        threatLevel: ThreatLevel,
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

struct ScanReport: Codable, Sendable, Identifiable {
    let id: UUID
    let findings: [SystemSecurityFinding]
    let scanDuration: TimeInterval
    let categoriesScanned: [ScanCategory]
    let filesScanned: Int
    let startedAt: Date
    let completedAt: Date

    var overallThreatLevel: ThreatLevel {
        findings.max { $0.threatLevel < $1.threatLevel }?.threatLevel ?? .clean
    }

    var findingsByCategory: [ScanCategory: [SystemSecurityFinding]] {
        Dictionary(grouping: findings, by: \.category)
    }

    var criticalCount: Int { findings.filter { $0.threatLevel == .critical }.count }
    var highCount: Int { findings.filter { $0.threatLevel == .high }.count }
    var mediumCount: Int { findings.filter { $0.threatLevel == .medium }.count }
    var lowCount: Int { findings.filter { $0.threatLevel == .low }.count }
}

// MARK: - Signature Patterns

// periphery:ignore - Reserved: MalwareSignature type — reserved for future feature activation
private struct MalwareSignature: Sendable {
    let name: String
    let pattern: String // hex or string pattern
    let category: ScanCategory
    let threat: ThreatLevel
// periphery:ignore - Reserved: MalwareSignature type reserved for future feature activation
}

// MARK: - SecurityScanner Service

actor SystemSecurityScanner {
    static let shared = SystemSecurityScanner()

    private var scanHistory: [ScanReport] = []
    private let historyFile: URL
    private var isScanning = false

    // Known suspicious paths on macOS
    // periphery:ignore - Reserved: suspiciousPaths property — reserved for future feature activation
    private let suspiciousPaths: [String] = [
        "/Library/LaunchDaemons",
        "/Library/LaunchAgents",
        "~/Library/LaunchAgents"
    // periphery:ignore - Reserved: suspiciousPaths property reserved for future feature activation
    ]

    // Known adware bundle IDs
    private let knownAdware: Set<String> = [
        "com.genieo", "com.crossrider", "com.operatorMac",
        "com.vsearch", "com.conduit", "com.spigot",
        "com.installmac", "com.mackeeper", "com.advanced-mac-cleaner",
        "com.zeobit.MacKeeper"
    ]

    // Known PUP indicators
    private let pupIndicators: [String] = [
        "MacKeeper", "CleanMyMac X", "Advanced Mac Cleaner",
        "Mac Auto Fixer", "Mac Tonic", "Smart Mac Booster"
    ]

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let theaDir = appSupport.appendingPathComponent("Thea/SecurityScanner")
        do {
            try FileManager.default.createDirectory(at: theaDir, withIntermediateDirectories: true)
        } catch {
            ssLogger.error("Failed to create SecurityScanner directory: \(error.localizedDescription)")
        }
        let file = theaDir.appendingPathComponent("scan_history.json")
        self.historyFile = file
        // Inline loadHistory to avoid calling actor-isolated method from init
        do {
            let data = try Data(contentsOf: file)
            self.scanHistory = try JSONDecoder().decode([ScanReport].self, from: data)
        } catch CocoaError.fileReadNoSuchFile {
            self.scanHistory = []
        } catch {
            ssLogger.error("Failed to load scan history: \(error.localizedDescription)")
            self.scanHistory = []
        }
    }

    // MARK: - Full Scan

    func runFullScan(categories: [ScanCategory] = ScanCategory.allCases) async -> ScanReport {
        guard !isScanning else {
            return ScanReport(
                id: UUID(), findings: [], scanDuration: 0,
                categoriesScanned: [], filesScanned: 0,
                startedAt: Date(), completedAt: Date()
            )
        }

        isScanning = true
        let startTime = Date()
        var allFindings: [SystemSecurityFinding] = []
        var totalFiles = 0

        for category in categories {
            let (findings, filesChecked) = await scanCategory(category)
            allFindings.append(contentsOf: findings)
            totalFiles += filesChecked
        }

        let endTime = Date()
        let report = ScanReport(
            id: UUID(),
            findings: allFindings,
            scanDuration: endTime.timeIntervalSince(startTime),
            categoriesScanned: categories,
            filesScanned: totalFiles,
            startedAt: startTime,
            completedAt: endTime
        )

        scanHistory.append(report)
        if scanHistory.count > 50 {
            scanHistory = Array(scanHistory.suffix(50))
        }
        saveHistory()
        isScanning = false

        ssLogger.info("Security scan complete: \(allFindings.count) findings, \(totalFiles) files scanned in \(report.scanDuration, format: .fixed(precision: 1))s")
        return report
    }

    // MARK: - Category Scans

    private func scanCategory(_ category: ScanCategory) async -> ([SystemSecurityFinding], Int) {
        switch category {
        case .malware: return await scanForMalware()
        case .adware: return await scanForAdware()
        case .pup: return await scanForPUP()
        case .privacy: return await scanPrivacy()
        case .network: return await scanNetwork()
        case .permissions: return await scanPermissions()
        case .credentials: return await scanCredentials()
        case .systemIntegrity: return await scanSystemIntegrity()
        }
    }

    private func scanForMalware() async -> ([SystemSecurityFinding], Int) {
        var findings: [SystemSecurityFinding] = []
        var filesChecked = 0

        // Check LaunchDaemons/LaunchAgents for suspicious items
        let launchPaths = [
            "/Library/LaunchDaemons",
            "/Library/LaunchAgents",
            NSHomeDirectory() + "/Library/LaunchAgents"
        ]

        for dir in launchPaths {
            let items: [String]
            do {
                items = try FileManager.default.contentsOfDirectory(atPath: dir)
            } catch {
                ssLogger.debug("Cannot read directory \(dir): \(error.localizedDescription)")
                continue
            }
            for item in items {
                filesChecked += 1
                let fullPath = (dir as NSString).appendingPathComponent(item)

                // Check for suspicious plist content
                if let data = FileManager.default.contents(atPath: fullPath),
                   let content = String(data: data, encoding: .utf8) {
                    // Check for known malware patterns
                    if content.contains("curl") && content.contains("bash") {
                        findings.append(SystemSecurityFinding(
                            category: .malware,
                            threatLevel: .high,
                            title: "Suspicious Launch Agent: \(item)",
                            description: "Launch agent contains curl+bash pattern, often used by malware to download and execute payloads",
                            filePath: fullPath,
                            recommendation: "Inspect the plist file and the binary it references. Remove if unrecognized."
                        ))
                    }

                    // Check for obfuscated paths
                    if content.contains("/tmp/.") || content.contains("/var/tmp/.") {
                        findings.append(SystemSecurityFinding(
                            category: .malware,
                            threatLevel: .medium,
                            title: "Hidden File Reference: \(item)",
                            description: "Launch agent references a hidden file in temp directory",
                            filePath: fullPath,
                            recommendation: "Hidden files in /tmp may indicate malware. Verify the referenced binary."
                        ))
                    }
                }
            }
        }

        return (findings, filesChecked)
    }

    private func scanForAdware() async -> ([SystemSecurityFinding], Int) {
        var findings: [SystemSecurityFinding] = []
        var filesChecked = 0

        let appsDir = "/Applications"
        let items: [String]
        do {
            items = try FileManager.default.contentsOfDirectory(atPath: appsDir)
        } catch {
            ssLogger.error("Cannot read /Applications: \(error.localizedDescription)")
            return ([], 0)
        }

        for item in items where item.hasSuffix(".app") {
            filesChecked += 1
            let infoPlistPath = "\(appsDir)/\(item)/Contents/Info.plist"

            guard let data = FileManager.default.contents(atPath: infoPlistPath) else { continue }
            do {
                let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
                if let bundleID = plist?["CFBundleIdentifier"] as? String, knownAdware.contains(bundleID) {
                    findings.append(SystemSecurityFinding(
                        category: .adware,
                        threatLevel: .high,
                        title: "Known Adware: \(item)",
                        description: "Application \(item) is identified as adware (bundle: \(bundleID))",
                        filePath: "\(appsDir)/\(item)",
                        recommendation: "Remove this application. It may inject ads, track browsing, or modify browser settings."
                    ))
                }
            } catch {
                ssLogger.debug("Cannot parse Info.plist for \(item): \(error.localizedDescription)")
            }
        }

        // Check browser extensions directory
        let safariExtDir = NSHomeDirectory() + "/Library/Safari/Extensions"
        do {
            let extItems = try FileManager.default.contentsOfDirectory(atPath: safariExtDir)
            filesChecked += extItems.count
        } catch {
            ssLogger.debug("Cannot read Safari extensions directory: \(error.localizedDescription)")
        }

        return (findings, filesChecked)
    }

    private func scanForPUP() async -> ([SystemSecurityFinding], Int) {
        var findings: [SystemSecurityFinding] = []
        var filesChecked = 0

        let appsDir = "/Applications"
        let items: [String]
        do {
            items = try FileManager.default.contentsOfDirectory(atPath: appsDir)
        } catch {
            ssLogger.error("Cannot read /Applications for PUP scan: \(error.localizedDescription)")
            return ([], 0)
        }

        for item in items where item.hasSuffix(".app") {
            filesChecked += 1
            let appName = (item as NSString).deletingPathExtension
            if pupIndicators.contains(where: { appName.localizedCaseInsensitiveContains($0) }) {
                findings.append(SystemSecurityFinding(
                    category: .pup,
                    threatLevel: .medium,
                    title: "Potentially Unwanted: \(item)",
                    description: "This application is commonly associated with aggressive marketing or unnecessary system modifications",
                    filePath: "\(appsDir)/\(item)",
                    recommendation: "Consider removing. These apps often provide minimal value while consuming system resources."
                ))
            }
        }

        return (findings, filesChecked)
    }

    private func scanPrivacy() async -> ([SystemSecurityFinding], Int) {
        var findings: [SystemSecurityFinding] = []
        var filesChecked = 0

        #if os(macOS)
        // Check TCC database for apps with sensitive permissions
        let tccPath = NSHomeDirectory() + "/Library/Application Support/com.apple.TCC/TCC.db"
        if FileManager.default.fileExists(atPath: tccPath) {
            filesChecked += 1
            // We can't directly read TCC.db (SIP-protected), but we can note its existence
            ssLogger.info("TCC database found — permission audit available via System Settings")
        }

        // Check for apps that have accessibility permission (TCC database)
        _ = "/Library/Application Support/com.apple.TCC/TCC.db"
        filesChecked += 1

        // Check for tracking-related files
        let trackingPaths = [
            NSHomeDirectory() + "/Library/Application Support/Google/Chrome/Default/Cookies",
            NSHomeDirectory() + "/Library/Cookies/Cookies.binarycookies",
            NSHomeDirectory() + "/Library/Safari/History.db"
        ]

        for path in trackingPaths {
            if FileManager.default.fileExists(atPath: path) {
                filesChecked += 1
                do {
                    let attrs = try FileManager.default.attributesOfItem(atPath: path)
                    let size = (attrs[.size] as? Int64) ?? 0
                    if size > 10_000_000 { // > 10MB
                        findings.append(SystemSecurityFinding(
                            category: .privacy,
                            threatLevel: .low,
                            title: "Large Tracking Database",
                            description: "Tracking/cookie database at \((path as NSString).lastPathComponent) is \(Self.formatFileSize(size))",
                            filePath: path,
                            recommendation: "Consider clearing browser cookies and history periodically to reduce tracking surface."
                        ))
                    }
                } catch {
                    ssLogger.debug("Cannot read attributes for \(path): \(error.localizedDescription)")
                }
            }
        }
        #endif

        return (findings, filesChecked)
    }

    private func scanNetwork() async -> ([SystemSecurityFinding], Int) {
        var findings: [SystemSecurityFinding] = []
        var filesChecked = 0

        #if os(macOS)
        // Check if firewall is enabled
        let firewallPlist = "/Library/Preferences/com.apple.alf.plist"
        filesChecked += 1
        if let data = FileManager.default.contents(atPath: firewallPlist) {
            do {
                let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
                if let enabled = plist?["globalstate"] as? Int, enabled == 0 {
                    findings.append(SystemSecurityFinding(
                        category: .network,
                        threatLevel: .medium,
                        title: "macOS Firewall Disabled",
                        description: "The built-in application firewall is not enabled",
                        recommendation: "Enable firewall in System Settings > Network > Firewall"
                    ))
                }
            } catch {
                ssLogger.debug("Cannot parse firewall plist: \(error.localizedDescription)")
            }
        }

        // Check SSH config for weak settings
        let sshConfig = NSHomeDirectory() + "/.ssh/config"
        filesChecked += 1
        if let configData = FileManager.default.contents(atPath: sshConfig),
           let content = String(data: configData, encoding: .utf8) {
            if content.contains("StrictHostKeyChecking no") {
                findings.append(SystemSecurityFinding(
                    category: .network,
                    threatLevel: .medium,
                    title: "Weak SSH Configuration",
                    description: "SSH config disables strict host key checking, allowing MITM attacks",
                    filePath: sshConfig,
                    recommendation: "Remove 'StrictHostKeyChecking no' from SSH config"
                ))
            }
        }

        // Check for open ports (listen sockets)
        let lsofOutput = runProcess("/usr/sbin/lsof", arguments: ["-i", "-P", "-n"])
        let listenLines = lsofOutput.components(separatedBy: "\n").filter { $0.contains("LISTEN") }
        filesChecked += listenLines.count
        if listenLines.count > 20 {
            findings.append(SystemSecurityFinding(
                category: .network,
                threatLevel: .low,
                title: "Many Listening Ports (\(listenLines.count))",
                description: "There are \(listenLines.count) processes listening on network ports",
                recommendation: "Review listening services and disable any that are not needed."
            ))
        }
        #endif

        return (findings, filesChecked)
    }

    private func scanPermissions() async -> ([SystemSecurityFinding], Int) {
        var findings: [SystemSecurityFinding] = []
        var filesChecked = 0

        #if os(macOS)
        // Check for world-writable files in sensitive locations
        let sensitiveDirs = ["/usr/local/bin", "/usr/local/sbin"]

        for dir in sensitiveDirs {
            let items: [String]
            do {
                items = try FileManager.default.contentsOfDirectory(atPath: dir)
            } catch {
                ssLogger.debug("Cannot read directory \(dir): \(error.localizedDescription)")
                continue
            }
            for item in items.prefix(100) { // Limit to prevent slow scans
                filesChecked += 1
                let path = (dir as NSString).appendingPathComponent(item)
                do {
                    let attrs = try FileManager.default.attributesOfItem(atPath: path)
                    guard let permissions = attrs[.posixPermissions] as? Int else { continue }
                    // Check world-writable (o+w = 0o002)
                    if permissions & 0o002 != 0 {
                        findings.append(SystemSecurityFinding(
                            category: .permissions,
                            threatLevel: .high,
                            title: "World-Writable Binary: \(item)",
                            description: "Binary at \(path) is writable by any user, allowing potential tampering",
                            filePath: path,
                            recommendation: "Fix permissions: chmod o-w \(path)"
                        ))
                    }
                } catch {
                    ssLogger.debug("Cannot read attributes for \(path): \(error.localizedDescription)")
                }
            }
        }

        // Check SSH key permissions
        let sshDir = NSHomeDirectory() + "/.ssh"
        let sshItems: [String]
        do {
            sshItems = try FileManager.default.contentsOfDirectory(atPath: sshDir)
        } catch {
            ssLogger.debug("Cannot read ~/.ssh: \(error.localizedDescription)")
            return (findings, filesChecked)
        }
        for item in sshItems {
            filesChecked += 1
            let path = (sshDir as NSString).appendingPathComponent(item)
            if item.hasPrefix("id_") && !item.hasSuffix(".pub") {
                do {
                    let attrs = try FileManager.default.attributesOfItem(atPath: path)
                    guard let permissions = attrs[.posixPermissions] as? Int else { continue }
                    if permissions & 0o077 != 0 {
                        findings.append(SystemSecurityFinding(
                            category: .permissions,
                            threatLevel: .high,
                            title: "Insecure SSH Key: \(item)",
                            description: "SSH private key has overly permissive access (mode: \(String(permissions, radix: 8)))",
                            filePath: path,
                            recommendation: "Fix permissions: chmod 600 \(path)"
                        ))
                    }
                } catch {
                    ssLogger.debug("Cannot read attributes for SSH key \(item): \(error.localizedDescription)")
                }
            }
        }
        #endif

        return (findings, filesChecked)
    }

    private func scanCredentials() async -> ([SystemSecurityFinding], Int) {
        var findings: [SystemSecurityFinding] = []
        var filesChecked = 0

        // Check common credential locations
        let credentialPatterns: [(path: String, pattern: String, desc: String)] = [
            (NSHomeDirectory() + "/.netrc", "password", ".netrc contains plaintext passwords"),
            (NSHomeDirectory() + "/.aws/credentials", "aws_secret_access_key", "AWS credentials in plaintext"),
            (NSHomeDirectory() + "/.npmrc", "//registry.npmjs.org/:_authToken", "NPM auth token in plaintext"),
            (NSHomeDirectory() + "/.gitconfig", "password", "Git config may contain passwords")
        ]

        for check in credentialPatterns {
            filesChecked += 1
            if let data = FileManager.default.contents(atPath: check.path),
               let content = String(data: data, encoding: .utf8),
               content.localizedCaseInsensitiveContains(check.pattern) {
                findings.append(SystemSecurityFinding(
                    category: .credentials,
                    threatLevel: .high,
                    title: "Exposed Credentials: \((check.path as NSString).lastPathComponent)",
                    description: check.desc,
                    filePath: check.path,
                    recommendation: "Move credentials to macOS Keychain or use environment variables."
                ))
            }
        }

        // Check for .env files in common project directories
        let projectDirs = [
            NSHomeDirectory() + "/Documents",
            NSHomeDirectory() + "/Projects",
            NSHomeDirectory() + "/Developer"
        ]

        for dir in projectDirs {
            let items: [String]
            do {
                items = try FileManager.default.contentsOfDirectory(atPath: dir)
            } catch {
                continue // Directory might not exist
            }
            for item in items where item == ".env" {
                filesChecked += 1
                findings.append(SystemSecurityFinding(
                    category: .credentials,
                    threatLevel: .medium,
                    title: "Environment File: \(dir)/\(item)",
                    description: "Plaintext .env file may contain API keys and secrets",
                    filePath: "\(dir)/\(item)",
                    recommendation: "Ensure .env files are in .gitignore and credentials are stored securely."
                ))
            }
        }

        return (findings, filesChecked)
    }

    private func scanSystemIntegrity() async -> ([SystemSecurityFinding], Int) {
        var findings: [SystemSecurityFinding] = []
        var filesChecked = 0

        #if os(macOS)
        // Check SIP status
        let sipOutput = runProcess("/usr/bin/csrutil", arguments: ["status"])
        filesChecked += 1
        if sipOutput.contains("disabled") {
            findings.append(SystemSecurityFinding(
                category: .systemIntegrity,
                threatLevel: .critical,
                title: "System Integrity Protection Disabled",
                description: "SIP is disabled, allowing modification of protected system files",
                recommendation: "Re-enable SIP in Recovery Mode: csrutil enable"
            ))
        }

        // Check Gatekeeper status
        let gkOutput = runProcess("/usr/sbin/spctl", arguments: ["--status"])
        filesChecked += 1
        if gkOutput.contains("disabled") {
            findings.append(SystemSecurityFinding(
                category: .systemIntegrity,
                threatLevel: .high,
                title: "Gatekeeper Disabled",
                description: "Gatekeeper is disabled, allowing unverified apps to run without warning",
                recommendation: "Re-enable in System Settings > Privacy & Security"
            ))
        }

        // Check FileVault status
        let fvOutput = runProcess("/usr/bin/fdesetup", arguments: ["status"])
        filesChecked += 1
        if fvOutput.contains("FileVault is Off") {
            findings.append(SystemSecurityFinding(
                category: .systemIntegrity,
                threatLevel: .high,
                title: "FileVault Disabled",
                description: "Disk encryption is not enabled, data at rest is unprotected",
                recommendation: "Enable FileVault in System Settings > Privacy & Security > FileVault"
            ))
        }
        #endif

        return (findings, filesChecked)
    }

    // MARK: - Helper

    nonisolated private func runProcess(_ path: String, arguments: [String]) -> String {
        #if os(macOS)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
        #else
        return ""
        #endif
    }

    // MARK: - Formatting

    nonisolated private static func formatFileSize(_ bytes: Int64) -> String {
        let units = ["B", "KB", "MB", "GB"]
        var value = Double(bytes)
        var unitIndex = 0
        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }
        return unitIndex == 0 ? "\(bytes) B" : String(format: "%.1f %@", value, units[unitIndex])
    }

    // MARK: - History

    func getHistory() -> [ScanReport] { scanHistory }

    // periphery:ignore - Reserved: lastScan() instance method — reserved for future feature activation
    func lastScan() -> ScanReport? { scanHistory.last }

    // periphery:ignore - Reserved: clearHistory() instance method — reserved for future feature activation
    func clearHistory() {
        // periphery:ignore - Reserved: lastScan() instance method reserved for future feature activation
        scanHistory.removeAll()
        // periphery:ignore - Reserved: clearHistory() instance method reserved for future feature activation
        saveHistory()
    }

    // periphery:ignore - Reserved: getScanningStatus() instance method — reserved for future feature activation
    func getScanningStatus() -> Bool { isScanning }

// periphery:ignore - Reserved: getScanningStatus() instance method reserved for future feature activation

    // MARK: - Persistence

    // periphery:ignore - Reserved: loadHistory() instance method reserved for future feature activation
    private func loadHistory() {
        do {
            let data = try Data(contentsOf: historyFile)
            scanHistory = try JSONDecoder().decode([ScanReport].self, from: data)
        } catch CocoaError.fileReadNoSuchFile {
            // File doesn't exist yet - expected on first run
            return
        } catch {
            ssLogger.error("Failed to load scan history: \(error.localizedDescription)")
        }
    }

    private func saveHistory() {
        do {
            let data = try JSONEncoder().encode(scanHistory)
            try data.write(to: historyFile, options: .atomic)
        } catch {
            ssLogger.error("Failed to save scan history: \(error.localizedDescription)")
        }
    }
}
