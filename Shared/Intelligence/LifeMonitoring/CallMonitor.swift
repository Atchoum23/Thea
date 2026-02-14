// CallMonitor.swift
// THEA - Voice Call Transcription & Intelligence
// Created by Claude - February 2026
//
// Listens to ALL calls (any app), transcribes in real-time,
// extracts actionable information, commitments, and follow-ups

import Foundation
import AVFoundation
#if canImport(Speech)
import Speech
#endif

// MARK: - Call Monitor

/// Main engine for monitoring, transcribing, and analyzing calls
public actor CallMonitor {
    // MARK: - Singleton

    public static let shared = CallMonitor()

    // MARK: - Configuration

    public struct Configuration: Sendable {
        public var enableTranscription: Bool = true
        public var enableRealTimeAnalysis: Bool = true
        public var saveAudioRecordings: Bool = false
        public var audioRecordingsPath: String = ""
        public var transcriptionLanguage: String = "en-US"
        public var autoDetectLanguage: Bool = true
        public var monitoredApps: Set<CallSource> = Set(CallSource.allCases)
        public var minCallDurationToAnalyze: TimeInterval = 30 // Only analyze calls > 30s
        public var notifyOnCommitments: Bool = true
        public var notifyOnActionItems: Bool = true
        public var integrateWithDeadlineIntelligence: Bool = true
        public var integrateWithReminders: Bool = true

        public init() {}
    }

    // MARK: - Properties

    private var configuration: Configuration
    private var activeCalls: [UUID: CallRecord] = [:]
    private var callHistory: [CallRecord] = []
    private var isRunning = false
    private var transcriptionEngine: TranscriptionEngine?
    private var analysisEngine: CallAnalysisEngine?

    // Callbacks
    private var onCallStarted: ((CallRecord) -> Void)?
    private var onCallEnded: ((CallRecord) -> Void)?
    private var onTranscriptUpdated: ((CallRecord, CallTranscriptSegment) -> Void)?
    private var onAnalysisComplete: ((CallRecord, CallAnalysis) -> Void)?
    private var onActionItemDetected: ((CallAnalysis.ActionItem, CallRecord) -> Void)?
    private var onCommitmentDetected: ((CallAnalysis.Commitment, CallRecord) -> Void)?

    // MARK: - Initialization

    private init() {
        self.configuration = Configuration()
        self.transcriptionEngine = TranscriptionEngine()
        self.analysisEngine = CallAnalysisEngine()
    }

    // MARK: - Configuration

    public func configure(_ config: Configuration) {
        self.configuration = config
    }

    public func configure(
        onCallStarted: @escaping @Sendable (CallRecord) -> Void,
        onCallEnded: @escaping @Sendable (CallRecord) -> Void,
        onTranscriptUpdated: @escaping @Sendable (CallRecord, CallTranscriptSegment) -> Void,
        onAnalysisComplete: @escaping @Sendable (CallRecord, CallAnalysis) -> Void,
        onActionItemDetected: @escaping @Sendable (CallAnalysis.ActionItem, CallRecord) -> Void,
        onCommitmentDetected: @escaping @Sendable (CallAnalysis.Commitment, CallRecord) -> Void
    ) {
        self.onCallStarted = onCallStarted
        self.onCallEnded = onCallEnded
        self.onTranscriptUpdated = onTranscriptUpdated
        self.onAnalysisComplete = onAnalysisComplete
        self.onActionItemDetected = onActionItemDetected
        self.onCommitmentDetected = onCommitmentDetected
    }

    // MARK: - Lifecycle

    public func start() async {
        guard !isRunning else { return }
        isRunning = true

        // Start monitoring for calls
        await startCallMonitoring()

        // Initialize transcription engine
        await transcriptionEngine?.initialize(language: configuration.transcriptionLanguage)
    }

    public func stop() async {
        isRunning = false

        // End any active calls
        for callId in activeCalls.keys {
            await endCall(callId)
        }

        // Stop transcription
        await transcriptionEngine?.stop()
    }

    // MARK: - Call Management

    /// Start tracking a new call
    public func startCall(
        source: CallSource,
        type: CallType,
        participants: [CallParticipant],
        metadata: CallRecord.CallMetadata
    ) async -> UUID {
        let call = CallRecord(
            source: source,
            type: type,
            participants: participants,
            metadata: metadata
        )

        activeCalls[call.id] = call
        onCallStarted?(call)

        // Start transcription if enabled
        if configuration.enableTranscription {
            await startTranscription(for: call.id)
        }

        return call.id
    }

    /// End an active call
    public func endCall(_ callId: UUID) async {
        guard var call = activeCalls[callId] else { return }

        call.endTime = Date()
        call.status = .ended

        // Stop transcription
        await stopTranscription(for: callId)

        // Analyze if long enough
        if call.duration >= configuration.minCallDurationToAnalyze {
            if let analysis = await analyzeCall(call) {
                call.analysis = analysis
                onAnalysisComplete?(call, analysis)

                // Notify about action items and commitments
                for item in analysis.actionItems {
                    onActionItemDetected?(item, call)
                }
                for commitment in analysis.commitments {
                    onCommitmentDetected?(commitment, call)
                }

                // Integrate with DeadlineIntelligence
                if configuration.integrateWithDeadlineIntelligence {
                    await integrateWithDeadlines(analysis, call: call)
                }
            }
        }

        // Move to history
        activeCalls.removeValue(forKey: callId)
        callHistory.append(call)

        // Keep history manageable (last 1000 calls)
        if callHistory.count > 1000 {
            callHistory.removeFirst(callHistory.count - 1000)
        }

        onCallEnded?(call)
    }

    /// Update call with new audio for transcription
    /// Update call with new audio for transcription
    /// Note: This must be called from the main thread/queue where the buffer is valid
    public func processAudio(_ buffer: AVAudioPCMBuffer, forCall callId: UUID) async {
        guard activeCalls[callId] != nil else { return }

        // Wrap buffer to cross actor boundary safely
        let sendableBuffer = SendableAudioBuffer(buffer)

        // Send to transcription engine
        if let segment = await transcriptionEngine?.transcribe(buffer: sendableBuffer, callId: callId) {
            // Update transcript
            activeCalls[callId]?.transcript.segments.append(segment)

            if let call = activeCalls[callId] {
                onTranscriptUpdated?(call, segment)
            }

            // Real-time analysis for urgent items
            if configuration.enableRealTimeAnalysis {
                await performRealTimeAnalysis(segment, callId: callId)
            }
        }
    }

    // MARK: - Query

    /// Get active calls
    public func getActiveCalls() -> [CallRecord] {
        Array(activeCalls.values)
    }

    /// Get call history
    public func getCallHistory(limit: Int = 100) -> [CallRecord] {
        Array(callHistory.suffix(limit))
    }

    /// Get calls with a specific contact
    public func getCalls(with identifier: String) -> [CallRecord] {
        callHistory.filter { call in
            call.participants.contains { $0.identifier == identifier }
        }
    }

    /// Search transcripts
    public func searchTranscripts(query: String) -> [(CallRecord, [CallTranscriptSegment])] {
        let lowercasedQuery = query.lowercased()
        var results: [(CallRecord, [CallTranscriptSegment])] = []

        for call in callHistory {
            let matchingSegments = call.transcript.segments.filter {
                $0.text.lowercased().contains(lowercasedQuery)
            }
            if !matchingSegments.isEmpty {
                results.append((call, matchingSegments))
            }
        }

        return results
    }

    /// Get all action items from recent calls
    public func getRecentActionItems(days: Int = 7) -> [CallAnalysis.ActionItem] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        return callHistory
            .filter { $0.startTime >= cutoff }
            .compactMap { $0.analysis?.actionItems }
            .flatMap { $0 }
    }

    /// Get all commitments from recent calls
    public func getRecentCommitments(days: Int = 7) -> [CallAnalysis.Commitment] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        return callHistory
            .filter { $0.startTime >= cutoff }
            .compactMap { $0.analysis?.commitments }
            .flatMap { $0 }
    }

    // MARK: - Private Methods

    private func startCallMonitoring() async {
        // This would integrate with:
        // 1. CallKit for phone calls
        // 2. App-specific APIs (Zoom SDK, Teams SDK, etc.)
        // 3. Audio session monitoring for other apps
        // 4. Accessibility APIs if available

        // Note: Actual implementation requires proper permissions and
        // may vary by platform and app
    }

    private func startTranscription(for callId: UUID) async {
        await transcriptionEngine?.startSession(callId: callId)
    }

    private func stopTranscription(for callId: UUID) async {
        await transcriptionEngine?.stopSession(callId: callId)
    }

    private func analyzeCall(_ call: CallRecord) async -> CallAnalysis? {
        await analysisEngine?.analyze(call)
    }

    private func performRealTimeAnalysis(_ segment: CallTranscriptSegment, callId: UUID) async {
        // Quick check for urgent patterns
        let text = segment.text.lowercased()

        // Check for commitment language
        let commitmentPatterns = [
            "i will", "i'll", "i promise", "i commit",
            "you can count on me", "consider it done",
            "i guarantee", "absolutely", "definitely"
        ]

        for pattern in commitmentPatterns {
            if text.contains(pattern) {
                // Flag this segment for detailed analysis
                // Could trigger immediate notification
                break
            }
        }

        // Check for deadline mentions
        let deadlinePatterns = [
            "by tomorrow", "by friday", "end of day",
            "by the end of", "deadline is", "due on"
        ]

        for pattern in deadlinePatterns {
            if text.contains(pattern) {
                // Flag for deadline extraction
                break
            }
        }
    }

    private func integrateWithDeadlines(_ analysis: CallAnalysis, call: CallRecord) async {
        // Send deadlines to DeadlineIntelligence
        for deadline in analysis.deadlinesMentioned {
            let extractedDeadline = Deadline(
                title: deadline.description,
                description: "Mentioned in call with \(call.participants.compactMap { $0.name }.joined(separator: ", "))",
                dueDate: deadline.date,
                source: .voiceCall,
                category: .work,
                extractedFrom: Deadline.ExtractionContext(
                    sourceText: deadline.context,
                    sourceURL: nil,
                    sourceFile: nil,
                    extractionMethod: "CallMonitor",
                    timestamp: Date()
                ),
                confidence: 0.7
            )
            await DeadlineIntelligence.shared.addDeadline(extractedDeadline)
        }

        // Convert action items with due dates to deadlines
        for item in analysis.actionItems where item.dueDate != nil {
            let deadline = Deadline(
                title: item.description,
                description: "Action item from call",
                dueDate: item.dueDate!,
                source: .voiceCall,
                category: .work,
                priority: item.priority == .urgent ? 9 : (item.priority == .high ? 7 : 5),
                extractedFrom: Deadline.ExtractionContext(
                    sourceText: item.extractedFrom,
                    sourceURL: nil,
                    sourceFile: nil,
                    extractionMethod: "CallMonitor.ActionItem",
                    timestamp: Date()
                ),
                confidence: 0.75
            )
            await DeadlineIntelligence.shared.addDeadline(deadline)
        }

        // Convert commitments with deadlines
        for commitment in analysis.commitments where commitment.deadline != nil {
            let deadline = Deadline(
                title: "Commitment: \(commitment.description)",
                description: "Made by \(commitment.madeBy)",
                dueDate: commitment.deadline!,
                source: .voiceCall,
                category: .work,
                extractedFrom: Deadline.ExtractionContext(
                    sourceText: commitment.extractedFrom,
                    sourceURL: nil,
                    sourceFile: nil,
                    extractionMethod: "CallMonitor.Commitment",
                    timestamp: Date()
                ),
                confidence: 0.8
            )
            await DeadlineIntelligence.shared.addDeadline(deadline)
        }
    }
}

