// LocalModelRecommendationEngine.swift
// AI-powered local model monitoring, discovery, and recommendation system

import Foundation

// MARK: - Local Model Recommendation Engine

@MainActor
@Observable
final class LocalModelRecommendationEngine {
    static let shared = LocalModelRecommendationEngine()

    // MARK: - State

    private(set) var availableModels: [DiscoveredModel] = []
    private(set) var installedModels: [InstalledLocalModel] = []
    private(set) var recommendations: [ModelRecommendation] = []
    private(set) var isScanning = false
    private(set) var lastScanDate: Date?
    private(set) var userProfile = UserUsageProfile()

    // Configuration
    struct Configuration: Codable, Sendable {
        var enableAutoDiscovery = true
        var scanIntervalHours: Int = 24
        var enableProactiveRecommendations = true
        var maxRecommendations = 5
        var preferredQuantization: String = "4bit"
        var maxModelSizeGB: Double = 8.0
        var preferredSources: [String] = ["mlx-community", "huggingface"]
    }

    private(set) var configuration = Configuration()

    // MARK: - Initialization

    private init() {
        loadConfiguration()
        loadUserProfile()
        Task {
            await initialScan()
            startMonitoring()
        }
    }

    // MARK: - Scanning & Discovery

    /// Perform initial scan of installed and available models
    private func initialScan() async {
        await scanInstalledModels()
        await discoverAvailableModels()
        await generateRecommendations()
    }

    /// Scan locally installed models (MLX, Ollama, etc.)
    func scanInstalledModels() async {
        isScanning = true
        defer { isScanning = false }

        var models: [InstalledLocalModel] = []

        // Scan MLX models
        let mlxModels = await scanMLXModels()
        models.append(contentsOf: mlxModels)

        // Scan Ollama models
        let ollamaModels = await scanOllamaModels()
        models.append(contentsOf: ollamaModels)

        installedModels = models
        lastScanDate = Date()
        saveLastScanDate()
    }

