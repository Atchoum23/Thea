// VoiceProactivity.swift
// THEA - Contextual Voice Interactions
// Created by Claude - February 2026
//
// Proactively speaks to user in appropriate contexts (driving, etc.)
// Can relay commands through Mac when iPhone is locked
// Supports multiple messaging platforms (iMessage, WhatsApp, Telegram)

import Foundation
import AVFoundation
#if canImport(Speech)
import Speech
#endif

// MARK: - Voice Context

/// Context that determines voice interaction appropriateness
public enum VoiceContext: String, Sendable, CaseIterable {
    case driving = "driving"           // In vehicle, hands busy
    case walking = "walking"           // Walking, can listen
    case exercising = "exercising"     // Working out
    case working = "working"           // At work, be quiet
    case sleeping = "sleeping"         // Do not disturb
    case meeting = "meeting"           // In a meeting
    case home = "home"                 // At home, normal volume
    case transit = "transit"           // Public transit
    case unknown = "unknown"           // Default

    public var isVoiceSafe: Bool {
        switch self {
        case .driving, .walking, .exercising, .home:
            return true
        case .working, .sleeping, .meeting, .transit, .unknown:
            return false
        }
    }

    public var preferredVolume: Float {
        switch self {
        case .driving: return 0.9
        case .walking, .exercising: return 0.7
        case .home: return 0.5
        default: return 0.3
        }
    }

    public var interruptionPolicy: InterruptionPolicy {
        switch self {
        case .driving: return .urgentOnly
        case .working, .meeting: return .emergencyOnly
        case .sleeping: return .never
        default: return .normal
        }
    }

    public enum InterruptionPolicy: String, Sendable {
        case never       // Never interrupt
        case emergencyOnly  // Only emergencies
        case urgentOnly  // Urgent and above
        case normal      // Normal threshold
        case always      // Any notification
    }
}

// MARK: - Voice Interaction Types

/// Type of voice interaction
public enum VoiceInteractionType: String, Sendable {
    case notification = "notification"    // One-way notification
    case question = "question"            // Expecting yes/no response
    case request = "request"              // Expecting action/data
    case conversation = "conversation"    // Multi-turn
    case alert = "alert"                  // Urgent alert
    case reminder = "reminder"            // Scheduled reminder
}

/// Priority of voice interaction
public enum VoiceInteractionPriority: Int, Sendable, Comparable {
    case low = 1
    case normal = 2
    case high = 3
    case urgent = 4
    case emergency = 5

    public static func < (lhs: VoiceInteractionPriority, rhs: VoiceInteractionPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var allowedInContext: [VoiceContext] {
        switch self {
        case .emergency: return VoiceContext.allCases
        case .urgent: return [.driving, .walking, .exercising, .home, .transit]
        case .high: return [.driving, .walking, .home]
        case .normal: return [.walking, .home]
        case .low: return [.home]
        }
    }
}

// MARK: - Voice Interaction

/// A voice interaction to deliver to user
public struct VoiceInteraction: Identifiable, Sendable {
    public let id: UUID
    public let type: VoiceInteractionType
    public let priority: VoiceInteractionPriority
    public let message: String
    public let ssml: String? // SSML for more natural speech
    public let expectedResponses: [ExpectedResponse]?
    public let followUpId: UUID? // Reference to follow-up interaction
    public let context: [String: String]
    public let createdAt: Date
    public var deliveredAt: Date?
    public var response: VoiceResponse?
    public let expiresAt: Date?

    public struct ExpectedResponse: Sendable {
        public let keywords: [String]
        public let action: String
        public let nextInteractionId: UUID? // Reference instead of direct struct

        public init(keywords: [String], action: String, nextInteractionId: UUID? = nil) {
            self.keywords = keywords
            self.action = action
            self.nextInteractionId = nextInteractionId
        }
    }

    public init(
        id: UUID = UUID(),
        type: VoiceInteractionType,
        priority: VoiceInteractionPriority = .normal,
        message: String,
        ssml: String? = nil,
        expectedResponses: [ExpectedResponse]? = nil,
        followUpId: UUID? = nil,
        context: [String: String] = [:],
        expiresIn: TimeInterval? = nil
    ) {
        self.id = id
        self.type = type
        self.priority = priority
        self.message = message
        self.ssml = ssml
        self.expectedResponses = expectedResponses
        self.followUpId = followUpId
        self.context = context
        self.createdAt = Date()
        self.deliveredAt = nil
        self.response = nil
        self.expiresAt = expiresIn.map { Date().addingTimeInterval($0) }
    }

