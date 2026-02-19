// PrivacyPreservingAIRouterTypes.swift
// Types, enums, and supporting actors for PrivacyPreservingAIRouter

import Foundation
import OSLog

// MARK: - Data Sensitivity Classification

/// Classification of how sensitive data is - determines routing
public enum DataSensitivityLevel: Int, Sendable, Comparable {
    case public_ = 0           // Can be sent anywhere (weather, general knowledge)
    case contextual = 1        // Okay to send context without identifiers
    case personal = 2          // PII - names, emails, phone numbers
    case sensitive = 3         // Financial, health, intimate conversations
    case critical = 4          // Passwords, SSN, banking credentials

    public static func < (lhs: DataSensitivityLevel, rhs: DataSensitivityLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var requiresLocalProcessing: Bool {
        self >= .personal
    }

    public var canBeAnonymized: Bool {
        self <= .sensitive
    }

    public var description: String {
        switch self {
        case .public_: return "Public"
        case .contextual: return "Contextual"
        case .personal: return "Personal"
        case .sensitive: return "Sensitive"
        case .critical: return "Critical"
        }
    }
}

// MARK: - Data Type Classification

/// Types of data and their inherent sensitivity
public enum PrivateDataType: String, Sendable, CaseIterable {
    // Identity (Personal)
    case fullName = "full_name"
    case email = "email"
    case phoneNumber = "phone_number"
    case address = "address"
    case birthDate = "birth_date"

    // Financial (Sensitive)
    case bankAccount = "bank_account"
    case creditCard = "credit_card"
    case income = "income"
    case transactions = "transactions"
    case investments = "investments"

    // Health (Sensitive)
    case medicalRecords = "medical_records"
    case medications = "medications"
    case mentalHealth = "mental_health"
    case biometrics = "biometrics"

    // Communications (Personal-Sensitive)
    case emailContent = "email_content"
    case messageContent = "message_content"
    case callTranscript = "call_transcript"
    case contactList = "contact_list"

    // Location (Personal)
    case preciseLocation = "precise_location"
    case locationHistory = "location_history"
    case homeAddress = "home_address"
    case workAddress = "work_address"

    // Credentials (Critical)
    case password = "password"
    case ssn = "ssn"
    case governmentId = "government_id"
    case apiKey = "api_key"

    // Behavioral (Contextual-Personal)
    case browsingHistory = "browsing_history"
    case appUsage = "app_usage"
    case searchHistory = "search_history"
    case purchaseHistory = "purchase_history"

    public var defaultSensitivity: DataSensitivityLevel {
        switch self {
        // Critical - never leave device
        case .password, .ssn, .governmentId, .apiKey:
            return .critical

        // Sensitive - process locally, anonymize for insights
        case .bankAccount, .creditCard, .income, .transactions, .investments,
             .medicalRecords, .medications, .mentalHealth, .biometrics,
             .callTranscript:
            return .sensitive

        // Personal - anonymize before remote
        case .fullName, .email, .phoneNumber, .address, .birthDate,
             .emailContent, .messageContent, .contactList,
             .preciseLocation, .locationHistory, .homeAddress, .workAddress,
             .browsingHistory, .searchHistory, .purchaseHistory:
            return .personal

        // Contextual - can send with care
        case .appUsage:
            return .contextual
        }
    }
}

// MARK: - Anonymization Strategies

/// How to anonymize different types of data
public enum AnonymizationStrategy: String, Sendable {
    case hash              // One-way hash (for IDs)
    case pseudonymize      // Replace with consistent fake (names -> Person A)
    case generalize        // Make less specific (address -> city)
    case suppress          // Remove entirely
    case aggregate         // Combine into statistics
    case temporalShift     // Shift times by random offset
    case spatialBlur       // Blur location precision
    case categorize        // Convert to categories (income -> "middle")
}

/// Anonymized data wrapper
public struct AnonymizedData: Sendable {
    public let originalType: PrivateDataType
    public let strategy: AnonymizationStrategy
    public let anonymizedValue: String
    public let retainedContext: String? // Non-identifying context
    public let timestamp: Date

