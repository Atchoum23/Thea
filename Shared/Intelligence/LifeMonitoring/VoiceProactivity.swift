// VoiceProactivity.swift
// THEA - Contextual Voice Interactions
// Created by Claude - February 2026
//
// Proactively speaks to user in appropriate contexts (driving, etc.)
// Can relay commands through Mac when iPhone is locked
// Supports multiple messaging platforms (iMessage, WhatsApp, Telegram)

import Foundation
import AVFoundation
import OSLog
import UserNotifications
#if canImport(Speech)
import Speech
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Voice Proactivity Engine

/// Main engine for proactive voice interactions
public actor VoiceProactivity {
    private let logger = Logger(subsystem: "ai.thea.app", category: "VoiceProactivity")
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

    /// Read recent notifications from the notification center
    public func readNotifications(limit: Int = 5) async {
        let center = UNUserNotificationCenter.current()
        let delivered = await center.deliveredNotifications()

        guard !delivered.isEmpty else {
            await speakImmediate("You have no new notifications.")
            return
        }

        let recent = delivered.prefix(limit)
        await speakImmediate("You have \(delivered.count) notification\(delivered.count == 1 ? "" : "s"). Here are the most recent:")

        for notification in recent {
            let title = notification.request.content.title
            let body = notification.request.content.body
            let text = body.isEmpty ? title : "\(title): \(body)"
            await speakImmediate(text)
        }
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
        do {
            try audioEngine.start()
        } catch {
            logger.error("Failed to start audio engine: \(error.localizedDescription)")
            return
        }

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
            do {
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            } catch {
                break
            }
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
        #if os(macOS)
        // Use AppleScript to send iMessage on macOS
        let escapedMessage = relay.message.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedRecipient = relay.recipient.replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Messages"
            set targetService to 1st service whose service type = iMessage
            set targetBuddy to buddy "\(escapedRecipient)" of targetService
            send "\(escapedMessage)" to targetBuddy
        end tell
        """

        return await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                var error: NSDictionary?
                if let appleScript = NSAppleScript(source: script) {
                    appleScript.executeAndReturnError(&error)
                    continuation.resume(returning: error == nil)
                } else {
                    continuation.resume(returning: false)
                }
            }
        }
        #elseif os(iOS)
        // On iOS, use URL scheme to open Messages with pre-filled content
        let encodedBody = relay.message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedRecipient = relay.recipient.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "sms:\(encodedRecipient)&body=\(encodedBody)") else {
            return false
        }
        return await MainActor.run {
            UIApplication.shared.open(url)
            return true
        }
        #else
        return false
        #endif
    }

    private func relayThroughMac(_ command: DeviceRelayCommand) async -> Bool {
        guard configuration.macRelayEnabled, !configuration.macRelayHostname.isEmpty else {
            return false
        }

        let hostname = configuration.macRelayHostname
        let commandData: Data
        do {
            commandData = try JSONEncoder().encode(["command": String(describing: command)])
        } catch {
            return false
        }

        // Try Tailscale hostname first, then .local mDNS
        let hosts = [hostname, "\(hostname).local"]

        for host in hosts {
            guard let url = URL(string: "http://\(host):18789/relay") else { continue }
            var request = URLRequest(url: url, timeoutInterval: 5)
            request.httpMethod = "POST"
            request.httpBody = commandData
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    let result = DeviceRelayResult(
                        success: true,
                        sourceDevice: ProcessInfo.processInfo.hostName,
                        targetDevice: hostname,
                        command: String(describing: command),
                        message: "Relayed via \(host)"
                    )
                    onDeviceRelayResult?(result)
                    return true
                }
            } catch {
                continue
            }
        }

        let result = DeviceRelayResult(
            success: false,
            sourceDevice: ProcessInfo.processInfo.hostName,
            targetDevice: hostname,
            command: String(describing: command),
            message: "Mac relay failed — host unreachable"
        )
        onDeviceRelayResult?(result)
        return false
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
