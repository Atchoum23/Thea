// TheaClipWindowController.swift
// Thea — Floating NSPanel for clipboard history (Shift+Cmd+V)

#if os(macOS)
    import AppKit
    import SwiftUI

    @MainActor
    final class TheaClipWindowController {
        static let shared = TheaClipWindowController()

        private var panel: NSPanel?

        private init() {}

        // MARK: - Panel Lifecycle

        func togglePanel() {
            if let panel, panel.isVisible {
                hidePanel()
            } else {
                showPanel()
            }
        }

        func showPanel() {
            if panel == nil {
                createPanel()
            }

            guard let panel else { return }

            // Position near mouse cursor or center of screen
            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                let panelSize = panel.frame.size
                let mouseLocation = NSEvent.mouseLocation

                var origin = NSPoint(
                    x: mouseLocation.x - panelSize.width / 2,
                    y: mouseLocation.y - panelSize.height / 2
                )

                // Clamp to screen bounds
                origin.x = max(screenFrame.minX, min(origin.x, screenFrame.maxX - panelSize.width))
                origin.y = max(screenFrame.minY, min(origin.y, screenFrame.maxY - panelSize.height))

                panel.setFrameOrigin(origin)
            }

            panel.makeKeyAndOrderFront(nil)
        }

        func hidePanel() {
            panel?.orderOut(nil)
        }

        // MARK: - Panel Creation

        private func createPanel() {
            let contentView = TheaClipPanelView()
            let hostingView = NSHostingView(rootView: contentView)

            let newPanel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
                styleMask: [.titled, .closable, .resizable, .nonactivatingPanel, .utilityWindow],
                backing: .buffered,
                defer: false
            )

            newPanel.contentView = hostingView
            newPanel.title = "Clipboard History"
            newPanel.level = .floating
            newPanel.isFloatingPanel = true
            newPanel.hidesOnDeactivate = false
            newPanel.setFrameAutosaveName("TheaClipPanel")
            newPanel.isMovableByWindowBackground = true
            newPanel.titlebarAppearsTransparent = true
            newPanel.titleVisibility = .visible
            newPanel.animationBehavior = .utilityWindow

            // Allow the panel to become key so search field works
            newPanel.becomesKeyOnlyIfNeeded = true

            panel = newPanel
        }
    }
#endif
