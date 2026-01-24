// TheaAdBlocker.swift
// Advanced ad blocking and tracker prevention
// Features: filter lists, element hiding, network blocking, anti-anti-adblock

import Foundation
import OSLog
import Combine

// MARK: - Ad Blocker Manager

@MainActor
public final class TheaAdBlockerManager: ObservableObject {
    public static let shared = TheaAdBlockerManager()

    private let logger = Logger(subsystem: "com.thea.extension", category: "AdBlocker")

    // MARK: - Published State

    @Published public var isEnabled = true
    @Published public private(set) var filterLists: [FilterList] = []
    @Published public private(set) var whitelist: Set<String> = []
    @Published public private(set) var stats = AdBlockerStats()
    @Published public var settings = AdBlockerSettings()

    // MARK: - Private Properties

    private var blockingRules: [BlockingRule] = []
    private var cosmeticRules: [CosmeticRule] = []
    private var exceptionRules: [ExceptionRule] = []

    // MARK: - Default Filter Lists

    public static let defaultFilterLists: [FilterList] = [
        FilterList(
            id: "easylist",
            name: "EasyList",
            description: "Primary filter list for ad blocking",
            url: URL(string: "https://easylist.to/easylist/easylist.txt")!,
            category: .ads,
            isEnabled: true,
            isBuiltIn: true
        ),
        FilterList(
            id: "easyprivacy",
            name: "EasyPrivacy",
            description: "Blocks tracking scripts and pixels",
            url: URL(string: "https://easylist.to/easylist/easyprivacy.txt")!,
            category: .privacy,
            isEnabled: true,
            isBuiltIn: true
        ),
        FilterList(
            id: "fanboy-annoyance",
            name: "Fanboy's Annoyance List",
            description: "Blocks cookie notices, social widgets, and other annoyances",
            url: URL(string: "https://easylist.to/easylist/fanboy-annoyance.txt")!,
            category: .annoyances,
            isEnabled: true,
            isBuiltIn: true
        ),
        FilterList(
            id: "ublock-filters",
            name: "uBlock Filters",
            description: "Additional filters maintained by uBlock Origin",
            url: URL(string: "https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/filters.txt")!,
            category: .ads,
            isEnabled: true,
            isBuiltIn: true
        ),
        FilterList(
            id: "ublock-privacy",
            name: "uBlock Privacy",
            description: "Privacy-focused filters",
            url: URL(string: "https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/privacy.txt")!,
            category: .privacy,
            isEnabled: true,
            isBuiltIn: true
        ),
        FilterList(
            id: "ublock-badware",
            name: "uBlock Badware",
            description: "Blocks malware and badware",
            url: URL(string: "https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/badware.txt")!,
            category: .security,
            isEnabled: true,
            isBuiltIn: true
        ),
        FilterList(
            id: "peter-lowe",
            name: "Peter Lowe's Ad/Tracking Server List",
            description: "Ad and tracking server blocklist",
            url: URL(string: "https://pgl.yoyo.org/adservers/serverlist.php?hostformat=adblockplus&showintro=1&mimetype=plaintext")!,
            category: .ads,
            isEnabled: false,
            isBuiltIn: true
        ),
        FilterList(
            id: "adguard-mobile",
            name: "AdGuard Mobile Ads",
            description: "Blocks mobile ads",
            url: URL(string: "https://raw.githubusercontent.com/AdguardTeam/FiltersRegistry/master/filters/filter_11_Mobile/filter.txt")!,
            category: .ads,
            isEnabled: false,
            isBuiltIn: true
        ),
        FilterList(
            id: "anti-adblock",
            name: "Anti-AdBlock Killer",
            description: "Circumvents anti-adblock scripts",
            url: URL(string: "https://raw.githubusercontent.com/nickspaargaren/anti-adblock-killer/master/anti-adblock-killer-filters.txt")!,
            category: .annoyances,
            isEnabled: false,
            isBuiltIn: true
        )
    ]

    // MARK: - Initialization

