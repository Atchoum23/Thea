// SystemCapabilityService.swift
// Thea
//
// Centralized runtime device introspection for hardware-aware configuration.
// All hardware queries happen once in init() — read-only after that.
//
// Design: @MainActor @Observable final class singleton.
// NOT an actor — all consumers (routers, views) are @MainActor.
// Read-only after init(), no concurrency issues.
//
// CREATED: February 2026

import Foundation
import OSLog

// MARK: - Chip Family

/// Apple Silicon chip family detected at runtime
public enum ChipFamily: String, Sendable {
    case m1 = "M1"
    case m2 = "M2"
    case m3 = "M3"
    case m4 = "M4"
    case aSeries = "A-Series"
    case intel = "Intel"
    case unknown = "Unknown"

    /// Whether this chip is M3 or newer generation
    public var isM3OrNewer: Bool {
        switch self {
        case .m3, .m4: return true
        default: return false
        }
    }

    /// Relative performance tier (higher = faster)
    public var performanceTier: Int {
        switch self {
        case .intel: return 1
        case .aSeries: return 2
        case .m1: return 3
        case .m2: return 4
        case .m3: return 5
        case .m4: return 6
        case .unknown: return 3
        }
    }
}

// MARK: - System Capability Service

/// Centralized runtime device introspection. All hardware queries happen once in init().
/// Provides system-aware recommendations for model loading, token limits, batch sizes, and budgets.
@MainActor
@Observable
public final class SystemCapabilityService {
    public static let shared = SystemCapabilityService()

    private let logger = Logger(subsystem: "com.thea.intelligence", category: "SystemCapability")

    // MARK: - Hardware Properties (computed once at init)

    /// Total physical RAM in GB
    public let physicalMemoryGB: Double

    /// Number of performance (efficiency excluded) CPU cores
    public let performanceCoreCount: Int

    /// Detected chip family
    public let chipFamily: ChipFamily

    /// Whether this is an Apple Silicon (arm64) device
    public let isAppleSilicon: Bool

    // MARK: - Derived Capabilities

    /// Maximum local model size that can be safely loaded (GB).
    /// Uses ~50% of physical RAM to leave headroom for the OS and app.
    public var maxLocalModelGB: Double {
        physicalMemoryGB * 0.50
    }

    /// Recommended embedding batch size for semantic search indexing.
    /// Scales with available RAM: more RAM → larger batches → faster indexing.
    public var embeddingBatchSize: Int {
        if physicalMemoryGB >= 64 { return 50 }
        if physicalMemoryGB >= 32 { return 30 }
        if physicalMemoryGB >= 16 { return 20 }
        return 10
    }

    /// Maximum number of MLX chat sessions to keep cached (LRU).
    /// More RAM allows caching more concurrent conversations.
    public var maxMLXCachedSessions: Int {
        if physicalMemoryGB >= 128 { return 30 }
        if physicalMemoryGB >= 64 { return 20 }
        if physicalMemoryGB >= 32 { return 12 }
        if physicalMemoryGB >= 16 { return 8 }
        return 5
    }

    /// Recommended daily API budget in USD based on device capability tier.
    /// High-RAM machines (MSM3U) can use more local models, reducing cloud cost.
    public var recommendedDailyBudget: Double {
        if physicalMemoryGB >= 128 { return 15.0 }
        if physicalMemoryGB >= 64 { return 10.0 }
        if physicalMemoryGB >= 32 { return 7.5 }
        return 5.0
    }

    /// Optimal cache size for config/result caching (item count).
    public var optimalCacheSize: Int {
        if physicalMemoryGB >= 64 { return 1000 }
        if physicalMemoryGB >= 32 { return 500 }
        if physicalMemoryGB >= 16 { return 200 }
        return 100
    }

    // MARK: - Model-Specific Recommendations

    /// Check whether a local model can be safely loaded without OOM risk.
    /// - Parameter model: The AI model to check.
    /// - Returns: `true` if the estimated memory footprint fits within the safe local budget.
    public func canRunLocalModel(_ model: AIModel) -> Bool {
        guard model.isLocal else { return true } // Cloud models always "can run"
        guard let estimatedGB = model.estimatedMemoryGB else {
            // Unknown memory requirement — allow if we have 16+ GB headroom
            return physicalMemoryGB >= 16
        }
        return estimatedGB <= maxLocalModelGB
    }

    /// Recommended maximum output tokens for a model, scaled to the model's capabilities.
    /// - Parameter model: The AI model.
    /// - Returns: Recommended max output tokens, capped at the model's hard limit.
    public func recommendedMaxTokens(for model: AIModel) -> Int {
        let modelMax = model.maxOutputTokens

        if model.isLocal {
            // For local models, be conservative to avoid OOM during generation
            if physicalMemoryGB >= 64 {
                return min(modelMax, 8192)
            }
            return min(modelMax, 4096)
        }

        // Cloud models: scale with model capability
        if modelMax >= 64_000 {
            return physicalMemoryGB >= 64 ? 16_384 : 8192
        }
        if modelMax >= 32_000 {
            return physicalMemoryGB >= 32 ? 8192 : 4096
        }
        return min(modelMax, 4096)
    }

    /// Recommended tokens to reserve for the model's response (context window budgeting).
    /// - Parameter model: The AI model.
    /// - Returns: Token count to reserve for the response.
    public func recommendedReservedForResponse(for model: AIModel) -> Int {
        if model.isLocal {
            return 2048
        }
        if model.maxOutputTokens >= 64_000 {
            return 8192
        }
        if model.maxOutputTokens >= 16_000 {
            return 4096
        }
        return 2048
    }

