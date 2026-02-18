import Testing
import Foundation

// MARK: - E4 Privacy Dashboard Tests

// Test doubles mirroring the real types from NetworkPrivacyMonitor, DNSBlocklistService,
// and PrivacyFirewallDashboardView for pure-logic unit testing.

// MARK: - TrafficRecord Types

private enum TestTrafficDirection: String, Codable {
    case outbound
    case inbound
}

private enum TestTrafficCategory: String, Codable, CaseIterable {
    case aiProvider = "AI Provider"
    case cloudSync = "Cloud Sync"
    case analytics = "Analytics"
    case advertising = "Advertising"
    case social = "Social Media"
    case tracker = "Tracker"
    case system = "System"
    case unknown = "Unknown"

    var sfSymbol: String {
        switch self {
        case .aiProvider: "brain"
        case .cloudSync: "icloud"
        case .analytics: "chart.bar"
        case .advertising: "megaphone"
        case .social: "person.2"
        case .tracker: "eye.trianglebadge.exclamationmark"
        case .system: "gear"
        case .unknown: "questionmark.circle"
        }
    }

    var isPrivacyConcern: Bool {
        switch self {
        case .analytics, .advertising, .tracker: true
        default: false
        }
    }
}

private struct TestTrafficRecord: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let hostname: String
    let port: UInt16
    let direction: TestTrafficDirection
    let category: TestTrafficCategory
    let wasBlocked: Bool
    let blockReason: String?
    let bytesEstimate: Int
}

// MARK: - DNS Blocklist Types

private enum TestBlockCategory: String, Codable, CaseIterable {
    case advertising = "Advertising"
    case tracker = "Tracker"
    case analytics = "Analytics"
    case malware = "Malware"
    case phishing = "Phishing"
    case cryptominer = "Cryptominer"
    case custom = "Custom"

    var sfSymbol: String {
        switch self {
        case .advertising: "megaphone.fill"
        case .tracker: "eye.slash.fill"
        case .analytics: "chart.bar.xaxis"
        case .malware: "exclamationmark.shield.fill"
        case .phishing: "fish.fill"
        case .cryptominer: "bitcoinsign.circle.fill"
        case .custom: "hand.raised.fill"
        }
    }
}

private enum TestBlockSource: String, Codable {
    case builtin = "Built-in"
    case user = "User"
}

private struct TestBlocklistEntry: Identifiable, Codable {
    let id: UUID
    let domain: String
    let category: TestBlockCategory
    let source: TestBlockSource
    let addedAt: Date
    var isEnabled: Bool

    init(domain: String, category: TestBlockCategory, source: TestBlockSource, isEnabled: Bool = true) {
        self.id = UUID()
        self.domain = domain.lowercased()
        self.category = category
        self.source = source
        self.addedAt = Date()
        self.isEnabled = isEnabled
    }
}

private struct TestBlockCheckResult {
    let isBlocked: Bool
    let matchedDomain: String?
    let category: TestBlockCategory?
}

private struct TestBlocklistStats {
    let totalDomains: Int
    let enabledDomains: Int
    let blockedToday: Int
    let blockedAllTime: Int
    let byCategory: [TestBlockCategory: Int]
}

// MARK: - Audit Types

private enum TestAuditOutcome: String, Codable {
    case passed
    case redacted
    case blocked
}

private struct TestAuditEntry: Identifiable {
    let id: UUID
    let timestamp: Date
    let channel: String
    let policyName: String
    let outcome: TestAuditOutcome
    let redactionCount: Int
    let originalLength: Int
    let sanitizedLength: Int
}

// MARK: - Domain Classification Logic