    private init() {
        loadSettings()
        loadFilterLists()
        loadWhitelist()
        loadStats()

        Task {
            await compileRules()
        }
    }

    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: "adBlocker.settings"),
           let loaded = try? JSONDecoder().decode(AdBlockerSettings.self, from: data) {
            settings = loaded
            isEnabled = settings.enabled
        }
    }

    public func saveSettings() {
        settings.enabled = isEnabled
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: "adBlocker.settings")
        }
    }

    private func loadFilterLists() {
        if let data = UserDefaults.standard.data(forKey: "adBlocker.filterLists"),
           let loaded = try? JSONDecoder().decode([FilterList].self, from: data) {
            filterLists = loaded
        } else {
            filterLists = Self.defaultFilterLists
        }
    }

    private func saveFilterLists() {
        if let data = try? JSONEncoder().encode(filterLists) {
            UserDefaults.standard.set(data, forKey: "adBlocker.filterLists")
        }
    }

    private func loadWhitelist() {
        if let list = UserDefaults.standard.stringArray(forKey: "adBlocker.whitelist") {
            whitelist = Set(list)
        }
    }

    private func saveWhitelist() {
        UserDefaults.standard.set(Array(whitelist), forKey: "adBlocker.whitelist")
    }

    private func loadStats() {
        if let data = UserDefaults.standard.data(forKey: "adBlocker.stats"),
           let loaded = try? JSONDecoder().decode(AdBlockerStats.self, from: data) {
            stats = loaded
        }
    }

    private func saveStats() {
        if let data = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(data, forKey: "adBlocker.stats")
        }
    }

    // MARK: - Blocking

    /// Block ads on a page
    public func blockAds(on page: PageContext) async throws -> BlockingResult {
        guard isEnabled else {
            return BlockingResult(adsBlocked: 0, trackersBlocked: 0, scriptsBlocked: 0, elementsHidden: 0, dataSaved: 0)
        }

        // Check whitelist
        if isWhitelisted(page.domain) {
            return BlockingResult(adsBlocked: 0, trackersBlocked: 0, scriptsBlocked: 0, elementsHidden: 0, dataSaved: 0)
        }

        var adsBlocked = 0
        var trackersBlocked = 0
        var scriptsBlocked = 0
        var elementsHidden = 0
        var dataSaved = 0

        // Apply cosmetic rules
        let cosmeticSelectors = getCosmeticSelectors(for: page.domain)
        elementsHidden = cosmeticSelectors.count

        // Update stats
        stats.totalAdsBlocked += adsBlocked
        stats.totalTrackersBlocked += trackersBlocked
        stats.totalScriptsBlocked += scriptsBlocked
        stats.totalElementsHidden += elementsHidden
        stats.totalDataSaved += dataSaved
        stats.updateDomainStats(page.domain, blocked: adsBlocked + trackersBlocked)
        saveStats()

        // Update extension stats
        TheaExtensionState.shared.stats.adsBlocked += adsBlocked
        TheaExtensionState.shared.stats.trackersBlocked += trackersBlocked
        TheaExtensionState.shared.stats.dataSaved += dataSaved

        logger.debug("Blocked \(adsBlocked) ads, \(trackersBlocked) trackers on \(page.domain)")

        return BlockingResult(
            adsBlocked: adsBlocked,
            trackersBlocked: trackersBlocked,
            scriptsBlocked: scriptsBlocked,
            elementsHidden: elementsHidden,
            dataSaved: dataSaved
        )
    }

    /// Check if a request should be blocked
    public func shouldBlock(request: NetworkRequest) -> BlockDecision {
        guard isEnabled else {
            return BlockDecision(shouldBlock: false, reason: nil, rule: nil)
        }

        // Check whitelist
        if let sourceHost = request.sourceURL?.host, isWhitelisted(sourceHost) {
            return BlockDecision(shouldBlock: false, reason: nil, rule: nil)
        }

        // Check exception rules first
        for exception in exceptionRules {
            if exception.matches(request) {
                return BlockDecision(shouldBlock: false, reason: "Exception rule", rule: exception.raw)
            }
        }

        // Check blocking rules
        for rule in blockingRules {
            if rule.matches(request) {
                return BlockDecision(
                    shouldBlock: true,
                    reason: rule.category.rawValue,
                    rule: rule.raw
                )
            }
        }

        return BlockDecision(shouldBlock: false, reason: nil, rule: nil)
    }

    /// Get cosmetic selectors for hiding elements
    public func getCosmeticSelectors(for domain: String) -> [String] {
        guard isEnabled && !isWhitelisted(domain) else {
            return []
        }

        return cosmeticRules
            .filter { $0.appliesTo(domain: domain) }
            .map { $0.selector }
    }

    /// Get CSS for element hiding
    public func getCosmeticCSS(for domain: String) -> String {
        let selectors = getCosmeticSelectors(for: domain)
        guard !selectors.isEmpty else { return "" }

        return selectors.joined(separator: ",\n") + " { display: none !important; visibility: hidden !important; }"
    }

    // MARK: - Whitelist Management

    /// Add domain to whitelist
    public func whitelistDomain(_ domain: String) {
        let normalized = normalizeDomain(domain)
        whitelist.insert(normalized)
        saveWhitelist()
        logger.info("Whitelisted domain: \(normalized)")
    }

    /// Remove domain from whitelist
    public func removeFromWhitelist(_ domain: String) {
        let normalized = normalizeDomain(domain)
        whitelist.remove(normalized)
        saveWhitelist()
        logger.info("Removed from whitelist: \(normalized)")
    }

    /// Check if domain is whitelisted
    public func isWhitelisted(_ domain: String) -> Bool {
        let normalized = normalizeDomain(domain)

        // Check exact match
        if whitelist.contains(normalized) {
            return true
        }

        // Check parent domains
        var parts = normalized.split(separator: ".")
        while parts.count > 1 {
            parts.removeFirst()
            let parentDomain = parts.joined(separator: ".")
            if whitelist.contains(parentDomain) {
                return true
            }
        }

        return false
    }

    // MARK: - Filter List Management

    /// Update all filter lists
    public func updateFilterLists() async throws {
        logger.info("Updating filter lists...")

        for i in filterLists.indices where filterLists[i].isEnabled {
            do {
                try await updateFilterList(filterLists[i].id)
            } catch {
                logger.error("Failed to update \(filterLists[i].name): \(error.localizedDescription)")
            }
        }

        await compileRules()

        logger.info("Filter lists updated")
    }

    /// Update a specific filter list
    public func updateFilterList(_ listId: String) async throws {
        guard let index = filterLists.firstIndex(where: { $0.id == listId }) else {
            throw AdBlockerError.filterListNotFound
        }

        let list = filterLists[index]

        // Download the list
        let (data, _) = try await URLSession.shared.data(from: list.url)
        guard let content = String(data: data, encoding: .utf8) else {
            throw AdBlockerError.invalidFilterList
        }

        // Parse rules
        let rules = parseFilterList(content)

        // Update list metadata
        filterLists[index].lastUpdated = Date()
        filterLists[index].ruleCount = rules.count
        saveFilterLists()

        // Save rules
        try saveFilterRules(rules, for: listId)
    }

    /// Enable/disable a filter list
    public func setFilterListEnabled(_ listId: String, enabled: Bool) async {
        guard let index = filterLists.firstIndex(where: { $0.id == listId }) else {
            return
        }

        filterLists[index].isEnabled = enabled
        saveFilterLists()

        // Recompile rules
        await compileRules()
    }

    /// Add a custom filter list
    public func addCustomFilterList(name: String, url: URL) async throws {
        // Validate URL
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let content = String(data: data, encoding: .utf8) else {
            throw AdBlockerError.invalidFilterList
        }

        let rules = parseFilterList(content)

        let list = FilterList(
            id: UUID().uuidString,
            name: name,
            description: "Custom filter list",
            url: url,
            category: .custom,
            isEnabled: true,
            isBuiltIn: false,
            ruleCount: rules.count,
            lastUpdated: Date()
        )

        filterLists.append(list)
        saveFilterLists()

        try saveFilterRules(rules, for: list.id)
        await compileRules()
    }

    /// Remove a custom filter list
    public func removeFilterList(_ listId: String) async {
        filterLists.removeAll { $0.id == listId && !$0.isBuiltIn }
        saveFilterLists()

        // Delete saved rules
        UserDefaults.standard.removeObject(forKey: "adBlocker.rules.\(listId)")

        await compileRules()
    }

    // MARK: - Statistics

    /// Get blocking statistics
    public func getBlockingStats() -> AdBlockerStats {
        return stats
    }

    /// Reset statistics
    public func resetStats() {
        stats = AdBlockerStats()
        saveStats()
    }

    // MARK: - Rule Parsing

    private func parseFilterList(_ content: String) -> [ParsedRule] {
        var rules: [ParsedRule] = []

        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip comments and empty lines
            if trimmed.isEmpty || trimmed.hasPrefix("!") || trimmed.hasPrefix("[") {
                continue
            }

            if let rule = parseRule(trimmed) {
                rules.append(rule)
            }
        }

        return rules
    }

    private func parseRule(_ line: String) -> ParsedRule? {
        // Exception rules start with @@
        if line.hasPrefix("@@") {
            let pattern = String(line.dropFirst(2))
            return ParsedRule(type: .exception, pattern: pattern, raw: line)
        }

        // Cosmetic rules contain ##
        if line.contains("##") {
            let parts = line.components(separatedBy: "##")
            let domains = parts[0].isEmpty ? nil : parts[0]
            let selector = parts.count > 1 ? parts[1] : ""
            return ParsedRule(type: .cosmetic, pattern: selector, domains: domains, raw: line)
        }

        // Cosmetic exception rules contain #@#
        if line.contains("#@#") {
            let parts = line.components(separatedBy: "#@#")
            let domains = parts[0].isEmpty ? nil : parts[0]
            let selector = parts.count > 1 ? parts[1] : ""
            return ParsedRule(type: .cosmeticException, pattern: selector, domains: domains, raw: line)
        }

        // Network rules
        return ParsedRule(type: .network, pattern: line, raw: line)
    }

    private func compileRules() async {
        blockingRules.removeAll()
        cosmeticRules.removeAll()
        exceptionRules.removeAll()

        for list in filterLists where list.isEnabled {
            guard let rules = loadFilterRules(for: list.id) else { continue }

            for rule in rules {
                switch rule.type {
                case .network:
                    if let compiled = compileNetworkRule(rule) {
                        blockingRules.append(compiled)
                    }
                case .exception:
                    if let compiled = compileExceptionRule(rule) {
                        exceptionRules.append(compiled)
                    }
                case .cosmetic:
                    if let compiled = compileCosmeticRule(rule) {
                        cosmeticRules.append(compiled)
                    }
                case .cosmeticException:
                    // Handle cosmetic exceptions
                    break
                }
            }
        }

        logger.info("Compiled \(blockingRules.count) blocking, \(cosmeticRules.count) cosmetic, \(exceptionRules.count) exception rules")
    }

    private func compileNetworkRule(_ rule: ParsedRule) -> BlockingRule? {
        // Simplified rule compilation
        // In production, this would be a full AdBlock Plus syntax parser

        var pattern = rule.pattern
        var category: BlockCategory = .ads

        // Detect category from options
        if pattern.contains("third-party") {
            category = .tracking
        }
        if pattern.contains("script") {
            category = .scripts
        }

        // Convert to regex pattern
        pattern = pattern
            .replacingOccurrences(of: "||", with: "^https?://([^/]+\\.)?")
            .replacingOccurrences(of: "|", with: "^")
            .replacingOccurrences(of: "^", with: "[^a-zA-Z0-9_.-]")
            .replacingOccurrences(of: "*", with: ".*")

        return BlockingRule(
            pattern: pattern,
            category: category,
            raw: rule.raw
        )
    }

    private func compileExceptionRule(_ rule: ParsedRule) -> ExceptionRule? {
        var pattern = rule.pattern
            .replacingOccurrences(of: "||", with: "^https?://([^/]+\\.)?")
            .replacingOccurrences(of: "|", with: "^")
            .replacingOccurrences(of: "^", with: "[^a-zA-Z0-9_.-]")
            .replacingOccurrences(of: "*", with: ".*")

        return ExceptionRule(pattern: pattern, raw: rule.raw)
    }

    private func compileCosmeticRule(_ rule: ParsedRule) -> CosmeticRule? {
        return CosmeticRule(
            selector: rule.pattern,
            domains: rule.domains?.components(separatedBy: ","),
            excludedDomains: nil,
            raw: rule.raw
        )
    }

    private func saveFilterRules(_ rules: [ParsedRule], for listId: String) throws {
        let data = try JSONEncoder().encode(rules)
        UserDefaults.standard.set(data, forKey: "adBlocker.rules.\(listId)")
    }

    private func loadFilterRules(for listId: String) -> [ParsedRule]? {
        guard let data = UserDefaults.standard.data(forKey: "adBlocker.rules.\(listId)"),
              let rules = try? JSONDecoder().decode([ParsedRule].self, from: data) else {
            return nil
        }
        return rules
    }

    // MARK: - Helpers

    private func normalizeDomain(_ domain: String) -> String {
        var normalized = domain.lowercased()

        if let range = normalized.range(of: "://") {
            normalized = String(normalized[range.upperBound...])
        }

        if normalized.hasPrefix("www.") {
            normalized = String(normalized.dropFirst(4))
        }

        if let slashIndex = normalized.firstIndex(of: "/") {
            normalized = String(normalized[..<slashIndex])
        }

        return normalized
    }
}