    public init(
        originalType: PrivateDataType,
        strategy: AnonymizationStrategy,
        anonymizedValue: String,
        retainedContext: String? = nil
    ) {
        self.originalType = originalType
        self.strategy = strategy
        self.anonymizedValue = anonymizedValue
        self.retainedContext = retainedContext
        self.timestamp = Date()
    }
}

// MARK: - Processing Route

/// Where AI processing should happen
public enum ProcessingRoute: String, Sendable {
    case localOnly = "local"           // Must stay on device
    case localPreferred = "local_pref"  // Prefer local, fallback to remote
    case remoteAnonymized = "remote_anon" // Remote with anonymization
    case remoteAllowed = "remote"       // Can go remote directly
}

/// Result of routing decision
public struct PrivacyRoutingDecision: Sendable {
    public let route: ProcessingRoute
    public let reasoning: String
    public let sensitiveFields: [PrivateDataType]
    public let requiredAnonymization: [PrivateDataType: AnonymizationStrategy]
    public let estimatedLocalCapability: Double // 0-1, can local model handle this?

    public init(
        route: ProcessingRoute,
        reasoning: String,
        sensitiveFields: [PrivateDataType] = [],
        requiredAnonymization: [PrivateDataType: AnonymizationStrategy] = [:],
        estimatedLocalCapability: Double = 0.8
    ) {
        self.route = route
        self.reasoning = reasoning
        self.sensitiveFields = sensitiveFields
        self.requiredAnonymization = requiredAnonymization
        self.estimatedLocalCapability = estimatedLocalCapability
    }
}

// MARK: - Supporting Types

/// Context for processing decision
public struct ProcessingContext: Sendable {
    public let source: String // Where data came from
    public let userConsent: ConsentLevel
    public let urgency: Urgency
    public let qualityRequirement: QualityRequirement

    public enum ConsentLevel: String, Sendable {
        case none
        case basic
        case extended
        case full
    }

    public enum Urgency: String, Sendable {
        case low
        case normal
        case high
        case critical
    }

    public enum QualityRequirement: String, Sendable {
        case acceptable
        case good
        case excellent
    }

    public init(
        source: String,
        userConsent: ConsentLevel = .basic,
        urgency: Urgency = .normal,
        qualityRequirement: QualityRequirement = .good
    ) {
        self.source = source
        self.userConsent = userConsent
        self.urgency = urgency
        self.qualityRequirement = qualityRequirement
    }
}

/// Type of AI task
public enum AITaskType: String, Sendable {
    case classification = "classification"
    case summarization = "summarization"
    case extraction = "extraction"
    case generation = "generation"
    case reasoning = "reasoning"
    case conversation = "conversation"
    case translation = "translation"
    case codeGeneration = "code_generation"
    case analysis = "analysis"
}

/// Result of privacy-preserving processing
public struct ProcessingResult: Sendable {
    public let output: String
    public let processedLocally: Bool
    public let anonymizationApplied: Bool
    public let decision: PrivacyRoutingDecision
}

/// Anonymized content with mapping
public struct AnonymizedContent: Sendable {
    public let content: String
    public let mapping: [String: String] // anonymized -> original
    public let suppressedTypes: [PrivateDataType]
}

// MARK: - Data Classification Result

/// Result of classifying content for sensitive data
public struct ContentClassificationResult: Sendable {
    public let detectedTypes: [PrivateDataType]
    public let confidence: Double
    public let locations: [String: [Range<String.Index>]]

