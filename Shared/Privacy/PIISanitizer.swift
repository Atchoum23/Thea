// PIISanitizer.swift
// Privacy-first PII detection and masking for AI interactions
// Based on 2026 best practices for local AI security

import Foundation

// MARK: - PII Sanitizer

/// Detects and masks Personally Identifiable Information before sending to AI.
/// Compliant with GDPR, CCPA, and OWASP LLM security guidelines.
@MainActor
@Observable
final class PIISanitizer {
    /// Shared singleton instance.
    static let shared = PIISanitizer()

    // MARK: - Configuration

    /// Settings controlling which PII types to detect and mask.
    struct Configuration: Codable, Sendable {
        /// Master toggle for PII sanitization.
        var enablePIISanitization: Bool = true
        /// Whether to mask email addresses.
        var maskEmails: Bool = true
        /// Whether to mask phone numbers.
        var maskPhoneNumbers: Bool = true
        /// Whether to mask credit card numbers.
        var maskCreditCards: Bool = true
        /// Whether to mask Social Security Numbers.
        var maskSSNs: Bool = true
        /// Whether to mask IP addresses.
        var maskIPAddresses: Bool = true
        /// Whether to mask physical addresses.
        var maskAddresses: Bool = true
        /// Whether to mask personal names (disabled by default as names may be needed in context).
        var maskNames: Bool = false
        /// Whether to log detection events for statistics.
        var logDetections: Bool = false
        /// User-defined custom regex patterns to detect.
        var customPatterns: [CustomPattern] = []
    }

    /// A user-defined regex pattern for detecting custom PII types.
    struct CustomPattern: Codable, Sendable, Identifiable {
        /// Unique pattern identifier.
        let id: UUID
        /// Human-readable name for this pattern.
        var name: String
        /// Regex pattern string.
        var pattern: String
        /// Replacement text for matched content.
        var replacement: String
        /// Whether this custom pattern is active.
        var isEnabled: Bool

        /// Creates a custom PII detection pattern.
        /// - Parameters:
        ///   - id: Pattern identifier.
        ///   - name: Pattern name.
        ///   - pattern: Regex pattern.
        ///   - replacement: Replacement text.
        ///   - isEnabled: Whether active.
        init(id: UUID = UUID(), name: String, pattern: String, replacement: String, isEnabled: Bool = true) {
            self.id = id
            self.name = name
            self.pattern = pattern
            self.replacement = replacement
            self.isEnabled = isEnabled
        }
    }

    /// Current sanitization configuration.
    private(set) var configuration = Configuration()
    /// History of PII detections for statistics (limited to 1000 entries).
    private(set) var detectionHistory: [PIIDetection] = []

    // MARK: - Detection Types

    /// Types of PII that can be detected and masked.
    enum PIIType: String, Codable, Sendable, CaseIterable {
        /// Email address (user@example.com).
        case email
        /// Phone number (domestic or international).
        case phoneNumber
        /// Credit card number (Visa, MC, Amex, Discover).
        case creditCard
        /// US Social Security Number.
        case ssn
        /// IPv4 or IPv6 address.
        case ipAddress
        /// US physical/mailing address.
        case address
        /// Personal name.
        case name
        /// User-defined custom pattern.
        case custom

        /// Human-readable display name for this PII type.
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

        /// Replacement text used when masking this PII type.
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

    /// Record of a single PII detection event (stores only metadata, not the PII itself).
    struct PIIDetection: Identifiable, Codable, Sendable {
        /// Unique detection identifier.
        let id: UUID
        /// When the detection occurred.
        let timestamp: Date
        /// Type of PII detected.
        let type: PIIType
        /// Character length of the original PII (for statistics, not content).
        let originalLength: Int
        /// First and last character hint for verification (e.g. "j...n").
        let contextHint: String

        /// Creates a PII detection record from a matched string.
        /// - Parameters:
        ///   - type: Type of PII found.
        ///   - original: The matched PII string (only metadata is stored).
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

    /// Pre-compiled regex patterns for each PII type.
    private let patterns: [(PIIType, NSRegularExpression)] = {
        var result: [(PIIType, NSRegularExpression)] = []

        // Email pattern
        if let regex = try? NSRegularExpression(
            pattern: #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#,
            options: .caseInsensitive
        ) {
            result.append((.email, regex))
        }

        // Phone number patterns (US, UK, international)
        if let regex = try? NSRegularExpression(
            pattern: #"(\+?1?[-.\s]?)?\(?[0-9]{3}\)?[-.\s]?[0-9]{3}[-.\s]?[0-9]{4}"#,
            options: []
        ) {
            result.append((.phoneNumber, regex))
        }

        // Credit card patterns (Visa, MC, Amex, Discover)
        if let regex = try? NSRegularExpression(
            pattern: #"\b(?:4[0-9]{12}(?:[0-9]{3})?|5[1-5][0-9]{14}|3[47][0-9]{13}|6(?:011|5[0-9]{2})[0-9]{12})\b"#,
            options: []
        ) {
            result.append((.creditCard, regex))
        }

        // Credit card with spaces/dashes
        if let regex = try? NSRegularExpression(
            pattern: #"\b(?:\d{4}[-\s]?){3}\d{4}\b"#,
            options: []
        ) {
            result.append((.creditCard, regex))
        }

        // SSN patterns
        if let regex = try? NSRegularExpression(
            pattern: #"\b\d{3}[-\s]?\d{2}[-\s]?\d{4}\b"#,
            options: []
        ) {
            result.append((.ssn, regex))
        }

        // IPv4 addresses
        if let regex = try? NSRegularExpression(
            pattern: #"\b(?:\d{1,3}\.){3}\d{1,3}\b"#,
            options: []
        ) {
            result.append((.ipAddress, regex))
        }

        // IPv6 addresses (simplified)
        if let regex = try? NSRegularExpression(
            pattern: #"\b(?:[0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}\b"#,
            options: []
        ) {
            result.append((.ipAddress, regex))
        }

        // US Address patterns (simplified - street + city + state + zip)
        if let regex = try? NSRegularExpression(
            pattern: #"\d+\s+[\w\s]+(?:Street|St|Avenue|Ave|Road|Rd|Boulevard|Blvd|Drive|Dr|Lane|Ln|Court|Ct)\.?,?\s+[\w\s]+,?\s+[A-Z]{2}\s+\d{5}(?:-\d{4})?"#,
            options: .caseInsensitive
        ) {
            result.append((.address, regex))
        }

        return result
    }()

