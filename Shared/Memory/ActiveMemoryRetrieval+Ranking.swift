// ActiveMemoryRetrieval+Ranking.swift
// Thea
//
// AI-powered relevance ranking and information extraction for ActiveMemoryRetrieval

import Foundation

// MARK: - AI-Powered Ranking & Information Extraction

extension ActiveMemoryRetrieval {

    // MARK: - AI-Powered Ranking

    func rankSourcesByRelevance(
        sources: [RetrievalSource],
        query: String,
        taskType: TaskType?
    ) async -> [RetrievalSource] {
        guard !sources.isEmpty else { return [] }

        // If AI ranking is disabled or no provider available, use simple scoring
        guard config.enableAIRanking,
              let provider = ProviderRegistry.shared.getProvider(id: "openrouter")
                          ?? ProviderRegistry.shared.getProvider(id: "openai") else {
            return sources.sorted { $0.relevanceScore > $1.relevanceScore }
        }

        // Use AI to rank relevance
        let sourceSummaries = sources.enumerated().map { index, source in
            "[\(index)] \(source.type.rawValue): \(source.content.prefix(200))"
        }.joined(separator: "\n")

        let prompt = """
        Rank these memory sources by relevance to the query.
        Query: "\(query)"
        Task type: \(taskType?.rawValue ?? "general")

        Sources:
        \(sourceSummaries)

        Respond with JSON array of indices in order of relevance (most relevant first):
        [0, 2, 1, ...]
        """

        do {
            let message = AIMessage(
                id: UUID(),
                conversationID: UUID(),
                role: .user,
                content: .text(prompt),
                timestamp: Date(),
                model: "openai/gpt-4o-mini"
            )

            var responseText = ""
            let stream = try await provider.chat(
                messages: [message],
                model: "openai/gpt-4o-mini",
                stream: false
            )

            for try await chunk in stream {
                if case .delta(let text) = chunk.type {
                    responseText += text
                } else if case .complete(let msg) = chunk.type {
                    responseText = msg.content.textValue
                }
            }

            // Parse ranking
            if let jsonStart = responseText.firstIndex(of: "["),
               let jsonEnd = responseText.lastIndex(of: "]") {
                let jsonStr = String(responseText[jsonStart...jsonEnd])
                if let data = jsonStr.data(using: .utf8),
                   let indices = try? JSONDecoder().decode([Int].self, from: data) {
                    var rankedSources: [RetrievalSource] = []
                    for index in indices where index < sources.count {
                        var source = sources[index]
                        // Boost relevance based on AI ranking position
                        source.relevanceScore *= (1.0 - Double(rankedSources.count) * 0.1)
                        rankedSources.append(source)
                    }
                    // Add any sources not ranked by AI
                    let rankedIndices = Set(indices)
                    for (index, source) in sources.enumerated() where !rankedIndices.contains(index) {
                        rankedSources.append(source)
                    }
                    return rankedSources
                }
            }

        } catch {
            logger.warning("AI ranking failed: \(error.localizedDescription)")
        }

        // Fallback to score-based ranking
        return sources.sorted { $0.relevanceScore > $1.relevanceScore }
    }

    // MARK: - Information Extraction

    func extractInformation(
        userMessage: String,
        assistantResponse: String
    ) async -> ExtractedInformation {
        guard let provider = ProviderRegistry.shared.getProvider(id: "openrouter")
                        ?? ProviderRegistry.shared.getProvider(id: "openai") else {
            return ExtractedInformation(facts: [], importance: 0.3)
        }

        let prompt = """
        Extract key learnable facts from this conversation exchange.
        Focus on: user preferences, technical context, project details, personal info.

        User: \(userMessage.prefix(1000))
        Assistant: \(assistantResponse.prefix(1000))

        Respond with JSON:
        {
            "facts": [
                {"category": "preference|info|technical|project", "content": "fact text"}
            ],
            "importance": 0.0-1.0
        }
        """

        do {
            let message = AIMessage(
                id: UUID(),
                conversationID: UUID(),
                role: .user,
                content: .text(prompt),
                timestamp: Date(),
                model: "openai/gpt-4o-mini"
            )

            var responseText = ""
            let stream = try await provider.chat(
                messages: [message],
                model: "openai/gpt-4o-mini",
                stream: false
            )

            for try await chunk in stream {
                if case .delta(let text) = chunk.type {
                    responseText += text
                } else if case .complete(let msg) = chunk.type {
                    responseText = msg.content.textValue
                }
            }

            // Parse extraction
            if let jsonStart = responseText.firstIndex(of: "{"),
               let jsonEnd = responseText.lastIndex(of: "}") {
                let jsonStr = String(responseText[jsonStart...jsonEnd])
                if let data = jsonStr.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

                    var facts: [ExtractedFact] = []
                    if let factsArray = json["facts"] as? [[String: String]] {
                        for factDict in factsArray {
                            if let category = factDict["category"],
                               let content = factDict["content"] {
                                facts.append(ExtractedFact(category: category, content: content))
                            }
                        }
                    }

                    let importance = json["importance"] as? Double ?? 0.3
                    return ExtractedInformation(facts: facts, importance: importance)
                }
            }

        } catch {
            logger.warning("Information extraction failed: \(error.localizedDescription)")
        }

        return ExtractedInformation(facts: [], importance: 0.3)
    }
}
