// ProactivityEngine+ContextWatch.swift
// Thea V2 - Context Watch & Contradiction Detection
//
// Monitors registered context watches for new information that may
// contradict or update previous answers, enabling proactive notifications.

import Foundation
import os.log

// MARK: - ProactivityEngine Context Watch Management

extension ProactivityEngine {

    // MARK: - Registration

    /// Register a context watch to monitor for changes or contradictions.
    ///
    /// When new information is found that contradicts the `originalAnswer`,
    /// a ``ProactiveContextChange`` is generated and queued as a proactive suggestion.
    ///
    /// - Parameters:
    ///   - query: The original query to monitor.
    ///   - originalAnswer: The answer that was provided and should be monitored for staleness.
    ///   - conversationId: The conversation where this topic was discussed.
    ///   - keywords: Keywords to monitor for related new information. If empty, keywords are extracted from the query.
    public func registerContextWatch(
        query: String,
        originalAnswer: String,
        conversationId: UUID,
        keywords: [String] = []
    ) {
        let watch = ContextWatch(
            query: query,
            originalAnswer: originalAnswer,
            conversationId: conversationId,
            keywords: keywords.isEmpty ? extractKeywords(from: query) : keywords,
            registeredAt: Date()
        )

        contextWatches.append(watch)
        logger.info("Registered context watch for query: \(query.prefix(50))...")

        // Start monitoring if not already running
        if contextWatchTask == nil {
            startContextWatching()
        }
    }

    /// Remove a context watch by its identifier.
    ///
    /// Stops the monitoring loop if no watches remain.
    ///
    /// - Parameter id: The unique identifier of the watch to remove.
    public func unregisterContextWatch(id: UUID) {
        contextWatches.removeAll { $0.id == id }
        logger.debug("Unregistered context watch: \(id)")

        // Stop monitoring if no watches left
        if contextWatches.isEmpty {
            stopContextWatching()
        }
    }

    /// Remove all context watches associated with a specific conversation.
    ///
    /// - Parameter conversationId: The conversation whose watches should be removed.
    public func unregisterContextWatches(forConversation conversationId: UUID) {
        let count = contextWatches.filter { $0.conversationId == conversationId }.count
        contextWatches.removeAll { $0.conversationId == conversationId }
        logger.debug("Unregistered \(count) context watches for conversation: \(conversationId)")
    }

    /// Dismiss a context change notification.
    ///
    /// If acknowledged, records a preference in ``MemoryManager`` to refine future notifications.
    ///
    /// - Parameters:
    ///   - changeId: The identifier of the ``ProactiveContextChange`` to dismiss.
    ///   - acknowledged: Whether the user acknowledged the change (default `true`).
    public func dismissProactiveContextChange(_ changeId: UUID, acknowledged: Bool = true) async {
        pendingProactiveContextChanges.removeAll { $0.id == changeId }

        if acknowledged {
            // Learn that user cares about this type of notification
            await MemoryManager.shared.learnPreference(
                category: .timing,
                preference: "context_change_acknowledged",
                strength: 0.2
            )
        }
    }

    // MARK: - Monitoring Loop