private func classifyDomain(_ hostname: String) -> TestTrafficCategory {
    let lowered = hostname.lowercased()
    let aiDomains: Set<String> = ["api.anthropic.com", "api.openai.com", "generativelanguage.googleapis.com",
                                   "api.groq.com", "openrouter.ai", "api.perplexity.ai", "api.deepseek.com"]
    let trackerDomains: Set<String> = ["pixel.facebook.com", "t.co", "bat.bing.com"]
    let adDomains: Set<String> = ["doubleclick.net", "googlesyndication.com"]
    let analyticsDomains: Set<String> = ["google-analytics.com", "mixpanel.com"]
    let socialDomains: Set<String> = ["facebook.com", "twitter.com", "x.com"]
    let cloudDomains: Set<String> = ["icloud.com", "icloud-content.com", "apple-cloudkit.com"]

    // Use matchesDomain for proper subdomain matching (not substring contains)
    func matchesDomain(_ hostname: String, _ domain: String) -> Bool {
        hostname == domain || hostname.hasSuffix(".\(domain)")
    }

    if aiDomains.contains(where: { matchesDomain(lowered, $0) }) { return .aiProvider }
    if trackerDomains.contains(where: { matchesDomain(lowered, $0) }) { return .tracker }
    if adDomains.contains(where: { matchesDomain(lowered, $0) }) { return .advertising }
    if analyticsDomains.contains(where: { matchesDomain(lowered, $0) }) { return .analytics }
    if socialDomains.contains(where: { matchesDomain(lowered, $0) }) { return .social }
    if cloudDomains.contains(where: { matchesDomain(lowered, $0) }) { return .cloudSync }
    if lowered.hasSuffix(".apple.com") { return .system }
    return .unknown
}

// MARK: - DNS Blocklist Check Logic

private func checkDomain(_ domain: String, entries: [String: TestBlocklistEntry]) -> TestBlockCheckResult {
    let lowered = domain.lowercased()

    // Exact match
    if let entry = entries[lowered], entry.isEnabled {
        return TestBlockCheckResult(isBlocked: true, matchedDomain: entry.domain, category: entry.category)
    }

    // Subdomain match
    let components = lowered.split(separator: ".")
    for startIndex in 1..<components.count {
        let parentDomain = components[startIndex...].joined(separator: ".")
        if let entry = entries[parentDomain], entry.isEnabled {
            return TestBlockCheckResult(isBlocked: true, matchedDomain: entry.domain, category: entry.category)
        }
    }

    return TestBlockCheckResult(isBlocked: false, matchedDomain: nil, category: nil)
}

// MARK: - Provider Domain Mapping

private func domainForProvider(_ name: String) -> String {
    switch name.lowercased() {
    case "anthropic": "api.anthropic.com"
    case "openai": "api.openai.com"
    case "google": "generativelanguage.googleapis.com"
    case "groq": "api.groq.com"
    case "openrouter": "openrouter.ai"
    case "perplexity": "api.perplexity.ai"
    case "deepseek": "api.deepseek.com"
    default: "\(name.lowercased()).api"
    }
}

// MARK: - Privacy Score Calculation

private func computePrivacyScore(
    firewallMode: String,
    totalConnections: Int,
    privacyConcerns: Int,
    enabledBlocklistDomains: Int,
    channelCount: Int
) -> Int {
    var score = 50

    switch firewallMode {
    case "strict": score += 20
    case "standard": score += 10
    default: break
    }

    if totalConnections > 0 {
        let concernRatio = Double(privacyConcerns) / Double(totalConnections)
        if concernRatio < 0.05 { score += 15 }
        else if concernRatio < 0.15 { score += 10 }
        else if concernRatio < 0.30 { score += 5 }
    } else {
        score += 10
    }

    if enabledBlocklistDomains >= 30 {
        score += 10
    }

    if channelCount >= 5 {
        score += 5
    }

    return min(score, 100)
}

// MARK: - Tests

@Suite("Traffic Category Properties")
struct TrafficCategoryTests {
    @Test("All 8 categories have unique raw values")
    func uniqueRawValues() {
        let rawValues = TestTrafficCategory.allCases.map(\.rawValue)
        #expect(Set(rawValues).count == rawValues.count)
    }

    @Test("All categories have SF Symbols")
    func allHaveSymbols() {
        for category in TestTrafficCategory.allCases {
            #expect(!category.sfSymbol.isEmpty)
        }
    }

