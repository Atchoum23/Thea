// VoiceSettingsView.swift
// Comprehensive voice settings for Thea

import AVFoundation
import SwiftUI

struct VoiceSettingsView: View {
    @State private var voiceEngine = VoiceActivationEngine.shared
    @State private var config = AppConfiguration.shared.voiceConfig
    @State private var settingsManager = SettingsManager.shared
    @State private var showingWakeWordEditor = false
    @State private var showingVoiceSelector = false
    @State private var newWakeWord = ""
    @State private var availableVoices: [AVSpeechSynthesisVoice] = []
    @State private var selectedVoiceIdentifier: String = ""
    @State private var isTestingVoice = false

    var body: some View {
        Form {
            // MARK: - Overview
            Section("Voice Assistant Overview") {
                voiceOverview
            }

            // MARK: - Wake Word Settings
            Section("Wake Words") {
                wakeWordSection
            }

            // MARK: - Voice Profiles
            Section("Voice Output") {
                voiceOutputSection
            }

            // MARK: - Speech Recognition
            Section("Speech Recognition") {
                speechRecognitionSection
            }

            // MARK: - Conversation Mode
            Section("Conversation Mode") {
                conversationModeSection
            }

            // MARK: - Audio Feedback
            Section("Audio Feedback") {
                audioFeedbackSection
            }

            // MARK: - Advanced Settings
            Section("Advanced") {
                advancedSection
            }

            // MARK: - Test & Debug
            Section("Test & Debug") {
                testSection
            }

            // MARK: - Reset
            Section {
                Button("Reset Voice Settings", role: .destructive) {
                    resetToDefaults()
                }
            }
        }
        .formStyle(.grouped)
        #if os(macOS)
        .padding()
        #endif
        .onAppear {
            loadAvailableVoices()
            selectedVoiceIdentifier = config.speechLanguage
        }
        .onChange(of: config) { _, _ in
            saveConfig()
        }
        .sheet(isPresented: $showingWakeWordEditor) {
            wakeWordEditorSheet
        }
        .sheet(isPresented: $showingVoiceSelector) {
            voiceSelectorSheet
        }
    }

    // MARK: - Voice Overview

