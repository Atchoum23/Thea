// AudioOutputRouter.swift
// Thea
//
// Bridges BluetoothDeviceManager's device awareness to VoiceModeController,
// automatically routing chat responses through voice output when connected
// to audio devices like car stereos, headphones, or earbuds.

import Foundation
import os.log

// MARK: - Audio Output Router

/// Routes Thea's responses to the appropriate output channel based on
/// connected audio devices. When Bluetooth audio (car, headphones, earbuds)
/// is detected, responses are spoken via VoiceModeController. Otherwise,
/// responses remain text-only.
@MainActor
@Observable
public final class AudioOutputRouter {
    public static let shared = AudioOutputRouter()

    private let logger = Logger(subsystem: "ai.thea.app", category: "AudioRouter")

    // MARK: - State

    /// Whether voice output is currently active
    public private(set) var isVoiceOutputActive: Bool = false

    /// The device currently driving voice output (nil if text mode)
    public private(set) var activeVoiceDevice: TheaAudioDevice?

    /// History of routing decisions for debugging
    public private(set) var routingLog: [(Date, String)] = []

    // MARK: - Configuration

    /// Maximum text length to speak (longer responses are truncated with summary)
    public var maxSpeechLength: Int = 2000

    /// Whether to announce device connections
    public var announceConnections: Bool = true

    // MARK: - Initialization

    private init() {
        logger.info("AudioOutputRouter initializing")

        // Observe BluetoothDeviceManager for state changes
        let deviceManager = BluetoothDeviceManager.shared
        deviceManager.onVoiceOutputStateChanged = { [weak self] shouldUseVoice in
            Task { @MainActor in
                self?.handleVoiceOutputChange(shouldUseVoice)
            }
        }

        deviceManager.onDevicesChanged = { [weak self] devices in
            Task { @MainActor in
                self?.handleDevicesChanged(devices)
            }
        }

        // Sync initial state
        isVoiceOutputActive = deviceManager.shouldUseVoiceOutput
        activeVoiceDevice = deviceManager.connectedAudioDevices.first {
            deviceManager.voiceOutputCategories.contains($0.category)
        }
    }

    // MARK: - Response Routing

    /// Route a completed chat response through the appropriate output channel.
    /// Call this after the assistant response is fully streamed.
    ///
    /// - Parameter text: The complete response text to potentially speak
    public func routeResponse(_ text: String) {
        guard isVoiceOutputActive else { return }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let textToSpeak: String
        if text.count > maxSpeechLength {
            // For very long responses, speak a condensed version
            let truncated = String(text.prefix(maxSpeechLength))
            let lastSentenceEnd = truncated.lastIndex(of: ".") ?? truncated.endIndex
            textToSpeak = String(truncated[truncated.startIndex ..< lastSentenceEnd]) + "."
            logger.info("Truncated response from \(text.count) to \(textToSpeak.count) chars for speech")
        } else {
            textToSpeak = text
        }

        // Speak via VoiceModeController
        VoiceModeController.shared.speak(textToSpeak)
        logRouting("Spoke \(textToSpeak.count) chars via \(activeVoiceDevice?.name ?? "unknown")")
    }

    /// Check whether a response should be routed to voice
    public var shouldRouteToVoice: Bool {
        isVoiceOutputActive && BluetoothDeviceManager.shared.autoVoiceEnabled
    }

    // MARK: - Device Change Handling

    private func handleVoiceOutputChange(_ shouldUseVoice: Bool) {
        let previous = isVoiceOutputActive
        isVoiceOutputActive = shouldUseVoice

        // Update active device
        let deviceManager = BluetoothDeviceManager.shared
        activeVoiceDevice = deviceManager.connectedAudioDevices.first {
            deviceManager.voiceOutputCategories.contains($0.category)
        }

        guard previous != shouldUseVoice else { return }

        if shouldUseVoice {
            logger.info("Voice output activated — device: \(self.activeVoiceDevice?.name ?? "unknown")")
            logRouting("Voice output ON: \(activeVoiceDevice?.name ?? "unknown")")

            if announceConnections, let device = activeVoiceDevice {
                // Brief announcement that Thea is now in voice mode
                let announcement = "I'm connected to \(device.name). I'll speak my responses."
                VoiceModeController.shared.speak(announcement)
            }
        } else {
            logger.info("Voice output deactivated — returning to text mode")
            logRouting("Voice output OFF")
        }
    }

    private func handleDevicesChanged(_ devices: [TheaAudioDevice]) {
        // Update active voice device reference
        let deviceManager = BluetoothDeviceManager.shared
        activeVoiceDevice = devices.first {
            deviceManager.voiceOutputCategories.contains($0.category)
        }
    }

    // MARK: - Logging

    private func logRouting(_ message: String) {
        routingLog.append((Date(), message))
        // Keep last 50 entries
        if routingLog.count > 50 {
            routingLog.removeFirst(routingLog.count - 50)
        }
    }
}
