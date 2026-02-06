// AdaptiveLearningEngine.swift
// Thea V2
//
// Adaptive Learning Engine - Continuously improves from user interactions
// Implements online learning, preference evolution, and skill development

import Foundation
import OSLog

// MARK: - Adaptive Learning Engine

/// Continuously learns and adapts to user behavior
@MainActor
public final class AdaptiveLearningEngine: ObservableObject {

    public static let shared = AdaptiveLearningEngine()

    private let logger = Logger(subsystem: "app.thea.intelligence", category: "AdaptiveLearning")

    // MARK: - State

    @Published public private(set) var learningProfile = LearningProfile()
    @Published public private(set) var skillLevels: [SkillDomain: SkillLevel] = [:]
    @Published public private(set) var currentLearningRate: Float = 0.1

    // MARK: - Configuration

    public var baseLearningRate: Float = 0.1
    public var learningDecay: Float = 0.995

    // MARK: - Learning

    public func recordInteraction(_ interaction: UserInteraction) async {
        learningProfile.totalInteractions += 1
        learningProfile.lastInteractionAt = Date()
        updateTimePatterns(interaction)
        updateSkillEstimation(from: interaction)
        adaptLearningRate()
        logger.debug("Recorded interaction: \(interaction.type.rawValue)")
    }

    private func updateTimePatterns(_ interaction: UserInteraction) {
        let hour = Calendar.current.component(.hour, from: interaction.timestamp)
        let hourKey = "hour_\(hour)"
        learningProfile.activityByHour[hourKey] = (learningProfile.activityByHour[hourKey] ?? 0) + 1
    }

    private func updateSkillEstimation(from interaction: UserInteraction) {
        var skill = skillLevels[interaction.domain] ?? SkillLevel(domain: interaction.domain)

        switch interaction.complexity {
        case .simple: skill.simpleTaskCount += 1
        case .moderate: skill.moderateTaskCount += 1
        case .complex: skill.complexTaskCount += 1
        case .expert: skill.expertTaskCount += 1
        }

        skill.level = calculateSkillLevel(skill)
        skillLevels[interaction.domain] = skill
    }

    private func calculateSkillLevel(_ skill: SkillLevel) -> Float {
        let totalTasks = Float(
            skill.simpleTaskCount + skill.moderateTaskCount * 2 +
            skill.complexTaskCount * 4 + skill.expertTaskCount * 8
        )
        return min(1.0, totalTasks / 1000.0)
    }

    private func adaptLearningRate() {
        let interactionFactor = Float(learningProfile.totalInteractions)
        currentLearningRate = max(0.01, baseLearningRate * pow(learningDecay, interactionFactor / 100))
    }

    public func getPreference(_ key: String, default defaultValue: Float = 0.5) -> Float {
        learningProfile.preferences[key] ?? defaultValue
    }
}

// MARK: - Supporting Types

public struct LearningProfile: Codable, Sendable {
    public var totalInteractions: Int = 0
    public var lastInteractionAt: Date?
    public var activityByHour: [String: Int] = [:]
    public var preferences: [String: Float] = [:]
}

public struct SkillLevel: Codable, Sendable {
    public let domain: SkillDomain
    public var level: Float = 0.0
    public var simpleTaskCount: Int = 0
    public var moderateTaskCount: Int = 0
    public var complexTaskCount: Int = 0
    public var expertTaskCount: Int = 0
}

public enum SkillDomain: String, Codable, Sendable, CaseIterable {
    case coding, research, communication, dataAnalysis, creativity, planning
}

public struct UserInteraction: Sendable {
    public let id: UUID
    public let type: InteractionType
    public let domain: SkillDomain
    public let complexity: Complexity
    public let timestamp: Date

    public enum InteractionType: String, Sendable {
        case query, command, feedback, navigation, codeEdit
    }

    public enum Complexity: String, Sendable {
        case simple, moderate, complex, expert
    }

    public init(id: UUID = UUID(), type: InteractionType, domain: SkillDomain, complexity: Complexity = .moderate, timestamp: Date = Date()) {
        self.id = id
        self.type = type
        self.domain = domain
        self.complexity = complexity
        self.timestamp = timestamp
    }
}
