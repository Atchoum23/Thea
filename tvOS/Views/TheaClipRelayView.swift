// TheaClipRelayView.swift
// Thea — Read-only clipboard relay for tvOS
// Uses lightweight local types since tvOS target doesn't include Shared/

import SwiftUI

/// Lightweight clip representation for tvOS (populated via sync in future)
struct TVClipItem: Identifiable, Codable {
    let id: UUID
    let preview: String
    let contentType: String
    let sourceApp: String?
    let timestamp: Date

    static let placeholder: [TVClipItem] = []
}

// periphery:ignore - Reserved: AD3 audit — wired in future integration
struct TheaClipRelayView: View {
    @State private var clips: [TVClipItem] = TVClipItem.placeholder

    var body: some View {
        NavigationStack {
            if clips.isEmpty {
                ContentUnavailableView(
                    "No Clips",
                    systemImage: "doc.on.clipboard",
                    description: Text("Clips synced from your other devices will appear here.")
                )
            } else {
                List {
                    ForEach(clips) { clip in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Label(clip.contentType.capitalized, systemImage: iconForType(clip.contentType))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(clip.timestamp, style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Text(clip.preview)
                                .font(.body)
                                .lineLimit(4)

                            if let appName = clip.sourceApp {
                                Text("from \(appName)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .navigationTitle("Clipboard Relay")
            }
        }
    }

    private func iconForType(_ type: String) -> String {
        switch type {
        case "text", "richText": "text.alignleft"
        case "html": "chevron.left.forwardslash.chevron.right"
        case "url": "link"
        case "image": "photo"
        case "file": "doc"
        default: "doc.on.clipboard"
        }
    }
}
