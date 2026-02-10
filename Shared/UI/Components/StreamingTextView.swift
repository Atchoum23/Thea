//
//  StreamingTextView.swift
//  Thea
//
//  Advanced streaming text display with smooth token buffering,
//  typewriter animation, and content-aware rendering.
//
//  Based on 2026 AI chat UI best practices:
//  - Smooth text streaming at consistent, readable pace
//  - Thinking/reasoning display with collapsible sections
//  - Content-aware indicators for code, text, tools
//  - Natural typewriter animation with cursor
//

import SwiftUI

// MARK: - Streaming Text Configuration

/// Configuration for streaming text display behavior
public struct StreamingTextConfig: Sendable {
    /// Characters revealed per second for typewriter effect
    public var charactersPerSecond: Double = 60

    /// Minimum delay between character reveals (seconds)
    public var minCharacterDelay: Double = 0.008

    /// Maximum delay between character reveals (seconds)
    public var maxCharacterDelay: Double = 0.05

    /// Whether to use smooth animation
    public var useAnimation: Bool = true

    /// Whether to show cursor during streaming
    public var showCursor: Bool = true

    /// Whether to auto-scroll as text is revealed
    public var autoScroll: Bool = true

    public static let `default` = StreamingTextConfig()

    public static let fast = StreamingTextConfig(
        charactersPerSecond: 120,
        minCharacterDelay: 0.004,
        maxCharacterDelay: 0.02
    )

    public static let natural = StreamingTextConfig(
        charactersPerSecond: 45,
        minCharacterDelay: 0.015,
        maxCharacterDelay: 0.08
    )
}

// MARK: - Streaming Content Type

/// Type of content being streamed for adaptive display
public enum StreamingContentType: Equatable, Sendable {
    case text
    case code(language: String?)
    case thinking
    case toolCall(name: String)
    case markdown
    case mixed

    var icon: String {
        switch self {
        case .text: return "text.alignleft"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .thinking: return "sparkles"
        case .toolCall: return "wrench.and.screwdriver"
        case .markdown: return "doc.richtext"
        case .mixed: return "square.stack.3d.up"
        }
    }

    var label: String {
        switch self {
        case .text: return "Writing"
        case .code(let lang): return "Coding\(lang.map { " (\($0))" } ?? "")"
        case .thinking: return "Thinking"
        case .toolCall(let name): return "Using \(name)"
        case .markdown: return "Formatting"
        case .mixed: return "Generating"
        }
    }
}

// MARK: - Streaming Text View

/// A view that displays streaming text with smooth animation
public struct StreamingTextView: View {
    /// The full text received so far from the stream
    let sourceText: String

    /// Configuration for display behavior
    var config: StreamingTextConfig = .default

    /// Content type for adaptive styling
    var contentType: StreamingContentType = .text

    /// Whether streaming is currently active
    var isActive: Bool = true

    // MARK: - State

