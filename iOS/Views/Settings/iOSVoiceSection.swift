import SwiftUI

struct iOSVoiceSettingsView: View {
    @State private var voiceManager = VoiceActivationManager.shared
    @State private var customWakeWord = ""

    var body: some View {
        Form {
            Section {
                Toggle("Voice Activation", isOn: $voiceManager.isEnabled)
            } footer: {
                Text("Enable voice activation to use wake word detection")
            }

            if voiceManager.isEnabled {
                Section {
                    TextField("Wake Word", text: $customWakeWord)
                        .onSubmit {
                            voiceManager.wakeWord = customWakeWord
                        }
                } header: {
                    Text("Wake Word")
                } footer: {
                    Text("Say this phrase to activate THEA. Default is 'Hey Thea'")
                }

                Section {
                    Toggle("Conversation Mode", isOn: $voiceManager.conversationMode)
                } footer: {
                    Text("Keep listening after responding, allowing natural back-and-forth conversation")
                }

                Section {
                    if voiceManager.isListening {
                        HStack {
                            ProgressView()
                            Text("Listening...")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Button("Test Wake Word") {
                            testWakeWord()
                        }
                    }
                }
            }
        }
        .navigationTitle("Voice Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            customWakeWord = voiceManager.wakeWord
        }
    }

    func testWakeWord() {
        do {
            try voiceManager.startWakeWordDetection()
        } catch {
            print("Failed to start wake word detection: \(error)")
        }
    }
}
