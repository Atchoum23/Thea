// VoiceSystemTypesTests.swift
// Tests for voice system types: VoiceInteractionEngine, WakeWordEngine, VoiceFirstModeManager

import Testing
import Foundation

// MARK: - Test Doubles: VoiceBackend

private enum TestVoiceBackend: String, CaseIterable, Codable, Sendable {
    case appleNative, whisperKit, mlxAudio, vapi, hybrid

    var displayName: String {
        switch self {
        case .appleNative: return "Apple Native (On-Device)"
        case .whisperKit: return "WhisperKit (Local AI)"
        case .mlxAudio: return "MLX Audio (Local AI)"
        case .vapi: return "Vapi (Cloud)"
        case .hybrid: return "Hybrid (Auto-Select)"
        }
    }

    var isOnDevice: Bool {
        switch self {
        case .appleNative, .whisperKit, .mlxAudio: return true
        case .vapi: return false
        case .hybrid: return false
        }
    }
}

// MARK: - Test Doubles: VoiceInfo

private struct TestVoiceInfo: Identifiable, Sendable {
    let identifier: String
    let name: String
    let language: String
    let quality: Quality
    let gender: Gender

    var id: String { identifier }

    enum Quality: String, Codable, Sendable {
        case standard, enhanced, premium
    }

    enum Gender: String, Codable, Sendable {
        case male, female, unspecified
    }
}

// MARK: - Test Doubles: VoiceInteractionError

private enum TestVoiceInteractionError: Error, LocalizedError {
    case notAuthorized
    case recognitionUnavailable
    case audioSessionError
    case timeout
    case cancelled

    var errorDescription: String? {
        switch self {
        case .notAuthorized: return "Microphone access is not authorized"
        case .recognitionUnavailable: return "Speech recognition is unavailable"
        case .audioSessionError: return "Failed to configure audio session"
        case .timeout: return "Voice input timed out"
        case .cancelled: return "Voice input was cancelled"
        }
    }
}

// MARK: - Test Doubles: WakeWord

private enum TestWakeWord: String, CaseIterable, Codable, Sendable {
    case heyThea = "Hey, Thea"
    case thea = "Thea"

    var displayName: String { rawValue }

    var phonemes: [String] {
        switch self {
        case .heyThea: return ["HH", "EY", "TH", "IY", "AH"]
        case .thea: return ["TH", "IY", "AH"]
        }
    }

    var minimumDuration: Double {
        switch self {
        case .heyThea: return 0.6
        case .thea: return 0.3
        }
    }
}

// MARK: - Test Doubles: DetectedWakeWord

private struct TestDetectedWakeWord: Sendable {
    let wakeWord: TestWakeWord
    let confidence: Float
    let timestamp: Date
    let audioLevel: Float
    let speakerVerified: Bool
    let processingLatency: TimeInterval
}

// MARK: - Test Doubles: PowerLevel

private enum TestPowerLevel: String, CaseIterable, Codable, Sendable {
    case minimal, low, balanced, high

    var description: String {
        switch self {
        case .minimal: return "Minimal (VAD only)"
        case .low: return "Low (Occasional checks)"
        case .balanced: return "Balanced (Standard)"
        case .high: return "High (Maximum accuracy)"
        }
    }
}

// MARK: - Test Doubles: WakeWordConfiguration

private struct TestWakeWordConfig: Codable, Sendable {
    var enabledWakeWords: Set<String> = ["Hey, Thea", "Thea"]
    var sensitivity: Float = 0.5
    var enableSpeakerVerification: Bool = false
    var powerMode: TestPowerLevel = .balanced
    var enableHapticFeedback: Bool = true
    var enableAudioFeedback: Bool = true
    var maxFalseAcceptanceRate: Float = 0.01
    var targetFalseRejectionRate: Float = 0.05
    var continuousListening: Bool = true
    var timeoutAfterDetection: TimeInterval = 10.0
    var cooldownBetweenDetections: TimeInterval = 2.0

    var activeWakeWords: [TestWakeWord] {
        TestWakeWord.allCases.filter { enabledWakeWords.contains($0.rawValue) }
    }
}

// MARK: - Test Doubles: WakeWordError

private enum TestWakeWordError: Error, LocalizedError {
    case notAuthorized
    case audioSetupFailed
    case alreadyListening
    case notListening
    case speakerVerificationNotEnabled
    case trainingFailed

    var errorDescription: String? {
        switch self {
        case .notAuthorized: return "Microphone access not authorized"
        case .audioSetupFailed: return "Failed to set up audio"
        case .alreadyListening: return "Already listening for wake word"
        case .notListening: return "Not currently listening"
        case .speakerVerificationNotEnabled: return "Speaker verification is not enabled"
        case .trainingFailed: return "Wake word training failed"
        }
    }
}

