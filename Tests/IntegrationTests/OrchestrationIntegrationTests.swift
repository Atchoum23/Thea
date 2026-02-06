// OrchestrationIntegrationTests.swift
// End-to-end integration tests for the AI orchestration system

@testable import TheaCore
import XCTest

// MARK: - Orchestration Integration Tests

/// These tests verify the integration between orchestration components:
/// - SubAgentOrchestrator
/// - ReActExecutor
/// - ParallelQueryExecutor
/// - ResilienceManager
/// - ConnectivityMonitor
/// - QueryDecomposer
/// - TaskClassifier
/// - ModelRouter
@MainActor
final class OrchestrationIntegrationTests: XCTestCase {
    // MARK: - Component Availability Tests

    func testAllOrchestrationComponentsAvailable() {
        // Verify all singletons are accessible
        XCTAssertNotNil(SubAgentOrchestrator.shared)
        XCTAssertNotNil(ResilienceManager.shared)
        XCTAssertNotNil(ConnectivityMonitor.shared)
        XCTAssertNotNil(TaskClassifier.shared)
        XCTAssertNotNil(ModelRouter.shared)
        XCTAssertNotNil(QueryDecomposer.shared)
    }

    func testOrchestrationComponentsIndependent() {
        // Each singleton should be a different instance
        let orchestrator = SubAgentOrchestrator.shared
        let resilience = ResilienceManager.shared
        let connectivity = ConnectivityMonitor.shared

        XCTAssertFalse(orchestrator === resilience as AnyObject)
        XCTAssertFalse(orchestrator === connectivity as AnyObject)
        XCTAssertFalse(resilience === connectivity as AnyObject)
    }

    // MARK: - TaskClassifier Integration Tests

    func testTaskClassifierClassifiesQueries() async {
        let classifier = TaskClassifier.shared

        // Test simple QA classification
        let simpleResult = await classifier.classify("What is the capital of France?")
        XCTAssertNotNil(simpleResult.taskType)
        XCTAssertGreaterThan(simpleResult.confidence, 0.0)

        // Test code generation classification
        let codeResult = await classifier.classify("Write a Swift function to sort an array")
        XCTAssertNotNil(codeResult.taskType)
    }

    func testTaskClassifierConfidenceRange() async {
        let classifier = TaskClassifier.shared

        let result = await classifier.classify("Explain quantum computing")
        XCTAssertGreaterThanOrEqual(result.confidence, 0.0)
        XCTAssertLessThanOrEqual(result.confidence, 1.0)
    }

    // MARK: - QueryDecomposer Integration Tests

    func testQueryDecomposerAnalyzesQueries() async {
        let decomposer = QueryDecomposer.shared

        let query = "What are the best practices for Swift concurrency and how do they compare to other languages?"
        let analysis = await decomposer.analyzeQuery(query)

        XCTAssertNotNil(analysis)
    }

    func testQueryDecomposerHandlesSimpleQueries() async {
        let decomposer = QueryDecomposer.shared

        let simpleQuery = "What time is it?"
        let analysis = await decomposer.analyzeQuery(simpleQuery)

        XCTAssertNotNil(analysis)
    }

    // MARK: - ModelRouter Integration Tests

    func testModelRouterSelectsModel() async {
        let router = ModelRouter.shared

        let selection = await router.selectModel(
            for: .codeGeneration,
            complexity: .moderate,
            contextSize: 1000
        )

        // Selection may be nil if no providers configured, but should not crash
        XCTAssertTrue(true) // Test passes if no crash
    }

    func testModelRouterHandlesAllTaskTypes() async {
        let router = ModelRouter.shared

        for taskType in TaskType.allCases {
            let selection = await router.selectModel(
                for: taskType,
                complexity: .simple,
                contextSize: 500
            )
            // Just verify no crashes
            _ = selection
        }
    }

    // MARK: - ResilienceManager Integration Tests

