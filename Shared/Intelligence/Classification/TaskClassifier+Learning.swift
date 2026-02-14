// TaskClassifier+Learning.swift
// Thea V2
//
// Caching, historical learning, feedback, and MemoryManager integration
// Extracted from TaskClassifier.swift

import Foundation
import OSLog

// MARK: - Caching

extension TaskClassifier {
    /// Cache a classification result
    func cacheResult(_ result: ClassificationResult, for key: String) {
        classificationCache[key] = result

        // Prune cache if needed
        if classificationCache.count > maxCacheSize {
            // Remove oldest entries (simple approach)
            let keysToRemove = classificationCache.keys.prefix(10)
            keysToRemove.forEach { classificationCache.removeValue(forKey: $0) }
        }
    }

    /// Clear the classification cache
    public func clearCache() {
        classificationCache.removeAll()
    }

    // MARK: - Historical Learning

    /// Find a historical classification that matches the query
    func findHistoricalMatch(for query: String) -> ClassificationResult? {
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

    /// Calculate Jaccard similarity between two strings
    func calculateSimilarity(_ str1: String, _ str2: String) -> Double {
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
    func loadLearnedPatterns() async {
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
    func storeClassificationCorrection(
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
    func extractKeyPatterns(from query: String) -> [String] {
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
    func findMatchingLearnedPatterns(for query: String) -> [(TaskType, Double)] {
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
    func findCommonPatterns(in queries: [String]) -> [String] {
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