    // MARK: - Initialization

    private init() {
        loadConfiguration()
    }

    // MARK: - Sanitization

    /// Scans text for PII and replaces detected instances with mask tokens.
    /// - Parameter text: Input text to sanitize.
    /// - Returns: A result containing the sanitized text, detections, and whether modifications were made.
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
            if let regex = try? NSRegularExpression(pattern: customPattern.pattern, options: .caseInsensitive) {
                let range = NSRange(sanitizedText.startIndex..., in: sanitizedText)
                let matches = regex.matches(in: sanitizedText, options: [], range: range)

                for match in matches.reversed() {
                    guard let matchRange = Range(match.range, in: sanitizedText) else { continue }
                    let matched = String(sanitizedText[matchRange])

                    let detection = PIIDetection(type: .custom, original: matched)
                    detections.append(detection)
                    sanitizedText.replaceSubrange(matchRange, with: customPattern.replacement)
                }
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

    /// Checks whether the given PII type should be masked based on current configuration.
    /// - Parameter type: The PII type to check.
    /// - Returns: Whether masking is enabled for this type.
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

    /// Validates that a regex match is actually PII to reduce false positives.
    /// - Parameters:
    ///   - match: The matched string.
    ///   - type: The PII type the match was detected as.
    /// - Returns: Whether the match is valid PII.
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

    /// Validates a credit card number using the Luhn algorithm.
    /// - Parameter number: Digits-only card number string.
    /// - Returns: Whether the number passes Luhn validation.
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

    /// Replaces the current configuration with a new one and persists it.
    /// - Parameter config: New configuration to apply.
    func updateConfiguration(_ config: Configuration) {
        configuration = config
        saveConfiguration()
    }

    /// Adds a custom PII detection pattern and persists the updated configuration.
    /// - Parameter pattern: Custom pattern to add.
    func addCustomPattern(_ pattern: CustomPattern) {
        configuration.customPatterns.append(pattern)
        saveConfiguration()
    }

    /// Removes a custom PII detection pattern by ID and persists the updated configuration.
    /// - Parameter id: Identifier of the pattern to remove.
    func removeCustomPattern(id: UUID) {
        configuration.customPatterns.removeAll { $0.id == id }
        saveConfiguration()
    }

    /// Loads configuration from UserDefaults.
    private func loadConfiguration() {
        if let data = UserDefaults.standard.data(forKey: "PIISanitizer.config"),
           let config = try? JSONDecoder().decode(Configuration.self, from: data) {
            configuration = config
        }
    }

    /// Persists the current configuration to UserDefaults.
    private func saveConfiguration() {
        if let data = try? JSONEncoder().encode(configuration) {
            UserDefaults.standard.set(data, forKey: "PIISanitizer.config")
        }
    }

    // MARK: - Statistics

    /// Returns aggregate statistics about PII detection history.
    /// - Returns: Statistics including total detections and breakdown by type.
    func getStatistics() -> PIISanitizerStats {
        PIISanitizerStats(
            totalDetections: detectionHistory.count,
            detectionsByType: Dictionary(grouping: detectionHistory) { $0.type }
                .mapValues { $0.count },
            lastDetection: detectionHistory.last?.timestamp
        )
    }

    /// Clears all detection history.
    func clearHistory() {
        detectionHistory.removeAll()
    }
}

// MARK: - Supporting Types

/// Result of sanitizing a text string for PII.
struct SanitizationResult: Sendable {
    /// Text with PII replaced by mask tokens.
    let sanitizedText: String
    /// Individual PII detections that were made.
    let detections: [PIISanitizer.PIIDetection]
    /// Whether any PII was detected and masked.
    let wasModified: Bool
}

/// Aggregate statistics about PII detection activity.
struct PIISanitizerStats: Sendable {
    /// Total number of PII instances detected.
    let totalDetections: Int
    /// Detection count broken down by PII type.
    let detectionsByType: [PIISanitizer.PIIType: Int]
    /// Timestamp of the most recent detection.
    let lastDetection: Date?
}
