// CallMonitor.swift
// THEA - Voice Call Transcription & Intelligence
// Created by Claude - February 2026
//
// Listens to ALL calls (any app), transcribes in real-time,
// extracts actionable information, commitments, and follow-ups
//
// Query methods are in CallMonitor+Queries.swift
// Deadline integration is in CallMonitor+DeadlineIntegration.swift
// TranscriptionEngine is in CallMonitor+TranscriptionEngine.swift
// CallAnalysisEngine is in CallMonitor+AnalysisEngine.swift
// Analysis helpers are in CallMonitor+AnalysisHelpers.swift

import Foundation
import AVFoundation
import OSLog
#if canImport(Speech)
import Speech
#endif

// MARK: - Module Logger
let callMonitorLogger = Logger(subsystem: "ai.thea.app", category: "CallMonitor")

// MARK: - Call Monitor

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

    // MARK: - Properties (internal for extensions)

    var configuration: Configuration
    var activeCalls: [UUID: CallRecord] = [:]
    var callHistory: [CallRecord] = []
    var isRunning = false
    var transcriptionEngine: TranscriptionEngine?
    var analysisEngine: CallAnalysisEngine?

    // Callbacks
    var onCallStarted: ((CallRecord) -> Void)?
    var onCallEnded: ((CallRecord) -> Void)?
    var onTranscriptUpdated: ((CallRecord, CallTranscriptSegment) -> Void)?
    var onAnalysisComplete: ((CallRecord, CallAnalysis) -> Void)?
    var onActionItemDetected: ((CallAnalysis.ActionItem, CallRecord) -> Void)?
    var onCommitmentDetected: ((CallAnalysis.Commitment, CallRecord) -> Void)?

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

    // MARK: - Private Helpers

    private func startCallMonitoring() async {
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
}
