// WebSearchVerifier.swift
// Thea
//
// AI-powered web search verification for fact-checking
// Automatically verifies factual claims against current web sources

import Foundation
import OSLog

// MARK: - Web Search Verifier

/// Verifies factual claims in responses using web search
@MainActor
public final class WebSearchVerifier {
    private let logger = Logger(subsystem: "com.thea.ai", category: "WebSearchVerifier")

    // Configuration
    public var maxClaimsToVerify: Int = 5
    public var minConfidenceToVerify: Double = 0.3
    public var timeout: TimeInterval = 10.0

    // MARK: - Verification

    /// Verify a response by fact-checking against web sources
    public func verify(response: String, query: String) async -> WebVerificationResult {
        logger.info("Starting web verification")

        // 1. Extract factual claims from response
        let claims = await extractFactualClaims(from: response)

        guard !claims.isEmpty else {
            return WebVerificationResult(
                source: ConfidenceSource(
                    type: .webVerification,
                    name: "Web Verification",
                    confidence: 0.5,
                    weight: 0.20,
                    details: "No verifiable factual claims found",
                    verified: false
                ),
                factors: [],
                verifiedClaims: [],
                unverifiedClaims: []
            )
        }

        // 2. Verify each claim
        var verifiedClaims: [VerifiedClaim] = []
        var unverifiedClaims: [String] = []

        for claim in claims.prefix(maxClaimsToVerify) {
            if let verification = await verifyClaim(claim) {
                verifiedClaims.append(verification)
            } else {
                unverifiedClaims.append(claim)
            }
        }

        // 3. Calculate confidence
        let verificationRate = Double(verifiedClaims.count) / Double(claims.prefix(maxClaimsToVerify).count)
        let confirmedRate = Double(verifiedClaims.filter { $0.confirmed }.count) / Double(max(1, verifiedClaims.count))

        let confidence = (verificationRate * 0.4 + confirmedRate * 0.6)

        // 4. Build factors
        var factors: [ConfidenceDecomposition.DecompositionFactor] = []

        factors.append(ConfidenceDecomposition.DecompositionFactor(
            name: "Claims Verified",
            contribution: (verificationRate - 0.5) * 2,
            explanation: "\(verifiedClaims.count)/\(claims.prefix(maxClaimsToVerify).count) claims checked against sources"
        ))

        if !verifiedClaims.isEmpty {
            factors.append(ConfidenceDecomposition.DecompositionFactor(
                name: "Source Confirmation",
                contribution: (confirmedRate - 0.5) * 2,
                explanation: "\(verifiedClaims.filter { $0.confirmed }.count) claims confirmed by web sources"
            ))
        }

        let contradicted = verifiedClaims.filter { !$0.confirmed }
        if !contradicted.isEmpty {
            factors.append(ConfidenceDecomposition.DecompositionFactor(
                name: "Contradicted Claims",
                contribution: -0.3 * Double(contradicted.count),
                explanation: "\(contradicted.count) claims contradicted by sources"
            ))
        }

        let details = """
            Extracted \(claims.count) claims, verified \(verifiedClaims.count).
            Confirmed: \(verifiedClaims.filter { $0.confirmed }.count), \
            Contradicted: \(contradicted.count)
            Sources: \(Set(verifiedClaims.compactMap { $0.source }).joined(separator: ", "))
            """

        return WebVerificationResult(
            source: ConfidenceSource(
                type: .webVerification,
                name: "Web Verification",
                confidence: confidence,
                weight: 0.20,
                details: details,
                verified: confirmedRate >= 0.7
            ),
            factors: factors,
            verifiedClaims: verifiedClaims,
            unverifiedClaims: unverifiedClaims
        )
    }

    // MARK: - Claim Extraction

    private func extractFactualClaims(from response: String) async -> [String] {
        // Use AI to extract verifiable factual claims
        let prompt = """
            Extract specific, verifiable factual claims from this text.
            Only include claims that can be fact-checked (dates, numbers, names, events, definitions).
            Do NOT include opinions, predictions, or code-related statements.

            Text:
            \(response.prefix(2000))

            Respond with JSON array of claims:
            ["claim 1", "claim 2", ...]
            """

        guard let provider = ProviderRegistry.shared.getProvider(id: "openrouter")
            ?? ProviderRegistry.shared.getProvider(id: "openai") else {
            // Fallback: simple pattern extraction
            return extractClaimsWithPatterns(from: response)
        }

        do {
            let message = AIMessage(
                id: UUID(), conversationID: UUID(), role: .user,
                content: .text(prompt),
                timestamp: Date(), model: "openai/gpt-4o-mini"
            )

            var responseText = ""
            let stream = try await provider.chat(
                messages: [message],
                model: "openai/gpt-4o-mini",
                stream: false
            )

            for try await chunk in stream {
                switch chunk.type {
                case let .delta(text):
                    responseText += text
                case let .complete(msg):
                    responseText = msg.content.textValue
                case .error:
                    break
                }
            }

            // Parse claims array
            if let jsonStart = responseText.firstIndex(of: "["),
               let jsonEnd = responseText.lastIndex(of: "]") {
                let jsonStr = String(responseText[jsonStart...jsonEnd])
                if let data = jsonStr.data(using: .utf8) {
                    do {
                        let claims = try JSONDecoder().decode([String].self, from: data)
                        return claims
                    } catch {
                        logger.debug("Failed to decode claims JSON: \(error.localizedDescription)")
                    }
                }
            }

        } catch {
            logger.warning("AI claim extraction failed: \(error.localizedDescription)")
        }

        return extractClaimsWithPatterns(from: response)
    }

