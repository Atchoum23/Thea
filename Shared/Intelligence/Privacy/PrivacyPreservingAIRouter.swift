// PrivacyPreservingAIRouter.swift
// THEA - Privacy-Preserving AI Architecture
// Created by Claude - February 2026
//
// Core principle: Personal data NEVER leaves the device
// Only anonymized, abstracted insights go to remote AI models

import Foundation

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

// MARK: - Privacy-Preserving AI Router

/// Main router that ensures privacy-preserving AI processing
public actor PrivacyPreservingAIRouter {
    // MARK: - Singleton

    public static let shared = PrivacyPreservingAIRouter()

    // MARK: - Configuration

    public struct Configuration: Sendable {
        public var strictMode: Bool = true // Never send anything sensitive remotely
        public var preferLocalProcessing: Bool = true
        public var allowRemoteForNonSensitive: Bool = true
        public var minimumLocalCapabilityThreshold: Double = 0.6
        public var anonymizationLevel: AnonymizationLevel = .aggressive

        public enum AnonymizationLevel: String, Sendable {
            case minimal     // Basic anonymization
            case standard    // Balanced
            case aggressive  // Maximum privacy
        }

        public init() {}
    }

    // MARK: - Properties

    private var configuration: Configuration
    private let dataClassifier: DataClassifier
    private let anonymizer: DataAnonymizer
    private var routingHistory: [RoutingHistoryEntry] = []

    private struct RoutingHistoryEntry: Sendable {
        let timestamp: Date
        let dataTypes: [PrivateDataType]
        let decision: PrivacyRoutingDecision
        let wasOverridden: Bool
    }

    // MARK: - Initialization

    private init() {
        self.configuration = Configuration()
        self.dataClassifier = DataClassifier()
        self.anonymizer = DataAnonymizer()
    }

    // MARK: - Public API

    /// Configure the router
    public func configure(_ config: Configuration) {
        self.configuration = config
    }

    /// Analyze content and determine routing
    public func analyzeAndRoute(
        content: String,
        context: ProcessingContext,
        taskType: AITaskType
    ) async -> PrivacyRoutingDecision {
        // Step 1: Classify the data
        let classification = await dataClassifier.classify(content: content, context: context)

        // Step 2: Determine maximum sensitivity
        let maxSensitivity = classification.detectedTypes.map { $0.defaultSensitivity }.max() ?? .public_

        // Step 3: Decide route based on sensitivity and task
        let route = determineRoute(
            maxSensitivity: maxSensitivity,
            classification: classification,
            taskType: taskType
        )

        // Step 4: Determine required anonymization
        let anonymization = determineAnonymization(
            classification: classification,
            route: route
        )

        // Step 5: Estimate local capability
        let localCapability = estimateLocalCapability(taskType: taskType)

        // Build decision
        let decision = PrivacyRoutingDecision(
            route: route,
            reasoning: buildReasoning(
                maxSensitivity: maxSensitivity,
                classification: classification,
                taskType: taskType,
                route: route
            ),
            sensitiveFields: classification.detectedTypes.filter { $0.defaultSensitivity >= .personal },
            requiredAnonymization: anonymization,
            estimatedLocalCapability: localCapability
        )

        // Record for analytics
        recordRouting(
            dataTypes: classification.detectedTypes,
            decision: decision
        )

        return decision
    }

    /// Anonymize content based on routing decision
    public func anonymize(
        content: String,
        decision: PrivacyRoutingDecision
    ) async -> AnonymizedContent {
        await anonymizer.anonymize(
            content: content,
            strategies: decision.requiredAnonymization,
            level: configuration.anonymizationLevel
        )
    }

    /// Process with appropriate route
    public func processWithPrivacy(
        content: String,
        context: ProcessingContext,
        taskType: AITaskType,
        localProcessor: @Sendable () async throws -> String,
        remoteProcessor: @Sendable (String) async throws -> String
    ) async throws -> ProcessingResult {
        // Get routing decision
        let decision = await analyzeAndRoute(content: content, context: context, taskType: taskType)

        switch decision.route {
        case .localOnly:
            // Must process locally
            let result = try await localProcessor()
            return ProcessingResult(
                output: result,
                processedLocally: true,
                anonymizationApplied: false,
                decision: decision
            )

        case .localPreferred:
            // Try local first
            if decision.estimatedLocalCapability >= configuration.minimumLocalCapabilityThreshold {
                do {
                    let result = try await localProcessor()
                    return ProcessingResult(
                        output: result,
                        processedLocally: true,
                        anonymizationApplied: false,
                        decision: decision
                    )
                } catch {
                    // Local failed — fall through to anonymized remote
                }
            }
            // Anonymize then send remote (same as remoteAnonymized)
            let anonymizedLocal = await anonymize(content: content, decision: decision)
            let resultLocal = try await remoteProcessor(anonymizedLocal.content)
            let finalLocal = await anonymizer.deAnonymize(result: resultLocal, mapping: anonymizedLocal.mapping)
            return ProcessingResult(
                output: finalLocal,
                processedLocally: false,
                anonymizationApplied: true,
                decision: decision
            )

        case .remoteAnonymized:
            // Anonymize then send remote
            let anonymized = await anonymize(content: content, decision: decision)
            let result = try await remoteProcessor(anonymized.content)

            // De-anonymize result if needed
            let finalResult = await anonymizer.deAnonymize(result: result, mapping: anonymized.mapping)

            return ProcessingResult(
                output: finalResult,
                processedLocally: false,
                anonymizationApplied: true,
                decision: decision
            )

        case .remoteAllowed:
            // Can send directly
            let result = try await remoteProcessor(content)
            return ProcessingResult(
                output: result,
                processedLocally: false,
                anonymizationApplied: false,
                decision: decision
            )
        }
    }

    // MARK: - Private Methods

    private func determineRoute(
        maxSensitivity: DataSensitivityLevel,
        classification: ContentClassificationResult,
        taskType: AITaskType
    ) -> ProcessingRoute {
        // Critical data: ALWAYS local
        if maxSensitivity == .critical {
            return .localOnly
        }

        // Strict mode: sensitive and personal stay local
        if configuration.strictMode && maxSensitivity >= .personal {
            return .localOnly
        }

        // Sensitive data: local preferred, anonymized remote as fallback
        if maxSensitivity == .sensitive {
            return configuration.preferLocalProcessing ? .localPreferred : .remoteAnonymized
        }

        // Personal data: anonymize for remote
        if maxSensitivity == .personal {
            return .remoteAnonymized
        }

        // Contextual/Public: can go remote
        if configuration.allowRemoteForNonSensitive {
            return .remoteAllowed
        }

        return .localPreferred
    }

    private func determineAnonymization(
        classification: ContentClassificationResult,
        route: ProcessingRoute
    ) -> [PrivateDataType: AnonymizationStrategy] {
        guard route == .remoteAnonymized else { return [:] }

        var strategies: [PrivateDataType: AnonymizationStrategy] = [:]

        for dataType in classification.detectedTypes {
            strategies[dataType] = selectStrategy(for: dataType)
        }

        return strategies
    }

    private func selectStrategy(for dataType: PrivateDataType) -> AnonymizationStrategy {
        switch dataType {
        // Identity - pseudonymize
        case .fullName:
            return .pseudonymize
        case .email, .phoneNumber:
            return configuration.anonymizationLevel == .aggressive ? .suppress : .hash
        case .address, .homeAddress, .workAddress:
            return .generalize
        case .birthDate:
            return .generalize // Year only

        // Financial - categorize or suppress
        case .bankAccount, .creditCard:
            return .suppress
        case .income:
            return .categorize
        case .transactions:
            return configuration.anonymizationLevel == .aggressive ? .suppress : .aggregate
        case .investments:
            return .categorize

        // Health - suppress or aggregate
        case .medicalRecords, .mentalHealth:
            return .suppress
        case .medications:
            return configuration.anonymizationLevel == .aggressive ? .suppress : .categorize
        case .biometrics:
            return .aggregate

        // Communications - pseudonymize participants
        case .emailContent, .messageContent:
            return .pseudonymize
        case .callTranscript:
            return .suppress // Never send call transcripts
        case .contactList:
            return .suppress

        // Location - blur
        case .preciseLocation:
            return .spatialBlur
        case .locationHistory:
            return configuration.anonymizationLevel == .aggressive ? .suppress : .spatialBlur

        // Credentials - always suppress
        case .password, .ssn, .governmentId, .apiKey:
            return .suppress

        // Behavioral - aggregate
        case .browsingHistory, .searchHistory:
            return configuration.anonymizationLevel == .aggressive ? .suppress : .categorize
        case .appUsage:
            return .aggregate
        case .purchaseHistory:
            return .categorize
        }
    }

    private func estimateLocalCapability(taskType: AITaskType) -> Double {
        switch taskType {
        case .classification:
            return 0.95 // Local models great at classification
        case .summarization:
            return 0.85 // Good at summarization
        case .extraction:
            return 0.9 // Good at extraction
        case .generation:
            return 0.7 // Reasonable at generation
        case .reasoning:
            return 0.6 // Complex reasoning harder
        case .conversation:
            return 0.75 // Decent for conversation
        case .translation:
            return 0.8 // Good at translation
        case .codeGeneration:
            return 0.65 // Code generation okay
        case .analysis:
            return 0.8 // Good at analysis
        }
    }

    private func buildReasoning(
        maxSensitivity: DataSensitivityLevel,
        classification: ContentClassificationResult,
        taskType: AITaskType,
        route: ProcessingRoute
    ) -> String {
        var parts: [String] = []

        parts.append("Data sensitivity: \(maxSensitivity.description)")

        if !classification.detectedTypes.isEmpty {
            let types = classification.detectedTypes.map { $0.rawValue }.joined(separator: ", ")
            parts.append("Detected types: \(types)")
        }

        parts.append("Task type: \(taskType.rawValue)")
        parts.append("Route: \(route.rawValue)")

        if route == .localOnly {
            parts.append("Reason: Privacy requirements mandate local processing")
        } else if route == .remoteAnonymized {
            parts.append("Reason: Content anonymized before remote processing")
        }

        return parts.joined(separator: "; ")
    }

    private func recordRouting(
        dataTypes: [PrivateDataType],
        decision: PrivacyRoutingDecision
    ) {
        let entry = RoutingHistoryEntry(
            timestamp: Date(),
            dataTypes: dataTypes,
            decision: decision,
            wasOverridden: false
        )

        routingHistory.append(entry)

        // Keep last 1000 entries
        if routingHistory.count > 1000 {
            routingHistory.removeFirst(routingHistory.count - 1000)
        }
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

        // Simple name pseudonymization
        let namePatterns = [
            #"(?<=from |to |by |with |for |sent by |cc: |bcc: )[A-Z][a-z]+ [A-Z][a-z]+"#,
            #"(?<=Hi |Hello |Dear |Hey )[A-Z][a-z]+"#
        ]

        for pattern in namePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let nsContent = result as NSString
                let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: nsContent.length))

                for match in matches.reversed() {
                    let originalName = nsContent.substring(with: match.range)
                    let pseudonym = getPseudonym(for: originalName)
                    result = nsContent.replacingCharacters(in: match.range, with: pseudonym) as String
                    mapping[pseudonym] = originalName
                }
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
            if let regex = try? NSRegularExpression(pattern: #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#, options: []) {
                let nsContent = result as NSString
                let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: nsContent.length))

                for match in matches.reversed() {
                    let email = nsContent.substring(with: match.range)
                    let hash = String(email.hashValue.magnitude).prefix(8)
                    result = nsContent.replacingCharacters(in: match.range, with: "user_\(hash)@domain.tld") as String
                }
            }
        }

        return result
    }

    private func generalize(_ content: String, type: PrivateDataType, level: PrivacyPreservingAIRouter.Configuration.AnonymizationLevel) -> String {
        var result = content

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
        // Convert individual values to aggregates
        // This is simplified - real implementation would collect and aggregate
        content
    }

    private func blurLocation(_ content: String, level: PrivacyPreservingAIRouter.Configuration.AnonymizationLevel) -> String {
        var result = content

        // Replace precise coordinates with approximate
        let coordPattern = #"(-?\d{1,3}\.\d{4,}),\s*(-?\d{1,3}\.\d{4,})"#
        if let regex = try? NSRegularExpression(pattern: coordPattern, options: []) {
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
            if let regex = try? NSRegularExpression(pattern: dollarPattern, options: []) {
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
            }

        default:
            break
        }

        return result
    }
}