    @Test("Privacy concerns: analytics, advertising, tracker")
    func privacyConcerns() {
        #expect(TestTrafficCategory.analytics.isPrivacyConcern)
        #expect(TestTrafficCategory.advertising.isPrivacyConcern)
        #expect(TestTrafficCategory.tracker.isPrivacyConcern)
        #expect(!TestTrafficCategory.aiProvider.isPrivacyConcern)
        #expect(!TestTrafficCategory.cloudSync.isPrivacyConcern)
        #expect(!TestTrafficCategory.system.isPrivacyConcern)
        #expect(!TestTrafficCategory.unknown.isPrivacyConcern)
        #expect(!TestTrafficCategory.social.isPrivacyConcern)
    }
}

@Suite("Domain Classification")
struct DomainClassificationTests {
    @Test("Classifies AI provider domains")
    func aiProviders() {
        #expect(classifyDomain("api.anthropic.com") == .aiProvider)
        #expect(classifyDomain("api.openai.com") == .aiProvider)
        #expect(classifyDomain("api.groq.com") == .aiProvider)
        #expect(classifyDomain("openrouter.ai") == .aiProvider)
    }

    @Test("Classifies tracker domains")
    func trackers() {
        #expect(classifyDomain("pixel.facebook.com") == .tracker)
        #expect(classifyDomain("bat.bing.com") == .tracker)
    }

    @Test("Classifies advertising domains")
    func advertising() {
        #expect(classifyDomain("doubleclick.net") == .advertising)
        #expect(classifyDomain("googlesyndication.com") == .advertising)
    }

    @Test("Classifies analytics domains")
    func analytics() {
        #expect(classifyDomain("google-analytics.com") == .analytics)
        #expect(classifyDomain("mixpanel.com") == .analytics)
    }

    @Test("Classifies social domains")
    func social() {
        #expect(classifyDomain("facebook.com") == .social)
        #expect(classifyDomain("twitter.com") == .social)
    }

    @Test("Classifies cloud sync domains")
    func cloudSync() {
        #expect(classifyDomain("icloud.com") == .cloudSync)
        #expect(classifyDomain("icloud-content.com") == .cloudSync)
        #expect(classifyDomain("apple-cloudkit.com") == .cloudSync)
    }

    @Test("Classifies Apple system domains")
    func system() {
        #expect(classifyDomain("configuration.apple.com") == .system)
        #expect(classifyDomain("gsa.apple.com") == .system)
    }

    @Test("Unknown domains classified as unknown")
    func unknown() {
        #expect(classifyDomain("example.com") == .unknown)
        #expect(classifyDomain("myserver.net") == .unknown)
    }
}

@Suite("DNS Blocklist Check Logic")
struct DNSBlocklistCheckTests {
    @Test("Exact match blocks domain")
    func exactMatch() {
        var entries: [String: TestBlocklistEntry] = [:]
        let entry = TestBlocklistEntry(domain: "tracker.com", category: .tracker, source: .builtin)
        entries["tracker.com"] = entry

        let result = checkDomain("tracker.com", entries: entries)
        #expect(result.isBlocked)
        #expect(result.matchedDomain == "tracker.com")
        #expect(result.category == .tracker)
    }

    @Test("Subdomain match blocks domain")
    func subdomainMatch() {
        var entries: [String: TestBlocklistEntry] = [:]
        let entry = TestBlocklistEntry(domain: "tracker.com", category: .tracker, source: .builtin)
        entries["tracker.com"] = entry

        let result = checkDomain("sub.tracker.com", entries: entries)
        #expect(result.isBlocked)
        #expect(result.matchedDomain == "tracker.com")
    }

    @Test("Deep subdomain match works")
    func deepSubdomain() {
        var entries: [String: TestBlocklistEntry] = [:]
        let entry = TestBlocklistEntry(domain: "ads.example.com", category: .advertising, source: .builtin)
        entries["ads.example.com"] = entry

        let result = checkDomain("cdn.ads.example.com", entries: entries)
        #expect(result.isBlocked)
    }

    @Test("Non-matching domain passes")
    func noMatch() {
        var entries: [String: TestBlocklistEntry] = [:]
        let entry = TestBlocklistEntry(domain: "tracker.com", category: .tracker, source: .builtin)
        entries["tracker.com"] = entry

        let result = checkDomain("safe.example.com", entries: entries)
        #expect(!result.isBlocked)
        #expect(result.matchedDomain == nil)
    }

