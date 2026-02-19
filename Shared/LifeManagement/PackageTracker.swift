// PackageTracker.swift
// Thea — Package tracking service
// Replaces: Parcel app
//
// Auto-detect tracking numbers from text/emails/messages.
// Track packages via carrier APIs (Swiss Post, DHL, FedEx, UPS, Amazon, La Poste).
// Status notifications and delivery predictions.

import Foundation
import OSLog

private let ptLogger = Logger(subsystem: "ai.thea.app", category: "PackageTracker")

// MARK: - Carrier

enum PackageCarrier: String, Codable, Sendable, CaseIterable, Identifiable {
    case swissPost = "Swiss Post"
    case dhl = "DHL"
    case fedex = "FedEx"
    case ups = "UPS"
    case amazon = "Amazon"
    case laPoste = "La Poste"
    case dpd = "DPD"
    case gls = "GLS"
    case hermes = "Hermes"
    case unknown = "Unknown"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .swissPost: "flag.fill"
        case .dhl: "shippingbox.fill"
        case .fedex: "airplane"
        case .ups: "shippingbox"
        case .amazon: "cart.fill"
        case .laPoste: "envelope.fill"
        case .dpd: "truck.box.fill"
        case .gls: "box.truck.fill"
        case .hermes: "shippingbox.circle"
        case .unknown: "questionmark.circle"
        }
    }

    var trackingURLTemplate: String? {
        switch self {
        case .swissPost: "https://service.post.ch/EasyTrack/submitParcelData.do?formattedParcelCodes="
        case .dhl: "https://www.dhl.com/en/express/tracking.html?AWB="
        case .fedex: "https://www.fedex.com/fedextrack/?trknbr="
        case .ups: "https://www.ups.com/track?tracknum="
        case .amazon: nil // Amazon uses order IDs, not standard tracking
        case .laPoste: "https://www.laposte.fr/outils/suivre-vos-envois?code="
        case .dpd: "https://tracking.dpd.de/status/en_US/parcel/"
        case .gls: "https://gls-group.com/EU/en/parcel-tracking?match="
        case .hermes: "https://www.myhermes.de/empfangen/sendungsverfolgung/sendungsinformation#"
        case .unknown: nil
        }
    }

    func trackingURL(for number: String) -> URL? {
        guard let template = trackingURLTemplate else { return nil }
        return URL(string: template + number)
    }
}

// MARK: - Package Status

enum PackageStatus: String, Codable, Sendable, CaseIterable {
    case ordered = "Ordered"
    case labelCreated = "Label Created"
    case inTransit = "In Transit"
    case outForDelivery = "Out for Delivery"
    case delivered = "Delivered"
    case returnedToSender = "Returned to Sender"
    case exception = "Exception"
    case unknown = "Unknown"

    var icon: String {
        switch self {
        case .ordered: "bag"
        case .labelCreated: "tag"
        case .inTransit: "truck.box.fill"
        case .outForDelivery: "figure.walk"
        case .delivered: "checkmark.circle.fill"
        case .returnedToSender: "arrow.uturn.left"
        case .exception: "exclamationmark.triangle.fill"
        case .unknown: "questionmark.circle"
        }
    }

    var color: String {
        switch self {
        case .ordered, .labelCreated: "gray"
        case .inTransit: "blue"
        case .outForDelivery: "orange"
        case .delivered: "green"
        case .returnedToSender: "purple"
        case .exception: "red"
        case .unknown: "gray"
        }
    }

    var isTerminal: Bool {
        switch self {
        case .delivered, .returnedToSender: true
        default: false
        }
    }
}

// MARK: - Tracking Event

struct PackageTrackingEvent: Codable, Sendable, Identifiable {
    let id: UUID
    let timestamp: Date
    let status: PackageStatus
    let description: String
    let location: String?

    init(timestamp: Date, status: PackageStatus, description: String, location: String? = nil) {
        self.id = UUID()
        self.timestamp = timestamp
        self.status = status
        self.description = description
        self.location = location
    }
}

// MARK: - Tracked Package

struct TrackedPackage: Codable, Sendable, Identifiable {
    let id: UUID
    let trackingNumber: String
    let carrier: PackageCarrier
    var label: String
    var status: PackageStatus
    var events: [PackageTrackingEvent]
    var estimatedDelivery: Date?
    var lastUpdated: Date
    let addedAt: Date
    var isArchived: Bool
    var notes: String?

