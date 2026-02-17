// CallMonitor.swift
// THEA - Voice Call Transcription & Intelligence
// Created by Claude - February 2026
//
// Listens to ALL calls (any app), transcribes in real-time,
// extracts actionable information, commitments, and follow-ups.
//
// Split into focused modules:
//   CallMonitor.swift                         — Core actor, lifecycle, call management
//   CallMonitor+Queries.swift                 — Query/search methods
//   CallMonitor+DeadlineIntegration.swift      — Real-time analysis & deadline forwarding
//   CallMonitor+TranscriptionEngine.swift      — Speech-to-text engine
//   CallMonitor+AnalysisEngine.swift           — Post-call analysis engine
//   CallMonitor+AnalysisHelpers.swift          — Date parsing, assignee, context helpers
//   CallMonitorTypes.swift                     — Data model types (pre-existing)

import Foundation
import AVFoundation
#if canImport(Speech)
import Speech
#endif

// MARK: - Call Monitor

/// Main engine for monitoring, transcribing, and analyzing voice calls.
///
/// `CallMonitor` is an actor-isolated singleton that:
/// - Tracks active calls from any source (phone, FaceTime, Zoom, Teams, etc.)
/// - Transcribes audio in real time via `TranscriptionEngine`
/// - Performs post-call analysis via `CallAnalysisEngine`
/// - Integrates extracted deadlines, action items, and commitments with `DeadlineIntelligence`
///
/// Usage:
/// ```swift
/// await CallMonitor.shared.start()
/// let callId = await CallMonitor.shared.startCall(
///     source: .zoom, type: .incoming,
///     participants: [participant],
///     metadata: metadata
/// )
/// // ... feed audio buffers ...
/// await CallMonitor.shared.endCall(callId)
/// ```
public actor CallMonitor {

    // MARK: - Singleton

    /// The shared `CallMonitor` instance.
    public static let shared = CallMonitor()

    // MARK: - Configuration

    /// Configuration options controlling transcription, analysis, and integration behavior.
    public struct Configuration: Sendable {
        /// Whether to transcribe call audio in real time.
        public var enableTranscription: Bool = true
        /// Whether to run lightweight pattern matching on each new transcript segment.
        public var enableRealTimeAnalysis: Bool = true
        /// Whether to save raw audio recordings to disk.
        public var saveAudioRecordings: Bool = false
        /// File-system path for saved audio recordings.
        public var audioRecordingsPath: String = ""
        /// BCP-47 language code for the speech recognizer (e.g., "en-US").
        public var transcriptionLanguage: String = "en-US"
        /// Whether to auto-detect the spoken language.
        public var autoDetectLanguage: Bool = true
        /// The set of call sources to monitor.
        public var monitoredApps: Set<CallSource> = Set(CallSource.allCases)
        /// Minimum call duration (in seconds) required before post-call analysis runs.
        public var minCallDurationToAnalyze: TimeInterval = 30
        /// Whether to notify the user when commitments are detected.
        public var notifyOnCommitments: Bool = true
        /// Whether to notify the user when action items are detected.
        public var notifyOnActionItems: Bool = true
        /// Whether to forward extracted deadlines to `DeadlineIntelligence`.
        public var integrateWithDeadlineIntelligence: Bool = true
        /// Whether to create reminders from extracted action items.
        public var integrateWithReminders: Bool = true

        public init() {}
    }

    // MARK: - Properties

    /// The current configuration.
    var configuration: Configuration
    /// Active (in-progress) calls keyed by UUID.
    var activeCalls: [UUID: CallRecord] = [:]
    /// Completed calls stored in chronological order (capped at 1000).
    var callHistory: [CallRecord] = []
    /// Whether the monitor is currently running.
    private var isRunning = false
    /// The speech transcription engine.
    var transcriptionEngine: TranscriptionEngine?
    /// The post-call analysis engine.
    var analysisEngine: CallAnalysisEngine?

    // MARK: - Callbacks

    /// Called when a new call begins.
    private var onCallStarted: ((CallRecord) -> Void)?
    /// Called when a call ends.
    private var onCallEnded: ((CallRecord) -> Void)?
    /// Called when a new transcript segment is produced.
    private var onTranscriptUpdated: ((CallRecord, CallTranscriptSegment) -> Void)?
    /// Called when post-call analysis completes.
    private var onAnalysisComplete: ((CallRecord, CallAnalysis) -> Void)?
    /// Called for each action item extracted from a call.
    private var onActionItemDetected: ((CallAnalysis.ActionItem, CallRecord) -> Void)?
    /// Called for each commitment extracted from a call.
    private var onCommitmentDetected: ((CallAnalysis.Commitment, CallRecord) -> Void)?

    // MARK: - Initialization

    private init() {
        self.configuration = Configuration()
        self.transcriptionEngine = TranscriptionEngine()
        self.analysisEngine = CallAnalysisEngine()
    }

    // MARK: - Configuration

    /// Replaces the current configuration with the provided one.
    /// - Parameter config: The new `Configuration` to apply.
    public func configure(_ config: Configuration) {
        self.configuration = config
    }

    /// Registers callbacks for call lifecycle and analysis events.
    ///
    /// - Parameters:
    ///   - onCallStarted: Invoked when a call begins.
    ///   - onCallEnded: Invoked when a call ends.
    ///   - onTranscriptUpdated: Invoked when a new transcript segment arrives.
    ///   - onAnalysisComplete: Invoked when post-call analysis finishes.
    ///   - onActionItemDetected: Invoked for each extracted action item.
    ///   - onCommitmentDetected: Invoked for each extracted commitment.
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

    /// Starts the call monitor: begins listening for calls and initializes the transcription engine.
    public func start() async {
        guard !isRunning else { return }
        isRunning = true

        // Start monitoring for calls
        await startCallMonitoring()

        // Initialize transcription engine
        await transcriptionEngine?.initialize(language: configuration.transcriptionLanguage)
    }

    /// Stops the call monitor: ends all active calls and shuts down transcription.
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

    /// Begins tracking a new call and starts transcription if enabled.
    ///
    /// - Parameters:
    ///   - source: The application or service the call originates from.
    ///   - type: Whether the call is incoming, outgoing, or a conference.
    ///   - participants: The list of call participants.
    ///   - metadata: Additional metadata about the call.
    /// - Returns: The UUID assigned to this call, for use in subsequent calls to `endCall(_:)` and `processAudio(_:forCall:)`.
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

    /// Ends an active call, triggers post-call analysis, and moves it to history.
    ///
    /// If the call's duration exceeds `configuration.minCallDurationToAnalyze`, full
    /// analysis is performed and results are forwarded to callbacks and, optionally,
    /// to `DeadlineIntelligence`.
    ///
    /// - Parameter callId: The UUID of the call to end.
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

    /// Feeds a new audio buffer to the transcription engine for an active call.
    ///
    /// Must be called from the main thread/queue where the buffer is valid.
    /// The buffer is wrapped in a `SendableAudioBuffer` before crossing the actor boundary.
    ///
    /// - Parameters:
    ///   - buffer: The `AVAudioPCMBuffer` containing new audio data.
    ///   - callId: The UUID of the active call the audio belongs to.
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

    // MARK: - Private Methods

    /// Sets up system-level call monitoring integrations.
    ///
    /// Would integrate with CallKit, app-specific SDKs (Zoom, Teams),
    /// audio session monitoring, and Accessibility APIs.
    private func startCallMonitoring() async {
        // This would integrate with:
        // 1. CallKit for phone calls
        // 2. App-specific APIs (Zoom SDK, Teams SDK, etc.)
        // 3. Audio session monitoring for other apps
        // 4. Accessibility APIs if available

        // Note: Actual implementation requires proper permissions and
        // may vary by platform and app
    }

    /// Starts a transcription session for the given call.
    /// - Parameter callId: The UUID of the call to transcribe.
    private func startTranscription(for callId: UUID) async {
        await transcriptionEngine?.startSession(callId: callId)
    }

    /// Stops the transcription session for the given call.
    /// - Parameter callId: The UUID of the call whose transcription should stop.
    private func stopTranscription(for callId: UUID) async {
        await transcriptionEngine?.stopSession(callId: callId)
    }

    /// Runs the analysis engine on a completed call.
    /// - Parameter call: The `CallRecord` to analyze.
    /// - Returns: A `CallAnalysis` if the transcript was non-empty, otherwise `nil`.
    private func analyzeCall(_ call: CallRecord) async -> CallAnalysis? {
        await analysisEngine?.analyze(call)
    }
}
