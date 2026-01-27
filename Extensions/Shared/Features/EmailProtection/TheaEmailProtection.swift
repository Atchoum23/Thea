// TheaEmailProtection.swift
// Email alias and tracker protection (replaces iCloud Hide My Email)
// Features: alias generation, tracker removal, link protection, privacy reports

import CryptoKit
import Foundation
import OSLog

// MARK: - Email Protection Manager

@MainActor
public final class TheaEmailProtectionManager: ObservableObject {
    public static let shared = TheaEmailProtectionManager()

    private let logger = Logger(subsystem: "com.thea.extension", category: "EmailProtection")

    // MARK: - Published State

    @Published public private(set) var aliases: [EmailAlias] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var stats = EmailProtectionStats()
    @Published public var settings = EmailProtectionSettings()

    // MARK: - Private Properties

    private let aliasStorageKey = "emailProtection.aliases"
    private let statsStorageKey = "emailProtection.stats"

    // MARK: - Initialization

    private init() {
        loadData()
    }

    private func loadData() {
        // Load aliases
        if let data = UserDefaults.standard.data(forKey: aliasStorageKey),
           let loaded = try? JSONDecoder().decode([EmailAlias].self, from: data)
        {
            aliases = loaded
        }

        // Load stats
        if let data = UserDefaults.standard.data(forKey: statsStorageKey),
           let loaded = try? JSONDecoder().decode(EmailProtectionStats.self, from: data)
        {
            stats = loaded
        }
    }

    private func saveAliases() {
        if let data = try? JSONEncoder().encode(aliases) {
            UserDefaults.standard.set(data, forKey: aliasStorageKey)
        }
    }

