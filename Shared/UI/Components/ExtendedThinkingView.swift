//
//  ExtendedThinkingView.swift
//  Thea
//
//  Expandable view for displaying AI thinking/reasoning process
//  Based on Claude Desktop's Extended Thinking UI pattern
//

import SwiftUI

// MARK: - Extended Thinking View

/// Displays an expandable section showing the AI's thinking process
struct ExtendedThinkingView: View {
    let thinkingContent: String
    let elapsedTime: TimeInterval?
    let isComplete: Bool

    @State private var isExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header (always visible)
            thinkingHeader
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(reduceMotion ? .none : .spring(response: 0.3)) {
                        isExpanded.toggle()
                    }
                }

            // Expandable content
            if isExpanded {
                thinkingContent(content: thinkingContent)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(thinkingBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.theaPrimaryDefault.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Header

    private var thinkingHeader: some View {
        HStack(spacing: 10) {
            // Animated thinking icon
            ThinkingIcon(isAnimating: !isComplete)

            VStack(alignment: .leading, spacing: 2) {
                Text(isComplete ? "Thought Process" : "Thinking...")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)

                if let elapsed = elapsedTime {
                    Text(formatElapsedTime(elapsed))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            Spacer()

            // Expand/collapse indicator
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isComplete ? "Thought process complete" : "AI is thinking")
        .accessibilityHint(isExpanded ? "Tap to collapse" : "Tap to expand and see thinking process")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Content

    private func thinkingContent(content: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .background(Color.theaPrimaryDefault.opacity(0.2))

            ScrollView {
                Text(content)
                    .font(.system(size: 13, design: .default))
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 200)
            .padding(14)
        }
    }

    // MARK: - Helpers

    private var thinkingBackground: Color {
        Color.theaPrimaryDefault.opacity(0.08)
    }

    private func formatElapsedTime(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return String(format: "%.1fs", seconds)
        } else {
            let minutes = Int(seconds) / 60
            let remainingSeconds = Int(seconds) % 60
            return String(format: "%dm %ds", minutes, remainingSeconds)
        }
    }
}

// MARK: - Thinking Icon

/// Animated thinking icon using Thea spiral
struct ThinkingIcon: View {
    let isAnimating: Bool

    var body: some View {
        TheaSpiralIconView(
            size: 24,
            isThinking: isAnimating,
            showGlow: isAnimating
        )
    }
}

// MARK: - Thinking Timer

/// Timer that tracks elapsed thinking time
@MainActor
class ThinkingTimer: ObservableObject {
    @Published var elapsedTime: TimeInterval = 0
    @Published var isRunning = false

    private var timer: Timer?
    private var startTime: Date?

    func start() {
        guard !isRunning else { return }
        isRunning = true
        startTime = Date()
        elapsedTime = 0

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let start = self.startTime else { return }
                self.elapsedTime = Date().timeIntervalSince(start)
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }
}

// MARK: - Streaming Thinking View

/// View that displays thinking content as it streams in
// periphery:ignore - Reserved: StreamingThinkingView type reserved for future feature activation
struct StreamingThinkingView: View {
    @ObservedObject var timer: ThinkingTimer
    let thinkingText: String
    let isComplete: Bool

    var body: some View {
        ExtendedThinkingView(
            thinkingContent: thinkingText.isEmpty ? "Processing your request..." : thinkingText,
            elapsedTime: timer.elapsedTime,
            isComplete: isComplete
        )
        .onAppear {
            if !isComplete {
                timer.start()
            }
        }
        .onChange(of: isComplete) { _, complete in
            if complete {
                timer.stop()
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Extended Thinking - Expanded") {
        VStack(spacing: 20) {
            ExtendedThinkingView(
                thinkingContent: """
                Let me analyze this step by step:

                1. First, I need to understand the user's request about implementing message branching.

                2. Message branching allows users to edit previous messages and create alternative conversation paths.

                3. The key components needed are:
                   - Parent message ID tracking
                   - Branch index for ordering alternatives
                   - UI for navigating between branches

                4. This is similar to how version control works with branches in git.
                """,
                elapsedTime: 12.5,
                isComplete: true
            )

            ExtendedThinkingView(
                thinkingContent: "Analyzing the code structure and determining the best approach...",
                elapsedTime: 3.2,
                isComplete: false
            )
        }
        .padding()
        .frame(width: 500)
    }

    #Preview("Thinking Icon") {
        HStack(spacing: 40) {
            VStack {
                ThinkingIcon(isAnimating: true)
                Text("Animating").font(.caption)
            }
            VStack {
                ThinkingIcon(isAnimating: false)
                Text("Static").font(.caption)
            }
        }
        .padding()
    }
#endif
