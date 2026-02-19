// FocusModeIntelligence+UrgencyAssessment.swift
// THEA - Autonomous urgency determination and contextual intelligence
// Split from FocusModeIntelligence+Learning.swift

import Foundation

// MARK: - Urgency Assessment

extension FocusModeIntelligence {

    // MARK: - Types

    /// Comprehensive urgency score (0.0 = not urgent, 1.0 = critical emergency)
    public struct UrgencyAssessment: Sendable {
        public let score: Double // 0.0 to 1.0
        public let level: IncomingCommunication.UrgencyLevel
        public let confidence: Double // How confident THEA is in this assessment
        public let signals: [UrgencySignal]
        public let recommendation: UrgencyRecommendation
        public let reasoning: String // Human-readable explanation

        public enum UrgencyRecommendation: String, Sendable {
            case ignoreCompletely = "ignore" // Not urgent at all
            case autoReplyOnly = "auto_reply" // Send auto-reply, don't notify user
            case autoReplyAndMonitor = "monitor" // Auto-reply and watch for escalation
            case notifyUserLater = "notify_later" // Add to summary for later
            case notifyUserNow = "notify_now" // This is actually urgent
            case emergencyAlert = "emergency" // Critical - break through Focus
        }
    }

    /// A single signal contributing to the urgency score.
    public struct UrgencySignal: Sendable {
        public let type: SignalType
        public let weight: Double // Contribution to score
        public let description: String

        public enum SignalType: String, Sendable {
            case keywordMatch = "keyword"
            case contactPriority = "contact_priority"
            case messageFrequency = "frequency"
            case timeOfDay = "time"
            case calendarContext = "calendar"
            case sentimentAnalysis = "sentiment"
            case historicalPattern = "history"
            case multiPlatformAttempt = "multi_platform"
            case voiceMessage = "voice"
            case callAttempt = "call"
            case deadlineRelated = "deadline"
            case familyContact = "family"
            case workRelated = "work"
        }
    }

    // MARK: - Autonomous Urgency Determination

    // THEA monitors your entire life and can autonomously determine what's truly
    // urgent or time-sensitive WITHOUT bothering you. This uses multiple signals:
    //
    // 1. CONTACT HISTORY & PATTERNS
    // 2. MESSAGE CONTENT ANALYSIS
    // 3. CONTEXTUAL SIGNALS
    // 4. BEHAVIORAL SIGNALS
    // 5. CROSS-REFERENCED INTELLIGENCE
    //
    // DECISION: If score > threshold -> handle autonomously (no user notification)
    //           If score indicates true urgency -> notify user

