// TheaClipRowView.swift
// Thea — Clipboard entry row for iOS list views

import SwiftUI

struct TheaClipRowView: View {
    let entry: TheaClipEntry

    var body: some View {
        HStack(spacing: 10) {
            typeIcon
                .frame(width: 28, height: 28)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.previewText)
                    .font(.subheadline)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    if let appName = entry.sourceAppName {
                        Text(appName)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Text(entry.createdAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            badges
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rowAccessibilityLabel)
    }

    private var rowAccessibilityLabel: String {
        var parts: [String] = []
        parts.append("\(entry.contentType) clipboard entry")
        parts.append(entry.previewText)
        if let appName = entry.sourceAppName {
            parts.append("from \(appName)")
        }
        if entry.isFavorite { parts.append("favorite") }
        if entry.isPinned { parts.append("pinned") }
        if entry.isSensitive { parts.append("sensitive") }
        return parts.joined(separator: ", ")
    }

    @ViewBuilder
    private var typeIcon: some View {
        switch entry.contentType {
        case .text, .richText:
            Image(systemName: "text.alignleft")
        case .html:
            Image(systemName: "chevron.left.forwardslash.chevron.right")
        case .url:
            Image(systemName: "link")
        case .image:
            if let imageData = entry.imageData {
                #if canImport(UIKit)
                    if let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .accessibilityLabel("Clipboard image thumbnail")
                    }
                #endif
            } else {
                Image(systemName: "photo")
            }
        case .file:
            Image(systemName: "doc")
        case .color:
            Image(systemName: "paintpalette")
        }
    }

    private var badges: some View {
        HStack(spacing: 4) {
            if entry.isFavorite {
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundStyle(.theaWarning)
                    .accessibilityHidden(true)
            }
            if entry.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(.theaWarning)
                    .accessibilityHidden(true)
            }
            if entry.isSensitive {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                    .foregroundStyle(.theaError)
                    .accessibilityHidden(true)
            }
        }
    }
}
