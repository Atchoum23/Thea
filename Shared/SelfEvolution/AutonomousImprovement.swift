// AutonomousImprovement.swift
// Thea V2
//
// Autonomous self-improvement engine.
// Enables Thea to:
// - Monitor AI developments daily
// - Identify improvement opportunities
// - Generate and execute improvement plans
// - Self-implement beneficial changes
//
// THIS IS WHAT MAKES V2 TRULY CAPABLE OF SELF-EVOLUTION
//
// CREATED: February 2, 2026

import Foundation
import OSLog

// MARK: - Autonomous Improvement Engine

@MainActor
@Observable
public final class AutonomousImprovementEngine {
    public static let shared = AutonomousImprovementEngine()

    private let logger = Logger(subsystem: "com.thea.evolution", category: "Autonomous")

    // MARK: - State

    public private(set) var isRunning = false
    public private(set) var lastReview: Date?
    public private(set) var pendingImprovements: [ImprovementProposal] = []
    public private(set) var implementedImprovements: [ImplementedImprovement] = []
    public private(set) var reviewHistory: [DailyReview] = []

    // MARK: - Configuration

    public var autoImplement: Bool = false // Requires explicit user approval by default
    public var reviewSchedule: ReviewSchedule = .daily
    public var focusAreas: Set<FocusArea> = Set(FocusArea.allCases)

    private var reviewTask: Task<Void, Never>?

    private init() {
        loadState()
        startScheduledReviews()
    }

    // MARK: - Public API

    /// Perform a comprehensive AI development review
    public func performDailyReview() async -> DailyReview {
        isRunning = true
        defer { isRunning = false }

        logger.info("Starting daily AI development review...")

        let review = DailyReview(
            date: Date(),
            discoveries: await discoverNewDevelopments(),
            opportunities: await identifyImprovementOpportunities(),
            proposals: await generateImprovementProposals(),
            status: .completed
        )

        reviewHistory.append(review)
        lastReview = Date()
        pendingImprovements.append(contentsOf: review.proposals)

        saveState()

        logger.info("Daily review complete. Found \(review.proposals.count) improvement opportunities.")

        // Auto-implement if enabled and proposals are safe
        if autoImplement {
            for proposal in review.proposals where proposal.riskLevel == .low {
                _ = await implementProposal(proposal)
            }
        }

        return review
    }

    /// Implement a specific improvement proposal
    public func implementProposal(_ proposal: ImprovementProposal) async -> ImplementationResult {
        logger.info("Implementing proposal: \(proposal.title)")

        // Generate implementation blueprint
        let blueprint = await generateBlueprint(for: proposal)

        // Execute via BlueprintExecutor
        let result = await BlueprintExecutor.shared.execute(blueprint: blueprint)

        if result.success {
            let improvement = ImplementedImprovement(
                proposal: proposal,
                implementedAt: Date(),
                result: .success,
                details: "Successfully implemented via BlueprintExecutor"
            )
            implementedImprovements.append(improvement)
            pendingImprovements.removeAll { $0.id == proposal.id }

            logger.info("Successfully implemented: \(proposal.title)")
            return .success(improvement)
        } else {
            logger.error("Failed to implement: \(proposal.title) - \(result.error ?? "Unknown")")
            return .failure(result.error ?? "Unknown error")
        }
    }

    /// Get improvement status
    public func getStatus() -> ImprovementStatus {
        ImprovementStatus(
            isRunning: isRunning,
            lastReview: lastReview,
            pendingCount: pendingImprovements.count,
            implementedCount: implementedImprovements.count,
            nextScheduledReview: nextReviewDate()
        )
    }

    // MARK: - Discovery Methods

    private func discoverNewDevelopments() async -> [AIDiscovery] {
        var discoveries: [AIDiscovery] = []

        // Check for new model releases
        if let modelDiscoveries = await checkForNewModels() {
            discoveries.append(contentsOf: modelDiscoveries)
        }

        // Check for new techniques/patterns
        if let techniqueDiscoveries = await checkForNewTechniques() {
            discoveries.append(contentsOf: techniqueDiscoveries)
        }

        // Check for framework updates
        if let frameworkDiscoveries = await checkForFrameworkUpdates() {
            discoveries.append(contentsOf: frameworkDiscoveries)
        }

        return discoveries
    }

