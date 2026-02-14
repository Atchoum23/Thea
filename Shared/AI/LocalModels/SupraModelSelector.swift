//
//  SupraModelSelector.swift
//  Thea
//
//  Intelligent selection system for the Supra-Model (always-present anchor)
//  Uses multi-factor scoring including quality benchmarks, resource fit, and versatility
//
//  SELECTION CRITERIA:
//  1. Quality Score: Historical performance across task types
//  2. Resource Fit: Memory/disk footprint vs available resources
//  3. Versatility: Ability to handle diverse task types
//  4. Recency: How up-to-date the model architecture is
//  5. Community Standing: Downloads, likes, benchmark rankings
//
//  CREATED: February 5, 2026
//

import Foundation
import OSLog

// MARK: - Supra-Model Selector

/// Selects and manages the optimal Supra-Model (always-present anchor)
/// Now uses adaptive hyperparameters for scoring weights instead of fixed values
final class SupraModelSelector: Sendable {
    /// Reference to adaptive orchestrator for hyperparameter access
    private let adaptiveOrchestrator: AdaptiveGovernanceOrchestrator?

    init(adaptiveOrchestrator: AdaptiveGovernanceOrchestrator? = nil) {
        self.adaptiveOrchestrator = adaptiveOrchestrator
    }

    // MARK: - Selection

    /// Select the best Supra-Model from installed models
    func selectBestSupraModel(
        from models: [LocalModel],
        resourceSnapshot: ResourceSnapshot,
        qualityTracker: ModelQualityBenchmark
    ) async -> SupraModelCandidate? {
        guard !models.isEmpty else { return nil }

        var candidates: [SupraModelCandidate] = []

        for model in models {
            let score = await calculateSupraScore(
                model: model,
                resourceSnapshot: resourceSnapshot,
                qualityTracker: qualityTracker
            )

            candidates.append(SupraModelCandidate(
                model: model,
                score: score.total,
                reason: score.reason,
                breakdown: score
            ))
        }

        // Sort by score descending
        candidates.sort { $0.score > $1.score }

        return candidates.first
    }

    /// Calculate comprehensive Supra-Model score
    /// Uses adaptive hyperparameters for weights when available
    private func calculateSupraScore(
        model: LocalModel,
        resourceSnapshot: ResourceSnapshot,
        qualityTracker: ModelQualityBenchmark
    ) async -> SupraScoreBreakdown {
        // 1. Quality Score
        let qualityScore = qualityTracker.getQualityScore(for: model.name)

        // 2. Resource Fit Score
        let resourceScore = calculateResourceFitScore(model: model, snapshot: resourceSnapshot)

        // 3. Versatility Score
        let versatilityScore = calculateVersatilityScore(model: model)

        // 4. Architecture Recency Score
        let recencyScore = calculateRecencyScore(model: model)

        // 5. Community Standing Score
        let communityScore = calculateCommunityScore(model: model)

        // Get adaptive weights (or use defaults if orchestrator not available)
        let weights = await getAdaptiveScoringWeights()

        // Weighted total using adaptive weights
        let total = (qualityScore * weights.quality) +
                   (resourceScore * weights.resourceFit) +
                   (versatilityScore * weights.versatility) +
                   (recencyScore * weights.recency) +
                   (communityScore * weights.community)

        // Build reason string
        let reasons = buildReasonString(
            quality: qualityScore,
            resource: resourceScore,
            versatility: versatilityScore,
            recency: recencyScore,
            community: communityScore
        )

        return SupraScoreBreakdown(
            total: total,
            qualityScore: qualityScore,
            resourceFitScore: resourceScore,
            versatilityScore: versatilityScore,
            recencyScore: recencyScore,
            communityScore: communityScore,
            reason: reasons
        )
    }

    /// Get adaptive evolution threshold from orchestrator or use default
    private func getAdaptiveEvolutionThreshold() async -> Double {
        guard let orchestrator = adaptiveOrchestrator else {
            return 0.15 // Default: 15% improvement required
        }
        return await orchestrator.getHyperparameter(.evolutionThreshold)
    }

