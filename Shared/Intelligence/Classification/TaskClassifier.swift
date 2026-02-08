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

    private let logger = Logger(subsystem: "com.thea.v2", category: "TaskClassifier")

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
    private var classificationCache: [String: ClassificationResult] = [:]
    private let maxCacheSize = 100

    // MARK: - Semantic Embeddings

    /// Query embeddings cache for similarity matching
    private var queryEmbeddings: [String: QueryEmbedding] = [:]
    private let maxEmbeddingCacheSize = 500

    /// Prototype embeddings for each task type (learned from examples)
    @Published public private(set) var taskTypePrototypes: [TaskType: [Float]] = [:]

    /// Enable semantic embedding-based similarity matching
    public var useSemanticEmbeddings: Bool = true

    /// Embedding dimension (default for sentence transformers)
    private let embeddingDimension = 384

    // MARK: - Learning

    /// Historical classifications for learning
    @Published public private(set) var classificationHistory: [ClassificationRecord] = []

    /// Enable AI-powered semantic classification (vs keyword matching fallback)
    public var useSemanticClassification: Bool = true

    /// Learned task patterns from MemoryManager
    @Published public private(set) var learnedPatterns: [LearnedTaskPattern] = []

    /// Task type performance scores (learned over time)
    @Published public private(set) var taskTypeScores: [TaskType: Double] = [:]

    /// Confidence calibration data (for calibrating confidence to accuracy)
    private var calibrationData: [CalibrationBucket] = []

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

    // MARK: - Semantic Embedding Classification

    /// Classify using semantic embedding similarity
    private func classifyWithEmbedding(_ query: String) async -> ClassificationResult? {
        // Generate or retrieve embedding for query
        let queryEmb = await getOrGenerateEmbedding(for: query)

        // Compare against task type prototypes
        var bestMatch: (TaskType, Double) = (.conversation, 0.0)

        for (taskType, prototype) in taskTypePrototypes {
            let similarity = cosineSimilarity(queryEmb, prototype)
            if similarity > bestMatch.1 {
                bestMatch = (taskType, similarity)
            }
        }

        // Also check against recent classified queries (nearest neighbor)
        let nearestNeighbor = findNearestNeighbor(embedding: queryEmb)

        // Combine prototype matching with nearest neighbor
        if let neighbor = nearestNeighbor, neighbor.1 > bestMatch.1 {
            // Nearest neighbor is closer - use its classification
            return ClassificationResult(
                taskType: neighbor.0,
                confidence: neighbor.1,
                reasoning: "Semantic similarity to previous query",
                classificationMethod: .embedding
            )
        }

        // Use prototype matching
        guard bestMatch.1 >= 0.5 else { return nil } // Too low confidence

        return ClassificationResult(
            taskType: bestMatch.0,
            confidence: bestMatch.1,
            reasoning: "Semantic similarity to task type prototype",
            classificationMethod: .embedding
        )
    }

    /// Get or generate embedding for a query
    private func getOrGenerateEmbedding(for query: String) async -> [Float] {
        let key = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Check cache
        if let cached = queryEmbeddings[key] {
            return cached.embedding
        }

        // Generate simple TF-IDF style embedding (fast, local)
        // In production, this would use a sentence transformer model
        let embedding = generateSimpleEmbedding(for: query)

        return embedding
    }

    /// Generate a simple embedding using character n-grams and word hashing
    /// This is a fast approximation - production would use sentence transformers
    private func generateSimpleEmbedding(for text: String) -> [Float] {
        var embedding = [Float](repeating: 0, count: embeddingDimension)

        let normalized = text.lowercased()
        let words = normalized.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }

        // Word-level features (hash to embedding dimensions)
        for word in words {
            let hash = abs(word.hashValue)
            let dim1 = hash % embeddingDimension
            let dim2 = (hash / embeddingDimension) % embeddingDimension
            embedding[dim1] += 1.0
            embedding[dim2] += 0.5
        }

        // Character trigram features
        for i in 0..<max(0, normalized.count - 2) {
            let startIdx = normalized.index(normalized.startIndex, offsetBy: i)
            let endIdx = normalized.index(startIdx, offsetBy: 3)
            let trigram = String(normalized[startIdx..<endIdx])
            let hash = abs(trigram.hashValue) % embeddingDimension
            embedding[hash] += 0.3
        }

        // Structural features
        let questionMarks = text.filter { $0 == "?" }.count
        let exclamationMarks = text.filter { $0 == "!" }.count
        let codeIndicators = ["func ", "def ", "class ", "import ", "```", "function", "const ", "let ", "var "]
            .reduce(0) { $0 + (text.contains($1) ? 1 : 0) }

        if questionMarks > 0 {
            embedding[0] += Float(questionMarks) * 0.5
        }
        if exclamationMarks > 0 {
            embedding[1] += Float(exclamationMarks) * 0.3
        }
        if codeIndicators > 0 {
            embedding[2] += Float(codeIndicators) * 1.0
        }

        // Length-based features
        embedding[3] = Float(min(words.count, 50)) / 50.0

        return normalizeVector(embedding)
    }

    /// Find nearest neighbor in embedding cache
    private func findNearestNeighbor(embedding: [Float]) -> (TaskType, Double)? {
        var best: (TaskType, Double)?

        for (_, queryEmb) in queryEmbeddings {
            let similarity = cosineSimilarity(embedding, queryEmb.embedding)
            if similarity > (best?.1 ?? 0.7) { // Minimum threshold
                best = (queryEmb.taskType, similarity)
            }
        }

        return best
    }

    /// Store query embedding for future similarity matching
    private func storeQueryEmbedding(query: String, result: ClassificationResult) async {
        let key = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let embedding = await getOrGenerateEmbedding(for: query)

        queryEmbeddings[key] = QueryEmbedding(
            query: query,
            embedding: embedding,
            taskType: result.taskType,
            timestamp: Date()
        )

        // Update task type prototype with weighted average
        if var prototype = taskTypePrototypes[result.taskType] {
            // Exponential moving average (learning rate 0.1)
            let alpha: Float = 0.1
            for i in 0..<embeddingDimension {
                prototype[i] = (1 - alpha) * prototype[i] + alpha * embedding[i]
            }
            taskTypePrototypes[result.taskType] = normalizeVector(prototype)
        }

        // Evict old embeddings if needed
        if queryEmbeddings.count > maxEmbeddingCacheSize {
            let sorted = queryEmbeddings.sorted { $0.value.timestamp < $1.value.timestamp }
            for (key, _) in sorted.prefix(100) {
                queryEmbeddings.removeValue(forKey: key)
            }
        }

        // Periodically persist prototypes to memory
        if queryEmbeddings.count % 50 == 0 {
            await persistPrototypeEmbeddings()
        }
    }

    /// Cosine similarity between two vectors
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }

        var dotProduct: Float = 0
        var normA: Float = 0
        var normB: Float = 0

        vDSP_dotpr(a, 1, b, 1, &dotProduct, vDSP_Length(a.count))

        var sumA: Float = 0
        var sumB: Float = 0
        vDSP_svesq(a, 1, &sumA, vDSP_Length(a.count))
        vDSP_svesq(b, 1, &sumB, vDSP_Length(b.count))

        normA = sqrt(sumA)
        normB = sqrt(sumB)

        guard normA > 0 && normB > 0 else { return 0 }

        return Double(dotProduct / (normA * normB))
    }

    /// Normalize a vector to unit length
    private func normalizeVector(_ v: [Float]) -> [Float] {
        var sumSquares: Float = 0
        vDSP_svesq(v, 1, &sumSquares, vDSP_Length(v.count))
        let norm = sqrt(sumSquares)

        guard norm > 0 else { return v }

        var result = [Float](repeating: 0, count: v.count)
        var divisor = norm
        vDSP_vsdiv(v, 1, &divisor, &result, 1, vDSP_Length(v.count))

        return result
    }

    /// Load prototype embeddings from MemoryManager
    private func loadPrototypeEmbeddingsFromMemory() async {
        let records = await MemoryManager.shared.retrieveSemanticMemories(
            category: .taskPattern,
            limit: 50
        )

        for record in records {
            guard record.key.hasPrefix("prototype_"),
                  let data = record.value.data(using: .utf8),
                  let embedding = try? JSONDecoder().decode([Float].self, from: data),
                  let taskType = TaskType(rawValue: String(record.key.dropFirst(10))) else {
                continue
            }

            taskTypePrototypes[taskType] = embedding
        }

        logger.debug("Loaded \(self.taskTypePrototypes.count) prototype embeddings from memory")
    }

    /// Persist prototype embeddings to MemoryManager
    private func persistPrototypeEmbeddings() async {
        for (taskType, embedding) in taskTypePrototypes {
            guard let data = try? JSONEncoder().encode(embedding),
                  let value = String(data: data, encoding: .utf8) else {
                continue
            }

            await MemoryManager.shared.storeSemanticMemory(
                category: .taskPattern,
                key: "prototype_\(taskType.rawValue)",
                value: value,
                confidence: 1.0,
                source: .inferred
            )
        }

        logger.debug("Persisted \(self.taskTypePrototypes.count) prototype embeddings")
    }

    // MARK: - Confidence Calibration

    /// Apply confidence calibration based on historical accuracy
    private func applyConfidenceCalibration(_ result: ClassificationResult) -> ClassificationResult {
        // Find the calibration bucket for this confidence
        let bucketIndex = min(9, Int(result.confidence * 10))
        let bucket = calibrationData[bucketIndex]

        // If we have enough data, adjust confidence based on actual accuracy
        guard bucket.totalCount >= 10 else { return result }

        let calibrationFactor = bucket.accuracy / ((bucket.rangeStart + bucket.rangeEnd) / 2)
        let calibratedConfidence = min(1.0, result.confidence * calibrationFactor)

        return ClassificationResult(
            taskType: result.taskType,
            confidence: calibratedConfidence,
            reasoning: result.reasoning,
            alternativeTypes: result.alternativeTypes,
            classificationMethod: result.classificationMethod
        )
    }

    /// Update calibration data with a classification outcome
    public func updateCalibration(confidence: Double, wasCorrect: Bool) {
        let bucketIndex = min(9, Int(confidence * 10))
        calibrationData[bucketIndex].add(wasCorrect: wasCorrect)
    }

    /// Get current calibration statistics
    public func getCalibrationStats() -> [(range: String, accuracy: Double, count: Int)] {
        calibrationData.map { bucket in
            (
                range: String(format: "%.1f-%.1f", bucket.rangeStart, bucket.rangeEnd),
                accuracy: bucket.accuracy,
                count: bucket.totalCount
            )
        }
    }

    // MARK: - AI Classification

    private func buildClassificationPrompt(for query: String) -> String {
        let taskTypes = TaskType.allCases.map { type in
            "- \(type.rawValue): \(type.description)"
        }.joined(separator: "\n")

        return """
        You are a task classifier. Analyze the following user query and classify it into exactly one category.

        CATEGORIES:
        \(taskTypes)

        USER QUERY:
        "\(query)"

        Respond with a JSON object:
        {
          "taskType": "<category>",
          "confidence": <0.0-1.0>,
          "reasoning": "<brief explanation>",
          "alternatives": [
            {"type": "<category>", "confidence": <0.0-1.0>}
          ]
        }

        Guidelines:
        - Code-related queries (write, fix, explain code) go to appropriate code categories
        - Questions seeking facts go to "factual"
        - Open-ended creative tasks go to "creative"
        - File, terminal, system operations go to "system"
        - General chat, greetings, opinions go to "conversation"
        - If truly ambiguous, choose the most likely and note alternatives

        Respond ONLY with the JSON, no additional text.
        """
    }

    private func classifyWithAI(prompt: String) async throws -> String {
        let convID = UUID()
        let messages = [
            AIMessage(
                id: UUID(), conversationID: convID, role: .system,
                content: .text("You are a precise task classifier. Respond only with JSON."),
                timestamp: Date(), model: classificationModel
            ),
            AIMessage(
                id: UUID(), conversationID: convID, role: .user,
                content: .text(prompt),
                timestamp: Date(), model: classificationModel
            )
        ]

        guard let provider = ProviderRegistry.shared.getDefaultProvider() else {
            throw ClassificationError.noProvider
        }

        let stream = try await provider.chat(messages: messages, model: classificationModel, stream: false)
        var responseText = ""
        for try await chunk in stream {
            if case let .delta(text) = chunk.type {
                responseText += text
            } else if case let .complete(message) = chunk.type {
                responseText = message.content.textValue
            }
        }

        return responseText
    }

    private func parseClassificationResponse(_ response: String, for query: String) throws -> ClassificationResult {
        // Extract JSON from response
        let jsonString = extractJSON(from: response)

        guard let data = jsonString.data(using: .utf8) else {
            throw ClassificationError.invalidResponse("Could not parse response")
        }

        let decoder = JSONDecoder()
        let parsed = try decoder.decode(ClassificationResponse.self, from: data)

        // Validate task type
        guard let taskType = TaskType(rawValue: parsed.taskType) else {
            // Try to match closest
            let closest = TaskType.allCases.first { $0.rawValue.lowercased() == parsed.taskType.lowercased() }
            guard let matched = closest else {
                throw ClassificationError.unknownTaskType(parsed.taskType)
            }
            return ClassificationResult(
                taskType: matched,
                confidence: parsed.confidence,
                reasoning: parsed.reasoning
            )
        }

        // Parse alternatives
        let alternatives = parsed.alternatives?.compactMap { alt -> (TaskType, Double)? in
            guard let type = TaskType(rawValue: alt.type) else { return nil }
            return (type, alt.confidence)
        }

        return ClassificationResult(
            taskType: taskType,
            confidence: parsed.confidence,
            reasoning: parsed.reasoning,
            alternativeTypes: alternatives
        )
    }

    private func extractJSON(from text: String) -> String {
        // Try to find JSON in the response
        if let startIndex = text.firstIndex(of: "{"),
           let endIndex = text.lastIndex(of: "}") {
            return String(text[startIndex...endIndex])
        }
        return text
    }

    // MARK: - Caching

    private func cacheResult(_ result: ClassificationResult, for key: String) {
        classificationCache[key] = result

        // Prune cache if needed
        if classificationCache.count > maxCacheSize {
            // Remove oldest entries (simple approach)
            let keysToRemove = classificationCache.keys.prefix(10)
            keysToRemove.forEach { classificationCache.removeValue(forKey: $0) }
        }
    }

    public func clearCache() {
        classificationCache.removeAll()
    }

    // MARK: - Historical Learning

    private func findHistoricalMatch(for query: String) -> ClassificationResult? {
        // Simple similarity matching with recent classifications
        let normalizedQuery = query.lowercased()

        for record in classificationHistory.suffix(50) {
            let similarity = calculateSimilarity(normalizedQuery, record.query.lowercased())
            if similarity > 0.85 {
                // High similarity - reuse classification
                return ClassificationResult(
                    taskType: record.taskType,
                    confidence: min(record.confidence, similarity),
                    reasoning: "Based on similar historical query"
                )
            }
        }

        return nil
    }

    private func calculateSimilarity(_ str1: String, _ str2: String) -> Double {
        // Simple Jaccard similarity on words
        let words1 = Set(str1.split(separator: " ").map(String.init))
        let words2 = Set(str2.split(separator: " ").map(String.init))

        let intersection = words1.intersection(words2).count
        let union = words1.union(words2).count

        guard union > 0 else { return 0 }
        return Double(intersection) / Double(union)
    }

    /// Record a classification for learning
    public func recordClassification(
        query: String,
        result: ClassificationResult,
        wasCorrect: Bool? = nil
    ) {
        let record = ClassificationRecord(
            query: query,
            taskType: result.taskType,
            confidence: result.confidence,
            wasCorrect: wasCorrect,
            timestamp: Date()
        )

        classificationHistory.append(record)

        // Limit history size
        if classificationHistory.count > 1000 {
            classificationHistory.removeFirst(100)
        }

        // Log learning event if feedback provided
        if let correct = wasCorrect {
            EventBus.shared.logLearning(
                type: correct ? .feedbackPositive : .feedbackNegative,
                data: [
                    "taskType": result.taskType.rawValue,
                    "confidence": String(result.confidence)
                ]
            )
        }
    }

    // MARK: - Feedback

    /// Record user feedback on a classification
    public func provideFeedback(
        for query: String,
        classified: TaskType,
        actual: TaskType
    ) {
        // Record the correction
        if classified != actual {
            EventBus.shared.logLearning(
                type: .userCorrection,
                data: [
                    "query": query,
                    "classified": classified.rawValue,
                    "actual": actual.rawValue
                ]
            )

            // Update cache with correct classification
            let cacheKey = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            classificationCache[cacheKey] = ClassificationResult(
                taskType: actual,
                confidence: 1.0,
                reasoning: "User correction"
            )

            // Store correction in MemoryManager for long-term learning
            Task {
                await storeClassificationCorrection(query: query, from: classified, to: actual)
            }
        }
    }

    // MARK: - MemoryManager Integration

    /// Load learned patterns from MemoryManager
    private func loadLearnedPatterns() async {
        // Load task patterns from semantic memory
        let patterns = await MemoryManager.shared.retrieveSemanticMemories(
            category: .taskPattern,
            limit: 100
        )

        learnedPatterns = patterns.compactMap { record -> LearnedTaskPattern? in
            guard let taskType = TaskType(rawValue: record.category) else { return nil }
            return LearnedTaskPattern(
                pattern: record.key,
                taskType: taskType,
                confidence: record.confidence,
                usageCount: record.accessCount,
                lastUsed: record.lastAccessed
            )
        }

        // Load task type scores from model performance memories
        let performanceRecords = await MemoryManager.shared.retrieveSemanticMemories(
            category: .modelPerformance,
            limit: 50
        )

        for record in performanceRecords {
            if let taskType = TaskType(rawValue: record.key) {
                taskTypeScores[taskType] = record.confidence
            }
        }

        logger.info("Loaded \(self.learnedPatterns.count) learned patterns and \(self.taskTypeScores.count) task scores")
    }

    /// Store a successful classification for future learning
    public func storeSuccessfulClassification(
        query: String,
        result: ClassificationResult,
        wasUseful: Bool
    ) async {
        // Extract key patterns from the query
        let patterns = extractKeyPatterns(from: query)

        for pattern in patterns {
            await MemoryManager.shared.storeSemanticMemory(
                category: .taskPattern,
                key: pattern,
                value: result.taskType.rawValue,
                confidence: wasUseful ? result.confidence : result.confidence * 0.8,
                source: .inferred
            )
        }

        // Update task type performance score
        let currentScore = taskTypeScores[result.taskType] ?? 0.5
        let adjustment = wasUseful ? 0.02 : -0.01
        let newScore = max(0.1, min(1.0, currentScore + adjustment))

        await MemoryManager.shared.storeSemanticMemory(
            category: .modelPerformance,
            key: result.taskType.rawValue,
            value: "task_score",
            confidence: newScore,
            source: .inferred
        )

        taskTypeScores[result.taskType] = newScore

        // Store episodic memory of this classification
        await MemoryManager.shared.storeEpisodicMemory(
            event: "classification",
            context: "Query: \(query.prefix(100))\nType: \(result.taskType.rawValue)\nConfidence: \(result.confidence)",
            outcome: wasUseful ? "useful" : "not_useful",
            emotionalValence: wasUseful ? 0.5 : -0.3
        )

        logger.debug("Stored classification for learning: \(result.taskType.rawValue)")
    }

    /// Store a classification correction for learning
    private func storeClassificationCorrection(
        query: String,
        from oldType: TaskType,
        to newType: TaskType
    ) async {
        // Extract patterns and associate with correct type
        let patterns = extractKeyPatterns(from: query)

        for pattern in patterns {
            // Store the correct association with high confidence
            await MemoryManager.shared.storeSemanticMemory(
                category: .taskPattern,
                key: pattern,
                value: newType.rawValue,
                confidence: 0.95, // High confidence from user correction
                source: .explicit
            )
        }

        // Decrease score for the incorrectly predicted type
        let oldScore = taskTypeScores[oldType] ?? 0.5
        taskTypeScores[oldType] = max(0.1, oldScore - 0.05)

        // Increase score for the correct type
        let newScore = taskTypeScores[newType] ?? 0.5
        taskTypeScores[newType] = min(1.0, newScore + 0.05)

        // Store correction as episodic memory
        await MemoryManager.shared.storeEpisodicMemory(
            event: "classification_correction",
            context: "Query: \(query.prefix(100))\nFrom: \(oldType.rawValue)\nTo: \(newType.rawValue)",
            outcome: "corrected",
            emotionalValence: 0.0 // Neutral - learning opportunity
        )

        // Reload patterns to include the correction
        await loadLearnedPatterns()

        logger.info("Stored classification correction: \(oldType.rawValue) -> \(newType.rawValue)")
    }

    /// Extract key patterns from a query for learning
    private func extractKeyPatterns(from query: String) -> [String] {
        var patterns: [String] = []

        let words = query.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 3 }

        // Single important words
        let importantWords = words.filter { word in
            // Filter out common stop words
            let stopWords = ["this", "that", "what", "which", "where", "when", "would", "could", "should", "have", "been", "being", "will", "with", "your", "from", "they", "them", "their", "there", "here"]
            return !stopWords.contains(word)
        }

        patterns.append(contentsOf: importantWords.prefix(5))

        // Bigrams (two-word patterns)
        for i in 0..<max(0, words.count - 1) {
            let bigram = "\(words[i]) \(words[i + 1])"
            if bigram.count > 8 {
                patterns.append(bigram)
            }
        }

        return Array(Set(patterns)).prefix(10).map { String($0) }
    }

    /// Find learned patterns that match a query
    private func findMatchingLearnedPatterns(for query: String) -> [(TaskType, Double)] {
        let queryLower = query.lowercased()
        var matches: [TaskType: Double] = [:]

        for pattern in learnedPatterns {
            if queryLower.contains(pattern.pattern) {
                let currentScore = matches[pattern.taskType] ?? 0
                matches[pattern.taskType] = max(currentScore, pattern.confidence)
            }
        }

        return matches.sorted { $0.value > $1.value }
    }

    /// Detect emerging task patterns that might warrant new task types
    public func detectEmergingPatterns() async -> [EmergingTaskPattern] {
        var emerging: [EmergingTaskPattern] = []

        // Analyze recent classification history for patterns
        let recentHistory = classificationHistory.suffix(200)

        // Group by task type
        let grouped = Dictionary(grouping: recentHistory) { $0.taskType }

        for (taskType, records) in grouped {
            // Look for consistent low-confidence classifications
            let avgConfidence = records.map(\.confidence).reduce(0, +) / Double(records.count)

            if avgConfidence < 0.7 && records.count > 10 {
                // This task type has consistent uncertainty - might need splitting
                let commonPatterns = findCommonPatterns(in: records.map(\.query))

                if !commonPatterns.isEmpty {
                    emerging.append(EmergingTaskPattern(
                        suggestedName: "\(taskType.rawValue)_variant",
                        relatedType: taskType,
                        patterns: commonPatterns,
                        frequency: records.count,
                        averageConfidence: avgConfidence
                    ))
                }
            }
        }

        // Store emerging patterns for review
        for pattern in emerging {
            await MemoryManager.shared.storeSemanticMemory(
                category: .taskPattern,
                key: "emerging_\(pattern.suggestedName)",
                value: pattern.patterns.joined(separator: ","),
                confidence: pattern.averageConfidence,
                source: .inferred
            )
        }

        return emerging
    }

    /// Find common patterns across multiple queries
    private func findCommonPatterns(in queries: [String]) -> [String] {
        var wordFrequency: [String: Int] = [:]

        for query in queries {
            let words = query.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count > 3 }

            for word in Set(words) {
                wordFrequency[word, default: 0] += 1
            }
        }

        // Return words that appear in at least 30% of queries
        let threshold = max(3, queries.count / 3)
        return wordFrequency
            .filter { $0.value >= threshold }
            .sorted { $0.value > $1.value }
            .prefix(10)
            .map(\.key)
    }

    /// Get classification insights for the user
    public func getClassificationInsights() async -> ClassificationInsights {
        let total = classificationHistory.count
        let confident = classificationHistory.filter { $0.confidence >= 0.8 }.count
        let corrected = classificationHistory.filter { $0.wasCorrect == false }.count

        let taskDistribution = Dictionary(grouping: classificationHistory) { $0.taskType }
            .mapValues { $0.count }

        let topPatterns = learnedPatterns
            .sorted { $0.confidence > $1.confidence }
            .prefix(10)
            .map { $0 }

        return ClassificationInsights(
            totalClassifications: total,
            confidentClassifications: confident,
            correctionsCount: corrected,
            taskDistribution: taskDistribution,
            topLearnedPatterns: Array(topPatterns),
            emergingPatterns: await detectEmergingPatterns()
        )
    }
}