    private func checkForNewModels() async -> [AIDiscovery]? {
        guard let provider = ProviderRegistry.shared.getDefaultProvider() else {
            return nil
        }

        let prompt = """
        You are an AI development analyst. List any significant new AI models or model updates
        released in the past week that could improve a macOS/iOS AI assistant app. Focus on:
        - New language models (OpenAI, Anthropic, open-source)
        - Vision models
        - Audio/speech models
        - On-device/edge models (especially for Apple Silicon)

        Format as JSON array:
        [{"name": "model_name", "provider": "provider", "capability": "what it does", "relevance": "high/medium/low"}]

        Only include genuinely new developments, not existing models.
        Return empty array [] if no significant new developments.
        """

        do {
            let model = await DynamicConfig.shared.bestModel(for: .analysis)
            let response = try await streamToString(
                provider: provider,
                prompt: prompt,
                model: model
            )

            // Parse JSON response
            if let data = response.data(using: String.Encoding.utf8),
               let models = try? JSONDecoder().decode([ModelDiscoveryJSON].self, from: data) {
                return models.map { model in
                    AIDiscovery(
                        type: .newModel,
                        title: model.name,
                        description: model.capability,
                        source: model.provider,
                        relevance: Relevance(rawValue: model.relevance) ?? .medium,
                        discoveredAt: Date()
                    )
                }
            }
        } catch {
            logger.warning("Failed to check for new models: \(error.localizedDescription)")
        }

        return nil
    }

    private func checkForNewTechniques() async -> [AIDiscovery]? {
        guard let provider = ProviderRegistry.shared.getDefaultProvider() else {
            return nil
        }

        let prompt = """
        You are an AI development analyst. List any significant new AI techniques,
        prompt engineering patterns, or best practices that emerged recently that could
        improve an AI assistant app. Focus on:
        - New prompting techniques
        - RAG improvements
        - Context management strategies
        - Multi-agent patterns
        - Tool use improvements

        Format as JSON array:
        [{"name": "technique_name", "description": "what it does", "applicability": "how to apply it"}]

        Return empty array [] if no significant new techniques.
        """

        do {
            let model = await DynamicConfig.shared.bestModel(for: .analysis)
            let response = try await streamToString(
                provider: provider,
                prompt: prompt,
                model: model
            )

            if let data = response.data(using: String.Encoding.utf8),
               let techniques = try? JSONDecoder().decode([TechniqueDiscoveryJSON].self, from: data) {
                return techniques.map { tech in
                    AIDiscovery(
                        type: .newTechnique,
                        title: tech.name,
                        description: "\(tech.description). Application: \(tech.applicability)",
                        source: "AI Research",
                        relevance: .medium,
                        discoveredAt: Date()
                    )
                }
            }
        } catch {
            logger.warning("Failed to check for new techniques: \(error.localizedDescription)")
        }

        return nil
    }

    private func checkForFrameworkUpdates() async -> [AIDiscovery]? {
        // Check relevant frameworks: SwiftUI, MLX, CoreML, etc.
        // This would integrate with package managers and release feeds
        nil
    }

    // MARK: - Opportunity Identification

    private func identifyImprovementOpportunities() async -> [ImprovementOpportunity] {
        var opportunities: [ImprovementOpportunity] = []

        // Analyze current codebase for improvement areas
        if focusAreas.contains(.performance) {
            opportunities.append(contentsOf: await analyzePerformanceOpportunities())
        }

        if focusAreas.contains(.features) {
            opportunities.append(contentsOf: await analyzeFeatureOpportunities())
        }

        if focusAreas.contains(.codeQuality) {
            opportunities.append(contentsOf: await analyzeCodeQualityOpportunities())
        }

        if focusAreas.contains(.userExperience) {
            opportunities.append(contentsOf: await analyzeUXOpportunities())
        }

        return opportunities
    }

    private func analyzePerformanceOpportunities() async -> [ImprovementOpportunity] {
        // Analyze app performance metrics and suggest optimizations
        [
            ImprovementOpportunity(
                area: .performance,
                title: "Response streaming optimization",
                description: "Implement token-level streaming for faster perceived response times",
                estimatedImpact: .medium,
                estimatedEffort: .low
            )
        ]
    }

    private func analyzeFeatureOpportunities() async -> [ImprovementOpportunity] {
        [
            ImprovementOpportunity(
                area: .features,
                title: "Vision capability integration",
                description: "Add image understanding via GPT-4V or local vision models",
                estimatedImpact: .high,
                estimatedEffort: .medium
            )
        ]
    }

    private func analyzeCodeQualityOpportunities() async -> [ImprovementOpportunity] {
        [
            ImprovementOpportunity(
                area: .codeQuality,
                title: "Comprehensive error handling audit",
                description: "Ensure all async operations have proper error handling and recovery",
                estimatedImpact: .medium,
                estimatedEffort: .medium
            )
        ]
    }