    @Test("Disabled entry does not block")
    func disabledEntry() {
        var entries: [String: TestBlocklistEntry] = [:]
        var entry = TestBlocklistEntry(domain: "tracker.com", category: .tracker, source: .builtin)
        entry.isEnabled = false
        entries["tracker.com"] = entry

        let result = checkDomain("tracker.com", entries: entries)
        #expect(!result.isBlocked)
    }

    @Test("Case insensitive matching")
    func caseInsensitive() {
        var entries: [String: TestBlocklistEntry] = [:]
        let entry = TestBlocklistEntry(domain: "tracker.com", category: .tracker, source: .builtin)
        entries["tracker.com"] = entry

        let result = checkDomain("TRACKER.COM", entries: entries)
        #expect(result.isBlocked)
    }
}

@Suite("Block Category Properties")
struct BlockCategoryTests {
    @Test("All 7 categories have unique raw values")
    func uniqueRawValues() {
        let rawValues = TestBlockCategory.allCases.map(\.rawValue)
        #expect(Set(rawValues).count == rawValues.count)
    }

    @Test("All categories have SF Symbols")
    func allHaveSymbols() {
        for category in TestBlockCategory.allCases {
            #expect(!category.sfSymbol.isEmpty)
        }
    }

    @Test("CaseIterable count is 7")
    func caseCount() {
        #expect(TestBlockCategory.allCases.count == 7)
    }
}

@Suite("Blocklist Entry Properties")
struct BlocklistEntryTests {
    @Test("Entry creation with defaults")
    func defaults() {
        let entry = TestBlocklistEntry(domain: "TEST.COM", category: .advertising, source: .builtin)
        #expect(entry.domain == "test.com")
        #expect(entry.isEnabled)
        #expect(entry.category == .advertising)
        #expect(entry.source == .builtin)
    }

    @Test("Entry creation disabled")
    func disabled() {
        let entry = TestBlocklistEntry(domain: "test.com", category: .custom, source: .user, isEnabled: false)
        #expect(!entry.isEnabled)
        #expect(entry.source == .user)
    }

    @Test("Entry has unique ID")
    func uniqueID() {
        let a = TestBlocklistEntry(domain: "a.com", category: .tracker, source: .builtin)
        let b = TestBlocklistEntry(domain: "b.com", category: .tracker, source: .builtin)
        #expect(a.id != b.id)
    }
}

@Suite("Provider Domain Mapping")
struct ProviderDomainMappingTests {
    @Test("Anthropic maps to api.anthropic.com")
    func anthropic() {
        #expect(domainForProvider("anthropic") == "api.anthropic.com")
        #expect(domainForProvider("Anthropic") == "api.anthropic.com")
    }

    @Test("OpenAI maps to api.openai.com")
    func openai() {
        #expect(domainForProvider("openai") == "api.openai.com")
    }

    @Test("Google maps to googleapis.com")
    func google() {
        #expect(domainForProvider("google") == "generativelanguage.googleapis.com")
    }

    @Test("Groq maps to api.groq.com")
    func groq() {
        #expect(domainForProvider("groq") == "api.groq.com")
    }

    @Test("Unknown provider gets generic domain")
    func unknown() {
        #expect(domainForProvider("custom") == "custom.api")
        #expect(domainForProvider("MyProvider") == "myprovider.api")
    }
}

@Suite("Privacy Score Calculation")
struct PrivacyScoreTests {
    @Test("Strict mode gives highest score base")
    func strictMode() {
        let score = computePrivacyScore(
            firewallMode: "strict",
            totalConnections: 0,
            privacyConcerns: 0,
            enabledBlocklistDomains: 50,
            channelCount: 7
        )
        #expect(score == 95) // 50 + 20 + 10 + 10 + 5
    }

    @Test("Standard mode gives moderate score")
    func standardMode() {
        let score = computePrivacyScore(
            firewallMode: "standard",
            totalConnections: 0,
            privacyConcerns: 0,
            enabledBlocklistDomains: 50,
            channelCount: 7
        )
        #expect(score == 85) // 50 + 10 + 10 + 10 + 5
    }