// MARK: - Transcription Engine

/// Engine for real-time speech transcription
actor TranscriptionEngine {
    #if canImport(Speech)
    private var recognizer: SFSpeechRecognizer?
    private var sessions: [UUID: SFSpeechAudioBufferRecognitionRequest] = [:]
    private var tasks: [UUID: SFSpeechRecognitionTask] = [:]
    #endif
    private var currentSpeaker: String = "Unknown"
    private var segmentStartTime: Date?

    func initialize(language: String) async {
        #if canImport(Speech)
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: language))
        #endif
    }

    func startSession(callId: UUID) async {
        #if canImport(Speech)
        guard recognizer != nil else { return }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true // Privacy: on-device only

        sessions[callId] = request
        segmentStartTime = Date()
        #endif
    }

    func stopSession(callId: UUID) async {
        #if canImport(Speech)
        sessions[callId]?.endAudio()
        sessions.removeValue(forKey: callId)
        tasks[callId]?.cancel()
        tasks.removeValue(forKey: callId)
        #endif
    }

    /// Transcribe audio buffer using Sendable wrapper
    func transcribe(buffer: SendableAudioBuffer, callId: UUID) async -> CallTranscriptSegment? {
        #if canImport(Speech)
        guard let request = sessions[callId], let recognizer = recognizer else {
            return nil
        }

        // Append audio from the wrapped buffer
        request.append(buffer.buffer)

        // If no active task, start one
        if tasks[callId] == nil {
            let task = recognizer.recognitionTask(with: request) { _, _ in
                // Handle results
                // This is simplified - actual implementation would be more complex
            }
            tasks[callId] = task
        }

        // Return a segment (simplified - actual implementation uses delegate pattern)
        return nil
        #else
        return nil
        #endif
    }

    func stop() async {
        #if canImport(Speech)
        for (_, request) in sessions {
            request.endAudio()
        }
        for (_, task) in tasks {
            task.cancel()
        }
        sessions.removeAll()
        tasks.removeAll()
        #endif
    }
}