    /// Get adaptive scoring weights from orchestrator or use defaults
    private func getAdaptiveScoringWeights() async -> ScoringWeights {
        guard let orchestrator = adaptiveOrchestrator else {
            // Default weights: quality (30%), resource fit (25%), versatility (25%), recency (10%), community (10%)
            return ScoringWeights(quality: 0.30, resourceFit: 0.25, versatility: 0.25, recency: 0.10, community: 0.10)
        }

        // Get learned weights from adaptive hyperparameter tuner
        let qualityWeight = await orchestrator.getHyperparameter(.supraQualityWeight)
        let resourceFitWeight = await orchestrator.getHyperparameter(.supraResourceWeight)
        let versatilityWeight = await orchestrator.getHyperparameter(.supraVersatilityWeight)
        let recencyWeight = await orchestrator.getHyperparameter(.supraRecencyWeight)
        let communityWeight = await orchestrator.getHyperparameter(.supraCommunityWeight)

        // Normalize weights to sum to 1.0
        let total = qualityWeight + resourceFitWeight + versatilityWeight + recencyWeight + communityWeight
        guard total > 0 else {
            return ScoringWeights(quality: 0.30, resourceFit: 0.25, versatility: 0.25, recency: 0.10, community: 0.10)
        }

        return ScoringWeights(
            quality: qualityWeight / total,
            resourceFit: resourceFitWeight / total,
            versatility: versatilityWeight / total,
            recency: recencyWeight / total,
            community: communityWeight / total
        )
    }

    /// Calculate resource fit score
    private func calculateResourceFitScore(model: LocalModel, snapshot: ResourceSnapshot) -> Double {
        let modelSizeGB = Double(model.size) / 1_000_000_000

        // Ideal model size is 20-40% of available memory
        let idealMinSize = snapshot.availableMemoryGB * 0.2
        let idealMaxSize = snapshot.availableMemoryGB * 0.4

        if modelSizeGB >= idealMinSize && modelSizeGB <= idealMaxSize {
            return 1.0 // Perfect fit
        } else if modelSizeGB < idealMinSize {
            // Too small - might lack capability
            return 0.7 + (modelSizeGB / idealMinSize) * 0.3
        } else if modelSizeGB <= snapshot.availableMemoryGB * 0.6 {
            // Acceptable but large
            return 0.8 - ((modelSizeGB - idealMaxSize) / idealMaxSize) * 0.2
        } else {
            // Too large - risk of memory pressure
            return max(0.3, 0.6 - ((modelSizeGB - snapshot.availableMemoryGB * 0.6) / modelSizeGB))
        }
    }

    /// Calculate versatility score based on model capabilities
    private func calculateVersatilityScore(model: LocalModel) -> Double {
        let name = model.name.lowercased()
        var score = 0.5 // Base score

        // General-purpose instruction models are most versatile
        if name.contains("instruct") {
            score += 0.2
        }

        // Known versatile model families
        if name.contains("qwen") {
            score += 0.15 // Qwen is excellent at many tasks
        }
        if name.contains("llama") {
            score += 0.1
        }
        if name.contains("mistral") {
            score += 0.1
        }

        // Specialized models are less versatile (but not necessarily bad)
        if name.contains("coder") || name.contains("code") {
            score -= 0.1 // Good at code, less versatile overall
        }
        if name.contains("math") {
            score -= 0.1
        }

        // Size indicates capability breadth
        let sizeGB = Double(model.size) / 1_000_000_000
        if sizeGB >= 7 {
            score += 0.1 // Larger models tend to be more capable
        }

        return min(1.0, max(0.0, score))
    }

    /// Calculate recency score based on model architecture
    private func calculateRecencyScore(model: LocalModel) -> Double {
        let name = model.name.lowercased()

        // Latest model architectures (2024-2025)
        if name.contains("3.2") || name.contains("3.3") || name.contains("2.5") {
            return 1.0
        }
        if name.contains("r1") { // DeepSeek R1
            return 1.0
        }
        if name.contains("3.1") || name.contains("2.0") {
            return 0.85
        }
        if name.contains("3") || name.contains("v3") {
            return 0.8
        }
        if name.contains("2") || name.contains("v2") {
            return 0.6
        }

        // Older or unknown versions
        return 0.5
    }

