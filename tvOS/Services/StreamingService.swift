import Foundation

// MARK: - Streaming Service for tvOS
// Ported from thea-tizen with Swiss-specific bundled services

/// Streaming app identifiers
enum StreamingAppID: String, Codable, CaseIterable, Sendable {
    case netflix
    case prime
    case disney
    case apple
    case hbo
    case paramount
    case peacock
    case hulu
    case canal
    case canalCH = "canal_ch"
    case plex
    case youtube
    case crunchyroll
    case swisscom
    case other

    var displayName: String {
        switch self {
        case .netflix: "Netflix"
        case .prime: "Prime Video"
        case .disney: "Disney+"
        case .apple: "Apple TV+"
        case .hbo: "Max (HBO)"
        case .paramount: "Paramount+"
        case .peacock: "Peacock"
        case .hulu: "Hulu"
        case .canal: "Canal+"
        case .canalCH: "Canal+ Switzerland"
        case .plex: "Plex"
        case .youtube: "YouTube"
        case .crunchyroll: "Crunchyroll"
        case .swisscom: "blue TV"
        case .other: "Other"
        }
    }

    var iconName: String {
        switch self {
        case .netflix: "play.tv.fill"
        case .prime: "play.rectangle.fill"
        case .disney: "sparkles.tv.fill"
        case .apple: "appletv.fill"
        case .hbo: "film.fill"
        case .paramount: "mountain.2.fill"
        case .peacock: "bird.fill"
        case .hulu: "play.circle.fill"
        case .canal: "tv.fill"
        case .canalCH: "tv.fill"
        case .plex: "server.rack"
        case .youtube: "play.rectangle.fill"
        case .crunchyroll: "leaf.fill"
        case .swisscom: "tv.and.hifispeaker.fill"
        case .other: "questionmark.circle"
        }
    }

    /// URL scheme for deep linking on tvOS
    var urlScheme: String? {
        switch self {
        case .netflix: "nflx://"
        case .prime: "aiv://"
        case .disney: "disneyplus://"
        case .apple: "videos://"
        case .youtube: "youtube://"
        case .plex: "plex://"
        default: nil
        }
    }
}

/// User's streaming subscription tier
enum SubscriptionTier: String, Codable, Sendable {
    case free
    case adSupported = "ad-supported"
    case standard
    case premium
    case fourK = "4k"
}

/// Streaming account configuration
struct StreamingAccount: Codable, Identifiable, Sendable {
    let id: String
    let appID: StreamingAppID
    var accountName: String
    var email: String?
    var country: String
    var tier: SubscriptionTier
    var features: StreamingFeatures
    var isActive: Bool

    struct StreamingFeatures: Codable, Sendable {
        var maxQuality: VideoQuality
        var hasAds: Bool
        var simultaneousStreams: Int
        var downloadable: Bool
        var hdr: Bool
        var dolbyVision: Bool
        var dolbyAtmos: Bool
    }
}

/// Video quality levels
enum VideoQuality: String, Codable, Comparable, Sendable {
    case sd480 = "480p"
    case hd720 = "720p"
    case fullHD1080 = "1080p"
    case uhd4K = "4K"

    static func < (lhs: VideoQuality, rhs: VideoQuality) -> Bool {
        let order: [VideoQuality] = [.sd480, .hd720, .fullHD1080, .uhd4K]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else { return false }
        return lhsIndex < rhsIndex
    }
}

/// Swiss bundled streaming service info
/// Canal+ Switzerland includes HBO Max and Paramount+ via Swisscom TV
// periphery:ignore - Reserved: AD3 audit — wired in future integration
struct BundledStreamingInfo: Sendable {
    let mainProvider: StreamingAppID
    let accessedVia: String
    let includedServices: [StreamingAppID]
    let note: String
}

/// Content availability information
struct StreamingContentInfo: Codable, Sendable {
    let accountID: String
    let appID: StreamingAppID
    let appName: String
    let isAvailable: Bool
    var availableSeasons: [Int]?
    var missingSeasons: [Int]?
    let maxQuality: VideoQuality
    let hasHDR: Bool
    let hasDolbyVision: Bool
    let hasDolbyAtmos: Bool
    let audioLanguages: [String]
    let subtitleLanguages: [String]
    let requiresPayment: Bool
    var paymentAmount: Double?
    let hasAds: Bool
    var releaseDelay: Int?
    var expiresAt: Date?
    let isExtendedCut: Bool
    let country: String
    let isGeoBlocked: Bool
}

