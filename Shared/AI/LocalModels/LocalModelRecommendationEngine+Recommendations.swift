//
//  LocalModelRecommendationEngine+Recommendations.swift
//  Thea
//
//  AI-powered recommendation generation for local models
//  Extracted from LocalModelRecommendationEngine.swift for better code organization
//

import Foundation

// MARK: - Recommendations

extension LocalModelRecommendationEngine {
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

    func analyzeUserTaskTypes() -> [TaskType: Double] {
        // Return task distribution from user profile
        userProfile.taskDistribution
    }

    func analyzeSystemCapabilities() -> SystemCapabilities {
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
        // periphery:ignore - Reserved: getOptimalModelRecommendation() instance method reserved for future feature activation
        recommendations.first
    }

    /// Get system capability summary for UI display
    // periphery:ignore - Reserved: getSystemCapabilitySummary() instance method reserved for future feature activation
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

    func calculateRecommendationScore(
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

    func generateRecommendationReasons(model: DiscoveredModel, topTasks: [TaskType: Double]) -> [String] {
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

    func determinePriority(score: Double) -> RecommendationPriority {
        if score > 0.8 { .high } else if score > 0.6 { .medium } else { .low }
    }

    func mapTaskToCapability(_ task: TaskType) -> LocalModelCapability {
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
}