    /// Calculate community standing score
    private func calculateCommunityScore(model: LocalModel) -> Double {
        let name = model.name.lowercased()

        // Well-known, highly-regarded model families
        if name.contains("llama") || name.contains("qwen") || name.contains("deepseek") {
            return 0.9
        }
        if name.contains("mistral") || name.contains("gemma") {
            return 0.85
        }
        if name.contains("phi") {
            return 0.8
        }

        // MLX community optimized models are trusted
        if name.contains("mlx") {
            return 0.8
        }

        return 0.6 // Unknown models
    }

    /// Build human-readable reason string
    private func buildReasonString(
        quality: Double,
        resource: Double,
        versatility: Double,
        recency: Double,
        community: Double
    ) -> String {
        var strengths: [String] = []

        if quality >= 0.8 {
            strengths.append("Proven quality (\(Int(quality * 100))%)")
        }
        if resource >= 0.8 {
            strengths.append("Optimal resource fit")
        }
        if versatility >= 0.8 {
            strengths.append("Highly versatile")
        }
        if recency >= 0.9 {
            strengths.append("Latest architecture")
        }
        if community >= 0.85 {
            strengths.append("Strong community support")
        }

        if strengths.isEmpty {
            return "Balanced general-purpose model"
        }

        return strengths.joined(separator: ", ")
    }

    // MARK: - Evolution Detection

    /// Determine if Supra-Model should evolve to a better option
    func shouldEvolveSupraModel(
        current: SupraModelState,
        installedModels: [LocalModel],
        resourceSnapshot: ResourceSnapshot,
        qualityTracker: ModelQualityBenchmark
    ) async -> EvolutionDecision {
        // Find current model
        guard let currentModel = installedModels.first(where: { $0.name == current.modelName }) else {
            // Current Supra-Model no longer installed - must evolve
            return EvolutionDecision(
                shouldChange: true,
                reason: "Current Supra-Model no longer available",
                recommendedModel: await selectBestSupraModel(
                    from: installedModels,
                    resourceSnapshot: resourceSnapshot,
                    qualityTracker: qualityTracker
                )?.model
            )
        }

        // Calculate current model's score
        let currentScore = await calculateSupraScore(
            model: currentModel,
            resourceSnapshot: resourceSnapshot,
            qualityTracker: qualityTracker
        )

        // Find best alternative
        let otherModels = installedModels.filter { $0.name != current.modelName }
        guard let bestAlternative = await selectBestSupraModel(
            from: otherModels,
            resourceSnapshot: resourceSnapshot,
            qualityTracker: qualityTracker
        ) else {
            // No alternatives available
            return EvolutionDecision(
                shouldChange: false,
                reason: "No better alternatives available",
                recommendedModel: nil
            )
        }

        // Evolution threshold: uses adaptive hyperparameter instead of fixed 15%
        let improvementThreshold = await getAdaptiveEvolutionThreshold()
        let improvement = bestAlternative.score - currentScore.total

        if improvement > improvementThreshold {
            return EvolutionDecision(
                shouldChange: true,
                reason: "Better model available: \(bestAlternative.model.name) (+\(Int(improvement * 100))% improvement)",
                recommendedModel: bestAlternative.model
            )
        }

        // Check for quality degradation
        let qualityDegradation = qualityTracker.getQualityTrend(for: current.modelName)
        if qualityDegradation < -0.1 {
            return EvolutionDecision(
                shouldChange: true,
                reason: "Quality degradation detected, recommending evolution",
                recommendedModel: bestAlternative.model
            )
        }

        return EvolutionDecision(
            shouldChange: false,
            reason: "Current Supra-Model performing well",
            recommendedModel: nil
        )
    }

    // MARK: - Bootstrap Recommendation

