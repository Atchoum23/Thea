import Foundation
import OSLog
import Observation
@preconcurrency import SwiftData

// MARK: - Browser History Tracker

// Tracks browsing activity for context-aware assistance

@MainActor
@Observable
final class BrowserHistoryTracker {
    // periphery:ignore - Reserved: shared static property — reserved for future feature activation
    static let shared = BrowserHistoryTracker()

    private let logger = Logger(subsystem: "ai.thea.app", category: "BrowserHistoryTracker")
    private var modelContext: ModelContext?
    private(set) var isTracking = false
    private(set) var browsingHistory: [BrowsingSession] = []
    private(set) var currentSession: BrowsingSession?

    private var config: LifeTrackingConfiguration {
        AppConfiguration.shared.lifeTrackingConfig
    }

    private init() {}

    // periphery:ignore - Reserved: setModelContext(_:) instance method — reserved for future feature activation
    func setModelContext(_ context: ModelContext) {
        modelContext = context
    // periphery:ignore - Reserved: shared static property reserved for future feature activation
    }

// periphery:ignore - Reserved: logger property reserved for future feature activation

    // MARK: - Tracking Control

    func startTracking() {
        guard config.browserTrackingEnabled, !isTracking else { return }

// periphery:ignore - Reserved: config property reserved for future feature activation

        isTracking = true
        currentSession = BrowsingSession(startTime: Date(), visits: [])
    }

    // periphery:ignore - Reserved: setModelContext(_:) instance method reserved for future feature activation
    func stopTracking() {
        isTracking = false

        if let session = currentSession {
            Task {
                // periphery:ignore - Reserved: startTracking() instance method reserved for future feature activation
                await saveSession(session)
            }
        }
        currentSession = nil
    }

    // periphery:ignore - Reserved: stopTracking() instance method reserved for future feature activation
    // MARK: - Page Visit Tracking

    func trackPageVisit(url: URL, title: String?, content _: String?) {
        guard isTracking else { return }

        let visit = PageVisit(
            url: url,
            title: title ?? url.absoluteString,
            timestamp: Date(),
            duration: 0,
            contentSummary: nil,
            category: categorizeURL(url)
        // periphery:ignore - Reserved: trackPageVisit(url:title:content:) instance method reserved for future feature activation
        )

        currentSession?.visits.append(visit)

        Task {
            await saveVisit(visit)
        }
    }

    // MARK: - URL Categorization

    private func categorizeURL(_ url: URL) -> URLCategory {
        let host = url.host?.lowercased() ?? ""

        // Work-related
        if host.contains("github") || host.contains("stackoverflow") || host.contains("docs.") || host.contains("developer") {
            return .work
        }

        // Learning
        // periphery:ignore - Reserved: categorizeURL(_:) instance method reserved for future feature activation
        if host.contains("coursera") || host.contains("udemy") || host.contains("youtube") && url.path.contains("watch") {
            return .learning
        }

        // Social media
        if host.contains("twitter") || host.contains("facebook") || host.contains("instagram") || host.contains("reddit") || host.contains("linkedin") {
            return .social
        }

        // Shopping
        if host.contains("amazon") || host.contains("ebay") || host.contains("shop") || host.contains("store") {
            return .shopping
        }

        // News
        if host.contains("news") || host.contains("cnn") || host.contains("bbc") || host.contains("nytimes") {
            return .news
        }

        // Entertainment
        if host.contains("netflix") || host.contains("hulu") || host.contains("spotify") || host.contains("youtube") {
            return .entertainment
        }

        // Reference
        if host.contains("wikipedia") || host.contains("google") {
            return .reference
        }

        return .other
    }

    // MARK: - Data Persistence

    private func saveVisit(_ visit: PageVisit) async {
        guard let context = modelContext else { return }

        let sessionID = currentSession?.id ?? UUID()

        // SECURITY FIX (FINDING-009): Sanitize URL before storing
        // Remove query parameters that may contain sensitive data (tokens, auth, etc.)
        let sanitizedURL = sanitizeURL(visit.url)

// periphery:ignore - Reserved: saveVisit(_:) instance method reserved for future feature activation

        let record = BrowsingRecord(
            sessionID: sessionID,
            url: sanitizedURL,
            title: visit.title,
            timestamp: visit.timestamp,
            duration: visit.duration,
            category: visit.category.rawValue,
            contentSummary: visit.contentSummary
        )

        context.insert(record)
        do {
            try context.save()
        } catch {
            logger.error("Failed to save browsing record: \(error.localizedDescription)")
        }
    }