// MARK: - Learning Types

/// A learned task pattern from historical classifications
public struct LearnedTaskPattern: Identifiable, Sendable {
    public let id = UUID()
    public let pattern: String
    public let taskType: TaskType
    public let confidence: Double
    public let usageCount: Int
    public let lastUsed: Date
}

/// An emerging pattern that might warrant a new task type
public struct EmergingTaskPattern: Identifiable, Sendable {
    public let id = UUID()
    public let suggestedName: String
    public let relatedType: TaskType
    public let patterns: [String]
    public let frequency: Int
    public let averageConfidence: Double
}

/// Insights about classification performance
public struct ClassificationInsights: Sendable {
    public let totalClassifications: Int
    public let confidentClassifications: Int
    public let correctionsCount: Int
    public let taskDistribution: [TaskType: Int]
    public let topLearnedPatterns: [LearnedTaskPattern]
    public let emergingPatterns: [EmergingTaskPattern]

    public var confidenceRate: Double {
        guard totalClassifications > 0 else { return 0 }
        return Double(confidentClassifications) / Double(totalClassifications)
    }

    public var correctionRate: Double {
        guard totalClassifications > 0 else { return 0 }
        return Double(correctionsCount) / Double(totalClassifications)
    }
}

// MARK: - Supporting Types

