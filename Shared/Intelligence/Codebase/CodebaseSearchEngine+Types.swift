// CodebaseSearchEngine+Types.swift
// Thea V2
//
// Supporting types and SIMD vector operations for codebase search.

import Foundation
import Accelerate

// MARK: - Supporting Types

struct ParsedQuery {
    let terms: [String]
    let exactPhrases: [String]
    // periphery:ignore - Reserved: excludeTerms property — reserved for future feature activation
    let excludeTerms: [String]
    // periphery:ignore - Reserved: filePatterns property — reserved for future feature activation
    let filePatterns: [String]
    let symbolPatterns: [String]
}

// periphery:ignore - Reserved: excludeTerms property reserved for future feature activation

// periphery:ignore - Reserved: filePatterns property reserved for future feature activation

struct SearchHistoryEntry {
    let query: String
    let timestamp: Date
    // periphery:ignore - Reserved: query property reserved for future feature activation
    // periphery:ignore - Reserved: timestamp property reserved for future feature activation
    // periphery:ignore - Reserved: resultCount property reserved for future feature activation
    let resultCount: Int
}

// MARK: - SIMD Vector Operations

/// Optimized vector operations using Accelerate framework
public enum VectorOperations {

    /// Compute cosine similarity between two vectors using SIMD
    public static func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }

        var dotProduct: Float = 0
        var normA: Float = 0
        var normB: Float = 0

        // Use vDSP for SIMD acceleration
        vDSP_dotpr(a, 1, b, 1, &dotProduct, vDSP_Length(a.count))
        vDSP_dotpr(a, 1, a, 1, &normA, vDSP_Length(a.count))
        vDSP_dotpr(b, 1, b, 1, &normB, vDSP_Length(b.count))

        let denominator = sqrt(normA) * sqrt(normB)
        guard denominator > 0 else { return 0 }

        return dotProduct / denominator
    }

    /// Find top-k most similar vectors using batch computation
    public static func topKSimilar(
        query: [Float],
        vectors: [[Float]],
        k: Int
    ) -> [(index: Int, score: Float)] {
        var scores: [(index: Int, score: Float)] = []

        for (index, vector) in vectors.enumerated() {
            let score = cosineSimilarity(query, vector)
            scores.append((index, score))
        }

        // Partial sort for top-k
        return Array(scores.sorted { $0.score > $1.score }.prefix(k))
    }

    /// Normalize a vector to unit length
    public static func normalize(_ vector: [Float]) -> [Float] {
        var norm: Float = 0
        vDSP_dotpr(vector, 1, vector, 1, &norm, vDSP_Length(vector.count))
        norm = sqrt(norm)

        guard norm > 0 else { return vector }

        var result = [Float](repeating: 0, count: vector.count)
        var divisor = norm
        vDSP_vsdiv(vector, 1, &divisor, &result, 1, vDSP_Length(vector.count))

        return result
    }
}