    private func saveStats() {
        if let data = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(data, forKey: statsStorageKey)
        }
    }

    // MARK: - Alias Management

    /// Generate a new email alias
    public func generateAlias(
        for domain: String,
        note: String? = nil,
        format: AliasFormat = .random
    ) async throws -> EmailAlias {
        isLoading = true
        defer { isLoading = false }

        // Check alias limit
        let activeAliases = aliases.filter(\.isEnabled)
        guard activeAliases.count < settings.maxActiveAliases else {
            throw EmailProtectionError.aliasLimitReached
        }

        // Generate alias address
        let aliasAddress = generateAliasAddress(format: format, domain: domain)

        let alias = EmailAlias(
            id: UUID().uuidString,
            alias: aliasAddress,
            forwardTo: settings.forwardingEmail,
            domain: domain,
            createdAt: Date(),
            isEnabled: true,
            note: note ?? "Created for \(domain)",
            emailsReceived: 0,
            trackersBlocked: 0
        )

        aliases.insert(alias, at: 0)
        saveAliases()

        // Update stats
        stats.totalAliasesCreated += 1
        saveStats()

        // Update extension stats
        TheaExtensionState.shared.stats.emailsProtected += 1

        logger.info("Created alias for domain: \(domain)")

        // Notify extension bridge
        TheaExtensionBridge.shared.notifyExtensions(
            ExtensionNotification(
                type: .aliasCreated,
                data: [
                    "aliasId": AnyCodable(alias.id),
                    "domain": AnyCodable(domain)
                ]
            )
        )

        return alias
    }

    /// List all aliases
    public func listAliases(filter: AliasFilter? = nil) -> [EmailAlias] {
        var result = aliases

        if let filter {
            switch filter {
            case .active:
                result = result.filter(\.isEnabled)
            case .inactive:
                result = result.filter { !$0.isEnabled }
            case let .domain(domain):
                result = result.filter { $0.domain.contains(domain) }
            case let .recent(days):
                let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
                result = result.filter { $0.createdAt > cutoff }
            }
        }

        return result
    }

    /// Toggle alias enabled state
    public func toggleAlias(_ aliasId: String, enabled: Bool) async throws {
        guard let index = aliases.firstIndex(where: { $0.id == aliasId }) else {
            throw EmailProtectionError.aliasNotFound
        }

        // Check if enabling would exceed limit
        if enabled {
            let activeCount = aliases.count(where: { $0.isEnabled && $0.id != aliasId })
            guard activeCount < settings.maxActiveAliases else {
                throw EmailProtectionError.aliasLimitReached
            }
        }

        aliases[index].isEnabled = enabled
        saveAliases()

        logger.info("Toggled alias \(aliasId) to \(enabled ? "enabled" : "disabled")")
    }

    /// Delete an alias permanently
    public func deleteAlias(_ aliasId: String) async throws {
        guard let index = aliases.firstIndex(where: { $0.id == aliasId }) else {
            throw EmailProtectionError.aliasNotFound
        }

        let alias = aliases.remove(at: index)
        saveAliases()

        logger.info("Deleted alias: \(alias.alias)")
    }

    /// Update alias note
    public func updateAliasNote(_ aliasId: String, note: String) throws {
        guard let index = aliases.firstIndex(where: { $0.id == aliasId }) else {
            throw EmailProtectionError.aliasNotFound
        }

        aliases[index].note = note
        saveAliases()
    }

    // MARK: - Tracker Protection

    /// Process an incoming email and remove trackers
    public func processEmail(_ email: IncomingEmail) async throws -> ProcessedEmail {
        var processedContent = email.htmlContent

        // Find and remove tracking pixels
        let trackingPixels = findTrackingPixels(in: processedContent)
        for pixel in trackingPixels {
            processedContent = processedContent.replacingOccurrences(of: pixel.html, with: "")
        }

        // Find and clean tracking links
        let trackingLinks = findTrackingLinks(in: processedContent)
        for link in trackingLinks {
            if let cleanUrl = cleanTrackingUrl(link.url) {
                processedContent = processedContent.replacingOccurrences(
                    of: link.href,
                    with: cleanUrl.absoluteString
                )
            }
        }

        // Upgrade HTTP links to HTTPS
        processedContent = upgradeToHTTPS(processedContent)

        // Update alias stats
        if let aliasIndex = aliases.firstIndex(where: { $0.alias == email.toAddress }) {
            aliases[aliasIndex].emailsReceived += 1
            aliases[aliasIndex].trackersBlocked += trackingPixels.count + trackingLinks.count
            saveAliases()
        }

        // Update global stats
        stats.emailsProcessed += 1
        stats.trackersRemoved += trackingPixels.count + trackingLinks.count
        stats.linksProtected += trackingLinks.count
        saveStats()

        let processedEmail = ProcessedEmail(
            originalEmail: email,
            processedContent: processedContent,
            trackersRemoved: trackingPixels.count,
            linksProtected: trackingLinks.count,
            trackerReport: TrackerAnalysis(
                pixels: trackingPixels,
                links: trackingLinks,
                senderDomain: email.senderDomain
            )
        )

        logger.info("Processed email: removed \(trackingPixels.count) pixels, protected \(trackingLinks.count) links")

        return processedEmail
    }

    /// Get tracker report for an alias
    public func getTrackerReport(for aliasId: String) async throws -> TrackerReport {
        guard let alias = aliases.first(where: { $0.id == aliasId }) else {
            throw EmailProtectionError.aliasNotFound
        }

        // In a real implementation, this would fetch from a backend service
        return TrackerReport(
            aliasId: aliasId,
            totalEmails: alias.emailsReceived,
            trackersRemoved: alias.trackersBlocked,
            trackerTypes: stats.trackersByType,
            recentActivity: [] // Would be populated from actual email processing logs
        )
    }

    // MARK: - Private Helpers

    private func generateAliasAddress(format: AliasFormat, domain: String) -> String {
        let localPart: String

        switch format {
        case .random:
            // Generate random string like "abc123def456"
            let chars = "abcdefghijklmnopqrstuvwxyz0123456789"
            localPart = String((0 ..< 12).map { _ in chars.randomElement()! })

        case .wordBased:
            // Generate word-based alias like "brave-sunset-42"
            let adjectives = ["swift", "bright", "calm", "deep", "eager", "fair", "glad", "keen", "mild", "neat"]
            let nouns = ["cloud", "dawn", "echo", "flame", "grove", "hill", "isle", "lake", "moon", "peak"]
            let adj = adjectives.randomElement()!
            let noun = nouns.randomElement()!
            let num = Int.random(in: 10 ... 99)
            localPart = "\(adj)-\(noun)-\(num)"

        case .domainBased:
            // Generate alias based on the target domain
            let sanitized = domain.replacingOccurrences(of: ".", with: "-")
            let random = String((0 ..< 4).map { _ in "0123456789".randomElement()! })
            localPart = "\(sanitized)-\(random)"

        case let .custom(prefix):
            let random = String((0 ..< 6).map { _ in "abcdefghijklmnopqrstuvwxyz0123456789".randomElement()! })
            localPart = "\(prefix)-\(random)"
        }

        return "\(localPart)@\(settings.aliasDomain)"
    }

    private func findTrackingPixels(in html: String) -> [TrackingPixel] {
        var pixels: [TrackingPixel] = []

        // Common tracking pixel patterns
        let patterns = [
            // 1x1 images
            "<img[^>]+(?:width=[\"']1[\"']|height=[\"']1[\"'])[^>]*>",
            // Hidden images
            "<img[^>]+style=[\"'][^\"']*(?:display:\\s*none|visibility:\\s*hidden)[^\"']*[\"'][^>]*>",
            // Common tracker domains
            "<img[^>]+src=[\"'][^\"']*(mailchimp|sendgrid|hubspot|marketo|eloqua|mailgun|constantcontact|mailtrack|yesware|streak|bananatag|cirrusinsight|mixmax|boomerang)[^\"']*[\"'][^>]*>"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: html, options: [], range: NSRange(html.startIndex..., in: html))
                for match in matches {
                    if let range = Range(match.range, in: html) {
                        let htmlSnippet = String(html[range])
                        pixels.append(TrackingPixel(
                            html: htmlSnippet,
                            detectedBy: "pattern-match"
                        ))
                    }
                }
            }
        }

        return pixels
    }

    private func findTrackingLinks(in html: String) -> [TrackingLink] {
        var links: [TrackingLink] = []

        // Find all href attributes
        let pattern = "href=[\"']([^\"']+)[\"']"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return links
        }

        let matches = regex.matches(in: html, options: [], range: NSRange(html.startIndex..., in: html))

        for match in matches {
            if let urlRange = Range(match.range(at: 1), in: html),
               let hrefRange = Range(match.range, in: html)
            {
                let urlString = String(html[urlRange])
                let href = String(html[hrefRange])

                if let url = URL(string: urlString), isTrackingUrl(url) {
                    links.append(TrackingLink(
                        href: href,
                        url: url,
                        tracker: identifyTracker(url)
                    ))
                }
            }
        }

        return links
    }

    private func isTrackingUrl(_ url: URL) -> Bool {
        let trackingDomains = [
            "click.", "track.", "open.", "link.", "go.",
            "mailchi.mp", "list-manage.com", "sendgrid.net",
            "hubspot.com", "mkto", "eloqua.com", "em.link"
        ]

        let trackingParams = [
            "utm_source", "utm_medium", "utm_campaign", "utm_content", "utm_term",
            "mc_cid", "mc_eid", "fbclid", "gclid", "msclkid",
            "_hsenc", "_hsmi", "trk", "trkEmail"
        ]

        // Check domain
        if let host = url.host {
            for domain in trackingDomains {
                if host.contains(domain) {
                    return true
                }
            }
        }

        // Check query parameters
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems
        {
            for item in queryItems {
                if trackingParams.contains(item.name) {
                    return true
                }
            }
        }

        return false
    }

    private func identifyTracker(_ url: URL) -> String {
        guard let host = url.host else { return "Unknown" }

        let trackers: [String: String] = [
            "mailchimp": "Mailchimp",
            "sendgrid": "SendGrid",
            "hubspot": "HubSpot",
            "marketo": "Marketo",
            "eloqua": "Oracle Eloqua",
            "constantcontact": "Constant Contact",
            "mailgun": "Mailgun",
            "facebook": "Facebook",
            "google": "Google"
        ]

        for (domain, name) in trackers {
            if host.contains(domain) {
                return name
            }
        }

        return "Generic Tracker"
    }

    private func cleanTrackingUrl(_ url: URL) -> URL? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }

        // Tracking parameters to remove
        let trackingParams = Set([
            "utm_source", "utm_medium", "utm_campaign", "utm_content", "utm_term",
            "mc_cid", "mc_eid", "fbclid", "gclid", "msclkid", "dclid",
            "_hsenc", "_hsmi", "trk", "trkEmail", "sc_cid",
            "oly_anon_id", "oly_enc_id", "ref", "ref_src"
        ])

        // Check for redirect URL in query (common in email tracking)
        if let queryItems = components.queryItems {
            // Look for actual URL in parameters
            for item in queryItems {
                if let value = item.value,
                   value.hasPrefix("http"),
                   let redirectUrl = URL(string: value)
                {
                    // Return the actual destination URL
                    return cleanTrackingUrl(redirectUrl)
                }
            }

            // Remove tracking parameters
            components.queryItems = queryItems.filter { !trackingParams.contains($0.name) }

            // Remove empty query string
            if components.queryItems?.isEmpty == true {
                components.queryItems = nil
            }
        }

        return components.url
    }

    private func upgradeToHTTPS(_ html: String) -> String {
        // Upgrade HTTP links to HTTPS
        var result = html
        result = result.replacingOccurrences(of: "http://", with: "https://")
        return result
    }
}