    private func analyzeUXOpportunities() async -> [ImprovementOpportunity] {
        [
            ImprovementOpportunity(
                area: .userExperience,
                title: "Adaptive response formatting",
                description: "Format responses based on content type (code, prose, lists)",
                estimatedImpact: .medium,
                estimatedEffort: .low
            )
        ]
    }

    // MARK: - Proposal Generation

    private func generateImprovementProposals() async -> [ImprovementProposal] {
        guard let provider = ProviderRegistry.shared.getDefaultProvider() else {
            return []
        }

        var proposals: [ImprovementProposal] = []

        // Generate concrete proposals from opportunities
        let opportunities = await identifyImprovementOpportunities()

        for opportunity in opportunities.prefix(5) { // Limit to top 5
            let prompt = """
            Generate a concrete implementation plan for this improvement:
            Title: \(opportunity.title)
            Description: \(opportunity.description)
            Area: \(opportunity.area.rawValue)

            The app is a macOS/iOS AI assistant built with SwiftUI, Swift 6, and async/await.
            It uses multiple AI providers (OpenAI, Anthropic, local MLX models).

            Provide a JSON response with:
            {
                "title": "improvement title",
                "description": "what this improves",
                "implementation_steps": ["step1", "step2", ...],
                "files_to_modify": ["file1.swift", "file2.swift"],
                "estimated_lines": 50,
                "risk_level": "low/medium/high",
                "rollback_plan": "how to revert if needed"
            }
            """

            do {
                let model = await DynamicConfig.shared.bestModel(for: .codeGeneration)
                let response = try await streamToString(
                    provider: provider,
                    prompt: prompt,
                    model: model
                )

                if let data = response.data(using: String.Encoding.utf8),
                   let proposalJSON = try? JSONDecoder().decode(ProposalJSON.self, from: data) {
                    proposals.append(ImprovementProposal(
                        id: UUID(),
                        title: proposalJSON.title,
                        description: proposalJSON.description,
                        implementationSteps: proposalJSON.implementation_steps,
                        filesToModify: proposalJSON.files_to_modify,
                        estimatedLines: proposalJSON.estimated_lines,
                        riskLevel: RiskLevel(rawValue: proposalJSON.risk_level) ?? .medium,
                        rollbackPlan: proposalJSON.rollback_plan,
                        createdAt: Date(),
                        status: .pending
                    ))
                }
            } catch {
                logger.warning("Failed to generate proposal for: \(opportunity.title)")
            }
        }

        return proposals
    }

    // MARK: - AI Helper

    /// Sends a prompt to the given provider and collects the full response text.
    private func streamToString(
        provider: AIProvider,
        prompt: String,
        model: String
    ) async throws -> String {
        let message = AIMessage(
            id: UUID(), conversationID: UUID(), role: .user,
            content: .text(prompt),
            timestamp: Date(), model: model
        )

        let stream = try await provider.chat(
            messages: [message],
            model: model,
            stream: false
        )

        var result = ""
        for try await chunk in stream {
            switch chunk.type {
            case let .delta(text):
            case .thinkingDelta: break
                result += text
            case let .complete(msg):
                result = msg.content.textValue
            case .error:
                break
            }
        }
        return result
    }

    // MARK: - Blueprint Generation

    private func generateBlueprint(for proposal: ImprovementProposal) async -> Blueprint {
        var phases: [BlueprintPhase] = []

        // Phase 1: Backup
        phases.append(BlueprintPhase(
            name: "Backup",
            description: "Create backup before changes",
            steps: [
                BlueprintStep(
                    description: "Git commit current state",
                    type: .command("git add -A && git commit -m 'Pre-improvement backup: \(proposal.title)' || true")
                )
            ]
        ))

        // Phase 2: Implementation
        var implementationSteps: [BlueprintStep] = []
        for step in proposal.implementationSteps {
            implementationSteps.append(BlueprintStep(
                description: step,
                type: .aiTask(BlueprintAITask(
                    description: step,
                    prompt: """
                    Implement this step for Thea V2 (Swift 6, SwiftUI, async/await):
                    Step: \(step)
                    Context: \(proposal.description)

                    Provide the exact code changes needed.
                    """,
                    model: await DynamicConfig.shared.bestModel(for: .codeGeneration)
                ))
            ))
        }

        phases.append(BlueprintPhase(
            name: "Implementation",
            description: proposal.description,
            steps: implementationSteps,
            verification: .buildSucceeds(scheme: "Thea-macOS")
        ))

        // Phase 3: Verification
        phases.append(BlueprintPhase(
            name: "Verification",
            description: "Verify changes work correctly",
            steps: [
                BlueprintStep(
                    description: "Run tests",
                    type: .verification(.testsPass(target: nil))
                )
            ]
        ))

        return Blueprint(
            name: "Implement: \(proposal.title)",
            description: proposal.description,
            phases: phases
        )
    }

