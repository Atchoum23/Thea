//
//  DNSBlocklistService.swift
//  Thea
//
//  Local DNS-level domain blocking with curated and custom blocklists.
//  Integrates with OutboundPrivacyGuard and NetworkPrivacyMonitor.
//

import Foundation
import os.log

/// Application-level domain blocklist service.
/// Blocks requests to known trackers, ad servers, and malware domains
/// before they reach OutboundPrivacyGuard's content sanitization layer.
actor DNSBlocklistService {
    static let shared = DNSBlocklistService()

    private let logger = Logger(subsystem: "app.thea", category: "DNSBlocklistService")

    // MARK: - Types

    struct BlocklistEntry: Sendable, Codable, Identifiable {
        let id: UUID
        let domain: String
        let category: BlockCategory
        let source: BlockSource
        let addedAt: Date
        var isEnabled: Bool

        init(domain: String, category: BlockCategory, source: BlockSource, isEnabled: Bool = true) {
            self.id = UUID()
            self.domain = domain.lowercased()
            self.category = category
            self.source = source
            self.addedAt = Date()
            self.isEnabled = isEnabled
        }
    }

    enum BlockCategory: String, Codable, Sendable, CaseIterable {
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

    enum BlockSource: String, Codable, Sendable {
        case builtin = "Built-in"
        case user = "User"
    }

    struct BlockCheckResult: Sendable {
        let isBlocked: Bool
        let matchedDomain: String?
        let category: BlockCategory?
    }

    struct BlocklistStats: Sendable {
        let totalDomains: Int
        let enabledDomains: Int
        let blockedToday: Int
        let blockedAllTime: Int
        let byCategory: [BlockCategory: Int]
    }

    // MARK: - State

    private var entries: [String: BlocklistEntry] = [:]
    private var wildcardPatterns: [(suffix: String, entry: BlocklistEntry)] = []
    private var blockedCountToday: Int = 0
    private var blockedCountTotal: Int = 0
    private var lastResetDate: Date = .distantPast
    private(set) var isEnabled = true
    private let storageKey = "DNSBlocklistService.entries"
    private let statsKey = "DNSBlocklistService.stats"

    // MARK: - Initialization

    init() {
        // Inline persistence load (cannot call actor-isolated methods from init)
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let persisted = try? JSONDecoder().decode([BlocklistEntry].self, from: data) {
            for entry in persisted {
                entries[entry.domain] = entry
            }
            let statsData = UserDefaults.standard.dictionary(forKey: statsKey)
            blockedCountTotal = statsData?["total"] as? Int ?? 0
        }

        if entries.isEmpty {
            // Inline built-in blocklists
            let adDomains = [
                "doubleclick.net", "googlesyndication.com", "googleadservices.com",
                "adservice.google.com", "pagead2.googlesyndication.com",
                "ad.doubleclick.net", "ads.linkedin.com", "ads-twitter.com",
                "adsserver.com", "adnxs.com", "adzerk.net", "moatads.com",
                "serving-sys.com", "bidswitch.net", "casalemedia.com",
                "contextweb.com", "criteo.com", "pubmatic.com", "rubiconproject.com",
                "taboola.com", "outbrain.com", "mgid.com"
            ]
            let trackerDomains = [
                "pixel.facebook.com", "connect.facebook.net", "pixel.wp.com",
                "sb.scorecardresearch.com", "bat.bing.com", "tr.snapchat.com",
                "static.ads-twitter.com", "t.co", "tags.tiqcdn.com",
                "cdn.mxpnl.com", "ct.pinterest.com", "dc.ads.linkedin.com",
                "smetrics.att.com", "b.scorecardresearch.com"
            ]
            let analyticsDomains = [
                "google-analytics.com", "googletagmanager.com", "segment.io",
                "mixpanel.com", "amplitude.com", "hotjar.com", "heap.io",
                "fullstory.com", "mouseflow.com", "crazyegg.com",
                "kissmetrics.io", "optimizely.com", "quantserve.com"
            ]
            let malwareDomains = ["malware-check.com.example", "phishing-test.example"]

            for domain in adDomains {
                let entry = BlocklistEntry(domain: domain, category: .advertising, source: .builtin)
                entries[entry.domain] = entry
            }
            for domain in trackerDomains {
                let entry = BlocklistEntry(domain: domain, category: .tracker, source: .builtin)
                entries[entry.domain] = entry
            }
            for domain in analyticsDomains {
                let entry = BlocklistEntry(domain: domain, category: .analytics, source: .builtin)
                entries[entry.domain] = entry
            }
            for domain in malwareDomains {
                let entry = BlocklistEntry(domain: domain, category: .malware, source: .builtin)
                entries[entry.domain] = entry
            }
        }
    }

    // MARK: - Public API

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        logger.info("DNS blocklist \(enabled ? "enabled" : "disabled")")
    }

    /// Checks if a domain should be blocked.
    func checkDomain(_ domain: String) -> BlockCheckResult {
        guard isEnabled else {
            return BlockCheckResult(isBlocked: false, matchedDomain: nil, category: nil)
        }

        resetDailyCountsIfNeeded()
        let lowered = domain.lowercased()

        // Exact match
        if let entry = entries[lowered], entry.isEnabled {
            recordBlock()
            return BlockCheckResult(isBlocked: true, matchedDomain: entry.domain, category: entry.category)
        }

        // Subdomain match (e.g., "sub.tracker.com" matches "tracker.com")
        let components = lowered.split(separator: ".")
        for startIndex in 1..<components.count {
            let parentDomain = components[startIndex...].joined(separator: ".")
            if let entry = entries[parentDomain], entry.isEnabled {
                recordBlock()
                return BlockCheckResult(isBlocked: true, matchedDomain: entry.domain, category: entry.category)
            }
        }

        // Wildcard pattern match
        for pattern in wildcardPatterns where pattern.entry.isEnabled {
            if lowered.hasSuffix(pattern.suffix) {
                recordBlock()
                return BlockCheckResult(isBlocked: true, matchedDomain: pattern.entry.domain, category: pattern.entry.category)
            }
        }

        return BlockCheckResult(isBlocked: false, matchedDomain: nil, category: nil)
    }

    /// Adds a custom domain to the blocklist.
    func addDomain(_ domain: String, category: BlockCategory = .custom) {
        let entry = BlocklistEntry(domain: domain, category: category, source: .user)
        entries[entry.domain] = entry
        persistEntries()
        logger.info("Added domain to blocklist: \(domain)")
    }

    /// Removes a domain from the blocklist.
    func removeDomain(_ domain: String) {
        entries.removeValue(forKey: domain.lowercased())
        wildcardPatterns.removeAll { $0.entry.domain == domain.lowercased() }
        persistEntries()
    }

    /// Toggles a domain entry on/off.
    func toggleDomain(_ domain: String, enabled: Bool) {
        let lowered = domain.lowercased()
        if var entry = entries[lowered] {
            entry.isEnabled = enabled
            entries[lowered] = entry
            persistEntries()
        }
    }

    func getEntries(category: BlockCategory? = nil) -> [BlocklistEntry] {
        let all = Array(entries.values)
        if let category {
            return all.filter { $0.category == category }.sorted { $0.domain < $1.domain }
        }
        return all.sorted { $0.domain < $1.domain }
    }

    func getUserEntries() -> [BlocklistEntry] {
        entries.values.filter { $0.source == .user }.sorted { $0.domain < $1.domain }
    }

    func getStats() -> BlocklistStats {
        resetDailyCountsIfNeeded()
        var byCategory: [BlockCategory: Int] = [:]
        for entry in entries.values where entry.isEnabled {
            byCategory[entry.category, default: 0] += 1
        }
        return BlocklistStats(
            totalDomains: entries.count,
            enabledDomains: entries.values.filter(\.isEnabled).count,
            blockedToday: blockedCountToday,
            blockedAllTime: blockedCountTotal,
            byCategory: byCategory
        )
    }

    func resetStats() {
        blockedCountToday = 0
        blockedCountTotal = 0
    }

    // MARK: - Built-in Lists

    private func loadBuiltinBlocklists() {
        // Advertising domains
        let adDomains = [
            "doubleclick.net", "googlesyndication.com", "googleadservices.com",
            "adservice.google.com", "pagead2.googlesyndication.com",
            "ad.doubleclick.net", "ads.linkedin.com", "ads-twitter.com",
            "adsserver.com", "adnxs.com", "adzerk.net", "moatads.com",
            "serving-sys.com", "bidswitch.net", "casalemedia.com",
            "contextweb.com", "criteo.com", "pubmatic.com", "rubiconproject.com",
            "taboola.com", "outbrain.com", "mgid.com"
        ]

        // Tracker domains
        let trackerDomains = [
            "pixel.facebook.com", "connect.facebook.net", "pixel.wp.com",
            "sb.scorecardresearch.com", "bat.bing.com", "tr.snapchat.com",
            "static.ads-twitter.com", "t.co", "tags.tiqcdn.com",
            "cdn.mxpnl.com", "ct.pinterest.com", "dc.ads.linkedin.com",
            "smetrics.att.com", "b.scorecardresearch.com"
        ]

        // Analytics domains
        let analyticsDomains = [
            "google-analytics.com", "googletagmanager.com", "segment.io",
            "mixpanel.com", "amplitude.com", "hotjar.com", "heap.io",
            "fullstory.com", "mouseflow.com", "crazyegg.com",
            "kissmetrics.io", "optimizely.com", "quantserve.com"
        ]

        // Malware/phishing domains (examples only — in production, use updated threat feeds)
        let malwareDomains = [
            "malware-check.com.example", "phishing-test.example"
        ]

        for domain in adDomains {
            let entry = BlocklistEntry(domain: domain, category: .advertising, source: .builtin)
            entries[entry.domain] = entry
        }
        for domain in trackerDomains {
            let entry = BlocklistEntry(domain: domain, category: .tracker, source: .builtin)
            entries[entry.domain] = entry
        }
        for domain in analyticsDomains {
            let entry = BlocklistEntry(domain: domain, category: .analytics, source: .builtin)
            entries[entry.domain] = entry
        }
        for domain in malwareDomains {
            let entry = BlocklistEntry(domain: domain, category: .malware, source: .builtin)
            entries[entry.domain] = entry
        }

        persistEntries()
        logger.info("Loaded \(self.entries.count) built-in blocklist entries")
    }

    // MARK: - Persistence

    private func persistEntries() {
        let allEntries = Array(entries.values)
        if let data = try? JSONEncoder().encode(allEntries) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadPersistedEntries() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let persisted = try? JSONDecoder().decode([BlocklistEntry].self, from: data)
        else { return }

        for entry in persisted {
            entries[entry.domain] = entry
        }

        let statsData = UserDefaults.standard.dictionary(forKey: statsKey)
        blockedCountTotal = statsData?["total"] as? Int ?? 0
    }

    private func recordBlock() {
        blockedCountToday += 1
        blockedCountTotal += 1
        if blockedCountTotal % 50 == 0 {
            UserDefaults.standard.set(["total": blockedCountTotal], forKey: statsKey)
        }
    }

    private func resetDailyCountsIfNeeded() {
        if !Calendar.current.isDateInToday(lastResetDate) {
            blockedCountToday = 0
            lastResetDate = Date()
        }
    }
}
