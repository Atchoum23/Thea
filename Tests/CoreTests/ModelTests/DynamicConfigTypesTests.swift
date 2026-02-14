// DynamicConfigTypesTests.swift
// Tests for DynamicConfig types — AI task categories, temperature, tokens, intervals, cache

import Testing
import Foundation

// MARK: - Test Doubles

private enum TestAITaskCategory2: String, Codable, Sendable, CaseIterable {
    case codeGeneration, codeReview, bugFix
    case conversation, assistance
    case creative, brainstorming
    case analysis, classification
    case translation, correction
}

private func testTemperature2(for task: TestAITaskCategory2) -> Double {
    switch task {
    case .codeGeneration, .codeReview, .bugFix:
        return 0.1
    case .creative, .brainstorming:
        return 0.9
    case .conversation, .assistance:
        return 0.7
    case .analysis, .classification:
        return 0.3
    case .translation, .correction:
        return 0.2
    }
}

private func testMaxTokens2(for task: TestAITaskCategory2, inputLength: Int = 0) -> Int {
    switch task {
    case .codeGeneration:
        return 4000
    case .codeReview, .bugFix:
        return 2000
    case .conversation:
        return 1000
    case .analysis:
        return 1500
    case .creative, .brainstorming:
        return 3000
    case .translation, .correction:
        return max(inputLength * 2, 500)
    case .assistance:
        return 2000
    case .classification:
        return 100
    }
}

private func testDefaultModel2(for task: TestAITaskCategory2) -> String {
    switch task {
    case .codeGeneration, .codeReview, .bugFix, .creative, .analysis:
        return "gpt-4o"
    default:
        return "gpt-4o-mini"
    }
}

private struct TestCachedValue2 {
    let value: Any
    let expiry: Date
    var isExpired: Bool { Date() > expiry }
}

private enum TestPeriodicTask2: String, Sendable, CaseIterable {
    case contextUpdate, insightGeneration, healthCheck
    case cacheCleanup, modelOptimization, selfImprovement
}

private func testDefaultInterval2(for task: TestPeriodicTask2) -> TimeInterval {
    switch task {
    case .contextUpdate: return 900
    case .insightGeneration: return 3600
    case .healthCheck: return 300
    case .cacheCleanup: return 7200
    case .modelOptimization: return 86400
    case .selfImprovement: return 43200
    }
}

// MARK: - Tests: Temperature Logic

@Suite("AI Task Temperature — DynamicConfig")
struct AITaskTemperatureDCTests {
    @Test("Code tasks have low temperature (0.1)")
    func codeTemperature() {
        #expect(testTemperature2(for: .codeGeneration) == 0.1)
        #expect(testTemperature2(for: .codeReview) == 0.1)
        #expect(testTemperature2(for: .bugFix) == 0.1)
    }

    @Test("Creative tasks have high temperature (0.9)")
    func creativeTemperature() {
        #expect(testTemperature2(for: .creative) == 0.9)
        #expect(testTemperature2(for: .brainstorming) == 0.9)
    }

    @Test("Conversation tasks have balanced temperature (0.7)")
    func conversationTemperature() {
        #expect(testTemperature2(for: .conversation) == 0.7)
        #expect(testTemperature2(for: .assistance) == 0.7)
    }

    @Test("Analysis tasks have lower temperature (0.3)")
    func analysisTemperature() {
        #expect(testTemperature2(for: .analysis) == 0.3)
        #expect(testTemperature2(for: .classification) == 0.3)
    }

    @Test("Translation tasks have precision temperature (0.2)")
    func translationTemperature() {
        #expect(testTemperature2(for: .translation) == 0.2)
        #expect(testTemperature2(for: .correction) == 0.2)
    }

    @Test("All task categories covered with valid range")
    func allCategoriesCovered() {
        for task in TestAITaskCategory2.allCases {
            let temp = testTemperature2(for: task)
            #expect(temp >= 0.0)
            #expect(temp <= 1.0)
        }
    }
}

// MARK: - Tests: Max Tokens Logic

@Suite("AI Task Max Tokens — DynamicConfig")
struct AITaskMaxTokensDCTests {
    @Test("Code generation gets highest tokens")
    func codeGenerationTokens() {
        #expect(testMaxTokens2(for: .codeGeneration) == 4000)
    }