// MARK: - Supporting Types

public struct EmailProtectionSettings: Codable {
    public var forwardingEmail: String = ""
    public var aliasDomain: String = "alias.thea.app"
    public var maxActiveAliases: Int = 100
    public var autoRemoveTrackers: Bool = true
    public var autoCleanLinks: Bool = true
    public var upgradeToHTTPS: Bool = true
    public var showTrackerReport: Bool = true
    public var notifyOnNewEmail: Bool = false
}

public struct EmailProtectionStats: Codable {
    public var totalAliasesCreated: Int = 0
    public var emailsProcessed: Int = 0
    public var trackersRemoved: Int = 0
    public var linksProtected: Int = 0
    public var trackersByType: [String: Int] = [:]
}

public enum AliasFormat {
    case random // abc123def456
    case wordBased // brave-sunset-42
    case domainBased // example-com-1234
    case custom(String) // prefix-abc123
}

public enum AliasFilter {
    case active
    case inactive
    case domain(String)
    case recent(Int) // days
}

public struct IncomingEmail {
    public let id: String
    public let fromAddress: String
    public let toAddress: String // alias
    public let subject: String
    public let htmlContent: String
    public let textContent: String?
    public let receivedAt: Date

    public var senderDomain: String {
        fromAddress.components(separatedBy: "@").last ?? "unknown"
    }
}

