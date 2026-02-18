// TaskClassifier+Embeddings.swift
// Thea V2
//
// Semantic embedding classification, confidence calibration, and AI classification
// Extracted from TaskClassifier.swift

import Accelerate
import Foundation
import OSLog

// MARK: - Semantic Embedding Classification

extension TaskClassifier {
    /// Classify using semantic embedding similarity
    func classifyWithEmbedding(_ query: String) async -> ClassificationResult? {
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
    func getOrGenerateEmbedding(for query: String) async -> [Float] {
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
    func generateSimpleEmbedding(for text: String) -> [Float] {
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
    func findNearestNeighbor(embedding: [Float]) -> (TaskType, Double)? {
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
    func storeQueryEmbedding(query: String, result: ClassificationResult) async {
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
    func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Double {
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
    func normalizeVector(_ v: [Float]) -> [Float] {
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
    func loadPrototypeEmbeddingsFromMemory() async {
        let records = await MemoryManager.shared.retrieveSemanticMemories(
            category: .taskPattern,
            limit: 50
        )

        for record in records {
            guard record.key.hasPrefix("prototype_"),
                  let data = record.value.data(using: .utf8),
                  let taskType = TaskType(rawValue: String(record.key.dropFirst(10))) else {
                continue
            }
            let embedding: [Float]
            do {
                embedding = try JSONDecoder().decode([Float].self, from: data)
            } catch {
                logger.error("Failed to decode prototype embedding for \(record.key): \(error.localizedDescription)")
                continue
            }

            taskTypePrototypes[taskType] = embedding
        }

        logger.debug("Loaded \(self.taskTypePrototypes.count) prototype embeddings from memory")
    }

    /// Persist prototype embeddings to MemoryManager
    func persistPrototypeEmbeddings() async {
        for (taskType, embedding) in taskTypePrototypes {
            let data: Data
            do {
                data = try JSONEncoder().encode(embedding)
            } catch {
                logger.error("Failed to encode prototype embedding for \(taskType.rawValue): \(error.localizedDescription)")
                continue
            }
            guard let value = String(data: data, encoding: .utf8) else {
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
    func applyConfidenceCalibration(_ result: ClassificationResult) -> ClassificationResult {
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
    func updateCalibration(confidence: Double, wasCorrect: Bool) {
        let bucketIndex = min(9, Int(confidence * 10))
        calibrationData[bucketIndex].add(wasCorrect: wasCorrect)
    }

    /// Get current calibration statistics
    func getCalibrationStats() -> [(range: String, accuracy: Double, count: Int)] {
        calibrationData.map { bucket in
            (
                range: String(format: "%.1f-%.1f", bucket.rangeStart, bucket.rangeEnd),
                accuracy: bucket.accuracy,
                count: bucket.totalCount
            )
        }
    }

    // MARK: - AI Classification

    func buildClassificationPrompt(for query: String) -> String {
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

    func classifyWithAI(prompt: String) async throws -> String {
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

    func parseClassificationResponse(_ response: String, for _query: String) throws -> ClassificationResult {
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

    func extractJSON(from text: String) -> String {
        // Try to find JSON in the response
        if let startIndex = text.firstIndex(of: "{"),
           let endIndex = text.lastIndex(of: "}") {
            return String(text[startIndex...endIndex])
        }
        return text
    }
}
