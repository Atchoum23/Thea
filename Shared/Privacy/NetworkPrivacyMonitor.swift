//
//  NetworkPrivacyMonitor.swift
//  Thea
//
//  Real-time network connection monitoring with privacy-aware logging.
//  Tracks outbound connections, integrates with OutboundPrivacyGuard audit.
//

import Foundation
import Network
import os.log

/// Monitors network connections and records privacy-relevant traffic events.
/// Integrates with OutboundPrivacyGuard for unified audit trail.
actor NetworkPrivacyMonitor {
    static let shared = NetworkPrivacyMonitor()

    private let logger = Logger(subsystem: "app.thea", category: "NetworkPrivacyMonitor")

    // MARK: - Traffic Records

    struct TrafficRecord: Sendable, Identifiable, Codable {
        let id: UUID
        let timestamp: Date
        let hostname: String
        let port: UInt16
        let direction: Direction
        let category: TrafficCategory
        let wasBlocked: Bool
        let blockReason: String?
        let bytesEstimate: Int

        enum Direction: String, Codable, Sendable {
            case outbound
            case inbound
        }
    }

    enum TrafficCategory: String, Codable, Sendable, CaseIterable {
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

    // MARK: - Per-Service Stats

    struct ServiceStats: Sendable, Codable {
        let service: String
        var connectionCount: Int
        var bytesEstimate: Int
        var blockedCount: Int
        var lastSeen: Date
    }

    struct DailySnapshot: Sendable, Codable {
        let date: String
        let totalConnections: Int
        let totalBytes: Int
        let blockedConnections: Int
        let privacyConcerns: Int
        let byService: [String: ServiceStats]
        let byCategory: [String: Int]
    }

    // MARK: - State

    private(set) var isMonitoring = false
    private var trafficLog: [TrafficRecord] = []
    private var pathMonitor: NWPathMonitor?
    private var connectionCounts: [String: Int] = [:]
    private var blockedCounts: [TrafficCategory: Int] = [:]
    private var serviceStats: [String: ServiceStats] = [:]
    private var dailySnapshots: [DailySnapshot] = []
    private var dailyTrafficBytes: Int = 0
    private var lastResetDate: Date = .distantPast
    private let maxLogEntries = 5000
    private let maxSnapshots = 90
    private let snapshotKey = "NetworkPrivacyMonitor.snapshots"

// periphery:ignore - Reserved: maxSnapshots property reserved for future feature activation

    // MARK: - Domain Classification

    private static let aiProviderDomains: Set<String> = [
        "api.anthropic.com", "api.openai.com", "generativelanguage.googleapis.com",
        "api.groq.com", "openrouter.ai", "api.perplexity.ai", "api.deepseek.com"
    ]

    private static let analyticsDomains: Set<String> = [
        "google-analytics.com", "analytics.google.com", "segment.io",
        "mixpanel.com", "amplitude.com", "heap.io", "hotjar.com",
        "plausible.io", "matomo.org"
    ]

    private static let advertisingDomains: Set<String> = [
        "doubleclick.net", "googlesyndication.com", "googleadservices.com",
        "facebook.com/tr", "ads.linkedin.com", "ad.doubleclick.net",
        "pagead2.googlesyndication.com", "adservice.google.com"
    ]

    private static let trackerDomains: Set<String> = [
        "pixel.facebook.com", "t.co", "bat.bing.com", "tr.snapchat.com",
        "connect.facebook.net", "www.googletagmanager.com", "static.ads-twitter.com",
        "pixel.wp.com", "sb.scorecardresearch.com"
    ]

    private static let socialDomains: Set<String> = [
        "facebook.com", "instagram.com", "twitter.com", "x.com",
        "tiktok.com", "linkedin.com", "reddit.com", "threads.net"
    ]

    private static let cloudSyncDomains: Set<String> = [
        "icloud.com", "icloud-content.com", "apple-cloudkit.com",
        "cloudflare.com", "amazonaws.com"
    ]

    // MARK: - Lifecycle

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        resetDailyCountsIfNeeded()

        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            Task { [weak self] in
                await self?.handlePathUpdate(path)
            }
        }
        monitor.start(queue: DispatchQueue(label: "app.thea.network-privacy-monitor"))
        pathMonitor = monitor
        logger.info("Network privacy monitoring started")
    }

    func stopMonitoring() {
        isMonitoring = false
        pathMonitor?.cancel()
        pathMonitor = nil
        logger.info("Network privacy monitoring stopped")
    }

    // MARK: - Connection Recording

    /// Records an outbound connection for privacy tracking.
    func recordConnection(
        hostname: String,
        port: UInt16 = 443,
        bytesEstimate: Int = 0,
        wasBlocked: Bool = false,
        blockReason: String? = nil
    ) {
        resetDailyCountsIfNeeded()

        let category = classifyDomain(hostname)
        let record = TrafficRecord(
            id: UUID(),
            timestamp: Date(),
            hostname: hostname,
            port: port,
            direction: .outbound,
            category: category,
            wasBlocked: wasBlocked,
            blockReason: blockReason,
            bytesEstimate: bytesEstimate
        )

        trafficLog.append(record)
        connectionCounts[hostname, default: 0] += 1
        dailyTrafficBytes += bytesEstimate

        if wasBlocked {
            blockedCounts[category, default: 0] += 1
        }

        // Per-service tracking
        let serviceName = resolveServiceName(hostname)
        var stats = serviceStats[serviceName] ?? ServiceStats(
            service: serviceName, connectionCount: 0, bytesEstimate: 0, blockedCount: 0, lastSeen: Date()
        )
        stats.connectionCount += 1
        stats.bytesEstimate += bytesEstimate
        if wasBlocked { stats.blockedCount += 1 }
        stats.lastSeen = Date()
        serviceStats[serviceName] = stats

        if trafficLog.count > maxLogEntries {
            trafficLog = Array(trafficLog.suffix(maxLogEntries / 2))
        }
    }

    // MARK: - Queries

    func getRecentTraffic(limit: Int = 100) -> [TrafficRecord] {
        Array(trafficLog.suffix(limit).reversed())
    }

    func getTrafficByCategory() -> [(category: TrafficCategory, count: Int)] {
        var counts: [TrafficCategory: Int] = [:]
        for record in trafficLog {
            counts[record.category, default: 0] += 1
        }
        return counts.map { (category: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    func getBlockedTrafficCount() -> Int {
        trafficLog.filter(\.wasBlocked).count
    }

    func getPrivacyConcernCount() -> Int {
        trafficLog.filter { $0.category.isPrivacyConcern && !$0.wasBlocked }.count
    }

    func getTopDomains(limit: Int = 10) -> [(domain: String, count: Int)] {
        connectionCounts
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { (domain: $0.key, count: $0.value) }
    }

    func getDailyTrafficBytes() -> Int {
        resetDailyCountsIfNeeded()
        return dailyTrafficBytes
    }

    func getTotalConnections() -> Int {
        trafficLog.count
    }

    func clearLog() {
        trafficLog.removeAll()
        connectionCounts.removeAll()
        blockedCounts.removeAll()
        serviceStats.removeAll()
        dailyTrafficBytes = 0
        logger.info("Network privacy log cleared")
    }

    // MARK: - Per-Service Queries

    func getServiceStats() -> [ServiceStats] {
        serviceStats.values.sorted { $0.bytesEstimate > $1.bytesEstimate }
    }

    // periphery:ignore - Reserved: getServiceStats(for:) instance method — reserved for future feature activation
    func getServiceStats(for service: String) -> ServiceStats? {
        // periphery:ignore - Reserved: getServiceStats(for:) instance method reserved for future feature activation
        serviceStats[service]
    }

    // MARK: - Daily History

    func getDailySnapshots(days: Int = 30) -> [DailySnapshot] {
        Array(dailySnapshots.suffix(days))
    }

    // periphery:ignore - Reserved: saveDailySnapshot() instance method reserved for future feature activation
    func saveDailySnapshot() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateKey = formatter.string(from: Date())

        // Don't duplicate today's snapshot
        dailySnapshots.removeAll { $0.date == dateKey }

        var byCategory: [String: Int] = [:]
        for record in trafficLog {
            byCategory[record.category.rawValue, default: 0] += 1
        }

        let snapshot = DailySnapshot(
            date: dateKey,
            totalConnections: trafficLog.count,
            totalBytes: dailyTrafficBytes,
            blockedConnections: trafficLog.filter(\.wasBlocked).count,
            privacyConcerns: trafficLog.filter { $0.category.isPrivacyConcern && !$0.wasBlocked }.count,
            byService: serviceStats,
            byCategory: byCategory
        )
        dailySnapshots.append(snapshot)

        if dailySnapshots.count > maxSnapshots {
            dailySnapshots = Array(dailySnapshots.suffix(maxSnapshots))
        }

        do {
            let data = try JSONEncoder().encode(dailySnapshots)
            UserDefaults.standard.set(data, forKey: snapshotKey)
        } catch {
            logger.debug("Could not save daily snapshots: \(error.localizedDescription)")
        }
    }

    func loadDailySnapshots() {
        guard let data = UserDefaults.standard.data(forKey: snapshotKey) else { return }
        do {
            dailySnapshots = try JSONDecoder().decode([DailySnapshot].self, from: data)
        } catch {
            logger.debug("Could not load daily snapshots: \(error.localizedDescription)")
        }
    }

    // MARK: - Export

    struct TransparencyReportExport: Codable, Sendable {
        let generatedAt: Date
        let periodDays: Int
        let totalConnections: Int
        let totalBytesEstimate: Int
        let blockedConnections: Int
        let privacyConcerns: Int
        let serviceBreakdown: [ServiceStats]
        let categoryBreakdown: [String: Int]
        let topDomains: [String: Int]
        let dailyHistory: [DailySnapshot]
    }

    func generateExportReport(days: Int = 30) -> TransparencyReportExport {
        var categoryBreakdown: [String: Int] = [:]
        for record in trafficLog {
            categoryBreakdown[record.category.rawValue, default: 0] += 1
        }

        return TransparencyReportExport(
            generatedAt: Date(),
            periodDays: days,
            totalConnections: trafficLog.count,
            totalBytesEstimate: dailyTrafficBytes,
            blockedConnections: trafficLog.filter(\.wasBlocked).count,
            privacyConcerns: trafficLog.filter { $0.category.isPrivacyConcern && !$0.wasBlocked }.count,
            serviceBreakdown: getServiceStats(),
            categoryBreakdown: categoryBreakdown,
            topDomains: connectionCounts,
            dailyHistory: getDailySnapshots(days: days)
        )
    }

    func exportReportAsJSON(days: Int = 30) -> Data? {
        let report = generateExportReport(days: days)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        do {
            return try encoder.encode(report)
        } catch {
            logger.debug("Could not encode export report: \(error.localizedDescription)")
            return nil
        }
    }

    func exportReportAsCSV() -> String {
        var csv = "Date,Service,Connections,Bytes,Blocked,Concerns\n"
        for snapshot in dailySnapshots {
            for (service, stats) in snapshot.byService.sorted(by: { $0.key < $1.key }) {
                csv += "\(snapshot.date),\(service),\(stats.connectionCount),\(stats.bytesEstimate),\(stats.blockedCount),0\n"
            }
            if snapshot.byService.isEmpty {
                csv += "\(snapshot.date),all,\(snapshot.totalConnections),\(snapshot.totalBytes),\(snapshot.blockedConnections),\(snapshot.privacyConcerns)\n"
            }
        }
        return csv
    }

    // MARK: - Monthly Transparency Report

    private let monthlyReportKey = "NetworkPrivacyMonitor.monthlyReports"
    private let lastMonthlyReportKey = "NetworkPrivacyMonitor.lastMonthlyReport"

    struct MonthlyTransparencyReport: Codable, Sendable {
        let id: UUID
        let generatedAt: Date
        let periodStart: Date
        let periodEnd: Date
        let totalConnections: Int
        let totalBytesEstimate: Int
        let blockedConnections: Int
        let privacyConcerns: Int
        let privacyScore: Int
        let serviceBreakdown: [ServiceStats]
        let categoryBreakdown: [String: Int]
        let topDomains: [String: Int]
        let recommendations: [String]
    }

    /// Checks if a monthly report is due and generates one if so.
    /// Call this on app launch — it will only generate once per calendar month.
    func generateMonthlyReportIfDue() async -> MonthlyTransparencyReport? {
        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)

        // Check last report date
        if let lastReportDate = UserDefaults.standard.object(forKey: lastMonthlyReportKey) as? Date {
            let lastMonth = calendar.component(.month, from: lastReportDate)
            let lastYear = calendar.component(.year, from: lastReportDate)
            if lastMonth == currentMonth && lastYear == currentYear {
                return nil // Already generated this month
            }
        }

        // Generate the report for the previous month's data
        let report = await generateMonthlyReport()

        // Persist the report
        var existingReports = loadMonthlyReports()
        existingReports.append(report)
        // Keep last 12 months
        if existingReports.count > 12 {
            existingReports = Array(existingReports.suffix(12))
        }
        do {
            let data = try JSONEncoder().encode(existingReports)
            UserDefaults.standard.set(data, forKey: monthlyReportKey)
        } catch {
            logger.debug("Could not save monthly reports: \(error.localizedDescription)")
        }
        UserDefaults.standard.set(now, forKey: lastMonthlyReportKey)

        logger.info("Monthly transparency report generated for \(currentYear)-\(currentMonth)")
        return report
    }

    /// Generate a monthly report from accumulated data.
    private func generateMonthlyReport() async -> MonthlyTransparencyReport {
        let calendar = Calendar.current
        let now = Date()
        let periodStart = calendar.date(byAdding: .month, value: -1, to: now) ?? now

        var categoryBreakdown: [String: Int] = [:]
        for record in trafficLog {
            categoryBreakdown[record.category.rawValue, default: 0] += 1
        }

        let blocked = trafficLog.filter(\.wasBlocked).count
        let concerns = trafficLog.filter { $0.category.isPrivacyConcern && !$0.wasBlocked }.count
        let total = trafficLog.count

        // Compute privacy score (0-100)
        var score = 70 // Base score
        if total > 0 {
            let blockedRatio = Double(blocked) / Double(total)
            let concernRatio = Double(concerns) / Double(total)
            score = max(0, min(100, Int(70.0 + blockedRatio * 20.0 - concernRatio * 30.0)))
        }

        // Generate recommendations
        var recommendations: [String] = []
        let firewallMode = await OutboundPrivacyGuard.shared.mode
        if firewallMode != .strict {
            recommendations.append("Enable strict firewall mode for maximum protection")
        }
        if concerns > 0 {
            recommendations.append("Review \(concerns) privacy concern(s) — consider adding domains to blocklist")
        }
        let blocklistStats = await DNSBlocklistService.shared.getStats()
        let disabledCount = blocklistStats.totalDomains - blocklistStats.enabledDomains
        if disabledCount > 5 {
            recommendations.append("Enable \(disabledCount) disabled blocklist entries for better coverage")
        }
        if total == 0 {
            recommendations.append("No network activity recorded — ensure monitoring is enabled")
        }
        if score >= 80 {
            recommendations.append("Privacy posture is strong — keep monitoring regularly")
        }

        return MonthlyTransparencyReport(
            id: UUID(),
            generatedAt: now,
            periodStart: periodStart,
            periodEnd: now,
            totalConnections: total,
            totalBytesEstimate: dailyTrafficBytes,
            blockedConnections: blocked,
            privacyConcerns: concerns,
            privacyScore: score,
            serviceBreakdown: getServiceStats(),
            categoryBreakdown: categoryBreakdown,
            topDomains: connectionCounts,
            recommendations: recommendations
        )
    }

    /// Load previously generated monthly reports.
    func loadMonthlyReports() -> [MonthlyTransparencyReport] {
        guard let data = UserDefaults.standard.data(forKey: monthlyReportKey) else { return [] }
        do {
            return try JSONDecoder().decode([MonthlyTransparencyReport].self, from: data)
        } catch {
            logger.debug("Could not load monthly reports: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Domain Classification

    func classifyDomain(_ hostname: String) -> TrafficCategory {
        let lowered = hostname.lowercased()

        if Self.aiProviderDomains.contains(where: { lowered.matchesDomain($0) }) {
            return .aiProvider
        }
        if Self.trackerDomains.contains(where: { lowered.matchesDomain($0) }) {
            return .tracker
        }
        if Self.advertisingDomains.contains(where: { lowered.matchesDomain($0) }) {
            return .advertising
        }
        if Self.analyticsDomains.contains(where: { lowered.matchesDomain($0) }) {
            return .analytics
        }
        if Self.socialDomains.contains(where: { lowered.matchesDomain($0) }) {
            return .social
        }
        if Self.cloudSyncDomains.contains(where: { lowered.matchesDomain($0) }) {
            return .cloudSync
        }
        if lowered.hasSuffix(".apple.com") || lowered.hasSuffix(".apple-dns.net") {
            return .system
        }

        return .unknown
    }

    // MARK: - Private

    /// Maps a hostname to a human-readable service name.
    private func resolveServiceName(_ hostname: String) -> String {
        let lowered = hostname.lowercased()
        if lowered.contains("anthropic") { return "Anthropic" }
        if lowered.contains("openai") { return "OpenAI" }
        if lowered.contains("googleapis") { return "Google" }
        if lowered.contains("groq") { return "Groq" }
        if lowered.contains("openrouter") { return "OpenRouter" }
        if lowered.contains("perplexity") { return "Perplexity" }
        if lowered.contains("deepseek") { return "DeepSeek" }
        if lowered.contains("icloud") || lowered.contains("apple-cloudkit") { return "iCloud" }
        if lowered.hasSuffix(".apple.com") { return "Apple" }
        if lowered.contains("facebook") || lowered.contains("instagram") { return "Meta" }
        if lowered.contains("google-analytics") || lowered.contains("googletagmanager") { return "Google Analytics" }
        if lowered.contains("doubleclick") || lowered.contains("googlesyndication") { return "Google Ads" }
        // Use the second-level domain as fallback
        let parts = lowered.split(separator: ".")
        if parts.count >= 2 {
            return String(parts[parts.count - 2]).capitalized
        }
        return hostname
    }

    private func handlePathUpdate(_ path: NWPath) {
        if path.status == .satisfied {
            logger.debug("Network path satisfied: \(path.availableInterfaces.map(\.name).joined(separator: ", "))")
        }
    }

    private func resetDailyCountsIfNeeded() {
        let calendar = Calendar.current
        if !calendar.isDateInToday(lastResetDate) {
            dailyTrafficBytes = 0
            lastResetDate = Date()
        }
    }
}

// MARK: - Domain Matching Extension

extension String {
    /// Checks if this hostname matches the given domain exactly or as a subdomain.
    /// e.g., "sub.tracker.com".matchesDomain("tracker.com") == true
    ///        "tracker.com".matchesDomain("tracker.com") == true
    ///        "nottracker.com".matchesDomain("tracker.com") == false
    ///        "apple-cloudkit.com".matchesDomain("t.co") == false (fixes false positive)
    func matchesDomain(_ domain: String) -> Bool {
        if self == domain { return true }
        return hasSuffix(".\(domain)")
    }
}
