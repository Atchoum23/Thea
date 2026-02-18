// QRIntelligence.swift
// Thea — QR/barcode scanning + understanding + auto-action
// Replaces: QR Capture
//
// Vision framework VNDetectBarcodesRequest. Auto-action: URLs → open,
// contacts → save, WiFi → connect, payment → process.

import Foundation
import OSLog
import Vision

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

private let qrLogger = Logger(subsystem: "ai.thea.app", category: "QRIntelligence")

// MARK: - Data Types

enum QRContentType: String, Codable, Sendable, CaseIterable {
    case url
    case text
    case email
    case phone
    case sms
    case wifi
    case vcard
    case geolocation
    case calendar
    case unknown

    var icon: String {
        switch self {
        case .url: "link"
        case .text: "doc.text"
        case .email: "envelope"
        case .phone: "phone"
        case .sms: "message"
        case .wifi: "wifi"
        case .vcard: "person.crop.rectangle"
        case .geolocation: "map"
        case .calendar: "calendar"
        case .unknown: "qrcode"
        }
    }

    var displayName: String {
        switch self {
        case .url: "URL"
        case .text: "Text"
        case .email: "Email"
        case .phone: "Phone"
        case .sms: "SMS"
        case .wifi: "WiFi"
        case .vcard: "Contact"
        case .geolocation: "Location"
        case .calendar: "Calendar Event"
        case .unknown: "Unknown"
        }
    }
}

struct QRAction: Codable, Sendable, Identifiable {
    let id: UUID
    let label: String
    let icon: String
    let actionType: QRActionType

    init(label: String, icon: String, actionType: QRActionType) {
        self.id = UUID()
        self.label = label
        self.icon = icon
        self.actionType = actionType
    }
}

enum QRActionType: String, Codable, Sendable {
    case openURL
    case copyToClipboard
    case shareContent
    case composeEmail
    case callPhone
    case sendSMS
    case connectWiFi
    case addContact
    case openMap
    case addCalendarEvent
}

struct ScannedQRCode: Codable, Sendable, Identifiable {
    let id: UUID
    let rawContent: String
    let contentType: QRContentType
    let parsedData: [String: String]
    let suggestedActions: [QRAction]
    let scannedAt: Date
    var isFavorite: Bool

    init(rawContent: String, contentType: QRContentType, parsedData: [String: String], suggestedActions: [QRAction]) {
        self.id = UUID()
        self.rawContent = rawContent
        self.contentType = contentType
        self.parsedData = parsedData
        self.suggestedActions = suggestedActions
        self.scannedAt = Date()
        self.isFavorite = false
    }

    var displayTitle: String {
        switch contentType {
        case .url:
            return parsedData["host"] ?? rawContent
        case .email:
            return parsedData["address"] ?? rawContent
        case .phone:
            return parsedData["number"] ?? rawContent
        case .wifi:
            return "WiFi: \(parsedData["ssid"] ?? "Unknown")"
        case .vcard:
            return parsedData["name"] ?? "Contact"
        case .geolocation:
            return "Location: \(parsedData["latitude"] ?? ""), \(parsedData["longitude"] ?? "")"
        case .calendar:
            return parsedData["summary"] ?? "Event"
        default:
            return String(rawContent.prefix(50))
        }
    }
}

// MARK: - QR Content Parser

struct QRContentParser: Sendable {

    // swiftlint:disable:next function_body_length
    static func parse(_ content: String) -> (QRContentType, [String: String], [QRAction]) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        // URL
        if let url = URL(string: trimmed),
           let scheme = url.scheme?.lowercased(),
           ["http", "https", "ftp"].contains(scheme) {
            let data = ["url": trimmed, "host": url.host ?? "", "scheme": scheme]
            let actions = [
                QRAction(label: "Open URL", icon: "safari", actionType: .openURL),
                QRAction(label: "Copy URL", icon: "doc.on.doc", actionType: .copyToClipboard),
                QRAction(label: "Share", icon: "square.and.arrow.up", actionType: .shareContent)
            ]
            return (.url, data, actions)
        }

        // Email (mailto:)
        if trimmed.lowercased().hasPrefix("mailto:") {
            let address = String(trimmed.dropFirst(7)).components(separatedBy: "?").first ?? ""
            let data = ["address": address, "raw": trimmed]
            let actions = [
                QRAction(label: "Send Email", icon: "envelope", actionType: .composeEmail),
                QRAction(label: "Copy Address", icon: "doc.on.doc", actionType: .copyToClipboard)
            ]
            return (.email, data, actions)
        }

        // Phone (tel:)
        if trimmed.lowercased().hasPrefix("tel:") {
            let number = String(trimmed.dropFirst(4))
            let data = ["number": number]
            let actions = [
                QRAction(label: "Call", icon: "phone", actionType: .callPhone),
                QRAction(label: "Copy Number", icon: "doc.on.doc", actionType: .copyToClipboard)
            ]
            return (.phone, data, actions)
        }

