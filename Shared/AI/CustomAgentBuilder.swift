//
//  CustomAgentBuilder.swift
//  Thea
//
//  Created by Claude Code on 2026-01-22
//  Copyright © 2026. All rights reserved.
//

import Foundation
import CloudKit

// MARK: - Custom Agent Builder

/// Create and manage custom AI agents similar to ChatGPT's GPTs
/// Supports custom instructions, knowledge bases, tools, and personas
@MainActor
public class CustomAgentBuilder: ObservableObject {
    public static let shared = CustomAgentBuilder()
    
    // MARK: - Published State
    
    @Published public private(set) var agents: [CustomAgent] = []
    @Published public private(set) var currentAgent: CustomAgent?
    @Published public private(set) var isLoading = false
    
    // MARK: - CloudKit
    
    private let container = CKContainer(identifier: "iCloud.app.thea.agents")
    private lazy var privateDatabase = container.privateCloudDatabase
    
    // MARK: - Storage
    
    private let storageKey = "CustomAgentBuilder.agents"
    private let agentsDirectory: URL
    
    // MARK: - Initialization
    
    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        agentsDirectory = documentsPath.appendingPathComponent("CustomAgents", isDirectory: true)

        try? FileManager.default.createDirectory(at: agentsDirectory, withIntermediateDirectories: true)

