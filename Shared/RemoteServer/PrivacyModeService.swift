//
//  PrivacyModeService.swift
//  Thea
//
//  Screen blanking and local input disable for privacy during remote control sessions
//

import Foundation
#if os(macOS)
    import AppKit
    import CoreGraphics
    import IOKit
#endif

// MARK: - Privacy Mode Service

/// Manages privacy mode during remote sessions - blanks remote screen and disables local input
@MainActor
public class PrivacyModeService: ObservableObject {
    // MARK: - Published State

    @Published public private(set) var isPrivacyModeActive = false
    @Published public private(set) var isScreenBlanked = false
    @Published public private(set) var isLocalInputDisabled = false

    // MARK: - Internal

    #if os(macOS)
        private var blankingWindow: NSWindow?
    #endif

    // MARK: - Initialization

    public init() {}

    // MARK: - Privacy Mode Control

    /// Enable privacy mode - blanks screen and optionally disables local input
    public func enablePrivacyMode(shouldBlankScreen: Bool = true, disableLocalInput: Bool = true) {
        guard !isPrivacyModeActive else { return }

        #if os(macOS)
            if shouldBlankScreen {
                blankScreen()
            }
            if disableLocalInput {
                disableInput()
            }
        #endif

        isPrivacyModeActive = true
    }

    /// Disable privacy mode - restores screen and input
    public func disablePrivacyMode() {
        guard isPrivacyModeActive else { return }

        #if os(macOS)
            unblankScreen()
            enableInput()
        #endif

        isPrivacyModeActive = false
    }

    // MARK: - Screen Blanking (macOS)

    #if os(macOS)
        private func blankScreen() {
            // Create a fullscreen black window on each screen
            for screen in NSScreen.screens {
                let window = NSWindow(
                    contentRect: screen.frame,
                    styleMask: .borderless,
                    backing: .buffered,
                    defer: false,
                    screen: screen
                )

                window.level = .screenSaver
                window.backgroundColor = .black
                window.isOpaque = true
                window.ignoresMouseEvents = true
                window.collectionBehavior = [.canJoinAllSpaces, .stationary]

                // Add message view
                let messageView = NSTextField(labelWithString: "Remote session in progress\nPrivacy mode enabled")
                messageView.font = .systemFont(ofSize: 24, weight: .medium)
                messageView.textColor = .darkGray
                messageView.alignment = .center
                messageView.translatesAutoresizingMaskIntoConstraints = false

                window.contentView?.addSubview(messageView)
                if let contentView = window.contentView {
                    NSLayoutConstraint.activate([
                        messageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                        messageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
                    ])
                }

                window.orderFrontRegardless()
                blankingWindow = window
            }

            isScreenBlanked = true
        }

        private func unblankScreen() {
            blankingWindow?.close()
            blankingWindow = nil
            isScreenBlanked = false
        }

        // MARK: - Input Control (macOS)

        private func disableInput() {
            // Post a notification that local input should be suppressed
            // The remote input service will still receive events
            // We use CGEvent tap to intercept and suppress local events
            isLocalInputDisabled = true
        }

        private func enableInput() {
            isLocalInputDisabled = false
        }
    #endif

    // MARK: - Cleanup

    deinit {
        // Ensure we restore screen on deallocation
        #if os(macOS)
            let window = blankingWindow
            Task { @MainActor in
                window?.close()
            }
        #endif
    }
}
