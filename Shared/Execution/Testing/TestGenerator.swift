// TestGenerator.swift
// Thea V2
//
// AI-powered test generation
// Generates unit tests, edge cases, and coverage gap analysis

import Foundation
import OSLog

// MARK: - Test Generator

/// AI-powered test generator
@MainActor
@Observable
public final class TestGenerator {
    public static let shared = TestGenerator()

    private let logger = Logger(subsystem: "com.thea.testing", category: "TestGenerator")

    // MARK: - State

    private(set) var isGenerating = false
    private(set) var recentGenerations: [TestGenerationResult] = []

    // MARK: - Configuration

    /// Preferred test style (BDD vs traditional)
    public var preferBDDStyle: Bool = true

    /// Include descriptive comments
    public var includeComments: Bool = true

    /// Generate mock objects when needed
    public var generateMocks: Bool = true

    private init() {}

    // MARK: - Test Generation

    /// Generate tests for source code
    public func generateTests(
        request: TestGenerationRequest,
        progressHandler: (@Sendable (TestGenerationProgress) -> Void)? = nil
    ) async throws -> TestGenerationResult {
        guard !isGenerating else {
            throw TestGeneratorError.alreadyGenerating
        }

        isGenerating = true
        defer { isGenerating = false }

        let startTime = Date()
        logger.info("Starting test generation for \(request.filePath)")

        progressHandler?(TestGenerationProgress(
            phase: .analyzing,
            message: "Analyzing source code",
            progress: 0.1
        ))

        let analysis = analyzeSourceCode(request.sourceCode, language: request.language)

        let aiResponse = try await fetchAIResponse(
            request: request,
            analysis: analysis,
            progressHandler: progressHandler
        )

        let result = buildResult(
            from: aiResponse,
            request: request,
            analysis: analysis,
            startTime: startTime,
            progressHandler: progressHandler
        )

        storeResult(result)

        progressHandler?(TestGenerationProgress(
            phase: .completed,
            message: "Generated \(result.generatedTests.count) tests",
            progress: 1.0
        ))

        logger.info("Generated \(result.generatedTests.count) tests in \(String(format: "%.2f", result.generationTime))s")

        return result
    }

    /// Generate tests for a specific function
    public func generateTestsForFunction(
        function: String,
        sourceCode: String,
        language: ProgrammingLanguage
    ) async throws -> [GeneratedTest] {
        let request = TestGenerationRequest(
            sourceCode: sourceCode,
            filePath: "function_test",
            language: language,
            maxTests: 5
        )

        let result = try await generateTests(request: request)
        return result.generatedTests.filter { $0.targetFunction == function }
    }

    // MARK: - Private Helpers

    private func fetchAIResponse(
        request: TestGenerationRequest,
        analysis: SourceAnalysis,
        progressHandler: (@Sendable (TestGenerationProgress) -> Void)?
    ) async throws -> String {
        guard let provider = ProviderRegistry.shared.getDefaultProvider() ??
              ProviderRegistry.shared.configuredProviders.first else {
            throw TestGeneratorError.noProviderAvailable
        }

        progressHandler?(TestGenerationProgress(
            phase: .generating,
            message: "Generating tests with AI",
            progress: 0.3
        ))

        let prompt = buildTestGenerationPrompt(request: request, analysis: analysis)

        let userMessage = AIMessage(
            id: UUID(),
            conversationID: UUID(),
            role: .user,
            content: .text(prompt),
            timestamp: Date(),
            model: ""
        )
        let model = AppConfiguration.shared.providerConfig.defaultModel
        let stream = try await provider.chat(
            messages: [userMessage],
            model: model.isEmpty ? "gpt-4" : model,
            stream: true
        )

        var aiResponse = ""
        for try await chunk in stream {
            switch chunk.type {
            case .delta(let text):
                aiResponse += text
            case .complete:
                break
            case .error(let error):
                throw error
            }
        }

        return aiResponse
    }

    private func buildResult(
        from aiResponse: String,
        request: TestGenerationRequest,
        analysis: SourceAnalysis,
        startTime: Date,
        progressHandler: (@Sendable (TestGenerationProgress) -> Void)?
    ) -> TestGenerationResult {
        progressHandler?(TestGenerationProgress(
            phase: .parsing,
            message: "Parsing generated tests",
            progress: 0.7
        ))

        let generatedTests = parseGeneratedTests(
            response: aiResponse,
            language: request.language,
            focusAreas: request.focusAreas
        )

        progressHandler?(TestGenerationProgress(
            phase: .formatting,
            message: "Formatting test file",
            progress: 0.9
        ))

        let testFileContent = generateTestFile(
            tests: generatedTests,
            request: request,
            analysis: analysis
        )

        let coverageAnalysis = analyzeCoverageGaps(
            sourceAnalysis: analysis,
            existingTests: request.existingTests,
            generatedTests: generatedTests
        )

        let suggestedFilePath = suggestTestFilePath(for: request.filePath, language: request.language)

        return TestGenerationResult(
            request: request,
            generatedTests: generatedTests,
            testFileContent: testFileContent,
            suggestedFilePath: suggestedFilePath,
            coverageAnalysis: coverageAnalysis,
            generationTime: Date().timeIntervalSince(startTime)
        )
    }

    private func storeResult(_ result: TestGenerationResult) {
        recentGenerations.insert(result, at: 0)
        if recentGenerations.count > 20 {
            recentGenerations.removeLast()
        }
    }
}
