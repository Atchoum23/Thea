// TaskClassifier.swift
// Thea V2
//
// AI-powered task classification - NO keyword matching, pure semantic understanding
// Enhanced with MemoryManager integration for long-term learning
// Upgraded with semantic embeddings for query similarity (2026 Intelligence Upgrade)

import Accelerate
import Foundation
import OSLog

// MARK: - Task Classifier

/// AI-powered task classification without keyword matching
/// Uses semantic understanding to classify user queries
/// Integrates with MemoryManager for persistent learning across sessions
/// Features semantic embeddings for query similarity matching
@MainActor
public final class TaskClassifier: ObservableObject {
    public static let shared = TaskClassifier()

    let logger = Logger(subsystem: "com.thea.v2", category: "TaskClassifier")

    // MARK: - Configuration

    /// Model to use for classification (fast model preferred)
    public var classificationModel: String = "gpt-4o-mini"

    /// Minimum confidence threshold for accepting classification
    public var confidenceThreshold: Double = 0.6

    /// Domain-aware confidence thresholds (higher for specialized domains)
    public var domainConfidenceThresholds: [TaskType: Double] = [
        .codeGeneration: 0.75,      // Higher threshold for code - mistakes costly
        .codeAnalysis: 0.70,
        .codeDebugging: 0.75,
        .math: 0.70,                // Math requires precision
        .factual: 0.65,             // Facts need verification
        .creative: 0.55,            // Creative is more flexible
        .conversation: 0.50,        // Conversational is flexible
        .system: 0.70               // System commands need accuracy
    ]

    /// Cache recent classifications
    var classificationCache: [String: ClassificationResult] = [:]
    let maxCacheSize = 100

    // MARK: - Semantic Embeddings

    /// Query embeddings cache for similarity matching
    var queryEmbeddings: [String: QueryEmbedding] = [:]
    let maxEmbeddingCacheSize = 500

    /// Prototype embeddings for each task type (learned from examples)
    @Published public internal(set) var taskTypePrototypes: [TaskType: [Float]] = [:]

    /// Enable semantic embedding-based similarity matching
    public var useSemanticEmbeddings: Bool = true

    /// Embedding dimension (default for sentence transformers)
    let embeddingDimension = 384

    // MARK: - Learning

    /// Historical classifications for learning
    @Published public internal(set) var classificationHistory: [ClassificationRecord] = []

    /// Enable AI-powered semantic classification (vs keyword matching fallback)
    public var useSemanticClassification: Bool = true

    /// Learned task patterns from MemoryManager
    @Published public internal(set) var learnedPatterns: [LearnedTaskPattern] = []

    /// Task type performance scores (learned over time)
    @Published public internal(set) var taskTypeScores: [TaskType: Double] = [:]

    /// Confidence calibration data (for calibrating confidence to accuracy)
    var calibrationData: [CalibrationBucket] = []

    // MARK: - Initialization

    private init() {
        initializePrototypeEmbeddings()
        initializeCalibrationBuckets()

        Task {
            await loadLearnedPatterns()
            await loadPrototypeEmbeddingsFromMemory()
        }
    }

    // MARK: - Prototype Embeddings Initialization

    /// Initialize with hand-crafted prototype embeddings (will be refined through learning)
    private func initializePrototypeEmbeddings() {
        // Initialize with random normalized vectors - will be refined through learning
        for taskType in TaskType.allCases {
            taskTypePrototypes[taskType] = createInitialPrototype(for: taskType)
        }
    }

    /// Create initial prototype embedding based on task type characteristics
    private func createInitialPrototype(for taskType: TaskType) -> [Float] {
        // Create a deterministic "seed" embedding based on task type
        // These will be overwritten by learned embeddings
        var embedding = [Float](repeating: 0, count: embeddingDimension)

        // Use task type hash as seed for reproducibility
        let seed = taskType.rawValue.hashValue
        var rng = SeededRandomGenerator(seed: UInt64(bitPattern: Int64(seed)))

        for i in 0..<embeddingDimension {
            embedding[i] = Float.random(in: -1...1, using: &rng)
        }

        // Normalize
        return normalizeVector(embedding)
    }

    /// Initialize calibration buckets for confidence calibration
    private func initializeCalibrationBuckets() {
        // Create 10 buckets for confidence ranges 0-0.1, 0.1-0.2, etc.
        calibrationData = (0..<10).map { i in
            CalibrationBucket(
                rangeStart: Double(i) * 0.1,
                rangeEnd: Double(i + 1) * 0.1
            )
        }
    }

    // MARK: - Classification

    /// Classify a query using AI with semantic embedding support
    /// - Parameter query: The user's query to classify
    /// - Returns: Classification result with task type and confidence
    public func classify(_ query: String) async throws -> ClassificationResult {
        // Check cache first
        let cacheKey = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let cached = classificationCache[cacheKey] {
            logger.debug("Classification cache hit")
            return cached
        }

        let startTime = Date()

        // Try semantic embedding matching first (fast, local)
        if useSemanticEmbeddings {
            if let embeddingResult = await classifyWithEmbedding(query) {
                let domainThreshold = domainConfidenceThresholds[embeddingResult.taskType] ?? confidenceThreshold

                if embeddingResult.confidence >= domainThreshold {
                    logger.debug("Classification via embedding: \(embeddingResult.taskType.rawValue)")
                    cacheResult(embeddingResult, for: cacheKey)

                    // Store embedding for future learning
                    await storeQueryEmbedding(query: query, result: embeddingResult)

                    return embeddingResult
                }
            }
        }

        // Build classification prompt
        let prompt = buildClassificationPrompt(for: query)

        // Get classification from AI
        let response = try await classifyWithAI(prompt: prompt)

        // Parse response
        var result = try parseClassificationResponse(response, for: query)

        // Apply calibrated confidence
        result = applyConfidenceCalibration(result)

        // Cache result
        cacheResult(result, for: cacheKey)

        // Store embedding for future learning
        await storeQueryEmbedding(query: query, result: result)

        // Log event
        let duration = Date().timeIntervalSince(startTime)
        EventBus.shared.logAction(
            .classification,
            target: result.taskType.rawValue,
            parameters: [
                "confidence": String(format: "%.2f", result.confidence),
                "query_length": String(query.count),
                "method": "ai"
            ],
            success: true,
            duration: duration
        )

        logger.info("Classified as \(result.taskType.rawValue) with \(result.confidence) confidence")

        return result
    }

    /// Quick classification without AI (based on patterns learned from history)
    /// Falls back to AI if uncertain
    public func quickClassify(_ query: String) async throws -> ClassificationResult {
        // 1. Try cache first
        let cacheKey = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let cached = classificationCache[cacheKey] {
            logger.debug("Quick classification from cache")
            return cached
        }

        // 2. Try learned patterns from MemoryManager
        let learnedMatches = findMatchingLearnedPatterns(for: query)
        if let best = learnedMatches.first, best.1 >= 0.8 {
            logger.debug("Quick classification from learned pattern: \(best.0.rawValue)")
            let result = ClassificationResult(
                taskType: best.0,
                confidence: best.1,
                reasoning: "Matched learned pattern"
            )
            cacheResult(result, for: cacheKey)
            return result
        }

        // 3. Try to match with session history
        if let match = findHistoricalMatch(for: query) {
            logger.debug("Quick classification from session history")
            return match
        }

        // 4. Fall back to full AI classification
        return try await classify(query)
    }

}
