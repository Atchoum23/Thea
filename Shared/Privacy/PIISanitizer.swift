// PIISanitizer.swift
// Privacy-first PII detection and masking for AI interactions
// Based on 2026 best practices for local AI security

import Foundation
import OSLog

// MARK: - PII Sanitizer

/// Detects and masks Personally Identifiable Information before sending to AI
/// Compliant with GDPR, CCPA, and OWASP LLM security guidelines
@MainActor
@Observable
final class PIISanitizer {
    static let shared = PIISanitizer()

    private let logger = Logger(subsystem: "app.thea.privacy", category: "PIISanitizer")

    // MARK: - Configuration

    struct Configuration: Codable, Sendable {
        var enablePIISanitization: Bool = true
        var maskEmails: Bool = true
        var maskPhoneNumbers: Bool = true
        var maskCreditCards: Bool = true
        var maskSSNs: Bool = true
        var maskIPAddresses: Bool = true
        var maskAddresses: Bool = true
        var maskNames: Bool = false // Disabled by default - may be needed in context
        var logDetections: Bool = false
        var customPatterns: [CustomPattern] = []
    }

    struct CustomPattern: Codable, Sendable, Identifiable {
        let id: UUID
        var name: String
        var pattern: String
        var replacement: String
        var isEnabled: Bool

        init(id: UUID = UUID(), name: String, pattern: String, replacement: String, isEnabled: Bool = true) {
            self.id = id
            self.name = name
            self.pattern = pattern
            self.replacement = replacement
            self.isEnabled = isEnabled
        }
    }

    private(set) var configuration = Configuration()
    private(set) var detectionHistory: [PIIDetection] = []

    // MARK: - Detection Types

    enum PIIType: String, Codable, Sendable, CaseIterable {
        case email
        case phoneNumber
        case creditCard
        case ssn
        case ipAddress
        case address
        case name
        case custom

        var displayName: String {
            switch self {
            case .email: "Email Address"
            case .phoneNumber: "Phone Number"
            case .creditCard: "Credit Card"
            case .ssn: "Social Security Number"
            case .ipAddress: "IP Address"
            case .address: "Physical Address"
            case .name: "Personal Name"
            case .custom: "Custom Pattern"
            }
        }

        var maskText: String {
            switch self {
            case .email: "[EMAIL_REDACTED]"
            case .phoneNumber: "[PHONE_REDACTED]"
            case .creditCard: "[CARD_REDACTED]"
            case .ssn: "[SSN_REDACTED]"
            case .ipAddress: "[IP_REDACTED]"
            case .address: "[ADDRESS_REDACTED]"
            case .name: "[NAME_REDACTED]"
            case .custom: "[REDACTED]"
            }
        }
    }

    struct PIIDetection: Identifiable, Codable, Sendable {
        let id: UUID
        let timestamp: Date
        let type: PIIType
        let originalLength: Int
        let contextHint: String // First/last chars for verification

        init(type: PIIType, original: String) {
            self.id = UUID()
            self.timestamp = Date()
            self.type = type
            self.originalLength = original.count
            // Store only first and last char for context
            if original.count >= 2 {
                self.contextHint = "\(original.first!)...\(original.last!)"
            } else {
                self.contextHint = "***"
            }
        }
    }

    // MARK: - Regex Patterns

