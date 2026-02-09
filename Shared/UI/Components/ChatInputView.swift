import SwiftUI
import UniformTypeIdentifiers

// Debug logging for ChatInputView
private func inputLog(_ msg: String) {
    #if os(macOS)
    let logFile = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Desktop/thea_debug.log")
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let line = "[\(timestamp)] [ChatInputView] \(msg)\n"
    if let data = line.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: logFile.path) {
            if let handle = try? FileHandle(forUpdating: logFile) {
                _ = try? handle.seekToEnd()
                _ = try? handle.write(contentsOf: data)
                try? handle.close()
            }
        } else {
            try? data.write(to: logFile)
        }
    }
    #else
    // On iOS/watchOS/tvOS, use os.log instead
    print("[ChatInputView] \(msg)")
    #endif
}

struct ChatInputView: View {
    @Binding var text: String
    let isStreaming: Bool
    let onSend: () -> Void
    var onVoiceToggle: (() -> Void)?
    var isListening: Bool = false

    @FocusState private var isFocused: Bool
    @State private var selectedModel = AppConfiguration.shared.providerConfig.defaultModel
    @State private var showingScreenshotPreview = false
    @State private var capturedImage: CGImage?
    @State private var showingFilePicker = false
    @State private var attachmentManager = FileAttachmentManager.shared
    @State private var dragOver = false

    // Phase B: Slash commands & mentions overlay state
    #if os(macOS) || os(iOS)
    @State private var showMentionOverlay = false
    @State private var mentionQuery = ""
    #endif

    var body: some View {
        VStack(spacing: 8) {
            // Attachment preview bar
            if !attachmentManager.attachments.isEmpty {
                attachmentPreviewBar
            }

            // Slash command overlay (above input)
            #if os(macOS) || os(iOS)
            SlashCommandOverlay(inputText: $text) { command in
                handleSlashCommand(command)
            }
            .padding(.horizontal, TheaSpacing.lg)

            // Mention overlay (above input)
            if showMentionOverlay {
                MentionAutocompleteView(
                    query: mentionQuery,
                    onSelect: { item in handleMentionSelect(item) },
                    onDismiss: { showMentionOverlay = false }
                )
                .padding(.horizontal, TheaSpacing.lg)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            #endif

            // Model selector + character counter
            HStack {
                CompactModelSelectorView(
                    selectedModel: $selectedModel
                )
                .onChange(of: selectedModel) { _, newValue in
                    var providerConfig = AppConfiguration.shared.providerConfig
                    providerConfig.defaultModel = newValue
                    AppConfiguration.shared.providerConfig = providerConfig
                }

                Spacer()

                // Character counter
                if !text.isEmpty {
                    characterCounter
                }

                // Attachment count badge
                if !attachmentManager.attachments.isEmpty {
                    Text("\(attachmentManager.attachments.count) files")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.theaPrimary.opacity(0.2))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 16)

            // Input row
            HStack(alignment: .bottom, spacing: TheaSpacing.md) {
                // Attach file button
                Button(action: { showingFilePicker = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: TheaSize.iconLarge))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Attach Files")
                .accessibilityLabel("Attach files")
                .accessibilityHint("Opens file picker to attach documents")
                .disabled(isStreaming)

                #if os(macOS)
                    Button(action: captureScreenshot) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: TheaSize.iconMedium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Capture Screenshot")
                    .accessibilityLabel("Capture screenshot")
                    .accessibilityHint("Takes a screenshot to attach to your message")
                    .disabled(isStreaming)
                #endif

                // Text input — use TheaTextInputField on macOS for configurable shortcuts
                #if os(macOS)
                TheaTextInputField(
                    text: $text,
                    placeholder: "Message Thea...",
                    isFocused: _isFocused,
                    isDisabled: isStreaming,
                    dragOver: dragOver,
                    onSubmit: {
                        inputLog("onSubmit triggered via TheaTextInputField")
                        if canSend {
                            onSend()
                        }
                    },
                    onPasteImage: { imageData in
                        handlePastedImage(imageData)
                    }
                )
                .frame(minHeight: 36, maxHeight: 200)
                .onDrop(of: [.fileURL, .image, .text], isTargeted: $dragOver) { providers in
                    handleDrop(providers: providers)
                    return true
                }
                #else
                // iOS/watchOS/tvOS: standard TextField
                HStack(alignment: .bottom, spacing: TheaSpacing.sm) {
                    TextField("Message Thea...", text: $text, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1 ... 8)
                        .focused($isFocused)
                        .disabled(isStreaming)
                        .onSubmit {
                            inputLog("onSubmit triggered")
                            if canSend {
                                onSend()
                            }
                        }
                }
                .padding(.horizontal, TheaSpacing.lg)
                .padding(.vertical, TheaSpacing.md)
                .liquidGlassRounded(cornerRadius: TheaCornerRadius.xl)
                #endif

                // Microphone button (inline voice input)
                if let onVoiceToggle {
                    Button {
                        onVoiceToggle()
                    } label: {
                        Image(systemName: isListening ? "mic.fill" : "mic")
                            .font(.system(size: TheaSize.iconMedium))
                            .foregroundStyle(isListening ? .red : .secondary)
                            .symbolEffect(.bounce, value: isListening)
                    }
                    .buttonStyle(.plain)
                    .help(isListening ? "Stop listening" : "Voice input")
                    .accessibilityLabel(isListening ? "Stop voice input" : "Start voice input")
                    .accessibilityHint("Activates microphone for voice dictation")
                    .disabled(isStreaming)
                }

                // Send / Stop button
                Button {
                    inputLog("Send button pressed")
                    onSend()
                } label: {
                    Image(systemName: isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(canSend || isStreaming ? Color.theaPrimaryDefault : .secondary)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .disabled(!canSend && !isStreaming)
                .accessibilityLabel(isStreaming ? "Stop generating" : "Send message")
                .accessibilityHint(isStreaming ? "Stops the AI response" : "Sends your message to the AI")
            }
            .padding(.horizontal, TheaSpacing.lg)
        }
        .padding(.vertical, TheaSpacing.md)
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.item], // Allow all file types
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
        .onAppear {
            isFocused = true
            selectedModel = AppConfiguration.shared.providerConfig.defaultModel
        }
        #if os(macOS) || os(iOS)
        .onChange(of: text) { _, newValue in
            updateOverlayState(newValue)
        }
        #endif
        #if os(macOS)
        .sheet(isPresented: $showingScreenshotPreview) {
            if let image = capturedImage {
                ScreenshotPreview(
                    image: NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height)),
                    onSend: sendScreenshot
                ) { showingScreenshotPreview = false }
            }
        }
        #endif
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !attachmentManager.attachments.isEmpty
    }