    private func scanMLXModels() async -> [InstalledLocalModel] {
        var models: [InstalledLocalModel] = []

        // Get MLX model directories from settings
        let mlxPath = SettingsManager.shared.mlxModelsPath
        guard !mlxPath.isEmpty else { return [] }

        let url = URL(fileURLWithPath: mlxPath)
        let fileManager = FileManager.default

        guard let contents = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        for itemURL in contents {
            let isDirectory = (try? itemURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDirectory {
                // Check for MLX model files
                let configPath = itemURL.appendingPathComponent("config.json")
                if fileManager.fileExists(atPath: configPath.path) {
                    let model = InstalledLocalModel(
                        id: UUID(),
                        name: itemURL.lastPathComponent,
                        source: .mlx,
                        path: itemURL.path,
                        sizeBytes: calculateDirectorySize(url: itemURL),
                        quantization: detectQuantization(itemURL),
                        capabilities: detectCapabilities(itemURL),
                        installedDate: (try? fileManager.attributesOfItem(atPath: itemURL.path)[.creationDate] as? Date) ?? Date()
                    )
                    models.append(model)
                }
            }
        }

        return models
    }

    private func scanOllamaModels() async -> [InstalledLocalModel] {
        guard SettingsManager.shared.ollamaEnabled else { return [] }

        let ollamaURL = SettingsManager.shared.ollamaURL.isEmpty
            ? "http://localhost:11434"
            : SettingsManager.shared.ollamaURL

        guard let url = URL(string: "\(ollamaURL)/api/tags") else { return [] }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)

            return response.models.map { model in
                InstalledLocalModel(
                    id: UUID(),
                    name: model.name,
                    source: .ollama,
                    path: "ollama://\(model.name)",
                    sizeBytes: model.size,
                    quantization: model.details?.quantizationLevel,
                    capabilities: parseOllamaCapabilities(model),
                    installedDate: ISO8601DateFormatter().date(from: model.modifiedAt) ?? Date()
                )
            }
        } catch {
            print("Failed to scan Ollama models: \(error)")
            return []
        }
    }

    // MARK: - Model Discovery

    /// Discover available models from HuggingFace and other sources
    func discoverAvailableModels() async {
        isScanning = true
        defer { isScanning = false }

        var discovered: [DiscoveredModel] = []

        // Discover from HuggingFace MLX Community
        let hfModels = await discoverHuggingFaceModels()
        discovered.append(contentsOf: hfModels)

        // Discover from Ollama library
        let ollamaModels = await discoverOllamaLibraryModels()
        discovered.append(contentsOf: ollamaModels)

        availableModels = discovered
    }

    private func discoverHuggingFaceModels() async -> [DiscoveredModel] {
        // HuggingFace API for MLX models
        guard let url = URL(string: "https://huggingface.co/api/models?library=mlx&sort=downloads&limit=50") else {
            return []
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let models = try JSONDecoder().decode([HuggingFaceModel].self, from: data)

            return models.compactMap { hfModel -> DiscoveredModel? in
                guard let modelId = hfModel.modelId else { return nil }

                return DiscoveredModel(
                    id: modelId,
                    name: extractModelName(from: modelId),
                    source: .huggingFace,
                    author: hfModel.author ?? "unknown",
                    description: hfModel.description,
                    downloads: hfModel.downloads ?? 0,
                    likes: hfModel.likes ?? 0,
                    estimatedSizeGB: estimateModelSize(hfModel),
                    quantization: detectQuantizationFromName(modelId),
                    capabilities: detectCapabilitiesFromTags(hfModel.tags ?? []),
                    benchmarks: nil,
                    lastUpdated: ISO8601DateFormatter().date(from: hfModel.lastModified ?? "") ?? Date(),
                    downloadURL: "https://huggingface.co/\(modelId)"
                )
            }
        } catch {
            print("Failed to discover HuggingFace models: \(error)")
            return []
        }
    }

    private func discoverOllamaLibraryModels() async -> [DiscoveredModel] {
        // Popular Ollama models (static list since Ollama doesn't have a public discovery API)
        [
            DiscoveredModel(
                id: "llama3.2:latest",
                name: "Llama 3.2",
                source: .ollamaLibrary,
                author: "Meta",
                description: "Latest Llama model optimized for chat and code",
                downloads: 100000,
                likes: 5000,
                estimatedSizeGB: 4.7,
                quantization: "Q4_K_M",
                capabilities: [.chat, .code, .reasoning],
                benchmarks: ModelBenchmarks(mmlu: 75.2, humanEval: 68.0, gsm8k: 82.1),
                lastUpdated: Date(),
                downloadURL: "ollama://llama3.2"
            ),
            DiscoveredModel(
                id: "qwen2.5:7b",
                name: "Qwen 2.5 7B",
                source: .ollamaLibrary,
                author: "Alibaba",
                description: "Excellent multilingual and coding capabilities",
                downloads: 80000,
                likes: 4200,
                estimatedSizeGB: 4.4,
                quantization: "Q4_K_M",
                capabilities: [.chat, .code, .multilingual],
                benchmarks: ModelBenchmarks(mmlu: 74.8, humanEval: 71.2, gsm8k: 79.5),
                lastUpdated: Date(),
                downloadURL: "ollama://qwen2.5:7b"
            ),
            DiscoveredModel(
                id: "deepseek-coder-v2:16b",
                name: "DeepSeek Coder V2 16B",
                source: .ollamaLibrary,
                author: "DeepSeek",
                description: "State-of-the-art coding model with MoE architecture",
                downloads: 60000,
                likes: 3800,
                estimatedSizeGB: 8.5,
                quantization: "Q4_K_M",
                capabilities: [.code, .reasoning],
                benchmarks: ModelBenchmarks(mmlu: 72.0, humanEval: 82.5, gsm8k: 75.0),
                lastUpdated: Date(),
                downloadURL: "ollama://deepseek-coder-v2:16b"
            ),
            DiscoveredModel(
                id: "mistral:7b",
                name: "Mistral 7B",
                source: .ollamaLibrary,
                author: "Mistral AI",
                description: "Fast and efficient general-purpose model",
                downloads: 150000,
                likes: 6000,
                estimatedSizeGB: 4.1,
                quantization: "Q4_K_M",
                capabilities: [.chat, .reasoning],
                benchmarks: ModelBenchmarks(mmlu: 70.5, humanEval: 52.0, gsm8k: 68.0),
                lastUpdated: Date(),
                downloadURL: "ollama://mistral:7b"
            ),
            DiscoveredModel(
                id: "codellama:7b",
                name: "Code Llama 7B",
                source: .ollamaLibrary,
                author: "Meta",
                description: "Specialized for code generation and understanding",
                downloads: 120000,
                likes: 5500,
                estimatedSizeGB: 3.8,
                quantization: "Q4_K_M",
                capabilities: [.code],
                benchmarks: ModelBenchmarks(mmlu: 45.0, humanEval: 75.0, gsm8k: 35.0),
                lastUpdated: Date(),
                downloadURL: "ollama://codellama:7b"
            )
        ]
    }

    // MARK: - Recommendations

    /// Generate personalized model recommendations based on user activity
    func generateRecommendations() async {
        var recs: [ModelRecommendation] = []

        // Analyze user's usage patterns
        let topTaskTypes = analyzeUserTaskTypes()
        let systemCapabilities = analyzeSystemCapabilities()

        // Filter models that fit system constraints
        let eligibleModels = availableModels.filter { model in
            model.estimatedSizeGB <= configuration.maxModelSizeGB &&
            !installedModels.contains { $0.name.lowercased().contains(model.name.lowercased()) }
        }

        // Score and rank models
        for model in eligibleModels {
            let score = calculateRecommendationScore(
                model: model,
                topTasks: topTaskTypes,
                systemCaps: systemCapabilities
            )

            if score > 0.5 {
                let reasons = generateRecommendationReasons(
                    model: model,
                    topTasks: topTaskTypes
                )

                recs.append(ModelRecommendation(
                    model: model,
                    score: score,
                    reasons: reasons,
                    priority: determinePriority(score: score)
                ))
            }
        }

        // Sort by score and limit
        recommendations = recs
            .sorted { $0.score > $1.score }
            .prefix(configuration.maxRecommendations)
            .map { $0 }
    }

    private func analyzeUserTaskTypes() -> [TaskType: Double] {
        // Return task distribution from user profile
        userProfile.taskDistribution
    }

    private func analyzeSystemCapabilities() -> SystemCapabilities {
        let memory = ProcessInfo.processInfo.physicalMemory
        let memoryGB = Double(memory) / 1_073_741_824

        return SystemCapabilities(
            totalMemoryGB: memoryGB,
            availableMemoryGB: memoryGB * 0.7, // Estimate 70% available
            hasGPU: true, // Apple Silicon always has GPU
            isAppleSilicon: true
        )
    }

    private func calculateRecommendationScore(
        model: DiscoveredModel,
        topTasks: [TaskType: Double],
        systemCaps: SystemCapabilities
    ) -> Double {
        var score = 0.0

        // Task capability match (0-0.4)
        for (task, weight) in topTasks {
            if model.capabilities.contains(mapTaskToCapability(task)) {
                score += 0.4 * weight
            }
        }

        // Size appropriateness (0-0.2)
        let sizeRatio = model.estimatedSizeGB / systemCaps.availableMemoryGB
        if sizeRatio < 0.3 {
            score += 0.2
        } else if sizeRatio < 0.5 {
            score += 0.15
        } else if sizeRatio < 0.7 {
            score += 0.1
        }

        // Popularity/quality signal (0-0.2)
        let popularityScore = min(1.0, Double(model.downloads) / 100000.0)
        score += 0.2 * popularityScore

        // Benchmark scores (0-0.2)
        if let benchmarks = model.benchmarks {
            let avgBenchmark = (benchmarks.mmlu + benchmarks.humanEval + benchmarks.gsm8k) / 300.0
            score += 0.2 * avgBenchmark
        }

        return min(1.0, score)
    }

    private func generateRecommendationReasons(model: DiscoveredModel, topTasks: [TaskType: Double]) -> [String] {
        var reasons: [String] = []

        // Task match reasons
        for (task, weight) in topTasks where weight > 0.2 {
            if model.capabilities.contains(mapTaskToCapability(task)) {
                reasons.append("Great for \(task.displayName.lowercased()) tasks")
            }
        }

        // Size reason
        if model.estimatedSizeGB < 4.0 {
            reasons.append("Compact size - runs efficiently")
        }

        // Benchmark reasons
        if let benchmarks = model.benchmarks {
            if benchmarks.humanEval > 70 {
                reasons.append("Excellent coding performance (HumanEval: \(Int(benchmarks.humanEval))%)")
            }
            if benchmarks.mmlu > 70 {
                reasons.append("Strong general knowledge (MMLU: \(Int(benchmarks.mmlu))%)")
            }
        }

        // Popularity
        if model.downloads > 50000 {
            reasons.append("Popular choice with \(formatNumber(model.downloads)) downloads")
        }

        return Array(reasons.prefix(3))
    }

    private func determinePriority(score: Double) -> RecommendationPriority {
        if score > 0.8 { .high } else if score > 0.6 { .medium } else { .low }
    }

    private func mapTaskToCapability(_ task: TaskType) -> LocalModelCapability {
        switch task {
        case .codeGeneration, .debugging, .appDevelopment:
            .code
        case .complexReasoning, .mathLogic, .analysis:
            .reasoning
        case .creativeWriting, .contentCreation:
            .creative
        case .summarization, .factual, .informationRetrieval:
            .chat
        default:
            .chat
        }
    }

    // MARK: - Monitoring

    private var monitoringTask: Task<Void, Never>?

    private func startMonitoring() {
        guard configuration.enableAutoDiscovery else { return }

        monitoringTask?.cancel()
        monitoringTask = Task {
            while !Task.isCancelled {
                let intervalSeconds = configuration.scanIntervalHours * 3600
                try? await Task.sleep(for: .seconds(intervalSeconds))

                await scanInstalledModels()
                await discoverAvailableModels()
                await generateRecommendations()
            }
        }
    }

    func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
    }

    // MARK: - User Profile

    /// Record user activity to improve recommendations
    func recordUserActivity(taskType: TaskType) {
        userProfile.recordTask(taskType)
        saveUserProfile()

        // Regenerate recommendations periodically
        Task {
            await generateRecommendations()
        }
    }

    // MARK: - Configuration

    func updateConfiguration(_ config: Configuration) {
        configuration = config
        saveConfiguration()

        if config.enableAutoDiscovery {
            startMonitoring()
        } else {
            stopMonitoring()
        }
    }

    private func loadConfiguration() {
        if let data = UserDefaults.standard.data(forKey: "LocalModelRecommendation.config"),
           let config = try? JSONDecoder().decode(Configuration.self, from: data) {
            configuration = config
        }
    }

    private func saveConfiguration() {
        if let data = try? JSONEncoder().encode(configuration) {
            UserDefaults.standard.set(data, forKey: "LocalModelRecommendation.config")
        }
    }

    private func loadUserProfile() {
        if let data = UserDefaults.standard.data(forKey: "LocalModelRecommendation.userProfile"),
           let profile = try? JSONDecoder().decode(UserUsageProfile.self, from: data) {
            userProfile = profile
        }
    }

    private func saveUserProfile() {
        if let data = try? JSONEncoder().encode(userProfile) {
            UserDefaults.standard.set(data, forKey: "LocalModelRecommendation.userProfile")
        }
    }

    private func saveLastScanDate() {
        UserDefaults.standard.set(lastScanDate, forKey: "LocalModelRecommendation.lastScan")
    }

    // MARK: - Helper Methods

    private func calculateDirectorySize(url: URL) -> UInt64 {
        let fileManager = FileManager.default
        var totalSize: UInt64 = 0

        if let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator {
                if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += UInt64(size)
                }
            }
        }

        return totalSize
    }

    private func detectQuantization(_ url: URL) -> String? {
        let name = url.lastPathComponent.lowercased()
        if name.contains("4bit") || name.contains("q4") { return "4-bit" }
        if name.contains("8bit") || name.contains("q8") { return "8-bit" }
        if name.contains("fp16") { return "FP16" }
        return nil
    }

    private func detectCapabilities(_ url: URL) -> [LocalModelCapability] {
        let name = url.lastPathComponent.lowercased()
        var capabilities: [LocalModelCapability] = [.chat]

        if name.contains("code") || name.contains("coder") {
            capabilities.append(.code)
        }
        if name.contains("instruct") {
            capabilities.append(.reasoning)
        }
        if name.contains("vision") || name.contains("vlm") {
            capabilities.append(.vision)
        }

        return capabilities
    }

    private func parseOllamaCapabilities(_ model: OllamaModel) -> [LocalModelCapability] {
        var caps: [LocalModelCapability] = [.chat]
        let name = model.name.lowercased()

        if name.contains("code") { caps.append(.code) }
        if name.contains("vision") { caps.append(.vision) }
        if model.details?.families?.contains("llama") == true { caps.append(.reasoning) }

        return caps
    }

    private func extractModelName(from id: String) -> String {
        // Extract clean name from "mlx-community/Llama-3.2-1B-Instruct-4bit"
        let parts = id.split(separator: "/")
        let name = parts.last.map(String.init) ?? id
        return name
            .replacingOccurrences(of: "-4bit", with: "")
            .replacingOccurrences(of: "-8bit", with: "")
            .replacingOccurrences(of: "-", with: " ")
    }

    private func estimateModelSize(_ model: HuggingFaceModel) -> Double {
        // Estimate based on name hints or default
        let name = (model.modelId ?? "").lowercased()
        if name.contains("1b") { return 1.5 }
        if name.contains("3b") { return 3.5 }
        if name.contains("7b") { return 4.5 }
        if name.contains("8b") { return 5.0 }
        if name.contains("13b") { return 8.0 }
        return 4.0 // Default estimate
    }

    private func detectQuantizationFromName(_ name: String) -> String? {
        let lower = name.lowercased()
        if lower.contains("4bit") || lower.contains("q4") { return "4-bit" }
        if lower.contains("8bit") || lower.contains("q8") { return "8-bit" }
        if lower.contains("fp16") { return "FP16" }
        return nil
    }

    private func detectCapabilitiesFromTags(_ tags: [String]) -> [LocalModelCapability] {
        var caps: [LocalModelCapability] = []

        for tag in tags {
            let lower = tag.lowercased()
            if lower.contains("text-generation") || lower.contains("conversational") {
                caps.append(.chat)
            }
            if lower.contains("code") {
                caps.append(.code)
            }
            if lower.contains("vision") || lower.contains("image") {
                caps.append(.vision)
            }
        }

        if caps.isEmpty { caps.append(.chat) }
        return caps
    }

    private func formatNumber(_ num: Int) -> String {
        if num >= 1000000 {
            return String(format: "%.1fM", Double(num) / 1000000)
        } else if num >= 1000 {
            return String(format: "%.1fK", Double(num) / 1000)
        }
        return "\(num)"
    }
}

