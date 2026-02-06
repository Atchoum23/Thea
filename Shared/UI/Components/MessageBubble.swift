//
//  MessageBubble.swift
//  Thea
//
//  Enhanced message display with markdown rendering and code syntax highlighting
//  Based on 2026 AI chat UI best practices research
//

import MarkdownUI
import SwiftUI

#if canImport(Highlightr)
    import Highlightr
#endif

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: Message

    /// Callback when user wants to edit this message (creates a branch)
    var onEdit: ((Message) -> Void)?

    /// Callback when user wants to regenerate this response
    var onRegenerate: ((Message) -> Void)?

    /// Branch navigation info (nil if no branches exist)
    var branchInfo: BranchInfo?

    @State private var isHovering = false
    @State private var showCopiedFeedback = false
    @Environment(\.colorScheme) private var colorScheme

    /// Info about branches for this message position
    struct BranchInfo {
        let currentIndex: Int
        let totalCount: Int
        let onNavigate: (Int) -> Void
    }

    var body: some View {
        HStack(alignment: .top, spacing: TheaSpacing.md) {
            if message.messageRole == .assistant {
                Image(systemName: "sparkles")
                    .font(.system(size: TheaSize.iconSmall, weight: .medium))
                    .foregroundStyle(Color.theaPrimaryDefault)
                    .frame(width: TheaSize.messageAvatarSize, height: TheaSize.messageAvatarSize)
            }

            if message.messageRole == .user {
                Spacer(minLength: TheaSpacing.jumbo)
            }

            VStack(alignment: message.messageRole == .user ? .trailing : .leading, spacing: TheaSpacing.xs) {
                if let branchInfo, branchInfo.totalCount > 1 {
                    BranchNavigator(
                        currentBranchIndex: branchInfo.currentIndex,
                        totalBranches: branchInfo.totalCount,
                        onPrevious: { branchInfo.onNavigate(branchInfo.currentIndex - 1) },
                        onNext: { branchInfo.onNavigate(branchInfo.currentIndex + 1) }
                    )
                }

                messageContent
                    .padding(.horizontal, TheaSpacing.lg)
                    .padding(.vertical, TheaSpacing.md)
                    .background(backgroundColor)
                    .foregroundStyle(foregroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: TheaCornerRadius.lg))

                metadataRow
            }
            .frame(maxWidth: TheaSize.messageMaxWidth, alignment: message.messageRole == .user ? .trailing : .leading)

            if message.messageRole == .assistant {
                Spacer(minLength: TheaSpacing.jumbo)
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        // Overlay action buttons on hover (macOS only)
        #if os(macOS)
            .overlay(alignment: message.messageRole == .user ? .topLeading : .topTrailing) {
                if isHovering {
                    hoverActions
                        .offset(x: message.messageRole == .user ? -8 : 8, y: -8)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
        #endif
    }

    // MARK: - Message Content

    @ViewBuilder
    private var messageContent: some View {
        let text = message.content.textValue

        if message.messageRole == .assistant {
            // Use MarkdownUI for assistant messages (supports code blocks, lists, etc.)
            Markdown(text)
                .markdownTheme(theaMarkdownTheme)
                .markdownCodeSyntaxHighlighter(TheaCodeHighlighter())
                .textSelection(.enabled)
        } else {
            // User messages: plain text (usually short prompts)
            Text(text)
                .font(.theaBody)
                .textSelection(.enabled)
        }
    }

    // MARK: - Metadata Row

    private var metadataRow: some View {
        HStack(spacing: 8) {
            // Show edited badge if message was edited
            if message.isEdited || message.branchIndex > 0 {
                BranchInfoBadge(isEdited: message.isEdited, branchIndex: message.branchIndex)
            }

            if let model = message.model {
                Text(model)
                    .font(.theaCaption2)
                    .foregroundStyle(.secondary)
            }

            Text(message.timestamp, format: .dateTime.hour().minute())
                .font(.theaCaption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Hover Actions

    #if os(macOS)
        private var hoverActions: some View {
            HStack(spacing: 4) {
                // Copy button
                Button {
                    copyToClipboard()
                } label: {
                    Image(systemName: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundStyle(showCopiedFeedback ? .green : .secondary)
                        .frame(width: 24, height: 24)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Copy message")
                .accessibilityLabel("Copy message to clipboard")

                // Edit button (user messages only - creates a branch)
                if message.messageRole == .user, let onEdit {
                    Button {
                        onEdit(message)
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .help("Edit message (creates a branch)")
                    .accessibilityLabel("Edit message to create a new branch")
                }

                // Regenerate button (assistant messages only)
                if message.messageRole == .assistant {
                    Button {
                        if let onRegenerate {
                            onRegenerate(message)
                        } else {
                            regenerateMessage()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .help("Regenerate response")
                    .accessibilityLabel("Regenerate AI response")
                }
            }
            .padding(4)
        }
    #endif

    // MARK: - Actions

    private func copyToClipboard() {
        #if os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(message.content.textValue, forType: .string)
        #else
            UIPasteboard.general.string = message.content.textValue
        #endif

        withAnimation {
            showCopiedFeedback = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showCopiedFeedback = false
            }
        }
    }

    private func regenerateMessage() {
        // TODO: Implement regenerate via ChatManager
        // This should trigger a new response for the same user message
    }

    // MARK: - Styling

    private var backgroundColor: Color {
        switch message.messageRole {
        case .user:
            return .theaUserBubble
        case .assistant:
            return .theaAssistantBubble
        case .system:
            return .theaSurface
        }
    }

    private var foregroundColor: Color {
        switch message.messageRole {
        case .user:
            .white
        case .assistant, .system:
            .primary
        }
    }

    // MARK: - Markdown Theme

    private var theaMarkdownTheme: MarkdownUI.Theme {
        MarkdownUI.Theme()
            .text {
                FontSize(.em(1))
            }
            .code {
                FontSize(.em(0.9))
                BackgroundColor(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.95))
            }
            .codeBlock { configuration in
                CodeBlockView(configuration: configuration)
            }
            .heading1 { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontWeight(.bold)
                        FontSize(.em(1.5))
                    }
                    .padding(.bottom, 8)
            }
            .heading2 { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontWeight(.semibold)
                        FontSize(.em(1.3))
                    }
                    .padding(.bottom, 6)
            }
            .heading3 { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontWeight(.semibold)
                        FontSize(.em(1.15))
                    }
                    .padding(.bottom, 4)
            }
            .listItem { configuration in
                configuration.label
                    .padding(.leading, 4)
            }
            .blockquote { configuration in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.theaPrimary.opacity(0.5))
                        .frame(width: 3)
                    configuration.label
                        .padding(.leading, 12)
                        .foregroundStyle(.secondary)
                }
            }
            .link {
                ForegroundColor(.theaPrimary)
                UnderlineStyle(.single)
            }
    }
}

// MARK: - Code Block View with Syntax Highlighting

struct CodeBlockView: View {
    let configuration: CodeBlockConfiguration

    @State private var showCopied = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with language and copy button
            HStack {
                if let language = configuration.language {
                    Text(language)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                }

                Spacer()

                Button {
                    copyCode()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                        Text(showCopied ? "Copied" : "Copy")
                    }
                    .font(.caption)
                    .foregroundStyle(showCopied ? .green : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Copy code snippet")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(headerBackground)

            // Code content with syntax highlighting
            ScrollView(.horizontal, showsIndicators: false) {
                highlightedCode
                    .padding(12)
            }
            .background(codeBackground)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var highlightedCode: some View {
        let code = configuration.content

        #if canImport(Highlightr) && os(macOS)
            if let attributedCode = highlightCodeWithHighlightr(code) {
                Text(attributedCode)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            } else {
                plainCodeText(code)
            }
        #else
            plainCodeText(code)
        #endif
    }

    #if canImport(Highlightr) && os(macOS)
        /// Highlights code using Highlightr library
        private func highlightCodeWithHighlightr(_ code: String) -> AttributedString? {
            guard let highlighter = Highlightr(),
                  let language = configuration.language else {
                return nil
            }

            // Configure theme based on color scheme
            let themeName = colorScheme == .dark ? "monokai-sublime" : "github"
            highlighter.setTheme(to: themeName)

            guard let highlighted = highlighter.highlight(code, as: language) else {
                return nil
            }

            return AttributedString(highlighted)
        }
    #endif

    private func plainCodeText(_ code: String) -> some View {
        Text(code)
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(.primary)
            .textSelection(.enabled)
    }

    private func copyCode() {
        let code = configuration.content
        #if os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(code, forType: .string)
        #else
            UIPasteboard.general.string = code
        #endif

        withAnimation {
            showCopied = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showCopied = false
            }
        }
    }

    private var headerBackground: Color {
        colorScheme == .dark ? Color(white: 0.12) : Color(white: 0.92)
    }

    private var codeBackground: Color {
        colorScheme == .dark ? Color(white: 0.08) : Color(white: 0.97)
    }

    private var borderColor: Color {
        colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.85)
    }
}

// MARK: - Code Syntax Highlighter for MarkdownUI

struct TheaCodeHighlighter: CodeSyntaxHighlighter {
    func highlightCode(_ code: String, language: String?) -> Text {
        // For inline code, just use monospace font
        // Block-level code uses CodeBlockView with full highlighting
        Text(code)
            .font(.system(.body, design: .monospaced))
    }
}
