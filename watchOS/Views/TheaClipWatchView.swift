// TheaClipWatchView.swift
// Thea — Glanceable clipboard clips on watchOS
// Uses lightweight local types since watchOS target doesn't include Shared/

import SwiftUI

/// Lightweight clip representation for watchOS (populated via WatchConnectivity in future)
struct WatchClipItem: Identifiable, Codable {
    let id: UUID
    let preview: String
    let sourceApp: String?
    let timestamp: Date

    static let placeholder: [WatchClipItem] = []
}

struct TheaClipWatchView: View {
    @State private var clips: [WatchClipItem] = WatchClipItem.placeholder

    var body: some View {
        NavigationStack {
            if clips.isEmpty {
                ContentUnavailableView(
                    "No Clips",
                    systemImage: "doc.on.clipboard",
                    description: Text("Clips from your other devices will appear here.")
                )
            } else {
                List {
                    ForEach(clips) { clip in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(clip.preview)
                                .font(.caption)
                                .lineLimit(3)

                            if let appName = clip.sourceApp {
                                Text(appName)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .navigationTitle("Clips")
            }
        }
    }
}
