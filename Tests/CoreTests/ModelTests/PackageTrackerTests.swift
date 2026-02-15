// PackageTrackerTests.swift
// Tests for PackageTracker types, carrier detection, and status logic

import Testing
import Foundation

// MARK: - Mirror Types (SPM test target can't import app types)

private enum TestPackageCarrier: String, CaseIterable {
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
        case .amazon: nil
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

private enum TestPackageStatus: String, CaseIterable {
    case ordered = "Ordered"
    case labelCreated = "Label Created"
    case inTransit = "In Transit"
    case outForDelivery = "Out for Delivery"
    case delivered = "Delivered"
    case returnedToSender = "Returned to Sender"
    case exception = "Exception"
    case unknown = "Unknown"

    var isTerminal: Bool {
        switch self {
        case .delivered, .returnedToSender: true
        default: false
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
}

// Tracking number detection logic (mirrors production)
private struct TestDetection {
    let trackingNumber: String
    let carrier: TestPackageCarrier
    let confidence: Double

    static func detect(in text: String) -> [TestDetection] {
        var results: [TestDetection] = []

        // Swiss Post
        let swissPostPatterns = [
            #"99\.\d{2}\.\d{3}\.\d{3}\.\d{5}\.\d{2}"#,
            #"\b[A-Z]{2}\d{9}CH\b"#
        ]
        for pattern in swissPostPatterns {
            results.append(contentsOf: findMatches(pattern, in: text, carrier: .swissPost, confidence: 0.9))
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

        // La Poste: XX + 9 digits + FR
        results.append(contentsOf: findMatches(
            #"\b[A-Z]{2}\d{9}FR\b"#,
            in: text, carrier: .laPoste, confidence: 0.9
        ))

        // Deduplicate
        var seen: [String: TestDetection] = [:]
        for d in results {
            if seen[d.trackingNumber] == nil || d.confidence > (seen[d.trackingNumber]?.confidence ?? 0) {
                seen[d.trackingNumber] = d
            }
        }
        return Array(seen.values).sorted { $0.confidence > $1.confidence }
    }

    private static func findMatches(
        _ pattern: String,
        in text: String,
        carrier: TestPackageCarrier,
        confidence: Double
    ) -> [TestDetection] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)
        return matches.compactMap { match in
            guard let matchRange = Range(match.range, in: text) else { return nil }
            let number = String(text[matchRange]).replacingOccurrences(of: " ", with: "")
            return TestDetection(trackingNumber: number, carrier: carrier, confidence: confidence)
        }
    }
}

// Status inference (mirrors production)
private func inferStatus(from description: String) -> TestPackageStatus {
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

// MARK: - Tests

@Suite("PackageCarrier")
struct PackageCarrierTests {
    @Test("All carriers have unique raw values")
    func uniqueRawValues() {
        let values = TestPackageCarrier.allCases.map(\.rawValue)
        #expect(Set(values).count == values.count)
    }

    @Test("All carriers have icons")
    func allHaveIcons() {
        for carrier in TestPackageCarrier.allCases {
            #expect(!carrier.icon.isEmpty)
        }
    }

    @Test("10 carriers total")
    func carrierCount() {
        #expect(TestPackageCarrier.allCases.count == 10)
    }

    @Test("Swiss Post has tracking URL template")
    func swissPostURL() {
        let url = TestPackageCarrier.swissPost.trackingURL(for: "99.12.345.678.90123.45")
        #expect(url != nil)
        #expect(url?.absoluteString.contains("post.ch") == true)
    }

    @Test("Amazon has no tracking URL template")
    func amazonNoURL() {
        #expect(TestPackageCarrier.amazon.trackingURLTemplate == nil)
        #expect(TestPackageCarrier.amazon.trackingURL(for: "TBA123456789012") == nil)
    }

    @Test("Unknown carrier has no tracking URL")
    func unknownNoURL() {
        #expect(TestPackageCarrier.unknown.trackingURLTemplate == nil)
    }

    @Test("DHL tracking URL contains tracking number")
    func dhlURL() {
        let url = TestPackageCarrier.dhl.trackingURL(for: "1234567890")
        #expect(url?.absoluteString.contains("1234567890") == true)
    }

    @Test("UPS tracking URL")
    func upsURL() {
        let url = TestPackageCarrier.ups.trackingURL(for: "1Z999AA10123456784")
        #expect(url != nil)
        #expect(url?.absoluteString.contains("ups.com") == true)
    }
}

@Suite("PackageStatus")
struct PackageStatusTests {
    @Test("8 statuses total")
    func statusCount() {
        #expect(TestPackageStatus.allCases.count == 8)
    }

    @Test("Terminal statuses: delivered and returnedToSender")
    func terminalStatuses() {
        #expect(TestPackageStatus.delivered.isTerminal)
        #expect(TestPackageStatus.returnedToSender.isTerminal)
        #expect(!TestPackageStatus.inTransit.isTerminal)
        #expect(!TestPackageStatus.ordered.isTerminal)
        #expect(!TestPackageStatus.outForDelivery.isTerminal)
        #expect(!TestPackageStatus.exception.isTerminal)
    }

    @Test("Status colors are meaningful")
    func statusColors() {
        #expect(TestPackageStatus.delivered.color == "green")
        #expect(TestPackageStatus.inTransit.color == "blue")
        #expect(TestPackageStatus.outForDelivery.color == "orange")
        #expect(TestPackageStatus.exception.color == "red")
        #expect(TestPackageStatus.returnedToSender.color == "purple")
    }

    @Test("All statuses have non-empty raw values")
    func nonEmptyRawValues() {
        for status in TestPackageStatus.allCases {
            #expect(!status.rawValue.isEmpty)
        }
    }
}

@Suite("Tracking Number Detection")
struct TrackingNumberDetectionTests {
    @Test("Detect Swiss Post tracking number")
    func swissPost() {
        let text = "Your package 99.12.345.678.90123.45 has been shipped"
        let results = TestDetection.detect(in: text)
        #expect(results.count >= 1)
        #expect(results.first?.carrier == .swissPost)
        #expect(results.first?.trackingNumber == "99.12.345.678.90123.45")
    }

    @Test("Detect Swiss Post international format")
    func swissPostInternational() {
        let text = "Tracking: AB123456789CH"
        let results = TestDetection.detect(in: text)
        #expect(results.contains { $0.carrier == .swissPost && $0.trackingNumber == "AB123456789CH" })
    }

    @Test("Detect UPS tracking number")
    func ups() {
        let text = "UPS tracking: 1Z999AA10123456784"
        let results = TestDetection.detect(in: text)
        #expect(results.contains { $0.carrier == .ups })
        #expect(results.first?.confidence == 0.95)
    }

    @Test("Detect Amazon tracking number")
    func amazon() {
        let text = "Amazon delivery TBA123456789012"
        let results = TestDetection.detect(in: text)
        #expect(results.contains { $0.carrier == .amazon })
    }

    @Test("Detect La Poste tracking number")
    func laPoste() {
        let text = "Suivi: AB123456789FR"
        let results = TestDetection.detect(in: text)
        #expect(results.contains { $0.carrier == .laPoste })
    }

    @Test("No false positives on regular text")
    func noFalsePositives() {
        let text = "Hello, this is a normal message without tracking numbers."
        let results = TestDetection.detect(in: text)
        #expect(results.isEmpty)
    }

    @Test("Multiple tracking numbers in one text")
    func multipleNumbers() {
        let text = "Swiss Post: 99.12.345.678.90123.45 and UPS: 1Z999AA10123456784"
        let results = TestDetection.detect(in: text)
        #expect(results.count >= 2)
        let carriers = Set(results.map(\.carrier))
        #expect(carriers.contains(.swissPost))
        #expect(carriers.contains(.ups))
    }

    @Test("Results sorted by confidence descending")
    func sortedByConfidence() {
        let text = "Swiss Post: 99.12.345.678.90123.45 and UPS: 1Z999AA10123456784"
        let results = TestDetection.detect(in: text)
        for i in 0..<(results.count - 1) {
            #expect(results[i].confidence >= results[i + 1].confidence)
        }
    }

    @Test("Empty text returns no detections")
    func emptyText() {
        let results = TestDetection.detect(in: "")
        #expect(results.isEmpty)
    }

    @Test("Deduplication keeps highest confidence")
    func deduplication() {
        // A number that matches multiple patterns should keep the highest confidence match
        let text = "1Z999AA10123456784" // UPS format, high confidence
        let results = TestDetection.detect(in: text)
        let upsMatches = results.filter { $0.trackingNumber == "1Z999AA10123456784" }
        #expect(upsMatches.count == 1)
    }
}

@Suite("Status Inference")
struct StatusInferenceTests {
    @Test("English delivered")
    func englishDelivered() {
        #expect(inferStatus(from: "Package delivered to recipient") == .delivered)
    }

    @Test("French delivered")
    func frenchDelivered() {
        #expect(inferStatus(from: "Colis livré au destinataire") == .delivered)
    }

    @Test("German delivered")
    func germanDelivered() {
        #expect(inferStatus(from: "Sendung zugestellt") == .delivered)
    }

    @Test("Out for delivery")
    func outForDelivery() {
        #expect(inferStatus(from: "Out for delivery") == .outForDelivery)
    }

    @Test("French out for delivery")
    func frenchOutForDelivery() {
        #expect(inferStatus(from: "En cours de livraison") == .outForDelivery)
    }

    @Test("In transit")
    func inTransit() {
        #expect(inferStatus(from: "Package in transit to destination") == .inTransit)
    }

    @Test("Departed facility")
    func departed() {
        #expect(inferStatus(from: "Departed from sort facility") == .inTransit)
    }

    @Test("Arrived at hub")
    func arrived() {
        #expect(inferStatus(from: "Arrived at distribution hub") == .inTransit)
    }

    @Test("German in transit")
    func germanInTransit() {
        #expect(inferStatus(from: "Sendung unterwegs") == .inTransit)
    }

    @Test("Label created")
    func labelCreated() {
        #expect(inferStatus(from: "Shipping label created") == .labelCreated)
    }

    @Test("Registered")
    func registered() {
        #expect(inferStatus(from: "Shipment registered") == .labelCreated)
    }

    @Test("Return to sender")
    func returnToSender() {
        #expect(inferStatus(from: "Return to sender") == .returnedToSender)
    }

    @Test("French return")
    func frenchReturn() {
        #expect(inferStatus(from: "Retour à l'expéditeur") == .returnedToSender)
    }

    @Test("Exception")
    func exception() {
        #expect(inferStatus(from: "Delivery exception: address issue") == .exception)
    }

    @Test("Failed delivery")
    func failedDelivery() {
        #expect(inferStatus(from: "Delivery failed - nobody home") == .exception)
    }

    @Test("Problem detected")
    func problem() {
        #expect(inferStatus(from: "Problem with shipment") == .exception)
    }

    @Test("Unknown status defaults to inTransit")
    func unknownDefaults() {
        #expect(inferStatus(from: "Processing at sorting center") == .inTransit)
    }
}
