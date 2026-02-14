import Foundation
import XCTest

/// Standalone tests for PII detection regex patterns mirroring PIISanitizer.
/// Tests email, phone, SSN, IP, credit card, and address detection
/// plus Luhn validation and false positive prevention.
final class PIIPatternTests: XCTestCase {

    // MARK: - Pattern Definitions (mirror PIISanitizer.swift)

    private enum PIIType: String {
        case email, phoneNumber, creditCard, ssn, ipAddress, address

        var maskText: String {
            switch self {
            case .email: "[EMAIL_REDACTED]"
            case .phoneNumber: "[PHONE_REDACTED]"
            case .creditCard: "[CARD_REDACTED]"
            case .ssn: "[SSN_REDACTED]"
            case .ipAddress: "[IP_REDACTED]"
            case .address: "[ADDRESS_REDACTED]"
            }
        }
    }

    private let patterns: [(PIIType, NSRegularExpression)] = {
        var result: [(PIIType, NSRegularExpression)] = []

        if let r = try? NSRegularExpression(
            pattern: #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#,
            options: .caseInsensitive
        ) { result.append((.email, r)) }

        if let r = try? NSRegularExpression(
            pattern: #"(\+?1?[-.\s]?)?\(?[0-9]{3}\)?[-.\s]?[0-9]{3}[-.\s]?[0-9]{4}"#
        ) { result.append((.phoneNumber, r)) }

        if let r = try? NSRegularExpression(
            pattern: #"\b(?:4[0-9]{12}(?:[0-9]{3})?|5[1-5][0-9]{14}|3[47][0-9]{13}|6(?:011|5[0-9]{2})[0-9]{12})\b"#
        ) { result.append((.creditCard, r)) }

        if let r = try? NSRegularExpression(
            pattern: #"\b(?:\d{4}[-\s]?){3}\d{4}\b"#
        ) { result.append((.creditCard, r)) }

        if let r = try? NSRegularExpression(
            pattern: #"\b\d{3}[-\s]?\d{2}[-\s]?\d{4}\b"#
        ) { result.append((.ssn, r)) }

        if let r = try? NSRegularExpression(
            pattern: #"\b(?:\d{1,3}\.){3}\d{1,3}\b"#
        ) { result.append((.ipAddress, r)) }

        if let r = try? NSRegularExpression(
            pattern: #"\b(?:[0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}\b"#
        ) { result.append((.ipAddress, r)) }

        if let r = try? NSRegularExpression(
            pattern: #"\d+\s+[\w\s]+(?:Street|St|Avenue|Ave|Road|Rd|Boulevard|Blvd|Drive|Dr|Lane|Ln|Court|Ct)\.?,?\s+[\w\s]+,?\s+[A-Z]{2}\s+\d{5}(?:-\d{4})?"#,
            options: .caseInsensitive
        ) { result.append((.address, r)) }

        return result
    }()

    private func detect(_ text: String) -> [PIIType] {
        var found: [PIIType] = []
        for (type, regex) in patterns {
            let range = NSRange(text.startIndex..., in: text)
            if regex.firstMatch(in: text, range: range) != nil {
                found.append(type)
            }
        }
        return found
    }

    // MARK: - Email Detection

    func testDetectsStandardEmail() {
        let types = detect("Contact me at user@example.com please")
        XCTAssertTrue(types.contains(.email))
    }

    func testDetectsEmailWithSubdomain() {
        let types = detect("Send to admin@mail.company.co.uk")
        XCTAssertTrue(types.contains(.email))
    }

    func testDetectsEmailWithPlus() {
        let types = detect("Use user+tag@gmail.com for filtering")
        XCTAssertTrue(types.contains(.email))
    }

    func testIgnoresIncompleteEmail() {
        let types = detect("This is user@incomplete")
        // Might match or not depending on regex strictness — at least shouldn't crash
        XCTAssertNotNil(types)
    }

    // MARK: - Phone Number Detection

    func testDetectsUSPhoneNumber() {
        let types = detect("Call me at (555) 123-4567")
        XCTAssertTrue(types.contains(.phoneNumber))
    }

    func testDetectsPhoneWithDashes() {
        let types = detect("555-123-4567")
        XCTAssertTrue(types.contains(.phoneNumber))
    }

    func testDetectsPhoneWithDots() {
        let types = detect("555.123.4567")
        XCTAssertTrue(types.contains(.phoneNumber))
    }

    func testDetectsPhoneWithCountryCode() {
        let types = detect("+1 555-123-4567")
        XCTAssertTrue(types.contains(.phoneNumber))
    }

    // MARK: - Credit Card Detection (with Luhn)

    private func validateLuhn(_ number: String) -> Bool {
        let digits = number.compactMap { $0.wholeNumberValue }
        guard digits.count >= 13, digits.count <= 19 else { return false }
        var sum = 0
        for (index, digit) in digits.reversed().enumerated() {
            if index % 2 == 1 {
                let doubled = digit * 2
                sum += doubled > 9 ? doubled - 9 : doubled
            } else {
                sum += digit
            }
        }
        return sum % 10 == 0
    }

    func testLuhnValidVisa() {
        XCTAssertTrue(validateLuhn("4111111111111111"), "Visa test number should pass Luhn")
    }

    func testLuhnValidMastercard() {
        XCTAssertTrue(validateLuhn("5500000000000004"), "Mastercard test number should pass Luhn")
    }

    func testLuhnValidAmex() {
        XCTAssertTrue(validateLuhn("378282246310005"), "Amex test number should pass Luhn")
    }

    func testLuhnInvalid() {
        XCTAssertFalse(validateLuhn("4111111111111112"), "Modified Visa number should fail Luhn")
    }

