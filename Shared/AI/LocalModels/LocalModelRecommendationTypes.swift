//
//  LocalModelRecommendationTypes.swift
//  Thea
//
//  Supporting types for local model recommendation engine
//  Extracted from LocalModelRecommendationEngine.swift for better code organization
//

import Foundation

// MARK: - Installed Model

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

// MARK: - Discovered Model

struct DiscoveredModel: Identifiable, Sendable {
    let id: String
    let name: String
    let source: LocalModelSource
    let author: String
    let description: String?
    // periphery:ignore - Reserved: source property reserved for future feature activation
    // periphery:ignore - Reserved: path property reserved for future feature activation
    let downloads: Int
    // periphery:ignore - Reserved: quantization property reserved for future feature activation
    // periphery:ignore - Reserved: capabilities property reserved for future feature activation
    // periphery:ignore - Reserved: installedDate property reserved for future feature activation
    let likes: Int
    // periphery:ignore - Reserved: formattedSize property reserved for future feature activation
    let estimatedSizeGB: Double
    let quantization: String?
    let capabilities: [LocalModelCapability]
    let benchmarks: ModelBenchmarks?
    let lastUpdated: Date
    let downloadURL: String
}

// MARK: - Model Recommendation

// periphery:ignore - Reserved: source property reserved for future feature activation

// periphery:ignore - Reserved: author property reserved for future feature activation

// periphery:ignore - Reserved: description property reserved for future feature activation

// periphery:ignore - Reserved: likes property reserved for future feature activation
struct ModelRecommendation: Identifiable, Sendable {
    // periphery:ignore - Reserved: quantization property reserved for future feature activation
    var id: String { model.id }
    let model: DiscoveredModel
    // periphery:ignore - Reserved: lastUpdated property reserved for future feature activation
    // periphery:ignore - Reserved: downloadURL property reserved for future feature activation
    let score: Double
    let reasons: [String]
    let priority: RecommendationPriority
}

// MARK: - Model Benchmarks

struct ModelBenchmarks: Sendable {
    let mmlu: Double       // General knowledge
    let humanEval: Double  // Coding
    let gsm8k: Double      // Math reasoning
}

// MARK: - User Usage Profile

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
            // periphery:ignore - Reserved: recordTask(_:) instance method reserved for future feature activation
            taskDistribution[key] = value / Double(totalTasks)
        }

        lastActivityDate = Date()
    }
}

// MARK: - System Capabilities

struct SystemCapabilities: Sendable {
    let totalMemoryGB: Double
    let availableMemoryGB: Double
    let hasGPU: Bool
    let isAppleSilicon: Bool
    let gpuCores: Int
    let neuralEngineTOPS: Double
    let recommendedMaxModelGB: Double
}

// periphery:ignore - Reserved: hasGPU property reserved for future feature activation

// periphery:ignore - Reserved: isAppleSilicon property reserved for future feature activation

// periphery:ignore - Reserved: gpuCores property reserved for future feature activation

// periphery:ignore - Reserved: neuralEngineTOPS property reserved for future feature activation

// periphery:ignore - Reserved: recommendedMaxModelGB property reserved for future feature activation

// MARK: - System Hardware Profile

struct SystemHardwareProfile: Sendable {
    let totalMemoryGB: Double
    let cpuCores: Int
    // periphery:ignore - Reserved: cpuCores property reserved for future feature activation
    let chipType: AppleSiliconChip
    let gpuCores: Int
    let neuralEngineCapability: NeuralEngineCapability
    let thermalState: LocalThermalState
    let batteryPowered: Bool
}

// MARK: - Apple Silicon Chip