    public var isExpired: Bool {
        if let expires = expiresAt {
            return Date() > expires
        }
        return false
    }
}

/// User's voice response
public struct VoiceResponse: Sendable {
    public let transcription: String
    public let confidence: Double
    public let matchedExpectation: VoiceInteraction.ExpectedResponse?
    public let timestamp: Date

    public init(
        transcription: String,
        confidence: Double,
        matchedExpectation: VoiceInteraction.ExpectedResponse? = nil
    ) {
        self.transcription = transcription
        self.confidence = confidence
        self.matchedExpectation = matchedExpectation
        self.timestamp = Date()
    }
}

// MARK: - Messaging Relay

/// Platform for sending messages
public enum MessagingPlatform: String, Sendable, CaseIterable {
    case iMessage = "imessage"
    case whatsApp = "whatsapp"
    case telegram = "telegram"
    case signal = "signal"
    case slack = "slack"
    case sms = "sms"

    public var displayName: String {
        switch self {
        case .iMessage: return "iMessage"
        case .whatsApp: return "WhatsApp"
        case .telegram: return "Telegram"
        case .signal: return "Signal"
        case .slack: return "Slack"
        case .sms: return "SMS"
        }
    }

    public var urlScheme: String? {
        switch self {
        case .iMessage: return "imessage://"
        case .whatsApp: return "whatsapp://"
        case .telegram: return "tg://"
        case .signal: return nil // Uses Shortcuts
        case .slack: return "slack://"
        case .sms: return "sms://"
        }
    }
}

/// A message to relay
public struct MessageRelay: Sendable {
    public let platform: MessagingPlatform
    public let recipient: String
    public let recipientName: String?
    public let message: String
    public let attachments: [String]? // File paths
    public let replyToMessageId: String?

    public init(
        platform: MessagingPlatform,
        recipient: String,
        recipientName: String? = nil,
        message: String,
        attachments: [String]? = nil,
        replyToMessageId: String? = nil
    ) {
        self.platform = platform
        self.recipient = recipient
        self.recipientName = recipientName
        self.message = message
        self.attachments = attachments
        self.replyToMessageId = replyToMessageId
    }
}

// MARK: - Device Relay

/// Relay commands between devices
public enum DeviceRelayCommand: Sendable {
    case sendMessage(MessageRelay)
    case makeCall(to: String, platform: MessagingPlatform)
    case readNotifications
    case playMedia(String)
    case pauseMedia
    case navigate(to: String)
    case searchWeb(query: String)
    case setReminder(title: String, dueDate: Date)
    case custom(action: String, parameters: [String: String])
}

/// Result of device relay
public struct DeviceRelayResult: Sendable {
    public let success: Bool
    public let sourceDevice: String
    public let targetDevice: String
    public let command: String
    public let message: String?
    public let timestamp: Date