// MARK: - Call Analysis Engine

/// Engine for analyzing call content
actor CallAnalysisEngine {

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

    private func generateSummary(_ call: CallRecord) -> String {
        let duration = Int(call.duration / 60)
        let participantNames = call.participants.compactMap { $0.name ?? $0.identifier }.joined(separator: ", ")
        let topics = extractTopics(call.transcript.fullText).prefix(3).map { $0.name }.joined(separator: ", ")

        return "\(duration)-minute call with \(participantNames). Main topics: \(topics.isEmpty ? "General discussion" : topics)"
    }

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

    private func extractCommitments(_ text: String, call: CallRecord) -> [CallAnalysis.Commitment] {
        var commitments: [CallAnalysis.Commitment] = []

        let patterns = [
            #"(?i)(I promise|I commit|I guarantee|I'll make sure|you can count on me)[:\s]+([^.!?]+)"#,
            #"(?i)(I will|I'll)\s+(definitely|certainly|absolutely)\s+([^.!?]+)"#,
            #"(?i)consider it done[.!]?\s*([^.!?]*)"#
        ]

        for pattern in patterns {
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

    private func extractFollowUps(_ text: String) -> [CallAnalysis.FollowUp] {
        var followUps: [CallAnalysis.FollowUp] = []

        let patterns = [
            (#"(?i)let's (schedule|set up|arrange) (a|another) (call|meeting|follow-up)"#, CallAnalysis.FollowUp.FollowUpType.meeting),
            (#"(?i)I'll (send|forward|email) you"#, .email),
            (#"(?i)let's (touch base|reconnect|talk again)"#, .call),
            (#"(?i)follow up (on|with|about)"#, .other)
        ]

        for (pattern, type) in patterns {
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

    private func extractDeadlines(_ text: String) -> [CallAnalysis.MentionedDeadline] {
        var deadlines: [CallAnalysis.MentionedDeadline] = []

        let patterns = [
            #"(?i)(due|deadline|by|before|until)\s+(\w+\s+\d{1,2}(?:st|nd|rd|th)?,?\s*\d{0,4})"#,
            #"(?i)(due|deadline|by|before|until)\s+(tomorrow|monday|tuesday|wednesday|thursday|friday|saturday|sunday|next week|end of (?:day|week|month))"#
        ]

        for pattern in patterns {
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

    private func analyzeSentiment(_ call: CallRecord) -> CallAnalysis.CallSentiment {
        // Simplified sentiment analysis
        // Real implementation would use ML model

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

    private func extractTopics(_ text: String) -> [CallAnalysis.Topic] {
        // Simplified topic extraction
        // Real implementation would use NLP/ML

        var topicCounts: [String: Int] = [:]

        // Common topic keywords
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

    private func extractDecisions(_ text: String) -> [CallAnalysis.Decision] {
        var decisions: [CallAnalysis.Decision] = []

        let patterns = [
            #"(?i)(we decided|we've decided|the decision is|we agreed|let's go with)\s+([^.!?]+)"#,
            #"(?i)(final decision|our decision)[:\s]+([^.!?]+)"#
        ]

        for pattern in patterns {
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

    // MARK: - Helper Methods

    private func extractDateFromContext(_ text: String) -> Date? {
        let lowercased = text.lowercased()
        let calendar = Calendar.current
        let now = Date()

        // Tomorrow
        if lowercased.contains("tomorrow") {
            return calendar.date(byAdding: .day, value: 1, to: now)
        }

        // Day names
        let days = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
        for (index, day) in days.enumerated() {
            if lowercased.contains("next \(day)") {
                let currentWeekday = calendar.component(.weekday, from: now)
                var daysToAdd = index + 1 - currentWeekday
                if daysToAdd <= 0 { daysToAdd += 7 }
                daysToAdd += 7 // "next" means following week
                return calendar.date(byAdding: .day, value: daysToAdd, to: now)
            } else if lowercased.contains(day) {
                let currentWeekday = calendar.component(.weekday, from: now)
                var daysToAdd = index + 1 - currentWeekday
                if daysToAdd <= 0 { daysToAdd += 7 }
                return calendar.date(byAdding: .day, value: daysToAdd, to: now)
            }
        }

        // End of day/week/month
        if lowercased.contains("end of day") || lowercased.contains("eod") {
            return calendar.date(bySettingHour: 17, minute: 0, second: 0, of: now)
        } else if lowercased.contains("end of week") || lowercased.contains("eow") {
            let weekday = calendar.component(.weekday, from: now)
            let daysToFriday = (6 - weekday + 7) % 7
            return calendar.date(byAdding: .day, value: daysToFriday, to: now)
        } else if lowercased.contains("end of month") || lowercased.contains("eom") {
            let range = calendar.range(of: .day, in: .month, for: now)!
            let daysInMonth = range.count
            let currentDay = calendar.component(.day, from: now)
            return calendar.date(byAdding: .day, value: daysInMonth - currentDay, to: now)
        }

        return nil
    }

    private func parseDate(_ text: String) -> Date? {
        // Try various date formats
        let formatters: [DateFormatter] = [
            {
                let f = DateFormatter()
                f.dateFormat = "MMMM d, yyyy"
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "MMMM d"
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "MM/dd/yyyy"
                return f
            }()
        ]

        for formatter in formatters {
            if let date = formatter.date(from: text) {
                return date
            }
        }

        return extractDateFromContext(text)
    }

    private func extractAssignee(_ text: String, participants: [CallParticipant]) -> String? {
        let lowercased = text.lowercased()

        // Check for explicit assignment
        if lowercased.contains("i will") || lowercased.contains("i'll") {
            return "Me"
        }

        // Check for "you" patterns
        if lowercased.contains("you need to") || lowercased.contains("you should") || lowercased.contains("can you") {
            // Try to identify which participant
            for participant in participants where !participant.isLocalUser {
                if let name = participant.name {
                    return name
                }
            }
            return "Other party"
        }

        return nil
    }

    private func expandContext(_ text: String, range: NSRange, chars: Int) -> String {
        let nsText = text as NSString
        let start = max(0, range.location - chars)
        let end = min(nsText.length, range.location + range.length + chars)
        return nsText.substring(with: NSRange(location: start, length: end - start))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