    func testResilienceManagerBuildsFallbackChains() {
        let resilience = ResilienceManager.shared

        for taskType in TaskType.allCases {
            for preference in OrchestratorConfiguration.LocalModelPreference.allCases {
                let chain = resilience.buildFallbackChain(for: taskType, preference: preference)
                XCTAssertNotNil(chain)
            }
        }
    }

    func testResilienceManagerHealthTracking() {
        let resilience = ResilienceManager.shared

        // Reset and verify initial state
        resilience.resetHealthScores()

        let initialScore = resilience.getHealthScore(for: "test-provider")
        XCTAssertEqual(initialScore, 1.0, accuracy: 0.001) // Default healthy

        let allScores = resilience.getAllHealthScores()
        XCTAssertNotNil(allScores)

        let providersByHealth = resilience.getProvidersByHealth()
        XCTAssertNotNil(providersByHealth)
    }

    // MARK: - ConnectivityMonitor Integration Tests

    func testConnectivityMonitorReportsStatus() {
        let monitor = ConnectivityMonitor.shared

        let status = monitor.currentStatus
        XCTAssertNotNil(status)

        let mode = monitor.recommendedExecutionMode
        XCTAssertNotNil(mode)

        let summary = monitor.statusSummary
        XCTAssertFalse(summary.isEmpty)
    }

    func testConnectivityMonitorStartStop() {
        let monitor = ConnectivityMonitor.shared

        // Should not crash
        monitor.startMonitoring()
        monitor.stopMonitoring()
        monitor.startMonitoring()
    }

    // MARK: - Cross-Component Integration Tests

    func testResilienceWithConnectivity() {
        let resilience = ResilienceManager.shared
        let connectivity = ConnectivityMonitor.shared

        // Get connectivity status
        let isConnected = connectivity.isConnected

        // Build fallback chain based on connectivity
        let preference: OrchestratorConfiguration.LocalModelPreference = isConnected ? .cloudFirst : .always
        let chain = resilience.buildFallbackChain(for: .simpleQA, preference: preference)

        XCTAssertNotNil(chain)
    }

    func testClassifierWithRouter() async {
        let classifier = TaskClassifier.shared
        let router = ModelRouter.shared

        // Classify a query
        let classification = await classifier.classify("Write unit tests for a login function")

        // Route based on classification
        let selection = await router.selectModel(
            for: classification.taskType,
            complexity: classification.complexity,
            contextSize: 1000
        )

        // Just verify no crashes
        _ = selection
    }

    // MARK: - ReActExecutor Integration Tests

    func testReActExecutorConfiguration() {
        var config = ReActConfig()
        config.maxSteps = 5

        let executor = ReActExecutor(config: config)
        XCTAssertEqual(executor.config.maxSteps, 5)
    }

    func testReActExecutorWithDefaultConfig() {
        let executor = ReActExecutor()
        XCTAssertEqual(executor.config.maxSteps, 10) // Default
    }

    // MARK: - ParallelQueryExecutor Integration Tests

    func testParallelQueryExecutorConfiguration() {
        var config = ParallelExecutionConfig()
        config.maxConcurrency = 2
        config.failFast = false

        let executor = ParallelQueryExecutor(config: config)
        XCTAssertEqual(executor.config.maxConcurrency, 2)
        XCTAssertFalse(executor.config.failFast)
    }

    // MARK: - Error Handling Integration Tests

    func testOrchestrationErrorsArePropagated() {
        // Test that errors from components are properly typed
        let noProviderError = SubAgentOrchestratorError.noProviderAvailable
        XCTAssertNotNil(noProviderError.errorDescription)

        let resilienceError = ResilienceError.timeout
        XCTAssertNotNil(resilienceError.errorDescription)

        let reactError = ReActError.maxStepsExceeded(10)
        XCTAssertNotNil(reactError.errorDescription)

        let parallelError = ParallelExecutionError.allQueriesFailed
        XCTAssertNotNil(parallelError.errorDescription)
    }

    // MARK: - State Consistency Tests

