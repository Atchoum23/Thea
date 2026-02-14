// VoiceModeTypesTests.swift
// Tests for VoiceModeState, VoiceSettings, WakeWordSensitivity,
// and VoiceModeError types.
// Mirrors types from Shared/Voice/VoiceModeControllerTypes.swift.

import Foundation
import XCTest

// MARK: - Mirror Types

private enum VoiceModeState: Equatable {
    case idle, listening, activated, processing, responding
    case error(String)

    var displayName: String {
        switch self {
        case .idle: "Off"
        case .listening: "Listening..."
        case .activated: "Speak now"
        case .processing: "Processing..."
        case .responding: "Responding..."
        case .error(let msg): "Error: \(msg)"
        }
    }

    var icon: String {
        switch self {
        case .idle: "mic.slash"
        case .listening: "waveform"
        case .activated: "mic.fill"
        case .processing: "brain.head.profile"
        case .responding: "speaker.wave.3.fill"
        case .error: "exclamationmark.triangle"
        }
    }
}

private struct VoiceSettings: Codable, Equatable {
    var wakeWord: String = "Hey THEA"
    var sensitivity: WakeWordSensitivity = .medium
    var confirmActivation: Bool = true
    var voiceFeedback: Bool = true
    var continuousListening: Bool = false
    var silenceTimeout: TimeInterval = 3.0
    var preferredLanguage: String = "en-US"

    enum WakeWordSensitivity: String, Codable, CaseIterable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"

        var threshold: Float {
            switch self {
            case .low: 0.85
            case .medium: 0.75
            case .high: 0.65
            }
        }
    }
}

private enum VoiceModeError: LocalizedError {
    case permissionDenied
    case speechRecognizerUnavailable
    case recognitionRequestFailed
    case audioEngineError

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "Microphone or speech recognition permission denied"
        case .speechRecognizerUnavailable:
            "Speech recognizer is not available"
        case .recognitionRequestFailed:
            "Failed to create recognition request"
        case .audioEngineError:
            "Audio engine error"
        }
    }
}

// MARK: - VoiceModeState Tests

final class VoiceModeStateTests: XCTestCase {

    func testIdleDisplayName() {
        XCTAssertEqual(VoiceModeState.idle.displayName, "Off")
    }

    func testListeningDisplayName() {
        XCTAssertEqual(VoiceModeState.listening.displayName, "Listening...")
    }

    func testActivatedDisplayName() {
        XCTAssertEqual(VoiceModeState.activated.displayName, "Speak now")
    }

    func testProcessingDisplayName() {
        XCTAssertEqual(VoiceModeState.processing.displayName, "Processing...")
    }

    func testRespondingDisplayName() {
        XCTAssertEqual(VoiceModeState.responding.displayName, "Responding...")
    }

    func testErrorDisplayNameIncludesMessage() {
        let state = VoiceModeState.error("Network timeout")
        XCTAssertEqual(state.displayName, "Error: Network timeout")
    }

    func testErrorDisplayNameEmptyMessage() {
        let state = VoiceModeState.error("")
        XCTAssertEqual(state.displayName, "Error: ")
    }

    func testIdleIcon() {
        XCTAssertEqual(VoiceModeState.idle.icon, "mic.slash")
    }

    func testListeningIcon() {
        XCTAssertEqual(VoiceModeState.listening.icon, "waveform")
    }

    func testActivatedIcon() {
        XCTAssertEqual(VoiceModeState.activated.icon, "mic.fill")
    }

    func testProcessingIcon() {
        XCTAssertEqual(VoiceModeState.processing.icon, "brain.head.profile")
    }

    func testRespondingIcon() {
        XCTAssertEqual(VoiceModeState.responding.icon, "speaker.wave.3.fill")
    }

    func testErrorIcon() {
        XCTAssertEqual(VoiceModeState.error("any").icon, "exclamationmark.triangle")
    }

    func testEquality() {
        XCTAssertEqual(VoiceModeState.idle, .idle)
        XCTAssertEqual(VoiceModeState.listening, .listening)
        XCTAssertNotEqual(VoiceModeState.idle, .listening)
    }

    func testErrorEquality() {
        XCTAssertEqual(VoiceModeState.error("a"), .error("a"))
        XCTAssertNotEqual(VoiceModeState.error("a"), .error("b"))
    }

    func testAllNonErrorStatesHaveNonEmptyDisplayNames() {
        let states: [VoiceModeState] = [.idle, .listening, .activated, .processing, .responding]
        for state in states {
            XCTAssertFalse(state.displayName.isEmpty, "\(state) should have non-empty displayName")
        }
    }

    func testAllStatesHaveNonEmptyIcons() {
        let states: [VoiceModeState] = [.idle, .listening, .activated, .processing, .responding, .error("x")]
        for state in states {
            XCTAssertFalse(state.icon.isEmpty, "\(state) should have non-empty icon")
        }
    }
}

// MARK: - WakeWordSensitivity Tests

