import SwiftUI

#if os(macOS)
    import AppKit

    // MARK: - Screenshot Preview

    // Preview and send screenshot to chat

    struct ScreenshotPreview: View {
        let image: NSImage
        let onSend: () -> Void
        let onCancel: () -> Void

        @State private var annotation = ""

        var body: some View {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Text("Screenshot Captured")
                        .font(.theaHeadline)

                    Spacer()

                    Button(action: onCancel) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Cancel screenshot")
                }

                // Image preview
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 400)
                    .cornerRadius(8)
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)

                // Image info
                HStack {
                    Label("\(Int(image.size.width)) × \(Int(image.size.height))", systemImage: "photo")
                        .font(.theaCaption1)
                        .foregroundColor(.secondary)

                    Spacer()
                }

                // Annotation field
                VStack(alignment: .leading, spacing: 4) {
                    Text("Add context (optional)")
                        .font(.theaCaption1)
                        .foregroundColor(.secondary)

                    TextField("Describe what you'd like help with...", text: $annotation, axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Color.controlBackground)
                        .cornerRadius(6)
                        .lineLimit(1 ... 5)
                }

                // Actions
                HStack(spacing: 12) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .keyboardShortcut(.escape)

                    Spacer()

                    Button("Send to Chat") {
                        onSend()
                    }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
                    .tint(.theaPrimary)
                }
            }
            .padding(20)
            .frame(width: 500)
            .background(Color.windowBackground)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        }
    }

    #Preview {
        ScreenshotPreview(
            image: NSImage(systemSymbolName: "photo", accessibilityDescription: nil)!,
            onSend: { print("Send") },
            onCancel: { print("Cancel") }
        )
    }

#endif