    // Not @Observable-tracked: compiled once at init, never changes
    private static let compiledPatterns: [(PIIType, NSRegularExpression)] = {
        let patternDefinitions: [(PIIType, String, NSRegularExpression.Options)] = [
            (.email, #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#, .caseInsensitive),
            (.phoneNumber, #"(\+?1?[-.\s]?)?\(?[0-9]{3}\)?[-.\s]?[0-9]{3}[-.\s]?[0-9]{4}"#, []),
            (.creditCard, #"\b(?:4[0-9]{12}(?:[0-9]{3})?|5[1-5][0-9]{14}|3[47][0-9]{13}|6(?:011|5[0-9]{2})[0-9]{12})\b"#, []),
            (.creditCard, #"\b(?:\d{4}[-\s]?){3}\d{4}\b"#, []),
            (.ssn, #"\b\d{3}[-\s]?\d{2}[-\s]?\d{4}\b"#, []),
            (.ipAddress, #"\b(?:\d{1,3}\.){3}\d{1,3}\b"#, []),
            (.ipAddress, #"\b(?:[0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}\b"#, []),
            (.address, #"\d+\s+[\w\s]+(?:Street|St|Avenue|Ave|Road|Rd|Boulevard|Blvd|Drive|Dr|Lane|Ln|Court|Ct)\.?,?\s+[\w\s]+,?\s+[A-Z]{2}\s+\d{5}(?:-\d{4})?"#, .caseInsensitive)
        ]
        var result: [(PIIType, NSRegularExpression)] = []
        for (type, pattern, options) in patternDefinitions {
            if let regex = try? NSRegularExpression(pattern: pattern, options: options) {
                result.append((type, regex))
            }
        }
        return result
    }()

    private var patterns: [(PIIType, NSRegularExpression)] { Self.compiledPatterns }

    // MARK: - Initialization

    private init() {
        loadConfiguration()
    }

    // MARK: - Sanitization

    /// Sanitize text by masking detected PII
    func sanitize(_ text: String) -> SanitizationResult {
        guard configuration.enablePIISanitization else {
            return SanitizationResult(sanitizedText: text, detections: [], wasModified: false)
        }

        var sanitizedText = text
        var detections: [PIIDetection] = []

        // Apply built-in patterns
        for (type, regex) in patterns {
            guard shouldMask(type) else { continue }

            let range = NSRange(sanitizedText.startIndex..., in: sanitizedText)
            let matches = regex.matches(in: sanitizedText, options: [], range: range)

            // Process matches in reverse to maintain indices
            for match in matches.reversed() {
                guard let matchRange = Range(match.range, in: sanitizedText) else { continue }
                let matched = String(sanitizedText[matchRange])

                // Validate match
                if validateMatch(matched, for: type) {
                    let detection = PIIDetection(type: type, original: matched)
                    detections.append(detection)
                    sanitizedText.replaceSubrange(matchRange, with: type.maskText)
                }
            }
        }

        // Apply custom patterns
        for customPattern in configuration.customPatterns where customPattern.isEnabled {
            do {
                let regex = try NSRegularExpression(pattern: customPattern.pattern, options: .caseInsensitive)
                let range = NSRange(sanitizedText.startIndex..., in: sanitizedText)
                let matches = regex.matches(in: sanitizedText, options: [], range: range)

                for match in matches.reversed() {
                    guard let matchRange = Range(match.range, in: sanitizedText) else { continue }
                    let matched = String(sanitizedText[matchRange])

                    let detection = PIIDetection(type: .custom, original: matched)
                    detections.append(detection)
                    sanitizedText.replaceSubrange(matchRange, with: customPattern.replacement)
                }
            } catch {
                logger.error("Failed to compile custom PII pattern '\(customPattern.name)': \(error.localizedDescription)")
                logger.error("Pattern: \(customPattern.pattern)")
            }
        }

        // Log detections if enabled
        if configuration.logDetections {
            detectionHistory.append(contentsOf: detections)
            // Keep only last 1000 detections
            if detectionHistory.count > 1000 {
                detectionHistory = Array(detectionHistory.suffix(1000))
            }
        }

        return SanitizationResult(
            sanitizedText: sanitizedText,
            detections: detections,
            wasModified: !detections.isEmpty
        )
    }

    /// Check if we should mask this type based on configuration
    private func shouldMask(_ type: PIIType) -> Bool {
        switch type {
        case .email: configuration.maskEmails
        case .phoneNumber: configuration.maskPhoneNumbers
        case .creditCard: configuration.maskCreditCards
        case .ssn: configuration.maskSSNs
        case .ipAddress: configuration.maskIPAddresses
        case .address: configuration.maskAddresses
        case .name: configuration.maskNames
        case .custom: true
        }
    }

    /// Validate that a match is actually PII (reduce false positives)
    private func validateMatch(_ match: String, for type: PIIType) -> Bool {
        switch type {
        case .creditCard:
            // Luhn algorithm validation
            return validateLuhn(match.filter { $0.isNumber })
        case .ipAddress:
            // Validate IP octets are in valid range
            let octets = match.split(separator: ".").compactMap { Int($0) }
            return octets.count == 4 && octets.allSatisfy { $0 >= 0 && $0 <= 255 }
        case .ssn:
            // Basic SSN validation (not 000, 666, or 900-999 for first group)
            let digits = match.filter { $0.isNumber }
            guard digits.count == 9 else { return false }
            let firstThree = Int(String(digits.prefix(3))) ?? 0
            return firstThree != 0 && firstThree != 666 && firstThree < 900
        default:
            return true
        }
    }

    /// Luhn algorithm for credit card validation
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

    // MARK: - Configuration

    func updateConfiguration(_ config: Configuration) {
        configuration = config
        saveConfiguration()
    }

    func addCustomPattern(_ pattern: CustomPattern) {
        configuration.customPatterns.append(pattern)
        saveConfiguration()
    }

    func removeCustomPattern(id: UUID) {
        configuration.customPatterns.removeAll { $0.id == id }
        saveConfiguration()
    }

    private func loadConfiguration() {
        guard let data = UserDefaults.standard.data(forKey: "PIISanitizer.config") else { return }
        do {
            configuration = try JSONDecoder().decode(Configuration.self, from: data)
        } catch {
            logger.error("Failed to decode PIISanitizer configuration: \(error.localizedDescription)")
        }
    }

    private func saveConfiguration() {
        do {
            let data = try JSONEncoder().encode(configuration)
            UserDefaults.standard.set(data, forKey: "PIISanitizer.config")
        } catch {
            logger.error("Failed to encode PIISanitizer configuration: \(error.localizedDescription)")
        }
    }

    // MARK: - Statistics

    func getStatistics() -> PIISanitizerStats {
        PIISanitizerStats(
            totalDetections: detectionHistory.count,
            detectionsByType: Dictionary(grouping: detectionHistory) { $0.type }
                .mapValues { $0.count },
            lastDetection: detectionHistory.last?.timestamp
        )
    }

    func clearHistory() {
        detectionHistory.removeAll()
    // periphery:ignore - Reserved: clearHistory() instance method reserved for future feature activation
    }
}

// MARK: - Supporting Types

struct SanitizationResult: Sendable {
    let sanitizedText: String
    let detections: [PIISanitizer.PIIDetection]
    let wasModified: Bool
}

struct PIISanitizerStats: Sendable {
    let totalDetections: Int
    let detectionsByType: [PIISanitizer.PIIType: Int]
    // periphery:ignore - Reserved: detectionsByType property reserved for future feature activation
    // periphery:ignore - Reserved: lastDetection property reserved for future feature activation
    let lastDetection: Date?
}