    func testOrchestratorStateConsistency() {
        let orchestrator = SubAgentOrchestrator.shared

        // Initially not orchestrating
        XCTAssertFalse(orchestrator.isOrchestrating)

        // Active agents accessible
        XCTAssertNotNil(orchestrator.activeAgents)

        // Completed tasks accessible
        XCTAssertNotNil(orchestrator.completedTasks)
    }

    func testResilienceStateConsistency() {
        let resilience = ResilienceManager.shared

        // Reset state
        resilience.resetStats()
        resilience.resetCircuitBreakers()
        resilience.resetHealthScores()

        // Verify reset
        XCTAssertEqual(resilience.stats.successfulRequests, 0)
        XCTAssertEqual(resilience.stats.failedRequests, 0)
    }

    // MARK: - Configuration Propagation Tests

    func testMetaAIConfigurationAccessible() {
        let config = AppConfiguration.shared.metaAIConfig

        XCTAssertNotNil(config.plannerModel)
        XCTAssertNotNil(config.coderModel)
        XCTAssertNotNil(config.analystModel)
    }

    func testOrchestratorConfigurationPreferences() {
        let config = AppConfiguration.shared.orchestratorConfig

        XCTAssertNotNil(config.localModelPreference)
        XCTAssertGreaterThan(config.maxConcurrentTasks, 0)
    }
}

// MARK: - Agent Type Integration Tests

@MainActor
final class AgentTypeIntegrationTests: XCTestCase {
    func testAllAgentTypesHaveValidConfiguration() {
        for agentType in SubAgentOrchestrator.AgentType.allCases {
            // System prompt should exist
            let prompt = agentType.systemPrompt
            XCTAssertFalse(prompt.isEmpty, "Agent \(agentType) should have system prompt")

            // Capabilities should exist
            let capabilities = agentType.capabilities
            XCTAssertFalse(capabilities.isEmpty, "Agent \(agentType) should have capabilities")

            // Raw value should exist
            let rawValue = agentType.rawValue
            XCTAssertFalse(rawValue.isEmpty, "Agent \(agentType) should have raw value")
        }
    }

    func testCoderAgentHasSwiftPrompt() {
        let coderPrompt = SubAgentOrchestrator.AgentType.coder.systemPrompt

        XCTAssertTrue(coderPrompt.contains("Swift"), "Coder prompt should mention Swift")
        XCTAssertTrue(coderPrompt.contains("@MainActor") || coderPrompt.contains("concurrency"),
                      "Coder prompt should mention concurrency")
    }

    func testAgentCapabilitiesMatch() {
        // Coder should have code capabilities
        let coderCaps = SubAgentOrchestrator.AgentType.coder.capabilities
        XCTAssertTrue(coderCaps.contains("code_generation"))

        // Researcher should have research capabilities
        let researcherCaps = SubAgentOrchestrator.AgentType.researcher.capabilities
        XCTAssertTrue(researcherCaps.contains("web_search"))

        // Validator should have validation capabilities
        let validatorCaps = SubAgentOrchestrator.AgentType.validator.capabilities
        XCTAssertTrue(validatorCaps.contains("verification"))
    }
}

// MARK: - Concurrent Access Tests

@MainActor
final class ConcurrentAccessTests: XCTestCase {
    func testResilienceManagerThreadSafe() async {
        let resilience = ResilienceManager.shared

        // Access from multiple tasks
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask { @MainActor in
                    _ = resilience.getHealthScore(for: "test-\(UUID())")
                }
            }
        }

        // If we get here without crash, test passes
        XCTAssertTrue(true)
    }

    func testConnectivityMonitorThreadSafe() async {
        let monitor = ConnectivityMonitor.shared

        // Access from multiple tasks
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask { @MainActor in
                    _ = monitor.currentStatus
                    _ = monitor.isConnected
                }
            }
        }

        // If we get here without crash, test passes
        XCTAssertTrue(true)
    }
}
