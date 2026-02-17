// TheaClipCardView.swift
// Thea — Visual clipboard entry card for the clipboard history panel

import SwiftUI

struct TheaClipCardView: View {
    let entry: TheaClipEntry
    let isSelected: Bool
    var onPaste: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            contentPreview
            metadataBar
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
                }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onPaste?()
        }
    }

    // MARK: - Content Preview

    @ViewBuilder
    private var contentPreview: some View {
        switch entry.contentType {
        case .text, .richText, .html:
            Text(entry.previewText)
                .font(.caption)
                .lineLimit(4)
                .foregroundStyle(.primary)

        case .url:
            HStack(spacing: 4) {
                Image(systemName: "link")
                    .font(.caption2)
                    .foregroundStyle(.theaInfo)
                    .accessibilityHidden(true)
                Text(entry.urlString ?? entry.previewText)
                    .font(.caption)
                    .lineLimit(2)
                    .foregroundStyle(.theaInfo)
            }

        case .image:
            if let imageData = entry.imageData {
                #if os(macOS)
                    if let nsImage = NSImage(data: imageData) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                #endif
            } else {
                Label("Image", systemImage: "photo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .file:
            VStack(alignment: .leading, spacing: 2) {
                ForEach(entry.fileNames.prefix(3), id: \.self) { name in
                    HStack(spacing: 4) {
                        Image(systemName: "doc")
                            .font(.caption2)
                            .accessibilityHidden(true)
                        Text(name)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
                if entry.fileNames.count > 3 {
                    Text("+\(entry.fileNames.count - 3) more")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

        case .color:
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray)
                .frame(height: 30)
                .overlay {
                    Text(entry.previewText)
                        .font(.caption2)
                        .foregroundStyle(.white)
                }
        }
    }

    // MARK: - Metadata Bar

    private var metadataBar: some View {
        HStack(spacing: 6) {
            if let appName = entry.sourceAppName {
                Text(appName)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if entry.isFavorite {
                Image(systemName: "star.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.theaWarning)
                    .accessibilityHidden(true)
            }

            if entry.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.theaWarning)
                    .accessibilityHidden(true)
            }

            if entry.isSensitive {
                Image(systemName: "lock.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.theaError)
                    .accessibilityHidden(true)
            }

            Text(entry.createdAt, style: .relative)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
    }
}