    // periphery:ignore - Reserved: assessUrgencyAutonomously(contactId:phoneNumber:messageContent:platform:language:) instance method — reserved for future feature activation
    /// Autonomously assess urgency using all available intelligence.
    ///
    /// Combines keyword analysis, contact priority, message frequency, time-of-day context,
    /// time-sensitive language, sentiment analysis, and multi-platform escalation signals
    /// to produce a comprehensive urgency assessment.
    ///
    /// - Parameters:
    ///   - contactId: The contact identifier, if known.
    ///   - phoneNumber: The phone number of the sender, if available.
    ///   - messageContent: The text content of the incoming message.
    ///   - platform: The communication platform the message arrived on.
    ///   - language: The BCP-47 language code for keyword matching.
    /// - Returns: An ``UrgencyAssessment`` with score, level, confidence, and recommendation.
    func assessUrgencyAutonomously(
        contactId: String?,
        phoneNumber: String?,
        messageContent: String,
        platform: CommunicationPlatform,
        language: String
    ) async -> UrgencyAssessment {

        var signals: [UrgencySignal] = []
        var totalScore: Double = 0.0
        let contactKey = contactId ?? phoneNumber ?? "unknown"

        // periphery:ignore - Reserved: assessUrgencyAutonomously(contactId:phoneNumber:messageContent:platform:language:) instance method reserved for future feature activation
        // ========== 1. KEYWORD ANALYSIS ==========
        let keywordScore = analyzeKeywordsForUrgency(messageContent, language: language)
        if keywordScore > 0 {
            signals.append(UrgencySignal(
                type: .keywordMatch,
                weight: keywordScore * 0.25,
                description: "Message contains urgency indicators"
            ))
            totalScore += keywordScore * 0.25
        }

        // ========== 2. CONTACT PRIORITY ==========
        let contactPriority = getContactPriority(contactKey)
        if contactPriority > 0.7 {
            signals.append(UrgencySignal(
                type: .contactPriority,
                weight: (contactPriority - 0.5) * 0.3,
                description: "High-priority contact based on history"
            ))
            totalScore += (contactPriority - 0.5) * 0.3
        }

        // Check if VIP
        if let cId = contactId, getGlobalSettings().vipContacts.contains(cId) {
            signals.append(UrgencySignal(
                type: .contactPriority,
                weight: 0.2,
                description: "VIP contact"
            ))
            totalScore += 0.2
        }

        // Check if emergency contact
        if let cId = contactId, isEmergencyContact(cId) {
            signals.append(UrgencySignal(
                type: .familyContact,
                weight: 0.4,
                description: "Emergency contact"
            ))
            totalScore += 0.4
        }

        // ========== 3. MESSAGE FREQUENCY (Escalation) ==========
        let timestamps = getMessageCountTracking(for: contactKey)
        let recentMessages = timestamps.filter { Date().timeIntervalSince($0) < 600 } // Last 10 min
        if recentMessages.count >= 3 {
            let frequencyScore = min(0.3, Double(recentMessages.count) * 0.05)
            signals.append(UrgencySignal(
                type: .messageFrequency,
                weight: frequencyScore,
                description: "\(recentMessages.count) messages in last 10 minutes"
            ))
            totalScore += frequencyScore
        }

        // ========== 4. TIME OF DAY CONTEXT ==========
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 22 || hour < 6 {
            // Late night/early morning - more likely urgent if reaching out
            signals.append(UrgencySignal(
                type: .timeOfDay,
                weight: 0.15,
                description: "Unusual hours contact"
            ))
            totalScore += 0.15
        }

        // ========== 5. TIME-SENSITIVE LANGUAGE ==========
        let timeSensitiveScore = analyzeTimeSensitiveLanguage(messageContent, language: language)
        if timeSensitiveScore > 0 {
            signals.append(UrgencySignal(
                type: .deadlineRelated,
                weight: timeSensitiveScore * 0.2,
                description: "Time-sensitive language detected"
            ))
            totalScore += timeSensitiveScore * 0.2
        }

        // ========== 6. SENTIMENT ANALYSIS ==========
        let sentimentScore = analyzeSentimentForUrgency(messageContent)
        if sentimentScore > 0.3 {
            signals.append(UrgencySignal(
                type: .sentimentAnalysis,
                weight: sentimentScore * 0.15,
                description: "Elevated stress/urgency in tone"
            ))
            totalScore += sentimentScore * 0.15
        }

        // ========== 7. MULTI-PLATFORM ATTEMPTS ==========
        let platformsUsed = countRecentPlatformAttempts(contactKey: contactKey)
        if platformsUsed > 1 {
            signals.append(UrgencySignal(
                type: .multiPlatformAttempt,
                weight: 0.2,
                description: "Tried \(platformsUsed) different platforms"
            ))
            totalScore += 0.2
        }

        // ========== CALCULATE FINAL ASSESSMENT ==========
        let clampedScore = min(1.0, max(0.0, totalScore))
        let level = scoreToUrgencyLevel(clampedScore)
        let recommendation = determineRecommendation(score: clampedScore, signals: signals)
        let confidence = calculateConfidence(signals: signals)

        let reasoning = generateReasoning(signals: signals, score: clampedScore, recommendation: recommendation)

        return UrgencyAssessment(
            score: clampedScore,
            level: level,
            confidence: confidence,
            signals: signals,
            recommendation: recommendation,
            reasoning: reasoning
        )
    }

    // MARK: - Urgency Analysis Helpers

