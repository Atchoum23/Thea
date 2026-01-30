//
//  QuickEntryWindow.swift
//  Thea
//
//  Quick Entry window that appears on Option+Option double-tap
//  Inspired by Claude Desktop's Quick Entry feature
//

#if os(macOS)
    import AppKit
    import SwiftUI

    // MARK: - Quick Entry Window Controller

    /// Controller for the Quick Entry floating window
    class QuickEntryWindowController: NSWindowController {
        static let shared = QuickEntryWindowController()

        private var lastOptionPressTime: Date?
        private var eventMonitor: Any?

        private init() {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 120),
                styleMask: [.borderless, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )

            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = .floating
            window.hasShadow = true
            window.isMovableByWindowBackground = true
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

            super.init(window: window)

            let contentView = QuickEntryView(
                onSubmit: { [weak self] text in
                    self?.handleSubmit(text)
                },
                onDismiss: { [weak self] in
                    self?.dismiss()
                }
            )

            window.contentView = NSHostingView(rootView: contentView)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        // MARK: - Global Hotkey Setup

        /// Start monitoring for Option+Option double-tap
        func startMonitoring() {
            eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
                self?.handleFlagsChanged(event)
            }
        }

        /// Stop monitoring
        func stopMonitoring() {
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
                eventMonitor = nil
            }
        }

        private func handleFlagsChanged(_ event: NSEvent) {
            // Check if Option key was pressed
            guard event.modifierFlags.contains(.option) else {
                return
            }

            let now = Date()

            if let lastPress = lastOptionPressTime,
               now.timeIntervalSince(lastPress) < 0.4
            {
                // Double-tap detected
                DispatchQueue.main.async { [weak self] in
                    self?.toggle()
                }
                lastOptionPressTime = nil
            } else {
                lastOptionPressTime = now
            }
        }

        // MARK: - Window Management

        func toggle() {
            if window?.isVisible == true {
                dismiss()
            } else {
                show()
            }
        }

        func show() {
            guard let window, let screen = NSScreen.main else { return }

            // Center horizontally, position near top of screen
            let screenFrame = screen.visibleFrame
            let windowFrame = window.frame
            let x = screenFrame.midX - windowFrame.width / 2
            let y = screenFrame.maxY - windowFrame.height - 100

            window.setFrameOrigin(NSPoint(x: x, y: y))

            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)

            // Post notification to focus the text field
            NotificationCenter.default.post(name: .quickEntryDidShow, object: nil)
        }

        func dismiss() {
            window?.orderOut(nil)
        }

        private func handleSubmit(_ text: String) {
            dismiss()

            // Send the text to the main chat
            NotificationCenter.default.post(
                name: .quickEntrySubmit,
                object: text
            )
        }
    }

    // MARK: - Quick Entry View

    struct QuickEntryView: View {
        let onSubmit: (String) -> Void
        let onDismiss: () -> Void

        @State private var inputText = ""
        @State private var attachedScreenshot: NSImage?
        @FocusState private var isFocused: Bool

        var body: some View {
            VStack(spacing: 0) {
                // Main input area
                HStack(spacing: 12) {
                    // Thea icon
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.theaPrimaryDefault)

                    // Text field
                    TextField("Ask THEA anything...", text: $inputText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                        .focused($isFocused)
                        .onSubmit {
                            submitIfNotEmpty()
                        }

                    // Screenshot button
                    Button {
                        captureScreenshot()
                    } label: {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Capture screenshot")

                    // Send button
                    Button {
                        submitIfNotEmpty()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(inputText.isEmpty ? .secondary : Color.theaPrimaryDefault)
                    }
                    .buttonStyle(.plain)
                    .disabled(inputText.isEmpty)
                }
                .padding(16)

                // Screenshot preview (if attached)
                if let screenshot = attachedScreenshot {
                    Divider()
                    HStack {
                        Image(nsImage: screenshot)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        Spacer()

                        Button {
                            attachedScreenshot = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }

                // Hint bar
                HStack {
                    Text("↵ Send")
                    Text("•")
                    Text("⎋ Dismiss")
                    Text("•")
                    Text("⌥⌥ Toggle")
                }
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            .background(.ultraThickMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
            .onReceive(NotificationCenter.default.publisher(for: .quickEntryDidShow)) { _ in
                isFocused = true
            }
            .onKeyPress(.escape) {
                onDismiss()
                return .handled
            }
        }

        private func submitIfNotEmpty() {
            let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }

            onSubmit(trimmed)
            inputText = ""
            attachedScreenshot = nil
        }

        private func captureScreenshot() {
            // Note: In a full implementation, use ScreenCaptureKit for modern screenshot capture
            // For now, show a placeholder indicating the feature
            // TODO: Implement using SCStreamConfiguration and SCShareableContent

            // Create a placeholder image to indicate screenshot capture
            let size = NSSize(width: 200, height: 100)
            let image = NSImage(size: size)
            image.lockFocus()
            NSColor.systemGray.setFill()
            NSRect(origin: .zero, size: size).fill()
            let text = "Screenshot"
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.white,
                .font: NSFont.systemFont(ofSize: 14)
            ]
            text.draw(at: NSPoint(x: 70, y: 42), withAttributes: attrs)
            image.unlockFocus()
            attachedScreenshot = image
        }
    }

    // MARK: - Notification Names

    extension Notification.Name {
        static let quickEntryDidShow = Notification.Name("quickEntryDidShow")
        static let quickEntrySubmit = Notification.Name("quickEntrySubmit")
    }

    // MARK: - Preview

    #Preview {
        QuickEntryView(
            onSubmit: { print("Submit: \($0)") },
            onDismiss: { print("Dismiss") }
        )
        .frame(width: 600)
        .padding()
    }
#endif