    // MARK: - Character Counter

    private var characterCounter: some View {
        let count = text.count
        let color: Color = count > 10_000 ? .red : (count > 5_000 ? .orange : .secondary)
        return Text("\(count)")
            .font(.caption2.monospacedDigit())
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .accessibilityLabel("\(count) characters typed")
    }

    // MARK: - Slash Command Handling

    #if os(macOS) || os(iOS)
    private func handleSlashCommand(_ command: SlashCommand) {
        // Replace the "/" prefix with the command text and a trailing space
        text = "/\(command.name) "
        inputLog("Slash command selected: /\(command.name)")
    }

    // MARK: - Mention Handling

    private func handleMentionSelect(_ item: MentionItem) {
        // Replace the @query with the mention reference
        if let atRange = text.range(of: "@", options: .backwards) {
            text = String(text[text.startIndex..<atRange.lowerBound]) + "@\(item.name) "
        }
        showMentionOverlay = false
        inputLog("Mention selected: @\(item.name)")
    }

    // MARK: - Overlay State Management

    private func updateOverlayState(_ newText: String) {
        // Check for @mention trigger
        if let lastAt = newText.lastIndex(of: "@") {
            let afterAt = String(newText[newText.index(after: lastAt)...])
            // Only show if the @ is preceded by whitespace or is at the start
            let beforeAt = lastAt == newText.startIndex
                || newText[newText.index(before: lastAt)].isWhitespace
            if beforeAt && !afterAt.contains(" ") {
                mentionQuery = afterAt
                showMentionOverlay = true
                return
            }
        }
        showMentionOverlay = false
    }
    #endif

    // MARK: - Image Paste Handling

    private func handlePastedImage(_ imageData: Data) {
        // Convert pasted image data to a file attachment
        Task {
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "pasted-image-\(UUID().uuidString.prefix(8)).png"
            let tempURL = tempDir.appendingPathComponent(fileName)
            do {
                try imageData.write(to: tempURL)
                try await attachmentManager.addAttachment(from: tempURL)
                inputLog("Pasted image attached: \(fileName)")
            } catch {
                inputLog("Failed to attach pasted image: \(error)")
            }
        }
    }

    // MARK: - Attachment Preview Bar

    private var attachmentPreviewBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(attachmentManager.attachments) { attachment in
                    AttachmentChip(attachment: attachment) {
                        attachmentManager.removeAttachment(id: attachment.id)
                    }
                }

                // Clear all button
                if attachmentManager.attachments.count > 1 {
                    Button {
                        attachmentManager.clearAllAttachments()
                    } label: {
                        Label("Clear All", systemImage: "xmark.circle.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 44)
    }

    // MARK: - File Handling

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            Task {
                for url in urls {
                    // Access security-scoped resource
                    guard url.startAccessingSecurityScopedResource() else { continue }
                    defer { url.stopAccessingSecurityScopedResource() }

                    do {
                        try await attachmentManager.addAttachment(from: url)
                    } catch {
                        inputLog("Failed to attach file: \(error)")
                    }
                }
            }
        case .failure(let error):
            inputLog("File picker error: \(error)")
        }
    }

    #if os(macOS)
    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                    guard let data = data as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else { return }

                    Task { @MainActor in
                        do {
                            try await attachmentManager.addAttachment(from: url)
                        } catch {
                            inputLog("Drop attachment failed: \(error)")
                        }
                    }
                }
            }
        }
    }
    #endif

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

// MARK: - Attachment Chip

struct AttachmentChip: View {
    let attachment: FileAttachment
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: attachment.fileType.systemImage)
                .foregroundStyle(.theaPrimary)

            VStack(alignment: .leading, spacing: 0) {
                Text(attachment.name)
                    .font(.caption)
                    .lineLimit(1)
                Text(attachment.formattedSize)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(attachment.name)")
        }
        .padding(.horizontal, TheaSpacing.md)
        .padding(.vertical, TheaSpacing.sm)
        .background(Color.theaSurface)
        .clipShape(RoundedRectangle(cornerRadius: TheaCornerRadius.sm))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Attached file: \(attachment.name), \(attachment.formattedSize)")
    }
}

#Preview {
    VStack {
        Spacer()
        ChatInputView(text: .constant(""), isStreaming: false) {
            print("Send")
        }
    }
}
