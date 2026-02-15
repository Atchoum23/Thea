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

    // MARK: - State

    private(set) var isMonitoring = false
    private var trafficLog: [TrafficRecord] = []
    private var pathMonitor: NWPathMonitor?
    private var connectionCounts: [String: Int] = [:]
    private var blockedCounts: [TrafficCategory: Int] = [:]
    private var dailyTrafficBytes: Int = 0
    private var lastResetDate: Date = .distantPast
    private let maxLogEntries = 5000

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
        dailyTrafficBytes = 0
        logger.info("Network privacy log cleared")
    }

    // MARK: - Domain Classification

    func classifyDomain(_ hostname: String) -> TrafficCategory {
        let lowered = hostname.lowercased()

        if Self.aiProviderDomains.contains(where: { lowered.contains($0) }) {
            return .aiProvider
        }
        if Self.trackerDomains.contains(where: { lowered.contains($0) }) {
            return .tracker
        }
        if Self.advertisingDomains.contains(where: { lowered.contains($0) }) {
            return .advertising
        }
        if Self.analyticsDomains.contains(where: { lowered.contains($0) }) {
            return .analytics
        }
        if Self.socialDomains.contains(where: { lowered.contains($0) }) {
            return .social
        }
        if Self.cloudSyncDomains.contains(where: { lowered.contains($0) }) {
            return .cloudSync
        }
        if lowered.hasSuffix(".apple.com") || lowered.hasSuffix(".apple-dns.net") {
            return .system
        }

        return .unknown
    }

    // MARK: - Private

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
