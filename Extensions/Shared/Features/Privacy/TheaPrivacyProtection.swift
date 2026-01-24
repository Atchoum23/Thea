// TheaPrivacyProtection.swift
// Comprehensive privacy protection
// Features: tracker blocking, fingerprint protection, referrer control, GPC/DNT

import Foundation
import OSLog
import Combine

// MARK: - Privacy Protection Manager

@MainActor
public final class TheaPrivacyProtectionManager: ObservableObject {
    public static let shared = TheaPrivacyProtectionManager()

    private let logger = Logger(subsystem: "com.thea.extension", category: "PrivacyProtection")

    // MARK: - Published State

    @Published public var isEnabled = true
    @Published public private(set) var trackerDatabase: TrackerDatabase = TrackerDatabase()
    @Published public private(set) var siteReports: [String: PrivacyReport] = [:]
    @Published public var settings = PrivacySettings()

    // MARK: - Initialization

    private init() {
        loadSettings()
        loadTrackerDatabase()
    }

    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: "privacy.settings"),
           let loaded = try? JSONDecoder().decode(PrivacySettings.self, from: data) {
            settings = loaded
            isEnabled = settings.enabled
        }
    }

    public func saveSettings() {
        settings.enabled = isEnabled
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: "privacy.settings")
        }
    }

    private func loadTrackerDatabase() {
        // Load known tracker database
        // This would be populated from services like DuckDuckGo's tracker radar
        trackerDatabase = TrackerDatabase.defaultDatabase()
    }

    // MARK: - Tracker Removal

    /// Remove trackers from a page
    public func removeTrackers(on page: PageContext) async throws -> [TrackerInfo] {
        guard isEnabled else { return [] }

        var detectedTrackers: [TrackerInfo] = []

        // Analyze page for trackers
        // This would be implemented with WebKit content rules

        // Update site report
        updateSiteReport(for: page.domain, trackers: detectedTrackers)

        logger.debug("Detected \(detectedTrackers.count) trackers on \(page.domain)")

        return detectedTrackers
    }

    /// Analyze a network request for tracking
    public func analyzeRequest(_ request: NetworkRequest) -> TrackingAnalysis {
        guard isEnabled else {
            return TrackingAnalysis(isTracker: false, trackerInfo: nil, action: .allow)
        }

        let host = request.url.host ?? ""

        // Check tracker database
        if let tracker = trackerDatabase.findTracker(host: host) {
            let action: TrackingAction

            switch tracker.category {
            case .advertising:
                action = settings.blockAds ? .block : .allow
            case .analytics:
                action = settings.blockAnalytics ? .block : .allow
            case .social:
                action = settings.blockSocialTrackers ? .block : .allow
            case .fingerprinting:
                action = settings.blockFingerprinting ? .block : .allow
            case .cryptomining:
                action = .block // Always block
            case .other:
                action = settings.strictMode ? .block : .allow
            }

            return TrackingAnalysis(
                isTracker: true,
                trackerInfo: tracker,
                action: action
            )
        }

        return TrackingAnalysis(isTracker: false, trackerInfo: nil, action: .allow)
    }

    // MARK: - URL Cleaning

    /// Strip tracking parameters from URL
    public func stripTrackingParams(from url: URL) -> URL {
        guard settings.stripTrackingParams else { return url }

        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }

        // Known tracking parameters
        let trackingParams: Set<String> = [
            // UTM parameters
            "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content",
            "utm_name", "utm_cid", "utm_reader", "utm_viz_id", "utm_pubreferrer",

            // Facebook
            "fbclid", "fb_action_ids", "fb_action_types", "fb_source", "fb_ref",

            // Google
            "gclid", "gclsrc", "dclid", "gs_l",

            // Microsoft
            "msclkid",

            // Twitter
            "twclid",

            // Mailchimp
            "mc_cid", "mc_eid",

            // HubSpot
            "_hsenc", "_hsmi", "hsCtaTracking",

            // Marketo
            "mkt_tok",

            // Adobe
            "cid", "s_kwcid",

            // Generic tracking
            "ref", "ref_src", "ref_url", "source", "origin",
            "trk", "trkEmail", "trkInfo",
            "spm", "pvid", "scm", "algo_pvid", "algo_expid",

            // Others
            "yclid", "ymclid", "wbraid", "gbraid",
            "igshid", "_ga", "sc_cid", "oly_anon_id", "oly_enc_id"
        ]

        if var queryItems = components.queryItems {
            queryItems.removeAll { trackingParams.contains($0.name.lowercased()) }

            // Remove empty query string
            components.queryItems = queryItems.isEmpty ? nil : queryItems
        }

        return components.url ?? url
    }

    // MARK: - Fingerprint Protection

    /// Generate fingerprint protection headers
    public func getProtectionHeaders() -> [String: String] {
        guard isEnabled else { return [:] }

        var headers: [String: String] = [:]

        // Global Privacy Control
        if settings.enableGPC {
            headers["Sec-GPC"] = "1"
        }

        // Do Not Track
        if settings.enableDNT {
            headers["DNT"] = "1"
        }

        // Referrer policy
        if settings.limitReferrer {
            headers["Sec-Fetch-Dest"] = "document"
            headers["Sec-Fetch-Mode"] = "navigate"
            headers["Sec-Fetch-Site"] = "cross-site"
        }

        return headers
    }

    /// Get spoofed values for fingerprint protection
    public func getFingerprintProtection() -> FingerprintProtection {
        guard settings.blockFingerprinting else {
            return FingerprintProtection(enabled: false)
        }

        return FingerprintProtection(
            enabled: true,
            canvasNoise: settings.canvasNoise,
            webglNoise: settings.webglNoise,
            audioNoise: settings.audioNoise,
            fontFingerprint: settings.fontFingerprint,
            screenResolution: settings.screenResolution,
            timezone: settings.timezoneSpoof,
            language: settings.languageSpoof,
            hardwareConcurrency: settings.hardwareConcurrencySpoof
        )
    }

    /// Generate JavaScript for fingerprint protection
    public func getFingerprintProtectionScript() -> String {
        guard settings.blockFingerprinting else { return "" }

        return """
        (function() {
            'use strict';

            // Canvas fingerprinting protection
            \(settings.canvasNoise ? canvasProtectionScript : "")

            // WebGL fingerprinting protection
            \(settings.webglNoise ? webglProtectionScript : "")

            // Audio fingerprinting protection
            \(settings.audioNoise ? audioProtectionScript : "")

            // Hardware info protection
            \(settings.hardwareConcurrencySpoof ? hardwareProtectionScript : "")

            // Screen resolution protection
            \(settings.screenResolution ? screenProtectionScript : "")
        })();
        """
    }

    private var canvasProtectionScript: String {
        """
            // Add noise to canvas fingerprinting
            const originalToDataURL = HTMLCanvasElement.prototype.toDataURL;
            HTMLCanvasElement.prototype.toDataURL = function(type, quality) {
                const ctx = this.getContext('2d');
                if (ctx) {
                    const imageData = ctx.getImageData(0, 0, this.width, this.height);
                    const data = imageData.data;
                    // Add subtle noise
                    for (let i = 0; i < data.length; i += 4) {
                        data[i] = data[i] ^ (Math.random() > 0.99 ? 1 : 0);
                    }
                    ctx.putImageData(imageData, 0, 0);
                }
                return originalToDataURL.apply(this, arguments);
            };

            const originalGetImageData = CanvasRenderingContext2D.prototype.getImageData;
            CanvasRenderingContext2D.prototype.getImageData = function() {
                const imageData = originalGetImageData.apply(this, arguments);
                const data = imageData.data;
                for (let i = 0; i < data.length; i += 4) {
                    data[i] = data[i] ^ (Math.random() > 0.99 ? 1 : 0);
                }
                return imageData;
            };
        """
    }

    private var webglProtectionScript: String {
        """
            // WebGL fingerprinting protection
            const getParameterProxyHandler = {
                apply: function(target, thisArg, args) {
                    const param = args[0];
                    const result = target.apply(thisArg, args);

                    // Mask specific parameters
                    if (param === 37445) { // UNMASKED_VENDOR_WEBGL
                        return 'Intel Inc.';
                    }
                    if (param === 37446) { // UNMASKED_RENDERER_WEBGL
                        return 'Intel Iris OpenGL Engine';
                    }

                    return result;
                }
            };

            const originalGetParameter = WebGLRenderingContext.prototype.getParameter;
            WebGLRenderingContext.prototype.getParameter = new Proxy(originalGetParameter, getParameterProxyHandler);

            if (typeof WebGL2RenderingContext !== 'undefined') {
                const originalGetParameter2 = WebGL2RenderingContext.prototype.getParameter;
                WebGL2RenderingContext.prototype.getParameter = new Proxy(originalGetParameter2, getParameterProxyHandler);
            }
        """
    }

    private var audioProtectionScript: String {
        """
            // Audio fingerprinting protection
            const originalCreateAnalyser = AudioContext.prototype.createAnalyser;
            AudioContext.prototype.createAnalyser = function() {
                const analyser = originalCreateAnalyser.apply(this, arguments);
                const originalGetFloatFrequencyData = analyser.getFloatFrequencyData;
                analyser.getFloatFrequencyData = function(array) {
                    originalGetFloatFrequencyData.apply(this, arguments);
                    // Add noise
                    for (let i = 0; i < array.length; i++) {
                        array[i] = array[i] + (Math.random() * 0.0001 - 0.00005);
                    }
                };
                return analyser;
            };
        """
    }

    private var hardwareProtectionScript: String {
        """
            // Hardware info protection
            Object.defineProperty(navigator, 'hardwareConcurrency', {
                get: function() { return 4; }
            });

            Object.defineProperty(navigator, 'deviceMemory', {
                get: function() { return 8; }
            });
        """
    }

    private var screenProtectionScript: String {
        """
            // Screen resolution protection
            Object.defineProperty(screen, 'width', {
                get: function() { return 1920; }
            });
            Object.defineProperty(screen, 'height', {
                get: function() { return 1080; }
            });
            Object.defineProperty(screen, 'availWidth', {
                get: function() { return 1920; }
            });
            Object.defineProperty(screen, 'availHeight', {
                get: function() { return 1040; }
            });
            Object.defineProperty(screen, 'colorDepth', {
                get: function() { return 24; }
            });
            Object.defineProperty(screen, 'pixelDepth', {
                get: function() { return 24; }
            });
        """
    }

    // MARK: - Privacy Reports

    /// Get privacy report for a domain
    public func getPrivacyReport(for domain: String) -> PrivacyReport {
        let normalized = normalizeDomain(domain)

        if let cached = siteReports[normalized] {
            return cached
        }

        // Generate new report
        let report = generatePrivacyReport(for: normalized)
        siteReports[normalized] = report
        return report
    }

    private func generatePrivacyReport(for domain: String) -> PrivacyReport {
        // This would analyze the site for privacy issues
        // For now, return a default report
        return PrivacyReport(
            domain: domain,
            grade: "B",
            trackersFound: 0,
            trackersBlocked: 0,
            fingerprintingAttempts: 0,
            httpsStatus: true,
            privacyPractices: [
                "HTTPS": true,
                "Secure Cookies": true,
                "Content Security Policy": false,
                "Referrer Policy": true
            ]
        )
    }

    private func updateSiteReport(for domain: String, trackers: [TrackerInfo]) {
        let normalized = normalizeDomain(domain)
        var report = siteReports[normalized] ?? generatePrivacyReport(for: normalized)

        report.trackersFound = trackers.count
        report.trackersBlocked = trackers.filter { $0.blocked }.count

        // Calculate grade
        report.grade = calculateGrade(report)

        siteReports[normalized] = report
    }

    private func calculateGrade(_ report: PrivacyReport) -> String {
        var score = 100

        // Deduct for trackers
        score -= report.trackersFound * 5

        // Deduct for fingerprinting
        score -= report.fingerprintingAttempts * 10

        // Deduct for no HTTPS
        if !report.httpsStatus {
            score -= 30
        }

        // Deduct for missing security headers
        for (_, value) in report.privacyPractices {
            if !value { score -= 5 }
        }

        switch score {
        case 90...100: return "A+"
        case 80..<90: return "A"
        case 70..<80: return "B"
        case 60..<70: return "C"
        case 50..<60: return "D"
        default: return "F"
        }
    }

    // MARK: - Cookie Management

    /// Classify cookies
    public func classifyCookies(_ cookies: [HTTPCookie]) -> CookieClassification {
        var essential: [HTTPCookie] = []
        var functional: [HTTPCookie] = []
        var analytics: [HTTPCookie] = []
        var advertising: [HTTPCookie] = []
        var unknown: [HTTPCookie] = []

        for cookie in cookies {
            let classification = classifyCookie(cookie)
            switch classification {
            case .essential:
                essential.append(cookie)
            case .functional:
                functional.append(cookie)
            case .analytics:
                analytics.append(cookie)
            case .advertising:
                advertising.append(cookie)
            case .unknown:
                unknown.append(cookie)
            }
        }

        return CookieClassification(
            essential: essential,
            functional: functional,
            analytics: analytics,
            advertising: advertising,
            unknown: unknown
        )
    }

    private func classifyCookie(_ cookie: HTTPCookie) -> CookieType {
        let name = cookie.name.lowercased()
        let domain = cookie.domain.lowercased()

        // Check known advertising cookies
        let adCookies = ["_fbp", "_fbc", "fr", "datr", "_gcl_au", "IDE", "NID", "DSID", "FLC", "AID", "TAID"]
        if adCookies.contains(where: { name.contains($0.lowercased()) }) {
            return .advertising
        }

        // Check known analytics cookies
        let analyticsCookies = ["_ga", "_gid", "_gat", "__utma", "__utmb", "__utmc", "__utmz", "_hjid", "mp_", "amplitude"]
        if analyticsCookies.contains(where: { name.contains($0.lowercased()) }) {
            return .analytics
        }

        // Check known functional cookies
        let functionalCookies = ["lang", "locale", "theme", "preferences", "settings"]
        if functionalCookies.contains(where: { name.contains($0.lowercased()) }) {
            return .functional
        }

        // Check for session/auth cookies
        let essentialCookies = ["session", "auth", "csrf", "token", "sid", "ssid"]
        if essentialCookies.contains(where: { name.contains($0.lowercased()) }) {
            return .essential
        }

        // Check tracker database for domain
        if trackerDatabase.findTracker(host: domain) != nil {
            return .advertising
        }

        return .unknown
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

public struct PrivacySettings: Codable {
    public var enabled: Bool = true
    public var blockAds: Bool = true
    public var blockAnalytics: Bool = true
    public var blockSocialTrackers: Bool = true
    public var blockFingerprinting: Bool = true
    public var strictMode: Bool = false
    public var stripTrackingParams: Bool = true
    public var enableGPC: Bool = true
    public var enableDNT: Bool = true
    public var limitReferrer: Bool = true
    public var canvasNoise: Bool = true
    public var webglNoise: Bool = true
    public var audioNoise: Bool = true
    public var fontFingerprint: Bool = false
    public var screenResolution: Bool = true
    public var timezoneSpoof: Bool = false
    public var languageSpoof: Bool = false
    public var hardwareConcurrencySpoof: Bool = true
}

public struct TrackerDatabase {
    private var trackers: [String: TrackerInfo] = [:]

    public static func defaultDatabase() -> TrackerDatabase {
        var db = TrackerDatabase()

        // Popular trackers
        let knownTrackers: [(String, String, TrackerInfo.TrackerCategory)] = [
            ("google-analytics.com", "Google", .analytics),
            ("googleadservices.com", "Google", .advertising),
            ("doubleclick.net", "Google", .advertising),
            ("googlesyndication.com", "Google", .advertising),
            ("facebook.com", "Meta", .social),
            ("facebook.net", "Meta", .social),
            ("connect.facebook.net", "Meta", .social),
            ("twitter.com", "X", .social),
            ("ads-twitter.com", "X", .advertising),
            ("amazon-adsystem.com", "Amazon", .advertising),
            ("hotjar.com", "Hotjar", .analytics),
            ("mouseflow.com", "Mouseflow", .analytics),
            ("fullstory.com", "FullStory", .analytics),
            ("mixpanel.com", "Mixpanel", .analytics),
            ("amplitude.com", "Amplitude", .analytics),
            ("segment.io", "Segment", .analytics),
            ("criteo.com", "Criteo", .advertising),
            ("outbrain.com", "Outbrain", .advertising),
            ("taboola.com", "Taboola", .advertising),
            ("coinhive.com", "Coinhive", .cryptomining),
            ("coin-hive.com", "Coinhive", .cryptomining)
        ]

        for (domain, company, category) in knownTrackers {
            db.trackers[domain] = TrackerInfo(
                name: domain,
                company: company,
                category: category,
                blocked: false
            )
        }

        return db
    }

    public func findTracker(host: String) -> TrackerInfo? {
        // Direct match
        if let tracker = trackers[host] {
            return tracker
        }

        // Check parent domains
        var parts = host.split(separator: ".")
        while parts.count > 1 {
            parts.removeFirst()
            let parentDomain = parts.joined(separator: ".")
            if let tracker = trackers[parentDomain] {
                return tracker
            }
        }

        return nil
    }
}

public struct TrackingAnalysis {
    public let isTracker: Bool
    public let trackerInfo: TrackerInfo?
    public let action: TrackingAction
}

public enum TrackingAction {
    case allow
    case block
    case modify
}

public struct FingerprintProtection {
    public let enabled: Bool
    public var canvasNoise: Bool = false
    public var webglNoise: Bool = false
    public var audioNoise: Bool = false
    public var fontFingerprint: Bool = false
    public var screenResolution: Bool = false
    public var timezone: Bool = false
    public var language: Bool = false
    public var hardwareConcurrency: Bool = false
}

public struct CookieClassification {
    public let essential: [HTTPCookie]
    public let functional: [HTTPCookie]
    public let analytics: [HTTPCookie]
    public let advertising: [HTTPCookie]
    public let unknown: [HTTPCookie]

    public var totalCount: Int {
        essential.count + functional.count + analytics.count + advertising.count + unknown.count
    }
}

public enum CookieType {
    case essential
    case functional
    case analytics
    case advertising
    case unknown
}
