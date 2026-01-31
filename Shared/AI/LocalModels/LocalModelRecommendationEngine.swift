// LocalModelRecommendationEngine.swift
// AI-powered local model monitoring, discovery, and recommendation system
// Features system-aware intelligent defaults based on hardware capabilities

import Foundation
#if os(macOS)
import IOKit.ps
#elseif os(iOS) || os(watchOS) || os(tvOS)
import UIKit
#endif

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

    // Configuration - AI-powered with system-aware defaults
    struct Configuration: Codable, Sendable {
        var enableAutoDiscovery = true
        var scanIntervalHours: Int = 24
        var enableProactiveRecommendations = true
        var maxRecommendations = 5
        var preferredQuantization: String = "4bit"
        var maxModelSizeGB: Double = 8.0 // Will be overridden by system-aware calculation
        var preferredSources: [String] = ["mlx-community", "huggingface"]
        var enableAIPoweredScoring = true
        var autoAdjustToSystemCapabilities = true
        var performanceTier: PerformanceTier = .auto

        /// Model performance tiers based on system capabilities
        enum PerformanceTier: String, Codable, Sendable, CaseIterable {
            case auto          // AI determines best tier
            case ultralight    // 1-3GB models (8GB RAM systems)
            case light         // 3-5GB models (16GB RAM systems)
            case standard      // 5-10GB models (32GB RAM systems)
            case performance   // 10-20GB models (64GB RAM systems)
            case extreme       // 20-50GB+ models (128GB+ RAM systems)
            case unlimited     // No size restrictions (256GB+ systems)

            var displayName: String {
                switch self {
                case .auto: "Auto (AI-Selected)"
                case .ultralight: "Ultra Light (1-3GB)"
                case .light: "Light (3-5GB)"
                case .standard: "Standard (5-10GB)"
                case .performance: "Performance (10-20GB)"
                case .extreme: "Extreme (20-50GB)"
                case .unlimited: "Unlimited (50GB+)"
                }
            }

            var maxModelSizeGB: Double {
                switch self {
                case .auto: 0 // Calculated dynamically
                case .ultralight: 3.0
                case .light: 5.0
                case .standard: 10.0
                case .performance: 20.0
                case .extreme: 50.0
                case .unlimited: Double.greatestFiniteMagnitude // No limit
                }
            }
        }
    }

    private(set) var configuration = Configuration()
    private(set) var systemProfile: SystemHardwareProfile?

    // MARK: - Initialization

    private init() {
        loadConfiguration()
        loadUserProfile()
        Task {
            await detectSystemHardware()
            await applySystemAwareDefaults()
            await initialScan()
            startMonitoring()
        }
    }

    // MARK: - System Hardware Detection (AI-Powered)

    /// Detect and profile the system hardware for optimal model recommendations
    private func detectSystemHardware() async {
        let memory = ProcessInfo.processInfo.physicalMemory
        let memoryGB = Double(memory) / 1_073_741_824
        let cpuCores = ProcessInfo.processInfo.processorCount

        // Detect Apple Silicon chip type
        let chipType = detectAppleSiliconChip()

        // Estimate Neural Engine and GPU capabilities
        let neuralEngineCapability = estimateNeuralEngineCapability(chip: chipType)
        let gpuCores = estimateGPUCores(chip: chipType)

        systemProfile = SystemHardwareProfile(
            totalMemoryGB: memoryGB,
            cpuCores: cpuCores,
            chipType: chipType,
            gpuCores: gpuCores,
            neuralEngineCapability: neuralEngineCapability,
            thermalState: .nominal as LocalThermalState,
            batteryPowered: detectBatteryPower()
        )

        print("[LocalModelRecommendationEngine] System profile: \(memoryGB)GB RAM, \(chipType.rawValue), \(gpuCores) GPU cores, Neural Engine: \(neuralEngineCapability.rawValue)")
    }

    /// Apply AI-powered defaults based on detected system capabilities
    private func applySystemAwareDefaults() async {
        guard configuration.autoAdjustToSystemCapabilities,
              let profile = systemProfile else { return }

        // Calculate optimal max model size based on available RAM
        // Reserve ~30% of RAM for system and ~20% for app overhead
        // Only ~50% of RAM should be used for model weights
        let effectiveRAM = profile.totalMemoryGB * 0.5

        let tier: Configuration.PerformanceTier
        let maxSize: Double

        switch profile.totalMemoryGB {
        case 0..<12:
            tier = .ultralight
            maxSize = min(effectiveRAM, 3.0)
        case 12..<24:
            tier = .light
            maxSize = min(effectiveRAM, 5.0)
        case 24..<48:
            tier = .standard
            maxSize = min(effectiveRAM, 10.0)
        case 48..<96:
            tier = .performance
            maxSize = min(effectiveRAM, 20.0)
        case 96..<192:
            tier = .extreme
            maxSize = min(effectiveRAM, 50.0)
        case 192..<384:
            // 192GB-384GB RAM systems (e.g., M2 Ultra, M3 Ultra, M4 Ultra with 192GB)
            tier = .unlimited
            maxSize = min(effectiveRAM, 150.0)
        case 384..<768:
            // 384GB-768GB RAM systems (future high-end workstations)
            tier = .unlimited
            maxSize = min(effectiveRAM, 300.0)
        default:
            // 768GB+ RAM systems (future extreme systems)
            tier = .unlimited
            maxSize = effectiveRAM // No cap - use all available
        }

        // Apply the calculated defaults if not manually overridden
        if configuration.performanceTier == .auto {
            configuration.maxModelSizeGB = maxSize
            print("[LocalModelRecommendationEngine] AI-selected tier: \(tier.displayName), max model size: \(String(format: "%.1f", maxSize))GB")
        } else {
            // User has manually selected a tier
            configuration.maxModelSizeGB = configuration.performanceTier.maxModelSizeGB
        }

        // Adjust quantization preference based on memory
        if profile.totalMemoryGB < 16 {
            configuration.preferredQuantization = "4bit"
        } else if profile.totalMemoryGB < 64 {
            configuration.preferredQuantization = "4bit" // Still prefer 4bit for efficiency
        } else {
            configuration.preferredQuantization = "8bit" // Can afford higher precision
        }

        saveConfiguration()
    }

    private func detectAppleSiliconChip() -> AppleSiliconChip {
        #if os(macOS)
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var brand = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &brand, &size, nil, 0)
        let cpuBrand = String(cString: brand).lowercased()

        if cpuBrand.contains("m4 ultra") { return .m4Ultra }
        if cpuBrand.contains("m4 max") { return .m4Max }
        if cpuBrand.contains("m4 pro") { return .m4Pro }
        if cpuBrand.contains("m4") { return .m4 }
        if cpuBrand.contains("m3 ultra") { return .m3Ultra }
        if cpuBrand.contains("m3 max") { return .m3Max }
        if cpuBrand.contains("m3 pro") { return .m3Pro }
        if cpuBrand.contains("m3") { return .m3 }
        if cpuBrand.contains("m2 ultra") { return .m2Ultra }
        if cpuBrand.contains("m2 max") { return .m2Max }
        if cpuBrand.contains("m2 pro") { return .m2Pro }
        if cpuBrand.contains("m2") { return .m2 }
        if cpuBrand.contains("m1 ultra") { return .m1Ultra }
        if cpuBrand.contains("m1 max") { return .m1Max }
        if cpuBrand.contains("m1 pro") { return .m1Pro }
        if cpuBrand.contains("m1") { return .m1 }
        return .unknown
        #elseif os(iOS)
        // iOS device detection via memory and CPU core count
        return detectIOSChip()
        #elseif os(watchOS)
        return .unknown // watchOS chips are different (S-series)
        #elseif os(tvOS)
        return detectTVOSChip()
        #else
        return .unknown
        #endif
    }

    #if os(iOS)
    private func detectIOSChip() -> AppleSiliconChip {
        // Detect A-series and M-series chips in iPads/iPhones via RAM + cores
        let memoryGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        let cores = ProcessInfo.processInfo.processorCount

        // iPad Pro M4 (2024): 8GB-16GB RAM, 9-10 cores
        // iPad Pro M2 (2022): 8GB-16GB RAM, 8 cores
        // iPad Pro M1 (2021): 8GB-16GB RAM, 8 cores
        // iPhone 16 Pro: A18 Pro, 8GB RAM, 6 cores
        // iPhone 15 Pro: A17 Pro, 8GB RAM, 6 cores

        if memoryGB >= 12 && cores >= 9 { return .m4 }
        if memoryGB >= 8 && cores >= 8 { return .m2 }
        if memoryGB >= 6 && cores >= 6 { return .a17Pro }
        if memoryGB >= 6 { return .a16 }
        return .unknown
    }
    #endif

    #if os(tvOS)
    private func detectTVOSChip() -> AppleSiliconChip {
        // Apple TV chips
        let cores = ProcessInfo.processInfo.processorCount
        if cores >= 6 { return .a15 }
        return .unknown
    }
    #endif

    private func estimateNeuralEngineCapability(chip: AppleSiliconChip) -> NeuralEngineCapability {
        switch chip {
        case .m4Ultra, .m4Max, .m4Pro, .m4, .a18Pro, .a18:
            .generation5 // 38 TOPS (M4), 35 TOPS (A18)
        case .m3Ultra, .m3Max, .m3Pro, .m3, .a17Pro:
            .generation4 // 18 TOPS (M3), 35 TOPS (A17 Pro)
        case .m2Ultra, .m2Max, .m2Pro, .m2, .a16:
            .generation3 // 15.8 TOPS
        case .m1Ultra, .m1Max, .m1Pro, .m1, .a15:
            .generation2 // 11 TOPS (M1), 15.8 TOPS (A15)
        case .a14:
            .generation2 // 11 TOPS
        case .s9, .s10:
            .generation4 // S9/S10 have capable Neural Engines
        case .unknown:
            .unknown
        }
    }

    private func estimateGPUCores(chip: AppleSiliconChip) -> Int {
        switch chip {
        // M-series (Mac)
        case .m4Ultra: 80
        case .m4Max: 40
        case .m4Pro: 20
        case .m4: 10
        case .m3Ultra: 76
        case .m3Max: 40
        case .m3Pro: 18
        case .m3: 10
        case .m2Ultra: 76
        case .m2Max: 38
        case .m2Pro: 19
        case .m2: 10
        case .m1Ultra: 64
        case .m1Max: 32
        case .m1Pro: 16
        case .m1: 8
        // A-series (iPhone/iPad)
        case .a18Pro: 6
        case .a18: 5
        case .a17Pro: 6
        case .a16: 5
        case .a15: 5
        case .a14: 4
        // S-series (Watch)
        case .s9, .s10: 4
        case .unknown: 4
        }
    }

    private func detectBatteryPower() -> Bool {
        #if os(macOS)
        // Check if running on battery
        let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        guard let firstSource = sources?.first else { return false }
        let description = IOPSGetPowerSourceDescription(snapshot, firstSource)?.takeUnretainedValue() as? [String: Any]
        return description?[kIOPSPowerSourceStateKey as String] as? String == kIOPSBatteryPowerValue
        #elseif os(iOS) || os(watchOS)
        // iOS/watchOS devices are always battery-powered unless plugged in
        // UIDevice.current.batteryState requires monitoring
        return true // Conservative assumption
        #elseif os(tvOS)
        return false // Apple TV is always plugged in
        #else
        return true
        #endif
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
        guard let profile = systemProfile else {
            // Fallback if profile not yet initialized
            let memory = ProcessInfo.processInfo.physicalMemory
            let memoryGB = Double(memory) / 1_073_741_824
            return SystemCapabilities(
                totalMemoryGB: memoryGB,
                availableMemoryGB: memoryGB * 0.5,
                hasGPU: true,
                isAppleSilicon: true,
                gpuCores: 10,
                neuralEngineTOPS: 15.0,
                recommendedMaxModelGB: min(memoryGB * 0.5, 8.0)
            )
        }

        // AI-powered calculation based on hardware profile
        let neuralEngineTOPS: Double = switch profile.neuralEngineCapability {
        case .generation5: 38.0
        case .generation4: 18.0
        case .generation3: 15.8
        case .generation2: 11.0
        case .unknown: 10.0
        }

        // Calculate recommended max model size based on:
        // - Total RAM (50% rule)
        // - Whether on battery (reduce by 30% on battery)
        // - Thermal state
        var recommendedMax = profile.totalMemoryGB * 0.5

        if profile.batteryPowered {
            recommendedMax *= 0.7 // Reduce for battery efficiency
        }

        if profile.thermalState == .serious || profile.thermalState == .critical {
            recommendedMax *= 0.5 // Reduce for thermal management
        }

        return SystemCapabilities(
            totalMemoryGB: profile.totalMemoryGB,
            availableMemoryGB: profile.totalMemoryGB * 0.5,
            hasGPU: true,
            isAppleSilicon: profile.chipType != .unknown,
            gpuCores: profile.gpuCores,
            neuralEngineTOPS: neuralEngineTOPS,
            recommendedMaxModelGB: recommendedMax
        )
    }

    /// Get AI-powered recommendation for optimal model based on current system state
    func getOptimalModelRecommendation() -> ModelRecommendation? {
        recommendations.first
    }

    /// Get system capability summary for UI display
    func getSystemCapabilitySummary() -> SystemCapabilitySummary {
        let caps = analyzeSystemCapabilities()
        guard let profile = systemProfile else {
            return SystemCapabilitySummary(
                tierName: configuration.performanceTier.displayName,
                maxModelSize: "\(Int(configuration.maxModelSizeGB))GB",
                chipDescription: "Unknown",
                memoryDescription: "\(Int(caps.totalMemoryGB))GB Unified Memory",
                recommendation: "Install models up to \(Int(configuration.maxModelSizeGB))GB"
            )
        }

        let tierDescription = switch profile.totalMemoryGB {
        case 0..<16: "Entry-level - Best for small models"
        case 16..<32: "Standard - Good for 7B parameter models"
        case 32..<64: "Professional - Great for 13B models"
        case 64..<128: "High-end - Excellent for 30B+ models"
        default: "Extreme - Run any model efficiently"
        }

        return SystemCapabilitySummary(
            tierName: configuration.performanceTier.displayName,
            maxModelSize: "\(Int(configuration.maxModelSizeGB))GB",
            chipDescription: profile.chipType.displayName,
            memoryDescription: "\(Int(profile.totalMemoryGB))GB Unified Memory",
            recommendation: tierDescription
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
    let gpuCores: Int
    let neuralEngineTOPS: Double
    let recommendedMaxModelGB: Double
}

// MARK: - System Hardware Profile

struct SystemHardwareProfile: Sendable {
    let totalMemoryGB: Double
    let cpuCores: Int
    let chipType: AppleSiliconChip
    let gpuCores: Int
    let neuralEngineCapability: NeuralEngineCapability
    let thermalState: LocalThermalState
    let batteryPowered: Bool
}

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

enum NeuralEngineCapability: String, Codable, Sendable {
    case generation2 = "Gen 2 (11 TOPS)"
    case generation3 = "Gen 3 (15.8 TOPS)"
    case generation4 = "Gen 4 (18 TOPS)"
    case generation5 = "Gen 5 (38 TOPS)"
    case unknown = "Unknown"
}

enum LocalThermalState: String, Codable, Sendable {
    case nominal
    case fair
    case serious
    case critical
}

struct SystemCapabilitySummary: Sendable {
    let tierName: String
    let maxModelSize: String
    let chipDescription: String
    let memoryDescription: String
    let recommendation: String
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
