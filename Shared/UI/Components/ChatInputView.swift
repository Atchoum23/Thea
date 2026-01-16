import SwiftUI

struct ChatInputView: View {
    @Binding var text: String
    let isStreaming: Bool
    let onSend: () -> Void

    @FocusState private var isFocused: Bool
    @State private var selectedModel = AppConfiguration.shared.providerConfig.defaultModel
    @State private var showingScreenshotPreview = false
    @State private var capturedImage: CGImage?

    var body: some View {
        VStack(spacing: 8) {
            // Model selector
            HStack {
                CompactModelSelectorView(
                    selectedModel: $selectedModel,
                    availableModels: ["GPT-4", "GPT-3.5", "Claude 3", "Gemini Pro", "Llama 3"]
                )
                    .onChange(of: selectedModel) { _, newValue in
                        var providerConfig = AppConfiguration.shared.providerConfig
                        providerConfig.defaultModel = newValue
                        AppConfiguration.shared.providerConfig = providerConfig
                    }

                Spacer()
            }
            .padding(.horizontal, 16)

            // Input row
            HStack(alignment: .bottom, spacing: 12) {
                // Screenshot button
                #if os(macOS)
                Button(action: captureScreenshot) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 20))
                        .foregroundColor(.theaPrimary)
                }
                .buttonStyle(.plain)
                .help("Capture Screenshot")
                .disabled(isStreaming)
                #endif
                
                // Text input
                TextField("Message THEA...", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    #if os(macOS)
                    .background(Color(nsColor: .systemGray))
                    #else
                    .background(Color(uiColor: .systemGray6))
                    #endif
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .lineLimit(1...10)
                    .focused($isFocused)
                    .disabled(isStreaming)
                    .onSubmit {
                        if !text.isEmpty {
                            onSend()
                        }
                    }

                // Send button
                Button {
                    onSend()
                } label: {
                    Image(systemName: isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(canSend ? Color.theaPrimary : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(!canSend && !isStreaming)
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 12)
        .onAppear {
            isFocused = true
            selectedModel = AppConfiguration.shared.providerConfig.defaultModel
        }
        #if os(macOS)
        .sheet(isPresented: $showingScreenshotPreview) {
            if let image = capturedImage {
                ScreenshotPreview(
                    image: NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height)),
                    onSend: sendScreenshot
                )                    { showingScreenshotPreview = false }
            }
        }
        #endif
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Screenshot Handling
    
    #if os(macOS)
    private func captureScreenshot() {
        Task {
            do {
                let cgImage = try await ScreenCapture.shared.captureScreen()
                capturedImage = cgImage
                showingScreenshotPreview = true
            } catch {
                print("Screenshot capture failed: \(error)")
            }
        }
    }
    
    private func sendScreenshot() {
        // Add screenshot to chat (would need image message support)
        text = "[Screenshot attached] " + text
        showingScreenshotPreview = false
        capturedImage = nil
        onSend()
    }
    #endif
}

#Preview {
    VStack {
        Spacer()
        ChatInputView(text: .constant(""), isStreaming: false) {
            print("Send")
        }
    }
}