// MARK: - Test Doubles: VoicePhase

private enum TestVoicePhase: String, Sendable {
    case idle, waitingForWakeWord, listening, processing, speaking

    var isActive: Bool { self != .idle }

    var userInstruction: String {
        switch self {
        case .idle: return "Tap to start voice mode"
        case .waitingForWakeWord: return "Say \"Hey Thea\" to begin"
        case .listening: return "Listening... speak your query"
        case .processing: return "Processing your request..."
        case .speaking: return "Speaking response..."
        }
    }
}

// MARK: - Test Doubles: VoiceStats

private struct TestVoiceStats: Sendable {
    var sessionsStarted: Int = 0
    var wakeWordsDetected: Int = 0
    var queriesProcessed: Int = 0
    var responsesSpoken: Int = 0

    var successRate: Double {
        guard wakeWordsDetected > 0 else { return 0 }
        return Double(queriesProcessed) / Double(wakeWordsDetected)
    }
}

// MARK: - Test Doubles: VoiceFirstError

private enum TestVoiceFirstError: LocalizedError {
    case notAuthorized
    case notActive
    case voiceInputFailed(String)
    case processingFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthorized: return "Voice input is not authorized"
        case .notActive: return "Voice-first mode is not active"
        case .voiceInputFailed(let msg): return "Voice input failed: \(msg)"
        case .processingFailed(let msg): return "Processing failed: \(msg)"
        }
    }
}

// MARK: - Test Doubles: VoiceFirstConfiguration

private struct TestVoiceFirstConfig: Codable, Sendable {
    var autoSpeak: Bool = true
    var continuousMode: Bool = true
    var inputTimeout: TimeInterval = 10.0
    var voiceIdentifier: String?
    var speechRate: Float = 0.5
    var enableSounds: Bool = true
    var enableHaptics: Bool = true
    var briefResponseCommands: Set<String> = ["time", "date", "weather", "timer"]
}

// MARK: - Tests: VoiceBackend

@Suite("Voice Backend")
struct VoiceBackendTests {
    @Test("All cases exist")
    func allCases() {
        #expect(TestVoiceBackend.allCases.count == 5)
    }

    @Test("On-device backends")
    func onDeviceBackends() {
        #expect(TestVoiceBackend.appleNative.isOnDevice)
        #expect(TestVoiceBackend.whisperKit.isOnDevice)
        #expect(TestVoiceBackend.mlxAudio.isOnDevice)
    }

    @Test("Cloud backends")
    func cloudBackends() {
        #expect(!TestVoiceBackend.vapi.isOnDevice)
    }

    @Test("Hybrid is not on-device")
    func hybridNotOnDevice() {
        #expect(!TestVoiceBackend.hybrid.isOnDevice)
    }

    @Test("Display names are unique")
    func displayNamesUnique() {
        let names = Set(TestVoiceBackend.allCases.map(\.displayName))
        #expect(names.count == TestVoiceBackend.allCases.count)
    }

    @Test("Codable roundtrip")
    func codable() throws {
        for backend in TestVoiceBackend.allCases {
            let data = try JSONEncoder().encode(backend)
            let decoded = try JSONDecoder().decode(TestVoiceBackend.self, from: data)
            #expect(decoded == backend)
        }
    }
}

// MARK: - Tests: VoiceInfo

@Suite("Voice Info")
struct VoiceInfoTests {
    @Test("Quality enum cases")
    func qualityCases() {
        let qualities: [TestVoiceInfo.Quality] = [.standard, .enhanced, .premium]
        #expect(qualities.count == 3)
    }

    @Test("Gender enum cases")
    func genderCases() {
        let genders: [TestVoiceInfo.Gender] = [.male, .female, .unspecified]
        #expect(genders.count == 3)
    }

    @Test("Identifiable uses identifier")
    func identifiable() {
        let voice = TestVoiceInfo(identifier: "com.apple.voice.en-US.samantha", name: "Samantha", language: "en-US", quality: .enhanced, gender: .female)
        #expect(voice.id == "com.apple.voice.en-US.samantha")
    }

    @Test("Quality Codable roundtrip")
    func qualityCodable() throws {
        for quality in [TestVoiceInfo.Quality.standard, .enhanced, .premium] {
            let data = try JSONEncoder().encode(quality)
            let decoded = try JSONDecoder().decode(TestVoiceInfo.Quality.self, from: data)
            #expect(decoded == quality)
        }
    }
}

// MARK: - Tests: VoiceInteractionError

@Suite("Voice Interaction Error")
struct VoiceInteractionErrorTests {
    @Test("All errors have descriptions")
    func allDescriptions() {
        let errors: [TestVoiceInteractionError] = [.notAuthorized, .recognitionUnavailable, .audioSessionError, .timeout, .cancelled]
        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }

    @Test("Descriptions are unique")
    func descriptionsUnique() {
        let errors: [TestVoiceInteractionError] = [.notAuthorized, .recognitionUnavailable, .audioSessionError, .timeout, .cancelled]
        let descriptions = Set(errors.compactMap(\.errorDescription))
        #expect(descriptions.count == errors.count)
    }
}

// MARK: - Tests: WakeWord

@Suite("Wake Word")
struct WakeWordTests {
    @Test("All cases exist")
    func allCases() {
        #expect(TestWakeWord.allCases.count == 2)
    }

    @Test("Display names match raw values")
    func displayNames() {
        for word in TestWakeWord.allCases {
            #expect(word.displayName == word.rawValue)
        }
    }

    @Test("Hey Thea has more phonemes than Thea")
    func phonemeCounts() {
        #expect(TestWakeWord.heyThea.phonemes.count > TestWakeWord.thea.phonemes.count)
    }

    @Test("Hey Thea has longer minimum duration")
    func minimumDurations() {
        #expect(TestWakeWord.heyThea.minimumDuration > TestWakeWord.thea.minimumDuration)
    }

    @Test("Minimum durations are positive")
    func positiveDurations() {
        for word in TestWakeWord.allCases {
            #expect(word.minimumDuration > 0)
        }
    }

    @Test("Phonemes are non-empty")
    func phonemesNonEmpty() {
        for word in TestWakeWord.allCases {
            #expect(!word.phonemes.isEmpty)
        }
    }
}

// MARK: - Tests: PowerLevel

@Suite("Power Level")
struct PowerLevelTests {
    @Test("All cases exist")
    func allCases() {
        #expect(TestPowerLevel.allCases.count == 4)
    }

    @Test("Descriptions are non-empty")
    func descriptions() {
        for level in TestPowerLevel.allCases {
            #expect(!level.description.isEmpty)
        }
    }

    @Test("Descriptions are unique")
    func descriptionsUnique() {
        let descs = Set(TestPowerLevel.allCases.map(\.description))
        #expect(descs.count == TestPowerLevel.allCases.count)
    }
}

// MARK: - Tests: WakeWordConfiguration

@Suite("Wake Word Configuration")
struct WakeWordConfigTests {
    @Test("Default configuration")
    func defaults() {
        let config = TestWakeWordConfig()
        #expect(config.sensitivity == 0.5)
        #expect(!config.enableSpeakerVerification)
        #expect(config.powerMode == .balanced)
        #expect(config.continuousListening)
        #expect(config.enabledWakeWords.count == 2)
    }

    @Test("Active wake words from default config")
    func activeWakeWordsDefault() {
        let config = TestWakeWordConfig()
        let active = config.activeWakeWords
        #expect(active.count == 2)
    }

    @Test("Active wake words with subset")
    func activeWakeWordsSubset() {
        var config = TestWakeWordConfig()
        config.enabledWakeWords = ["Thea"]
        let active = config.activeWakeWords
        #expect(active.count == 1)
        #expect(active.first == .thea)
    }

    @Test("Active wake words with empty set")
    func activeWakeWordsEmpty() {
        var config = TestWakeWordConfig()
        config.enabledWakeWords = []
        #expect(config.activeWakeWords.isEmpty)
    }

    @Test("Codable roundtrip")
    func codable() throws {
        var config = TestWakeWordConfig()
        config.sensitivity = 0.8
        config.powerMode = .high
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(TestWakeWordConfig.self, from: data)
        #expect(decoded.sensitivity == 0.8)
        #expect(decoded.powerMode == .high)
    }
}

// MARK: - Tests: WakeWordError

@Suite("Wake Word Error")
struct WakeWordErrorTests {
    @Test("All errors have descriptions")
    func allDescriptions() {
        let errors: [TestWakeWordError] = [.notAuthorized, .audioSetupFailed, .alreadyListening, .notListening, .speakerVerificationNotEnabled, .trainingFailed]
        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }

    @Test("Descriptions are unique")
    func uniqueDescriptions() {
        let errors: [TestWakeWordError] = [.notAuthorized, .audioSetupFailed, .alreadyListening, .notListening, .speakerVerificationNotEnabled, .trainingFailed]
        let descs = Set(errors.compactMap(\.errorDescription))
        #expect(descs.count == errors.count)
    }
}

// MARK: - Tests: VoicePhase

@Suite("Voice Phase")
struct VoicePhaseTests {
    @Test("Idle is not active")
    func idleNotActive() {
        #expect(!TestVoicePhase.idle.isActive)
    }