// MARK: - Supporting Types

public struct AdBlockerSettings: Codable {
    public var enabled: Bool = true
    public var blockAds: Bool = true
    public var blockTrackers: Bool = true
    public var blockMalware: Bool = true
    public var blockAnnoyances: Bool = true
    public var cosmetic: Bool = true
    public var antiAntiAdblock: Bool = true
    public var updateInterval: TimeInterval = 86400 // 24 hours
}

public struct FilterList: Codable, Identifiable {
    public let id: String
    public var name: String
    public var description: String
    public var url: URL
    public var category: FilterCategory
    public var isEnabled: Bool
    public var isBuiltIn: Bool
    public var ruleCount: Int = 0
    public var lastUpdated: Date?

    public enum FilterCategory: String, Codable {
        case ads
        case privacy
        case annoyances
        case security
        case regional
        case custom
    }
}

public struct AdBlockerStats: Codable {
    public var totalAdsBlocked: Int = 0
    public var totalTrackersBlocked: Int = 0
    public var totalScriptsBlocked: Int = 0
    public var totalElementsHidden: Int = 0
    public var totalDataSaved: Int = 0
    public var blockedByDomain: [String: Int] = [:]
    public var blockedByDay: [String: Int] = [:]

    public mutating func updateDomainStats(_ domain: String, blocked: Int) {
        blockedByDomain[domain, default: 0] += blocked

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let today = dateFormatter.string(from: Date())
        blockedByDay[today, default: 0] += blocked
    }
}