    @State private var displayedCharacterCount: Int = 0
    @State private var animationTimer: Timer?
    @State private var lastSourceLength: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        text: String,
        config: StreamingTextConfig = .default,
        contentType: StreamingContentType = .text,
        isActive: Bool = true
    ) {
        self.sourceText = text
        self.config = config
        self.contentType = contentType
        self.isActive = isActive
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Content type indicator (only during active streaming)
            if isActive && !sourceText.isEmpty {
                contentTypeIndicator
                    .padding(.bottom, 8)
            }

            // Main text content with cursor
            HStack(alignment: .bottom, spacing: 0) {
                Text(displayedText)
                    .font(.theaBody)
                    .textSelection(.enabled)

                // Animated cursor
                if isActive && config.showCursor {
                    StreamingCursor()
                        .transition(.opacity)
                }
            }
        }
        .onChange(of: sourceText) { _, newText in
            handleTextUpdate(newText)
        }
        .onAppear {
            // Initialize with current text
            if reduceMotion {
                displayedCharacterCount = sourceText.count
            } else {
                startRevealAnimation()
            }
        }
        .onDisappear {
            stopAnimation()
        }
    }

    // MARK: - Computed Properties

    private var displayedText: String {
        if reduceMotion || !config.useAnimation {
            return sourceText
        }
        let endIndex = sourceText.index(
            sourceText.startIndex,
            offsetBy: min(displayedCharacterCount, sourceText.count)
        )
        return String(sourceText[..<endIndex])
    }

    // MARK: - Content Type Indicator

    private var contentTypeIndicator: some View {
        HStack(spacing: 6) {
            Image(systemName: contentType.icon)
                .font(.system(size: 11))
                .symbolEffect(.pulse, options: .repeating, isActive: isActive)

            Text(contentType.label)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
    }

    // MARK: - Animation Control

    private func handleTextUpdate(_ newText: String) {
        guard !reduceMotion else {
            displayedCharacterCount = newText.count
            return
        }

        // New text arrived - continue or start animation
        if newText.count > lastSourceLength {
            lastSourceLength = newText.count
            if animationTimer == nil {
                startRevealAnimation()
            }
        }
    }

    private func startRevealAnimation() {
        stopAnimation()

        // Calculate delay based on config
        let delay = 1.0 / config.charactersPerSecond
        let clampedDelay = max(config.minCharacterDelay, min(delay, config.maxCharacterDelay))

        animationTimer = Timer.scheduledTimer(withTimeInterval: clampedDelay, repeats: true) { _ in
            Task { @MainActor in
                revealNextCharacter()
            }
        }
    }

    private func revealNextCharacter() {
        guard displayedCharacterCount < sourceText.count else {
            // Caught up - pause animation but don't stop (more text may arrive)
            if !isActive {
                stopAnimation()
            }
            return
        }

        // Reveal next character
        withAnimation(.linear(duration: 0.02)) {
            displayedCharacterCount += 1
        }

        // Adaptive pacing: slow down at punctuation for natural feel
        if displayedCharacterCount < sourceText.count {
            let currentIndex = sourceText.index(sourceText.startIndex, offsetBy: displayedCharacterCount - 1)
            let currentChar = sourceText[currentIndex]

            // Add micro-pauses at sentence boundaries
            if ".!?".contains(currentChar) {
                // Slight pause after sentences
                animationTimer?.invalidate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    startRevealAnimation()
                }
            } else if ",;:".contains(currentChar) {
                // Smaller pause at commas
                animationTimer?.invalidate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                    startRevealAnimation()
                }
            }
        }
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
}

// MARK: - Streaming Cursor

/// Animated cursor that appears at the end of streaming text
struct StreamingCursor: View {
    @State private var opacity: Double = 1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Rectangle()
            .fill(Color.accentColor)
            .frame(width: 2, height: 18)
            .opacity(reduceMotion ? 1.0 : opacity)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    opacity = 0.3
                }
            }
    }
}

// Note: StreamingCursorIndicator is defined in StreamingIndicator.swift

// MARK: - Thinking Display View

/// Collapsible view for displaying AI thinking/reasoning process
public struct ThinkingDisplayView: View {
    let thinkingText: String
    var isComplete: Bool = false

    @State private var isExpanded: Bool = false
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with toggle
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    // THEA spiral icon (animated when thinking)
                    TheaSpiralIconView(
                        size: 18,
                        isThinking: !isComplete && !reduceMotion,
                        showGlow: !isComplete
                    )

                    Text(isComplete ? "Thought for \(formattedTime)" : "Thinking...")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(isComplete ? .secondary : .primary)

                    Spacer()

                    // Expand/collapse chevron
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            // Expandable thinking content
            if isExpanded && !thinkingText.isEmpty {
                ScrollView {
                    Text(thinkingText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 200)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.secondary.opacity(0.08))
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity
                ))
            }
        }
        .onAppear {
            if !isComplete {
                startTimer()
            }
        }
        .onDisappear {
            stopTimer()
        }
        .onChange(of: isComplete) { _, complete in
            if complete {
                stopTimer()
            }
        }
    }

    private var formattedTime: String {
        if elapsedTime < 1 {
            return "<1s"
        } else if elapsedTime < 60 {
            return "\(Int(elapsedTime))s"
        } else {
            let minutes = Int(elapsedTime) / 60
            let seconds = Int(elapsedTime) % 60
            return "\(minutes)m \(seconds)s"
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor [self] in
                elapsedTime += 0.1
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Tool Call Display View

/// View for displaying tool/action execution during streaming
public struct ToolCallDisplayView: View {
    let toolName: String
    let toolInput: String?
    var isExecuting: Bool = true
    var result: String?

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Tool execution header
            HStack(spacing: 8) {
                // Tool icon with animation
                Image(systemName: "wrench.and.screwdriver")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isExecuting ? Color.orange : .secondary)
                    .symbolEffect(.bounce, options: .repeating, isActive: isExecuting)

                Text(isExecuting ? "Using \(toolName)..." : "Used \(toolName)")
                    .font(.caption)
                    .fontWeight(.medium)

                Spacer()

                if !isExecuting {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.green)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isExecuting ? Color.orange.opacity(0.1) : Color.secondary.opacity(0.08))
            )

            // Expandable input/output (for debugging)
            if let input = toolInput, !input.isEmpty {
                DisclosureGroup("Input") {
                    Text(input)
                        .font(.caption2)
                        .fontDesign(.monospaced)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
            }

            if let result, !result.isEmpty {
                DisclosureGroup("Result") {
                    Text(result)
                        .font(.caption2)
                        .fontDesign(.monospaced)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(10)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
            }
        }
    }
}