    public init(
        success: Bool,
        sourceDevice: String,
        targetDevice: String,
        command: String,
        message: String? = nil
    ) {
        self.success = success
        self.sourceDevice = sourceDevice
        self.targetDevice = targetDevice
        self.command = command
        self.message = message
        self.timestamp = Date()
    }
}

// MARK: - Voice Proactivity Engine

/// Main engine for proactive voice interactions
public actor VoiceProactivity {
    // MARK: - Singleton

    public static let shared = VoiceProactivity()

    // MARK: - Configuration

    public struct Configuration: Sendable {
        public var enabled: Bool = true
        public var voiceEnabled: Bool = true
        public var listeningEnabled: Bool = true
        public var preferredVoice: String = "com.apple.voice.compact.en-US.Samantha"
        public var speechRate: Float = 0.5
        public var volume: Float = 0.7
        public var wakeWord: String = "Hey Thea"
        public var autoContextDetection: Bool = true
        public var defaultContext: VoiceContext = .home
        public var quietHoursStart: Int = 22 // 10 PM
        public var quietHoursEnd: Int = 7    // 7 AM
        public var macRelayEnabled: Bool = true
        public var macRelayHostname: String = ""
        public var preferredPlatformByContact: [String: MessagingPlatform] = [:]

        public init() {}
    }

    // MARK: - Properties

    private var configuration: Configuration
    private var currentContext: VoiceContext = .unknown
    private var isListening = false
    private var isSpeaking = false
    private var pendingInteractions: [VoiceInteraction] = []
    private var activeInteraction: VoiceInteraction?
    private var interactionHistory: [VoiceInteraction] = []

    // Speech
    private let synthesizer = AVSpeechSynthesizer()
    #if canImport(Speech)
    private var recognizer: SFSpeechRecognizer?
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    #endif

    // Callbacks
    private var onContextChanged: ((VoiceContext) -> Void)?
    private var onInteractionDelivered: ((VoiceInteraction) -> Void)?
    private var onResponseReceived: ((VoiceInteraction, VoiceResponse) -> Void)?
    private var onWakeWordDetected: (() -> Void)?
    private var onDeviceRelayResult: ((DeviceRelayResult) -> Void)?

    // MARK: - Initialization

    private init() {
        self.configuration = Configuration()
        #if canImport(Speech)
        self.recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        self.audioEngine = AVAudioEngine()
        #endif
    }

    // MARK: - Configuration

    public func configure(_ config: Configuration) {
        self.configuration = config
    }

    public func configure(
        onContextChanged: @escaping @Sendable (VoiceContext) -> Void,
        onInteractionDelivered: @escaping @Sendable (VoiceInteraction) -> Void,
        onResponseReceived: @escaping @Sendable (VoiceInteraction, VoiceResponse) -> Void,
        onWakeWordDetected: @escaping @Sendable () -> Void,
        onDeviceRelayResult: @escaping @Sendable (DeviceRelayResult) -> Void
    ) {
        self.onContextChanged = onContextChanged
        self.onInteractionDelivered = onInteractionDelivered
        self.onResponseReceived = onResponseReceived
        self.onWakeWordDetected = onWakeWordDetected
        self.onDeviceRelayResult = onDeviceRelayResult
    }

    // MARK: - Lifecycle

    public func start() async {
        guard configuration.enabled else { return }

        // Start context detection
        if configuration.autoContextDetection {
            await startContextDetection()
        }

        // Start wake word listening if enabled
        if configuration.listeningEnabled {
            await startListening()
        }

        // Process any pending interactions
        await processPendingInteractions()
    }

    public func stop() async {
        await stopListening()
        isSpeaking = false
    }

    // MARK: - Context Management

    /// Set current context
    public func setContext(_ context: VoiceContext) {
        let oldContext = currentContext
        currentContext = context

        if oldContext != context {
            onContextChanged?(context)

            // Re-evaluate pending interactions
            Task {
                await processPendingInteractions()
            }
        }
    }

    /// Get current context
    public func getContext() -> VoiceContext {
        currentContext
    }

    // MARK: - Voice Interactions

    /// Queue a voice interaction
    public func queueInteraction(_ interaction: VoiceInteraction) async {
        pendingInteractions.append(interaction)
        pendingInteractions.sort { $0.priority > $1.priority }

        await processPendingInteractions()
    }

    /// Speak immediately (bypasses queue)
    public func speakImmediate(
        _ message: String,
        priority: VoiceInteractionPriority = .urgent
    ) async {
        let interaction = VoiceInteraction(
            type: .alert,
            priority: priority,
            message: message
        )

        await deliverInteraction(interaction)
    }

    /// Ask a question and wait for response
    public func askQuestion(
        _ question: String,
        expectedResponses: [VoiceInteraction.ExpectedResponse],
        priority: VoiceInteractionPriority = .normal,
        timeout: TimeInterval = 10
    ) async -> VoiceResponse? {
        let interaction = VoiceInteraction(
            type: .question,
            priority: priority,
            message: question,
            expectedResponses: expectedResponses,
            expiresIn: timeout
        )

        await deliverInteraction(interaction)

        // Wait for response
        return await waitForResponse(interaction: interaction, timeout: timeout)
    }

    /// Send message via voice interface
    public func sendMessage(
        to recipient: String,
        recipientName: String?,
        message: String,
        platform: MessagingPlatform
    ) async -> Bool {
        let relay = MessageRelay(
            platform: platform,
            recipient: recipient,
            recipientName: recipientName,
            message: message
        )

        // Try to send directly if possible
        if await canSendDirectly(platform: platform) {
            return await sendMessageDirectly(relay)
        }

        // Otherwise relay through Mac
        if configuration.macRelayEnabled {
            return await relayThroughMac(.sendMessage(relay))
        }

        // Confirm message via voice
        let name = recipientName ?? recipient
        await speakImmediate("I'll prepare a message to \(name) on \(platform.displayName). The message is: \(message). Would you like me to send it?")

        return false // Requires user confirmation
    }

    // MARK: - Driving Mode Helpers

    /// Initiate a conversation-style messaging flow
    public func startMessagingFlow() async {
        // Ask who to message
        let whoResponse = await askQuestion(
            "Who would you like to message?",
            expectedResponses: [],
            priority: .high,
            timeout: 15
        )

        guard let recipient = whoResponse?.transcription else {
            await speakImmediate("I didn't catch that. Let me know when you want to send a message.")
            return
        }

        // Ask what platform
        let platformResponse = await askQuestion(
            "Would you like to use iMessage, WhatsApp, or Telegram?",
            expectedResponses: [
                VoiceInteraction.ExpectedResponse(keywords: ["imessage", "message", "text"], action: "imessage"),
                VoiceInteraction.ExpectedResponse(keywords: ["whatsapp", "whats app"], action: "whatsapp"),
                VoiceInteraction.ExpectedResponse(keywords: ["telegram"], action: "telegram")
            ],
            priority: .high
        )

        let platform = determinePlatform(from: platformResponse)

        // Ask for the message
        let messageResponse = await askQuestion(
            "What would you like to say?",
            expectedResponses: [],
            priority: .high,
            timeout: 30
        )

        guard let message = messageResponse?.transcription else {
            await speakImmediate("I didn't catch the message. Let's try again later.")
            return
        }

        // Confirm and send
        let confirmResponse = await askQuestion(
            "I'll send '\(message)' to \(recipient) via \(platform.displayName). Should I send it?",
            expectedResponses: [
                VoiceInteraction.ExpectedResponse(keywords: ["yes", "yeah", "yep", "send", "confirm"], action: "send"),
                VoiceInteraction.ExpectedResponse(keywords: ["no", "nope", "cancel", "don't"], action: "cancel")
            ],
            priority: .high
        )

        if confirmResponse?.matchedExpectation?.action == "send" {
            let success = await sendMessage(to: recipient, recipientName: nil, message: message, platform: platform)
            if success {
                await speakImmediate("Message sent!")
            } else {
                await speakImmediate("I couldn't send that message. Please try again later.")
            }
        } else {
            await speakImmediate("Message cancelled.")
        }
    }

    /// Read recent notifications
    public func readNotifications(limit: Int = 5) async {
        // Would integrate with notification center
        // For now, placeholder
        await speakImmediate("You have no new important notifications.")
    }

    /// Navigate to a destination
    public func startNavigation(to destination: String) async {
        await speakImmediate("Starting navigation to \(destination).")

        // Would integrate with Maps
        if configuration.macRelayEnabled {
            _ = await relayThroughMac(.navigate(to: destination))
        }
    }

    // MARK: - Private Methods

    private func startContextDetection() async {
        // Would integrate with:
        // - CarPlay detection
        // - Activity recognition
        // - Location context
        // - Calendar events
        // For now, default to home
        currentContext = configuration.defaultContext
    }

    private func startListening() async {
        #if canImport(Speech)
        guard !isListening, let recognizer = recognizer, recognizer.isAvailable else { return }

        isListening = true

        #if os(iOS)
        // Set up audio session (iOS only)
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            isListening = false
            return
        }
        #endif

        // Start recognition
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = true
        recognitionRequest?.requiresOnDeviceRecognition = true // Privacy

        guard let audioEngine = audioEngine, let recognitionRequest = recognitionRequest else { return }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        audioEngine.prepare()
        try? audioEngine.start()

        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                let transcription = result.bestTranscription.formattedString.lowercased()
                let isFinal = result.isFinal

                // Use detached tasks to avoid sending closure data race issues
                Task.detached { [weak self] in
                    await self?.checkForWakeWord(transcription)
                }

                Task.detached { [weak self] in
                    await self?.processVoiceInput(transcription, isFinal: isFinal)
                }
            }