    /// Recommended request timeout for a model.
    /// Local large models need more time; fast cloud models can timeout sooner.
    /// - Parameter model: The AI model.
    /// - Returns: Timeout in seconds.
    public func recommendedTimeout(for model: AIModel) -> TimeInterval {
        if model.isLocal {
            // Large local models (70B+) need extra time on slower machines
            if let estimatedGB = model.estimatedMemoryGB, estimatedGB > 40 {
                return physicalMemoryGB >= 64 ? 90 : 180
            }
            return 120
        }
        // Cloud models: generous timeout for reasoning models
        if model.capabilities.contains(.reasoning) {
            return 60
        }
        return 30
    }

    // MARK: - Adaptive Failure Handling

    /// Recommended max consecutive failures before cooling down a fallback tier.
    /// High-RAM machines can tolerate more retries (more memory = more concurrent resilience).
    public var recommendedMaxConsecutiveFailures: Int {
        physicalMemoryGB >= 64 ? 5 : 3
    }

    /// Recommended cooldown seconds after repeated failures.
    /// Newer chips recover faster so shorter cooldowns are appropriate.
    public var recommendedFailureCooldownSeconds: TimeInterval {
        chipFamily.isM3OrNewer ? 180 : 300
    }

    // MARK: - Initialization

    private init() {
        let memBytes = ProcessInfo.processInfo.physicalMemory
        physicalMemoryGB = Double(memBytes) / 1_073_741_824

        #if arch(arm64)
        isAppleSilicon = true
        chipFamily = Self.detectAppleSiliconChip()
        // arm64 macs report all cores; use processorCount as proxy for performance cores
        performanceCoreCount = ProcessInfo.processInfo.processorCount
        #else
        isAppleSilicon = false
        chipFamily = .intel
        performanceCoreCount = ProcessInfo.processInfo.processorCount
        #endif

        let logger = Logger(subsystem: "com.thea.intelligence", category: "SystemCapability")
        logger.info("""
            SystemCapabilityService initialized: \
            \(String(format: "%.0f", self.physicalMemoryGB))GB RAM, \
            chip=\(self.chipFamily.rawValue), \
            cores=\(self.performanceCoreCount), \
            maxLocalModel=\(String(format: "%.0f", self.maxLocalModelGB))GB, \
            embeddingBatch=\(self.embeddingBatchSize), \
            mlxSessions=\(self.maxMLXCachedSessions)
            """)
    }

    // MARK: - Chip Detection

    /// Detect the Apple Silicon chip family from sysctl brand string.
    private static func detectAppleSiliconChip() -> ChipFamily {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        guard size > 0 else { return .unknown }

        var brand = [CChar](repeating: 0, count: size)
        guard sysctlbyname("machdep.cpu.brand_string", &brand, &size, nil, 0) == 0 else {
            return .unknown
        }
        // Truncate null terminator then decode as UTF-8 (String(cString:) deprecated)
        let trimmedBrand = brand.prefix(while: { $0 != 0 }).map(UInt8.init)
        let brandString = String(decoding: trimmedBrand, as: UTF8.self)

        if brandString.contains("M4") { return .m4 }
        if brandString.contains("M3") { return .m3 }
        if brandString.contains("M2") { return .m2 }
        if brandString.contains("M1") { return .m1 }
        if brandString.contains("Apple A") { return .aSeries }

        // Fallback: check processorCount heuristic
        // M3 Ultra: 60 cores, M2 Ultra: 48 cores, M3 Pro: 18, M2 Pro: 12, etc.
        let coreCount = ProcessInfo.processInfo.processorCount
        if coreCount >= 32 { return .m3 } // Ultra/Max tier
        if coreCount >= 20 { return .m2 }
        if coreCount >= 10 { return .m1 }
        return .aSeries
    }
}

// MARK: - AIModel Memory Estimation

public extension AIModel {
    /// Heuristic estimated memory footprint in GB for local models.
    /// Based on model ID patterns (parameter count × bits per weight).
    /// Returns `nil` for cloud models or unknown local models.
    var estimatedMemoryGB: Double? {
        guard isLocal else { return nil }

        let lowID = id.lowercased()

        // Explicit size indicators in model IDs
        if lowID.contains("120b") { return 70.0 }   // 120B at 4-bit ≈ 60-80GB
        if lowID.contains("70b") { return 40.0 }    // 70B at 4-bit ≈ 35-45GB
        if lowID.contains("32b") { return 18.0 }    // 32B at 4-bit ≈ 16-20GB
        if lowID.contains("20b") { return 11.0 }    // 20B at 4-bit ≈ 10-12GB
        if lowID.contains("13b") { return 8.0 }     // 13B at 4-bit ≈ 7-9GB
        if lowID.contains("8b") { return 5.0 }      // 8B at 4-bit ≈ 4-6GB
        if lowID.contains("7b") { return 4.5 }      // 7B at 4-bit ≈ 4-5GB
        if lowID.contains("4b") { return 2.5 }      // 4B at 4-bit ≈ 2-3GB
        if lowID.contains("3b") { return 2.0 }      // 3B at 4-bit ≈ 1.5-2.5GB
        if lowID.contains("1b") { return 0.8 }      // 1B at 4-bit ≈ 0.5-1GB

        // Named models with known sizes
        if lowID.contains("gpt-oss-20b") { return 11.0 }
        if lowID.contains("gpt-oss-120b") { return 70.0 }
        if lowID.contains("qwen3-vl-8b") { return 5.0 }
        if lowID.contains("gemma-3-4b") { return 2.5 }
        if lowID.contains("gemma-3-1b") { return 0.8 }

        // Generic local model — unknown size
        return nil
    }
}
