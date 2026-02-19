// CallMonitor+AnalysisEngine.swift
// THEA - Voice Call Transcription & Intelligence
//
// Post-call analysis engine: extracts summaries, key points, action items,
// commitments, follow-ups, deadlines, sentiment, topics, decisions,
// and unanswered questions from call transcripts.
//
// Helper methods (date parsing, assignee inference, context expansion)
// live in CallMonitor+AnalysisHelpers.swift.

import Foundation

// MARK: - Call Analysis Engine

/// Actor that performs comprehensive post-call analysis on a `CallRecord`'s transcript.
///
/// Analysis includes:
/// - Natural-language summary generation
/// - Key-point extraction via regex patterns
/// - Action item detection with priority and assignee inference
/// - Commitment and follow-up extraction
/// - Deadline mention parsing (relative and absolute dates)
/// - Sentiment analysis (word-count heuristic)
/// - Topic classification against a keyword dictionary
/// - Decision and question extraction
actor CallAnalysisEngine {

    /// Analyzes a completed call's transcript and returns a `CallAnalysis`.
    ///
    /// Returns `nil` if the transcript contains no segments.
    ///
    /// - Parameter call: The `CallRecord` to analyze.
    /// - Returns: A fully populated `CallAnalysis`, or `nil` if the transcript is empty.
    func analyze(_ call: CallRecord) async -> CallAnalysis? {
        guard !call.transcript.segments.isEmpty else { return nil }

        let fullText = call.transcript.fullText

        // Extract various elements
        let summary = generateSummary(call)
        let keyPoints = extractKeyPoints(fullText)
        let actionItems = extractActionItems(fullText, call: call)
        let commitments = extractCommitments(fullText, call: call)
        let followUps = extractFollowUps(fullText)
        let deadlines = extractDeadlines(fullText)
        let sentiment = analyzeSentiment(call)
        let topics = extractTopics(fullText)
        let decisions = extractDecisions(fullText)
        let questions = extractQuestions(call)

        return CallAnalysis(
            callId: call.id,
            summary: summary,
            keyPoints: keyPoints,
            actionItems: actionItems,
            commitments: commitments,
            followUps: followUps,
            deadlinesMentioned: deadlines,
            sentiment: sentiment,
            topics: topics,
            decisions: decisions,
            questions: questions
        )
    }

    // MARK: - Summary & Key Points

    /// Generates a one-line summary of the call including duration, participants, and top topics.
    ///
    /// - Parameter call: The call to summarize.
    /// - Returns: A human-readable summary string.
    private func generateSummary(_ call: CallRecord) -> String {
        let duration = Int(call.duration / 60)
        let participantNames = call.participants.compactMap { $0.name ?? $0.identifier }.joined(separator: ", ")
        let topics = extractTopics(call.transcript.fullText).prefix(3).map { $0.name }.joined(separator: ", ")

        return "\(duration)-minute call with \(participantNames). Main topics: \(topics.isEmpty ? "General discussion" : topics)"
    }

    /// Extracts key points from the transcript by matching common
    /// emphasis patterns (e.g., "the key point is...", "most importantly...").
    ///
    /// - Parameter text: The full transcript text.
    /// - Returns: Up to 10 deduplicated key-point strings.
    private func extractKeyPoints(_ text: String) -> [String] {
        var keyPoints: [String] = []

        // Look for patterns that indicate key points
        let patterns = [
            #"(?i)the (main|key|important) (point|thing|takeaway) is[:\s]+([^.]+)"#,
            #"(?i)(most importantly|importantly|critically)[,:\s]+([^.]+)"#,
            #"(?i)to summarize[,:\s]+([^.]+)"#,
            #"(?i)in conclusion[,:\s]+([^.]+)"#
        ]

        for pattern in patterns {
            // Safe: compile-time known pattern; invalid regex → skip this pattern (no matches)
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let nsText = text as NSString
                let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))

                for match in matches {
                    let pointRange = match.range(at: match.numberOfRanges - 1)
                    if pointRange.location != NSNotFound {
                        let point = nsText.substring(with: pointRange).trimmingCharacters(in: .whitespaces)
                        if !point.isEmpty {
                            keyPoints.append(point)
                        }
                    }
                }
            }
        }

        return Array(Set(keyPoints)).prefix(10).map { $0 }
    }

    // MARK: - Action Items

    /// Extracts action items from the transcript using intent-based regex patterns.
    ///
    /// Patterns include "I need to...", "you should...", "urgent:...", "action item:...", etc.
    /// Each item is assigned a priority level and, when possible, an assignee and due date.
    ///
    /// - Parameters:
    ///   - text: The full transcript text.
    ///   - call: The `CallRecord` (used for participant-based assignee inference).
    /// - Returns: An array of `CallAnalysis.ActionItem` values.
    private func extractActionItems(_ text: String, call: CallRecord) -> [CallAnalysis.ActionItem] {
        var items: [CallAnalysis.ActionItem] = []

        // Patterns that indicate action items
        let patterns: [(String, CallAnalysis.ActionItem.Priority)] = [
            (#"(?i)(I need to|I have to|I must|I should|I will|I'll)\s+([^.!?]+)"#, .medium),
            (#"(?i)(you need to|you have to|you must|you should)\s+([^.!?]+)"#, .medium),
            (#"(?i)(can you|could you|would you)\s+([^.!?]+)\?"#, .low),
            (#"(?i)(urgent|urgently|asap|immediately)\s*[:\s]+([^.!?]+)"#, .urgent),
            (#"(?i)action item[:\s]+([^.!?]+)"#, .high),
            (#"(?i)(todo|to-do|to do)[:\s]+([^.!?]+)"#, .medium)
        ]

        for (pattern, priority) in patterns {
            // Safe: compile-time known pattern; invalid regex → skip this pattern (no matches)
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let nsText = text as NSString
                let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))

                for match in matches {
                    let actionRange = match.range(at: match.numberOfRanges - 1)
                    if actionRange.location != NSNotFound {
                        let action = nsText.substring(with: actionRange).trimmingCharacters(in: .whitespaces)
                        if !action.isEmpty && action.count > 5 {
                            let fullMatch = nsText.substring(with: match.range)

                            // Try to extract due date
                            let dueDate = extractDateFromContext(fullMatch)

                            // Try to extract assignee
                            let assignee = extractAssignee(fullMatch, participants: call.participants)

                            items.append(CallAnalysis.ActionItem(
                                description: action,
                                assignee: assignee,
                                dueDate: dueDate,
                                priority: priority,
                                extractedFrom: fullMatch
                            ))
                        }
                    }
                }
            }
        }

        return items
    }

    // MARK: - Commitments

    // periphery:ignore - Reserved: call parameter kept for API compatibility
    /// Extracts commitments (promises, guarantees) from the transcript.
    ///
    /// Detects patterns like "I promise...", "I guarantee...", "consider it done".
    ///
    /// - Parameters:
    ///   - text: The full transcript text.
    ///   - call: The `CallRecord` for context.
    /// - Returns: An array of `CallAnalysis.Commitment` values.
    private func extractCommitments(_ text: String, call: CallRecord) -> [CallAnalysis.Commitment] {
        var commitments: [CallAnalysis.Commitment] = []

        let patterns = [
            #"(?i)(I promise|I commit|I guarantee|I'll make sure|you can count on me)[:\s]+([^.!?]+)"#,
            #"(?i)(I will|I'll)\s+(definitely|certainly|absolutely)\s+([^.!?]+)"#,
            #"(?i)consider it done[.!]?\s*([^.!?]*)"#
        ]

        for pattern in patterns {
            // Safe: compile-time known pattern; invalid regex → skip this pattern (no matches)
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let nsText = text as NSString
                let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))

                for match in matches {
                    let commitmentRange = match.range(at: match.numberOfRanges - 1)
                    if commitmentRange.location != NSNotFound {
                        let commitment = nsText.substring(with: commitmentRange).trimmingCharacters(in: .whitespaces)
                        let fullMatch = nsText.substring(with: match.range)

                        if !commitment.isEmpty {
                            let deadline = extractDateFromContext(fullMatch)

                            commitments.append(CallAnalysis.Commitment(
                                description: commitment,
                                madeBy: "User", // Would need speaker diarization
                                madeAt: Date(),
                                deadline: deadline,
                                extractedFrom: fullMatch
                            ))
                        }
                    }
                }
            }
        }

        return commitments
    }

    // MARK: - Follow-Ups

    /// Extracts follow-up items from the transcript (scheduled meetings, emails, callbacks).
    ///
    /// - Parameter text: The full transcript text.
    /// - Returns: An array of `CallAnalysis.FollowUp` values with inferred type and optional date.
    private func extractFollowUps(_ text: String) -> [CallAnalysis.FollowUp] {
        var followUps: [CallAnalysis.FollowUp] = []

        let patterns = [
            (#"(?i)let's (schedule|set up|arrange) (a|another) (call|meeting|follow-up)"#, CallAnalysis.FollowUp.FollowUpType.meeting),
            (#"(?i)I'll (send|forward|email) you"#, .email),
            (#"(?i)let's (touch base|reconnect|talk again)"#, .call),
            (#"(?i)follow up (on|with|about)"#, .other)
        ]

        for (pattern, type) in patterns {
            // Safe: compile-time known pattern; invalid regex → skip this pattern (no matches)
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let nsText = text as NSString
                let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))

                for match in matches {
                    let context = expandContext(text, range: match.range, chars: 50)
                    let scheduledDate = extractDateFromContext(context)

                    followUps.append(CallAnalysis.FollowUp(
                        description: context,
                        scheduledFor: scheduledDate,
                        participants: [],
                        type: type
                    ))
                }
            }
        }

        return followUps
    }

    // MARK: - Deadlines

    /// Extracts explicitly mentioned deadlines from the transcript.
    ///
    /// Matches patterns like "due March 15th", "deadline is next Friday",
    /// "by end of week", etc.
    ///
    /// - Parameter text: The full transcript text.
    /// - Returns: An array of `CallAnalysis.MentionedDeadline` values with parsed dates.
    private func extractDeadlines(_ text: String) -> [CallAnalysis.MentionedDeadline] {
        var deadlines: [CallAnalysis.MentionedDeadline] = []

        let patterns = [
            #"(?i)(due|deadline|by|before|until)\s+(\w+\s+\d{1,2}(?:st|nd|rd|th)?,?\s*\d{0,4})"#,
            #"(?i)(due|deadline|by|before|until)\s+(tomorrow|monday|tuesday|wednesday|thursday|friday|saturday|sunday|next week|end of (?:day|week|month))"#
        ]

        for pattern in patterns {
            // Safe: compile-time known pattern; invalid regex → skip this pattern (no matches)
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let nsText = text as NSString
                let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))

                for match in matches {
                    let dateRange = match.range(at: 2)
                    if dateRange.location != NSNotFound {
                        let dateStr = nsText.substring(with: dateRange)
                        if let date = parseDate(dateStr) {
                            let context = expandContext(text, range: match.range, chars: 50)
                            deadlines.append(CallAnalysis.MentionedDeadline(
                                description: context,
                                date: date,
                                context: nsText.substring(with: match.range)
                            ))
                        }
                    }
                }
            }
        }

        return deadlines
    }

    // MARK: - Sentiment Analysis

    /// Performs word-count-based sentiment analysis on the call transcript.
    ///
    /// Counts occurrences of positive and negative sentiment words across all
    /// transcript segments and returns an overall sentiment level.
    ///
    /// - Parameter call: The `CallRecord` to analyze.
    /// - Returns: A `CallAnalysis.CallSentiment` with an overall level.
    private func analyzeSentiment(_ call: CallRecord) -> CallAnalysis.CallSentiment {
        let positiveWords = Set(["great", "excellent", "wonderful", "happy", "pleased", "good", "fantastic", "perfect", "love", "amazing"])
        let negativeWords = Set(["bad", "terrible", "awful", "disappointed", "frustrated", "angry", "upset", "problem", "issue", "concerned"])

        var positiveCount = 0
        var negativeCount = 0

        for segment in call.transcript.segments {
            let words = segment.text.lowercased().split(separator: " ").map { String($0) }
            positiveCount += words.filter { positiveWords.contains($0) }.count
            negativeCount += words.filter { negativeWords.contains($0) }.count
        }

        let overall: CallAnalysis.CallSentiment.SentimentLevel
        let ratio = Double(positiveCount) / max(Double(negativeCount + positiveCount), 1)

        if ratio > 0.7 {
            overall = .veryPositive
        } else if ratio > 0.55 {
            overall = .positive
        } else if ratio > 0.45 {
            overall = .neutral
        } else if ratio > 0.3 {
            overall = .negative
        } else {
            overall = .veryNegative
        }

        return CallAnalysis.CallSentiment(
            overall: overall,
            byParticipant: [:],
            trend: []
        )
    }

    // MARK: - Topics

    /// Classifies the transcript into topics using a keyword-frequency heuristic.
    ///
    /// Matches the transcript text against predefined keyword lists for common
    /// business topics (Budget, Timeline, Design, Development, etc.) and returns
    /// the top 5 by frequency.
    ///
    /// - Parameter text: The full transcript text.
    /// - Returns: Up to 5 `CallAnalysis.Topic` values sorted by keyword frequency.
    private func extractTopics(_ text: String) -> [CallAnalysis.Topic] {
        var topicCounts: [String: Int] = [:]

        let topicKeywords: [String: [String]] = [
            "Budget": ["budget", "cost", "price", "money", "funding", "expense", "financial"],
            "Timeline": ["timeline", "schedule", "deadline", "milestone", "date", "week", "month"],
            "Design": ["design", "ui", "ux", "interface", "layout", "visual", "mockup"],
            "Development": ["code", "develop", "build", "implement", "feature", "bug", "fix"],
            "Meeting": ["meeting", "call", "discussion", "sync", "standup", "review"],
            "Customer": ["customer", "client", "user", "feedback", "support", "request"],
            "Strategy": ["strategy", "plan", "goal", "objective", "target", "initiative"]
        ]

        let lowercasedText = text.lowercased()

        for (topic, keywords) in topicKeywords {
            let count = keywords.reduce(0) { count, keyword in
                count + lowercasedText.components(separatedBy: keyword).count - 1
            }
            if count > 0 {
                topicCounts[topic] = count
            }
        }

        return topicCounts
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { CallAnalysis.Topic(name: $0.key, duration: 0, keywords: topicKeywords[$0.key] ?? []) }
    }

    // MARK: - Decisions

    /// Extracts explicit decisions from the transcript.
    ///
    /// Matches patterns like "we decided...", "the decision is...", "let's go with...".
    ///
    /// - Parameter text: The full transcript text.
    /// - Returns: An array of `CallAnalysis.Decision` values.
    private func extractDecisions(_ text: String) -> [CallAnalysis.Decision] {
        var decisions: [CallAnalysis.Decision] = []

        let patterns = [
            #"(?i)(we decided|we've decided|the decision is|we agreed|let's go with)\s+([^.!?]+)"#,
            #"(?i)(final decision|our decision)[:\s]+([^.!?]+)"#
        ]

        for pattern in patterns {
            // Safe: compile-time known pattern; invalid regex → skip this pattern (no matches)
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let nsText = text as NSString
                let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))

                for match in matches {
                    let decisionRange = match.range(at: 2)
                    if decisionRange.location != NSNotFound {
                        let decision = nsText.substring(with: decisionRange).trimmingCharacters(in: .whitespaces)
                        if !decision.isEmpty {
                            decisions.append(CallAnalysis.Decision(
                                description: decision,
                                madeBy: nil,
                                alternatives: []
                            ))
                        }
                    }
                }
            }
        }

        return decisions
    }

    // MARK: - Questions

    /// Extracts questions from the transcript by looking for interrogative sentence patterns.
    ///
    /// Identifies sentences starting with question words (what, how, why, when, etc.)
    /// within segments that contain a question mark.
    ///
    /// - Parameter call: The `CallRecord` whose segments to scan.
    /// - Returns: An array of `CallAnalysis.Question` values with speaker attribution.
    private func extractQuestions(_ call: CallRecord) -> [CallAnalysis.Question] {
        var questions: [CallAnalysis.Question] = []

        for segment in call.transcript.segments {
            if segment.text.contains("?") {
                // Find the question
                let sentences = segment.text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
                for sentence in sentences {
                    let trimmed = sentence.trimmingCharacters(in: .whitespaces)
                    if trimmed.lowercased().starts(with: "what") ||
                       trimmed.lowercased().starts(with: "how") ||
                       trimmed.lowercased().starts(with: "why") ||
                       trimmed.lowercased().starts(with: "when") ||
                       trimmed.lowercased().starts(with: "where") ||
                       trimmed.lowercased().starts(with: "who") ||
                       trimmed.lowercased().starts(with: "can") ||
                       trimmed.lowercased().starts(with: "could") ||
                       trimmed.lowercased().starts(with: "would") ||
                       trimmed.lowercased().starts(with: "should") ||
                       trimmed.lowercased().starts(with: "is") ||
                       trimmed.lowercased().starts(with: "are") ||
                       trimmed.lowercased().starts(with: "do") ||
                       trimmed.lowercased().starts(with: "does") {
                        questions.append(CallAnalysis.Question(
                            text: trimmed + "?",
                            askedBy: segment.speaker,
                            wasAnswered: false, // Would need more analysis
                            answer: nil
                        ))
                    }
                }
            }
        }

        return questions
    }
}