        loadAgents()
        createDefaultAgents()
    }
    
    // MARK: - Load/Save
    
    private func loadAgents() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([CustomAgent].self, from: data) {
            agents = decoded
        }
        
        Task {
            await syncWithCloud()
        }
    }
    
    private func saveAgents() {
        if let data = try? JSONEncoder().encode(agents) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    private func createDefaultAgents() {
        guard agents.isEmpty else { return }
        
        // Create some default agents
        let codeReviewer = CustomAgent(
            name: "Code Reviewer",
            description: "Expert code reviewer that analyzes code quality, suggests improvements, and identifies bugs",
            avatar: "🔍",
            systemPrompt: """
            You are an expert code reviewer with deep knowledge of software engineering best practices.
            
            When reviewing code:
            1. Check for bugs and potential issues
            2. Evaluate code quality and readability
            3. Suggest performance improvements
            4. Ensure proper error handling
            5. Verify security best practices
            6. Check for code duplication
            7. Evaluate test coverage needs
            
            Be constructive and explain your suggestions clearly.
            """,
            capabilities: [.codeAnalysis, .suggestions],
            category: .development
        )
        
        let writingAssistant = CustomAgent(
            name: "Writing Assistant",
            description: "Professional writer that helps with content creation, editing, and proofreading",
            avatar: "✍️",
            systemPrompt: """
            You are a professional writing assistant with expertise in various writing styles.
            
            Your capabilities include:
            1. Content creation for blogs, articles, and documentation
            2. Editing for clarity, grammar, and style
            3. Proofreading and fact-checking
            4. Adapting tone for different audiences
            5. SEO optimization suggestions
            6. Structuring long-form content
            
            Always ask about the target audience and purpose before writing.
            """,
            capabilities: [.contentCreation, .editing],
            category: .writing
        )
        
        let dataAnalyst = CustomAgent(
            name: "Data Analyst",
            description: "Expert data analyst that helps analyze, visualize, and interpret data",
            avatar: "📊",
            systemPrompt: """
            You are an expert data analyst with skills in statistical analysis and visualization.
            
            Your expertise includes:
            1. Data cleaning and preprocessing
            2. Statistical analysis and hypothesis testing
            3. Data visualization recommendations
            4. Pattern recognition and trend analysis
            5. SQL query optimization
            6. Python/R analysis scripts
            7. Dashboard design suggestions
            
            Always explain your analysis methodology and assumptions.
            """,
            capabilities: [.dataAnalysis, .codeGeneration, .visualization],
            category: .analysis
        )
        
        agents = [codeReviewer, writingAssistant, dataAnalyst]
        saveAgents()
    }
    
    // MARK: - Create Agent
    
    /// Create a new custom agent
    public func createAgent(
        name: String,
        description: String,
        avatar: String = "🤖",
        systemPrompt: String,
        capabilities: Set<CustomAgentCapability> = [],
        tools: [String] = [],
        knowledgeFiles: [URL] = [],
        category: AgentCategory = .general,
        modelPreference: String? = nil,
        temperature: Double = 0.7,
        maxTokens: Int = 4096
    ) async throws -> CustomAgent {
        isLoading = true
        defer { isLoading = false }
        
        // Process knowledge files
        var knowledgeBase: [KnowledgeItem] = []
        for fileURL in knowledgeFiles {
            if let content = try? String(contentsOf: fileURL, encoding: .utf8) {
                knowledgeBase.append(KnowledgeItem(
                    id: UUID(),
                    filename: fileURL.lastPathComponent,
                    content: content,
                    addedAt: Date()
                ))
            }
        }
        
        let agent = CustomAgent(
            name: name,
            description: description,
            avatar: avatar,
            systemPrompt: systemPrompt,
            capabilities: capabilities,
            tools: tools,
            knowledgeBase: knowledgeBase,
            category: category,
            configuration: CustomAgentConfiguration(
                modelPreference: modelPreference,
                temperature: temperature,
                maxTokens: maxTokens
            )
        )
        
        agents.insert(agent, at: 0)
        saveAgents()
        
        Task {
            try? await saveToCloud(agent)
        }
        
        return agent
    }
    
    /// Duplicate an existing agent
    public func duplicate(_ agent: CustomAgent) async throws -> CustomAgent {
        var newAgent = agent
        newAgent.id = UUID()
        newAgent.name = "\(agent.name) (Copy)"
        newAgent.createdAt = Date()
        newAgent.modifiedAt = Date()
        newAgent.usageCount = 0
        
        agents.insert(newAgent, at: 0)
        saveAgents()
        
        return newAgent
    }
    
    // MARK: - Update Agent
    
    /// Update an agent's properties
    public func update(
        _ agent: CustomAgent,
        name: String? = nil,
        description: String? = nil,
        avatar: String? = nil,
        systemPrompt: String? = nil,
        capabilities: Set<CustomAgentCapability>? = nil,
        tools: [String]? = nil,
        category: AgentCategory? = nil,
        configuration: CustomAgentConfiguration? = nil
    ) async throws -> CustomAgent {
        guard let index = agents.firstIndex(where: { $0.id == agent.id }) else {
            throw CustomAgentError.notFound
        }
        
        var updated = agents[index]
        if let name = name { updated.name = name }
        if let description = description { updated.description = description }
        if let avatar = avatar { updated.avatar = avatar }
        if let systemPrompt = systemPrompt { updated.systemPrompt = systemPrompt }
        if let capabilities = capabilities { updated.capabilities = capabilities }
        if let tools = tools { updated.tools = tools }
        if let category = category { updated.category = category }
        if let configuration = configuration { updated.configuration = configuration }
        updated.modifiedAt = Date()
        
        agents[index] = updated
        saveAgents()
        
        Task {
            try? await saveToCloud(updated)
        }
        
        return updated
    }
    
    /// Add knowledge to an agent
    public func addKnowledge(to agent: CustomAgent, file: URL) async throws -> CustomAgent {
        guard let index = agents.firstIndex(where: { $0.id == agent.id }) else {
            throw CustomAgentError.notFound
        }
        
        let content = try String(contentsOf: file, encoding: .utf8)
        let item = KnowledgeItem(
            id: UUID(),
            filename: file.lastPathComponent,
            content: content,
            addedAt: Date()
        )
        
        agents[index].knowledgeBase.append(item)
        agents[index].modifiedAt = Date()
        saveAgents()
        
        return agents[index]
    }
    
    /// Remove knowledge from an agent
    public func removeKnowledge(from agent: CustomAgent, itemId: UUID) async throws -> CustomAgent {
        guard let index = agents.firstIndex(where: { $0.id == agent.id }) else {
            throw CustomAgentError.notFound
        }
        
        agents[index].knowledgeBase.removeAll { $0.id == itemId }
        agents[index].modifiedAt = Date()
        saveAgents()
        
        return agents[index]
    }
    
    // MARK: - Delete Agent
    
    /// Delete an agent
    public func delete(_ agent: CustomAgent) async throws {
        agents.removeAll { $0.id == agent.id }
        saveAgents()
        
        Task {
            try? await deleteFromCloud(agent)
        }
    }
    
    // MARK: - Use Agent
    
    /// Select an agent for use
    public func select(_ agent: CustomAgent) {
        currentAgent = agent
        
        // Update usage count
        if let index = agents.firstIndex(where: { $0.id == agent.id }) {
            agents[index].usageCount += 1
            agents[index].lastUsedAt = Date()
            saveAgents()
        }
    }
    
    /// Deselect current agent
    public func deselect() {
        currentAgent = nil
    }
    
    /// Get system prompt for current agent
    public func getSystemPrompt() -> String? {
        guard let agent = currentAgent else { return nil }
        
        var prompt = agent.systemPrompt
        
        // Add knowledge base context if available
        if !agent.knowledgeBase.isEmpty {
            prompt += "\n\n--- Knowledge Base ---\n"
            for item in agent.knowledgeBase {
                prompt += "\n[\(item.filename)]:\n\(item.content.prefix(5000))\n"
            }
        }
        
        return prompt
    }
    
    /// Get available tools for current agent
    public func getAvailableTools() -> [String] {
        currentAgent?.tools ?? []
    }
    
    // MARK: - Query
    
    /// Get agents by category
    public func getAgents(category: AgentCategory) -> [CustomAgent] {
        agents.filter { $0.category == category }
    }
    
    /// Get most used agents
    public func getMostUsed(limit: Int = 5) -> [CustomAgent] {
        agents.sorted { $0.usageCount > $1.usageCount }.prefix(limit).map { $0 }
    }
    
    /// Get recently used agents
    public func getRecentlyUsed(limit: Int = 5) -> [CustomAgent] {
        agents
            .filter { $0.lastUsedAt != nil }
            .sorted { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }
            .prefix(limit)
            .map { $0 }
    }
    
    /// Search agents
    public func search(query: String) -> [CustomAgent] {
        let lowercased = query.lowercased()
        return agents.filter { agent in
            agent.name.lowercased().contains(lowercased) ||
            agent.description.lowercased().contains(lowercased) ||
            agent.systemPrompt.lowercased().contains(lowercased)
        }
    }
    
    // MARK: - Import/Export
    
    /// Export agent to JSON
    public func export(_ agent: CustomAgent) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(agent)
    }
    
    /// Import agent from JSON
    public func importAgent(from data: Data) throws -> CustomAgent {
        var agent = try JSONDecoder().decode(CustomAgent.self, from: data)
        agent.id = UUID() // Generate new ID
        agent.createdAt = Date()
        agent.modifiedAt = Date()
        agent.usageCount = 0
        agent.lastUsedAt = nil
        
        agents.insert(agent, at: 0)
        saveAgents()
        
        return agent
    }
    
    /// Export agent to file
    public func export(_ agent: CustomAgent, to url: URL) throws {
        let data = try export(agent)
        try data.write(to: url)
    }
    
    /// Import agent from file
    public func importAgent(from url: URL) throws -> CustomAgent {
        let data = try Data(contentsOf: url)
        return try importAgent(from: data)
    }
    
    // MARK: - Cloud Sync
    
    private func syncWithCloud() async {
        do {
            let status = try await container.accountStatus()
            guard status == .available else { return }
            
            let query = CKQuery(recordType: "CustomAgent", predicate: NSPredicate(value: true))
            let results = try await privateDatabase.records(matching: query)
            
            for (_, result) in results.matchResults {
                if case .success(let record) = result,
                   let agent = CustomAgent(from: record),
                   !agents.contains(where: { $0.id == agent.id }) {
                    agents.append(agent)
                }
            }
            
            saveAgents()
        } catch {
            // Sync failed
        }
    }
    
    private func saveToCloud(_ agent: CustomAgent) async throws {
        let record = agent.toCKRecord()
        _ = try await privateDatabase.save(record)
    }
    
    private func deleteFromCloud(_ agent: CustomAgent) async throws {
        let recordID = CKRecord.ID(recordName: agent.id.uuidString)
        try await privateDatabase.deleteRecord(withID: recordID)
    }
}

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
              let systemPrompt = record["systemPrompt"] as? String else {
            return nil
        }
        
        self.id = id
        self.name = name
        self.description = record["description"] as? String ?? ""
        self.avatar = record["avatar"] as? String ?? "🤖"
        self.systemPrompt = systemPrompt
        self.capabilities = []
        self.tools = record["tools"] as? [String] ?? []
        self.knowledgeBase = []
        self.category = AgentCategory(rawValue: record["category"] as? String ?? "general") ?? .general
        self.configuration = CustomAgentConfiguration()
        self.createdAt = record["createdAt"] as? Date ?? Date()
        self.modifiedAt = record["modifiedAt"] as? Date ?? Date()
        self.usageCount = record["usageCount"] as? Int ?? 0
        self.lastUsedAt = record["lastUsedAt"] as? Date
        self.isPublic = record["isPublic"] as? Bool ?? false
        self.author = record["author"] as? String
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
    case editing = "editing"
    case dataAnalysis = "data_analysis"
    case visualization = "visualization"
    case research = "research"
    case translation = "translation"
    case summarization = "summarization"
    case suggestions = "suggestions"
    case webBrowsing = "web_browsing"
    case fileOperations = "file_operations"
    case imageGeneration = "image_generation"
    case imageAnalysis = "image_analysis"
    
    public var displayName: String {
        switch self {
        case .codeAnalysis: return "Code Analysis"
        case .codeGeneration: return "Code Generation"
        case .contentCreation: return "Content Creation"
        case .editing: return "Editing"
        case .dataAnalysis: return "Data Analysis"
        case .visualization: return "Visualization"
        case .research: return "Research"
        case .translation: return "Translation"
        case .summarization: return "Summarization"
        case .suggestions: return "Suggestions"
        case .webBrowsing: return "Web Browsing"
        case .fileOperations: return "File Operations"
        case .imageGeneration: return "Image Generation"
        case .imageAnalysis: return "Image Analysis"
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
        case .general: return "General"
        case .development: return "Development"
        case .writing: return "Writing"
        case .analysis: return "Analysis"
        case .productivity: return "Productivity"
        case .creative: return "Creative"
        case .education: return "Education"
        case .business: return "Business"
        case .lifestyle: return "Lifestyle"
        }
    }
    
    public var icon: String {
        switch self {
        case .general: return "sparkles"
        case .development: return "chevron.left.forwardslash.chevron.right"
        case .writing: return "pencil"
        case .analysis: return "chart.bar"
        case .productivity: return "checkmark.circle"
        case .creative: return "paintbrush"
        case .education: return "book"
        case .business: return "briefcase"
        case .lifestyle: return "heart"
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
            return "Agent not found"
        case .invalidConfiguration:
            return "Invalid agent configuration"
        case .importFailed(let reason):
            return "Failed to import agent: \(reason)"
        case .exportFailed(let reason):
            return "Failed to export agent: \(reason)"
        }
    }
}
