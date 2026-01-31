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

    @FocusState private var isFocused: Bool
    @State private var selectedModel = AppConfiguration.shared.providerConfig.defaultModel
    @State private var showingScreenshotPreview = false
    @State private var capturedImage: CGImage?
    @State private var showingFilePicker = false
    @State private var attachmentManager = FileAttachmentManager.shared
    @State private var dragOver = false

    var body: some View {
        VStack(spacing: 8) {
            // Attachment preview bar
            if !attachmentManager.attachments.isEmpty {
                attachmentPreviewBar
            }

            // Model selector
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
            HStack(alignment: .bottom, spacing: 12) {
                // Attach file button
                Button(action: { showingFilePicker = true }) {
                    Image(systemName: "paperclip")
                        .font(.system(size: 20))
                        .foregroundColor(.theaPrimary)
                }
                .buttonStyle(.plain)
                .help("Attach Files")
                .disabled(isStreaming)

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

                // Text input with drop support
                TextField("Message THEA...", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                #if os(macOS)
                    .background(dragOver ? Color.theaPrimary.opacity(0.2) : Color(nsColor: .systemGray))
                #else
                    .background(Color(uiColor: .systemGray6))
                #endif
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .lineLimit(1 ... 10)
                    .focused($isFocused)
                    .disabled(isStreaming)
                    .onSubmit {
                        inputLog("⏎ onSubmit triggered! text='\(text.prefix(30))...', isEmpty=\(text.isEmpty)")
                        if !text.isEmpty || !attachmentManager.attachments.isEmpty {
                            inputLog("✅ Calling onSend from onSubmit")
                            onSend()
                        }
                    }
                #if os(macOS)
                    .onDrop(of: [.fileURL, .image, .text], isTargeted: $dragOver) { providers in
                        handleDrop(providers: providers)
                        return true
                    }
                #endif

                // Send button
                Button {
                    inputLog("🔘 Send button pressed! text='\(text.prefix(30))...', canSend=\(canSend), isStreaming=\(isStreaming)")
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
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, error in
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
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        #if os(macOS)
        .background(Color(nsColor: .systemGray).opacity(0.5))
        #else
        .background(Color(uiColor: .systemGray5))
        #endif
        .cornerRadius(8)
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