    public init(detectedTypes: [PrivateDataType], confidence: Double, locations: [String: [Range<String.Index>]] = [:]) {
        self.detectedTypes = detectedTypes
        self.confidence = confidence
        self.locations = locations
    }
}

// MARK: - Data Classifier

/// Classifies content to detect sensitive data types
actor DataClassifier {

    func classify(content: String, context: ProcessingContext) -> ContentClassificationResult {
        var detected: [PrivateDataType] = []

        // Email detection
        if content.range(of: #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#, options: .regularExpression) != nil {
            detected.append(.email)
        }

        // Phone number detection
        if content.range(of: #"\+?[\d\s\-\(\)]{10,}"#, options: .regularExpression) != nil {
            detected.append(.phoneNumber)
        }

        // SSN detection
        if content.range(of: #"\d{3}-\d{2}-\d{4}"#, options: .regularExpression) != nil {
            detected.append(.ssn)
        }

        // Credit card detection
        if content.range(of: #"\d{4}[\s\-]?\d{4}[\s\-]?\d{4}[\s\-]?\d{4}"#, options: .regularExpression) != nil {
            detected.append(.creditCard)
        }

        // Bank account keywords
        let bankKeywords = ["bank account", "routing number", "account number", "IBAN", "SWIFT"]
        for keyword in bankKeywords {
            if content.localizedCaseInsensitiveContains(keyword) {
                detected.append(.bankAccount)
                break
            }
        }

        // Medical keywords
        let medicalKeywords = ["diagnosis", "prescription", "medication", "symptoms", "doctor", "hospital", "treatment"]
        for keyword in medicalKeywords {
            if content.localizedCaseInsensitiveContains(keyword) {
                detected.append(.medicalRecords)
                break
            }
        }

        // Mental health keywords
        let mentalHealthKeywords = ["anxiety", "depression", "therapy", "counseling", "psychiatrist", "mental health"]
        for keyword in mentalHealthKeywords {
            if content.localizedCaseInsensitiveContains(keyword) {
                detected.append(.mentalHealth)
                break
            }
        }

        // Financial keywords
        let financialKeywords = ["salary", "income", "investment", "portfolio", "stocks", "401k", "retirement"]
        for keyword in financialKeywords {
            if content.localizedCaseInsensitiveContains(keyword) {
                detected.append(.income)
                break
            }
        }

        // Password detection
        let passwordKeywords = ["password", "passwd", "pwd", "secret key", "api key", "api_key", "token"]
        for keyword in passwordKeywords {
            if content.localizedCaseInsensitiveContains(keyword) {
                detected.append(.password)
                break
            }
        }

        // Address detection (simplified)
        if content.range(of: #"\d+\s+[A-Za-z]+\s+(Street|St|Avenue|Ave|Road|Rd|Boulevard|Blvd|Drive|Dr|Lane|Ln)"#, options: .regularExpression) != nil {
            detected.append(.address)
        }

        // Context-based classification
        switch context.source.lowercased() {
        case let s where s.contains("email"):
            detected.append(.emailContent)
        case let s where s.contains("message") || s.contains("chat"):
            detected.append(.messageContent)
        case let s where s.contains("call"):
            detected.append(.callTranscript)
        case let s where s.contains("location"):
            detected.append(.preciseLocation)
        case let s where s.contains("health") || s.contains("apple health"):
            detected.append(.biometrics)
        default:
            break
        }

        return ContentClassificationResult(
            detectedTypes: Array(Set(detected)), // Remove duplicates
            confidence: detected.isEmpty ? 0.3 : 0.8,
            locations: [:]
        )
    }
}

// MARK: - Data Anonymizer

/// Anonymizes content based on strategies
actor DataAnonymizer {

    private let logger = Logger(subsystem: "ai.thea.app", category: "DataAnonymizer")
    private var pseudonymCache: [String: String] = [:]
    private var pseudonymCounter = 0

    func anonymize(
        content: String,
        strategies: [PrivateDataType: AnonymizationStrategy],
        level: PrivacyPreservingAIRouter.Configuration.AnonymizationLevel
    ) -> AnonymizedContent {
        var result = content
        var mapping: [String: String] = [:]
        var suppressed: [PrivateDataType] = []

        // Apply each strategy
        for (dataType, strategy) in strategies {
            switch strategy {
            case .suppress:
                result = suppressDataType(result, type: dataType)
                suppressed.append(dataType)

            case .pseudonymize:
                let (newContent, newMapping) = pseudonymize(result, type: dataType)
                result = newContent
                mapping.merge(newMapping) { $1 }

            case .hash:
                result = hashIdentifiers(result, type: dataType)

            case .generalize:
                result = generalize(result, type: dataType, level: level)

            case .aggregate:
                result = aggregate(result, type: dataType)

            case .spatialBlur:
                result = blurLocation(result, level: level)

            case .temporalShift:
                result = shiftTimes(result)

            case .categorize:
                result = categorize(result, type: dataType)
            }
        }

        return AnonymizedContent(
            content: result,
            mapping: mapping,
            suppressedTypes: suppressed
        )
    }

    func deAnonymize(result: String, mapping: [String: String]) -> String {
        var output = result
        for (anonymized, original) in mapping {
            output = output.replacingOccurrences(of: anonymized, with: original)
        }
        return output
    }

    // MARK: - Strategy Implementations

    private func suppressDataType(_ content: String, type: PrivateDataType) -> String {
        var result = content

        switch type {
        case .email:
            result = result.replacingOccurrences(
                of: #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#,
                with: "[EMAIL REDACTED]",
                options: .regularExpression
            )
        case .phoneNumber:
            result = result.replacingOccurrences(
                of: #"\+?[\d\s\-\(\)]{10,}"#,
                with: "[PHONE REDACTED]",
                options: .regularExpression
            )
        case .ssn:
            result = result.replacingOccurrences(
                of: #"\d{3}-\d{2}-\d{4}"#,
                with: "[SSN REDACTED]",
                options: .regularExpression
            )
        case .creditCard:
            result = result.replacingOccurrences(
                of: #"\d{4}[\s\-]?\d{4}[\s\-]?\d{4}[\s\-]?\d{4}"#,
                with: "[CARD REDACTED]",
                options: .regularExpression
            )
        default:
            break
        }

        return result
    }

    private func pseudonymize(_ content: String, type: PrivateDataType) -> (String, [String: String]) {
        var result = content
        var mapping: [String: String] = [:]

// periphery:ignore - Reserved: type parameter kept for API compatibility

        // Simple name pseudonymization
        let namePatterns = [
            #"(?<=from |to |by |with |for |sent by |cc: |bcc: )[A-Z][a-z]+ [A-Z][a-z]+"#,
            #"(?<=Hi |Hello |Dear |Hey )[A-Z][a-z]+"#
        ]

        for pattern in namePatterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [])
                let nsContent = result as NSString
                let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: nsContent.length))

                for match in matches.reversed() {
                    let originalName = nsContent.substring(with: match.range)
                    let pseudonym = getPseudonym(for: originalName)
                    result = nsContent.replacingCharacters(in: match.range, with: pseudonym) as String
                    mapping[pseudonym] = originalName
                }
            } catch {
                logger.debug("Invalid name pattern: \(error.localizedDescription)")
            }
        }

        return (result, mapping)
    }

    private func getPseudonym(for original: String) -> String {
        if let cached = pseudonymCache[original] {
            return cached
        }

        pseudonymCounter += 1
        let pseudonym = "Person \(pseudonymCounter)"
        pseudonymCache[original] = pseudonym
        return pseudonym
    }

    private func hashIdentifiers(_ content: String, type: PrivateDataType) -> String {
        // Replace identifiers with hashed versions
        var result = content

        if type == .email {
            do {
                let regex = try NSRegularExpression(pattern: #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#, options: [])
                let nsContent = result as NSString
                let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: nsContent.length))

                for match in matches.reversed() {
                    let email = nsContent.substring(with: match.range)
                    let hash = String(email.hashValue.magnitude).prefix(8)
                    result = nsContent.replacingCharacters(in: match.range, with: "user_\(hash)@domain.tld") as String
                }
            } catch {
                logger.debug("Invalid email pattern: \(error.localizedDescription)")
            }
        }

        return result
    }

    private func generalize(_ content: String, type: PrivateDataType, level: PrivacyPreservingAIRouter.Configuration.AnonymizationLevel) -> String {
        var result = content

// periphery:ignore - Reserved: level parameter kept for API compatibility

        switch type {
        case .address:
            // Replace full address with just city
            result = result.replacingOccurrences(
                of: #"\d+\s+[A-Za-z]+\s+(Street|St|Avenue|Ave|Road|Rd|Boulevard|Blvd|Drive|Dr|Lane|Ln)[^,]*,\s*([A-Za-z\s]+)"#,
                with: "[a location in $2]",
                options: .regularExpression
            )
        case .birthDate:
            // Replace full date with year
            result = result.replacingOccurrences(
                of: #"\d{1,2}/\d{1,2}/(\d{4})"#,
                with: "born in $1",
                options: .regularExpression
            )
        default:
            break
        }

        return result
    }

    private func aggregate(_ content: String, type: PrivateDataType) -> String {
        // periphery:ignore - Reserved: type parameter kept for API compatibility
        // Convert individual values to aggregates
        // This is simplified - real implementation would collect and aggregate
        content
    }

    // periphery:ignore - Reserved: level parameter kept for API compatibility
    private func blurLocation(_ content: String, level: PrivacyPreservingAIRouter.Configuration.AnonymizationLevel) -> String {
        var result = content

        // Replace precise coordinates with approximate
        let coordPattern = #"(-?\d{1,3}\.\d{4,}),\s*(-?\d{1,3}\.\d{4,})"#
        do {
            let regex = try NSRegularExpression(pattern: coordPattern, options: [])
            let nsContent = result as NSString
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: nsContent.length))

            for match in matches.reversed() {
                // Truncate to 2 decimal places (~1km precision)
                if let latRange = Range(match.range(at: 1), in: result),
                   let lonRange = Range(match.range(at: 2), in: result),
                   let lat = Double(result[latRange]),
                   let lon = Double(result[lonRange]) {
                    let blurred = String(format: "%.2f, %.2f", lat, lon)
                    result = nsContent.replacingCharacters(in: match.range, with: blurred) as String
                }
            }
        } catch {
            logger.debug("Invalid coordinate pattern: \(error.localizedDescription)")
        }

        return result
    }

    private func shiftTimes(_ content: String) -> String {
        // Shift times by a random offset (implementation simplified)
        content
    }

    private func categorize(_ content: String, type: PrivateDataType) -> String {
        var result = content

        switch type {
        case .income:
            // Replace specific amounts with ranges
            let amounts = [
                (0..<30000, "entry-level income"),
                (30000..<60000, "moderate income"),
                (60000..<100000, "above-average income"),
                (100000..<200000, "high income"),
                (200000..<1000000, "very high income")
            ]

            let dollarPattern = #"\$[\d,]+(?:\.\d{2})?"#
            do {
                let regex = try NSRegularExpression(pattern: dollarPattern, options: [])
                let nsContent = result as NSString
                let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: nsContent.length))

                for match in matches.reversed() {
                    let amountStr = nsContent.substring(with: match.range)
                        .replacingOccurrences(of: "$", with: "")
                        .replacingOccurrences(of: ",", with: "")

                    if let amount = Double(amountStr) {
                        for (range, category) in amounts {
                            if range.contains(Int(amount)) {
                                result = nsContent.replacingCharacters(in: match.range, with: "[\(category)]") as String
                                break
                            }
                        }
                    }
                }
            } catch {
                logger.debug("Invalid dollar amount pattern: \(error.localizedDescription)")
            }

        default:
            break
        }

        return result
    }
}
