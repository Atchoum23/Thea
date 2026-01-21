// ResultAggregator.swift
import Foundation
import OSLog

/// Synthesizes results from multiple agents/steps with intelligent merging.
/// Handles conflict resolution, quality scoring, and final output generation.
@MainActor
@Observable
public final class ResultAggregator {
    public static let shared = ResultAggregator()

    private let logger = Logger(subsystem: "com.thea.metaai", category: "ResultAggregator")
    
    /// Configuration for aggregation behavior
    public var config = AggregationConfig()

    private init() {}
    
    // MARK: - Result Aggregation
    
    /// Aggregate results from multiple sources into a unified response
    public func aggregate(_ results: [AggregatorInput]) async -> AggregatedResult {
        logger.info("Aggregating \(results.count) results")
        
        guard !results.isEmpty else {
            return AggregatedResult(
                content: "",
                sources: [],
                confidence: 0,
                conflicts: [],
                metadata: [:]
            )
        }
        
        // Single result - return directly
        if results.count == 1 {
            let result = results[0]
            return AggregatedResult(
                content: result.content,
                sources: [result.source],
                confidence: result.confidence,
                conflicts: [],
                metadata: result.metadata
            )
        }
        
        // Multiple results - intelligent merging
        let conflicts = detectConflicts(results)
        let resolvedContent = await resolveAndMerge(results, conflicts: conflicts)
        let aggregatedConfidence = calculateAggregatedConfidence(results, conflicts: conflicts)
        let mergedMetadata = mergeMetadata(results)
        
        logger.info("Aggregation complete. Confidence: \(aggregatedConfidence), Conflicts: \(conflicts.count)")
        
        return AggregatedResult(
            content: resolvedContent,
            sources: results.map { $0.source },
            confidence: aggregatedConfidence,
            conflicts: conflicts,
            metadata: mergedMetadata
        )
    }
    
    // MARK: - Conflict Detection
    
    /// Detect conflicts between multiple results
    private func detectConflicts(_ results: [AggregatorInput]) -> [ResultConflict] {
        var conflicts: [ResultConflict] = []
        
        for i in 0..<results.count {
            for j in (i + 1)..<results.count {
                if let conflict = detectConflictBetween(results[i], results[j]) {
                    conflicts.append(conflict)
                }
            }
        }
        
        return conflicts
    }
    
    private func detectConflictBetween(_ a: AggregatorInput, _ b: AggregatorInput) -> ResultConflict? {
        // Check for contradictory content
        let similarity = calculateSimilarity(a.content, b.content)
        
        // High similarity but different conclusions might indicate conflict
        if similarity > 0.3 && similarity < 0.8 {
            // Check for negation patterns or contradictory statements
            if containsContradiction(a.content, b.content) {
                return ResultConflict(
                    sourceA: a.source,
                    sourceB: b.source,
                    type: .contradiction,
                    description: "Sources provide contradictory information",
                    severity: .medium
                )
            }
        }
        
        // Check for incompatible data types or formats
        if a.resultType != b.resultType && a.resultType != .unknown && b.resultType != .unknown {
            return ResultConflict(
                sourceA: a.source,
                sourceB: b.source,
                type: .typeMismatch,
                description: "Sources return incompatible result types",
                severity: .low
            )
        }
        
        return nil
    }
    
    // MARK: - Conflict Resolution
    
    /// Resolve conflicts and merge results
    private func resolveAndMerge(_ results: [AggregatorInput], conflicts: [ResultConflict]) async -> String {
        // Sort by confidence
        let sortedResults = results.sorted { $0.confidence > $1.confidence }
        
        switch config.mergeStrategy {
        case .highestConfidence:
            // Use result with highest confidence
            return sortedResults.first?.content ?? ""
            
        case .consensus:
            // Find common elements across results
            return buildConsensusContent(sortedResults)
            
        case .weighted:
            // Weight by confidence and combine
            return buildWeightedContent(sortedResults)
            
        case .concatenate:
            // Combine all results with deduplication
            return buildConcatenatedContent(sortedResults)
            
        case .aiMerge:
            // Use AI to intelligently merge (future implementation)
            // For now, fall back to weighted merge
            return buildWeightedContent(sortedResults)
        }
    }
    
    private func buildConsensusContent(_ results: [AggregatorInput]) -> String {
        guard let first = results.first else { return "" }
        
        // Simple consensus: take the highest confidence result but note agreements
        var content = first.content
        
        let agreements = results.dropFirst().filter { 
            calculateSimilarity($0.content, first.content) > 0.7 
        }
        
        if !agreements.isEmpty {
            content += "\n\n[Consensus from \(agreements.count + 1) sources]"
        }
        
        return content
    }
    
    private func buildWeightedContent(_ results: [AggregatorInput]) -> String {
        // Take primary from highest confidence, augment with unique info from others
        guard let primary = results.first else { return "" }
        
        var content = primary.content
        var addedInfo: [String] = []
        
        for result in results.dropFirst() {
            // Extract unique information not in primary
            let uniqueInfo = extractUniqueInformation(from: result.content, notIn: primary.content)
            if !uniqueInfo.isEmpty && result.confidence > config.minimumConfidenceThreshold {
                addedInfo.append(uniqueInfo)
            }
        }
        
        if !addedInfo.isEmpty {
            content += "\n\nAdditional information:\n" + addedInfo.joined(separator: "\n")
        }
        
        return content
    }
    
    private func buildConcatenatedContent(_ results: [AggregatorInput]) -> String {
        var sections: [String] = []
        var seenContent: Set<String> = []
        
        for result in results {
            // Simple deduplication by content hash
            let contentHash = result.content.prefix(100).description
            if !seenContent.contains(contentHash) {
                seenContent.insert(contentHash)
                sections.append("[\(result.source)]:\n\(result.content)")
            }
        }
        
        return sections.joined(separator: "\n\n---\n\n")
    }
    