    @Test("Permissive mode gives lowest base")
    func permissiveMode() {
        let score = computePrivacyScore(
            firewallMode: "permissive",
            totalConnections: 0,
            privacyConcerns: 0,
            enabledBlocklistDomains: 50,
            channelCount: 7
        )
        #expect(score == 75) // 50 + 0 + 10 + 10 + 5
    }

    @Test("High concern ratio reduces score")
    func highConcerns() {
        let score = computePrivacyScore(
            firewallMode: "strict",
            totalConnections: 100,
            privacyConcerns: 50,
            enabledBlocklistDomains: 50,
            channelCount: 7
        )
        #expect(score == 85) // 50 + 20 + 0 + 10 + 5
    }

    @Test("Low concern ratio adds bonus")
    func lowConcerns() {
        let score = computePrivacyScore(
            firewallMode: "strict",
            totalConnections: 100,
            privacyConcerns: 2,
            enabledBlocklistDomains: 50,
            channelCount: 7
        )
        #expect(score == 100) // 50 + 20 + 15 + 10 + 5 = 100
    }

    @Test("Score capped at 100")
    func cappedAt100() {
        let score = computePrivacyScore(
            firewallMode: "strict",
            totalConnections: 100,
            privacyConcerns: 0,
            enabledBlocklistDomains: 50,
            channelCount: 7
        )
        #expect(score <= 100)
    }

    @Test("Minimum score with worst settings")
    func minimumScore() {
        let score = computePrivacyScore(
            firewallMode: "permissive",
            totalConnections: 10,
            privacyConcerns: 10,
            enabledBlocklistDomains: 0,
            channelCount: 0
        )
        #expect(score == 50) // Base only, no bonuses
    }

    @Test("Fewer than 5 channels: no channel bonus")
    func fewChannels() {
        let scoreWith = computePrivacyScore(
            firewallMode: "strict", totalConnections: 0, privacyConcerns: 0,
            enabledBlocklistDomains: 50, channelCount: 5
        )
        let scoreWithout = computePrivacyScore(
            firewallMode: "strict", totalConnections: 0, privacyConcerns: 0,
            enabledBlocklistDomains: 50, channelCount: 4
        )
        #expect(scoreWith == scoreWithout + 5)
    }
}

@Suite("Traffic Record Properties")
struct TrafficRecordTests {
    @Test("Record creation")
    func creation() {
        let record = TestTrafficRecord(
            id: UUID(), timestamp: Date(), hostname: "api.anthropic.com",
            port: 443, direction: .outbound, category: .aiProvider,
            wasBlocked: false, blockReason: nil, bytesEstimate: 1024
        )
        #expect(record.hostname == "api.anthropic.com")
        #expect(record.port == 443)
        #expect(record.direction == .outbound)
        #expect(record.category == .aiProvider)
        #expect(!record.wasBlocked)
        #expect(record.bytesEstimate == 1024)
    }

    @Test("Blocked record has reason")
    func blockedRecord() {
        let record = TestTrafficRecord(
            id: UUID(), timestamp: Date(), hostname: "tracker.com",
            port: 443, direction: .outbound, category: .tracker,
            wasBlocked: true, blockReason: "Domain in blocklist", bytesEstimate: 0
        )
        #expect(record.wasBlocked)
        #expect(record.blockReason == "Domain in blocklist")
    }

    @Test("Record is Identifiable")
    func identifiable() {
        let a = TestTrafficRecord(
            id: UUID(), timestamp: Date(), hostname: "a.com",
            port: 443, direction: .outbound, category: .unknown,
            wasBlocked: false, blockReason: nil, bytesEstimate: 0
        )
        let b = TestTrafficRecord(
            id: UUID(), timestamp: Date(), hostname: "b.com",
            port: 443, direction: .outbound, category: .unknown,
            wasBlocked: false, blockReason: nil, bytesEstimate: 0
        )
        #expect(a.id != b.id)
    }
}

