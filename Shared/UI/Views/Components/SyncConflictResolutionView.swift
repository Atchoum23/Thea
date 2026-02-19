//
//  SyncConflictResolutionView.swift
//  Thea
//
//  Conflict resolution dialog for sync conflicts.
//  Shows local vs remote versions and lets user choose resolution strategy.
//

import SwiftUI

/// A sync conflict requiring user resolution (UI presentation model).
struct SyncConflictItem: Identifiable, Sendable {
    let id: UUID
    let itemType: ItemType
    let localTitle: String
    let remoteTitle: String
    let localModified: Date
    let remoteModified: Date
    let localDevice: String
    let remoteDevice: String
    let localMessageCount: Int
    let remoteMessageCount: Int

    enum ItemType: String, Sendable {
        case conversation = "Conversation"
        case settings = "Settings"
        case project = "Project"
        case knowledge = "Knowledge Item"
    }

    enum Resolution: Sendable {
        case keepLocal
        case keepRemote
        case merge
    }
}

/// Dialog view for resolving a single sync conflict.
struct SyncConflictResolutionView: View {
    let conflict: SyncConflictItem
    let onResolve: @Sendable (SyncConflictItem.Resolution) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            // Header
            Label("Sync Conflict", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            Text("A \(conflict.itemType.rawValue.lowercased()) was modified on two devices simultaneously.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Comparison
            HStack(spacing: 12) {
                // Local version
                conflictVersionCard(
                    title: "This Device",
                    subtitle: conflict.localDevice,
                    itemTitle: conflict.localTitle,
                    modified: conflict.localModified,
                    messageCount: conflict.localMessageCount,
                    icon: "desktopcomputer",
                    color: .blue
                )

                Image(systemName: "arrow.left.arrow.right")
                    .font(.title2)
                    .foregroundStyle(.secondary)

                // Remote version
                conflictVersionCard(
                    title: "Other Device",
                    subtitle: conflict.remoteDevice,
                    itemTitle: conflict.remoteTitle,
                    modified: conflict.remoteModified,
                    messageCount: conflict.remoteMessageCount,
                    icon: "icloud",
                    color: .purple
                )
            }

            Divider()

            // Resolution buttons
            VStack(spacing: 8) {
                Button {
                    onResolve(.merge)
                    dismiss()
                } label: {
                    Label("Merge Both Versions", systemImage: "arrow.triangle.merge")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .accessibilityLabel("Merge both versions of the conflict")

                HStack(spacing: 8) {
                    Button {
                        onResolve(.keepLocal)
                        dismiss()
                    } label: {
                        Label("Keep Local", systemImage: "desktopcomputer")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Keep local version")

                    Button {
                        onResolve(.keepRemote)
                        dismiss()
                    } label: {
                        Label("Keep Remote", systemImage: "icloud.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Keep remote version")
                }
            }
        }
        .padding()
        .frame(minWidth: 400)
    }

    @ViewBuilder
    private func conflictVersionCard(
        title: String,
        subtitle: String,
        itemTitle: String,
        modified: Date,
        messageCount: Int,
        icon: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.subheadline.bold())
            }

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Text(itemTitle)
                .font(.caption.bold())
                .lineLimit(2)

            if messageCount > 0 {
                Label("\(messageCount) messages", systemImage: "bubble.left.and.bubble.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(modified, style: .relative)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(color.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(color.opacity(0.2), lineWidth: 1)
        )
    }
}

/// Manages pending sync conflicts that need user resolution.
@MainActor
final class SyncConflictManager: ObservableObject {
    static let shared = SyncConflictManager()

    @Published var pendingConflicts: [SyncConflictItem] = []
    @Published var activeConflict: SyncConflictItem?

    var hasConflicts: Bool { !pendingConflicts.isEmpty }

// periphery:ignore - Reserved: hasConflicts property reserved for future feature activation

    func addConflict(_ conflict: SyncConflictItem) {
        pendingConflicts.append(conflict)
        if activeConflict == nil {
            activeConflict = pendingConflicts.first
        }
    }

    func resolveActiveConflict(with resolution: SyncConflictItem.Resolution) {
        guard let active = activeConflict else { return }
        pendingConflicts.removeAll { $0.id == active.id }

        Task {
            await applyResolution(conflict: active, resolution: resolution)
        }

        // Show next conflict if any
        activeConflict = pendingConflicts.first
    }

    private func applyResolution(conflict: SyncConflictItem, resolution: SyncConflictItem.Resolution) async {
        let cloudKitResolution: CloudKitService.ConflictResolution
        switch resolution {
        case .keepLocal: cloudKitResolution = .keepLocal
        case .keepRemote: cloudKitResolution = .keepRemote
        case .merge: cloudKitResolution = .merge
        }

        // Post resolution for CloudKitService to handle
        NotificationCenter.default.post(
            name: .syncConflictResolved,
            object: nil,
            userInfo: [
                "conflictId": conflict.id,
                "resolution": cloudKitResolution
            ]
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let syncConflictResolved = Notification.Name("theaSyncConflictResolved")
    // periphery:ignore - Reserved: syncConflictDetected static property reserved for future feature activation
    static let syncConflictDetected = Notification.Name("theaSyncConflictDetected")
}
