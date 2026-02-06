//
//  TheaTextInputField.swift
//  Thea
//
//  Custom text input field with:
//  - Configurable submit shortcuts (Enter, Cmd+Enter, Shift+Enter)
//  - Clipboard image paste support
//  - Rich text paste handling
//

import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Thea Text Input Field

struct TheaTextInputField: View {
    @Binding var text: String
    let placeholder: String
    @FocusState var isFocused: Bool
    let isDisabled: Bool
    let dragOver: Bool
    let onSubmit: () -> Void
    let onPasteImage: ((Data) -> Void)?

    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        #if os(macOS)
        TheaMacTextInputField(
            text: $text,
            placeholder: placeholder,
            isDisabled: isDisabled,
            dragOver: dragOver,
            submitShortcut: settings.submitShortcut,
            onSubmit: onSubmit,
            onPasteImage: onPasteImage
        )
        #else
        // iOS/tvOS/watchOS: Use standard TextField
        TextField(placeholder, text: $text, axis: .vertical)
            .textFieldStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(dragOver ? TheaBrandColors.gold.opacity(0.15) : .clear)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isFocused
                            ? TheaBrandColors.gold.opacity(0.5)
                            : Color.clear,
                        lineWidth: 1.5
                    )
            )
            .lineLimit(1 ... 10)
            .focused($isFocused)
            .disabled(isDisabled)
            .accessibilityLabel("Message input")
            .accessibilityHint("Type your message to THEA. Press Return to send.")
            .onSubmit {
                onSubmit()
            }
        #endif
    }
}

// MARK: - macOS Implementation with NSTextView

#if os(macOS)
struct TheaMacTextInputField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let isDisabled: Bool
    let dragOver: Bool
    let submitShortcut: String
    let onSubmit: () -> Void
    let onPasteImage: ((Data) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = TheaNSTextView()
        textView.delegate = context.coordinator
        textView.coordinator = context.coordinator
        textView.isEditable = !isDisabled
        textView.isSelectable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.textColor = NSColor.labelColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 12, height: 8)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        scrollView.documentView = textView
        context.coordinator.textView = textView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? TheaNSTextView else { return }

        // Update text if changed externally
        if textView.string != text {
            textView.string = text
        }

        textView.isEditable = !isDisabled

        // Update coordinator
        context.coordinator.submitShortcut = submitShortcut
        context.coordinator.onSubmit = onSubmit
        context.coordinator.onPasteImage = onPasteImage
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: TheaMacTextInputField
        var textView: TheaNSTextView?
        var submitShortcut: String
        var onSubmit: () -> Void
        var onPasteImage: ((Data) -> Void)?

        init(_ parent: TheaMacTextInputField) {
            self.parent = parent
            self.submitShortcut = parent.submitShortcut
            self.onSubmit = parent.onSubmit
            self.onPasteImage = parent.onPasteImage
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }

        /// Handle key events for submit shortcuts
        func handleKeyDown(_ event: NSEvent) -> Bool {
            let isEnter = event.keyCode == 36 // Return key
            let isShiftPressed = event.modifierFlags.contains(.shift)
            let isCmdPressed = event.modifierFlags.contains(.command)

            guard isEnter else { return false }

            switch submitShortcut {
            case "enter":
                // Enter sends, Shift+Enter for newline
                if isShiftPressed {
                    // Insert newline
                    textView?.insertNewline(nil)
                    return true
                } else if !isCmdPressed {
                    // Send
                    onSubmit()
                    return true
                }

            case "cmdEnter":
                // Cmd+Enter sends, Enter for newline
                if isCmdPressed && !isShiftPressed {
                    onSubmit()
                    return true
                }
                // Let Enter insert newline normally

            case "shiftEnter":
                // Shift+Enter sends, Enter for newline
                if isShiftPressed && !isCmdPressed {
                    onSubmit()
                    return true
                }
                // Let Enter insert newline normally

            default:
                // Default: Enter sends
                if !isShiftPressed && !isCmdPressed {
                    onSubmit()
                    return true
                }
            }

            return false
        }

        /// Handle paste with image detection
        func handlePaste() -> Bool {
            let pasteboard = NSPasteboard.general

            // Check for image data
            if let imageTypes = pasteboard.types?.filter({ $0 == .tiff || $0 == .png }) {
                if let imageType = imageTypes.first,
                   let imageData = pasteboard.data(forType: imageType) {
                    onPasteImage?(imageData)
                    return true
                }
            }

            // Check for file URLs that are images
            if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] {
                for url in urls {
                    let ext = url.pathExtension.lowercased()
                    if ["png", "jpg", "jpeg", "gif", "webp", "heic"].contains(ext) {
                        if let imageData = try? Data(contentsOf: url) {
                            onPasteImage?(imageData)
                            return true
                        }
                    }
                }
            }

            return false // Let default paste handle text
        }
    }
}

// MARK: - Custom NSTextView for keyboard handling

class TheaNSTextView: NSTextView {
    weak var coordinator: TheaMacTextInputField.Coordinator?

    override func keyDown(with event: NSEvent) {
        if coordinator?.handleKeyDown(event) == true {
            return
        }
        super.keyDown(with: event)
    }

    override func paste(_ sender: Any?) {
        // Try to handle image paste first
        if coordinator?.handlePaste() == true {
            return
        }
        // Fall back to default paste
        super.paste(sender)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Handle Cmd+V for paste
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "v" {
            if coordinator?.handlePaste() == true {
                return true
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}
#endif

// MARK: - Queued Message Chip

struct QueuedMessageChip: View {
    let message: QueuedMessage
    let index: Int
    let onEdit: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text("\(index)")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.orange))

            Text(message.text)
                .font(.caption)
                .lineLimit(1)
                .frame(maxWidth: 150)

            if !message.attachments.isEmpty {
                Image(systemName: "paperclip")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Button {
                onEdit()
            } label: {
                Image(systemName: "pencil")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Preview

private struct TheaTextInputFieldPreview: View {
    @State private var text = "Hello THEA"
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack {
            Spacer()
            TheaTextInputField(
                text: $text,
                placeholder: "Message THEA...",
                isFocused: _isFocused,
                isDisabled: false,
                dragOver: false,
                onSubmit: { print("Submit") },
                onPasteImage: { _ in print("Image pasted") }
            )
            .frame(height: 100)
            .padding()
        }
    }
}

#Preview {
    TheaTextInputFieldPreview()
}
