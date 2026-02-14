import SwiftUI

// MARK: - API Key Setup View

struct APIKeySetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("To use THEA's chat features, you need to add an OpenAI API key.")
                        .font(.theaCaption1)
                        .foregroundStyle(.secondary)
                }

                Section("API Key") {
                    SecureField("Enter your OpenAI API key", text: $apiKey)

                    if let url = URL(string: "https://platform.openai.com/api-keys") {
                        Link("Get API Key →", destination: url)
                            .font(.theaCaption1)
                    }
                }

                Section {
                    Button("Save API Key") {
                        saveAPIKey()
                    }
                    .disabled(apiKey.isEmpty)
                    .frame(maxWidth: .infinity)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Setup API Key")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        #if os(macOS)
        .frame(width: 450, height: 300)
        #endif
    }

    private func saveAPIKey() {
        Task {
            do {
                try SecureStorage.shared.saveAPIKey(apiKey, for: "openai")
                dismiss()
            } catch {
                print("Failed to save API key: \(error)")
            }
        }
    }
}
