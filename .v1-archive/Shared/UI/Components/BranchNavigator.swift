//
//  BranchNavigator.swift
//  Thea
//
//  Component for navigating between conversation message branches
//  Based on Claude Desktop's conversation branching pattern
//

import SwiftUI

// MARK: - Branch Navigator View

/// Displays branch navigation controls when a message has alternative versions
struct BranchNavigator: View {
    let currentBranchIndex: Int
    let totalBranches: Int
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .semibold))
            }
            .buttonStyle(.plain)
            .disabled(currentBranchIndex <= 0)
            .opacity(currentBranchIndex > 0 ? 1 : 0.3)

            Text("\(currentBranchIndex + 1)/\(totalBranches)")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
            }
            .buttonStyle(.plain)
            .disabled(currentBranchIndex >= totalBranches - 1)
            .opacity(currentBranchIndex < totalBranches - 1 ? 1 : 0.3)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Branch \(currentBranchIndex + 1) of \(totalBranches)")
        .accessibilityHint("Use left and right to navigate between branches")
    }
}

// MARK: - Message Edit Sheet

/// Sheet for editing a user message to create a new branch
struct MessageEditSheet: View {
    let originalMessage: Message
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @State private var editedText: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Edit Message")
                    .font(.headline)
                Spacer()
                Button("Cancel", action: onCancel)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }

            // Info banner
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.branch")
                    .foregroundStyle(.blue)
                Text("Editing creates a new branch. The original message is preserved.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(Color.blue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Text editor
            TextEditor(text: $editedText)
                .font(.body)
                .frame(minHeight: 100, maxHeight: 300)
                .padding(8)
                #if os(macOS)
                    .background(Color(nsColor: .controlBackgroundColor))
                #else
                    .background(Color(uiColor: .secondarySystemBackground))
                #endif
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .focused($isFocused)

            // Actions
            HStack {
                Spacer()
                Button("Save & Send") {
                    onSave(editedText)
                }
                .buttonStyle(.borderedProminent)
                .disabled(editedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 500)
        .onAppear {
            editedText = originalMessage.content.textValue
            isFocused = true
        }
    }
}

// MARK: - Branch Info Badge

/// Small badge showing branch information on a message
struct BranchInfoBadge: View {
    let isEdited: Bool
    let branchIndex: Int

    var body: some View {
        HStack(spacing: 4) {
            if isEdited {
                Image(systemName: "pencil")
                    .font(.system(size: 9))
            }

            if branchIndex > 0 {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 9))
                Text("Branch \(branchIndex)")
                    .font(.system(size: 10))
            }
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
}

// MARK: - Preview

#if DEBUG
    #Preview("Branch Navigator") {
        VStack(spacing: 20) {
            BranchNavigator(
                currentBranchIndex: 0,
                totalBranches: 3,
                onPrevious: {},
                onNext: {}
            )

            BranchNavigator(
                currentBranchIndex: 1,
                totalBranches: 3,
                onPrevious: {},
                onNext: {}
            )

            BranchNavigator(
                currentBranchIndex: 2,
                totalBranches: 3,
                onPrevious: {},
                onNext: {}
            )
        }
        .padding()
    }

    #Preview("Branch Info Badge") {
        VStack(spacing: 10) {
            BranchInfoBadge(isEdited: false, branchIndex: 0)
            BranchInfoBadge(isEdited: true, branchIndex: 0)
            BranchInfoBadge(isEdited: false, branchIndex: 1)
            BranchInfoBadge(isEdited: true, branchIndex: 2)
        }
        .padding()
    }
#endif