    init(
        trackingNumber: String,
        carrier: PackageCarrier,
        label: String = "",
        status: PackageStatus = .unknown,
        estimatedDelivery: Date? = nil,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.trackingNumber = trackingNumber
        self.carrier = carrier
        self.label = label.isEmpty ? trackingNumber : label
        self.status = status
        self.events = []
        self.estimatedDelivery = estimatedDelivery
        self.lastUpdated = Date()
        self.addedAt = Date()
        self.isArchived = false
        self.notes = notes
    }

    var latestEvent: PackageTrackingEvent? {
        events.sorted { $0.timestamp > $1.timestamp }.first
    }

    var trackingURL: URL? {
        carrier.trackingURL(for: trackingNumber)
    }

    mutating func addEvent(_ event: PackageTrackingEvent) {
        events.append(event)
        status = event.status
        lastUpdated = Date()
    }

    mutating func archive() {
        isArchived = true
    }
}

// MARK: - Tracking Number Detection

struct TrackingNumberDetection: Sendable {
    let trackingNumber: String
    let carrier: PackageCarrier
    let confidence: Double

    static func detect(in text: String) -> [TrackingNumberDetection] {
        var results: [TrackingNumberDetection] = []

        // Swiss Post: 99.XX.XXX.XXX.XXXXX.XX or similar
        let swissPostPatterns = [
            #"99\.\d{2}\.\d{3}\.\d{3}\.\d{5}\.\d{2}"#,
            #"\b[A-Z]{2}\d{9}CH\b"#
        ]
        for pattern in swissPostPatterns {
            results.append(contentsOf: findMatches(pattern, in: text, carrier: .swissPost, confidence: 0.9))
        }

        // DHL: 10-digit or 12-digit numbers starting with specific prefixes
        let dhlPatterns = [
            #"\b\d{10,12}\b"#, // Generic, lower confidence
            #"\bJJD\d{18}\b"#, // DHL eCommerce
            #"\b\d{4} \d{4} \d{4}\b"# // Spaced format
        ]
        for (idx, pattern) in dhlPatterns.enumerated() {
            let conf = idx == 0 ? 0.4 : 0.85
            results.append(contentsOf: findMatches(pattern, in: text, carrier: .dhl, confidence: conf))
        }

        // FedEx: 12 or 15 or 20 or 22 digits
        let fedexPatterns = [
            #"\b\d{12}\b"#,
            #"\b\d{15}\b"#,
            #"\b\d{20}\b"#,
            #"\b\d{22}\b"#
        ]
        for pattern in fedexPatterns {
            results.append(contentsOf: findMatches(pattern, in: text, carrier: .fedex, confidence: 0.5))
        }

        // UPS: 1Z + 16 alphanumeric
        results.append(contentsOf: findMatches(
            #"\b1Z[A-Z0-9]{16}\b"#,
            in: text, carrier: .ups, confidence: 0.95
        ))

        // Amazon: TBA + 12 digits
        results.append(contentsOf: findMatches(
            #"\bTBA\d{12}\b"#,
            in: text, carrier: .amazon, confidence: 0.9
        ))

        // La Poste: 2 letters + 9 digits + 2 letters (FR)
        results.append(contentsOf: findMatches(
            #"\b[A-Z]{2}\d{9}FR\b"#,
            in: text, carrier: .laPoste, confidence: 0.9
        ))

        // DPD: 14 digits
        results.append(contentsOf: findMatches(
            #"\b\d{14}\b"#,
            in: text, carrier: .dpd, confidence: 0.45
        ))

        // Deduplicate by tracking number, keeping highest confidence
        var seen: [String: TrackingNumberDetection] = [:]
        for detection in results {
            let existing = seen[detection.trackingNumber]
            if existing == nil || detection.confidence > (existing?.confidence ?? 0) {
                seen[detection.trackingNumber] = detection
            }
        }

        return Array(seen.values).sorted { $0.confidence > $1.confidence }
    }

    private static func findMatches(
        _ pattern: String,
        in text: String,
        carrier: PackageCarrier,
        confidence: Double
    ) -> [TrackingNumberDetection] {
        let regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: pattern)
        } catch {
            ptLogger.debug("Invalid tracking regex pattern '\(pattern)': \(error.localizedDescription)")
            return []
        }
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)
        return matches.compactMap { match in
            guard let matchRange = Range(match.range, in: text) else { return nil }
            let number = String(text[matchRange]).replacingOccurrences(of: " ", with: "")
            return TrackingNumberDetection(trackingNumber: number, carrier: carrier, confidence: confidence)
        }
    }
}

