// QRIntelligenceTests.swift
// Tests for QR code content parsing, type detection, and action suggestions

import Foundation
import Testing

// MARK: - Test Doubles

private enum TestQRContentType: String, CaseIterable, Sendable {
    case url, text, email, phone, sms, wifi, vcard, geolocation, calendar, unknown

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

private enum TestQRActionType: String, Sendable {
    case openURL, copyToClipboard, shareContent, composeEmail
    case callPhone, sendSMS, connectWiFi, addContact, openMap, addCalendarEvent
}

// swiftlint:disable:next cyclomatic_complexity
private func parseQR(_ content: String) -> (TestQRContentType, [String: String], [TestQRActionType]) {
    let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

    // URL
    if let url = URL(string: trimmed),
       let scheme = url.scheme?.lowercased(),
       ["http", "https", "ftp"].contains(scheme) {
        return (.url, ["url": trimmed, "host": url.host ?? ""], [.openURL, .copyToClipboard, .shareContent])
    }

    // mailto:
    if trimmed.lowercased().hasPrefix("mailto:") {
        let address = String(trimmed.dropFirst(7)).components(separatedBy: "?").first ?? ""
        return (.email, ["address": address], [.composeEmail, .copyToClipboard])
    }

    // tel:
    if trimmed.lowercased().hasPrefix("tel:") {
        let number = String(trimmed.dropFirst(4))
        return (.phone, ["number": number], [.callPhone, .copyToClipboard])
    }

    // sms:
    if trimmed.lowercased().hasPrefix("sms:") || trimmed.lowercased().hasPrefix("smsto:") {
        let offset = trimmed.lowercased().hasPrefix("smsto:") ? 6 : 4
        let parts = String(trimmed.dropFirst(offset)).components(separatedBy: ":")
        return (.sms, ["number": parts.first ?? ""], [.sendSMS, .copyToClipboard])
    }

    // WIFI:
    if trimmed.uppercased().hasPrefix("WIFI:") {
        var data: [String: String] = [:]
        let body = String(trimmed.dropFirst(5))
        for field in body.components(separatedBy: ";") {
            let parts = field.components(separatedBy: ":")
            guard parts.count >= 2 else { continue }
            switch parts[0].uppercased() {
            case "S": data["ssid"] = parts.dropFirst().joined(separator: ":")
            case "T": data["security"] = parts[1]
            case "P": data["password"] = parts.dropFirst().joined(separator: ":")
            case "H": data["hidden"] = parts[1]
            default: break
            }
        }
        return (.wifi, data, [.connectWiFi, .copyToClipboard])
    }

    // vCard
    if trimmed.hasPrefix("BEGIN:VCARD") {
        var data: [String: String] = [:]
        for line in trimmed.components(separatedBy: .newlines) {
            let parts = line.components(separatedBy: ":")
            guard parts.count >= 2 else { continue }
            let key = parts[0].components(separatedBy: ";").first?.uppercased() ?? ""
            let value = parts.dropFirst().joined(separator: ":")
            switch key {
            case "FN": data["name"] = value
            case "TEL": data["phone"] = value
            case "EMAIL": data["email"] = value
            default: break
            }
        }
        return (.vcard, data, [.addContact, .copyToClipboard])
    }

    // geo:
    if trimmed.lowercased().hasPrefix("geo:") {
        let coords = String(trimmed.dropFirst(4)).components(separatedBy: ",")
        let lat = coords.first?.trimmingCharacters(in: .whitespaces) ?? ""
        let lon = coords.count > 1 ? coords[1].components(separatedBy: "?").first?.trimmingCharacters(in: .whitespaces) ?? "" : ""
        return (.geolocation, ["latitude": lat, "longitude": lon], [.openMap, .copyToClipboard])
    }

    // Calendar
    if trimmed.hasPrefix("BEGIN:VEVENT") || trimmed.hasPrefix("BEGIN:VCALENDAR") {
        var data: [String: String] = [:]
        for line in trimmed.components(separatedBy: .newlines) {
            let parts = line.components(separatedBy: ":")
            guard parts.count >= 2 else { continue }
            let key = parts[0].components(separatedBy: ";").first?.uppercased() ?? ""
            let value = parts.dropFirst().joined(separator: ":")
            if key == "SUMMARY" { data["summary"] = value }
        }
        return (.calendar, data, [.addCalendarEvent, .copyToClipboard])
    }

    // Email pattern
    let emailPattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
    if trimmed.range(of: emailPattern, options: .regularExpression) != nil {
        return (.email, ["address": trimmed], [.composeEmail, .copyToClipboard])
    }

    // Phone pattern
    let phonePattern = #"^\+?[\d\s\-\(\)]{7,}$"#
    if trimmed.range(of: phonePattern, options: .regularExpression) != nil {
        return (.phone, ["number": trimmed], [.callPhone, .copyToClipboard])
    }

    return (.text, ["text": trimmed], [.copyToClipboard, .shareContent])
}

// MARK: - Content Type Tests

@Suite("QRIntelligence — Content Types")
struct QRContentTypeTests {
    @Test("All 10 content types exist")
    func allTypes() {
        #expect(TestQRContentType.allCases.count == 10)
    }

