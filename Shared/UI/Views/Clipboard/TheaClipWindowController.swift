#if os(macOS)
import AppKit
import SwiftUI

@MainActor
final class TheaClipWindowController {
    static let shared = TheaClipWindowController()

    private var panel: NSPanel?

    private init() {}

    func togglePanel() {
        if let panel, panel.isVisible {
            panel.close()
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 560),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Clipboard History"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.contentView = NSHostingView(rootView: ClipboardHistoryPanel())
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }
}

private struct ClipboardHistoryPanel: View {
    @ObservedObject private var manager = ClipboardHistoryManager.shared

    var body: some View {
        VStack(spacing: 0) {
            Text("Clipboard History")
                .font(.headline)
                .padding()

            if manager.recentEntries.isEmpty {
                ContentUnavailableView(
                    "No Clipboard History",
                    systemImage: "doc.on.clipboard",
                    description: Text("Copied items will appear here")
                )
            } else {
                List(manager.recentEntries, id: \.id) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.previewText)
                            .lineLimit(3)
                            .font(.body)
                        HStack {
                            Text(entry.contentType.rawValue)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(entry.createdAt, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(minWidth: 300, minHeight: 400)
    }
}
#endif
