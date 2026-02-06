//
//  MeetingIntelligence.swift
//  Thea
//
//  Created by Thea
//  Real-time meeting transcription, speaker identification, and action items
//

import Foundation
import os.log

#if canImport(Speech)
    import Speech
#endif

#if canImport(AVFoundation)
    import AVFoundation
#endif

// MARK: - Meeting Intelligence

/// Provides meeting transcription, speaker identification, and action item extraction
@MainActor
public final class MeetingIntelligence: ObservableObject {
    public static let shared = MeetingIntelligence()

    private let logger = Logger(subsystem: "app.thea.meetings", category: "MeetingIntelligence")

    // MARK: - State

    @Published public private(set) var isRecording = false
    @Published public private(set) var currentMeeting: Meeting?
    @Published public private(set) var transcript: [TranscriptSegment] = []
    @Published public private(set) var actionItems: [ActionItem] = []
    @Published public private(set) var detectedParticipants: [Participant] = []
    @Published public private(set) var meetingHistory: [Meeting] = []

    // MARK: - Audio Components

    #if canImport(AVFoundation)
        private var audioEngine: AVAudioEngine?
        #if os(iOS) || os(watchOS) || os(tvOS)
            private var audioSession: AVAudioSession?
        #endif
    #endif

    #if canImport(Speech)
        private var speechRecognizer: SFSpeechRecognizer?
        private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
        private var recognitionTask: SFSpeechRecognitionTask?
    #endif

    // MARK: - Configuration

    public var enableSpeakerIdentification = true
    public var enableActionItemExtraction = true
    public var transcriptionLanguage = "en-US"

    // MARK: - Callbacks

    public var onTranscriptUpdated: (([TranscriptSegment]) -> Void)?
    public var onActionItemDetected: ((ActionItem) -> Void)?
    public var onSpeakerChanged: ((Participant) -> Void)?

    private init() {
        loadMeetingHistory()
        setupSpeechRecognition()
    }

    // MARK: - Speech Recognition Setup

