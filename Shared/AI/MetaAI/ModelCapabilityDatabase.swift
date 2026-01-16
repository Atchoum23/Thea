import Foundation
import OSLog

// MARK: - Model Capability Database
// Maintains up-to-date database of AI model capabilities for intelligent routing

public struct ModelCapability: Codable, Identifiable, Sendable, Hashable {
    public let id: String  // modelId
    public let modelId: String
    public let displayName: String
    public let provider: String
    public let strengths: [TaskType]
    public let contextWindow: Int
    public let costPerMillionInput: Double
    public let costPerMillionOutput: Double
    public let averageLatency: Double
    public let qualityScore: Double
    public let lastUpdated: Date
    public let source: DataSource
    
    public enum DataSource: String, Codable, Sendable {
        case artificialAnalysis = "Artificial Analysis"
        case openRouter = "OpenRouter API"
        case huggingFace = "Hugging Face"
        case manual = "Manual Entry"
    }
    
    public enum TaskType: String, Codable, Sendable, CaseIterable {
        case code = "Code Generation"
        case reasoning = "Complex Reasoning"
        case creative = "Creative Writing"
        case factual = "Factual Q&A"
        case math = "Math & Logic"
        case summarization = "Summarization"
        case translation = "Translation"
        case vision = "Image Analysis"
        case multimodal = "Multimodal"
        case conversational = "Conversation"
    }
    
    public init(
        modelId: String,
        displayName: String,
        provider: String,
        strengths: [TaskType],
        contextWindow: Int,
        costPerMillionInput: Double,
        costPerMillionOutput: Double,
        averageLatency: Double,
        qualityScore: Double,
        lastUpdated: Date = Date(),
        source: DataSource
    ) {
        self.id = modelId
        self.modelId = modelId
        self.displayName = displayName
        self.provider = provider
        self.strengths = strengths
        self.contextWindow = contextWindow
        self.costPerMillionInput = costPerMillionInput
        self.costPerMillionOutput = costPerMillionOutput
        self.averageLatency = averageLatency
        self.qualityScore = qualityScore
        self.lastUpdated = lastUpdated
        self.source = source
    }
    
    public var costPerToken: Double {
        (costPerMillionInput + costPerMillionOutput) / 2_000_000
    }
    
    public var qualityCostRatio: Double {
        qualityScore / (costPerMillionInput + costPerMillionOutput)
    }
}

// MARK: - Model Capability Database

@MainActor
@Observable
public final class ModelCapabilityDatabase {
    public static let shared = ModelCapabilityDatabase()
    
    private let logger = Logger(subsystem: "com.thea.orchestrator", category: "ModelCapabilityDatabase")
    
    public private(set) var models: [ModelCapability] = []
    public private(set) var lastUpdated: Date?
    public private(set) var isUpdating: Bool = false
    
    private let storageKey = "com.thea.model.capability.database"
    private let cacheExpiration: TimeInterval = 86400 // 24 hours
    
    public var autoUpdate: Bool = true {
        didSet {
            UserDefaults.standard.set(autoUpdate, forKey: "modelCapability.autoUpdate")
        }
    }
    
    public var updateFrequency: UpdateFrequency = .daily {
        didSet {
            UserDefaults.standard.set(updateFrequency.rawValue, forKey: "modelCapability.updateFrequency")
        }
    }
    
    public enum UpdateFrequency: String, Codable, CaseIterable, Sendable {
        case hourly = "Hourly"
        case daily = "Daily"
        case weekly = "Weekly"
        case manual = "Manual Only"
        
        public var interval: TimeInterval {
            switch self {
            case .hourly: return 3600
            case .daily: return 86400
            case .weekly: return 604800
            case .manual: return .infinity
            }
        }
    }
    
    private init() {
        loadAutoUpdateSettings()
        loadModels()
        
        // Add seed data if empty
        if models.isEmpty {
            addSeedData()
        }
        
        // Auto-update check
        if autoUpdate {
            Task {
                await checkAndUpdate()
            }
        }
    }
    
    // MARK: - Seed Data
    