public struct NetworkRequest {
    public let url: URL
    public let sourceURL: URL?
    public let resourceType: ResourceType
    public let method: String

    public enum ResourceType: String {
        case document
        case script
        case stylesheet
        case image
        case font
        case xhr
        case fetch
        case websocket
        case media
        case other
    }
}

public struct BlockDecision {
    public let shouldBlock: Bool
    public let reason: String?
    public let rule: String?
}

public enum BlockCategory: String, Codable {
    case ads
    case tracking
    case scripts
    case malware
    case annoyances
}

struct BlockingRule {
    let pattern: String
    let category: BlockCategory
    let raw: String

    func matches(_ request: NetworkRequest) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return false
        }

        let urlString = request.url.absoluteString
        let range = NSRange(urlString.startIndex..., in: urlString)
        return regex.firstMatch(in: urlString, options: [], range: range) != nil
    }
}

struct ExceptionRule {
    let pattern: String
    let raw: String

    func matches(_ request: NetworkRequest) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return false
        }

        let urlString = request.url.absoluteString
        let range = NSRange(urlString.startIndex..., in: urlString)
        return regex.firstMatch(in: urlString, options: [], range: range) != nil
    }
}

struct CosmeticRule {
    let selector: String
    let domains: [String]?
    let excludedDomains: [String]?
    let raw: String

    func appliesTo(domain: String) -> Bool {
        // If no domains specified, applies to all
        guard let domains = domains, !domains.isEmpty else {
            return true
        }

        // Check if domain matches any in the list
        for d in domains {
            if d.hasPrefix("~") {
                // Exclusion
                let excluded = String(d.dropFirst())
                if domain.hasSuffix(excluded) || domain == excluded {
                    return false
                }
            } else {
                if domain.hasSuffix(d) || domain == d {
                    return true
                }
            }
        }

        return false
    }
}

struct ParsedRule: Codable {
    let type: RuleType
    let pattern: String
    var domains: String?
    let raw: String

    enum RuleType: String, Codable {
        case network
        case exception
        case cosmetic
        case cosmeticException
    }
}

public enum AdBlockerError: Error, LocalizedError {
    case filterListNotFound
    case invalidFilterList
    case updateFailed(String)

    public var errorDescription: String? {
        switch self {
        case .filterListNotFound:
            return "Filter list not found"
        case .invalidFilterList:
            return "Invalid filter list format"
        case .updateFailed(let reason):
            return "Update failed: \(reason)"
        }
    }
}