    // MARK: - Scheduling

    private func startScheduledReviews() {
        reviewTask?.cancel()

        reviewTask = Task {
            while !Task.isCancelled {
                let nextReview = nextReviewDate()
                let delay = nextReview.timeIntervalSinceNow

                if delay > 0 {
                    try? await Task.sleep(for: .seconds(delay))
                }

                if !Task.isCancelled {
                    _ = await performDailyReview()
                }
            }
        }
    }

    private func nextReviewDate() -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 3 // 3 AM - quiet time
        components.minute = 0

        if let todayReview = calendar.date(from: components) {
            if Date() > todayReview {
                // Already past today's review time, schedule for tomorrow
                return calendar.date(byAdding: .day, value: 1, to: todayReview) ?? todayReview
            }
            return todayReview
        }

        return Date().addingTimeInterval(86400)
    }

    // MARK: - Persistence

    private func loadState() {
        // Load from UserDefaults or persistent storage
        if let lastReviewData = UserDefaults.standard.object(forKey: "AutonomousImprovement.lastReview") as? Date {
            lastReview = lastReviewData
        }
    }

    private func saveState() {
        UserDefaults.standard.set(lastReview, forKey: "AutonomousImprovement.lastReview")
    }
}

// MARK: - Supporting Types

public struct DailyReview: Sendable, Identifiable {
    public let id = UUID()
    public let date: Date
    public let discoveries: [AIDiscovery]
    public let opportunities: [ImprovementOpportunity]
    public let proposals: [ImprovementProposal]
    public let status: ReviewStatus
}

public struct AIDiscovery: Sendable, Identifiable {
    public let id = UUID()
    public let type: DiscoveryType
    public let title: String
    public let description: String
    public let source: String
    public let relevance: Relevance
    public let discoveredAt: Date
}

public enum DiscoveryType: String, Sendable {
    case newModel
    case newTechnique
    case frameworkUpdate
    case securityPatch
    case performanceImprovement
}

public enum Relevance: String, Sendable, Codable {
    case high, medium, low
}

public struct ImprovementOpportunity: Sendable, Identifiable {
    public let id = UUID()
    public let area: FocusArea
    public let title: String
    public let description: String
    public let estimatedImpact: Impact
    public let estimatedEffort: Effort
}

public enum FocusArea: String, Sendable, CaseIterable {
    case performance
    case features
    case codeQuality
    case userExperience
    case security
    case accessibility
}

public enum Impact: String, Sendable {
    case high, medium, low
}

public enum Effort: String, Sendable {
    case high, medium, low
}

public struct ImprovementProposal: Sendable, Identifiable {
    public let id: UUID
    public let title: String
    public let description: String
    public let implementationSteps: [String]
    public let filesToModify: [String]
    public let estimatedLines: Int
    public let riskLevel: RiskLevel
    public let rollbackPlan: String
    public let createdAt: Date
    public var status: ProposalStatus
}

public enum RiskLevel: String, Sendable, Codable {
    case low, medium, high
}

public enum ProposalStatus: String, Sendable {
    case pending, approved, implementing, completed, rejected, failed
}

public struct ImplementedImprovement: Sendable, Identifiable {
    public let id = UUID()
    public let proposal: ImprovementProposal
    public let implementedAt: Date
    public let result: ImplementationResultType
    public let details: String
}

public enum ImplementationResultType: String, Sendable {
    case success, partialSuccess, failure
}

public enum ImplementationResult: Sendable {
    case success(ImplementedImprovement)
    case failure(String)
}

public enum ReviewStatus: String, Sendable {
    case pending, inProgress, completed, failed
}

public enum ReviewSchedule: String, Sendable {
    case hourly, daily, weekly
}

public struct ImprovementStatus: Sendable {
    public let isRunning: Bool
    public let lastReview: Date?
    public let pendingCount: Int
    public let implementedCount: Int
    public let nextScheduledReview: Date
}

// MARK: - JSON Parsing Types

private struct ModelDiscoveryJSON: Codable {
    let name: String
    let provider: String
    let capability: String
    let relevance: String
}

private struct TechniqueDiscoveryJSON: Codable {
    let name: String
    let description: String
    let applicability: String
}

private struct ProposalJSON: Codable {
    let title: String
    let description: String
    let implementation_steps: [String]
    let files_to_modify: [String]
    let estimated_lines: Int
    let risk_level: String
    let rollback_plan: String
}