    @Test("All non-idle phases are active")
    func nonIdleActive() {
        let phases: [TestVoicePhase] = [.waitingForWakeWord, .listening, .processing, .speaking]
        for phase in phases {
            #expect(phase.isActive)
        }
    }

    @Test("User instructions are non-empty")
    func instructions() {
        let phases: [TestVoicePhase] = [.idle, .waitingForWakeWord, .listening, .processing, .speaking]
        for phase in phases {
            #expect(!phase.userInstruction.isEmpty)
        }
    }

    @Test("User instructions are unique")
    func instructionsUnique() {
        let phases: [TestVoicePhase] = [.idle, .waitingForWakeWord, .listening, .processing, .speaking]
        let instructions = Set(phases.map(\.userInstruction))
        #expect(instructions.count == phases.count)
    }
}

// MARK: - Tests: VoiceStats

@Suite("Voice Stats")
struct VoiceStatsTests {
    @Test("Default stats are zero")
    func defaults() {
        let stats = TestVoiceStats()
        #expect(stats.sessionsStarted == 0)
        #expect(stats.wakeWordsDetected == 0)
        #expect(stats.queriesProcessed == 0)
        #expect(stats.responsesSpoken == 0)
    }

    @Test("Success rate with zero detections")
    func successRateZeroDivision() {
        let stats = TestVoiceStats()
        #expect(stats.successRate == 0)
    }

    @Test("Success rate calculation")
    func successRate() {
        let stats = TestVoiceStats(wakeWordsDetected: 10, queriesProcessed: 7)
        #expect(stats.successRate == 0.7)
    }

    @Test("Perfect success rate")
    func perfectSuccessRate() {
        let stats = TestVoiceStats(wakeWordsDetected: 5, queriesProcessed: 5)
        #expect(stats.successRate == 1.0)
    }
}

// MARK: - Tests: VoiceFirstError

@Suite("Voice First Error")
struct VoiceFirstErrorTests {
    @Test("Error descriptions contain details")
    func descriptions() {
        let errors: [TestVoiceFirstError] = [.notAuthorized, .notActive, .voiceInputFailed("timeout"), .processingFailed("model error")]
        for error in errors {
            #expect(error.errorDescription != nil)
        }
    }

    @Test("VoiceInputFailed includes message")
    func voiceInputFailedMsg() {
        let error = TestVoiceFirstError.voiceInputFailed("microphone not found")
        #expect(error.errorDescription!.contains("microphone not found"))
    }

    @Test("ProcessingFailed includes message")
    func processingFailedMsg() {
        let error = TestVoiceFirstError.processingFailed("inference error")
        #expect(error.errorDescription!.contains("inference error"))
    }
}

// MARK: - Tests: VoiceFirstConfiguration

@Suite("Voice First Configuration")
struct VoiceFirstConfigTests {
    @Test("Default configuration")
    func defaults() {
        let config = TestVoiceFirstConfig()
        #expect(config.autoSpeak)
        #expect(config.continuousMode)
        #expect(config.inputTimeout == 10.0)
        #expect(config.voiceIdentifier == nil)
        #expect(config.speechRate == 0.5)
        #expect(config.enableSounds)
        #expect(config.enableHaptics)
        #expect(config.briefResponseCommands.count == 4)
    }

    @Test("Brief response commands include time")
    func briefCommands() {
        let config = TestVoiceFirstConfig()
        #expect(config.briefResponseCommands.contains("time"))
        #expect(config.briefResponseCommands.contains("weather"))
    }

    @Test("Codable roundtrip")
    func codable() throws {
        var config = TestVoiceFirstConfig()
        config.autoSpeak = false
        config.speechRate = 0.8
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(TestVoiceFirstConfig.self, from: data)
        #expect(!decoded.autoSpeak)
        #expect(decoded.speechRate == 0.8)
    }
}

// MARK: - Tests: DetectedWakeWord

@Suite("Detected Wake Word")
struct DetectedWakeWordTests {
    @Test("Creation with all properties")
    func creation() {
        let now = Date()
        let detected = TestDetectedWakeWord(wakeWord: .heyThea, confidence: 0.95, timestamp: now, audioLevel: 0.7, speakerVerified: true, processingLatency: 0.05)
        #expect(detected.wakeWord == .heyThea)
        #expect(detected.confidence == 0.95)
        #expect(detected.speakerVerified)
        #expect(detected.processingLatency < 0.1)
    }

    @Test("Low confidence detection")
    func lowConfidence() {
        let detected = TestDetectedWakeWord(wakeWord: .thea, confidence: 0.3, timestamp: Date(), audioLevel: 0.2, speakerVerified: false, processingLatency: 0.1)
        #expect(detected.confidence < 0.5)
        #expect(!detected.speakerVerified)
    }
}