        // SMS (smsto: or sms:)
        if trimmed.lowercased().hasPrefix("sms:") || trimmed.lowercased().hasPrefix("smsto:") {
            let parts = trimmed.dropFirst(trimmed.lowercased().hasPrefix("smsto:") ? 6 : 4)
            let components = parts.components(separatedBy: ":")
            let number = components.first ?? ""
            let message = components.count > 1 ? components[1] : ""
            let data = ["number": number, "message": message]
            let actions = [
                QRAction(label: "Send SMS", icon: "message", actionType: .sendSMS),
                QRAction(label: "Copy Number", icon: "doc.on.doc", actionType: .copyToClipboard)
            ]
            return (.sms, data, actions)
        }

        // WiFi (WIFI:S:ssid;T:WPA;P:password;;)
        if trimmed.uppercased().hasPrefix("WIFI:") {
            let wifiData = parseWiFi(trimmed)
            let actions = [
                QRAction(label: "Connect to WiFi", icon: "wifi", actionType: .connectWiFi),
                QRAction(label: "Copy Password", icon: "doc.on.doc", actionType: .copyToClipboard)
            ]
            return (.wifi, wifiData, actions)
        }

        // vCard
        if trimmed.hasPrefix("BEGIN:VCARD") {
            let vcardData = parseVCard(trimmed)
            let actions = [
                QRAction(label: "Add Contact", icon: "person.crop.circle.badge.plus", actionType: .addContact),
                QRAction(label: "Copy", icon: "doc.on.doc", actionType: .copyToClipboard)
            ]
            return (.vcard, vcardData, actions)
        }

        // Geolocation (geo:lat,lon)
        if trimmed.lowercased().hasPrefix("geo:") {
            let coords = String(trimmed.dropFirst(4)).components(separatedBy: ",")
            let lat = coords.first?.trimmingCharacters(in: .whitespaces) ?? ""
            let lon = coords.count > 1 ? coords[1].components(separatedBy: "?").first?.trimmingCharacters(in: .whitespaces) ?? "" : ""
            let data = ["latitude": lat, "longitude": lon]
            let actions = [
                QRAction(label: "Open in Maps", icon: "map", actionType: .openMap),
                QRAction(label: "Copy Coordinates", icon: "doc.on.doc", actionType: .copyToClipboard)
            ]
            return (.geolocation, data, actions)
        }

        // Calendar (VEVENT)
        if trimmed.hasPrefix("BEGIN:VEVENT") || trimmed.hasPrefix("BEGIN:VCALENDAR") {
            let eventData = parseCalendarEvent(trimmed)
            let actions = [
                QRAction(label: "Add to Calendar", icon: "calendar.badge.plus", actionType: .addCalendarEvent),
                QRAction(label: "Copy", icon: "doc.on.doc", actionType: .copyToClipboard)
            ]
            return (.calendar, eventData, actions)
        }

        // Email pattern (no mailto: prefix)
        let emailPattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        if trimmed.range(of: emailPattern, options: .regularExpression) != nil {
            let data = ["address": trimmed]
            let actions = [
                QRAction(label: "Send Email", icon: "envelope", actionType: .composeEmail),
                QRAction(label: "Copy", icon: "doc.on.doc", actionType: .copyToClipboard)
            ]
            return (.email, data, actions)
        }

        // Phone pattern (no tel: prefix)
        let phonePattern = #"^\+?[\d\s\-\(\)]{7,}$"#
        if trimmed.range(of: phonePattern, options: .regularExpression) != nil {
            let data = ["number": trimmed]
            let actions = [
                QRAction(label: "Call", icon: "phone", actionType: .callPhone),
                QRAction(label: "Copy", icon: "doc.on.doc", actionType: .copyToClipboard)
            ]
            return (.phone, data, actions)
        }

        // Plain text
        let data = ["text": trimmed]
        let actions = [
            QRAction(label: "Copy Text", icon: "doc.on.doc", actionType: .copyToClipboard),
            QRAction(label: "Share", icon: "square.and.arrow.up", actionType: .shareContent)
        ]
        return (.text, data, actions)
    }

    // MARK: - WiFi Parser

    private static func parseWiFi(_ content: String) -> [String: String] {
        var data: [String: String] = [:]
        let body = String(content.dropFirst(5)) // Remove "WIFI:"

        let fields = body.components(separatedBy: ";")
        for field in fields {
            let parts = field.components(separatedBy: ":")
            guard parts.count >= 2 else { continue }
            let key = parts[0].uppercased()
            let value = parts.dropFirst().joined(separator: ":")
            switch key {
            case "S": data["ssid"] = value
            case "T": data["security"] = value
            case "P": data["password"] = value
            case "H": data["hidden"] = value
            default: break
            }
        }

        return data
    }

    // MARK: - vCard Parser

    private static func parseVCard(_ content: String) -> [String: String] {
        var data: [String: String] = [:]
        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let parts = line.components(separatedBy: ":")
            guard parts.count >= 2 else { continue }
            let key = parts[0].components(separatedBy: ";").first?.uppercased() ?? ""
            let value = parts.dropFirst().joined(separator: ":")

            switch key {
            case "FN": data["name"] = value
            case "TEL": data["phone"] = value
            case "EMAIL": data["email"] = value
            case "ORG": data["organization"] = value
            case "TITLE": data["title"] = value
            case "URL": data["url"] = value
            case "ADR": data["address"] = value.replacingOccurrences(of: ";", with: ", ")
            default: break
            }
        }

        return data
    }

    // MARK: - Calendar Event Parser

    private static func parseCalendarEvent(_ content: String) -> [String: String] {
        var data: [String: String] = [:]
        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let parts = line.components(separatedBy: ":")
            guard parts.count >= 2 else { continue }
            let key = parts[0].components(separatedBy: ";").first?.uppercased() ?? ""
            let value = parts.dropFirst().joined(separator: ":")

            switch key {
            case "SUMMARY": data["summary"] = value
            case "DTSTART": data["start"] = value
            case "DTEND": data["end"] = value
            case "LOCATION": data["location"] = value
            case "DESCRIPTION": data["description"] = value
            default: break
            }
        }

        return data
    }
}

