//
//  AssistantIntegration.swift
//  Thea
//
//  Created by Thea
//  Maximize Siri Shortcuts to approximate default assistant functionality
//

#if os(iOS)
    import Foundation
    import Intents
    import IntentsUI
    import os.log
    import Speech

    // MARK: - Assistant Integration

    /// Integrates Thea as deeply as possible with iOS assistant features
    @MainActor
    public final class AssistantIntegration: ObservableObject {
        public static let shared = AssistantIntegration()

        private let logger = Logger(subsystem: "app.thea.assistant", category: "AssistantIntegration")

        // MARK: - Published State

        @Published public private(set) var isListening = false
        @Published public private(set) var lastQuery: String?
        @Published public private(set) var lastResponse: String?
        @Published public private(set) var siriEnabled = false

        // MARK: - Speech Recognition

        private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
        private var recognitionTask: SFSpeechRecognitionTask?
        private let audioEngine = AVAudioEngine()

        // MARK: - Voice Activation

        public var wakeWord = "Hey Thea"
        public var listeningTimeout: TimeInterval = 5.0
        public var continuousListening = false

        private init() {
            requestPermissions()
        }

        // MARK: - Permissions

        private func requestPermissions() {
            // Speech recognition permission
            SFSpeechRecognizer.requestAuthorization { [weak self] status in
                Task { @MainActor in
                    switch status {
                    case .authorized:
                        self?.logger.info("Speech recognition authorized")
                    case .denied, .restricted, .notDetermined:
                        self?.logger.warning("Speech recognition not authorized")
                    @unknown default:
                        break
                    }
                }
            }

            // Siri permission
            INPreferences.requestSiriAuthorization { [weak self] status in
                Task { @MainActor in
                    self?.siriEnabled = status == .authorized
                    self?.logger.info("Siri authorization: \(String(describing: status))")
                }
            }
        }

        // MARK: - Voice Input

        /// Start listening for voice input
        public func startListening() async throws {
            guard let recognizer = speechRecognizer, recognizer.isAvailable else {
                throw AssistantError.speechRecognizerUnavailable
            }

            // Cancel any existing task
            recognitionTask?.cancel()
            recognitionTask = nil

            // Configure audio session
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            // Create recognition request
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

            guard let request = recognitionRequest else {
                throw AssistantError.recognitionRequestFailed
            }

            request.shouldReportPartialResults = true
            request.requiresOnDeviceRecognition = false // Set to true for privacy

            // Get input node
            let inputNode = audioEngine.inputNode

            // Create recognition task
            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    if let result {
                        self?.lastQuery = result.bestTranscription.formattedString

                        if result.isFinal {
                            self?.stopListening()
                            await self?.processQuery(result.bestTranscription.formattedString)
                        }
                    }

                    if error != nil {
                        self?.stopListening()
                    }
                }
            }

            // Configure audio input
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                self.recognitionRequest?.append(buffer)
            }

            // Start audio engine
            audioEngine.prepare()
            try audioEngine.start()

            isListening = true
            logger.info("Started listening")

            // Auto-stop after timeout
            if !continuousListening {
                Task {
                    do {
                        try await Task.sleep(nanoseconds: UInt64(listeningTimeout * 1_000_000_000))
                    } catch {
                        return
                    }
                    if self.isListening {
                        self.stopListening()
                    }
                }
            }
        }

        /// Stop listening
        public func stopListening() {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)

            recognitionRequest?.endAudio()
            recognitionRequest = nil

            recognitionTask?.cancel()
            recognitionTask = nil

            isListening = false
            logger.info("Stopped listening")
        }

        // MARK: - Query Processing

        /// Process a voice or text query
        public func processQuery(_ query: String) async {
            logger.info("Processing query: \(query)")
            lastQuery = query

            // Check for built-in commands first
            if let response = await handleBuiltInCommand(query) {
                lastResponse = response
                await speak(response)
                return
            }

            // Check for Shortcuts
            if let shortcutResponse = await handleShortcutCommand(query) {
                lastResponse = shortcutResponse
                await speak(shortcutResponse)
                return
            }

            // Forward to Thea's AI
            let response = await forwardToTheaAI(query)
            lastResponse = response
            await speak(response)
        }

        private func handleBuiltInCommand(_ query: String) async -> String? {
            let lowercased = query.lowercased()

            // Time queries
            if lowercased.contains("what time") || lowercased.contains("what's the time") {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                return "It's \(formatter.string(from: Date()))"
            }

            // Date queries
            if lowercased.contains("what day") || lowercased.contains("what's the date") {
                let formatter = DateFormatter()
                formatter.dateStyle = .full
                return "Today is \(formatter.string(from: Date()))"
            }

            // Weather (would need API)
            if lowercased.contains("weather") {
                return "I'll check the weather for you. Opening Weather app."
            }

            // Timer
            if lowercased.contains("set a timer") || lowercased.contains("set timer") {
                if let minutes = extractNumber(from: query) {
                    return "Setting a timer for \(minutes) minutes."
                }
            }

            // Reminder
            if lowercased.contains("remind me") {
                return "I'll create a reminder for you."
            }

            // HomeKit
            if lowercased.contains("turn on") || lowercased.contains("turn off") {
                if lowercased.contains("lights") {
                    let action = lowercased.contains("turn on") ? "on" : "off"
                    return "Turning \(action) the lights."
                }
            }

            return nil
        }

        private func handleShortcutCommand(_ query: String) async -> String? {
            let lowercased = query.lowercased()

            // Check if query matches a shortcut
            if lowercased.contains("run") || lowercased.contains("execute") {
                // Extract shortcut name
                let shortcutKeywords = ["run", "execute", "start", "launch"]
                for keyword in shortcutKeywords {
                    if let range = lowercased.range(of: keyword) {
                        let afterKeyword = String(lowercased[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                        if !afterKeyword.isEmpty {
                            // Try to run shortcut
                            return "Running shortcut: \(afterKeyword)"
                        }
                    }
                }
            }

            return nil
        }

        private func forwardToTheaAI(_ query: String) async -> String {
            guard let provider = ProviderRegistry.shared.getProvider(
                id: SettingsManager.shared.defaultProvider
            ) else {
                return "No AI provider configured. Please set up a provider in Thea Settings."
            }

            let message = AIMessage(
                id: UUID(),
                conversationID: UUID(),
                role: .user,
                content: .text(query),
                timestamp: Date(),
                model: ""
            )

            do {
                var responseText = ""
                let stream = try await provider.chat(
                    messages: [message],
                    model: "",
                    stream: false
                )
                for try await chunk in stream {
                    if case .delta(let text) = chunk.type {
                        responseText += text
                    } else if case .complete(let msg) = chunk.type {
                        responseText = msg.content.textValue
                    }
                }
                return responseText.isEmpty ? "I couldn't generate a response." : responseText
            } catch {
                return "Error processing your request: \(error.localizedDescription)"
            }
        }

        private func extractNumber(from text: String) -> Int? {
            let words = text.components(separatedBy: .whitespaces)
            for word in words {
                if let number = Int(word) {
                    return number
                }
            }

            // Check word numbers
            let wordNumbers = ["one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
                               "ten": 10, "fifteen": 15, "twenty": 20, "thirty": 30]

            for (word, value) in wordNumbers {
                if text.lowercased().contains(word) {
                    return value
                }
            }

            return nil
        }

        // MARK: - Speech Output

        /// Speak a response
        public func speak(_ text: String) async {
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate
            utterance.pitchMultiplier = 1.0

            let synthesizer = AVSpeechSynthesizer()
            synthesizer.speak(utterance)

            logger.debug("Speaking: \(text)")
        }

        // MARK: - Siri Shortcuts Donation

        /// Donate an intent to Siri for future suggestions
        public func donateIntent(_ intent: INIntent) {
            let interaction = INInteraction(intent: intent, response: nil)
            interaction.donate { [weak self] error in
                if let error {
                    self?.logger.error("Failed to donate intent: \(error)")
                } else {
                    self?.logger.debug("Donated intent to Siri")
                }
            }
        }

        /// Create and donate a custom shortcut
        public func createShortcut(
            title: String,
            phrase: String,
            intent: INIntent
        ) {
            intent.suggestedInvocationPhrase = phrase

            let shortcut = INShortcut(intent: intent)

            INVoiceShortcutCenter.shared.setShortcutSuggestions([shortcut!])

            logger.info("Created shortcut: \(title)")
        }

        // MARK: - Shortcut Suggestions

        /// Get suggested shortcuts based on user behavior
        public func getSuggestedShortcuts() -> [ShortcutSuggestion] {
            // Analyze user behavior and suggest relevant shortcuts
            var suggestions: [ShortcutSuggestion] = []

            // Time-based suggestions
            let hour = Calendar.current.component(.hour, from: Date())

            if hour >= 6, hour < 9 {
                suggestions.append(ShortcutSuggestion(
                    title: "Good Morning Routine",
                    phrase: "Good morning",
                    description: "Start your day with weather, calendar, and news"
                ))
            }

            if hour >= 17, hour < 20 {
                suggestions.append(ShortcutSuggestion(
                    title: "Evening Summary",
                    phrase: "How was my day",
                    description: "Review today's activity and tomorrow's schedule"
                ))
            }

            if hour >= 21 {
                suggestions.append(ShortcutSuggestion(
                    title: "Wind Down",
                    phrase: "Time for bed",
                    description: "Set sleep focus and dim lights"
                ))
            }

            return suggestions
        }

        // MARK: - Intent Handling

        /// Handle incoming intents
        public func handleIntent(_ intent: INIntent) async -> INIntentResponse? {
            logger.info("Handling intent: \(type(of: intent))")

            // Handle different intent types
            switch intent {
            case let searchIntent as INSearchForMessagesIntent:
                return await handleSearchMessages(searchIntent)

            case let sendIntent as INSendMessageIntent:
                return await handleSendMessage(sendIntent)

            default:
                return nil
            }
        }

        private func handleSearchMessages(_: INSearchForMessagesIntent) async -> INSearchForMessagesIntentResponse {
            // Implement message search
            let response = INSearchForMessagesIntentResponse(code: .success, userActivity: nil)
            return response
        }

        private func handleSendMessage(_: INSendMessageIntent) async -> INSendMessageIntentResponse {
            // Implement message sending
            let response = INSendMessageIntentResponse(code: .success, userActivity: nil)
            return response
        }
    }

    // MARK: - Supporting Types

    public struct ShortcutSuggestion: Identifiable {
        public let id = UUID()
        public let title: String
        public let phrase: String
        public let description: String
    }

    public enum AssistantError: Error, LocalizedError {
        case speechRecognizerUnavailable
        case recognitionRequestFailed
        case microphoneAccessDenied
        case siriNotAuthorized

        public var errorDescription: String? {
            switch self {
            case .speechRecognizerUnavailable:
                "Speech recognizer is not available"
            case .recognitionRequestFailed:
                "Failed to create recognition request"
            case .microphoneAccessDenied:
                "Microphone access is required"
            case .siriNotAuthorized:
                "Siri authorization is required"
            }
        }
    }

    // MARK: - App Intent for Shortcuts

    import AppIntents

    @available(iOS 16.0, *)
    struct AssistantAskTheaIntent: AppIntent {
        static let title: LocalizedStringResource = "Ask Thea"
        static let description = IntentDescription("Ask Thea a question")

        @Parameter(title: "Question")
        var question: String

        static var parameterSummary: some ParameterSummary {
            Summary("Ask Thea \(\.$question)")
        }

        func perform() async throws -> some IntentResult & ReturnsValue<String> {
            await AssistantIntegration.shared.processQuery(question)
            let response = await AssistantIntegration.shared.lastResponse ?? "Processing..."
            return .result(value: response)
        }
    }

    @available(iOS 16.0, *)
    struct TheaVoiceCommandIntent: AppIntent {
        static let title: LocalizedStringResource = "Thea Voice Command"
        static let description = IntentDescription("Start listening for a voice command")

        static let openAppWhenRun: Bool = true

        func perform() async throws -> some IntentResult {
            try await AssistantIntegration.shared.startListening()
            return .result()
        }
    }

    // NOTE: TheaAssistantShortcuts removed - only one AppShortcutsProvider allowed per app
    // See TheaAppIntents.swift for the canonical AppShortcutsProvider
#endif