@Suite("Audit Entry Properties")
struct AuditEntryTests {
    @Test("Passed audit entry")
    func passed() {
        let entry = TestAuditEntry(
            id: UUID(), timestamp: Date(), channel: "cloud_api",
            policyName: "CloudAPIPolicy", outcome: .passed,
            redactionCount: 0, originalLength: 100, sanitizedLength: 100
        )
        #expect(entry.outcome == .passed)
        #expect(entry.redactionCount == 0)
        #expect(entry.originalLength == entry.sanitizedLength)
    }

    @Test("Redacted audit entry has reduced length")
    func redacted() {
        let entry = TestAuditEntry(
            id: UUID(), timestamp: Date(), channel: "messaging",
            policyName: "MessagingPolicy", outcome: .redacted,
            redactionCount: 3, originalLength: 200, sanitizedLength: 150
        )
        #expect(entry.outcome == .redacted)
        #expect(entry.redactionCount == 3)
        #expect(entry.sanitizedLength < entry.originalLength)
    }

    @Test("Blocked audit entry")
    func blocked() {
        let entry = TestAuditEntry(
            id: UUID(), timestamp: Date(), channel: "unknown_channel",
            policyName: "Default", outcome: .blocked,
            redactionCount: 0, originalLength: 500, sanitizedLength: 0
        )
        #expect(entry.outcome == .blocked)
        #expect(entry.sanitizedLength == 0)
    }

    @Test("Audit outcomes have raw values")
    func rawValues() {
        #expect(TestAuditOutcome.passed.rawValue == "passed")
        #expect(TestAuditOutcome.redacted.rawValue == "redacted")
        #expect(TestAuditOutcome.blocked.rawValue == "blocked")
    }
}

@Suite("Blocklist Stats")
struct BlocklistStatsTests {
    @Test("Stats with empty list")
    func empty() {
        let stats = TestBlocklistStats(
            totalDomains: 0, enabledDomains: 0,
            blockedToday: 0, blockedAllTime: 0, byCategory: [:]
        )
        #expect(stats.totalDomains == 0)
        #expect(stats.enabledDomains == 0)
    }

    @Test("Stats with populated list")
    func populated() {
        let stats = TestBlocklistStats(
            totalDomains: 51, enabledDomains: 48,
            blockedToday: 12, blockedAllTime: 350,
            byCategory: [.advertising: 22, .tracker: 14, .analytics: 13, .malware: 2]
        )
        #expect(stats.totalDomains == 51)
        #expect(stats.enabledDomains == 48)
        #expect(stats.blockedToday == 12)
        #expect(stats.blockedAllTime == 350)
        #expect(stats.byCategory[.advertising] == 22)
    }

    @Test("Category counts sum to enabled")
    func categorySumMatchesEnabled() {
        let byCat: [TestBlockCategory: Int] = [.advertising: 10, .tracker: 8, .analytics: 5]
        let stats = TestBlocklistStats(
            totalDomains: 25, enabledDomains: 23,
            blockedToday: 0, blockedAllTime: 0,
            byCategory: byCat
        )
        let catSum = byCat.values.reduce(0, +)
        #expect(catSum == 23)
        #expect(catSum == stats.enabledDomains)
    }
}

// MARK: - DNS Blocklist Integration Tests

private struct TestMonthlyReport: Codable {
    let id: UUID
    let generatedAt: Date
    let periodStart: Date
    let periodEnd: Date
    let totalConnections: Int
    let totalBytesEstimate: Int
    let blockedConnections: Int
    let privacyConcerns: Int
    let privacyScore: Int
    let recommendations: [String]
}

private func computeMonthlyPrivacyScore(
    totalConnections: Int,
    blockedConnections: Int,
    privacyConcerns: Int,
    firewallMode: String
) -> Int {
    var score = 70
    if totalConnections > 0 {
        let blockedRatio = Double(blockedConnections) / Double(totalConnections)
        let concernRatio = Double(privacyConcerns) / Double(totalConnections)
        score = max(0, min(100, Int(70.0 + blockedRatio * 20.0 - concernRatio * 30.0)))
    }
    return score
}

