// EnhancedMessageBubble.swift
// Thea V2 - Omni-AI UI
//
// Enhanced message display with dynamic blocks, following 2026 AI UX best practices:
// - Dynamic Blocks: Beyond pure chat, with task-oriented UI components
// - Semantic Responses: Code, tables, actions, citations rendered appropriately
// - Micro-interactions: Subtle hover effects and animations
// - Accessibility: VoiceOver-optimized with clear labels
//
// Created: February 3, 2026

import MarkdownUI
import SwiftUI

#if canImport(Highlightr)
import Highlightr
#endif

// Supporting types (IconActionButton, ConfidenceDot, EnhancedCodeBlock, ParsedBlock,
// parseResponseBlocks(), MessageQuickAction, Preview) are in EnhancedMessageBubbleTypes.swift

// MARK: - Enhanced Message Bubble

/// Next-generation message bubble with dynamic block rendering
public struct EnhancedMessageBubble: View {
    let message: Message

    /// Whether this message is currently being streamed
    var isStreaming: Bool = false

    /// Callback when user wants to edit this message
    var onEdit: ((Message) -> Void)?

    /// Callback when user wants to regenerate this response
    var onRegenerate: ((Message) -> Void)?

    /// Callback for quick actions
    var onQuickAction: ((MessageQuickAction) -> Void)?