    // periphery:ignore - Reserved: analyzeKeywordsForUrgency(_:language:) instance method — reserved for future feature activation
    /// Analyze message content for urgency-related keywords in multiple languages.
    ///
    /// - Parameters:
    ///   - message: The message text to analyze.
    ///   - language: The BCP-47 language code for keyword selection.
    /// - Returns: A score from 0.0 (no urgency keywords) to 1.0 (strong urgency keywords).
    func analyzeKeywordsForUrgency(_ message: String, language: String) -> Double {
        let lowercased = message.lowercased()
        var score: Double = 0

        // Emergency keywords = high score
        let emergencyKeywords = ["emergency", "urgent", "help", "asap", "immediately", "critical",
                                  "dringend", "notfall", "hilfe", "sofort",
                                  "urgence", "aide", "imm\u{00E9}diatement",
                                  "emergenza", "urgente", "aiuto", "subito"]
        for keyword in emergencyKeywords {
            if lowercased.contains(keyword) {
                // periphery:ignore - Reserved: analyzeKeywordsForUrgency(_:language:) instance method reserved for future feature activation
                score += 0.4
            }
        }

        // Moderate urgency keywords
        let moderateKeywords = ["important", "need", "please call", "call me", "waiting",
                                 "wichtig", "bitte anrufen", "warte",
                                 "important", "appelle", "attends",
                                 "importante", "chiamami", "aspetto"]
        for keyword in moderateKeywords {
            if lowercased.contains(keyword) {
                score += 0.2
            }
        }

        return min(1.0, score)
    }

    // periphery:ignore - Reserved: analyzeTimeSensitiveLanguage(_:language:) instance method — reserved for future feature activation
    /// Detect time-sensitive language patterns (deadlines, time references).
    ///
    /// - Parameters:
    ///   - message: The message text to analyze.
    ///   - language: The BCP-47 language code for keyword selection.
    /// - Returns: A score from 0.0 (no time sensitivity) to 1.0 (strong time sensitivity).
    func analyzeTimeSensitiveLanguage(_ message: String, language: String) -> Double {
        let lowercased = message.lowercased()
        var score: Double = 0

        let timeSensitive = ["today", "tonight", "now", "right now", "this hour", "deadline",
                              "heute", "jetzt", "sofort", "deadline",
                              "aujourd'hui", "maintenant", "ce soir",
                              "oggi", "adesso", "stasera", "subito"]

        for keyword in timeSensitive {
            // periphery:ignore - Reserved: analyzeTimeSensitiveLanguage(_:language:) instance method reserved for future feature activation
            if lowercased.contains(keyword) {
                score += 0.3
            }
        }

        // Check for time mentions (e.g., "by 5pm", "before 3")
        let timePattern = #"\d{1,2}[:\.]?\d{0,2}\s*(am|pm|uhr|h|heure)?"#
        if lowercased.range(of: timePattern, options: .regularExpression) != nil {
            score += 0.2
        }

        return min(1.0, score)
    }

    // periphery:ignore - Reserved: analyzeSentimentForUrgency(_:) instance method — reserved for future feature activation
    /// Analyze message sentiment for stress and urgency indicators.
    ///
    /// Looks for repeated punctuation, caps lock usage, and stress-related phrases.
    ///
    /// - Parameter message: The message text to analyze.
    /// - Returns: A score from 0.0 (calm) to 1.0 (high stress/urgency).
    func analyzeSentimentForUrgency(_ message: String) -> Double {
        let lowercased = message.lowercased()
        var score: Double = 0

        // Stress indicators
        let stressIndicators = ["!!!", "???", "please please", "really need", "desperate",
                                 "worried", "scared", "anxious", "panicking"]
        for indicator in stressIndicators {
            if lowercased.contains(indicator) {
                // periphery:ignore - Reserved: analyzeSentimentForUrgency(_:) instance method reserved for future feature activation
                score += 0.3
            }
        }

        // Caps lock = shouting (check if significant portion is caps)
        let capsCount = message.filter { $0.isUppercase }.count
        let totalLetters = message.filter { $0.isLetter }.count
        if totalLetters > 10 && Double(capsCount) / Double(totalLetters) > 0.5 {
            score += 0.2
        }

        return min(1.0, score)
    }

    // periphery:ignore - Reserved: countRecentPlatformAttempts(contactKey:) instance method — reserved for future feature activation
    /// Count the number of distinct communication platforms a contact has used recently.
    ///
    /// - Parameter contactKey: The contact identifier or phone number.
    /// - Returns: The number of unique platforms used in the last 30 minutes.
    func countRecentPlatformAttempts(contactKey: String) -> Int {
        // Count unique platforms this contact has used in last 30 min
        let cutoff = Date().addingTimeInterval(-1800)
        let recentComms = getRecentCommunicationsInternal().filter {
            ($0.contactId == contactKey || $0.phoneNumber == contactKey) && $0.timestamp > cutoff
        }

        let platforms = Set(recentComms.map { $0.platform })
        // periphery:ignore - Reserved: countRecentPlatformAttempts(contactKey:) instance method reserved for future feature activation
        return platforms.count
    }