    @Test("All types have unique icons")
    func uniqueIcons() {
        let icons = TestQRContentType.allCases.map(\.icon)
        #expect(Set(icons).count == icons.count)
    }

    @Test("All types have display names")
    func displayNames() {
        for type in TestQRContentType.allCases {
            #expect(!type.displayName.isEmpty)
        }
    }
}

// MARK: - URL Detection Tests

@Suite("QRIntelligence — URL Detection")
struct QRURLDetectionTests {
    @Test("HTTP URL detected")
    func httpURL() {
        let (type, data, actions) = parseQR("http://example.com")
        #expect(type == .url)
        #expect(data["host"] == "example.com")
        #expect(actions.contains(.openURL))
    }

    @Test("HTTPS URL detected")
    func httpsURL() {
        let (type, data, _) = parseQR("https://www.example.com/path?q=test")
        #expect(type == .url)
        #expect(data["host"] == "www.example.com")
    }

    @Test("FTP URL detected")
    func ftpURL() {
        let (type, _, _) = parseQR("ftp://files.example.com/doc.pdf")
        #expect(type == .url)
    }

    @Test("URL actions include open, copy, share")
    func urlActions() {
        let (_, _, actions) = parseQR("https://example.com")
        #expect(actions.contains(.openURL))
        #expect(actions.contains(.copyToClipboard))
        #expect(actions.contains(.shareContent))
    }
}

// MARK: - Email Detection Tests

@Suite("QRIntelligence — Email Detection")
struct QREmailDetectionTests {
    @Test("Mailto URI detected")
    func mailtoURI() {
        let (type, data, actions) = parseQR("mailto:user@example.com")
        #expect(type == .email)
        #expect(data["address"] == "user@example.com")
        #expect(actions.contains(.composeEmail))
    }

    @Test("Bare email address detected")
    func bareEmail() {
        let (type, data, _) = parseQR("user@example.com")
        #expect(type == .email)
        #expect(data["address"] == "user@example.com")
    }

    @Test("Mailto with parameters")
    func mailtoWithParams() {
        let (type, data, _) = parseQR("mailto:user@example.com?subject=Hello")
        #expect(type == .email)
        #expect(data["address"] == "user@example.com")
    }
}

// MARK: - Phone Detection Tests

@Suite("QRIntelligence — Phone Detection")
struct QRPhoneDetectionTests {
    @Test("Tel URI detected")
    func telURI() {
        let (type, data, actions) = parseQR("tel:+41791234567")
        #expect(type == .phone)
        #expect(data["number"] == "+41791234567")
        #expect(actions.contains(.callPhone))
    }

    @Test("Bare phone number detected")
    func barePhone() {
        let (type, data, _) = parseQR("+1 (555) 123-4567")
        #expect(type == .phone)
        #expect(data["number"] == "+1 (555) 123-4567")
    }
}

// MARK: - SMS Detection Tests

@Suite("QRIntelligence — SMS Detection")
struct QRSMSDetectionTests {
    @Test("SMS URI detected")
    func smsURI() {
        let (type, data, actions) = parseQR("sms:+41791234567")
        #expect(type == .sms)
        #expect(data["number"] == "+41791234567")
        #expect(actions.contains(.sendSMS))
    }

    @Test("SMSTO URI detected")
    func smstoURI() {
        let (type, data, _) = parseQR("smsto:+41791234567")
        #expect(type == .sms)
        #expect(data["number"] == "+41791234567")
    }
}

// MARK: - WiFi Detection Tests

@Suite("QRIntelligence — WiFi Detection")
struct QRWiFiDetectionTests {
    @Test("WiFi QR code parsed")
    func wifiParsed() {
        let (type, data, actions) = parseQR("WIFI:S:MyNetwork;T:WPA;P:MyPassword;;")
        #expect(type == .wifi)
        #expect(data["ssid"] == "MyNetwork")
        #expect(data["security"] == "WPA")
        #expect(data["password"] == "MyPassword")
        #expect(actions.contains(.connectWiFi))
    }

