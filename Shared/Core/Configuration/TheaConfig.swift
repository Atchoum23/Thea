// TheaConfig.swift
// Thea V2
//
// Schema-driven configuration - single source of truth
// AI can query and modify any setting at runtime

import Foundation
import Combine
import OSLog

// MARK: - Master Configuration

/// Single source of truth for ALL Thea configuration
@MainActor
@Observable
public final class TheaConfig {
    public static let shared = TheaConfig()

    private let logger = Logger(subsystem: "com.thea.v2", category: "Config")

    // MARK: - Configuration Sections

    public var ai = AIConfiguration()
    public var memory = MemoryConfiguration()
    public var verification = VerificationConfiguration()
    public var providers = ProvidersConfiguration()
    public var ui = UIConfiguration()
    public var tracking = TrackingConfiguration()
    public var security = SecurityConfiguration()

    // MARK: - Persistence

    private let storageKey = "TheaConfig.v2"

    private init() {
        load()
    }

    public func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(ConfigSnapshot(
                ai: ai,
                memory: memory,
                verification: verification,
                providers: providers,
                ui: ui,
                tracking: tracking,
                security: security
            ))
            UserDefaults.standard.set(data, forKey: storageKey)

            // Publish config change event
            EventBus.shared.publish(StateEvent(
                source: .system,
                component: "Configuration",
                newState: "saved"
            ))