    // periphery:ignore - Reserved: scoreToUrgencyLevel(_:) instance method — reserved for future feature activation
    /// Convert a numeric urgency score to a discrete urgency level.
    ///
    /// - Parameter score: The urgency score (0.0 to 1.0).
    /// - Returns: The corresponding ``IncomingCommunication.UrgencyLevel``.
    func scoreToUrgencyLevel(_ score: Double) -> IncomingCommunication.UrgencyLevel {
        switch score {
        case 0.8...: return .emergency
        case 0.6..<0.8: return .urgent
        case 0.4..<0.6: return .possiblyUrgent
        case 0.2..<0.4: return .unknown
        default: return .notUrgent
        // periphery:ignore - Reserved: scoreToUrgencyLevel(_:) instance method reserved for future feature activation
        }
    }

    // periphery:ignore - Reserved: determineRecommendation(score:signals:) instance method — reserved for future feature activation
    /// Determine the recommended action based on urgency score and signals.
    ///
    /// - Parameters:
    ///   - score: The urgency score (0.0 to 1.0).
    ///   - signals: The urgency signals that contributed to the score.
    /// - Returns: The recommended ``UrgencyAssessment.UrgencyRecommendation``.
    func determineRecommendation(score: Double, signals: [UrgencySignal]) -> UrgencyAssessment.UrgencyRecommendation {
        // Check for emergency signals
        if signals.contains(where: { $0.type == .familyContact && $0.weight > 0.3 }) {
            return .notifyUserNow
        }

        // periphery:ignore - Reserved: determineRecommendation(score:signals:) instance method reserved for future feature activation
        switch score {
        case 0.8...: return .emergencyAlert
        case 0.6..<0.8: return .notifyUserNow
        case 0.4..<0.6: return .autoReplyAndMonitor
        case 0.2..<0.4: return .autoReplyOnly
        default: return .ignoreCompletely
        }
    }

    // periphery:ignore - Reserved: calculateConfidence(signals:) instance method — reserved for future feature activation
    /// Calculate assessment confidence based on the number and strength of signals.
    ///
    /// - Parameter signals: The urgency signals to evaluate.
    /// - Returns: A confidence value from 0.0 to 0.95.
    func calculateConfidence(signals: [UrgencySignal]) -> Double {
        // More signals = higher confidence
        let signalCount = Double(signals.count)
        let baseConfidence = min(0.9, signalCount * 0.15)

        // periphery:ignore - Reserved: calculateConfidence(signals:) instance method reserved for future feature activation
        // Strong signals increase confidence
        let strongSignals = signals.filter { $0.weight > 0.2 }.count
        let strongBonus = Double(strongSignals) * 0.1

        return min(0.95, baseConfidence + strongBonus)
    }

    // periphery:ignore - Reserved: generateReasoning(signals:score:recommendation:) instance method — reserved for future feature activation
    /// Generate a human-readable reasoning string for the urgency assessment.
    ///
    /// - Parameters:
    ///   - signals: The urgency signals contributing to the assessment.
    ///   - score: The overall urgency score.
    ///   - recommendation: The recommended action.
    /// - Returns: A human-readable explanation of the assessment.
    func generateReasoning(signals: [UrgencySignal], score: Double, recommendation: UrgencyAssessment.UrgencyRecommendation) -> String {
        if signals.isEmpty {
            return "No urgency signals detected. Will auto-reply and handle normally."
        }

// periphery:ignore - Reserved: generateReasoning(signals:score:recommendation:) instance method reserved for future feature activation

        let topSignals = signals.sorted { $0.weight > $1.weight }.prefix(3)
        let signalDescriptions = topSignals.map { $0.description }.joined(separator: "; ")

        let actionDescription: String
        switch recommendation {
        case .ignoreCompletely:
            actionDescription = "No action needed."
        case .autoReplyOnly:
            actionDescription = "Sending auto-reply, no user notification."
        case .autoReplyAndMonitor:
            actionDescription = "Sending auto-reply and monitoring for escalation."
        case .notifyUserLater:
            actionDescription = "Will include in Focus Mode summary."
        case .notifyUserNow:
            actionDescription = "Notifying user - this appears genuinely urgent."
        case .emergencyAlert:
            actionDescription = "EMERGENCY: Breaking through Focus Mode."
        }

        return "Score: \(String(format: "%.1f", score * 100))%. Signals: \(signalDescriptions). \(actionDescription)"
    }

    // MARK: - Contextual Intelligence

