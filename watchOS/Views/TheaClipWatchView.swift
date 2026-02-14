// TheaClipWatchView.swift
// Thea — Glanceable clipboard clips on watchOS

import SwiftUI

struct TheaClipWatchView: View {
    @StateObject private var clipManager = ClipboardHistoryManager.shared

    var body: some View {
        NavigationStack {
            if clipManager.recentEntries.isEmpty {
                ContentUnavailableView(
                    "No Clips",
                    systemImage: "doc.on.clipboard",
                    description: Text("Clips from your other devices will appear here.")
                )
            } else {
                List {
                    ForEach(textEntries) { entry in
                        Button {
                            copyToClipboard(entry)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.previewText)
                                    .font(.caption)
                                    .lineLimit(3)

                                if let appName = entry.sourceAppName {
                                    Text(appName)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Clips")
            }
        }
    }

    private var textEntries: [TheaClipEntry] {
        clipManager.recentEntries.filter {
            $0.contentType == .text || $0.contentType == .url || $0.contentType == .richText
        }
        .prefix(20)
        .map { $0 }
    }

    private func copyToClipboard(_ entry: TheaClipEntry) {
        #if os(watchOS)
            // watchOS doesn't have a general pasteboard API;
            // tapping shows the content for manual copy or handoff
        #endif
    }
}