    private func addSeedData() {
        models = [
            // Claude Models
            ModelCapability(
                modelId: "anthropic/claude-opus-4-5-20251101",
                displayName: "Claude Opus 4.5",
                provider: "anthropic",
                strengths: [.code, .reasoning, .creative, .conversational],
                contextWindow: 200_000,
                costPerMillionInput: 15.0,
                costPerMillionOutput: 75.0,
                averageLatency: 2500,
                qualityScore: 0.95,
                source: .manual
            ),
            ModelCapability(
                modelId: "anthropic/claude-sonnet-4-20250514",
                displayName: "Claude Sonnet 4",
                provider: "anthropic",
                strengths: [.code, .reasoning, .conversational],
                contextWindow: 200_000,
                costPerMillionInput: 3.0,
                costPerMillionOutput: 15.0,
                averageLatency: 1800,
                qualityScore: 0.92,
                source: .manual
            ),
            
            // OpenAI Models
            ModelCapability(
                modelId: "openai/gpt-4o",
                displayName: "GPT-4o",
                provider: "openai",
                strengths: [.code, .reasoning, .vision, .multimodal],
                contextWindow: 128_000,
                costPerMillionInput: 5.0,
                costPerMillionOutput: 15.0,
                averageLatency: 1500,
                qualityScore: 0.90,
                source: .manual
            ),
            ModelCapability(
                modelId: "openai/gpt-4o-mini",
                displayName: "GPT-4o Mini",
                provider: "openai",
                strengths: [.factual, .summarization, .conversational],
                contextWindow: 128_000,
                costPerMillionInput: 0.15,
                costPerMillionOutput: 0.60,
                averageLatency: 800,
                qualityScore: 0.80,
                source: .manual
            ),
            
            // Google Models
            ModelCapability(
                modelId: "google/gemini-2.0-flash",
                displayName: "Gemini 2.0 Flash",
                provider: "google",
                strengths: [.code, .multimodal, .vision],
                contextWindow: 1_000_000,
                costPerMillionInput: 0.10,
                costPerMillionOutput: 0.40,
                averageLatency: 1200,
                qualityScore: 0.88,
                source: .manual
            ),
            
            // DeepSeek Models
            ModelCapability(
                modelId: "deepseek/deepseek-chat",
                displayName: "DeepSeek Chat",
                provider: "deepseek",
                strengths: [.code, .reasoning, .math],
                contextWindow: 128_000,
                costPerMillionInput: 0.14,
                costPerMillionOutput: 0.28,
                averageLatency: 1600,
                qualityScore: 0.85,
                source: .manual
            ),
            
            // Meta Models
            ModelCapability(
                modelId: "meta-llama/llama-3.1-405b",
                displayName: "Llama 3.1 405B",
                provider: "meta",
                strengths: [.code, .reasoning, .creative],
                contextWindow: 128_000,
                costPerMillionInput: 3.0,
                costPerMillionOutput: 3.0,
                averageLatency: 2000,
                qualityScore: 0.87,
                source: .manual
            )
        ]
        
        lastUpdated = Date()
        saveModels()
        logger.info("Added \(self.models.count) seed models to database")
    }
    
    // MARK: - Public API
    
    public func updateNow() async {
        guard !isUpdating else {
            logger.warning("Update already in progress")
            return
        }
        
        isUpdating = true
        defer { isUpdating = false }
        
        logger.info("Starting model capability database update...")
        
        // Update from OpenRouter API
        await updateFromOpenRouter()
        
        lastUpdated = Date()
        saveModels()
        
        logger.info("Database updated: \(self.models.count) models indexed")
    }
    
    public func getBestModel(for taskType: ModelCapability.TaskType, preferences: RoutingPreferences) -> ModelCapability? {
        return models
            .filter { $0.strengths.contains(taskType) }
            .filter { preferences.localPreferred ? $0.provider == "local" : true }
            .sorted { model1, model2 in
                // Sort by quality-cost ratio
                let ratio1 = model1.qualityScore / (model1.costPerMillionInput + 0.01)
                let ratio2 = model2.qualityScore / (model2.costPerMillionInput + 0.01)
                return ratio1 > ratio2
            }
            .first
    }
    
    public func getModel(id: String) -> ModelCapability? {
        return models.first { $0.modelId == id }
    }
    
    public func getModels(for provider: String) -> [ModelCapability] {
        return models.filter { $0.provider == provider }
    }
    
    public func getModels(strongIn taskType: ModelCapability.TaskType) -> [ModelCapability] {
        return models.filter { $0.strengths.contains(taskType) }
    }
    
    public struct RoutingPreferences: Sendable {
        public let localPreferred: Bool
        public let maxCostPerMillion: Double?
        public let minQualityScore: Double?
        
        public init(
            localPreferred: Bool = false,
            maxCostPerMillion: Double? = nil,
            minQualityScore: Double? = nil
        ) {
            self.localPreferred = localPreferred
            self.maxCostPerMillion = maxCostPerMillion
            self.minQualityScore = minQualityScore
        }
    }
    
    // MARK: - Auto-Update
    
    private func checkAndUpdate() async {
        guard autoUpdate else { return }
        
        let shouldUpdate: Bool
        if let lastUpdate = lastUpdated {
            let elapsed = Date().timeIntervalSince(lastUpdate)
            shouldUpdate = elapsed >= updateFrequency.interval
        } else {
            shouldUpdate = true
        }
        
        if shouldUpdate {
            await updateNow()
        }
    }
    
    // MARK: - Data Sources
    
    private func updateFromOpenRouter() async {
        // Stub implementation - would call OpenRouter API
        // GET https://openrouter.ai/api/v1/models
        logger.info("Updating from OpenRouter API (stub)")
        
        // In production:
        // 1. Fetch models from API
        // 2. Parse response
        // 3. Map to ModelCapability
        // 4. Merge with existing models
    }
    
    // MARK: - Persistence
    
    private func saveModels() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(models)
            UserDefaults.standard.set(data, forKey: storageKey)
            
            if let lastUpdate = lastUpdated {
                UserDefaults.standard.set(lastUpdate, forKey: "\(storageKey).lastUpdated")
            }
        } catch {
            logger.error("Failed to save models: \(error.localizedDescription)")
        }
    }
    
    private func loadModels() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            models = try decoder.decode([ModelCapability].self, from: data)
            lastUpdated = UserDefaults.standard.object(forKey: "\(storageKey).lastUpdated") as? Date
            logger.info("Loaded \(self.models.count) models from cache")
        } catch {
            logger.error("Failed to load models: \(error.localizedDescription)")
        }
    }
    
    private func loadAutoUpdateSettings() {
        autoUpdate = UserDefaults.standard.bool(forKey: "modelCapability.autoUpdate")
        if let frequencyRaw = UserDefaults.standard.string(forKey: "modelCapability.updateFrequency"),
           let frequency = UpdateFrequency(rawValue: frequencyRaw) {
            updateFrequency = frequency
        }
    }
}