/// Reason for recommending download over streaming
enum DownloadReason: String, Codable, Sendable {
    case notAvailable = "not_available"
    case delayedRelease = "delayed_release"
    case requiresPayment = "requires_payment"
    case hasAds = "has_ads"
    case lowQuality = "low_quality"
    case missingLanguage = "missing_language"
    case partialAvailability = "partial_availability"
    case expiringSoon = "expiring_soon"
    case extendedVersion = "extended_version"
    case geoBlocked = "geo_blocked"

    var displayText: String {
        switch self {
        case .notAvailable: "Not available on streaming"
        case .delayedRelease: "Release delayed on streaming"
        case .requiresPayment: "Requires extra payment"
        case .hasAds: "Only available with ads"
        case .lowQuality: "Streaming quality too low"
        case .missingLanguage: "Missing required language"
        case .partialAvailability: "Only partially available"
        case .expiringSoon: "Leaving streaming soon"
        case .extendedVersion: "Extended version not available"
        case .geoBlocked: "Geo-blocked in your region"
        }
    }
}

/// Download priority levels
enum DownloadPriority: String, Codable, Sendable {
    case low
    case medium
    case high
    case critical
}

/// Availability recommendation
// periphery:ignore - Reserved: AD3 audit — wired in future integration
struct AvailabilityRecommendation: Sendable {
    let shouldDownload: Bool
    let reasons: [DownloadReason]
    let bestStreamingOption: StreamingContentInfo?
    let explanation: String
    let priority: DownloadPriority
}

// MARK: - Streaming Availability Service

@MainActor
final class StreamingAvailabilityService: ObservableObject {
    static let shared = StreamingAvailabilityService()

    @Published private(set) var accounts: [StreamingAccount] = []
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    @Published private(set) var userRegion: String = "CH"

    private let userDefaultsKey = "StreamingAccounts"

    /// Swiss bundled services configuration
    /// Canal+ Switzerland (via Swisscom TV) includes HBO Max and Paramount+
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    static let swissBundledServices: [BundledStreamingInfo] = [
        BundledStreamingInfo(
            mainProvider: .canalCH,
            accessedVia: "Swisscom TV",
            includedServices: [.hbo, .paramount],
            note: "HBO Max and Paramount+ content accessible via Canal+ Switzerland app"
        )
    ]

    private init() {
        loadAccounts()
    }

    // MARK: - Account Management

    func addAccount(_ account: StreamingAccount) {
        accounts.removeAll { $0.id == account.id }
        accounts.append(account)
        saveAccounts()
    }

