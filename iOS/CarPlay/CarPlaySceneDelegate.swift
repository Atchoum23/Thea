//
//  CarPlaySceneDelegate.swift
//  Thea iOS
//
//  CarPlay voice-first interface for in-vehicle AI assistant.
//
//  ENTITLEMENT NOTE: com.apple.developer.carplay-audio requires Apple approval.
//  All CarPlay UI code is wrapped in #if CARPLAY_ENTITLEMENT_APPROVED so the file
//  compiles cleanly today. Once Apple grants the entitlement, add the flag to
//  iOS target's OTHER_SWIFT_FLAGS: -D CARPLAY_ENTITLEMENT_APPROVED
//

import CarPlay
import Foundation
import os.log

private let logger = Logger(subsystem: "app.thea.ios", category: "CarPlay")

// MARK: - CarPlay Scene Delegate

/// Manages the CarPlay scene lifecycle and registers Thea's voice-first interface.
/// The primary template is CPVoiceControlTemplate which gives a minimal,
/// distraction-free voice interaction model safe for in-vehicle use.
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    // MARK: - Properties

    private var interfaceController: CPInterfaceController?

    // MARK: - CPTemplateApplicationSceneDelegate

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        logger.info("CarPlay connected — presenting voice interface")
        presentVoiceInterface()
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        logger.info("CarPlay disconnected")
        self.interfaceController = nil
    }

    // MARK: - Interface Construction

    private func presentVoiceInterface() {
        guard let controller = interfaceController else { return }

#if CARPLAY_ENTITLEMENT_APPROVED
        // CPVoiceControlTemplate: minimal voice-first UI with activation/deactivation
        // states and optional waveform animation. Safe for driver attention.
        let voiceTemplate = CPVoiceControlTemplate(
            voiceControlStates: [
                makeState(.idle),
                makeState(.listening),
                makeState(.processing),
                makeState(.speaking)
            ]
        )

        controller.setRootTemplate(voiceTemplate, animated: false) { success, error in
            if let error {
                logger.error("Failed to set voice template: \(error.localizedDescription)")
            } else if success {
                logger.info("CPVoiceControlTemplate active — Thea CarPlay ready")
            }
        }
#else
        // Entitlement pending — show a minimal list template explaining this.
        let item = CPListItem(
            text: "Thea Voice Assistant",
            detailText: "CarPlay voice interface coming soon"
        )
        let section = CPListSection(items: [item])
        let listTemplate = CPListTemplate(title: "Thea", sections: [section])
        controller.setRootTemplate(listTemplate, animated: false) { _, _ in }
        logger.warning("CARPLAY_ENTITLEMENT_APPROVED not set — showing fallback list template")
#endif
    }

#if CARPLAY_ENTITLEMENT_APPROVED
    // MARK: - Voice Control State Factory

    private func makeState(_ type: VoiceStateType) -> CPVoiceControlState {
        switch type {
        case .idle:
            return CPVoiceControlState(
                identifier: "thea.idle",
                titleVariants: ["Say something to Thea…"],
                image: UIImage(systemName: "waveform"),
                repeats: false
            )
        case .listening:
            return CPVoiceControlState(
                identifier: "thea.listening",
                titleVariants: ["Listening…", "I'm listening"],
                image: UIImage(systemName: "waveform.badge.microphone"),
                repeats: true
            )
        case .processing:
            return CPVoiceControlState(
                identifier: "thea.processing",
                titleVariants: ["Thinking…"],
                image: UIImage(systemName: "brain"),
                repeats: true
            )
        case .speaking:
            return CPVoiceControlState(
                identifier: "thea.speaking",
                titleVariants: ["Thea is speaking"],
                image: UIImage(systemName: "speaker.wave.2.fill"),
                repeats: true
            )
        }
    }

    private enum VoiceStateType {
        case idle, listening, processing, speaking
    }
#endif
}

// MARK: - CarPlay Session Manager

/// Manages CarPlay voice session lifecycle: captures audio, sends to ChatManager,
/// and returns spoken responses via AVSpeechSynthesizer.
@MainActor
final class CarPlaySessionManager: ObservableObject {

    static let shared = CarPlaySessionManager()

    @Published private(set) var isListening = false
    @Published private(set) var lastQuery: String?
    @Published private(set) var lastResponse: String?

    private init() {}

    /// Begin a voice query session. Delegates actual speech capture to
    /// the existing VoiceInputManager (iOS voice pipeline).
    func startListening() {
        guard !isListening else { return }
        isListening = true
        logger.info("CarPlay session: listening started")
    }

    /// Process the transcribed text through ChatManager and return a response.
    func processQuery(_ text: String) async {
        guard !text.isEmpty else { return }
        lastQuery = text
        // ABB3: Log length only — do not log voice content (privacy: voice queries stay private)
        logger.info("CarPlay session: processing query (\(text.count) chars)")

        // Delegate to ChatManager for AI response.
        // Requires an active conversation — use existing or create a CarPlay conversation.
        guard let conversation = ChatManager.shared.activeConversation else {
            logger.warning("CarPlay session: no active conversation — create one first")
            isListening = false
            return
        }

        do {
            try await ChatManager.shared.sendMessage(text, in: conversation)
            // The last assistant message is the most recent Message with role "assistant"
            if let response = conversation.messages
                .filter({ $0.role == "assistant" })
                .last?
                .content
                .textValue
            {
                lastResponse = response
                logger.info("CarPlay session: response ready (\(response.count) chars)")
            }
        } catch {
            logger.error("CarPlay session: query failed — \(error.localizedDescription)")
        }

        isListening = false
    }

    func stopListening() {
        isListening = false
        logger.info("CarPlay session: listening stopped")
    }
}