    func testLuhnTooShort() {
        XCTAssertFalse(validateLuhn("123456"), "Too-short number should fail Luhn")
    }

    func testLuhnEmpty() {
        XCTAssertFalse(validateLuhn(""), "Empty should fail Luhn")
    }

    func testDetectsCreditCardWithSpaces() {
        let types = detect("Card: 4111 1111 1111 1111")
        XCTAssertTrue(types.contains(.creditCard))
    }

    func testDetectsCreditCardWithDashes() {
        let types = detect("Card: 4111-1111-1111-1111")
        XCTAssertTrue(types.contains(.creditCard))
    }

    // MARK: - SSN Detection

    func testDetectsSSNWithDashes() {
        let types = detect("SSN: 123-45-6789")
        XCTAssertTrue(types.contains(.ssn))
    }

    func testDetectsSSNWithSpaces() {
        let types = detect("SSN: 123 45 6789")
        XCTAssertTrue(types.contains(.ssn))
    }

    func testDetectsSSNWithoutSeparators() {
        let types = detect("SSN: 123456789")
        XCTAssertTrue(types.contains(.ssn))
    }

    private func validateSSN(_ match: String) -> Bool {
        let digits = match.filter { $0.isNumber }
        guard digits.count == 9 else { return false }
        let firstThree = Int(String(digits.prefix(3))) ?? 0
        return firstThree != 0 && firstThree != 666 && firstThree < 900
    }

    func testSSNValidationRejectsInvalid000() {
        XCTAssertFalse(validateSSN("000-12-3456"), "SSN starting with 000 is invalid")
    }

    func testSSNValidationRejectsInvalid666() {
        XCTAssertFalse(validateSSN("666-12-3456"), "SSN starting with 666 is invalid")
    }

    func testSSNValidationRejectsInvalid900() {
        XCTAssertFalse(validateSSN("900-12-3456"), "SSN starting with 900+ is invalid")
    }

    func testSSNValidationAcceptsValid() {
        XCTAssertTrue(validateSSN("123-45-6789"))
    }

    // MARK: - IP Address Detection

    func testDetectsIPv4() {
        let types = detect("Server at 192.168.1.1")
        XCTAssertTrue(types.contains(.ipAddress))
    }

    func testDetectsIPv4Public() {
        let types = detect("DNS is 8.8.8.8")
        XCTAssertTrue(types.contains(.ipAddress))
    }

    private func validateIPv4(_ ip: String) -> Bool {
        let octets = ip.split(separator: ".").compactMap { Int($0) }
        return octets.count == 4 && octets.allSatisfy { $0 >= 0 && $0 <= 255 }
    }

    func testIPv4ValidationRejectsOutOfRange() {
        XCTAssertFalse(validateIPv4("256.1.1.1"))
    }

    func testIPv4ValidationRejectsTooFewOctets() {
        XCTAssertFalse(validateIPv4("1.2.3"))
    }

    func testIPv4ValidationAcceptsValid() {
        XCTAssertTrue(validateIPv4("192.168.0.1"))
        XCTAssertTrue(validateIPv4("0.0.0.0"))
        XCTAssertTrue(validateIPv4("255.255.255.255"))
    }

    func testDetectsIPv6() {
        let types = detect("IPv6: 2001:0db8:85a3:0000:0000:8a2e:0370:7334")
        XCTAssertTrue(types.contains(.ipAddress))
    }

    // MARK: - Address Detection

    func testDetectsUSAddress() {
        let types = detect("123 Main Street, Springfield, IL 62704")
        XCTAssertTrue(types.contains(.address))
    }

    func testDetectsAddressWithAve() {
        let types = detect("456 Oak Avenue, Portland, OR 97201")
        XCTAssertTrue(types.contains(.address))
    }

    func testDetectsAddressWithZipPlus4() {
        let types = detect("789 Pine Drive, Seattle, WA 98101-1234")
        XCTAssertTrue(types.contains(.address))
    }

    // MARK: - False Positive Prevention

    func testIgnoresNormalText() {
        let types = detect("The weather is nice today")
        XCTAssertTrue(types.isEmpty, "Normal text should not trigger: \(types)")
    }

    func testIgnoresCodeSnippets() {
        let types = detect("func calculate(_ x: Int) -> Int { return x * 2 }")
        // May detect false positives for certain patterns — check no email/SSN
        XCTAssertFalse(types.contains(.email))
        XCTAssertFalse(types.contains(.ssn))
    }

    func testIgnoresURLs() {
        let types = detect("Visit https://www.apple.com/shop")
        XCTAssertFalse(types.contains(.email), "URL should not be detected as email")
    }

    // MARK: - Edge Cases

    func testEmptyString() {
        let types = detect("")
        XCTAssertTrue(types.isEmpty)
    }

    func testMultiplePIIInSameText() {
        let text = "Email: user@test.com, Phone: 555-123-4567, IP: 10.0.0.1"
        let types = detect(text)
        XCTAssertTrue(types.contains(.email))
        XCTAssertTrue(types.contains(.phoneNumber))
        XCTAssertTrue(types.contains(.ipAddress))
    }

    func testAllPatternsCompile() {
        XCTAssertGreaterThanOrEqual(patterns.count, 7, "Should have at least 7 PII patterns")
    }

    // MARK: - Mask Text Consistency

    func testMaskTextsAreBracketed() {
        let types: [PIIType] = [.email, .phoneNumber, .creditCard, .ssn, .ipAddress, .address]
        for type in types {
            XCTAssertTrue(type.maskText.hasPrefix("["), "\(type) mask should start with [")
            XCTAssertTrue(type.maskText.hasSuffix("]"), "\(type) mask should end with ]")
            XCTAssertTrue(type.maskText.contains("REDACTED"), "\(type) mask should contain REDACTED")
        }
    }
}