// MARK: - Enhanced Streaming Message View

/// Complete streaming message view combining all streaming display components
public struct EnhancedStreamingMessageView: View {
    /// Current streaming text content
    let streamingText: String

    /// Optional thinking/reasoning text
    var thinkingText: String?

    /// Current streaming status
    var status: StreamingStatus = .generating

    /// Detected content type
    var contentType: StreamingContentType = .mixed

    /// Active tool calls
    var activeToolCalls: [(name: String, input: String?, result: String?)] = []

    /// Configuration
    var config: StreamingTextConfig = .default

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                // Thinking section (collapsible)
                if let thinking = thinkingText, !thinking.isEmpty {
                    ThinkingDisplayView(
                        thinkingText: thinking,
                        isComplete: status != .thinking
                    )
                }

                // Tool calls
                ForEach(Array(activeToolCalls.enumerated()), id: \.offset) { _, tool in
                    ToolCallDisplayView(
                        toolName: tool.name,
                        toolInput: tool.input,
                        isExecuting: tool.result == nil,
                        result: tool.result
                    )
                }

                // Main streaming content
                if !streamingText.isEmpty {
                    StreamingTextView(
                        text: streamingText,
                        config: config,
                        contentType: contentType,
                        isActive: isActiveStreaming
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(backgroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                } else if status == .thinking {
                    // Show typing indicator when thinking but no text yet
                    StreamingTypingIndicator()
                }

                // Status indicator
                if status != .idle && status != .complete {
                    StreamingIndicatorView(status: status)
                }
            }

            Spacer(minLength: 60)
        }
    }

    private var isActiveStreaming: Bool {
        switch status {
        case .generating, .thinking, .searching, .usingTool:
            return true
        default:
            return false
        }
    }

    private var backgroundColor: Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(uiColor: .secondarySystemBackground)
        #endif
    }
}

// Note: PulsingGlowModifier and pulsingGlow extension are defined in MessageBubble.swift

// MARK: - Streaming Typing Indicator

/// Animated typing indicator (three bouncing dots) shown while AI is thinking
struct StreamingTypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.secondary.opacity(0.6))
                    .frame(width: 8, height: 8)
                    .offset(y: animating ? -4 : 4)
                    .animation(
                        .easeInOut(duration: 0.5)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.15),
                        value: animating
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        #if os(macOS)
        .background(Color(.controlBackgroundColor).opacity(0.5))
        #else
        .background(Color(.systemGray6).opacity(0.5))
        #endif
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear { animating = true }
    }
}

// MARK: - Preview

#Preview("Streaming Text") {
    VStack(spacing: 24) {
        StreamingTextView(
            text: "Here's how you can implement async/await in Swift. First, mark your function with the async keyword...",
            contentType: .text,
            isActive: true
        )
        .padding()
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))

        ThinkingDisplayView(
            thinkingText: "Let me analyze this code and identify potential issues. I'll check for memory leaks, race conditions, and API misuse...",
            isComplete: false
        )

        ToolCallDisplayView(
            toolName: "Web Search",
            toolInput: "Swift concurrency best practices 2026",
            isExecuting: true
        )

        EnhancedStreamingMessageView(
            streamingText: "Based on my research, here are the key points...",
            thinkingText: "Analyzing the user's question about SwiftUI performance...",
            status: .generating,
            contentType: .mixed
        )
    }
    .padding()
}