final class WakeWordSensitivityTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(VoiceSettings.WakeWordSensitivity.allCases.count, 3)
    }

    func testRawValues() {
        XCTAssertEqual(VoiceSettings.WakeWordSensitivity.low.rawValue, "Low")
        XCTAssertEqual(VoiceSettings.WakeWordSensitivity.medium.rawValue, "Medium")
        XCTAssertEqual(VoiceSettings.WakeWordSensitivity.high.rawValue, "High")
    }

    func testThresholds() {
        XCTAssertEqual(VoiceSettings.WakeWordSensitivity.low.threshold, 0.85, accuracy: 0.001)
        XCTAssertEqual(VoiceSettings.WakeWordSensitivity.medium.threshold, 0.75, accuracy: 0.001)
        XCTAssertEqual(VoiceSettings.WakeWordSensitivity.high.threshold, 0.65, accuracy: 0.001)
    }

    func testHigherSensitivityMeansLowerThreshold() {
        // Higher sensitivity = lower threshold = easier to trigger
        XCTAssertGreaterThan(
            VoiceSettings.WakeWordSensitivity.low.threshold,
            VoiceSettings.WakeWordSensitivity.medium.threshold
        )
        XCTAssertGreaterThan(
            VoiceSettings.WakeWordSensitivity.medium.threshold,
            VoiceSettings.WakeWordSensitivity.high.threshold
        )
    }

    func testAllThresholdsInRange() {
        for sensitivity in VoiceSettings.WakeWordSensitivity.allCases {
            XCTAssertGreaterThan(sensitivity.threshold, 0.0)
            XCTAssertLessThanOrEqual(sensitivity.threshold, 1.0)
        }
    }

    func testCodableRoundTrip() throws {
        for sensitivity in VoiceSettings.WakeWordSensitivity.allCases {
            let data = try JSONEncoder().encode(sensitivity)
            let decoded = try JSONDecoder().decode(VoiceSettings.WakeWordSensitivity.self, from: data)
            XCTAssertEqual(decoded, sensitivity)
        }
    }
}

// MARK: - VoiceSettings Tests

final class VoiceSettingsTests: XCTestCase {

    func testDefaults() {
        let settings = VoiceSettings()
        XCTAssertEqual(settings.wakeWord, "Hey THEA")
        XCTAssertEqual(settings.sensitivity, .medium)
        XCTAssertTrue(settings.confirmActivation)
        XCTAssertTrue(settings.voiceFeedback)
        XCTAssertFalse(settings.continuousListening)
        XCTAssertEqual(settings.silenceTimeout, 3.0, accuracy: 0.001)
        XCTAssertEqual(settings.preferredLanguage, "en-US")
    }

    func testCodableRoundTrip() throws {
        var settings = VoiceSettings()
        settings.wakeWord = "Hey Assistant"
        settings.sensitivity = .high
        settings.continuousListening = true
        settings.silenceTimeout = 5.0
        settings.preferredLanguage = "fr-FR"

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(VoiceSettings.self, from: data)
        XCTAssertEqual(decoded, settings)
    }

    func testMutation() {
        var settings = VoiceSettings()
        settings.sensitivity = .low
        XCTAssertEqual(settings.sensitivity, .low)
        settings.sensitivity = .high
        XCTAssertEqual(settings.sensitivity, .high)
    }

    func testEquatable() {
        let settings1 = VoiceSettings()
        var settings2 = VoiceSettings()
        XCTAssertEqual(settings1, settings2)
        settings2.wakeWord = "Different"
        XCTAssertNotEqual(settings1, settings2)
    }
}

// MARK: - VoiceModeError Tests

final class VoiceModeErrorTests: XCTestCase {

    func testPermissionDeniedDescription() {
        let error = VoiceModeError.permissionDenied
        XCTAssertEqual(error.errorDescription, "Microphone or speech recognition permission denied")
    }

    func testSpeechRecognizerUnavailableDescription() {
        let error = VoiceModeError.speechRecognizerUnavailable
        XCTAssertEqual(error.errorDescription, "Speech recognizer is not available")
    }

    func testRecognitionRequestFailedDescription() {
        let error = VoiceModeError.recognitionRequestFailed
        XCTAssertEqual(error.errorDescription, "Failed to create recognition request")
    }

    func testAudioEngineErrorDescription() {
        let error = VoiceModeError.audioEngineError
        XCTAssertEqual(error.errorDescription, "Audio engine error")
    }

    func testAllErrorsHaveDescriptions() {
        let errors: [VoiceModeError] = [
            .permissionDenied, .speechRecognizerUnavailable,
            .recognitionRequestFailed, .audioEngineError
        ]
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }

    func testAllDescriptionsUnique() {
        let errors: [VoiceModeError] = [
            .permissionDenied, .speechRecognizerUnavailable,
            .recognitionRequestFailed, .audioEngineError
        ]
        let descriptions = errors.compactMap(\.errorDescription)
        XCTAssertEqual(Set(descriptions).count, descriptions.count)
    }
}