    @Test("WiFi with hidden network")
    func wifiHidden() {
        let (_, data, _) = parseQR("WIFI:S:Secret;T:WPA2;P:pass123;H:true;;")
        #expect(data["hidden"] == "true")
    }

    @Test("WiFi without password")
    func wifiOpen() {
        let (type, data, _) = parseQR("WIFI:S:OpenNet;T:nopass;;")
        #expect(type == .wifi)
        #expect(data["ssid"] == "OpenNet")
        #expect(data["password"] == nil)
    }
}

// MARK: - vCard Detection Tests

@Suite("QRIntelligence — vCard Detection")
struct QRVCardDetectionTests {
    @Test("vCard with name and phone")
    func vcardBasic() {
        let vcard = "BEGIN:VCARD\nVERSION:3.0\nFN:John Doe\nTEL:+41791234567\nEND:VCARD"
        let (type, data, actions) = parseQR(vcard)
        #expect(type == .vcard)
        #expect(data["name"] == "John Doe")
        #expect(data["phone"] == "+41791234567")
        #expect(actions.contains(.addContact))
    }

    @Test("vCard with email")
    func vcardEmail() {
        let vcard = "BEGIN:VCARD\nFN:Jane\nEMAIL:jane@example.com\nEND:VCARD"
        let (_, data, _) = parseQR(vcard)
        #expect(data["email"] == "jane@example.com")
    }
}

// MARK: - Geolocation Detection Tests

@Suite("QRIntelligence — Geolocation Detection")
struct QRGeolocationDetectionTests {
    @Test("Geo URI parsed")
    func geoURI() {
        let (type, data, actions) = parseQR("geo:46.9481,7.4474")
        #expect(type == .geolocation)
        #expect(data["latitude"] == "46.9481")
        #expect(data["longitude"] == "7.4474")
        #expect(actions.contains(.openMap))
    }

    @Test("Geo URI with query parameters")
    func geoWithParams() {
        let (_, data, _) = parseQR("geo:47.3769,8.5417?z=15")
        #expect(data["latitude"] == "47.3769")
        #expect(data["longitude"] == "8.5417")
    }
}

// MARK: - Calendar Event Detection Tests

@Suite("QRIntelligence — Calendar Detection")
struct QRCalendarDetectionTests {
    @Test("VEVENT detected")
    func vevent() {
        let event = "BEGIN:VEVENT\nSUMMARY:Team Meeting\nDTSTART:20260215T100000Z\nEND:VEVENT"
        let (type, data, actions) = parseQR(event)
        #expect(type == .calendar)
        #expect(data["summary"] == "Team Meeting")
        #expect(actions.contains(.addCalendarEvent))
    }

    @Test("VCALENDAR wrapper detected")
    func vcalendar() {
        let event = "BEGIN:VCALENDAR\nBEGIN:VEVENT\nSUMMARY:Lunch\nEND:VEVENT\nEND:VCALENDAR"
        let (type, data, _) = parseQR(event)
        #expect(type == .calendar)
        #expect(data["summary"] == "Lunch")
    }
}

// MARK: - Plain Text Detection Tests

@Suite("QRIntelligence — Plain Text Detection")
struct QRPlainTextDetectionTests {
    @Test("Plain text fallback")
    func plainText() {
        let (type, data, actions) = parseQR("Hello World")
        #expect(type == .text)
        #expect(data["text"] == "Hello World")
        #expect(actions.contains(.copyToClipboard))
    }

    @Test("Non-URL non-email text")
    func nonURLText() {
        let (type, _, _) = parseQR("This is just some text content")
        #expect(type == .text)
    }
}

// MARK: - Edge Cases

@Suite("QRIntelligence — Edge Cases")
struct QREdgeCaseTests {
    @Test("Empty content is text")
    func emptyContent() {
        let (type, _, _) = parseQR("")
        #expect(type == .text)
    }

    @Test("Whitespace only is text")
    func whitespace() {
        let (type, _, _) = parseQR("   ")
        #expect(type == .text)
    }

    @Test("Non-standard URL scheme is text")
    func customScheme() {
        let (type, _, _) = parseQR("myapp://deeplink")
        #expect(type == .text)
    }

    @Test("Short number is text not phone")
    func shortNumber() {
        let (type, _, _) = parseQR("12345")
        #expect(type == .text)
    }
}