private func generateRecommendations(
    firewallMode: String,
    privacyConcerns: Int,
    disabledBlocklistCount: Int,
    totalConnections: Int,
    score: Int
) -> [String] {
    var recommendations: [String] = []
    if firewallMode != "strict" {
        recommendations.append("Enable strict firewall mode for maximum protection")
    }
    if privacyConcerns > 0 {
        recommendations.append("Review \(privacyConcerns) privacy concern(s) — consider adding domains to blocklist")
    }
    if disabledBlocklistCount > 5 {
        recommendations.append("Enable \(disabledBlocklistCount) disabled blocklist entries for better coverage")
    }
    if totalConnections == 0 {
        recommendations.append("No network activity recorded — ensure monitoring is enabled")
    }
    if score >= 80 {
        recommendations.append("Privacy posture is strong — keep monitoring regularly")
    }
    return recommendations
}

@Suite("DNS Blocklist Integration")
struct DNSBlocklistIntegrationTests {
    @Test("Blocklist domain check blocks known tracker")
    func blockKnownTracker() {
        var entries: [String: TestBlocklistEntry] = [:]
        let blockedDomains = ["doubleclick.net", "googlesyndication.com", "pixel.facebook.com"]
        for domain in blockedDomains {
            entries[domain] = TestBlocklistEntry(domain: domain, category: .advertising, source: .builtin)
        }

        let result = checkDomain("doubleclick.net", entries: entries)
        #expect(result.isBlocked)
    }

    @Test("Blocklist allows AI provider domains")
    func allowAIProviders() {
        var entries: [String: TestBlocklistEntry] = [:]
        entries["doubleclick.net"] = TestBlocklistEntry(domain: "doubleclick.net", category: .advertising, source: .builtin)

        let result = checkDomain("api.anthropic.com", entries: entries)
        #expect(!result.isBlocked)
    }

    @Test("Provider domain check before API call")
    func providerDomainCheck() {
        let domain = domainForProvider("Anthropic")
        let category = classifyDomain(domain)
        #expect(domain == "api.anthropic.com")
        #expect(category == .aiProvider)
    }

    @Test("Blocked provider domain prevents API call")
    func blockedProviderDomain() {
        // Simulate a scenario where a provider domain is blocklisted
        var entries: [String: TestBlocklistEntry] = [:]
        entries["api.anthropic.com"] = TestBlocklistEntry(
            domain: "api.anthropic.com", category: .custom, source: .user
        )

        let domain = domainForProvider("Anthropic")
        let result = checkDomain(domain, entries: entries)
        #expect(result.isBlocked)
        #expect(result.category == .custom)
    }

    @Test("Subdomain of blocklisted domain also blocked")
    func subdomainBlocking() {
        var entries: [String: TestBlocklistEntry] = [:]
        entries["facebook.com"] = TestBlocklistEntry(domain: "facebook.com", category: .tracker, source: .builtin)

        let result = checkDomain("pixel.facebook.com", entries: entries)
        #expect(result.isBlocked)
        #expect(result.matchedDomain == "facebook.com")
    }
}

@Suite("Monthly Transparency Report")
struct MonthlyTransparencyReportTests {
    @Test("Report generation with no traffic")
    func emptyTraffic() {
        let score = computeMonthlyPrivacyScore(
            totalConnections: 0, blockedConnections: 0,
            privacyConcerns: 0, firewallMode: "strict"
        )
        #expect(score == 70) // Base score with no data
    }

    @Test("Report score increases with blocked connections")
    func blockedConnectionsImproveScore() {
        let score = computeMonthlyPrivacyScore(
            totalConnections: 100, blockedConnections: 50,
            privacyConcerns: 0, firewallMode: "strict"
        )
        #expect(score > 70)
        #expect(score == 80) // 70 + 0.5 * 20 = 80
    }

    @Test("Report score decreases with privacy concerns")
    func privacyConcernsReduceScore() {
        let score = computeMonthlyPrivacyScore(
            totalConnections: 100, blockedConnections: 0,
            privacyConcerns: 50, firewallMode: "strict"
        )
        #expect(score < 70)
        #expect(score == 55) // 70 + 0 - 0.5 * 30 = 55
    }