    private var voiceOverview: some View {
        VStack(spacing: 12) {
            #if os(macOS)
            HStack(spacing: 16) {
                overviewCard(
                    title: "Status",
                    value: voiceEngine.isListening ? "Listening" : "Idle",
                    icon: voiceEngine.isListening ? "mic.fill" : "mic.slash.fill",
                    color: voiceEngine.isListening ? .green : .secondary
                )

                overviewCard(
                    title: "Wake Words",
                    value: "\(config.wakeWords.count)",
                    icon: "text.bubble.fill",
                    color: .blue
                )

                overviewCard(
                    title: "Mode",
                    value: voiceEngine.conversationMode ? "Conversation" : "Command",
                    icon: voiceEngine.conversationMode ? "bubble.left.and.bubble.right.fill" : "command",
                    color: voiceEngine.conversationMode ? .purple : .orange
                )

                overviewCard(
                    title: "Recognition",
                    value: config.requiresOnDeviceRecognition ? "On-Device" : "Cloud",
                    icon: config.requiresOnDeviceRecognition ? "cpu" : "cloud",
                    color: config.requiresOnDeviceRecognition ? .green : .blue
                )
            }
            #else
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                overviewCard(
                    title: "Status",
                    value: voiceEngine.isListening ? "Listening" : "Idle",
                    icon: voiceEngine.isListening ? "mic.fill" : "mic.slash.fill",
                    color: voiceEngine.isListening ? .green : .secondary
                )

                overviewCard(
                    title: "Wake Words",
                    value: "\(config.wakeWords.count)",
                    icon: "text.bubble.fill",
                    color: .blue
                )

                overviewCard(
                    title: "Mode",
                    value: voiceEngine.conversationMode ? "Conversation" : "Command",
                    icon: voiceEngine.conversationMode ? "bubble.left.and.bubble.right.fill" : "command",
                    color: voiceEngine.conversationMode ? .purple : .orange
                )

                overviewCard(
                    title: "Recognition",
                    value: config.requiresOnDeviceRecognition ? "On-Device" : "Cloud",
                    icon: config.requiresOnDeviceRecognition ? "cpu" : "cloud",
                    color: config.requiresOnDeviceRecognition ? .green : .blue
                )
            }
            #endif

            // Last transcript
            if !voiceEngine.lastTranscript.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Last Heard")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("\"\(voiceEngine.lastTranscript)\"")
                        .font(.body)
                        .italic()
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func overviewCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.headline)
                .fontWeight(.semibold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Wake Word Section

    private var wakeWordSection: some View {
        Group {
            Toggle("Enable Wake Word Detection", isOn: $config.wakeWordEnabled)
                .onChange(of: config.wakeWordEnabled) { _, enabled in
                    Task {
                        if enabled {
                            try? await voiceEngine.startWakeWordDetection()
                        } else {
                            voiceEngine.stopWakeWordDetection()
                        }
                    }
                }

            if config.wakeWordEnabled {
                HStack {
                    Image(systemName: voiceEngine.isListening ? "waveform.circle.fill" : "waveform.circle")
                        .foregroundStyle(voiceEngine.isListening ? .green : .secondary)
                        .symbolEffect(.pulse, isActive: voiceEngine.isListening)

                    Text(voiceEngine.isListening ? "Actively listening for wake words" : "Not listening")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // Wake words list
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Configured Wake Words")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text("\(config.wakeWords.count) phrases configured")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    showingWakeWordEditor = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }

            // Show wake words
            ForEach(config.wakeWords, id: \.self) { wakeWord in
                HStack {
                    Image(systemName: "quote.bubble")
                        .foregroundStyle(.secondary)

                    Text("\"\(wakeWord)\"")
                        .font(.body)

                    Spacer()
                }
            }
        }
    }

    // MARK: - Voice Output Section

    private var voiceOutputSection: some View {
        Group {
            Toggle("Read Responses Aloud", isOn: $settingsManager.readResponsesAloud)

            HStack {
                Text("Voice")
                Spacer()

                Button {
                    showingVoiceSelector = true
                } label: {
                    HStack {
                        Text(getVoiceName(for: selectedVoiceIdentifier))
                            .foregroundStyle(.primary)

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.bordered)
            }

            Divider()

            // Speech Rate
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Speech Rate")
                        .font(.subheadline)

                    Spacer()

                    Text("\(Int(config.speechRate * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Slider(value: $config.speechRate, in: 0.25 ... 1.0, step: 0.05)

                HStack {
                    Text("Slower")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("Faster")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Pitch
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Pitch")
                        .font(.subheadline)

                    Spacer()

                    Text(String(format: "%.1fx", config.pitchMultiplier))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Slider(value: $config.pitchMultiplier, in: 0.5 ... 2.0, step: 0.1)

                HStack {
                    Text("Lower")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("Higher")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Volume
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Volume")
                        .font(.subheadline)

                    Spacer()

                    Text("\(Int(config.volume * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Slider(value: $config.volume, in: 0.0 ... 1.0, step: 0.05)

                HStack {
                    Image(systemName: "speaker.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Image(systemName: "speaker.wave.3.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Speech Recognition Section

    private var speechRecognitionSection: some View {
        Group {
            Picker("Recognition Language", selection: $config.recognitionLanguage) {
                Text("English (US)").tag("en-US")
                Text("English (UK)").tag("en-GB")
                Text("English (Australia)").tag("en-AU")
                Text("Spanish (Spain)").tag("es-ES")
                Text("Spanish (Mexico)").tag("es-MX")
                Text("French").tag("fr-FR")
                Text("German").tag("de-DE")
                Text("Italian").tag("it-IT")
                Text("Portuguese (Brazil)").tag("pt-BR")
                Text("Japanese").tag("ja-JP")
                Text("Chinese (Simplified)").tag("zh-CN")
                Text("Korean").tag("ko-KR")
            }

            Toggle("On-Device Recognition Only", isOn: $config.requiresOnDeviceRecognition)

            Text("On-device recognition is faster and more private, but may be less accurate for complex speech.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            // Audio Buffer Size
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Audio Buffer Size")
                        .font(.subheadline)

                    Spacer()

                    Text("\(config.audioBufferSize) samples")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Picker("", selection: $config.audioBufferSize) {
                    Text("512 (Low latency)").tag(512)
                    Text("1024 (Balanced)").tag(1024)
                    Text("2048 (High quality)").tag(2048)
                    Text("4096 (Maximum quality)").tag(4096)
                }
                .pickerStyle(.segmented)

                Text("Larger buffer = better quality but higher latency")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Conversation Mode Section

    private var conversationModeSection: some View {
        Group {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Conversation Mode")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(voiceEngine.conversationMode ? "Active - Listening continuously" : "Inactive")
                        .font(.caption)
                        .foregroundStyle(voiceEngine.conversationMode ? .green : .secondary)
                }

                Spacer()

                Circle()
                    .fill(voiceEngine.conversationMode ? Color.green : Color.secondary.opacity(0.3))
                    .frame(width: 12, height: 12)
            }

            Divider()

            // Silence Threshold
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Silence Timeout")
                        .font(.subheadline)

                    Spacer()

                    Text(String(format: "%.1f seconds", config.silenceThresholdSeconds))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Slider(value: $config.silenceThresholdSeconds, in: 1.0 ... 5.0, step: 0.5)

                Text("Time of silence before exiting conversation mode")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Conversation Timeout
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Session Timeout")
                        .font(.subheadline)

                    Spacer()

                    Text("\(Int(config.conversationTimeoutSeconds)) seconds")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Slider(value: $config.conversationTimeoutSeconds, in: 15.0 ... 120.0, step: 5.0)

                Text("Maximum duration of a conversation session")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Audio Feedback Section

    private var audioFeedbackSection: some View {
        Group {
            Toggle("Activation Sound", isOn: $config.activationSoundEnabled)

            Text("Play a sound when wake word is detected")
                .font(.caption)
                .foregroundStyle(.secondary)

            if config.activationSoundEnabled {
                Picker("Sound Type", selection: $config.activationSoundID) {
                    Text("Tock").tag(UInt32(1054))
                    Text("Pop").tag(UInt32(1057))
                    Text("Morse").tag(UInt32(1058))
                    Text("Purr").tag(UInt32(1051))
                    Text("Typewriter").tag(UInt32(1306))
                }

                Button("Preview Sound") {
                    AudioServicesPlaySystemSound(config.activationSoundID)
                }
            }
        }
    }

    // MARK: - Advanced Section

    private var advancedSection: some View {
        Group {
            // Voice Assistant Model
            HStack {
                Text("Voice Assistant Model")
                Spacer()
                Text(config.voiceAssistantModel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TextField("Model ID", text: $config.voiceAssistantModel)
                .textFieldStyle(.roundedBorder)

            Text("The AI model used for voice assistant responses. Use a fast model for better responsiveness.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            // Speech Language (output)
            Picker("Speech Output Language", selection: $config.speechLanguage) {
                Text("English (US)").tag("en-US")
                Text("English (UK)").tag("en-GB")
                Text("English (Australia)").tag("en-AU")
                Text("Spanish").tag("es-ES")
                Text("French").tag("fr-FR")
                Text("German").tag("de-DE")
                Text("Italian").tag("it-IT")
                Text("Portuguese").tag("pt-BR")
                Text("Japanese").tag("ja-JP")
                Text("Chinese").tag("zh-CN")
                Text("Korean").tag("ko-KR")
            }

            Text("Language for text-to-speech output")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Test Section

    private var testSection: some View {
        Group {
            // Voice Test
            HStack {
                Button {
                    testVoice()
                } label: {
                    HStack {
                        if isTestingVoice {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "play.fill")
                        }
                        Text(isTestingVoice ? "Speaking..." : "Test Voice")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isTestingVoice)

                Button {
                    voiceEngine.stopSpeaking()
                    isTestingVoice = false
                } label: {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text("Stop")
                    }
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }

            Divider()

            // Wake Word Test
            Button {
                Task {
                    if voiceEngine.isListening {
                        voiceEngine.stopWakeWordDetection()
                    } else {
                        try? await voiceEngine.startWakeWordDetection()
                    }
                }
            } label: {
                HStack {
                    Image(systemName: voiceEngine.isListening ? "mic.slash.fill" : "mic.fill")
                    Text(voiceEngine.isListening ? "Stop Listening" : "Start Listening")
                }
            }
            .buttonStyle(.bordered)
            .tint(voiceEngine.isListening ? .red : .green)

            // Status
            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Processing", value: voiceEngine.isProcessing ? "Yes" : "No")
                LabeledContent("Conversation Mode", value: voiceEngine.conversationMode ? "Active" : "Inactive")
            }
            .font(.caption)
        }
    }

    // MARK: - Wake Word Editor Sheet

    private var wakeWordEditorSheet: some View {
        NavigationStack {
            List {
                Section("Current Wake Words") {
                    ForEach(config.wakeWords, id: \.self) { wakeWord in
                        HStack {
                            Text("\"\(wakeWord)\"")
                                .font(.body)

                            Spacer()
                        }
                    }
                    .onDelete { indexSet in
                        config.wakeWords.remove(atOffsets: indexSet)
                    }
                }

                Section("Add New Wake Word") {
                    HStack {
                        TextField("e.g., 'computer'", text: $newWakeWord)
                            .textFieldStyle(.roundedBorder)

                        Button {
                            addWakeWord()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                        }
                        .disabled(newWakeWord.trimmingCharacters(in: .whitespaces).isEmpty)
                    }

                    Text("Wake words should be 2-4 syllables for best recognition")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Tips") {
                    Label("Use unique, distinct phrases", systemImage: "lightbulb")
                        .font(.caption)

                    Label("Avoid common words that might trigger accidentally", systemImage: "exclamationmark.triangle")
                        .font(.caption)

                    Label("Test each wake word to ensure good recognition", systemImage: "checkmark.circle")
                        .font(.caption)
                }
            }
            .navigationTitle("Wake Words")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingWakeWordEditor = false
                    }
                }
            }
        }
        #if os(macOS)
        .frame(width: 500, height: 500)
        #endif
    }

    // MARK: - Voice Selector Sheet

    private var voiceSelectorSheet: some View {
        NavigationStack {
            List {
                ForEach(groupedVoices.keys.sorted(), id: \.self) { language in
                    Section(language) {
                        ForEach(groupedVoices[language] ?? [], id: \.identifier) { voice in
                            Button {
                                selectedVoiceIdentifier = voice.identifier
                                config.speechLanguage = voice.language
                                showingVoiceSelector = false
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(voice.name)
                                            .font(.body)
                                            .foregroundStyle(.primary)

                                        Text(voice.language)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    if voice.identifier == selectedVoiceIdentifier {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }

                                    if voice.quality == .enhanced {
                                        Text("Enhanced")
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.purple.opacity(0.2))
                                            .foregroundStyle(.purple)
                                            .cornerRadius(4)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Select Voice")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingVoiceSelector = false
                    }
                }
            }
        }
        #if os(macOS)
        .frame(width: 500, height: 600)
        #endif
    }

    // MARK: - Helper Methods

    private func loadAvailableVoices() {
        availableVoices = AVSpeechSynthesisVoice.speechVoices()
    }

    private var groupedVoices: [String: [AVSpeechSynthesisVoice]] {
        Dictionary(grouping: availableVoices) { voice in
            Locale(identifier: voice.language).localizedString(forIdentifier: voice.language) ?? voice.language
        }
    }

    private func getVoiceName(for identifier: String) -> String {
        if let voice = availableVoices.first(where: { $0.identifier == identifier }) {
            return voice.name
        }
        // Try to match by language
        if let voice = availableVoices.first(where: { $0.language == identifier }) {
            return voice.name
        }
        return "Default"
    }

    private func addWakeWord() {
        let trimmed = newWakeWord.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty, !config.wakeWords.contains(trimmed) else { return }
        config.wakeWords.append(trimmed)
        newWakeWord = ""
    }

    func testVoice() {
        isTestingVoice = true
        Task {
            await voiceEngine.speak("Hello! I'm Thea, your AI assistant. This is a test of the current voice settings.", rate: config.speechRate)
            await MainActor.run {
                isTestingVoice = false
            }
        }
    }

    private func saveConfig() {
        AppConfiguration.shared.voiceConfig = config
        voiceEngine.updateConfiguration()
    }

    private func resetToDefaults() {
        config = VoiceConfiguration()
        saveConfig()
    }
}

// MARK: - Preview

#if os(macOS)
#Preview {
    VoiceSettingsView()
        .frame(width: 700, height: 900)
}
#else
#Preview {
    NavigationStack {
        VoiceSettingsView()
            .navigationTitle("Voice")
    }
}
#endif