            if error != nil || (result?.isFinal ?? false) {
                Task.detached { [weak self] in
                    await self?.restartListeningIfNeeded()
                }
            }
        }
        #endif
    }

    private func stopListening() async {
        #if canImport(Speech)
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        isListening = false
        #endif
    }

    private func restartListeningIfNeeded() async {
        if configuration.listeningEnabled && !isListening {
            await startListening()
        }
    }

    private func checkForWakeWord(_ transcription: String) async {
        if transcription.contains(configuration.wakeWord.lowercased()) {
            onWakeWordDetected?()

            // Acknowledge
            await speakImmediate("Yes?", priority: .high)
        }
    }

    private func processVoiceInput(_ transcription: String, isFinal: Bool) async {
        guard let active = activeInteraction, active.type == .question || active.type == .request else {
            return
        }

        // Check against expected responses
        var matchedResponse: VoiceInteraction.ExpectedResponse?

        if let expected = active.expectedResponses {
            for response in expected {
                for keyword in response.keywords {
                    if transcription.contains(keyword.lowercased()) {
                        matchedResponse = response
                        break
                    }
                }
                if matchedResponse != nil { break }
            }
        }

        // If final or matched, record response
        if isFinal || matchedResponse != nil {
            let voiceResponse = VoiceResponse(
                transcription: transcription,
                confidence: matchedResponse != nil ? 0.9 : 0.7,
                matchedExpectation: matchedResponse
            )

            var updated = active
            updated.response = voiceResponse
            activeInteraction = updated

            onResponseReceived?(active, voiceResponse)

            // Process follow-up if any (using IDs)
            // Note: Follow-up interactions would need to be stored and retrieved by ID
        }
    }

    private func processPendingInteractions() async {
        guard !isSpeaking, activeInteraction == nil else { return }

        // Filter for current context
        let validInteractions = pendingInteractions.filter { interaction in
            // Check if priority allows in current context
            interaction.priority.allowedInContext.contains(currentContext) &&
            !interaction.isExpired &&
            shouldDeliverNow(interaction)
        }

        guard let next = validInteractions.first else { return }

        // Remove from pending
        pendingInteractions.removeAll { $0.id == next.id }

        await deliverInteraction(next)
    }

    private func shouldDeliverNow(_ interaction: VoiceInteraction) -> Bool {
        // Check quiet hours
        let hour = Calendar.current.component(.hour, from: Date())
        let inQuietHours = (hour >= configuration.quietHoursStart || hour < configuration.quietHoursEnd)

        if inQuietHours && interaction.priority < .urgent {
            return false
        }

        // Check interruption policy
        switch currentContext.interruptionPolicy {
        case .never:
            return false
        case .emergencyOnly:
            return interaction.priority == .emergency
        case .urgentOnly:
            return interaction.priority >= .urgent
        case .normal:
            return interaction.priority >= .normal
        case .always:
            return true
        }
    }

    private func deliverInteraction(_ interaction: VoiceInteraction) async {
        isSpeaking = true
        activeInteraction = interaction

        // Adjust volume for context
        let volume = min(configuration.volume, currentContext.preferredVolume)

        // Speak the message
        let utterance = AVSpeechUtterance(string: interaction.message)
        utterance.voice = AVSpeechSynthesisVoice(identifier: configuration.preferredVoice)
            ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = configuration.speechRate
        utterance.volume = volume

        // Use delegate pattern for completion
        await withCheckedContinuation { continuation in
            let delegate = SpeechDelegate {
                continuation.resume()
            }

            // Store delegate to prevent deallocation
            // In real implementation, use proper delegate management
            self.synthesizer.speak(utterance)

            // Simulate completion for now
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(interaction.message.count) * 0.05) {
                delegate.completion()
            }
        }

        // Update interaction
        var delivered = interaction
        delivered.deliveredAt = Date()

        // Move to history
        interactionHistory.append(delivered)
        if interactionHistory.count > 1000 {
            interactionHistory.removeFirst(interactionHistory.count - 1000)
        }

        onInteractionDelivered?(delivered)

        isSpeaking = false

        // If not expecting response, clear active
        if interaction.type == .notification || interaction.type == .alert {
            activeInteraction = nil
        }

        // Process next in queue
        await processPendingInteractions()
    }

    private func waitForResponse(interaction: VoiceInteraction, timeout: TimeInterval) async -> VoiceResponse? {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if let response = activeInteraction?.response {
                activeInteraction = nil
                return response
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }

        // Timed out
        activeInteraction = nil
        return nil
    }

    private func canSendDirectly(platform: MessagingPlatform) async -> Bool {
        // Check if we can send directly (e.g., device unlocked, app available)
        #if os(iOS)
        // On iOS, might need to check if unlocked
        return false // Conservative - always relay or confirm
        #else
        return true
        #endif
    }

    private func sendMessageDirectly(_ relay: MessageRelay) async -> Bool {
        // Would use platform-specific APIs
        // For iMessage: AppleScript on Mac, Messages framework on iOS
        // For WhatsApp/Telegram: URL schemes or API

        false // Placeholder
    }

    private func relayThroughMac(_ command: DeviceRelayCommand) async -> Bool {
        guard configuration.macRelayEnabled, !configuration.macRelayHostname.isEmpty else {
            return false
        }

        // Would communicate with Mac via:
        // 1. Local network (Bonjour/mDNS)
        // 2. iCloud relay
        // 3. Custom protocol

        let result = DeviceRelayResult(
            success: false,
            sourceDevice: "iPhone",
            targetDevice: configuration.macRelayHostname,
            command: String(describing: command),
            message: "Mac relay not implemented"
        )

        onDeviceRelayResult?(result)
        return result.success
    }

    private func determinePlatform(from response: VoiceResponse?) -> MessagingPlatform {
        guard let action = response?.matchedExpectation?.action else {
            return .iMessage // Default
        }

        switch action {
        case "imessage": return .iMessage
        case "whatsapp": return .whatsApp
        case "telegram": return .telegram
        default: return .iMessage
        }
    }
}