// MARK: - Supporting Types

struct InstalledLocalModel: Identifiable, Sendable {
    let id: UUID
    let name: String
    let source: LocalModelSource
    let path: String
    let sizeBytes: UInt64
    let quantization: String?
    let capabilities: [LocalModelCapability]
    let installedDate: Date

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(sizeBytes), countStyle: .file)
    }
}

struct DiscoveredModel: Identifiable, Sendable {
    let id: String
    let name: String
    let source: LocalModelSource
    let author: String
    let description: String?
    let downloads: Int
    let likes: Int
    let estimatedSizeGB: Double
    let quantization: String?
    let capabilities: [LocalModelCapability]
    let benchmarks: ModelBenchmarks?
    let lastUpdated: Date
    let downloadURL: String
}

struct ModelRecommendation: Identifiable, Sendable {
    var id: String { model.id }
    let model: DiscoveredModel
    let score: Double
    let reasons: [String]
    let priority: RecommendationPriority
}

struct ModelBenchmarks: Sendable {
    let mmlu: Double       // General knowledge
    let humanEval: Double  // Coding
    let gsm8k: Double      // Math reasoning
}

struct UserUsageProfile: Codable, Sendable {
    var taskDistribution: [TaskType: Double] = [:]
    var totalTasks: Int = 0
    var lastActivityDate: Date?