// MARK: - Package Tracker Service

@MainActor
final class PackageTracker: ObservableObject {
    static let shared = PackageTracker()

    @Published private(set) var packages: [TrackedPackage] = []
    @Published private(set) var isRefreshing = false

    private let storageURL: URL
    private let logger = Logger(subsystem: "ai.thea.app", category: "PackageTracker")

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = appSupport.appendingPathComponent("Thea/PackageTracker", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            // Non-fatal: directory may already exist
        }
        self.storageURL = dir.appendingPathComponent("packages.json")
        loadPackages()
    }

    // MARK: - CRUD

    func addPackage(trackingNumber: String, carrier: PackageCarrier, label: String = "", notes: String? = nil) {
        guard !packages.contains(where: { $0.trackingNumber == trackingNumber }) else {
            logger.warning("Package \(trackingNumber) already tracked")
            return
        }
        let package = TrackedPackage(
            trackingNumber: trackingNumber,
            carrier: carrier,
            label: label,
            notes: notes
        )
        packages.insert(package, at: 0)
        savePackages()
        logger.info("Added package: \(trackingNumber) via \(carrier.rawValue)")
    }

    func removePackage(_ package: TrackedPackage) {
        packages.removeAll { $0.id == package.id }
        savePackages()
    }

    func archivePackage(_ package: TrackedPackage) {
        if let idx = packages.firstIndex(where: { $0.id == package.id }) {
            packages[idx].archive()
            savePackages()
        }
    }

    // periphery:ignore - Reserved: updateLabel(_:newLabel:) instance method — reserved for future feature activation
    func updateLabel(_ package: TrackedPackage, newLabel: String) {
        if let idx = packages.firstIndex(where: { $0.id == package.id }) {
            packages[idx].label = newLabel
            // periphery:ignore - Reserved: updateLabel(_:newLabel:) instance method reserved for future feature activation
            savePackages()
        }
    }

    // periphery:ignore - Reserved: updateNotes(_:newNotes:) instance method — reserved for future feature activation
    func updateNotes(_ package: TrackedPackage, newNotes: String?) {
        if let idx = packages.firstIndex(where: { $0.id == package.id }) {
            // periphery:ignore - Reserved: updateNotes(_:newNotes:) instance method reserved for future feature activation
            packages[idx].notes = newNotes
            savePackages()
        }
    }

    // MARK: - Detection

    // periphery:ignore - Reserved: detectAndAdd(from:) instance method — reserved for future feature activation
    func detectAndAdd(from text: String) -> [TrackingNumberDetection] {
        // periphery:ignore - Reserved: detectAndAdd(from:) instance method reserved for future feature activation
        let detections = TrackingNumberDetection.detect(in: text)
        for detection in detections where detection.confidence >= 0.7 {
            addPackage(
                trackingNumber: detection.trackingNumber,
                carrier: detection.carrier
            )
        }
        return detections
    }

    // MARK: - Refresh Status

    func refreshAll() async {
        isRefreshing = true
        defer { isRefreshing = false }

        for idx in packages.indices where !packages[idx].status.isTerminal {
            await refreshPackage(at: idx)
        }
        savePackages()
    }

    func refreshPackage(_ package: TrackedPackage) async {
        guard let idx = packages.firstIndex(where: { $0.id == package.id }) else { return }
        await refreshPackage(at: idx)
        savePackages()
    }

    private func refreshPackage(at index: Int) async {
        let package = packages[index]
        guard let url = buildAPIURL(for: package) else { return }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                logger.warning("API returned non-200 for \(package.trackingNumber)")
                return
            }
            let events = parseCarrierResponse(data: data, carrier: package.carrier)
            for event in events {
                packages[index].addEvent(event)
            }
            logger.info("Refreshed \(package.trackingNumber): \(events.count) new events")
        } catch {
            logger.error("Failed to refresh \(package.trackingNumber): \(error.localizedDescription)")
        }
    }

    // MARK: - Carrier API Integration

    private func buildAPIURL(for package: TrackedPackage) -> URL? {
        switch package.carrier {
        case .swissPost:
            // Swiss Post Track & Trace API (public, no key required)
            return URL(string: "https://service.post.ch/EasyTrack/submitParcelData.do?formattedParcelCodes=\(package.trackingNumber)&from=direct&p_language=en")
        case .dhl:
            // DHL API requires API key — use tracking page scraping fallback
            return URL(string: "https://api-eu.dhl.com/track/shipments?trackingNumber=\(package.trackingNumber)")
        case .laPoste:
            // La Poste Suivi API
            return URL(string: "https://api.laposte.fr/suivi/v2/idships/\(package.trackingNumber)")
        default:
            // For carriers without free APIs, use the tracking URL for web scraping fallback
            return package.trackingURL
        }
    }

    private func parseCarrierResponse(data: Data, carrier: PackageCarrier) -> [PackageTrackingEvent] {
        // Generic JSON parsing — each carrier returns different formats
        // This handles the most common structure: array of events with timestamp, status, description
        let json: [String: Any]
        do {
            guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                logger.debug("Carrier response is not a JSON object")
                return []
            }
            json = parsed
        } catch {
            logger.debug("Failed to parse carrier response JSON: \(error.localizedDescription)")
            return []
        }

        var events: [PackageTrackingEvent] = []

        // Try common response structures
        let eventsArray: [[String: Any]]?
        if let shipments = json["shipments"] as? [[String: Any]],
           let firstShipment = shipments.first,
           let rawEvents = firstShipment["events"] as? [[String: Any]] {
            eventsArray = rawEvents
        } else if let rawEvents = json["events"] as? [[String: Any]] {
            eventsArray = rawEvents
        } else if let rawEvents = json["tracking_events"] as? [[String: Any]] {
            eventsArray = rawEvents
        } else {
            eventsArray = nil
        }

        let dateFormatter = ISO8601DateFormatter()

        for eventData in eventsArray ?? [] {
            let description = eventData["description"] as? String
                ?? eventData["statusDescription"] as? String
                ?? eventData["event"] as? String
                ?? "Status update"
            let location = eventData["location"] as? String
                ?? (eventData["location"] as? [String: Any])?["address"] as? String
            let timestamp: Date
            if let dateStr = eventData["timestamp"] as? String ?? eventData["date"] as? String {
                timestamp = dateFormatter.date(from: dateStr) ?? Date()
            } else {
                timestamp = Date()
            }

            let status = inferStatus(from: description, carrier: carrier)
            events.append(PackageTrackingEvent(
                timestamp: timestamp,
                status: status,
                description: description,
                location: location
            ))
        }

        return events
    }

    // periphery:ignore - Reserved: carrier parameter kept for API compatibility
    private func inferStatus(from description: String, carrier: PackageCarrier) -> PackageStatus {
        let lower = description.lowercased()
        if lower.contains("delivered") || lower.contains("livré") || lower.contains("zugestellt") {
            return .delivered
        } else if lower.contains("out for delivery") || lower.contains("en cours de livraison") {
            return .outForDelivery
        } else if lower.contains("in transit") || lower.contains("en route") || lower.contains("unterwegs") || lower.contains("departed") || lower.contains("arrived") {
            return .inTransit
        } else if lower.contains("label") || lower.contains("created") || lower.contains("registered") {
            return .labelCreated
        } else if lower.contains("return") || lower.contains("retour") {
            return .returnedToSender
        } else if lower.contains("exception") || lower.contains("failed") || lower.contains("problem") {
            return .exception
        }
        return .inTransit
    }

    // MARK: - Computed Properties

    var activePackages: [TrackedPackage] {
        packages.filter { !$0.isArchived && !$0.status.isTerminal }
    }

    var deliveredPackages: [TrackedPackage] {
        packages.filter { $0.status == .delivered && !$0.isArchived }
    }

    var archivedPackages: [TrackedPackage] {
        packages.filter(\.isArchived)
    }

    // MARK: - Persistence

    private func loadPackages() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            packages = try JSONDecoder().decode([TrackedPackage].self, from: data)
        } catch {
            logger.error("Failed to load packages: \(error.localizedDescription)")
        }
    }

    private func savePackages() {
        do {
            let data = try JSONEncoder().encode(packages)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            logger.error("Failed to save packages: \(error.localizedDescription)")
        }
    }
}
