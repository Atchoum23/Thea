import SwiftUI

struct VoiceSettingsView: View {
    @State private var voiceEngine = VoiceActivationEngine.shared
    @State private var isWakeWordEnabled = true
    @State private var selectedVoice = "Samantha"
    @State private var speechRate: Double = 0.5

    var body: some View {
        Form {
            Section("Voice Activation") {
                Toggle("Enable \"Hey Thea\"", isOn: $isWakeWordEnabled)
                    .onChange(of: isWakeWordEnabled) { _, enabled in
                        Task {
                            if enabled {
                                try? await voiceEngine.startWakeWordDetection()
                            } else {
                                voiceEngine.stopWakeWordDetection()
                            }
                        }
                    }

                if isWakeWordEnabled {
                    HStack {
                        Image(systemName: voiceEngine.isListening ? "mic.fill" : "mic.slash.fill")
                            .foregroundStyle(voiceEngine.isListening ? .green : .secondary)

                        Text(voiceEngine.isListening ? "Listening..." : "Not listening")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Voice Settings") {
                Picker("Voice", selection: $selectedVoice) {
                    Text("Samantha").tag("Samantha")
                    Text("Alex").tag("Alex")
                    Text("Victoria").tag("Victoria")
                }

                VStack(alignment: .leading) {
                    Text("Speech Rate")
                        .font(.caption)

                    Slider(value: $speechRate, in: 0.25 ... 1.0)

                    HStack {
                        Text("Slow")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text("Fast")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Conversation Mode") {
                Toggle("Auto-enable after wake word", isOn: .constant(true))

                HStack {
                    Text("Silence timeout")
                    Spacer()
                    Text("2 seconds")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Status") {
                LabeledContent("Conversation Mode", value: voiceEngine.conversationMode ? "Active" : "Inactive")
                LabeledContent("Last Transcript", value: voiceEngine.lastTranscript.isEmpty ? "None" : voiceEngine.lastTranscript)
            }

            Section {
                Button("Test Voice") {
                    Task {
                        await voiceEngine.speak("Hello! I'm Thea, your AI companion.")
                    }
                }

                Button("Stop Speaking") {
                    voiceEngine.stopSpeaking()
                }
                .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Voice Settings")
    }
}

#Preview {
    NavigationStack {
        VoiceSettingsView()
    }
}