    mutating func recordTask(_ type: TaskType) {
        totalTasks += 1
        let current = taskDistribution[type] ?? 0
        taskDistribution[type] = current + 1

        // Normalize to percentages
        for (key, value) in taskDistribution {
            taskDistribution[key] = value / Double(totalTasks)
        }

        lastActivityDate = Date()
    }
}

struct SystemCapabilities: Sendable {
    let totalMemoryGB: Double
    let availableMemoryGB: Double
    let hasGPU: Bool
    let isAppleSilicon: Bool
}

enum LocalModelSource: String, Codable, Sendable {
    case mlx
    case ollama
    case huggingFace
    case ollamaLibrary
}

enum LocalModelCapability: String, Codable, Sendable, CaseIterable {
    case chat
    case code
    case reasoning
    case vision
    case multilingual
    case creative
}

enum RecommendationPriority: String, Codable, Sendable {
    case high
    case medium
    case low
}

// MARK: - API Response Models

struct OllamaTagsResponse: Codable {
    let models: [OllamaModel]
}

struct OllamaModel: Codable {
    let name: String
    let modifiedAt: String
    let size: UInt64
    let digest: String?
    let details: OllamaModelDetails?

    enum CodingKeys: String, CodingKey {
        case name
        case modifiedAt = "modified_at"
        case size
        case digest
        case details
    }
}

struct OllamaModelDetails: Codable {
    let format: String?
    let family: String?
    let families: [String]?
    let parameterSize: String?
    let quantizationLevel: String?

    enum CodingKeys: String, CodingKey {
        case format
        case family
        case families
        case parameterSize = "parameter_size"
        case quantizationLevel = "quantization_level"
    }
}

struct HuggingFaceModel: Codable {
    let modelId: String?
    let author: String?
    let description: String?
    let downloads: Int?
    let likes: Int?
    let tags: [String]?
    let lastModified: String?

    enum CodingKeys: String, CodingKey {
        case modelId = "id"
        case author
        case description
        case downloads
        case likes
        case tags
        case lastModified
    }
}
