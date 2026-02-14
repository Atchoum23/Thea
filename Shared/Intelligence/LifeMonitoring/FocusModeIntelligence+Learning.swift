// FocusModeIntelligence+Learning.swift
// THEA - Urgency Assessment, VIP Mode, Learning, Reliability, Anticipation
// Split from FocusModeIntelligence.swift

import Foundation
import UserNotifications
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Learning, Analytics, Prediction & Advanced Features

extension FocusModeIntelligence {

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

    /// Autonomously assess urgency using all available intelligence
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

    func analyzeTimeSensitiveLanguage(_ message: String, language: String) -> Double {
        let lowercased = message.lowercased()
        var score: Double = 0

        let timeSensitive = ["today", "tonight", "now", "right now", "this hour", "deadline",
                              "heute", "jetzt", "sofort", "deadline",
                              "aujourd'hui", "maintenant", "ce soir",
                              "oggi", "adesso", "stasera", "subito"]

        for keyword in timeSensitive {
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

    func analyzeSentimentForUrgency(_ message: String) -> Double {
        let lowercased = message.lowercased()
        var score: Double = 0

        // Stress indicators
        let stressIndicators = ["!!!", "???", "please please", "really need", "desperate",
                                 "worried", "scared", "anxious", "panicking"]
        for indicator in stressIndicators {
            if lowercased.contains(indicator) {
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

    func countRecentPlatformAttempts(contactKey: String) -> Int {
        // Count unique platforms this contact has used in last 30 min
        let cutoff = Date().addingTimeInterval(-1800)
        let recentComms = getRecentCommunicationsInternal().filter {
            ($0.contactId == contactKey || $0.phoneNumber == contactKey) && $0.timestamp > cutoff
        }

        let platforms = Set(recentComms.map { $0.platform })
        return platforms.count
    }

    func scoreToUrgencyLevel(_ score: Double) -> IncomingCommunication.UrgencyLevel {
        switch score {
        case 0.8...: return .emergency
        case 0.6..<0.8: return .urgent
        case 0.4..<0.6: return .possiblyUrgent
        case 0.2..<0.4: return .unknown
        default: return .notUrgent
        }
    }

    func determineRecommendation(score: Double, signals: [UrgencySignal]) -> UrgencyAssessment.UrgencyRecommendation {
        // Check for emergency signals
        if signals.contains(where: { $0.type == .familyContact && $0.weight > 0.3 }) {
            return .notifyUserNow
        }

        switch score {
        case 0.8...: return .emergencyAlert
        case 0.6..<0.8: return .notifyUserNow
        case 0.4..<0.6: return .autoReplyAndMonitor
        case 0.2..<0.4: return .autoReplyOnly
        default: return .ignoreCompletely
        }
    }

    func calculateConfidence(signals: [UrgencySignal]) -> Double {
        // More signals = higher confidence
        let signalCount = Double(signals.count)
        let baseConfidence = min(0.9, signalCount * 0.15)

        // Strong signals increase confidence
        let strongSignals = signals.filter { $0.weight > 0.2 }.count
        let strongBonus = Double(strongSignals) * 0.1

        return min(0.95, baseConfidence + strongBonus)
    }

    func generateReasoning(signals: [UrgencySignal], score: Double, recommendation: UrgencyAssessment.UrgencyRecommendation) -> String {
        if signals.isEmpty {
            return "No urgency signals detected. Will auto-reply and handle normally."
        }

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

    // MARK: - VIP Mode (Enhancement 7)

    // VIP contacts get special treatment:
    // - Custom personalized messages
    // - Always ring through (optional)
    // - Higher priority in callbacks

    /// Check if contact is VIP
    public func isVIPContact(_ contactId: String) -> Bool {
        getGlobalSettings().vipContacts.contains(contactId)
    }

    /// Add VIP contact
    public func addVIPContact(_ contactId: String, customMessage: String? = nil) {
        var settings = getGlobalSettings()
        if !settings.vipContacts.contains(contactId) {
            settings.vipContacts.append(contactId)
        }
        if let message = customMessage {
            settings.vipCustomMessages[contactId] = message
        }
        setGlobalSettings(settings)

        Task {
            await saveSettings()
        }
    }

    /// Remove VIP contact
    public func removeVIPContact(_ contactId: String) {
        var settings = getGlobalSettings()
        settings.vipContacts.removeAll { $0 == contactId }
        settings.vipCustomMessages.removeValue(forKey: contactId)
        setGlobalSettings(settings)

        Task {
            await saveSettings()
        }
    }

    func getVIPMessage(for contactId: String, language: String) -> String? {
        guard isVIPContact(contactId) else { return nil }

        // Check for custom message first
        if let custom = getGlobalSettings().vipCustomMessages[contactId] {
            return custom
        }

        // Return a VIP-specific default
        let vipMessages: [String: String] = [
            "en": "Hi! I'm currently in Focus Mode but saw it's you. Is this something that can't wait?",
            "de": "Hallo! Ich bin gerade im Fokus-Modus, aber ich sehe, dass du es bist. Kann das nicht warten?",
            "fr": "Salut! Je suis en mode Concentration mais j'ai vu que c'\u{00E9}tait toi. C'est quelque chose qui ne peut pas attendre?",
            "it": "Ciao! Sono in modalit\u{00E0} Focus ma ho visto che sei tu. \u{00C8} qualcosa che non pu\u{00F2} aspettare?"
        ]

        return vipMessages[language] ?? vipMessages["en"]
    }

    // MARK: - Learning from Outcomes (Enhancement 8)

    // Track how Focus sessions go and learn:
    // - Which contacts actually have urgent matters
    // - Optimal reply timing
    // - Which phrases indicate real urgency
    // - Adjust behavior based on feedback

    struct FocusSessionAnalytics: Codable, Sendable {
        let sessionId: UUID
        let focusModeId: String
        let startTime: Date
        var endTime: Date?
        var messagesReceived: Int
        var callsReceived: Int
        var urgentMarked: Int
        var actuallyUrgent: Int // Based on user feedback
        var autoRepliesSent: Int
        var contactResponses: [String: ContactResponse] // Contact -> their response

        struct ContactResponse: Codable, Sendable {
            let contactId: String
            var messagesBeforeUrgent: Int
            var claimedUrgent: Bool
            var wasActuallyUrgent: Bool?
            var responseTime: TimeInterval?
        }
    }

    func startSessionAnalytics(mode: FocusModeConfiguration) {
        setCurrentSessionAnalytics(FocusSessionAnalytics(
            sessionId: UUID(),
            focusModeId: mode.id,
            startTime: Date(),
            messagesReceived: 0,
            callsReceived: 0,
            urgentMarked: 0,
            actuallyUrgent: 0,
            autoRepliesSent: 0,
            contactResponses: [:]
        ))
    }

    func applyLearningFromSession(mode: FocusModeConfiguration) async {
        guard var analytics = getCurrentSessionAnalytics() else { return }

        analytics.endTime = Date()
        appendHistoricalAnalytics(analytics)

        // Analyze patterns
        if getGlobalSettings().trackResponsePatterns {
            await analyzeContactPatterns()
        }

        if getGlobalSettings().adjustPriorityFromFeedback {
            await adjustContactPriorities()
        }

        if getGlobalSettings().learnOptimalReplyTiming {
            await analyzeOptimalTiming()
        }

        if getGlobalSettings().learnUrgencyIndicators {
            await learnNewUrgencyPatterns()
        }

        // Save analytics
        await saveAnalytics()

        setCurrentSessionAnalytics(nil)
    }

    func analyzeContactPatterns() async {
        // Analyze which contacts frequently mark things as urgent
        // Adjust their priority scores accordingly

        var urgencyFrequency: [String: Double] = [:]

        for session in getHistoricalAnalytics() {
            for (contactId, response) in session.contactResponses {
                if response.claimedUrgent {
                    urgencyFrequency[contactId, default: 0] += 1
                }
            }
        }

        // Contacts who frequently claim urgency might need different handling
        for (contactId, frequency) in urgencyFrequency {
            if frequency > 5 {
                // This contact often has urgent matters
                let current = getContactPriority(contactId)
                setContactPriorityValue(contactId, priority: min(1.0, current + 0.1))
            }
        }
    }

    func adjustContactPriorities() async {
        // Adjust based on whether "urgent" claims were actually urgent
        // This requires user feedback mechanism
    }

    func analyzeOptimalTiming() async {
        // Analyze when auto-replies are most effective
        // e.g., immediate replies vs delayed replies
    }

    func learnNewUrgencyPatterns() async {
        // Look for new phrases that indicate urgency
        // that aren't in our current keyword list
    }

    func saveAnalytics() async {
        if let defaults = UserDefaults(suiteName: "group.app.theathe"),
           let encoded = try? JSONEncoder().encode(getHistoricalAnalytics()) {
            defaults.set(encoded, forKey: "focusModeAnalytics")
            defaults.synchronize()
        }
    }

    // MARK: - Public API for User Feedback (Enhancement 8)

    /// User marks whether a contact's matter was actually urgent
    public func markUrgencyFeedback(contactId: String, wasActuallyUrgent: Bool) {
        guard var analytics = getCurrentSessionAnalytics(),
              var response = analytics.contactResponses[contactId] else { return }

        response.wasActuallyUrgent = wasActuallyUrgent
        analytics.contactResponses[contactId] = response

        if wasActuallyUrgent {
            analytics.actuallyUrgent += 1
        }

        setCurrentSessionAnalytics(analytics)

        // Adjust contact priority based on feedback
        if getGlobalSettings().adjustPriorityFromFeedback {
            let currentPriority = getContactPriority(contactId)

            if wasActuallyUrgent {
                // They were right, increase priority slightly
                setContactPriorityValue(contactId, priority: min(1.0, currentPriority + 0.05))
            } else {
                // They weren't urgent, decrease priority slightly
                setContactPriorityValue(contactId, priority: max(0.0, currentPriority - 0.02))
            }
        }
    }

    // MARK: - Public API for Shortcuts Integration

    /// Called when Focus mode changes via Shortcuts automation
    public func setActiveFocusMode(_ modeName: String?) async {
        if let name = modeName {
            // Find the mode by name
            if let mode = getAllFocusModes().first(where: { $0.name == name }) {
                var activeMode = mode
                activeMode.isActive = true
                setCurrentFocusModeValue(activeMode)
                await handleFocusModeActivated(activeMode)
                notifyFocusModeChanged(activeMode)
            }
        } else {
            // Focus mode deactivated
            if let previousMode = getCurrentFocusMode() {
                setCurrentFocusModeValue(nil)
                await handleFocusModeDeactivated(previousMode)
                notifyFocusModeChanged(nil)
            }
        }
    }

    /// Generate Shortcuts automation instructions
    public func generateShortcutsSetupInstructions() -> String {
        """
        # THEA Focus Mode Shortcuts Setup

        ## Required Shortcuts (THEA will help create these automatically)

        ### 1. "THEA Focus Activated" (Automation)
        **Trigger:** When ANY Focus mode turns ON
        **Actions:**
        1. Get name of Focus
        2. Open URL: thea://focus-activated?mode=[Focus Name]

        ### 2. "THEA Focus Deactivated" (Automation)
        **Trigger:** When ANY Focus mode turns OFF
        **Actions:**
        1. Open URL: thea://focus-deactivated

        ### 3. "THEA Call Forwarding" (Shortcut)
        **Input:** USSD code (e.g., *21*086#)
        **Actions:**
        1. Get text from Input
        2. Call [Input text]

        Note: This enables/disables call forwarding to COMBOX

        ### 4. "THEA Auto Reply" (Shortcut)
        **Input:** "phoneNumber|message"
        **Actions:**
        1. Split Input by "|"
        2. Send Message [Item 2] to [Item 1]

        ### 5. "THEA WhatsApp Reply" (Shortcut)
        **Input:** "phoneNumber|message"
        **Actions:**
        1. Split Input by "|"
        2. Open URL: whatsapp://send?phone=[Item 1]&text=[URL-encoded Item 2]
        3. Wait 1 second
        4. Tap "Send" (accessibility)

        ### 6. "THEA COMBOX Greeting" (Shortcut)
        **Input:** greeting type
        **Actions:**
        1. Call 086
        2. Wait for answer
        3. Play DTMF: 9 (settings menu)
        4. Wait 1 second
        5. Play DTMF: 1 (greeting settings)
        6. Wait 1 second
        7. If Input = "focus_mode": Play DTMF: 2
           Else: Play DTMF: 1

        ## Important Notes

        - Enable "Ask Before Running" = OFF for all automations
        - Grant necessary permissions to THEA app
        - Test each shortcut individually first

        ## Why Call Forwarding?

        When Focus Mode blocks calls, iOS **immediately rejects them** at the network level.
        The caller hears a 3-tone disconnect sound (like you hung up).
        They can't leave voicemail, and "call twice" won't work!

        **Solution:** Forward ALL calls to COMBOX when Focus is active.
        - Calls go to voicemail instead of being rejected
        - COMBOX plays a Focus-aware greeting
        - THEA sends SMS after voicemail with callback instructions
        """
    }

    // MARK: - Reliability: Action Verification & Retry

    /// Track pending actions that need verification
    struct PendingAction: Identifiable, Sendable {
        let id: UUID
        let actionType: ActionType
        let timestamp: Date
        var attempts: Int
        var lastAttempt: Date
        var verified: Bool
        let maxRetries: Int
        let verificationMethod: VerificationMethod

        enum ActionType: String, Sendable {
            case callForwardingEnable
            case callForwardingDisable
            case comboxGreetingChange
            case whatsAppStatusUpdate
            case sendAutoReply
            case shortcutExecution
        }

        enum VerificationMethod: String, Sendable {
            case callbackURL // THEA receives callback when done
            case pollStatus // Check status after delay
            case assumeSuccess // Fire and forget
            case userConfirmation // Ask user to confirm
        }
    }

    /// Execute action with verification and retry logic
    func executeWithVerification(
        actionType: PendingAction.ActionType,
        action: @escaping () async -> Bool,
        verificationMethod: PendingAction.VerificationMethod = .pollStatus,
        maxRetries: Int = 3
    ) async -> Bool {
        let pendingAction = PendingAction(
            id: UUID(),
            actionType: actionType,
            timestamp: Date(),
            attempts: 0,
            lastAttempt: Date(),
            verified: false,
            maxRetries: maxRetries,
            verificationMethod: verificationMethod
        )

        appendPendingAction(pendingAction)

        for attempt in 1...maxRetries {
            print("[Reliability] Executing \(actionType.rawValue), attempt \(attempt)/\(maxRetries)")

            let success = await action()

            if success {
                // Verify the action actually worked
                if verificationMethod == .pollStatus {
                    try? await Task.sleep(for: .seconds(2))
                    let verified = await verifyAction(actionType)
                    if verified {
                        markActionVerified(pendingAction.id)
                        return true
                    }
                } else {
                    markActionVerified(pendingAction.id)
                    return true
                }
            }

            // Wait before retry with exponential backoff
            let delay = Double(attempt) * 2.0
            try? await Task.sleep(for: .seconds(delay))
        }

        // All retries failed - notify user
        await notifyUserOfFailedAction(actionType)
        return false
    }

    func verifyAction(_ actionType: PendingAction.ActionType) async -> Bool {
        switch actionType {
        case .callForwardingEnable:
            // Could check by calling *#21# to query forwarding status
            return true // Assume success for now
        case .callForwardingDisable:
            return true
        case .comboxGreetingChange:
            return true
        case .whatsAppStatusUpdate:
            // Could check WhatsApp Desktop window
            return true
        case .sendAutoReply:
            return true
        case .shortcutExecution:
            return true
        }
    }

    func markActionVerified(_ id: UUID) {
        markPendingActionVerified(id)
    }

    func notifyUserOfFailedAction(_ actionType: PendingAction.ActionType) async {
        let content = UNMutableNotificationContent()
        content.title = "\u{26A0}\u{FE0F} THEA Action Failed"
        content.body = "Failed to execute: \(actionType.rawValue). Please check manually."
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)

        print("[Reliability] Action failed after all retries: \(actionType.rawValue)")
    }

    // MARK: - Proactive Anticipation

    /// Predict when Focus Mode should be activated
    public func predictFocusModeActivation() async -> FocusPrediction? {
        guard getGlobalSettings().suggestFocusModeActivation else { return nil }

        var signals: [PredictionSignal] = []

        // Check calendar for upcoming events
        if let calendarSignal = await checkCalendarForFocusTriggers() {
            signals.append(calendarSignal)
        }

        // Check time patterns (e.g., always Focus at 9am on weekdays)
        if let timeSignal = checkTimePatterns() {
            signals.append(timeSignal)
        }

        // Check location patterns
        if let locationSignal = await checkLocationPatterns() {
            signals.append(locationSignal)
        }

        // Calculate overall prediction
        guard !signals.isEmpty else { return nil }

        let totalConfidence = signals.map { $0.confidence }.reduce(0, +) / Double(signals.count)
        let suggestedMode = determineBestFocusMode(from: signals)

        return FocusPrediction(
            shouldActivate: totalConfidence > 0.7,
            suggestedMode: suggestedMode,
            confidence: totalConfidence,
            signals: signals,
            suggestedTime: signals.compactMap { $0.suggestedTime }.min()
        )
    }

    public struct FocusPrediction: Sendable {
        let shouldActivate: Bool
        let suggestedMode: String?
        let confidence: Double
        let signals: [PredictionSignal]
        let suggestedTime: Date?
    }

    public struct PredictionSignal: Sendable {
        let source: String
        let confidence: Double
        let suggestedMode: String?
        let suggestedTime: Date?
        let reason: String
    }

    func checkCalendarForFocusTriggers() async -> PredictionSignal? {
        #if os(macOS)
        // Check for meetings in the next 15 minutes
        let script = """
        tell application "Calendar"
            set currentDate to current date
            set futureDate to currentDate + (15 * minutes)
            set theCalendars to calendars
            repeat with cal in theCalendars
                set theEvents to (every event of cal whose start date \u{2265} currentDate and start date \u{2264} futureDate)
                if (count of theEvents) > 0 then
                    set theEvent to item 1 of theEvents
                    set eventStart to start date of theEvent
                    return (eventStart as string)
                end if
            end repeat
            return ""
        end tell
        """

        if let result = await runAppleScriptReturning(script), !result.isEmpty {
            return PredictionSignal(
                source: "calendar",
                confidence: 0.9,
                suggestedMode: "Work", // or detect from calendar type
                suggestedTime: Date(), // Parse result
                reason: "Upcoming calendar event"
            )
        }
        #endif

        return nil
    }

    func checkTimePatterns() -> PredictionSignal? {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        let weekday = calendar.component(.weekday, from: Date())
        let isWeekday = weekday >= 2 && weekday <= 6

        // Example: Suggest Work Focus at 9am on weekdays
        if isWeekday && hour == 9 {
            return PredictionSignal(
                source: "time_pattern",
                confidence: 0.7,
                suggestedMode: "Work",
                suggestedTime: nil,
                reason: "Typical work start time"
            )
        }

        // Suggest Sleep Focus at 10pm
        if hour == 22 {
            return PredictionSignal(
                source: "time_pattern",
                confidence: 0.8,
                suggestedMode: "Sleep",
                suggestedTime: nil,
                reason: "Typical sleep time"
            )
        }

        return nil
    }

    func checkLocationPatterns() async -> PredictionSignal? {
        // Would use CoreLocation
        nil
    }

    func determineBestFocusMode(from signals: [PredictionSignal]) -> String? {
        // Return most confident suggestion
        signals.max { $0.confidence < $1.confidence }?.suggestedMode
    }

    // MARK: - Contextual Intelligence

    /// Cross-reference message with calendar, projects, etc.
    func enrichUrgencyWithContext(
        _ assessment: UrgencyAssessment,
        contactId: String?,
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

    func hasMeetingWithContactSoon(_ contactId: String) async -> Bool {
        // Would check calendar for events with this contact
        false
    }

    func messageContainsProjectReference(_ message: String) -> Bool {
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

    func isReplyToYourMessage(contactId: String?) async -> Bool {
        // Would check recent outgoing messages to this contact
        false
    }

    // MARK: - Focus Session Summary

    /// Generate end-of-Focus summary of what happened
    public func generateFocusSessionSummary() async -> FocusSessionSummary {
        let duration = getCurrentSessionAnalytics().map {
            Date().timeIntervalSince($0.startTime)
        } ?? 0

        let allComms = getRecentCommunicationsInternal()

        let missedCalls = allComms.filter {
            $0.type == .missedCall && $0.focusModeWhenReceived != nil
        }

        let messages = allComms.filter {
            $0.type == .message && $0.focusModeWhenReceived != nil
        }

        let urgentContacts = getAllConversationStates().filter {
            $0.value.markedAsUrgent
        }.map { $0.key }

        let pendingResponses = getAllConversationStates().filter {
            $0.value.currentStage == .askedIfUrgent || $0.value.currentStage == .initial
        }.count

        return FocusSessionSummary(
            duration: duration,
            messagesReceived: messages.count,
            callsMissed: missedCalls.count,
            autoRepliesSent: getCurrentSessionAnalytics()?.autoRepliesSent ?? 0,
            urgentContacts: urgentContacts,
            pendingResponses: pendingResponses,
            topPriorityContacts: getTopPriorityContacts(from: messages),
            suggestedFollowUps: await generateFollowUpSuggestions()
        )
    }

    public struct FocusSessionSummary: Sendable {
        let duration: TimeInterval
        let messagesReceived: Int
        let callsMissed: Int
        let autoRepliesSent: Int
        let urgentContacts: [String]
        let pendingResponses: Int
        let topPriorityContacts: [String]
        let suggestedFollowUps: [FollowUpSuggestion]
    }

    public struct FollowUpSuggestion: Sendable {
        let contactId: String
        let reason: String
        let priority: Int // 1 = highest
        let suggestedAction: String
    }

    func getTopPriorityContacts(from communications: [IncomingCommunication]) -> [String] {
        var contactCounts: [String: Int] = [:]
        for comm in communications {
            if let cId = comm.contactId ?? comm.phoneNumber {
                contactCounts[cId, default: 0] += 1
            }
        }

        return contactCounts.sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }
    }

    func generateFollowUpSuggestions() async -> [FollowUpSuggestion] {
        var suggestions: [FollowUpSuggestion] = []

        // Suggest following up with urgent contacts
        for (contactKey, state) in getAllConversationStates() where state.markedAsUrgent {
            suggestions.append(FollowUpSuggestion(
                contactId: contactKey,
                reason: "Marked as urgent during Focus",
                priority: 1,
                suggestedAction: "Call back immediately"
            ))
        }

        // Suggest following up with high-frequency contacts
        for (contactKey, timestamps) in getAllMessageCountTracking() {
            if timestamps.count >= 3 {
                suggestions.append(FollowUpSuggestion(
                    contactId: contactKey,
                    reason: "Sent \(timestamps.count) messages",
                    priority: 2,
                    suggestedAction: "Check their messages"
                ))
            }
        }

        return suggestions.sorted { $0.priority < $1.priority }
    }

    // MARK: - Smart Auto-Focus Activation

    /// Automatically enable Focus based on context
    public func checkAndAutoEnableFocus() async {
        guard getGlobalSettings().autoFocusOnCalendarEvents else { return }

        // Already in Focus?
        guard getCurrentFocusMode() == nil else { return }

        // Check prediction
        if let prediction = await predictFocusModeActivation(),
           prediction.shouldActivate,
           prediction.confidence > 0.85,
           let modeName = prediction.suggestedMode {

            print("[AutoFocus] High-confidence prediction to enable '\(modeName)' Focus")

            // Could auto-enable or just notify user
            let content = UNMutableNotificationContent()
            content.title = "\u{1F4A1} Focus Mode Suggestion"
            content.body = "Should I enable \(modeName) Focus? Reason: \(prediction.signals.first?.reason ?? "detected pattern")"
            content.sound = .default
            content.categoryIdentifier = "FOCUS_SUGGESTION"
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    // MARK: - Swisscom COMBOX Visual Voicemail Integration

    /// Check COMBOX for new voicemails (requires Swisscom Visual Voicemail)
    public func checkComboxForNewVoicemails() async -> [VoicemailInfo] {
        // Swisscom Visual Voicemail pushes to device
        // We can monitor for these notifications

        // This would integrate with the iOS Visual Voicemail system
        // or poll COMBOX status via DTMF commands
        []
    }

    public struct VoicemailInfo: Sendable {
        let callerNumber: String
        let callerName: String?
        let timestamp: Date
        let duration: TimeInterval
        let transcription: String? // If available
        let urgencyAssessment: UrgencyAssessment?
    }

    // MARK: - Health & Activity Awareness

    /// Adjust behavior based on user's current activity
    public func adjustForActivity(_ activity: UserActivity) {
        var settings = getGlobalSettings()
        switch activity {
        case .sleeping:
            // Only true emergencies should break through
            settings.escalationMessageThreshold = 5
        case .exercising:
            // Brief responses only
            settings.autoReplyDelay = 0 // Immediate
        case .driving:
            // Voice-only if needed
            break
        case .inMeeting:
            // Standard Focus behavior
            break
        case .available:
            // Disable auto-replies
            settings.autoReplyEnabled = false
        }
        setGlobalSettings(settings)
    }

    public enum UserActivity: String, Sendable {
        case sleeping, exercising, driving, inMeeting, available
    }
}