    func removeAccount(id: String) {
        accounts.removeAll { $0.id == id }
        saveAccounts()
    }

    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    func updateAccount(_ account: StreamingAccount) {
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index] = account
            saveAccounts()
        }
    }

    // MARK: - Availability Check

    /// Check if content should be auto-downloaded based on streaming availability
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    func shouldAutoDownload(
        contentID: String,
        title: String,
        type: ContentType,
        season: Int? = nil
    ) async -> AvailabilityRecommendation {
        // Check streaming availability across all accounts
        let availability = await checkAvailability(contentID: contentID, type: type, season: season)

        return analyzeAvailability(availability, title: title)
    }

    /// Get the best streaming option for content
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    func getBestStreamingOption(contentID: String, type: ContentType) async -> StreamingContentInfo? {
        let availability = await checkAvailability(contentID: contentID, type: type, season: nil)
        return availability.filter { $0.isAvailable && !$0.isGeoBlocked }.first
    }

    /// Check if a provider's content is bundled in Switzerland
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    func getBundledAccessInfo(for providerID: Int) -> BundledStreamingInfo? {
        guard userRegion == "CH" else { return nil }

        // HBO Max (384, 1899) and Paramount+ (531) are bundled in Canal+ Switzerland
        let bundledProviderIDs: [Int: StreamingAppID] = [
            384: .hbo,
            1899: .hbo,
            531: .paramount
        ]

        guard let bundledApp = bundledProviderIDs[providerID] else { return nil }

        return Self.swissBundledServices.first { info in
            info.includedServices.contains(bundledApp)
        }
    }

    // MARK: - Private Helpers

    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    private func checkAvailability(
        contentID: String,
        type: ContentType,
        season: Int?
    ) async -> [StreamingContentInfo] {
        // In production, this would call TMDB/JustWatch API
        // For now, return simulated data based on configured accounts
        var results: [StreamingContentInfo] = []

        for account in accounts where account.isActive {
            // Simulate availability check
            let isAvailable = Bool.random() // Would be real API call

            let info = StreamingContentInfo(
                accountID: account.id,
                appID: account.appID,
                appName: account.appID.displayName,
                isAvailable: isAvailable,
                maxQuality: account.features.maxQuality,
                hasHDR: account.features.hdr,
                hasDolbyVision: account.features.dolbyVision,
                hasDolbyAtmos: account.features.dolbyAtmos,
                audioLanguages: ["en", "fr", "de"],
                subtitleLanguages: ["en", "fr", "de", "it"],
                requiresPayment: false,
                hasAds: account.features.hasAds,
                isExtendedCut: false,
                country: account.country,
                isGeoBlocked: false
            )
            results.append(info)
        }

        return results
    }

    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    private func analyzeAvailability(_ options: [StreamingContentInfo], title: String) -> AvailabilityRecommendation {
        var reasons: [DownloadReason] = []
        var bestOption: StreamingContentInfo?
        var bestScore = -1

        for option in options where option.isAvailable && !option.isGeoBlocked {
            var score = 0

            // Quality scoring
            if option.maxQuality >= .fullHD1080 { score += 20 }
            if option.hasHDR { score += 5 }
            if option.hasDolbyVision { score += 5 }
            if option.hasDolbyAtmos { score += 5 }

            // No ads bonus
            if !option.hasAds { score += 10 }

            // No payment bonus
            if !option.requiresPayment { score += 10 }

            if score > bestScore {
                bestScore = score
                bestOption = option
            }
        }

        let shouldDownload = bestOption == nil || !reasons.isEmpty

        var explanation: String
        if let best = bestOption, !shouldDownload {
            explanation = "Available on \(best.appName) in \(best.maxQuality.rawValue)"
            if best.hasHDR { explanation += " with HDR" }
        } else if options.isEmpty {
            explanation = "Not available on any configured streaming service"
            reasons.append(.notAvailable)
        } else {
            explanation = "Download recommended: \(reasons.map(\.displayText).joined(separator: ", "))"
        }

        return AvailabilityRecommendation(
            shouldDownload: shouldDownload,
            reasons: reasons.isEmpty && shouldDownload ? [.notAvailable] : reasons,
            bestStreamingOption: bestOption,
            explanation: explanation,
            priority: shouldDownload ? (reasons.contains(.notAvailable) ? .high : .medium) : .low
        )
    }

    // MARK: - Persistence

    private func loadAccounts() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode([StreamingAccount].self, from: data) else {
            // Load default Swiss configuration
            setupDefaultSwissAccounts()
            return
        }
        accounts = decoded
    }

    private func saveAccounts() {
        if let encoded = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    private func setupDefaultSwissAccounts() {
        // Default Swiss streaming setup with Canal+ Switzerland bundle
        let canalCH = StreamingAccount(
            id: UUID().uuidString,
            appID: .canalCH,
            accountName: "Canal+ Switzerland",
            email: nil,
            country: "CH",
            tier: .premium,
            features: StreamingAccount.StreamingFeatures(
                maxQuality: .uhd4K,
                hasAds: false,
                simultaneousStreams: 4,
                downloadable: true,
                hdr: true,
                dolbyVision: true,
                dolbyAtmos: true
            ),
            isActive: true
        )

        accounts = [canalCH]
        saveAccounts()
    }
}

// MARK: - Content Type

enum ContentType: String, Codable, Sendable {
    case movie
    case show
    case episode
}
