// ProactiveSuggestionEngine+Views.swift
// Thea
//
// SwiftUI views for proactive suggestions.

import Foundation
import SwiftUI

// MARK: - Proactive Suggestion Card View

/// UI component for displaying a proactive suggestion
public struct SmartSuggestionCard: View {
    let suggestion: SmartSuggestion
    let onAccept: () -> Void
    let onDismiss: () -> Void

    @State private var isHovered = false

    public var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: suggestion.type.icon)
                .font(.system(size: 20))
                .foregroundStyle(suggestion.urgency.displayColor)
                .frame(width: 32)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(suggestion.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            // Actions
            HStack(spacing: 8) {
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Button {
                    onAccept()
                } label: {
                    Text("Go")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(suggestion.urgency.displayColor.opacity(0.3), lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Proactive Suggestions List View

/// Container view for showing all active suggestions
public struct SmartSuggestionsView: View {
    @ObservedObject var engine = SmartSuggestionEngine.shared
    let onExecuteAction: (SmartSuggestion.SuggestionAction) -> Void

    public init(onExecuteAction: @escaping (SmartSuggestion.SuggestionAction) -> Void) {
        self.onExecuteAction = onExecuteAction
    }

    public var body: some View {
        if !engine.activeSuggestions.isEmpty && engine.isEnabled {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    TheaSpiralIconView(size: 16, isThinking: false, showGlow: false)
                    Text("Suggestions")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Dismiss All") {
                        engine.dismissAllSuggestions()
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)

                ForEach(engine.activeSuggestions) { suggestion in
                    SmartSuggestionCard(
                        suggestion: suggestion,
                        onAccept: {
                            engine.acceptSuggestion(suggestion)
                            onExecuteAction(suggestion.action)
                        },
                        onDismiss: {
                            engine.dismissSuggestion(suggestion)
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
                }
            }
            .padding()
            .animation(.spring(response: 0.4), value: engine.activeSuggestions.count)
        }
    }
}