    private func setupSpeechRecognition() {
        #if canImport(Speech)
            speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: transcriptionLanguage))
        #endif
    }

    // MARK: - Meeting Control

    /// Start a new meeting recording
    public func startMeeting(title: String? = nil, participants: [String] = []) async throws {
        guard !isRecording else {
            throw MeetingError.alreadyRecording
        }

        // Request permissions
        try await requestPermissions()

        // Create meeting
        let meeting = Meeting(
            id: UUID().uuidString,
            title: title ?? "Meeting \(Date().formatted(date: .abbreviated, time: .shortened))",
            startTime: Date(),
            participants: participants.map { Participant(name: $0) }
        )

        currentMeeting = meeting
        transcript = []
        actionItems = []
        detectedParticipants = meeting.participants

        // Start audio capture and transcription
        try await startAudioCapture()

        isRecording = true
        logger.info("Meeting started: \(meeting.title)")
    }

    /// Stop the current meeting
    public func stopMeeting() async throws {
        guard isRecording, var meeting = currentMeeting else {
            throw MeetingError.notRecording
        }

        // Stop audio capture
        stopAudioCapture()

        // Finalize meeting
        meeting.endTime = Date()
        meeting.transcript = transcript
        meeting.actionItems = actionItems
        meeting.participants = detectedParticipants

        // Generate summary
        meeting.summary = generateSummary()

        // Save to history
        meetingHistory.insert(meeting, at: 0)
        saveMeetingHistory()

        currentMeeting = meeting
        isRecording = false

        logger.info("Meeting ended: \(meeting.title), duration: \(meeting.duration ?? 0) seconds")
    }

    /// Pause transcription
    public func pauseTranscription() {
        #if canImport(Speech)
            recognitionTask?.cancel()
        #endif
        logger.debug("Transcription paused")
    }

    /// Resume transcription
    public func resumeTranscription() async throws {
        try await startAudioCapture()
        logger.debug("Transcription resumed")
    }

    // MARK: - Audio Capture

    private func startAudioCapture() async throws {
        #if canImport(AVFoundation) && canImport(Speech)
            guard let recognizer = speechRecognizer, recognizer.isAvailable else {
                throw MeetingError.speechRecognitionUnavailable
            }

            audioEngine = AVAudioEngine()
            guard let audioEngine else { return }

            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let request = recognitionRequest else { return }

            request.shouldReportPartialResults = true

            // On supported platforms, enable on-device recognition
            if #available(iOS 13.0, macOS 14.0, *) {
                request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
            }

            // Start recognition
            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    if let result {
                        self?.processRecognitionResult(result)
                    }

                    if let error {
                        self?.logger.error("Recognition error: \(error)")
                    }
                }
            }

            // Configure audio
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()

            logger.info("Audio capture started")
        #endif
    }

    private func stopAudioCapture() {
        #if canImport(AVFoundation) && canImport(Speech)
            recognitionRequest?.endAudio()
            audioEngine?.stop()
            audioEngine?.inputNode.removeTap(onBus: 0)
            recognitionTask?.cancel()

            recognitionRequest = nil
            recognitionTask = nil
            audioEngine = nil

            logger.info("Audio capture stopped")
        #endif
    }

    // MARK: - Transcription Processing

    #if canImport(Speech)
        private func processRecognitionResult(_ result: SFSpeechRecognitionResult) {
            let transcription = result.bestTranscription

            // Create or update current segment
            let text = transcription.formattedString

            // Determine speaker (simplified - would use actual speaker ID)
            let speaker = identifySpeaker(for: transcription)

            // Update transcript
            if transcript.isEmpty || transcript.last?.speaker != speaker {
                // New segment
                let segment = TranscriptSegment(
                    id: UUID().uuidString,
                    text: text,
                    speaker: speaker,
                    startTime: Date(),
                    confidence: Double(result.transcriptions.first?.segments.first?.confidence ?? 0)
                )
                transcript.append(segment)
            } else {
                // Update last segment
                if var lastSegment = transcript.last {
                    lastSegment.text = text
                    transcript[transcript.count - 1] = lastSegment
                }
            }

            onTranscriptUpdated?(transcript)

            // Check for action items in finalized segments
            if result.isFinal {
                extractActionItems(from: text)
            }
        }
    #endif

    #if canImport(Speech)
        private func identifySpeaker(for _: SFTranscription) -> Participant {
            // Simplified speaker identification
            // In a real implementation, would use audio analysis for voice prints

            // Default to first participant or create unknown
            if let firstParticipant = detectedParticipants.first {
                return firstParticipant
            }

            let unknown = Participant(name: "Unknown Speaker")
            detectedParticipants.append(unknown)
            return unknown
        }
    #endif

    // MARK: - Action Item Extraction

    private func extractActionItems(from text: String) {
        // Keywords that indicate action items
        let actionKeywords = [
            "action item", "todo", "to do", "task", "need to",
            "will do", "should do", "must do", "have to",
            "follow up", "followup", "take care of"
        ]

        let lowercaseText = text.lowercased()

        // Check for action keywords
        for keyword in actionKeywords {
            if lowercaseText.contains(keyword) {
                let actionItem = ActionItem(
                    id: UUID().uuidString,
                    text: text,
                    detectedKeyword: keyword,
                    assignee: nil,
                    dueDate: nil,
                    priority: .normal
                )

                // Avoid duplicates
                if !actionItems.contains(where: { $0.text == text }) {
                    actionItems.append(actionItem)
                    onActionItemDetected?(actionItem)
                    logger.debug("Action item detected: \(text.prefix(50))")
                }
                break
            }
        }

        // Also check for questions that might need follow-up
        if text.contains("?"), text.count > 20 {
            // Potential follow-up item
        }
    }

    // MARK: - Summary Generation

    private func generateSummary() -> MeetingSummary {
        let duration = currentMeeting?.duration ?? 0
        let wordCount = transcript.reduce(0) { $0 + $1.text.components(separatedBy: .whitespaces).count }

        // Key topics (simplified - would use NLP)
        let keyTopics = extractKeyTopics()

        // Generate summary text (simplified)
        let summaryText = "Meeting lasted \(Int(duration / 60)) minutes with \(detectedParticipants.count) participants. \(actionItems.count) action items were identified."

        return MeetingSummary(
            text: summaryText,
            keyTopics: keyTopics,
            actionItemCount: actionItems.count,
            participantCount: detectedParticipants.count,
            totalWords: wordCount,
            duration: duration
        )
    }

    private func extractKeyTopics() -> [String] {
        // Simplified topic extraction
        // In production, would use NLP/ML for proper topic modeling

        var wordFrequency: [String: Int] = [:]
        let stopWords = Set(["the", "a", "an", "is", "are", "was", "were", "be", "been", "being",
                             "have", "has", "had", "do", "does", "did", "will", "would", "could",
                             "should", "may", "might", "must", "shall", "can", "need", "dare",
                             "to", "of", "in", "for", "on", "with", "at", "by", "from", "as",
                             "into", "through", "during", "before", "after", "above", "below",
                             "and", "but", "or", "nor", "so", "yet", "both", "either", "neither",
                             "i", "you", "he", "she", "it", "we", "they", "that", "this", "these"])

        for segment in transcript {
            let words = segment.text.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted)
            for word in words where word.count > 3 && !stopWords.contains(word) {
                wordFrequency[word, default: 0] += 1
            }
        }

        // Return top 5 topics
        return wordFrequency
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map(\.key.capitalized)
    }

    // MARK: - Permissions

    private func requestPermissions() async throws {
        #if canImport(Speech)
            let authStatus = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status)
                }
            }
            guard authStatus == .authorized else {
                throw MeetingError.speechRecognitionDenied
            }
        #endif

        #if canImport(AVFoundation)
            // Request microphone access
            let micStatus = await AVAudioApplication.requestRecordPermission()
            guard micStatus else {
                throw MeetingError.microphoneAccessDenied
            }
        #endif
    }

    // MARK: - Meeting History

    private func loadMeetingHistory() {
        if let data = UserDefaults.standard.data(forKey: "thea.meetings.history"),
           let history = try? JSONDecoder().decode([Meeting].self, from: data)
        {
            meetingHistory = history
        }
    }

    private func saveMeetingHistory() {
        // Keep last 50 meetings
        let toSave = Array(meetingHistory.prefix(50))
        if let data = try? JSONEncoder().encode(toSave) {
            UserDefaults.standard.set(data, forKey: "thea.meetings.history")
        }
    }

    /// Delete a meeting from history
    public func deleteMeeting(_ id: String) {
        meetingHistory.removeAll { $0.id == id }
        saveMeetingHistory()
    }

    /// Get meeting by ID
    public func getMeeting(_ id: String) -> Meeting? {
        meetingHistory.first { $0.id == id }
    }
}