public struct ProcessedEmail {
    public let originalEmail: IncomingEmail
    public let processedContent: String
    public let trackersRemoved: Int
    public let linksProtected: Int
    public let trackerReport: TrackerAnalysis
}

public struct TrackerAnalysis {
    public let pixels: [TrackingPixel]
    public let links: [TrackingLink]
    public let senderDomain: String
}

public struct TrackingPixel {
    public let html: String
    public let detectedBy: String
}

public struct TrackingLink {
    public let href: String
    public let url: URL
    public let tracker: String
}

public enum EmailProtectionError: Error, LocalizedError {
    case aliasNotFound
    case aliasLimitReached
    case invalidEmail
    case processingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .aliasNotFound:
            "Email alias not found"
        case .aliasLimitReached:
            "Maximum number of active aliases reached"
        case .invalidEmail:
            "Invalid email address"
        case let .processingFailed(reason):
            "Email processing failed: \(reason)"
        }
    }
}

// MARK: - Form Detection

extension TheaEmailProtectionManager {
    /// Detect email input fields on a page
    public func detectEmailFields(in html: String) -> [EmailFieldInfo] {
        var fields: [EmailFieldInfo] = []

        // Find input fields with email-related attributes
        let patterns = [
            "<input[^>]+type=[\"']email[\"'][^>]*>",
            "<input[^>]+name=[\"'][^\"']*(email|mail)[^\"']*[\"'][^>]*>",
            "<input[^>]+id=[\"'][^\"']*(email|mail)[^\"']*[\"'][^>]*>",
            "<input[^>]+placeholder=[\"'][^\"']*(email|mail|@)[^\"']*[\"'][^>]*>"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: html, options: [], range: NSRange(html.startIndex..., in: html))
                for match in matches {
                    if let range = Range(match.range, in: html) {
                        let fieldHtml = String(html[range])
                        if let fieldInfo = parseEmailField(fieldHtml) {
                            fields.append(fieldInfo)
                        }
                    }
                }
            }
        }

        return fields
    }

    private func parseEmailField(_ html: String) -> EmailFieldInfo? {
        var info = EmailFieldInfo()

        // Extract id
        if let idMatch = html.range(of: "id=[\"']([^\"']+)[\"']", options: .regularExpression),
           let valueRange = html.range(of: "(?<=id=[\"'])[^\"']+", options: .regularExpression, range: idMatch)
        {
            info.id = String(html[valueRange])
        }

        // Extract name
        if let nameMatch = html.range(of: "name=[\"']([^\"']+)[\"']", options: .regularExpression),
           let valueRange = html.range(of: "(?<=name=[\"'])[^\"']+", options: .regularExpression, range: nameMatch)
        {
            info.name = String(html[valueRange])
        }

        // Extract placeholder
        if let placeholderMatch = html.range(of: "placeholder=[\"']([^\"']+)[\"']", options: .regularExpression),
           let valueRange = html.range(of: "(?<=placeholder=[\"'])[^\"']+", options: .regularExpression, range: placeholderMatch)
        {
            info.placeholder = String(html[valueRange])
        }

        guard info.id != nil || info.name != nil else { return nil }
        return info
    }
}

public struct EmailFieldInfo {
    public var id: String?
    public var name: String?
    public var placeholder: String?
    public var isRequired: Bool = false
}