enum AppleSiliconChip: String, Codable, Sendable {
    // M-series (Mac/iPad Pro)
    case m1 = "M1"
    case m1Pro = "M1 Pro"
    case m1Max = "M1 Max"
    case m1Ultra = "M1 Ultra"
    case m2 = "M2"
    case m2Pro = "M2 Pro"
    case m2Max = "M2 Max"
    case m2Ultra = "M2 Ultra"
    case m3 = "M3"
    case m3Pro = "M3 Pro"
    case m3Max = "M3 Max"
    case m3Ultra = "M3 Ultra"
    case m4 = "M4"
    case m4Pro = "M4 Pro"
    case m4Max = "M4 Max"
    case m4Ultra = "M4 Ultra"
    // A-series (iPhone/iPad/Apple TV)
    case a14 = "A14 Bionic"
    case a15 = "A15 Bionic"
    case a16 = "A16 Bionic"
    case a17Pro = "A17 Pro"
    case a18 = "A18"
    case a18Pro = "A18 Pro"
    // S-series (Apple Watch)
    case s9 = "S9"
    case s10 = "S10"
    case unknown = "Unknown"

    var displayName: String { rawValue }

    var generation: Int {
        switch self {
        case .m1, .m1Pro, .m1Max, .m1Ultra: 1
        case .m2, .m2Pro, .m2Max, .m2Ultra: 2
        case .m3, .m3Pro, .m3Max, .m3Ultra: 3
        case .m4, .m4Pro, .m4Max, .m4Ultra: 4
        case .a14, .a15, .a16: 0 // A-series uses different numbering
        case .a17Pro, .a18, .a18Pro: 0
        case .s9, .s10: 0
        case .unknown: 0
        }
    }

    /// Whether this chip supports on-device AI models
    var supportsLocalModels: Bool {
        switch self {
        case .m1, .m1Pro, .m1Max, .m1Ultra,
             .m2, .m2Pro, .m2Max, .m2Ultra,
             .m3, .m3Pro, .m3Max, .m3Ultra,
             .m4, .m4Pro, .m4Max, .m4Ultra:
            true // All M-series support local models
        case .a17Pro, .a18, .a18Pro:
            true // A17 Pro+ supports on-device LLMs
        case .a14, .a15, .a16:
            false // Older A-series: limited to Core ML
        case .s9, .s10:
            false // Apple Watch: too constrained
        case .unknown:
            false
        }
    }

    /// Maximum recommended model size for this chip (in GB)
    var maxRecommendedModelSizeGB: Double {
        switch self {
        case .m4Ultra: 100.0
        case .m4Max, .m3Ultra: 50.0
        case .m4Pro, .m3Max, .m2Ultra: 30.0
        case .m4, .m3Pro, .m2Max, .m1Ultra: 20.0
        case .m3, .m2Pro, .m1Max: 15.0
        case .m2, .m1Pro: 10.0
        case .m1: 8.0
        case .a18Pro, .a18: 4.0 // iPhone 16 Pro
        case .a17Pro: 3.0 // iPhone 15 Pro
        case .a14, .a15, .a16: 1.0 // Limited Core ML only
        case .s9, .s10: 0.0 // Not suitable for LLMs
        case .unknown: 4.0
        }
    }
}

// MARK: - Neural Engine Capability

enum NeuralEngineCapability: String, Codable, Sendable {
    case generation2 = "Gen 2 (11 TOPS)"
    case generation3 = "Gen 3 (15.8 TOPS)"
    case generation4 = "Gen 4 (18 TOPS)"
    case generation5 = "Gen 5 (38 TOPS)"
    case unknown = "Unknown"
}

// MARK: - Thermal State

enum LocalThermalState: String, Codable, Sendable {
    case nominal
    case fair
    case serious
    case critical
}

// MARK: - System Capability Summary

// periphery:ignore - Reserved: SystemCapabilitySummary type reserved for future feature activation
struct SystemCapabilitySummary: Sendable {
    let tierName: String
    let maxModelSize: String
    let chipDescription: String
    let memoryDescription: String
    let recommendation: String
}

// MARK: - Model Source

enum LocalModelSource: String, Codable, Sendable {
    case mlx
    case ollama
    case huggingFace
    case ollamaLibrary
}

// MARK: - Model Capability

enum LocalModelCapability: String, Codable, Sendable, CaseIterable {
    case chat
    case code
    case reasoning
    case vision
    case multilingual
    case creative
}

// MARK: - Recommendation Priority

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
