// TheaConfigSections.swift
// Thea V2
//
// Configuration section structs extracted from TheaConfig.swift for file_length compliance.

import Foundation

// MARK: - AI Configuration

public struct AIConfiguration: Codable, Sendable {
    public var defaultProvider: String = "openrouter"
    public var defaultModel: String = "anthropic/claude-sonnet-4-6"
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

// MARK: - Verification Configuration

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

// MARK: - Providers Configuration

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

// MARK: - UI Configuration

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

// MARK: - Tracking Configuration

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

// MARK: - Security Configuration

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

struct ConfigSnapshot: Codable {
    let ai: AIConfiguration
    let memory: MemoryConfiguration
    let verification: VerificationConfiguration
    let providers: ProvidersConfiguration
    let ui: UIConfiguration
    let tracking: TrackingConfiguration
    let security: SecurityConfiguration
}