    private func extractClaimsWithPatterns(from response: String) -> [String] {
        var claims: [String] = []

        // Pattern: sentences with numbers/dates
        let numberPattern = #"\b\d{4}\b|\b\d+%\b|\$[\d,]+|\b\d+\s*(million|billion|thousand)\b"#
        do {
            let regex = try NSRegularExpression(pattern: numberPattern, options: .caseInsensitive)
            let range = NSRange(response.startIndex..., in: response)
            let matches = regex.matches(in: response, range: range)

            for match in matches.prefix(10) {
                if let sentenceRange = findSentenceContaining(match: match, in: response) {
                    claims.append(String(response[sentenceRange]))
                }
            }
        } catch {
            logger.debug("Invalid number pattern regex: \(error.localizedDescription)")
        }

        return Array(Set(claims)).prefix(5).map { String($0) }
    }

    private func findSentenceContaining(match: NSTextCheckingResult, in text: String) -> Range<String.Index>? {
        guard let matchRange = Range(match.range, in: text) else { return nil }

        // Find sentence boundaries
        let beforeMatch = text[..<matchRange.lowerBound]
        let afterMatch = text[matchRange.upperBound...]

        let sentenceStart = beforeMatch.lastIndex(of: ".").map { text.index(after: $0) } ?? text.startIndex
        let sentenceEnd = afterMatch.firstIndex(of: ".").map { text.index(after: $0) } ?? text.endIndex

        return sentenceStart..<sentenceEnd
    }

    // MARK: - Claim Verification

    private func verifyClaim(_ claim: String) async -> VerifiedClaim? {
        // Try to verify using Perplexity (best for real-time search)
        if let perplexity = ProviderRegistry.shared.getProvider(id: "perplexity") {
            return await verifyWithProvider(claim: claim, provider: perplexity, modelId: "perplexity/sonar")
        }

        // Fallback to other providers with web access
        if let openrouter = ProviderRegistry.shared.getProvider(id: "openrouter") {
            return await verifyWithProvider(claim: claim, provider: openrouter, modelId: "perplexity/sonar-medium-online")
        }

        return nil
    }

    private func verifyWithProvider(claim: String, provider: AIProvider, modelId: String) async -> VerifiedClaim? {
        let prompt = """
            Verify this factual claim using current information:
            "\(claim)"

            Respond with JSON:
            {
                "confirmed": true/false,
                "confidence": 0.0-1.0,
                "source": "source name or URL",
                "correction": "corrected information if claim is wrong, or null"
            }
            """

        do {
            let message = AIMessage(
                id: UUID(), conversationID: UUID(), role: .user,
                content: .text(prompt),
                timestamp: Date(), model: modelId
            )

            var responseText = ""
            let stream = try await provider.chat(
                messages: [message],
                model: modelId,
                stream: false
            )

            for try await chunk in stream {
                switch chunk.type {
                case let .delta(text):
                    responseText += text
                case let .complete(msg):
                    responseText = msg.content.textValue
                case .error:
                    break
                }
            }

            // Parse response
            if let jsonStart = responseText.firstIndex(of: "{"),
               let jsonEnd = responseText.lastIndex(of: "}") {
                let jsonStr = String(responseText[jsonStart...jsonEnd])
                if let data = jsonStr.data(using: .utf8) {
                    do {
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            return VerifiedClaim(
                                claim: claim,
                                confirmed: json["confirmed"] as? Bool ?? false,
                                confidence: json["confidence"] as? Double ?? 0.5,
                                source: json["source"] as? String,
                                correction: json["correction"] as? String
                            )
                        }
                    } catch {
                        logger.debug("Failed to parse verification JSON: \(error.localizedDescription)")
                    }
                }
            }

        } catch {
            logger.warning("Claim verification failed: \(error.localizedDescription)")
        }

        return nil
    }
}

// MARK: - Supporting Types

public struct VerifiedClaim: Sendable {
    public let claim: String
    public let confirmed: Bool
    public let confidence: Double
    public let source: String?
    public let correction: String?
}

public struct WebVerificationResult: Sendable {
    public let source: ConfidenceSource
    public let factors: [ConfidenceDecomposition.DecompositionFactor]
    public let verifiedClaims: [VerifiedClaim]
    public let unverifiedClaims: [String]
}