// MARK: - Speech Delegate Helper

private class SpeechDelegate: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    let completion: () -> Void

    init(completion: @escaping () -> Void) {
        self.completion = completion
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        completion()
    }
}

// MARK: - Convenience Extensions

extension VoiceProactivity {
    /// Notify about an upcoming deadline
    public func notifyDeadline(
        title: String,
        dueDate: Date,
        urgency: DeadlineUrgency
    ) async {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let relative = formatter.localizedString(for: dueDate, relativeTo: Date())

        let priority: VoiceInteractionPriority = switch urgency {
        case .overdue: .urgent
        case .critical: .urgent
        case .urgent: .high
        case .approaching: .normal
        default: .low
        }

        let message: String
        if urgency == .overdue {
            message = "Reminder: \(title) is overdue. It was due \(relative)."
        } else {
            message = "Reminder: \(title) is due \(relative)."
        }

        let interaction = VoiceInteraction(
            type: .reminder,
            priority: priority,
            message: message
        )

        await queueInteraction(interaction)
    }

    /// Notify about an incoming message
    public func notifyMessage(
        from sender: String,
        platform: MessagingPlatform,
        preview: String
    ) async {
        let message = "New \(platform.displayName) message from \(sender). They said: \(preview)"

        let interaction = VoiceInteraction(
            type: .notification,
            priority: .normal,
            message: message,
            expectedResponses: [
                VoiceInteraction.ExpectedResponse(keywords: ["reply", "respond", "answer"], action: "reply"),
                VoiceInteraction.ExpectedResponse(keywords: ["ignore", "later", "dismiss"], action: "dismiss")
            ]
        )

        await queueInteraction(interaction)
    }

    /// Ask user's preference for action
    public func askPreference(
        question: String,
        options: [(name: String, keywords: [String])]
    ) async -> String? {
        let responses = options.map { option in
            VoiceInteraction.ExpectedResponse(
                keywords: option.keywords,
                action: option.name
            )
        }

        let response = await askQuestion(
            question,
            expectedResponses: responses,
            priority: .normal
        )

        return response?.matchedExpectation?.action
    }
}