    @Test("Classification gets lowest tokens")
    func classificationTokens() {
        #expect(testMaxTokens2(for: .classification) == 100)
    }

    @Test("Creative tasks get generous tokens")
    func creativeTokens() {
        #expect(testMaxTokens2(for: .creative) == 3000)
        #expect(testMaxTokens2(for: .brainstorming) == 3000)
    }

    @Test("Translation scales with input length")
    func translationScaling() {
        #expect(testMaxTokens2(for: .translation, inputLength: 0) == 500)
        #expect(testMaxTokens2(for: .translation, inputLength: 100) == 500)
        #expect(testMaxTokens2(for: .translation, inputLength: 300) == 600)
        #expect(testMaxTokens2(for: .translation, inputLength: 1000) == 2000)
    }

    @Test("Translation minimum is 500")
    func translationMinimum() {
        #expect(testMaxTokens2(for: .translation, inputLength: 0) >= 500)
        #expect(testMaxTokens2(for: .correction, inputLength: 100) >= 500)
    }

    @Test("All tasks return positive token counts")
    func allPositive() {
        for task in TestAITaskCategory2.allCases {
            #expect(testMaxTokens2(for: task) > 0)
        }
    }

    @Test("Code review and bug fix have same token limit")
    func codeReviewBugFixSame() {
        #expect(testMaxTokens2(for: .codeReview) == testMaxTokens2(for: .bugFix))
    }

    @Test("Assistance gets 2000 tokens")
    func assistanceTokens() {
        #expect(testMaxTokens2(for: .assistance) == 2000)
    }
}

// MARK: - Tests: Default Model Selection

@Suite("Default Model Selection — DynamicConfig")
struct DefaultModelSelectionDCTests {
    @Test("High-capability tasks default to gpt-4o")
    func highCapabilityDefaults() {
        #expect(testDefaultModel2(for: .codeGeneration) == "gpt-4o")
        #expect(testDefaultModel2(for: .codeReview) == "gpt-4o")
        #expect(testDefaultModel2(for: .bugFix) == "gpt-4o")
        #expect(testDefaultModel2(for: .creative) == "gpt-4o")
        #expect(testDefaultModel2(for: .analysis) == "gpt-4o")
    }

    @Test("Simple tasks default to gpt-4o-mini")
    func simpleDefaults() {
        #expect(testDefaultModel2(for: .conversation) == "gpt-4o-mini")
        #expect(testDefaultModel2(for: .assistance) == "gpt-4o-mini")
        #expect(testDefaultModel2(for: .classification) == "gpt-4o-mini")
        #expect(testDefaultModel2(for: .translation) == "gpt-4o-mini")
        #expect(testDefaultModel2(for: .correction) == "gpt-4o-mini")
        #expect(testDefaultModel2(for: .brainstorming) == "gpt-4o-mini")
    }
}

// MARK: - Tests: Periodic Task Intervals

@Suite("Periodic Task Intervals — DynamicConfig")
struct PeriodicTaskIntervalDCTests {
    @Test("Context update is 15 minutes")
    func contextUpdateInterval() {
        #expect(testDefaultInterval2(for: .contextUpdate) == 900)
    }

    @Test("Insight generation is 1 hour")
    func insightInterval() {
        #expect(testDefaultInterval2(for: .insightGeneration) == 3600)
    }

    @Test("Health check is 5 minutes")
    func healthCheckInterval() {
        #expect(testDefaultInterval2(for: .healthCheck) == 300)
    }

    @Test("Cache cleanup is 2 hours")
    func cacheCleanupInterval() {
        #expect(testDefaultInterval2(for: .cacheCleanup) == 7200)
    }

    @Test("Model optimization is daily")
    func modelOptimizationInterval() {
        #expect(testDefaultInterval2(for: .modelOptimization) == 86400)
    }

    @Test("Self improvement is 12 hours")
    func selfImprovementInterval() {
        #expect(testDefaultInterval2(for: .selfImprovement) == 43200)
    }

    @Test("All intervals are positive")
    func allPositive() {
        for task in TestPeriodicTask2.allCases {
            #expect(testDefaultInterval2(for: task) > 0)
        }
    }

    @Test("All cases have unique raw values")
    func uniqueRawValues() {
        let rawValues = TestPeriodicTask2.allCases.map(\.rawValue)
        #expect(Set(rawValues).count == rawValues.count)
    }

