// VoiceSettingsView.swift
// Settings for voice interaction, speech recognition, and TTS

import SwiftUI
import OSLog

// periphery:ignore - Reserved: logger global var reserved for future feature activation
private let logger = Logger(subsystem: "ai.thea.app", category: "VoiceSettingsView")

struct VoiceSettingsView: View {
    @State private var engine = VoiceInteractionEngine.shared
    @State private var isTestingVoice = false
    @State private var isTestingMic = false
    @State private var testTranscript = ""

    var body: some View {
        Form {
            generalSection
            recognitionSection
            synthesisSection
            voiceSelectionSection
            testingSection
        }
        .formStyle(.grouped)
        .navigationTitle("Voice Settings")
        #if os(macOS)
        .frame(minWidth: 500)
        #endif
    }

    // MARK: - General Section

    private var generalSection: some View {
        Section {
            Picker("Voice Backend", selection: Binding(
                get: { engine.configuration.backend },
                set: { updateBackend($0) }
            )) {
                ForEach(VoiceInteractionEngine.Configuration.VoiceBackend.allCases, id: \.self) { backend in
                    VStack(alignment: .leading) {
                        Text(backend.rawValue)
                        if backend.isOnDevice {
                            Text("Privacy-first, works offline")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(backend)
                }
            }

            Toggle("Enable Haptic Feedback", isOn: Binding(
                get: { engine.configuration.enableHapticFeedback },
                set: { updateHapticFeedback($0) }
            ))

            Toggle("Enable Visual Feedback", isOn: Binding(
                get: { engine.configuration.enableVisualFeedback },
                set: { updateVisualFeedback($0) }
            ))
        } header: {
            Text("General")
        } footer: {
            Text("Apple Native and WhisperKit process speech on-device for privacy.")
        }
    }

    // MARK: - Recognition Section

    private var recognitionSection: some View {
        Section {
            Toggle("On-Device Recognition", isOn: Binding(
                get: { engine.configuration.enableOnDeviceRecognition },
                set: { updateOnDeviceRecognition($0) }
            ))

            Toggle("Auto Language Detection", isOn: Binding(
                get: { engine.configuration.enableAutoLanguageDetection },
                set: { updateAutoLanguageDetection($0) }
            ))

            Toggle("Continuous Listening", isOn: Binding(
                get: { engine.configuration.enableContinuousListening },
                set: { updateContinuousListening($0) }
            ))

            VStack(alignment: .leading) {
                Text("Max Listening Duration: \(Int(engine.configuration.maxListeningDuration))s")
                Slider(
                    value: Binding(
                        get: { engine.configuration.maxListeningDuration },
                        set: { updateMaxDuration($0) }
                    ),
                    in: 10...120,
                    step: 10
                )
            }

            VStack(alignment: .leading) {
                Text("Silence Timeout: \(String(format: "%.1f", engine.configuration.silenceTimeout))s")
                Slider(
                    value: Binding(
                        get: { engine.configuration.silenceTimeout },
                        set: { updateSilenceTimeout($0) }
                    ),
                    in: 1...5,
                    step: 0.5
                )
            }
        } header: {
            Text("Speech Recognition")
        } footer: {
            Text("On-device recognition keeps your voice data private and works offline.")
        }
    }

    // MARK: - Synthesis Section

    private var synthesisSection: some View {
        Section {
            VStack(alignment: .leading) {
                Text("Speech Rate")
                HStack {
                    Text("Slow")
                        .font(.caption)
                    Slider(
                        value: Binding(
                            get: { engine.configuration.speechRate },
                            set: { updateSpeechRate($0) }
                        ),
                        in: 0.1...1.0
                    )
                    Text("Fast")
                        .font(.caption)
                }
            }

            VStack(alignment: .leading) {
                Text("Pitch")
                HStack {
                    Text("Low")
                        .font(.caption)
                    Slider(
                        value: Binding(
                            get: { engine.configuration.speechPitch },
                            set: { updatePitch($0) }
                        ),
                        in: 0.5...2.0
                    )
                    Text("High")
                        .font(.caption)
                }
            }
        } header: {
            Text("Speech Synthesis")
        }
    }

    // MARK: - Voice Selection

    private var voiceSelectionSection: some View {
        Section {
            let voices = engine.getAvailableVoices()
            let groupedVoices = Dictionary(grouping: voices) { String($0.language.prefix(2)) }

            ForEach(groupedVoices.keys.sorted(), id: \.self) { langCode in
                DisclosureGroup {
                    ForEach(groupedVoices[langCode] ?? [], id: \.identifier) { voice in
                        VoiceRow(
                            voice: voice,
                            isSelected: engine.configuration.preferredVoiceIdentifier == voice.identifier,
                            onSelect: { selectVoice(voice) },
                            onPreview: { previewVoice(voice) }
                        )
                    }
                } label: {
                    HStack {
                        Text(languageName(for: langCode))
                        Spacer()
                        Text("\(groupedVoices[langCode]?.count ?? 0) voices")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
            }
        } header: {
            Text("Voice Selection")
        } footer: {
            Text("Premium voices provide higher quality synthesis. Tap to preview.")
        }
    }

    // MARK: - Testing Section

    private var testingSection: some View {
        Section {
            // Test microphone
            Button {
                testMicrophone()
            } label: {
                HStack {
                    Image(systemName: isTestingMic ? "mic.fill" : "mic")
                        .foregroundStyle(isTestingMic ? .red : .primary)
                    Text(isTestingMic ? "Listening..." : "Test Microphone")
                    Spacer()
                    if isTestingMic {
                        ProgressView()
                    }
                }
            }
            .disabled(isTestingVoice)

            if !testTranscript.isEmpty {
                Text("Heard: \"\(testTranscript)\"")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Test voice
            Button {
                testVoice()
            } label: {
                HStack {
                    Image(systemName: isTestingVoice ? "speaker.wave.3.fill" : "speaker.wave.2")
                        .foregroundStyle(isTestingVoice ? .blue : .primary)
                    Text(isTestingVoice ? "Speaking..." : "Test Voice Output")
                    Spacer()
                    if isTestingVoice {
                        ProgressView()
                    }
                }
            }
            .disabled(isTestingMic)

            // Authorization status
            HStack {
                Text("Speech Recognition")
                Spacer()
                if engine.isAuthorized {
                    Label("Authorized", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Button("Authorize") {
                        Task {
                            _ = await engine.requestAuthorization()
                        }
                    }
                }
            }
        } header: {
            Text("Testing")
        }
    }

    // MARK: - Actions

    private func updateBackend(_ backend: VoiceInteractionEngine.Configuration.VoiceBackend) {
        var config = engine.configuration
        config.backend = backend
        engine.updateConfiguration(config)
    }

    private func updateHapticFeedback(_ enabled: Bool) {
        var config = engine.configuration
        config.enableHapticFeedback = enabled
        engine.updateConfiguration(config)
    }

    private func updateVisualFeedback(_ enabled: Bool) {
        var config = engine.configuration
        config.enableVisualFeedback = enabled
        engine.updateConfiguration(config)
    }

    private func updateOnDeviceRecognition(_ enabled: Bool) {
        var config = engine.configuration
        config.enableOnDeviceRecognition = enabled
        engine.updateConfiguration(config)
    }

    private func updateAutoLanguageDetection(_ enabled: Bool) {
        var config = engine.configuration
        config.enableAutoLanguageDetection = enabled
        engine.updateConfiguration(config)
    }

    private func updateContinuousListening(_ enabled: Bool) {
        var config = engine.configuration
        config.enableContinuousListening = enabled
        engine.updateConfiguration(config)
    }

    private func updateMaxDuration(_ duration: Double) {
        var config = engine.configuration
        config.maxListeningDuration = duration
        engine.updateConfiguration(config)
    }

    private func updateSilenceTimeout(_ timeout: Double) {
        var config = engine.configuration
        config.silenceTimeout = timeout
        engine.updateConfiguration(config)
    }

    private func updateSpeechRate(_ rate: Float) {
        var config = engine.configuration
        config.speechRate = rate
        engine.updateConfiguration(config)
    }

    private func updatePitch(_ pitch: Float) {
        var config = engine.configuration
        config.speechPitch = pitch
        engine.updateConfiguration(config)
    }

    private func selectVoice(_ voice: VoiceInfo) {
        var config = engine.configuration
        config.preferredVoiceIdentifier = voice.identifier
        engine.updateConfiguration(config)
    }

    private func previewVoice(_ voice: VoiceInfo) {
        engine.speak("Hello! I am \(voice.name), your voice assistant.", language: voice.language)
    }

    func testMicrophone() {
        if isTestingMic {
            engine.stopListening()
            isTestingMic = false
        } else {
            isTestingMic = true
            testTranscript = ""

            Task {
                do {
                    let text = try await engine.listenForSpeech(timeout: 5.0)
                    testTranscript = text
                } catch {
                    testTranscript = "Error: \(error.localizedDescription)"
                }
                isTestingMic = false
            }
        }
    }

    func testVoice() {
        if isTestingVoice {
            engine.stopSpeaking()
            isTestingVoice = false
        } else {
            isTestingVoice = true
            engine.speak("Hello! This is a test of the voice synthesis system. How does this sound?")

            Task {
                while engine.isSpeaking {
                    do {
                        try await Task.sleep(for: .milliseconds(100))
                    } catch {
                        break
                    }
                }
                isTestingVoice = false
            }
        }
    }

    private func languageName(for code: String) -> String {
        Locale.current.localizedString(forLanguageCode: code) ?? code
    }
}

// MARK: - Voice Row

struct VoiceRow: View {
    let voice: VoiceInfo
    let isSelected: Bool
    let onSelect: () -> Void
    let onPreview: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(voice.name)
                    if voice.quality == .premium {
                        Text("Premium")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.2))
                            .cornerRadius(4)
                    } else if voice.quality == .enhanced {
                        Text("Enhanced")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                Text("\(voice.language) - \(voice.gender.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                onPreview()
            } label: {
                Image(systemName: "play.circle")
            }
            .buttonStyle(.borderless)

            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(.blue)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
}

#Preview {
    NavigationStack {
        VoiceSettingsView()
    }
}