    @State private var isHovered = false
    @State private var showCopiedFeedback = false
    @State private var expandedBlocks: Set<String> = []
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public var body: some View {
        HStack(alignment: .top, spacing: TheaSpacing.md) {
            // Avatar for assistant messages
            if message.messageRole == .assistant {
                assistantAvatar
            }

            if message.messageRole == .user {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.messageRole == .user ? .trailing : .leading, spacing: TheaSpacing.sm) {
                // Main content with dynamic blocks
                messageContent
                    .entranceAnimation(delay: 0.05)

                // Quick actions for assistant messages
                if message.messageRole == .assistant && !isStreaming {
                    quickActionsRow
                        .entranceAnimation(delay: 0.15)
                }

                // Metadata row
                metadataRow
                    .entranceAnimation(delay: 0.1)
            }

            if message.messageRole == .assistant {
                Spacer(minLength: 40)
            }

            // User avatar (optional)
            if message.messageRole == .user {
                userAvatar
            }
        }
        .padding(.vertical, TheaSpacing.xs)
        .onHover { hovering in
            withAnimation(TheaAnimation.micro) {
                isHovered = hovering
            }
        }
        // Hover action overlay
        .overlay(alignment: message.messageRole == .user ? .topLeading : .topTrailing) {
            if isHovered && !isStreaming {
                hoverActions
                    .offset(x: message.messageRole == .user ? -8 : 8, y: -4)
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: message.messageRole == .user ? .trailing : .leading)))
            }
        }
    }

    // MARK: - Avatars

    private var assistantAvatar: some View {
        ZStack {
            Circle()
                .fill(Color.theaPrimaryGradientDefault)
                .frame(width: 32, height: 32)

            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
        }
        .layeredDepth(TheaShadow.subtle, cornerRadius: 16)
        .pulsingGlow(color: .theaPrimaryDefault, isActive: isStreaming)
    }

    private var userAvatar: some View {
        ZStack {
            Circle()
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 32, height: 32)

            Image(systemName: "person.fill")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Message Content

    @ViewBuilder
    private var messageContent: some View {
        let text = message.content.textValue

        if message.messageRole == .assistant {
            // Parse and render dynamic blocks
            VStack(alignment: .leading, spacing: TheaSpacing.sm) {
                if isStreaming {
                    streamingContent(text)
                } else {
                    dynamicBlocksContent(text)
                }
            }
        } else {
            // User message: clean, simple bubble
            userMessageBubble(text)
        }
    }

    private func userMessageBubble(_ text: String) -> some View {
        Text(text)
            .font(.theaBody)
            .foregroundStyle(.white)
            .padding(.horizontal, TheaSpacing.lg)
            .padding(.vertical, TheaSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: TheaRadius.xl)
                    .fill(Color.theaPrimaryGradientDefault)
            )
            .layeredDepth(TheaShadow.subtle, cornerRadius: TheaRadius.xl)
            .textSelection(.enabled)
    }

    private func streamingContent(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: TheaSpacing.sm) {
            // Streaming text with cursor
            HStack(alignment: .bottom, spacing: 2) {
                if text.isEmpty {
                    TheaStreamingIndicatorView(modelName: message.model)
                } else {
                    Text(text)
                        .font(.theaBody)
                        .textSelection(.enabled)

                    // Blinking cursor
                    Rectangle()
                        .fill(Color.theaPrimaryDefault)
                        .frame(width: 2, height: 16)
                        .opacity(reduceMotion ? 1.0 : cursorOpacity)
                        .animation(
                            reduceMotion ? nil : .easeInOut(duration: 0.5).repeatForever(),
                            value: cursorOpacity
                        )
                }
            }
            .padding(.horizontal, TheaSpacing.lg)
            .padding(.vertical, TheaSpacing.md)
            .frostedGlass(cornerRadius: TheaRadius.lg)
        }
    }

    @State private var cursorOpacity: Double = 1

    private func dynamicBlocksContent(_ text: String) -> some View {
        let blocks = parseResponseBlocks(text)

        return VStack(alignment: .leading, spacing: TheaSpacing.sm) {
            ForEach(blocks) { block in
                renderBlock(block)
            }
        }
    }

    // MARK: - Block Rendering

    @ViewBuilder
    private func renderBlock(_ block: ParsedBlock) -> some View {
        switch block.type {
        case .code:
            codeBlock(block)
        case .thinking:
            thinkingBlock(block)
        case .warning:
            warningBlock(block)
        case .success:
            successBlock(block)
        default:
            textBlock(block)
        }
    }

    private func textBlock(_ block: ParsedBlock) -> some View {
        Markdown(block.content)
            .markdownTheme(theaMarkdownTheme)
            .textSelection(.enabled)
            .padding(.horizontal, TheaSpacing.lg)
            .padding(.vertical, TheaSpacing.md)
            .frostedGlass(cornerRadius: TheaRadius.lg)
    }

    private func codeBlock(_ block: ParsedBlock) -> some View {
        ExecutableCodeBlock(
            code: block.content,
            language: block.metadata["language"],
            isExpanded: expandedBlocks.contains(block.id)
        ) {
            if expandedBlocks.contains(block.id) {
                expandedBlocks.remove(block.id)
            } else {
                expandedBlocks.insert(block.id)
            }
        }
    }

    private func thinkingBlock(_ block: ParsedBlock) -> some View {
        ResponseBlock(type: .thinking) {
            Text(block.content)
                .font(.theaCaption1)
                .foregroundStyle(.secondary)
        }
    }

    private func warningBlock(_ block: ParsedBlock) -> some View {
        HStack(spacing: TheaSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.theaWarning)
            Text(block.content)
                .font(.theaBody)
        }
        .padding(.horizontal, TheaSpacing.lg)
        .padding(.vertical, TheaSpacing.md)
        .frostedGlass(cornerRadius: TheaRadius.lg, tint: .theaWarning)
    }

    private func successBlock(_ block: ParsedBlock) -> some View {
        HStack(spacing: TheaSpacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.theaSuccess)
            Text(block.content)
                .font(.theaBody)
        }
        .padding(.horizontal, TheaSpacing.lg)
        .padding(.vertical, TheaSpacing.md)
        .frostedGlass(cornerRadius: TheaRadius.lg, tint: .theaSuccess)
    }

    // MARK: - Quick Actions

    private var quickActionsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: TheaSpacing.sm) {
                TheaQuickActionButton(title: "Copy", icon: "doc.on.doc") {
                    copyToClipboard()
                }

                TheaQuickActionButton(title: "Regenerate", icon: "arrow.clockwise") {
                    if let onRegenerate {
                        onRegenerate(message)
                    }
                }

                TheaQuickActionButton(title: "Expand", icon: "arrow.up.left.and.arrow.down.right") {
                    onQuickAction?(.expand as MessageQuickAction)
                }

                TheaQuickActionButton(title: "Simplify", icon: "minus.circle") {
                    onQuickAction?(.simplify as MessageQuickAction)
                }
            }
        }
    }

    // MARK: - Hover Actions

    private var hoverActions: some View {
        HStack(spacing: TheaSpacing.xs) {
            IconActionButton(icon: showCopiedFeedback ? "checkmark" : "doc.on.doc", color: showCopiedFeedback ? .theaSuccess : .secondary) {
                copyToClipboard()
            }

            if message.messageRole == .user, let onEdit {
                IconActionButton(icon: "pencil", color: .secondary) {
                    onEdit(message)
                }
            }

            if message.messageRole == .assistant {
                IconActionButton(icon: "arrow.clockwise", color: .secondary) {
                    onRegenerate?(message)
                }
            }
        }
        .padding(TheaSpacing.xs)
        .frostedGlass(cornerRadius: TheaRadius.sm)
    }

    // MARK: - Metadata Row

    private var metadataRow: some View {
        HStack(spacing: TheaSpacing.sm) {
            if isStreaming {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 12, height: 12)
                Text("Generating...")
                    .font(.theaCaption2)
                    .foregroundStyle(.secondary)
            } else {
                if let model = message.model {
                    Text(model)
                        .font(.theaCaption2)
                        .foregroundStyle(.tertiary)
                }

                Text(message.timestamp, format: .dateTime.hour().minute())
                    .font(.theaCaption2)
                    .foregroundStyle(.tertiary)

                // Confidence indicator
                if let confidence = message.metadata?.confidence {
                    HStack(spacing: 2) {
                        Image(systemName: confidenceIcon(for: confidence))
                            .font(.system(size: 8))
                        Text("\(Int(confidence * 100))%")
                            .font(.theaCaption2)
                    }
                    .foregroundStyle(confidenceColor(for: confidence))
                }
            }
        }
        .padding(.horizontal, TheaSpacing.xs)
    }

    // MARK: - Helpers

    private func copyToClipboard() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message.content.textValue, forType: .string)
        #else
        UIPasteboard.general.string = message.content.textValue
        #endif

        withAnimation(TheaAnimation.bouncy) {
            showCopiedFeedback = true
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            withAnimation {
                showCopiedFeedback = false
            }
        }
    }

    // MARK: - Markdown Theme

    private var theaMarkdownTheme: MarkdownUI.Theme {
        MarkdownUI.Theme()
            .text { FontSize(.em(1)) }
            .code {
                FontSize(.em(0.9))
                BackgroundColor(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.95))
            }
            .codeBlock { config in
                EnhancedCodeBlock(code: config.content, language: config.language, isExpanded: true) {}
            }
            .heading1 { config in
                config.label
                    .markdownTextStyle {
                        FontWeight(.bold)
                        FontSize(.em(1.4))
                    }
                    .padding(.bottom, 8)
            }
            .heading2 { config in
                config.label
                    .markdownTextStyle {
                        FontWeight(.semibold)
                        FontSize(.em(1.2))
                    }
                    .padding(.bottom, 6)
            }
            .link {
                ForegroundColor(.theaPrimary)
                UnderlineStyle(.single)
            }
    }

    // MARK: - Confidence Helpers

    private func confidenceIcon(for confidence: Double) -> String {
        switch confidence {
        case 0.9...: return "checkmark.seal.fill"
        case 0.7..<0.9: return "checkmark.circle.fill"
        case 0.5..<0.7: return "questionmark.circle"
        default: return "exclamationmark.circle"
        }
    }

    private func confidenceColor(for confidence: Double) -> Color {
        switch confidence {
        case 0.9...: return .theaSuccess
        case 0.7..<0.9: return .theaInfo
        case 0.5..<0.7: return .theaWarning
        default: return .theaError
        }
    }
}
