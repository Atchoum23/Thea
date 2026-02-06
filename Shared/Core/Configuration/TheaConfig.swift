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
        """
        THEA CONFIGURATION SCHEMA
        =========================

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

        5. UI Configuration (ui.*)
           - theme: String (system, light, dark)
           - accentColor: String
           - fontSize: CGFloat
           - showConfidenceIndicators: Bool
           - showMemoryContext: Bool
           - enableAnimations: Bool
           - compactMode: Bool

        6. Tracking Configuration (tracking.*)
           - enableLocation: Bool
           - enableHealth: Bool
           - enableUsage: Bool
           - enableBrowser: Bool
           - enableInput: Bool
           - localOnly: Bool
           - enableCloudSync: Bool
           - retentionDays: Int

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

public struct VerificationConfiguration: Codable, Sendable {
    public var enableMultiModel: Bool = true
    public var enableWebSearch: Bool = true
    public var enableCodeExecution: Bool = true
    public var enableStaticAnalysis: Bool = true
    public var enableFeedbackLearning: Bool = true

    public var highConfidenceThreshold: Double = 0.85
    public var mediumConfidenceThreshold: Double = 0.60
    public var lowConfidenceThreshold: Double = 0.30

    public var consensusWeight: Double = 0.30
    public var webSearchWeight: Double = 0.25
    public var codeExecutionWeight: Double = 0.25
    public var staticAnalysisWeight: Double = 0.10
    public var feedbackWeight: Double = 0.10

    public init() {}

    func getValue(_ key: String) -> Any? {
        switch key {
        case "enableMultiModel": return enableMultiModel
        case "enableWebSearch": return enableWebSearch
        case "enableCodeExecution": return enableCodeExecution
        case "enableStaticAnalysis": return enableStaticAnalysis
        case "enableFeedbackLearning": return enableFeedbackLearning
        case "highConfidenceThreshold": return highConfidenceThreshold
        case "mediumConfidenceThreshold": return mediumConfidenceThreshold
        case "lowConfidenceThreshold": return lowConfidenceThreshold
        case "consensusWeight": return consensusWeight
        case "webSearchWeight": return webSearchWeight
        case "codeExecutionWeight": return codeExecutionWeight
        case "staticAnalysisWeight": return staticAnalysisWeight
        case "feedbackWeight": return feedbackWeight
        default: return nil
        }
    }

    mutating func setValue(_ value: Any, forKey key: String) -> Bool {
        switch key {
        case "enableMultiModel":
            if let val = value as? Bool { enableMultiModel = val; return true }
        case "enableWebSearch":
            if let val = value as? Bool { enableWebSearch = val; return true }
        case "enableCodeExecution":
            if let val = value as? Bool { enableCodeExecution = val; return true }
        case "enableStaticAnalysis":
            if let val = value as? Bool { enableStaticAnalysis = val; return true }
        case "enableFeedbackLearning":
            if let val = value as? Bool { enableFeedbackLearning = val; return true }
        case "highConfidenceThreshold":
            if let val = value as? Double { highConfidenceThreshold = val; return true }
        case "mediumConfidenceThreshold":
            if let val = value as? Double { mediumConfidenceThreshold = val; return true }
        case "lowConfidenceThreshold":
            if let val = value as? Double { lowConfidenceThreshold = val; return true }
        case "consensusWeight":
            if let val = value as? Double { consensusWeight = val; return true }
        case "webSearchWeight":
            if let val = value as? Double { webSearchWeight = val; return true }
        case "codeExecutionWeight":
            if let val = value as? Double { codeExecutionWeight = val; return true }
        case "staticAnalysisWeight":
            if let val = value as? Double { staticAnalysisWeight = val; return true }
        case "feedbackWeight":
            if let val = value as? Double { feedbackWeight = val; return true }
        default:
            break
        }
        return false
    }
}

public struct ProvidersConfiguration: Codable, Sendable {
    public var anthropicBaseURL: String = "https://api.anthropic.com/v1"
    public var openaiBaseURL: String = "https://api.openai.com/v1"
    public var openrouterBaseURL: String = "https://openrouter.ai/api/v1"
    public var groqBaseURL: String = "https://api.groq.com/openai/v1"
    public var perplexityBaseURL: String = "https://api.perplexity.ai"
    public var googleBaseURL: String = "https://generativelanguage.googleapis.com/v1beta"
    public var ollamaBaseURL: String = "http://localhost:11434"

    public var timeout: TimeInterval = 60.0
    public var maxRetries: Int = 3
    public var retryDelay: TimeInterval = 1.0

    public init() {}

    func getValue(_ key: String) -> Any? {
        switch key {
        case "anthropicBaseURL": return anthropicBaseURL
        case "openaiBaseURL": return openaiBaseURL
        case "openrouterBaseURL": return openrouterBaseURL
        case "groqBaseURL": return groqBaseURL
        case "perplexityBaseURL": return perplexityBaseURL
        case "googleBaseURL": return googleBaseURL
        case "ollamaBaseURL": return ollamaBaseURL
        case "timeout": return timeout
        case "maxRetries": return maxRetries
        case "retryDelay": return retryDelay
        default: return nil
        }
    }

    mutating func setValue(_ value: Any, forKey key: String) -> Bool {
        switch key {
        case "anthropicBaseURL":
            if let val = value as? String { anthropicBaseURL = val; return true }
        case "openaiBaseURL":
            if let val = value as? String { openaiBaseURL = val; return true }
        case "openrouterBaseURL":
            if let val = value as? String { openrouterBaseURL = val; return true }
        case "groqBaseURL":
            if let val = value as? String { groqBaseURL = val; return true }
        case "perplexityBaseURL":
            if let val = value as? String { perplexityBaseURL = val; return true }
        case "googleBaseURL":
            if let val = value as? String { googleBaseURL = val; return true }
        case "ollamaBaseURL":
            if let val = value as? String { ollamaBaseURL = val; return true }
        case "timeout":
            if let val = value as? TimeInterval { timeout = val; return true }
        case "maxRetries":
            if let val = value as? Int { maxRetries = val; return true }
        case "retryDelay":
            if let val = value as? TimeInterval { retryDelay = val; return true }
        default:
            break
        }
        return false
    }
}

public struct UIConfiguration: Codable, Sendable {
    public var theme: String = "system"
    public var accentColor: String = "blue"
    public var fontSize: CGFloat = 14.0

    public var showConfidenceIndicators: Bool = true
    public var showMemoryContext: Bool = true
    public var enableAnimations: Bool = true
    public var compactMode: Bool = false

    public var sidebarWidth: CGFloat = 250.0
    public var messageSpacing: CGFloat = 12.0

    public init() {}

    func getValue(_ key: String) -> Any? {
        switch key {
        case "theme": return theme
        case "accentColor": return accentColor
        case "fontSize": return fontSize
        case "showConfidenceIndicators": return showConfidenceIndicators
        case "showMemoryContext": return showMemoryContext
        case "enableAnimations": return enableAnimations
        case "compactMode": return compactMode
        case "sidebarWidth": return sidebarWidth
        case "messageSpacing": return messageSpacing
        default: return nil
        }
    }

    mutating func setValue(_ value: Any, forKey key: String) -> Bool {
        switch key {
        case "theme":
            if let val = value as? String { theme = val; return true }
        case "accentColor":
            if let val = value as? String { accentColor = val; return true }
        case "fontSize":
            if let val = value as? CGFloat { fontSize = val; return true }
            if let val = value as? Double { fontSize = CGFloat(val); return true }
        case "showConfidenceIndicators":
            if let val = value as? Bool { showConfidenceIndicators = val; return true }
        case "showMemoryContext":
            if let val = value as? Bool { showMemoryContext = val; return true }
        case "enableAnimations":
            if let val = value as? Bool { enableAnimations = val; return true }
        case "compactMode":
            if let val = value as? Bool { compactMode = val; return true }
        case "sidebarWidth":
            if let val = value as? CGFloat { sidebarWidth = val; return true }
            if let val = value as? Double { sidebarWidth = CGFloat(val); return true }
        case "messageSpacing":
            if let val = value as? CGFloat { messageSpacing = val; return true }
            if let val = value as? Double { messageSpacing = CGFloat(val); return true }
        default:
            break
        }
        return false
    }
}

public struct TrackingConfiguration: Codable, Sendable {
    public var enableLocation: Bool = false
    public var enableHealth: Bool = false
    public var enableUsage: Bool = false
    public var enableBrowser: Bool = false
    public var enableInput: Bool = false

    public var localOnly: Bool = true
    public var enableCloudSync: Bool = false
    public var retentionDays: Int = 365

    public init() {}

    func getValue(_ key: String) -> Any? {
        switch key {
        case "enableLocation": return enableLocation
        case "enableHealth": return enableHealth
        case "enableUsage": return enableUsage
        case "enableBrowser": return enableBrowser
        case "enableInput": return enableInput
        case "localOnly": return localOnly
        case "enableCloudSync": return enableCloudSync
        case "retentionDays": return retentionDays
        default: return nil
        }
    }

    mutating func setValue(_ value: Any, forKey key: String) -> Bool {
        switch key {
        case "enableLocation":
            if let val = value as? Bool { enableLocation = val; return true }
        case "enableHealth":
            if let val = value as? Bool { enableHealth = val; return true }
        case "enableUsage":
            if let val = value as? Bool { enableUsage = val; return true }
        case "enableBrowser":
            if let val = value as? Bool { enableBrowser = val; return true }
        case "enableInput":
            if let val = value as? Bool { enableInput = val; return true }
        case "localOnly":
            if let val = value as? Bool { localOnly = val; return true }
        case "enableCloudSync":
            if let val = value as? Bool { enableCloudSync = val; return true }
        case "retentionDays":
            if let val = value as? Int { retentionDays = val; return true }
        default:
            break
        }
        return false
    }
}

public struct SecurityConfiguration: Codable, Sendable {
    public var requireApprovalForFiles: Bool = true
    public var requireApprovalForTerminal: Bool = true
    public var requireApprovalForNetwork: Bool = false

    public var blockedCommands: [String] = ["rm -rf /", "sudo rm", "mkfs", "dd if="]
    public var allowedDomains: [String] = []
    public var maxFileSize: Int = 100_000_000 // 100MB

    public var enableSandbox: Bool = true
    public var logSensitiveOperations: Bool = true

    public init() {}

    func getValue(_ key: String) -> Any? {
        switch key {
        case "requireApprovalForFiles": return requireApprovalForFiles
        case "requireApprovalForTerminal": return requireApprovalForTerminal
        case "requireApprovalForNetwork": return requireApprovalForNetwork
        case "blockedCommands": return blockedCommands
        case "allowedDomains": return allowedDomains
        case "maxFileSize": return maxFileSize
        case "enableSandbox": return enableSandbox
        case "logSensitiveOperations": return logSensitiveOperations
        default: return nil
        }
    }

    mutating func setValue(_ value: Any, forKey key: String) -> Bool {
        switch key {
        case "requireApprovalForFiles":
            if let val = value as? Bool { requireApprovalForFiles = val; return true }
        case "requireApprovalForTerminal":
            if let val = value as? Bool { requireApprovalForTerminal = val; return true }
        case "requireApprovalForNetwork":
            if let val = value as? Bool { requireApprovalForNetwork = val; return true }
        case "blockedCommands":
            if let val = value as? [String] { blockedCommands = val; return true }
        case "allowedDomains":
            if let val = value as? [String] { allowedDomains = val; return true }
        case "maxFileSize":
            if let val = value as? Int { maxFileSize = val; return true }
        case "enableSandbox":
            if let val = value as? Bool { enableSandbox = val; return true }
        case "logSensitiveOperations":
            if let val = value as? Bool { logSensitiveOperations = val; return true }
        default:
            break
        }
        return false
    }
}

// MARK: - Persistence Helper

private struct ConfigSnapshot: Codable {
    let ai: AIConfiguration
    let memory: MemoryConfiguration
    let verification: VerificationConfiguration
    let providers: ProvidersConfiguration
    let ui: UIConfiguration
    let tracking: TrackingConfiguration
    let security: SecurityConfiguration
}
