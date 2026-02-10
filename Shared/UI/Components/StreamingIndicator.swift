//
//  StreamingIndicator.swift
//  Thea
//
//  Streaming response indicators based on 2026 AI chat UI best practices
//  Includes thinking indicators, progress states, and animated feedback
//

import SwiftUI

// MARK: - Streaming Status

/// Represents the current state of AI response streaming
public enum StreamingStatus: Equatable, Sendable {
    case idle
    case thinking
    case searching(query: String)
    case generating
    case usingTool(name: String)
    case complete
    case error(String)

    var displayText: String {
        switch self {
        case .idle:
            return ""
        case .thinking:
            return "Thinking..."
        case let .searching(query):
            return "Searching \"\(query)\"..."
        case .generating:
            return "Generating..."
        case let .usingTool(name):
            return "Using \(name)..."
        case .complete:
            return "Done"
        case let .error(message):
            return "Error: \(message)"
        }
    }

    var icon: String {
        switch self {
        case .idle:
            return ""
        case .thinking:
            return "sparkles"
        case .searching:
            return "magnifyingglass"
        case .generating:
            return "text.cursor"
        case .usingTool:
            return "wrench.and.screwdriver"
        case .complete:
            return "checkmark.circle"
        case .error:
            return "exclamationmark.triangle"
        }
    }
}

// MARK: - Streaming Indicator View

/// Shows the current streaming status with animated indicator
struct StreamingIndicatorView: View {
    let status: StreamingStatus

    @State private var shimmerOffset: CGFloat = -200
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if status != .idle {
            HStack(spacing: 8) {
                // Animated icon
                Image(systemName: status.icon)
                    .font(.theaCallout)
                    .foregroundStyle(.secondary)
                    .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion && isActive)

                // Status text with shimmer effect
                Text(status.displayText)
                    .font(.theaCaption1)
                    .foregroundStyle(.secondary)
                    .overlay {
                        if !reduceMotion && isActive {
                            shimmerOverlay
                        }
                    }
                    .mask {
                        Text(status.displayText)
                            .font(.theaCaption1)
                    }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .transition(.scale.combined(with: .opacity))
            .accessibilityLabel(status.displayText)
        }
    }

    private var isActive: Bool {
        switch status {
        case .idle, .complete, .error:
            return false
        default:
            return true
        }
    }

    private var shimmerOverlay: some View {
        LinearGradient(
            colors: [
                .clear,
                Color.primary.opacity(0.4),
                .clear
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: 50)
        .offset(x: shimmerOffset)
        .onAppear {
            withAnimation(
                .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
            ) {
                shimmerOffset = 200
            }
        }
    }
}

// MARK: - Typing Indicator

/// Shows an animated typing indicator (three bouncing dots)
struct TypingIndicator: View {
    @State private var animationPhase = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0 ..< 3, id: \.self) { index in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 8, height: 8)
                    .scaleEffect(reduceMotion ? 1.0 : scale(for: index))
                    .animation(
                        reduceMotion ? nil :
                            Animation.easeInOut(duration: 0.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.15),
                        value: animationPhase
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            animationPhase = 1
        }
        .accessibilityLabel("Thea is typing")
    }

    private func scale(for index: Int) -> CGFloat {
        let base = 0.6
        let peak = 1.0

        // Create a wave effect - index determines animation delay (set in parent)
        // Animation handles the actual scaling via repeatForever
        _ = index // Used for animation delay in parent ForEach
        if animationPhase == 0 {
            return base
        }
        return peak
    }

    private var backgroundColor: Color {
        #if os(macOS)
            Color(nsColor: .controlBackgroundColor)
        #else
            Color(uiColor: .secondarySystemBackground)
        #endif
    }
}

// MARK: - Streaming Message View

/// Complete streaming message view with indicator and partial content
struct StreamingMessageView: View {
    let streamingText: String
    let status: StreamingStatus

    var body: some View {
        HStack(alignment: .top, spacing: TheaSpacing.md) {
            // Assistant avatar
            Image(systemName: "sparkles")
                .font(.system(size: TheaSize.iconSmall, weight: .medium))
                .foregroundStyle(Color.theaPrimaryDefault)
                .frame(width: TheaSize.messageAvatarSize, height: TheaSize.messageAvatarSize)

            VStack(alignment: .leading, spacing: TheaSpacing.sm) {
                StreamingIndicatorView(status: status)

                if !streamingText.isEmpty {
                    Text(streamingText)
                        .font(.theaBody)
                        .textSelection(.enabled)
                        .padding(.horizontal, TheaSpacing.lg)
                        .padding(.vertical, TheaSpacing.md)
                        .background(Color.theaAssistantBubble)
                        .clipShape(RoundedRectangle(cornerRadius: TheaCornerRadius.lg))
                        .overlay(alignment: .bottomTrailing) {
                            BlinkingCursor()
                                .padding(.trailing, TheaSpacing.sm)
                                .padding(.bottom, TheaSpacing.sm)
                        }
                } else if status == .thinking || status == .generating {
                    TypingIndicator()
                }
            }

            Spacer(minLength: TheaSpacing.jumbo)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(streamingAccessibilityLabel)
        .accessibilityValue(streamingText.isEmpty ? "Waiting for response" : streamingText)
    }

    private var streamingAccessibilityLabel: String {
        switch status {
        case .thinking:
            return "Thea is thinking"
        case .generating:
            return "Thea is responding"
        case let .searching(query):
            return "Thea is searching for \(query)"
        case let .usingTool(name):
            return "Thea is using \(name)"
        default:
            return "Thea is processing"
        }
    }
}

// MARK: - Blinking Cursor

/// A simple blinking cursor indicator
struct BlinkingCursor: View {
    @State private var isVisible = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Rectangle()
            .fill(Color.theaPrimary)
            .frame(width: 2, height: 16)
            .opacity(reduceMotion ? 1.0 : (isVisible ? 1.0 : 0.0))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(
                    .easeInOut(duration: 0.5)
                        .repeatForever(autoreverses: true)
                ) {
                    isVisible.toggle()
                }
            }
    }
}

// MARK: - Preview

#Preview("Streaming Indicators") {
    VStack(spacing: 24) {
        StreamingIndicatorView(status: .thinking)
        StreamingIndicatorView(status: .searching(query: "Swift concurrency"))
        StreamingIndicatorView(status: .generating)
        StreamingIndicatorView(status: .usingTool(name: "Web Search"))
        StreamingIndicatorView(status: .complete)
        StreamingIndicatorView(status: .error("Network timeout"))

        Divider()

        TypingIndicator()

        Divider()

        StreamingMessageView(
            streamingText: "Here's how you can implement async/await in Swift...",
            status: .generating
        )
    }
    .padding()
}
