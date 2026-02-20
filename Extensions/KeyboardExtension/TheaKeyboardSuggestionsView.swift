//
//  TheaKeyboardSuggestionsView.swift
//  TheaKeyboardExtension
//
//  AAB3-5: SwiftUI suggestion bar for the Thea Keyboard Extension.
//  Hosted via UIHostingController in KeyboardViewController.setupSuggestionsHostingController().
//

import SwiftUI

// MARK: - TheaKeyboardSuggestionsView

/// SwiftUI-based suggestion chip bar displayed above the keyboard.
struct TheaKeyboardSuggestionsView: View {
    let suggestions: [String]
    let onSelect: (String) -> Void
    let onAIAssist: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            // AI Assist chip — always present
            Button {
                onAIAssist()
            } label: {
                Label("Thea", systemImage: "sparkles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        LinearGradient(
                            colors: [Color.purple, Color.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Divider()
                .frame(height: 20)

            // Dynamic suggestion chips
            if suggestions.isEmpty {
                Text("Type to see suggestions…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
            } else {
                ForEach(suggestions.prefix(3), id: \.self) { suggestion in
                    Button {
                        onSelect(suggestion)
                    } label: {
                        Text(suggestion)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray5))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(height: 36)
        .background(Color(.systemBackground))
    }
}

#Preview {
    TheaKeyboardSuggestionsView(
        suggestions: ["Hello", "Thanks", "On my way"],
        onSelect: { _ in },
        onAIAssist: {}
    )
    .frame(width: 390)
}