// MARK: - QRIntelligence Service

@MainActor
@Observable
final class QRIntelligence {
    static let shared = QRIntelligence()

    private(set) var scannedCodes: [ScannedQRCode] = []
    private(set) var isScanning = false

    private let fileManager = FileManager.default
    private let storageDir: URL

    private init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        storageDir = appSupport.appendingPathComponent("Thea/QRCodes")
        do {
            try fileManager.createDirectory(at: storageDir, withIntermediateDirectories: true)
        } catch {
            qrLogger.error("Failed to create QR storage directory: \(error.localizedDescription)")
        }
        loadCodes()
    }

    // MARK: - Image Scanning

    func scanImage(_ cgImage: CGImage) async -> ScannedQRCode? {
        isScanning = true
        defer { isScanning = false }

        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr, .ean8, .ean13, .code128, .code39, .dataMatrix, .aztec, .pdf417]

        let handler = VNImageRequestHandler(cgImage: cgImage)

        do {
            try handler.perform([request])
        } catch {
            qrLogger.error("Vision barcode detection failed: \(error.localizedDescription)")
            return nil
        }

        guard let results = request.results, let firstBarcode = results.first,
              let payload = firstBarcode.payloadStringValue else {
            qrLogger.info("No barcode detected in image")
            return nil
        }

        let (contentType, parsedData, actions) = QRContentParser.parse(payload)
        let code = ScannedQRCode(
            rawContent: payload,
            contentType: contentType,
            parsedData: parsedData,
            suggestedActions: actions
        )

        scannedCodes.insert(code, at: 0)
        if scannedCodes.count > 200 {
            scannedCodes = Array(scannedCodes.prefix(200))
        }
        saveCodes()

        qrLogger.info("Scanned QR: \(contentType.rawValue) — \(String(payload.prefix(50)))")
        return code
    }

    func processRawContent(_ content: String) -> ScannedQRCode {
        let (contentType, parsedData, actions) = QRContentParser.parse(content)
        let code = ScannedQRCode(
            rawContent: content,
            contentType: contentType,
            parsedData: parsedData,
            suggestedActions: actions
        )

        scannedCodes.insert(code, at: 0)
        if scannedCodes.count > 200 {
            scannedCodes = Array(scannedCodes.prefix(200))
        }
        saveCodes()

        return code
    }

    // MARK: - CRUD

    func deleteCode(_ code: ScannedQRCode) {
        scannedCodes.removeAll { $0.id == code.id }
        saveCodes()
    }

    func toggleFavorite(_ codeID: UUID) {
        guard let index = scannedCodes.firstIndex(where: { $0.id == codeID }) else { return }
        scannedCodes[index].isFavorite.toggle()
        saveCodes()
    }

    func searchCodes(query: String) -> [ScannedQRCode] {
        guard !query.isEmpty else { return scannedCodes }
        let q = query.lowercased()
        return scannedCodes.filter {
            $0.rawContent.lowercased().contains(q) ||
            $0.displayTitle.lowercased().contains(q) ||
            $0.contentType.displayName.lowercased().contains(q)
        }
    }

    // MARK: - Persistence

    private var storageFile: URL { storageDir.appendingPathComponent("scanned_codes.json") }

    private func loadCodes() {
        guard FileManager.default.fileExists(atPath: storageFile.path) else { return }
        do {
            let data = try Data(contentsOf: storageFile)
            self.scannedCodes = try JSONDecoder().decode([ScannedQRCode].self, from: data)
        } catch {
            qrLogger.error("Failed to load QR codes: \(error.localizedDescription)")
        }
    }

    private func saveCodes() {
        do {
            let data = try JSONEncoder().encode(scannedCodes)
            try data.write(to: storageFile, options: .atomic)
        } catch {
            qrLogger.error("Failed to save QR codes: \(error.localizedDescription)")
        }
    }
}