    // SECURITY FIX (FINDING-009): Remove sensitive query parameters from URLs
    private func sanitizeURL(_ url: URL) -> String {
        // List of query parameter names that often contain sensitive data
        let sensitiveParams = [
            "token", "access_token", "refresh_token", "auth", "auth_token",
            "api_key", "apikey", "key", "secret", "password", "pwd",
            "session", "sessionid", "sid", "code", "state", "nonce",
            "oauth", "bearer", "jwt", "credential", "credentials",
            // periphery:ignore - Reserved: sanitizeURL(_:) instance method reserved for future feature activation
            "client_secret", "private_key"
        ]

        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            // If we can't parse, return just scheme + host + path (no query)
            if let host = url.host {
                return "\(url.scheme ?? "https")://\(host)\(url.path)"
            }
            return url.path
        }

        // Filter out sensitive query parameters
        if let queryItems = components.queryItems {
            let filteredItems = queryItems.filter { item in
                let lowercaseName = item.name.lowercased()
                // Remove if parameter name contains any sensitive keyword
                return !sensitiveParams.contains { lowercaseName.contains($0) }
            }

            // If all parameters were filtered, remove query string entirely
            components.queryItems = filteredItems.isEmpty ? nil : filteredItems
        }

        // Also remove fragments which may contain tokens (e.g., OAuth implicit flow)
        components.fragment = nil

        return components.string ?? url.absoluteString
    }

    private func saveSession(_ session: BrowsingSession) async {
        // Session data is already saved through individual visits
        browsingHistory.append(session)
    }

    // MARK: - Reports

// periphery:ignore - Reserved: saveSession(_:) instance method reserved for future feature activation

    func getDailyBrowsingReport() -> BrowsingReport {
        let today = Calendar.current.startOfDay(for: Date())
        let visits = currentSession?.visits ?? []

        var categoryDurations: [URLCategory: TimeInterval] = [:]

// periphery:ignore - Reserved: getDailyBrowsingReport() instance method reserved for future feature activation

        for visit in visits {
            categoryDurations[visit.category, default: 0] += visit.duration
        }

        return BrowsingReport(
            date: today,
            totalVisits: visits.count,
            categoryBreakdown: categoryDurations,
            topSites: Array(visits.prefix(10))
        )
    }

    // MARK: - Historical Data

    // periphery:ignore - Reserved: getVisits(for:) instance method — reserved for future feature activation
    func getVisits(for date: Date) async -> [BrowsingRecord] {
        guard let context = modelContext else { return [] }

        let calendar = Calendar.current
        // periphery:ignore - Reserved: getVisits(for:) instance method reserved for future feature activation
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay.addingTimeInterval(86400)

        // Fetch all and filter in memory to avoid Swift 6 #Predicate Sendable issues
        let descriptor = FetchDescriptor<BrowsingRecord>()
        let allRecords: [BrowsingRecord]
        do {
            allRecords = try context.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch browsing records for date: \(error.localizedDescription)")
            return []
        }
        return allRecords
            .filter { $0.timestamp >= startOfDay && $0.timestamp < endOfDay }
            .sorted { $0.timestamp > $1.timestamp }
    }

    // periphery:ignore - Reserved: getVisits(from:to:) instance method — reserved for future feature activation
    func getVisits(from start: Date, to end: Date) async -> [BrowsingRecord] {
        guard let context = modelContext else { return [] }

        // periphery:ignore - Reserved: getVisits(from:to:) instance method reserved for future feature activation
        // Fetch all and filter in memory to avoid Swift 6 #Predicate Sendable issues
        let descriptor = FetchDescriptor<BrowsingRecord>()
        let allRecords: [BrowsingRecord]
        do {
            allRecords = try context.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch browsing records for range: \(error.localizedDescription)")
            return []
        }
        return allRecords
            .filter { $0.timestamp >= start && $0.timestamp <= end }
            .sorted { $0.timestamp > $1.timestamp }
    }
}

// MARK: - Supporting Structures

struct BrowsingSession: Identifiable {
    let id = UUID()
    // periphery:ignore - Reserved: startTime property — reserved for future feature activation
    let startTime: Date
    var visits: [PageVisit]

// periphery:ignore - Reserved: startTime property reserved for future feature activation

    var totalDuration: TimeInterval {
        // periphery:ignore - Reserved: totalDuration property reserved for future feature activation
        visits.reduce(0) { $0 + $1.duration }
    }
}

struct PageVisit {
    let url: URL
    let title: String
    let timestamp: Date
    var duration: TimeInterval
    let contentSummary: String?
    let category: URLCategory
}

enum URLCategory: String {
    case work = "Work"
    case learning = "Learning"
    case social = "Social"
    case entertainment = "Entertainment"
    case shopping = "Shopping"
    case news = "News"
    case reference = "Reference"
    case other = "Other"
}

// periphery:ignore - Reserved: BrowsingReport type reserved for future feature activation
struct BrowsingReport {
    let date: Date
    let totalVisits: Int
    let categoryBreakdown: [URLCategory: TimeInterval]
    let topSites: [PageVisit]
}