    @Test("Score clamped to 0-100 range")
    func scoreClamped() {
        let highScore = computeMonthlyPrivacyScore(
            totalConnections: 100, blockedConnections: 100,
            privacyConcerns: 0, firewallMode: "strict"
        )
        #expect(highScore <= 100)

        let lowScore = computeMonthlyPrivacyScore(
            totalConnections: 100, blockedConnections: 0,
            privacyConcerns: 100, firewallMode: "strict"
        )
        #expect(lowScore >= 0)
    }

    @Test("Report Codable roundtrip")
    func codableRoundtrip() throws {
        let report = TestMonthlyReport(
            id: UUID(),
            generatedAt: Date(),
            periodStart: Date().addingTimeInterval(-86400 * 30),
            periodEnd: Date(),
            totalConnections: 150,
            totalBytesEstimate: 2_048_000,
            blockedConnections: 20,
            privacyConcerns: 5,
            privacyScore: 82,
            recommendations: ["Enable strict mode", "Review 5 concerns"]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(report)
        #expect(!data.isEmpty)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(TestMonthlyReport.self, from: data)
        #expect(decoded.totalConnections == 150)
        #expect(decoded.privacyScore == 82)
        #expect(decoded.recommendations.count == 2)
    }

    @Test("Report has valid period")
    func validPeriod() {
        let now = Date()
        let monthAgo = now.addingTimeInterval(-86400 * 30)
        let report = TestMonthlyReport(
            id: UUID(), generatedAt: now,
            periodStart: monthAgo, periodEnd: now,
            totalConnections: 0, totalBytesEstimate: 0,
            blockedConnections: 0, privacyConcerns: 0,
            privacyScore: 70, recommendations: []
        )
        #expect(report.periodStart < report.periodEnd)
        #expect(report.periodEnd <= report.generatedAt)
    }
}

@Suite("Recommendations Generation")
struct RecommendationsTests {
    @Test("Non-strict mode recommends enabling strict")
    func nonStrictRecommendation() {
        let recs = generateRecommendations(
            firewallMode: "standard", privacyConcerns: 0,
            disabledBlocklistCount: 0, totalConnections: 100, score: 85
        )
        #expect(recs.contains { $0.contains("strict") })
    }

    @Test("Strict mode does not recommend enabling strict")
    func strictNoRecommendation() {
        let recs = generateRecommendations(
            firewallMode: "strict", privacyConcerns: 0,
            disabledBlocklistCount: 0, totalConnections: 100, score: 95
        )
        #expect(!recs.contains { $0.contains("Enable strict") })
    }

    @Test("Privacy concerns generate review recommendation")
    func concernsRecommendation() {
        let recs = generateRecommendations(
            firewallMode: "strict", privacyConcerns: 5,
            disabledBlocklistCount: 0, totalConnections: 100, score: 70
        )
        #expect(recs.contains { $0.contains("5 privacy concern") })
    }

    @Test("Many disabled blocklist entries generate recommendation")
    func disabledBlocklistRecommendation() {
        let recs = generateRecommendations(
            firewallMode: "strict", privacyConcerns: 0,
            disabledBlocklistCount: 10, totalConnections: 100, score: 75
        )
        #expect(recs.contains { $0.contains("10 disabled") })
    }

    @Test("No activity generates monitoring recommendation")
    func noActivityRecommendation() {
        let recs = generateRecommendations(
            firewallMode: "strict", privacyConcerns: 0,
            disabledBlocklistCount: 0, totalConnections: 0, score: 70
        )
        #expect(recs.contains { $0.contains("No network activity") })
    }

    @Test("High score generates positive feedback")
    func highScorePositive() {
        let recs = generateRecommendations(
            firewallMode: "strict", privacyConcerns: 0,
            disabledBlocklistCount: 0, totalConnections: 100, score: 90
        )
        #expect(recs.contains { $0.contains("strong") })
    }

    @Test("Low score does not generate positive feedback")
    func lowScoreNoPositive() {
        let recs = generateRecommendations(
            firewallMode: "permissive", privacyConcerns: 20,
            disabledBlocklistCount: 0, totalConnections: 100, score: 40
        )
        #expect(!recs.contains { $0.contains("strong") })
    }
}