// MARK: - Models

public struct Meeting: Identifiable, Codable, Sendable {
    public let id: String
    public var title: String
    public let startTime: Date
    public var endTime: Date?
    public var participants: [Participant]
    public var transcript: [TranscriptSegment]
    public var actionItems: [ActionItem]
    public var summary: MeetingSummary?

    public var duration: TimeInterval? {
        guard let end = endTime else { return nil }
        return end.timeIntervalSince(startTime)
    }

    public init(
        id: String,
        title: String,
        startTime: Date,
        endTime: Date? = nil,
        participants: [Participant] = [],
        transcript: [TranscriptSegment] = [],
        actionItems: [ActionItem] = [],
        summary: MeetingSummary? = nil
    ) {
        self.id = id
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.participants = participants
        self.transcript = transcript
        self.actionItems = actionItems
        self.summary = summary
    }
}

public struct Participant: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public var name: String
    public var email: String?
    public var speakerProfile: Data? // Voice print data

    public init(name: String, email: String? = nil) {
        id = UUID().uuidString
        self.name = name
        self.email = email
    }

    public static func == (lhs: Participant, rhs: Participant) -> Bool {
        lhs.id == rhs.id
    }
}

public struct TranscriptSegment: Identifiable, Codable, Sendable {
    public let id: String
    public var text: String
    public var speaker: Participant
    public let startTime: Date
    public var endTime: Date?
    public var confidence: Double

    public init(
        id: String,
        text: String,
        speaker: Participant,
        startTime: Date,
        endTime: Date? = nil,
        confidence: Double = 1.0
    ) {
        self.id = id
        self.text = text
        self.speaker = speaker
        self.startTime = startTime
        self.endTime = endTime
        self.confidence = confidence
    }
}

public struct ActionItem: Identifiable, Codable, Sendable {
    public let id: String
    public let text: String
    public let detectedKeyword: String?
    public var assignee: Participant?
    public var dueDate: Date?
    public var priority: Priority
    public var isCompleted: Bool

    public enum Priority: String, Codable, Sendable {
        case low, normal, high, urgent
    }

    public init(
        id: String,
        text: String,
        detectedKeyword: String? = nil,
        assignee: Participant? = nil,
        dueDate: Date? = nil,
        priority: Priority = .normal,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.text = text
        self.detectedKeyword = detectedKeyword
        self.assignee = assignee
        self.dueDate = dueDate
        self.priority = priority
        self.isCompleted = isCompleted
    }
}

public struct MeetingSummary: Codable, Sendable {
    public let text: String
    public let keyTopics: [String]
    public let actionItemCount: Int
    public let participantCount: Int
    public let totalWords: Int
    public let duration: TimeInterval
}

// MARK: - Errors

public enum MeetingError: Error, LocalizedError {
    case alreadyRecording
    case notRecording
    case speechRecognitionUnavailable
    case speechRecognitionDenied
    case microphoneAccessDenied

    public var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            "A meeting is already being recorded"
        case .notRecording:
            "No meeting is currently being recorded"
        case .speechRecognitionUnavailable:
            "Speech recognition is not available"
        case .speechRecognitionDenied:
            "Speech recognition permission was denied"
        case .microphoneAccessDenied:
            "Microphone access was denied"
        }
    }
}
