// TheaClipRelayView.swift
// Thea — Read-only clipboard relay for tvOS

import SwiftUI

struct TheaClipRelayView: View {
    @StateObject private var clipManager = ClipboardHistoryManager.shared

    var body: some View {
        NavigationStack {
            if clipManager.recentEntries.isEmpty {
                ContentUnavailableView(
                    "No Clips",
                    systemImage: "doc.on.clipboard",
                    description: Text("Clips synced from your other devices will appear here.")
                )
            } else {
                List {
                    ForEach(clipManager.recentEntries.prefix(50), id: \.id) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                typeLabel(for: entry.contentType)
                                Spacer()
                                Text(entry.createdAt, style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Text(entry.previewText)
                                .font(.body)
                                .lineLimit(4)

                            if let appName = entry.sourceAppName {
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

    private func typeLabel(for type: TheaClipContentType) -> some View {
        HStack(spacing: 4) {
            Image(systemName: iconForType(type))
            Text(type.rawValue.capitalized)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func iconForType(_ type: TheaClipContentType) -> String {
        switch type {
        case .text: "text.alignleft"
        case .richText: "text.badge.star"
        case .html: "chevron.left.forwardslash.chevron.right"
        case .url: "link"
        case .image: "photo"
        case .file: "doc"
        case .color: "paintpalette"
        }
    }
}