            logger.info("Configuration saved")
        } catch {
            logger.error("Failed to save configuration: \(error.localizedDescription)")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            logger.info("No saved configuration, using defaults")
            return
        }

        do {
            let snapshot = try JSONDecoder().decode(ConfigSnapshot.self, from: data)
            ai = snapshot.ai
            memory = snapshot.memory
            verification = snapshot.verification
            providers = snapshot.providers
            ui = snapshot.ui
            tracking = snapshot.tracking
            security = snapshot.security
            logger.info("Configuration loaded")
        } catch {
            logger.error("Failed to load configuration: \(error.localizedDescription)")
        }
    }

    public func reset() {
        ai = AIConfiguration()
        memory = MemoryConfiguration()
        verification = VerificationConfiguration()
        providers = ProvidersConfiguration()
        ui = UIConfiguration()
        tracking = TrackingConfiguration()
        security = SecurityConfiguration()
        save()
    }

    // MARK: - AI-Queryable Schema

    /// Returns the complete configuration schema for AI consumption
    public func describeSchema() -> String {
        [
            schemaHeader,
            aiSchemaSection,
            memorySchemaSection,
            verificationSchemaSection,
            providersSchemaSection,
            uiSchemaSection,
            trackingSchemaSection,
            securitySchemaSection
        ].joined(separator: "\n")
    }

    // MARK: - Schema Sections

    private var schemaHeader: String {
        """
        THEA CONFIGURATION SCHEMA
        =========================
        """
    }

    private var aiSchemaSection: String {
        """

        1. AI Configuration (ai.*)
           - defaultProvider: String (openrouter, anthropic, openai, etc.)
           - defaultModel: String (model identifier)
           - temperature: Double (0.0-2.0)
           - maxTokens: Int (1-100000)
           - streamingEnabled: Bool
           - enableTaskClassification: Bool
           - enableModelRouting: Bool
           - enableQueryDecomposition: Bool
           - enableMultiAgentOrchestration: Bool
           - learningRate: Double (0.0-1.0)
           - feedbackDecayFactor: Double (0.0-1.0)
        """
    }

    private var memorySchemaSection: String {
        """

        2. Memory Configuration (memory.*)
           - workingCapacity: Int (max items in working memory)
           - episodicCapacity: Int (max conversations stored)
           - semanticCapacity: Int (max knowledge items)
           - proceduralCapacity: Int (max learned workflows)
           - consolidationInterval: TimeInterval (seconds)
           - decayRate: Double (0.0-1.0)
           - enableActiveRetrieval: Bool
           - enableContextInjection: Bool
           - retrievalLimit: Int
           - similarityThreshold: Double (0.0-1.0)
        """
    }

    private var verificationSchemaSection: String {
        """

        3. Verification Configuration (verification.*)
           - enableMultiModel: Bool
           - enableWebSearch: Bool
           - enableCodeExecution: Bool
           - enableStaticAnalysis: Bool
           - enableFeedbackLearning: Bool
           - highConfidenceThreshold: Double (0.0-1.0)
           - mediumConfidenceThreshold: Double (0.0-1.0)
           - lowConfidenceThreshold: Double (0.0-1.0)
           - consensusWeight: Double (0.0-1.0)
           - webSearchWeight: Double (0.0-1.0)
           - codeExecutionWeight: Double (0.0-1.0)
           - staticAnalysisWeight: Double (0.0-1.0)
           - feedbackWeight: Double (0.0-1.0)
        """
    }

    private var providersSchemaSection: String {
        """

        4. Providers Configuration (providers.*)
           - anthropicBaseURL: String
           - openaiBaseURL: String
           - openrouterBaseURL: String
           - groqBaseURL: String
           - perplexityBaseURL: String
           - googleBaseURL: String
           - timeout: TimeInterval
           - maxRetries: Int
           - retryDelay: TimeInterval
        """
    }

    private var uiSchemaSection: String {
        """

        5. UI Configuration (ui.*)
           - theme: String (system, light, dark)
           - accentColor: String
           - fontSize: CGFloat
           - showConfidenceIndicators: Bool
           - showMemoryContext: Bool
           - enableAnimations: Bool
           - compactMode: Bool
        """
    }

    private var trackingSchemaSection: String {
        """

        6. Tracking Configuration (tracking.*)
           - enableLocation: Bool
           - enableHealth: Bool
           - enableUsage: Bool
           - enableBrowser: Bool
           - enableInput: Bool
           - localOnly: Bool
           - enableCloudSync: Bool
           - retentionDays: Int
        """
    }

    private var securitySchemaSection: String {
        """

        7. Security Configuration (security.*)
           - requireApprovalForFiles: Bool
           - requireApprovalForTerminal: Bool
           - requireApprovalForNetwork: Bool
           - blockedCommands: [String]
           - allowedDomains: [String]
           - maxFileSize: Int
        """
    }

    /// Get a configuration value by key path
    public func getValue(at keyPath: String) -> Any? {
        let parts = keyPath.split(separator: ".")
        guard parts.count >= 2 else { return nil }

        let section = String(parts[0])
        let key = String(parts[1])

        switch section {
        case "ai":
            return ai.getValue(key)
        case "memory":
            return memory.getValue(key)
        case "verification":
            return verification.getValue(key)
        case "providers":
            return providers.getValue(key)
        case "ui":
            return ui.getValue(key)
        case "tracking":
            return tracking.getValue(key)
        case "security":
            return security.getValue(key)
        default:
            return nil
        }
    }

    /// Set a configuration value by key path
    @discardableResult
    public func setValue(_ value: Any, at keyPath: String) -> Bool {
        let parts = keyPath.split(separator: ".")
        guard parts.count >= 2 else { return false }

        let section = String(parts[0])
        let key = String(parts[1])

        var success = false
        switch section {
        case "ai":
            success = ai.setValue(value, forKey: key)
        case "memory":
            success = memory.setValue(value, forKey: key)
        case "verification":
            success = verification.setValue(value, forKey: key)
        case "providers":
            success = providers.setValue(value, forKey: key)
        case "ui":
            success = ui.setValue(value, forKey: key)
        case "tracking":
            success = tracking.setValue(value, forKey: key)
        case "security":
            success = security.setValue(value, forKey: key)
        default:
            break
        }

        if success {
            save()
        }
        return success
    }

    /// Export configuration as JSON
    public func exportJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let snapshot = ConfigSnapshot(
            ai: ai,
            memory: memory,
            verification: verification,
            providers: providers,
            ui: ui,
            tracking: tracking,
            security: security
        )

        if let data = try? encoder.encode(snapshot),
           let json = String(data: data, encoding: .utf8) {
            return json
        }
        return "{}"
    }

    /// Import configuration from JSON
    public func importJSON(_ json: String) -> Bool {
        guard let data = json.data(using: .utf8) else { return false }

        do {
            let snapshot = try JSONDecoder().decode(ConfigSnapshot.self, from: data)
            ai = snapshot.ai
            memory = snapshot.memory
            verification = snapshot.verification
            providers = snapshot.providers
            ui = snapshot.ui
            tracking = snapshot.tracking
            security = snapshot.security
            save()
            return true
        } catch {
            logger.error("Failed to import configuration: \(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - Configuration Sections

public struct AIConfiguration: Codable, Sendable {
    public var defaultProvider: String = "openrouter"
    public var defaultModel: String = "anthropic/claude-sonnet-4"
    public var temperature: Double = 0.7
    public var maxTokens: Int = 8192
    public var streamingEnabled: Bool = true

    public var enableTaskClassification: Bool = true
    public var enableModelRouting: Bool = true
    public var enableQueryDecomposition: Bool = true
    public var enableMultiAgentOrchestration: Bool = true

    public var learningRate: Double = 0.1
    public var feedbackDecayFactor: Double = 0.95

    public init() {}

    func getValue(_ key: String) -> Any? {
        switch key {
        case "defaultProvider": return defaultProvider
        case "defaultModel": return defaultModel
        case "temperature": return temperature
        case "maxTokens": return maxTokens
        case "streamingEnabled": return streamingEnabled
        case "enableTaskClassification": return enableTaskClassification
        case "enableModelRouting": return enableModelRouting
        case "enableQueryDecomposition": return enableQueryDecomposition
        case "enableMultiAgentOrchestration": return enableMultiAgentOrchestration
        case "learningRate": return learningRate
        case "feedbackDecayFactor": return feedbackDecayFactor
        default: return nil
        }
    }

    mutating func setValue(_ value: Any, forKey key: String) -> Bool {
        switch key {
        case "defaultProvider":
            if let val = value as? String { defaultProvider = val; return true }
        case "defaultModel":
            if let val = value as? String { defaultModel = val; return true }
        case "temperature":
            if let val = value as? Double { temperature = val; return true }
        case "maxTokens":
            if let val = value as? Int { maxTokens = val; return true }
        case "streamingEnabled":
            if let val = value as? Bool { streamingEnabled = val; return true }
        case "enableTaskClassification":
            if let val = value as? Bool { enableTaskClassification = val; return true }
        case "enableModelRouting":
            if let val = value as? Bool { enableModelRouting = val; return true }
        case "enableQueryDecomposition":
            if let val = value as? Bool { enableQueryDecomposition = val; return true }
        case "enableMultiAgentOrchestration":
            if let val = value as? Bool { enableMultiAgentOrchestration = val; return true }
        case "learningRate":
            if let val = value as? Double { learningRate = val; return true }
        case "feedbackDecayFactor":
            if let val = value as? Double { feedbackDecayFactor = val; return true }
        default:
            break
        }
        return false
    }
}

public struct MemoryConfiguration: Codable, Sendable, Equatable {
    // MARK: - Capacity Settings
    public var workingCapacity: Int = 100
    public var episodicCapacity: Int = 10000
    public var semanticCapacity: Int = 50000
    public var proceduralCapacity: Int = 1000

    // Legacy aliases for backward compatibility
    public var shortTermCapacity: Int {
        get { workingCapacity }
        set { workingCapacity = newValue }
    }
    public var longTermMaxItems: Int {
        get { semanticCapacity }
        set { semanticCapacity = newValue }
    }
    public var episodicMaxItems: Int {
        get { episodicCapacity }
        set { episodicCapacity = newValue }
    }
    public var semanticMaxItems: Int {
        get { semanticCapacity }
        set { semanticCapacity = newValue }
    }
    public var proceduralMaxItems: Int {
        get { proceduralCapacity }
        set { proceduralCapacity = newValue }
    }

    // MARK: - Consolidation Settings
    public var consolidationInterval: TimeInterval = 3600
    public var consolidationThresholdSeconds: TimeInterval {
        get { consolidationInterval }
        set { consolidationInterval = newValue }
    }
    public var consolidationMinImportance: Double = 0.3

    // MARK: - Decay Settings
    public var decayRate: Double = 0.99
    public var generalDecayRate: Float {
        get { Float(decayRate) }
        set { decayRate = Double(newValue) }
    }
    public var semanticDecayRate: Float = 0.995
    public var minImportance: Double = 0.1
    public var minImportanceThreshold: Float {
        get { Float(minImportance) }
        set { minImportance = Double(newValue) }
    }

    // MARK: - Retrieval Settings
    public var enableActiveRetrieval: Bool = true
    public var enableContextInjection: Bool = true
    public var retrievalLimit: Int = 10
    public var defaultRetrievalLimit: Int {
        get { retrievalLimit }
        set { retrievalLimit = newValue }
    }
    public var episodicRetrievalLimit: Int = 5
    public var semanticRetrievalLimit: Int = 10
    public var proceduralRetrievalLimit: Int = 5

    public var similarityThreshold: Double = 0.3
    public var defaultSimilarityThreshold: Float {
        get { Float(similarityThreshold) }
        set { similarityThreshold = Double(newValue) }
    }
    public var compressionSimilarityThreshold: Float = 0.8

    // MARK: - Boost Settings
    public var importanceBoostFactor: Float = 0.5
    public var accessBoostFactor: Float = 0.1
    public var accessImportanceBoost: Float = 1.05
    public var recencyBoostMax: Float = 0.3

    // MARK: - Keywords
    public var importantKeywords: [String] = [
        "important", "remember", "key", "critical", "must", "always", "never",
        "deadline", "password", "secret", "preference", "like", "dislike"
    ]

    // MARK: - Coding Keys (exclude computed properties)
    private enum CodingKeys: String, CodingKey {
        case workingCapacity, episodicCapacity, semanticCapacity, proceduralCapacity
        case consolidationInterval, consolidationMinImportance
        case decayRate, semanticDecayRate, minImportance
        case enableActiveRetrieval, enableContextInjection
        case retrievalLimit, episodicRetrievalLimit, semanticRetrievalLimit, proceduralRetrievalLimit
        case similarityThreshold, compressionSimilarityThreshold
        case importanceBoostFactor, accessBoostFactor, accessImportanceBoost, recencyBoostMax
        case importantKeywords
    }

    public init() {}

    func getValue(_ key: String) -> Any? {
        switch key {
        case "workingCapacity", "shortTermCapacity": return workingCapacity
        case "episodicCapacity", "episodicMaxItems": return episodicCapacity
        case "semanticCapacity", "semanticMaxItems", "longTermMaxItems": return semanticCapacity
        case "proceduralCapacity", "proceduralMaxItems": return proceduralCapacity
        case "consolidationInterval", "consolidationThresholdSeconds": return consolidationInterval
        case "consolidationMinImportance": return consolidationMinImportance
        case "decayRate", "generalDecayRate": return decayRate
        case "semanticDecayRate": return semanticDecayRate
        case "minImportance", "minImportanceThreshold": return minImportance
        case "enableActiveRetrieval": return enableActiveRetrieval
        case "enableContextInjection": return enableContextInjection
        case "retrievalLimit", "defaultRetrievalLimit": return retrievalLimit
        case "episodicRetrievalLimit": return episodicRetrievalLimit
        case "semanticRetrievalLimit": return semanticRetrievalLimit
        case "proceduralRetrievalLimit": return proceduralRetrievalLimit
        case "similarityThreshold", "defaultSimilarityThreshold": return similarityThreshold
        case "compressionSimilarityThreshold": return compressionSimilarityThreshold
        case "importanceBoostFactor": return importanceBoostFactor
        case "accessBoostFactor": return accessBoostFactor
        case "accessImportanceBoost": return accessImportanceBoost
        case "recencyBoostMax": return recencyBoostMax
        case "importantKeywords": return importantKeywords
        default: return nil
        }
    }

    mutating func setValue(_ value: Any, forKey key: String) -> Bool {
        switch key {
        case "workingCapacity", "shortTermCapacity":
            if let val = value as? Int { workingCapacity = val; return true }
        case "episodicCapacity", "episodicMaxItems":
            if let val = value as? Int { episodicCapacity = val; return true }
        case "semanticCapacity", "semanticMaxItems", "longTermMaxItems":
            if let val = value as? Int { semanticCapacity = val; return true }
        case "proceduralCapacity", "proceduralMaxItems":
            if let val = value as? Int { proceduralCapacity = val; return true }
        case "consolidationInterval", "consolidationThresholdSeconds":
            if let val = value as? TimeInterval { consolidationInterval = val; return true }
        case "consolidationMinImportance":
            if let val = value as? Double { consolidationMinImportance = val; return true }
        case "decayRate", "generalDecayRate":
            if let val = value as? Double { decayRate = val; return true }
        case "semanticDecayRate":
            if let val = value as? Float { semanticDecayRate = val; return true }
        case "minImportance", "minImportanceThreshold":
            if let val = value as? Double { minImportance = val; return true }
        case "enableActiveRetrieval":
            if let val = value as? Bool { enableActiveRetrieval = val; return true }
        case "enableContextInjection":
            if let val = value as? Bool { enableContextInjection = val; return true }
        case "retrievalLimit", "defaultRetrievalLimit":
            if let val = value as? Int { retrievalLimit = val; return true }
        case "episodicRetrievalLimit":
            if let val = value as? Int { episodicRetrievalLimit = val; return true }
        case "semanticRetrievalLimit":
            if let val = value as? Int { semanticRetrievalLimit = val; return true }
        case "proceduralRetrievalLimit":
            if let val = value as? Int { proceduralRetrievalLimit = val; return true }
        case "similarityThreshold", "defaultSimilarityThreshold":
            if let val = value as? Double { similarityThreshold = val; return true }
        case "compressionSimilarityThreshold":
            if let val = value as? Float { compressionSimilarityThreshold = val; return true }
        case "importanceBoostFactor":
            if let val = value as? Float { importanceBoostFactor = val; return true }
        case "accessBoostFactor":
            if let val = value as? Float { accessBoostFactor = val; return true }
        case "accessImportanceBoost":
            if let val = value as? Float { accessImportanceBoost = val; return true }
        case "recencyBoostMax":
            if let val = value as? Float { recencyBoostMax = val; return true }
        case "importantKeywords":
            if let val = value as? [String] { importantKeywords = val; return true }
        default:
            break
        }
        return false
    }
}

// VerificationConfiguration, ProvidersConfiguration, UIConfiguration,
// TrackingConfiguration, SecurityConfiguration, and ConfigSnapshot
// are defined in TheaConfigSections.swift