    /// Start the periodic monitoring loop for all context watches.
    ///
    /// Runs on a background task, checking at `contextCheckInterval` frequency.
    internal func startContextWatching() {
        guard contextWatchTask == nil else { return }

        contextWatchTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.checkProactiveContextChanges()

                do {
                    try await Task.sleep(for: .seconds(self?.contextCheckInterval ?? 300))
                } catch {
                    break
                }
            }
        }

        logger.info("Started context watch monitoring")
    }

    /// Stop the context watch monitoring loop.
    internal func stopContextWatching() {
        contextWatchTask?.cancel()
        contextWatchTask = nil
        logger.info("Stopped context watch monitoring")
    }

    /// Check all context watches for new information and contradictions.
    ///
    /// Iterates over registered watches, searches for new facts via ``MemoryManager``,
    /// and generates ``ProactiveContextChange`` entries for any detected contradictions.
    internal func checkProactiveContextChanges() async {
        guard isEnabled, !contextWatches.isEmpty else { return }

        for watch in contextWatches {
            // Skip recently checked watches
            if let lastCheck = watch.lastChecked,
               Date().timeIntervalSince(lastCheck) < contextCheckInterval {
                continue
            }

            // Search memory for new related information
            let newFacts = await searchForNewFacts(related: watch)

            // Check for contradictions
            for fact in newFacts {
                if let contradiction = await detectContradiction(
                    originalAnswer: watch.originalAnswer,
                    newFact: fact.content
                ) {
                    let change = ProactiveContextChange(
                        watchId: watch.id,
                        conversationId: watch.conversationId,
                        originalQuery: watch.query,
                        originalAnswer: watch.originalAnswer,
                        newInformation: fact.content,
                        contradictionDetails: contradiction,
                        detectedAt: Date(),
                        source: fact.source
                    )

                    pendingProactiveContextChanges.append(change)
                    await notifyProactiveContextChange(change)

                    logger.info("Detected context change for watch: \(watch.id)")
                }
            }

            // Update last checked time
            if let index = contextWatches.firstIndex(where: { $0.id == watch.id }) {
                contextWatches[index].lastChecked = Date()
            }
        }
    }

    // MARK: - Fact Search

    /// Search ``MemoryManager`` for new facts related to a context watch.
    ///
    /// Queries each keyword and returns facts that are newer than the watch's registration date.
    ///
    /// - Parameter watch: The ``ContextWatch`` whose keywords should be searched.
    /// - Returns: An array of ``NewFactResult`` with new relevant facts.
    internal func searchForNewFacts(related watch: ContextWatch) async -> [NewFactResult] {
        var results: [NewFactResult] = []

        // Query MemoryManager for recent memories matching keywords
        for keyword in watch.keywords {
            let memories = MemoryManager.shared.keywordSearch(
                query: keyword,
                limit: 5
            )

            for memory in memories {
                // Only consider facts newer than the watch registration
                if memory.timestamp > watch.registeredAt {
                    results.append(NewFactResult(
                        content: memory.value,
                        source: memory.source.rawValue,
                        timestamp: memory.timestamp
                    ))
                }
            }
        }

        return results
    }

    // MARK: - Contradiction Detection

    /// Detect whether new information contradicts an original answer.
    ///
    /// Uses keyword-based negation pattern matching and version-number comparison
    /// as heuristics. A more sophisticated implementation could use semantic similarity.
    ///
    /// - Parameters:
    ///   - originalAnswer: The previously provided answer text.
    ///   - newFact: The newly discovered fact text.
    /// - Returns: A human-readable contradiction description, or `nil` if no contradiction is detected.
    internal func detectContradiction(
        originalAnswer: String,
        newFact: String
    ) async -> String? {
        // Simple keyword-based contradiction detection
        // A more sophisticated implementation would use semantic similarity

        let original = originalAnswer.lowercased()
        let newLower = newFact.lowercased()

        // Check for negation patterns
        let negationPatterns: [(String, String)] = [
            ("is not", "is"),
            ("isn't", "is"),
            ("cannot", "can"),
            ("won't", "will"),
            ("doesn't", "does"),
            ("never", "always"),
            ("false", "true"),
            ("incorrect", "correct"),
            ("wrong", "right"),
            ("outdated", "current"),
            ("deprecated", "supported"),
            ("removed", "available")
        ]

        for (negation, affirmation) in negationPatterns {
            // Check if original says X and new says NOT X
            if original.contains(affirmation) && newLower.contains(negation) {
                return "Original stated '\(affirmation)' but new information indicates '\(negation)'"
            }
            // Check if original says NOT X and new says X
            if original.contains(negation) && newLower.contains(affirmation) && !newLower.contains(negation) {
                return "Original stated '\(negation)' but new information suggests otherwise"
            }
        }

        // Check for version/date contradictions
        // Safe: compile-time known version-number pattern; invalid regex → nil, version contradiction check is skipped
        let versionPattern = try? NSRegularExpression(
            pattern: "\\b(version|v)?\\s*(\\d+\\.\\d+(?:\\.\\d+)?)\\b",
            options: .caseInsensitive
        )

        if let pattern = versionPattern {
            let originalVersions = pattern.matches(in: original, range: NSRange(original.startIndex..., in: original))
            let newVersions = pattern.matches(in: newLower, range: NSRange(newLower.startIndex..., in: newLower))

            if !originalVersions.isEmpty && !newVersions.isEmpty {
                // Versions mentioned in both - might indicate update
                return "Version information may have changed - please verify current versions"
            }
        }

        return nil
    }

    // MARK: - Notification

    /// Notify the user about a context change by queuing it as a proactive suggestion.
    ///
    /// Also stores the notification as a prospective memory for future context matching.
    ///
    /// - Parameter change: The ``ProactiveContextChange`` to notify about.
    internal func notifyProactiveContextChange(_ change: ProactiveContextChange) async {
        // Queue as a proactive suggestion
        let suggestion = AIProactivitySuggestion(
            type: "context_change_\(change.id)",
            title: "Information Update Available",
            reason: "New information may affect a previous answer: \(change.contradictionDetails)",
            priority: .normal,
            actionPayload: [
                "watchId": change.watchId.uuidString,
                "conversationId": change.conversationId.uuidString
            ]
        )

        await queueSuggestion(suggestion)

        // Also store as prospective memory
        await MemoryManager.shared.storeProspectiveMemory(
            intention: "Notify user about context change: \(change.contradictionDetails)",
            triggerCondition: .contextMatch(change.originalQuery),
            priority: .high
        )
    }

    // MARK: - Keyword Extraction

    /// Extract meaningful keywords from a query by removing common stop words.
    ///
    /// - Parameter query: The user's query string.
    /// - Returns: Up to 10 unique keywords suitable for monitoring.
    internal func extractKeywords(from query: String) -> [String] {
        // Remove common words and extract meaningful keywords
        let stopWords: Set<String> = [
            "the", "a", "an", "is", "are", "was", "were", "be", "been", "being",
            "have", "has", "had", "do", "does", "did", "will", "would", "could",
            "should", "may", "might", "must", "shall", "can", "need", "dare",
            "ought", "used", "to", "of", "in", "for", "on", "with", "at", "by",
            "from", "up", "about", "into", "through", "during", "before", "after",
            "above", "below", "between", "under", "again", "further", "then",
            "once", "here", "there", "when", "where", "why", "how", "all", "each",
            "few", "more", "most", "other", "some", "such", "no", "nor", "not",
            "only", "own", "same", "so", "than", "too", "very", "just", "but",
            "and", "or", "if", "because", "as", "until", "while", "what", "which",
            "who", "whom", "this", "that", "these", "those", "am", "i", "me", "my",
            "we", "our", "you", "your", "he", "him", "his", "she", "her", "it",
            "its", "they", "them", "their"
        ]

        let words = query.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && $0.count > 2 && !stopWords.contains($0) }

        // Return unique keywords, max 10
        return Array(Set(words).prefix(10))
    }
}