    // MARK: - Quality Scoring
    
    private func calculateAggregatedConfidence(_ results: [AggregatorInput], conflicts: [ResultConflict]) -> Double {
        guard !results.isEmpty else { return 0 }
        
        // Base confidence is weighted average
        let totalWeight = results.reduce(0.0) { $0 + $1.confidence }
        let weightedSum = results.reduce(0.0) { $0 + ($1.confidence * $1.confidence) }
        var confidence = totalWeight > 0 ? weightedSum / totalWeight : 0
        
        // Reduce confidence based on conflicts
        let conflictPenalty = Double(conflicts.count) * config.conflictPenaltyFactor
        confidence = max(0, confidence - conflictPenalty)
        
        // Boost confidence if multiple sources agree
        let agreementBonus = calculateAgreementBonus(results)
        confidence = min(1.0, confidence + agreementBonus)
        
        return confidence
    }
    
    private func calculateAgreementBonus(_ results: [AggregatorInput]) -> Double {
        guard results.count >= 2 else { return 0 }
        
        var agreementCount = 0
        for i in 0..<results.count {
            for j in (i + 1)..<results.count {
                if calculateSimilarity(results[i].content, results[j].content) > 0.7 {
                    agreementCount += 1
                }
            }
        }
        
        // Max bonus of 0.15 for high agreement
        let maxPairs = (results.count * (results.count - 1)) / 2
        return Double(agreementCount) / Double(maxPairs) * 0.15
    }
    
    // MARK: - Helper Methods
    
    private func calculateSimilarity(_ a: String, _ b: String) -> Double {
        // Simple Jaccard similarity on word sets
        let wordsA = Set(a.lowercased().split(separator: " ").map { String($0) })
        let wordsB = Set(b.lowercased().split(separator: " ").map { String($0) })
        
        let intersection = wordsA.intersection(wordsB).count
        let union = wordsA.union(wordsB).count
        
        return union > 0 ? Double(intersection) / Double(union) : 0
    }
    
    private func containsContradiction(_ a: String, _ b: String) -> Bool {
        // Simple negation detection
        let negationPatterns = ["not ", "don't ", "doesn't ", "isn't ", "aren't ", "won't ", "can't ", "never "]
        
        let aLower = a.lowercased()
        let bLower = b.lowercased()
        
        for pattern in negationPatterns {
            if aLower.contains(pattern) != bLower.contains(pattern) {
                // One has negation, other doesn't - potential contradiction
                return true
            }
        }
        
        return false
    }
    
    private func extractUniqueInformation(from content: String, notIn reference: String) -> String {
        // Extract sentences from content that aren't similar to anything in reference
        let sentences = content.components(separatedBy: ". ")
        let referenceLower = reference.lowercased()
        
        let uniqueSentences = sentences.filter { sentence in
            let sentenceLower = sentence.lowercased()
            // Check if this sentence's key words are present in reference
            let words = sentenceLower.split(separator: " ").filter { $0.count > 4 }
            let matchingWords = words.filter { referenceLower.contains($0) }
            return Double(matchingWords.count) / Double(max(1, words.count)) < 0.5
        }
        
        return uniqueSentences.joined(separator: ". ")
    }
    
    private func mergeMetadata(_ results: [AggregatorInput]) -> [String: Any] {
        var merged: [String: Any] = [:]
        
        for result in results {
            for (key, value) in result.metadata {
                if merged[key] == nil {
                    merged[key] = value
                } else if let existing = merged[key] as? [Any], let new = value as? [Any] {
                    merged[key] = existing + new
                }
            }
        }
        
        merged["sourceCount"] = results.count
        merged["aggregatedAt"] = Date()
        
        return merged
    }
}

// MARK: - Models

/// Result from a single agent or processing step for aggregation
public struct AggregatorInput: Sendable {
    public let source: String
    public let content: String
    public let confidence: Double
    public let resultType: ResultType
    public let metadata: [String: Any]
    
    public init(
        source: String,
        content: String,
        confidence: Double,
        resultType: ResultType = .text,
        metadata: [String: Any] = [:]
    ) {
        self.source = source
        self.content = content
        self.confidence = confidence
        self.resultType = resultType
        self.metadata = metadata
    }
    
    public enum ResultType: Sendable {
        case text
        case code
        case data
        case structured
        case unknown
    }
}

/// Aggregated result from multiple sources
public struct AggregatedResult: Sendable {
    public let content: String
    public let sources: [String]
    public let confidence: Double
    public let conflicts: [ResultConflict]
    public let metadata: [String: Any]
}

/// Detected conflict between results
public struct ResultConflict: Sendable {
    public let sourceA: String
    public let sourceB: String
    public let type: ConflictType
    public let description: String
    public let severity: Severity
    
    public enum ConflictType: Sendable {
        case contradiction
        case typeMismatch
        case dataMismatch
        case incompleteness
    }
    
    public enum Severity: Sendable {
        case low
        case medium
        case high
    }
}

/// Configuration for aggregation behavior
public struct AggregationConfig: Sendable {
    public var mergeStrategy: MergeStrategy = .weighted
    public var minimumConfidenceThreshold: Double = 0.3
    public var conflictPenaltyFactor: Double = 0.1
    public var maxSourcesPerAggregation: Int = 10
    
    public enum MergeStrategy: Sendable {
        case highestConfidence  // Use only highest confidence result
        case consensus          // Find common ground across results
        case weighted           // Weight by confidence
        case concatenate        // Combine all with deduplication
        case aiMerge            // Use AI to merge intelligently
    }
}