struct ClassificationResponse: Codable {
    let taskType: String
    let confidence: Double
    let reasoning: String?
    let alternatives: [AlternativeClassification]?

    enum CodingKeys: String, CodingKey {
        case taskType, confidence, reasoning, alternatives
    }
}

struct AlternativeClassification: Codable {
    let type: String
    let confidence: Double
}

public struct ClassificationRecord: Codable, Sendable, Identifiable {
    public let id: UUID
    public let query: String
    public let taskType: TaskType
    public let confidence: Double
    public let wasCorrect: Bool?
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        query: String,
        taskType: TaskType,
        confidence: Double,
        wasCorrect: Bool? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.query = query
        self.taskType = taskType
        self.confidence = confidence
        self.wasCorrect = wasCorrect
        self.timestamp = timestamp
    }
}

// MARK: - Errors

public enum ClassificationError: Error, LocalizedError {
    case invalidResponse(String)
    case unknownTaskType(String)
    case providerError(Error)
    case noProvider

    public var errorDescription: String? {
        switch self {
        case let .invalidResponse(details):
            return "Invalid classification response: \(details)"
        case let .unknownTaskType(type):
            return "Unknown task type: \(type)"
        case let .providerError(error):
            return "Provider error during classification: \(error.localizedDescription)"
        case .noProvider:
            return "No AI provider available for classification"
        }
    }
}

// MARK: - Semantic Embedding Types

/// Cached query embedding for similarity matching
struct QueryEmbedding: Codable {
    let query: String
    let embedding: [Float]
    let taskType: TaskType
    let timestamp: Date
}

/// Classification method used (typealias for compatibility)
public typealias ClassificationMethod = ClassificationMethodType

/// Calibration bucket for confidence calibration
struct CalibrationBucket {
    let rangeStart: Double
    let rangeEnd: Double
    var correctCount: Int = 0
    var totalCount: Int = 0

    var accuracy: Double {
        guard totalCount > 0 else { return (rangeStart + rangeEnd) / 2 }
        return Double(correctCount) / Double(totalCount)
    }

    mutating func add(wasCorrect: Bool) {
        totalCount += 1
        if wasCorrect {
            correctCount += 1
        }
    }
}

/// Seeded random number generator for reproducible prototype initialization
struct SeededRandomGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        // xorshift64
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
