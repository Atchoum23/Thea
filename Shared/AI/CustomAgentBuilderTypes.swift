//
//  CustomAgentBuilderTypes.swift
//  Thea
//
//  Custom agent model, supporting types, and errors extracted
//  from CustomAgentBuilder.swift for file_length compliance.
//
//  Copyright 2026. All rights reserved.
//

import CloudKit
import Foundation

// MARK: - Custom Agent Model

public struct CustomAgent: Identifiable, Codable, Sendable {
    public var id: UUID
    public var name: String
    public var description: String
    public var avatar: String
    public var systemPrompt: String
    public var capabilities: Set<CustomAgentCapability>
    public var tools: [String]
    public var knowledgeBase: [KnowledgeItem]
    public var category: AgentCategory
    public var configuration: CustomAgentConfiguration
    public var createdAt: Date
    public var modifiedAt: Date
    public var usageCount: Int
    public var lastUsedAt: Date?
    public var isPublic: Bool
    public var author: String?

    public init(
        id: UUID = UUID(),
        name: String,
        description: String,
        avatar: String = "🤖",
        systemPrompt: String,
        capabilities: Set<CustomAgentCapability> = [],
        tools: [String] = [],
        knowledgeBase: [KnowledgeItem] = [],
        category: AgentCategory = .general,
        configuration: CustomAgentConfiguration = CustomAgentConfiguration(),
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        usageCount: Int = 0,
        lastUsedAt: Date? = nil,
        isPublic: Bool = false,
        author: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.avatar = avatar
        self.systemPrompt = systemPrompt
        self.capabilities = capabilities
        self.tools = tools
        self.knowledgeBase = knowledgeBase
        self.category = category
        self.configuration = configuration
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.usageCount = usageCount
        self.lastUsedAt = lastUsedAt
        self.isPublic = isPublic
        self.author = author
    }

    init?(from record: CKRecord) {
        guard let idString = record["id"] as? String,
              let id = UUID(uuidString: idString),
              let name = record["name"] as? String,
              let systemPrompt = record["systemPrompt"] as? String
        else {
            return nil
        }

        self.id = id
        self.name = name
        description = record["description"] as? String ?? ""
        avatar = record["avatar"] as? String ?? "🤖"
        self.systemPrompt = systemPrompt
        capabilities = []
        tools = record["tools"] as? [String] ?? []
        knowledgeBase = []
        category = AgentCategory(rawValue: record["category"] as? String ?? "general") ?? .general
        configuration = CustomAgentConfiguration()
        createdAt = record["createdAt"] as? Date ?? Date()
        modifiedAt = record["modifiedAt"] as? Date ?? Date()
        usageCount = record["usageCount"] as? Int ?? 0
        lastUsedAt = record["lastUsedAt"] as? Date
        isPublic = record["isPublic"] as? Bool ?? false
        author = record["author"] as? String
    }

    func toCKRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: id.uuidString)
        let record = CKRecord(recordType: "CustomAgent", recordID: recordID)

        record["id"] = id.uuidString
        record["name"] = name
        record["description"] = description
        record["avatar"] = avatar
        record["systemPrompt"] = systemPrompt
        record["tools"] = tools
        record["category"] = category.rawValue
        record["createdAt"] = createdAt
        record["modifiedAt"] = modifiedAt
        record["usageCount"] = usageCount
        record["lastUsedAt"] = lastUsedAt
        record["isPublic"] = isPublic
        record["author"] = author

        return record
    }
}

// MARK: - Supporting Types

public struct KnowledgeItem: Identifiable, Codable, Sendable {
    public let id: UUID
    public let filename: String
    public let content: String
    public let addedAt: Date
}

public struct CustomAgentConfiguration: Codable, Sendable {
    public var modelPreference: String?
    public var temperature: Double
    public var maxTokens: Int
    public var topP: Double
    public var frequencyPenalty: Double
    public var presencePenalty: Double

    public init(
        modelPreference: String? = nil,
        temperature: Double = 0.7,
        maxTokens: Int = 4096,
        topP: Double = 1.0,
        frequencyPenalty: Double = 0.0,
        presencePenalty: Double = 0.0
    ) {
        self.modelPreference = modelPreference
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.topP = topP
        self.frequencyPenalty = frequencyPenalty
        self.presencePenalty = presencePenalty
    }
}

public enum CustomAgentCapability: String, Codable, Sendable, CaseIterable {
    case codeAnalysis = "code_analysis"
    case codeGeneration = "code_generation"
    case contentCreation = "content_creation"
    case editing
    case dataAnalysis = "data_analysis"
    case visualization
    case research
    case translation
    case summarization
    case suggestions
    case webBrowsing = "web_browsing"
    case fileOperations = "file_operations"
    case imageGeneration = "image_generation"
    case imageAnalysis = "image_analysis"

    public var displayName: String {
        switch self {
        case .codeAnalysis: "Code Analysis"
        case .codeGeneration: "Code Generation"
        case .contentCreation: "Content Creation"
        case .editing: "Editing"
        case .dataAnalysis: "Data Analysis"
        case .visualization: "Visualization"
        case .research: "Research"
        case .translation: "Translation"
        case .summarization: "Summarization"
        case .suggestions: "Suggestions"
        case .webBrowsing: "Web Browsing"
        case .fileOperations: "File Operations"
        case .imageGeneration: "Image Generation"
        case .imageAnalysis: "Image Analysis"
        }
    }
}

public enum AgentCategory: String, Codable, Sendable, CaseIterable {
    case general
    case development
    case writing
    case analysis
    case productivity
    case creative
    case education
    case business
    case lifestyle

    public var displayName: String {
        switch self {
        case .general: "General"
        case .development: "Development"
        case .writing: "Writing"
        case .analysis: "Analysis"
        case .productivity: "Productivity"
        case .creative: "Creative"
        case .education: "Education"
        case .business: "Business"
        case .lifestyle: "Lifestyle"
        }
    }

    public var icon: String {
        switch self {
        case .general: "sparkles"
        case .development: "chevron.left.forwardslash.chevron.right"
        case .writing: "pencil"
        case .analysis: "chart.bar"
        case .productivity: "checkmark.circle"
        case .creative: "paintbrush"
        case .education: "book"
        case .business: "briefcase"
        case .lifestyle: "heart"
        }
    }
}

// MARK: - Errors

public enum CustomAgentError: Error, LocalizedError, Sendable {
    case notFound
    case invalidConfiguration
    case importFailed(String)
    case exportFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notFound:
            "Agent not found"
        case .invalidConfiguration:
            "Invalid agent configuration"
        case let .importFailed(reason):
            "Failed to import agent: \(reason)"
        case let .exportFailed(reason):
            "Failed to export agent: \(reason)"
        }
    }
}