    /// Get bootstrap recommendation when no models are installed
    /// Memory tier thresholds are now adaptive instead of fixed
    func getBootstrapRecommendation(resourceSnapshot: ResourceSnapshot) async -> ProactiveModelRecommendation? {
        // Get adaptive memory tier thresholds
        let tiers = await getAdaptiveMemoryTiers()
        let availableMemoryGB = resourceSnapshot.availableMemoryGB

        // Tier 1: High-end systems (default: 24GB+ available, ~32GB+ total)
        if availableMemoryGB >= tiers.ultraThreshold {
            return ProactiveModelRecommendation(
                modelId: "mlx-community/Qwen2.5-7B-Instruct-4bit",
                modelName: "Qwen 2.5 7B Instruct 4-bit",
                estimatedSizeGB: 4.5,
                downloadURL: "https://huggingface.co/mlx-community/Qwen2.5-7B-Instruct-4bit",
                reason: "Excellent versatile model for high-end system - strong reasoning, coding, and general capabilities",
                taskTypes: [.conversation, .codeGeneration, .math, .creative],
                priority: .high
            )
        }

        // Tier 2: Mid-range systems (default: 12GB+ available, ~16GB+ total)
        if availableMemoryGB >= tiers.proThreshold {
            return ProactiveModelRecommendation(
                modelId: "mlx-community/Llama-3.2-3B-Instruct-4bit",
                modelName: "Llama 3.2 3B Instruct 4-bit",
                estimatedSizeGB: 2.0,
                downloadURL: "https://huggingface.co/mlx-community/Llama-3.2-3B-Instruct-4bit",
                reason: "Fast, efficient model balancing quality and resource usage",
                taskTypes: [.conversation, .factual, .creative],
                priority: .high
            )
        }

        // Tier 3: Lower-end systems (default: 6GB+ available, ~8GB+ total)
        if availableMemoryGB >= tiers.plusThreshold {
            return ProactiveModelRecommendation(
                modelId: "mlx-community/Qwen2.5-1.5B-Instruct-4bit",
                modelName: "Qwen 2.5 1.5B Instruct 4-bit",
                estimatedSizeGB: 1.2,
                downloadURL: "https://huggingface.co/mlx-community/Qwen2.5-1.5B-Instruct-4bit",
                reason: "Lightweight model optimized for constrained systems",
                taskTypes: [.conversation, .factual],
                priority: .high
            )
        }

        // Tier 4: Very constrained systems (below plus threshold)
        return ProactiveModelRecommendation(
            modelId: "mlx-community/Qwen2.5-0.5B-Instruct-4bit",
            modelName: "Qwen 2.5 0.5B Instruct 4-bit",
            estimatedSizeGB: 0.5,
            downloadURL: "https://huggingface.co/mlx-community/Qwen2.5-0.5B-Instruct-4bit",
            reason: "Ultra-lightweight model for minimal resource systems",
            taskTypes: [.conversation],
            priority: .high
        )
    }

    /// Get adaptive memory tier thresholds
    /// Note: Memory tier thresholds are fixed as they represent hardware constraints
    private func getAdaptiveMemoryTiers() async -> MemoryTierThresholds {
        // Default thresholds (available memory, not total)
        // These are fixed values based on hardware capability tiers
        MemoryTierThresholds(ultraThreshold: 24, proThreshold: 12, plusThreshold: 6)
    }
}

/// Memory tier thresholds for model selection
struct MemoryTierThresholds: Sendable {
    let ultraThreshold: Double  // GB of available memory for Ultra tier
    let proThreshold: Double    // GB of available memory for Pro tier
    let plusThreshold: Double   // GB of available memory for Plus tier
}

// MARK: - Supporting Types

/// Supra-Model candidate with scoring
struct SupraModelCandidate: Sendable {
    let model: LocalModel
    let score: Double
    let reason: String
    let breakdown: SupraScoreBreakdown
}

/// Detailed score breakdown for Supra-Model selection
struct SupraScoreBreakdown: Sendable {
    let total: Double
    let qualityScore: Double
    let resourceFitScore: Double
    let versatilityScore: Double
    let recencyScore: Double
    let communityScore: Double
    let reason: String
}

/// Evolution decision result
struct EvolutionDecision: Sendable {
    let shouldChange: Bool
    let reason: String
    let recommendedModel: LocalModel?
}

/// Scoring weights for Supra-Model selection
struct ScoringWeights: Sendable {
    let quality: Double
    let resourceFit: Double
    let versatility: Double
    let recency: Double
    let community: Double
}