    // periphery:ignore - Reserved: enrichUrgencyWithContext(_:contactId:messageContent:) instance method — reserved for future feature activation
    /// Cross-reference an urgency assessment with calendar, projects, and conversation history.
    ///
    /// Enriches the base assessment with additional context signals such as upcoming meetings
    /// with the contact, project references in the message, and whether the message is a reply
    /// to something the user sent.
    ///
    /// - Parameters:
    ///   - assessment: The base ``UrgencyAssessment`` to enrich.
    ///   - contactId: The contact identifier, if known.
    ///   - messageContent: The message text for project reference analysis.
    /// - Returns: An enriched ``UrgencyAssessment`` with additional context signals.
    func enrichUrgencyWithContext(
        _ assessment: UrgencyAssessment,
        contactId: String?,
        // periphery:ignore - Reserved: enrichUrgencyWithContext(_:contactId:messageContent:) instance method reserved for future feature activation
        messageContent: String
    ) async -> UrgencyAssessment {
        var signals = assessment.signals
        var additionalScore: Double = 0

        // Check if sender has a meeting with you soon
        if let cId = contactId, await hasMeetingWithContactSoon(cId) {
            signals.append(UrgencySignal(
                type: .calendarContext,
                weight: 0.25,
                description: "Has meeting with you soon"
            ))
            additionalScore += 0.25
        }

        // Check if message references known project/deadline
        if messageContainsProjectReference(messageContent) {
            signals.append(UrgencySignal(
                type: .deadlineRelated,
                weight: 0.2,
                description: "References known project"
            ))
            additionalScore += 0.2
        }

        // Check if this is a reply to something you sent
        if await isReplyToYourMessage(contactId: contactId) {
            signals.append(UrgencySignal(
                type: .historicalPattern,
                weight: 0.15,
                description: "Reply to your recent message"
            ))
            additionalScore += 0.15
        }

        let newScore = min(1.0, assessment.score + additionalScore)
        let newLevel = scoreToUrgencyLevel(newScore)
        let newRecommendation = determineRecommendation(score: newScore, signals: signals)

        return UrgencyAssessment(
            score: newScore,
            level: newLevel,
            confidence: assessment.confidence,
            signals: signals,
            recommendation: newRecommendation,
            reasoning: generateReasoning(signals: signals, score: newScore, recommendation: newRecommendation)
        )
    }

    // periphery:ignore - Reserved: hasMeetingWithContactSoon(_:) instance method — reserved for future feature activation
    /// Check whether the user has an upcoming meeting with a given contact.
    ///
    /// - Parameter contactId: The contact identifier to look up.
    /// - Returns: `true` if a meeting is scheduled soon, `false` otherwise.
    func hasMeetingWithContactSoon(_ contactId: String) async -> Bool {
        // Would check calendar for events with this contact
        // periphery:ignore - Reserved: hasMeetingWithContactSoon(_:) instance method reserved for future feature activation
        false
    }

    // periphery:ignore - Reserved: messageContainsProjectReference(_:) instance method — reserved for future feature activation
    /// Check whether a message references known projects, ticket numbers, or deadlines.
    ///
    /// Matches patterns like JIRA-123, PR #456, issue #789, and deadline-related phrases.
    ///
    /// - Parameter message: The message text to analyze.
    /// - Returns: `true` if a project reference pattern is found.
    func messageContainsProjectReference(_ message: String) -> Bool {
        // periphery:ignore - Reserved: messageContainsProjectReference(_:) instance method reserved for future feature activation
        // Would check against known project names, ticket numbers, etc.
        let lowercased = message.lowercased()

        // Common project reference patterns
        let patterns = [
            "(jira|asana|trello|linear)-?\\d+", // Ticket numbers
            "pr[- ]?#?\\d+", // Pull request
            "issue[- ]?#?\\d+", // Issue numbers
            "deadline",
            "due (today|tomorrow|soon)"
        ]

        for pattern in patterns {
            if lowercased.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }

        return false
    }

    // periphery:ignore - Reserved: isReplyToYourMessage(contactId:) instance method reserved for future feature activation
    /// Check whether the incoming message is a reply to a message the user recently sent.
    ///
    /// - Parameter contactId: The contact identifier to check outgoing messages for.
    /// - Returns: `true` if the user recently sent a message to this contact.
    func isReplyToYourMessage(contactId: String?) async -> Bool {
        // Would check recent outgoing messages to this contact
        false
    }
}