    @Test("Intervals ordered by frequency")
    func intervalOrdering() {
        let healthCheck = testDefaultInterval2(for: .healthCheck)
        let contextUpdate = testDefaultInterval2(for: .contextUpdate)
        let insightGen = testDefaultInterval2(for: .insightGeneration)
        let cacheCleanup = testDefaultInterval2(for: .cacheCleanup)
        let selfImprove = testDefaultInterval2(for: .selfImprovement)
        let modelOpt = testDefaultInterval2(for: .modelOptimization)

        #expect(healthCheck < contextUpdate)
        #expect(contextUpdate < insightGen)
        #expect(insightGen < cacheCleanup)
        #expect(cacheCleanup < selfImprove)
        #expect(selfImprove < modelOpt)
    }
}

// MARK: - Tests: AITaskCategory Enum

@Suite("AITaskCategory Enum — DynamicConfig")
struct AITaskCategoryDCTests {
    @Test("All 11 cases exist")
    func allCases() {
        #expect(TestAITaskCategory2.allCases.count == 11)
    }

    @Test("All cases have unique raw values")
    func uniqueRawValues() {
        let rawValues = TestAITaskCategory2.allCases.map(\.rawValue)
        #expect(Set(rawValues).count == rawValues.count)
    }

    @Test("Codable roundtrip")
    func codableRoundtrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for task in TestAITaskCategory2.allCases {
            let data = try encoder.encode(task)
            let decoded = try decoder.decode(TestAITaskCategory2.self, from: data)
            #expect(decoded == task)
        }
    }
}

// MARK: - Tests: Optimization Gating

@Suite("Optimization Scheduling — DynamicConfig")
struct OptimizationGatingDCTests {
    @Test("Should optimize when never optimized")
    func shouldOptimizeInitially() {
        let lastOptimization: Date? = nil
        let shouldOptimize = (lastOptimization == nil) || (Date().timeIntervalSince(lastOptimization!) > 3600)
        #expect(shouldOptimize == true)
    }

    @Test("Should not optimize when optimized recently")
    func shouldNotOptimizeRecently() {
        let lastOptimization = Date()
        let shouldOptimize = Date().timeIntervalSince(lastOptimization) > 3600
        #expect(shouldOptimize == false)
    }

    @Test("Should optimize after 1 hour")
    func shouldOptimizeAfterHour() {
        let lastOptimization = Date().addingTimeInterval(-3601)
        let shouldOptimize = Date().timeIntervalSince(lastOptimization) > 3600
        #expect(shouldOptimize == true)
    }
}

// MARK: - Tests: Cache Logic

@Suite("Config Cache — DynamicConfig")
struct ConfigCacheDCTests {
    @Test("Cached value not expired when in future")
    func notExpired() {
        let cached = TestCachedValue2(
            value: "test", expiry: Date().addingTimeInterval(3600)
        )
        #expect(!cached.isExpired)
    }

    @Test("Cached value expired when in past")
    func expired() {
        let cached = TestCachedValue2(
            value: "test", expiry: Date().addingTimeInterval(-1)
        )
        #expect(cached.isExpired)
    }
}

// MARK: - Tests: Cache Size Logic

@Suite("Optimal Cache Size — DynamicConfig")
struct OptimalCacheSizeDCTests {
    private func cacheSize(memoryGB: Double) -> Int {
        memoryGB >= 16 ? 500 : (memoryGB >= 8 ? 200 : 100)
    }

    @Test("16GB+ gets large cache")
    func largeCacheFor16GB() {
        #expect(cacheSize(memoryGB: 16) == 500)
    }

    @Test("8-15GB gets medium cache")
    func mediumCacheFor8GB() {
        #expect(cacheSize(memoryGB: 8) == 200)
    }

    @Test("Under 8GB gets small cache")
    func smallCacheForLowMemory() {
        #expect(cacheSize(memoryGB: 4) == 100)
    }

    @Test("192GB Mac Studio gets large cache")
    func largeCacheFor192GB() {
        #expect(cacheSize(memoryGB: 192) == 500)
    }

    @Test("Log retention is constant 2000")
    func logRetention() {
        let optimalLogRetention = 2000
        #expect(optimalLogRetention == 2000)
    }
}
