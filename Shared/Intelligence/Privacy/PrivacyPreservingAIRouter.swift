// PrivacyPreservingAIRouter.swift
// THEA - Privacy-Preserving AI Architecture
// Created by Claude - February 2026
//
// Core principle: Personal data NEVER leaves the device
// Only anonymized, abstracted insights go to remote AI models

import Foundation

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
        // periphery:ignore - Reserved: timestamp property — reserved for future feature activation
        let timestamp: Date
        // periphery:ignore - Reserved: dataTypes property — reserved for future feature activation
        let dataTypes: [PrivateDataType]
        // periphery:ignore - Reserved: decision property — reserved for future feature activation
        let decision: PrivacyRoutingDecision
        // periphery:ignore - Reserved: wasOverridden property — reserved for future feature activation
        let wasOverridden: Bool
    }

// periphery:ignore - Reserved: timestamp property reserved for future feature activation

// periphery:ignore - Reserved: dataTypes property reserved for future feature activation

// periphery:ignore - Reserved: decision property reserved for future feature activation

// periphery:ignore - Reserved: wasOverridden property reserved for future feature activation

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
        // periphery:ignore - Reserved: classification parameter kept for API compatibility
        // periphery:ignore - Reserved: taskType parameter kept for API compatibility
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
