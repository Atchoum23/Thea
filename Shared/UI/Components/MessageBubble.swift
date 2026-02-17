//
//  MessageBubble.swift
//  Thea
//
//  Enhanced message display with markdown rendering, code syntax highlighting,
//  and comprehensive per-message actions (copy, edit, rewrite, split, etc.)
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

    /// Callback for extended actions
    var onAction: ((MessageAction, Message) -> Void)?

    /// Branch navigation info (nil if no branches exist)
    var branchInfo: BranchInfo?

    @State private var isHovering = false
    @State private var showCopiedFeedback = false
    @State private var isThinkingExpanded = false
    @StateObject private var settingsManager = SettingsManager.shared

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
                    .padding(.horizontal, densityHorizontalPadding)
                    .padding(.vertical, densityVerticalPadding)
                    .background(backgroundColor)
                    .foregroundStyle(foregroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: TheaCornerRadius.lg))

                // Hover action bar (appears below the bubble on hover)
                #if os(macOS)
                    if isHovering {
                        hoverActionBar
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                #endif

                metadataRow
            }
            .frame(maxWidth: TheaSize.messageMaxWidth, alignment: message.messageRole == .user ? .trailing : .leading)

            if message.messageRole == .assistant {
                Spacer(minLength: TheaSpacing.jumbo)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(messageAccessibilityLabel)
        .accessibilityHint(message.messageRole == .assistant ? "AI response" : "Your message")
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        // Context menu for full action set
        .contextMenu { messageContextMenu }
    }

    // MARK: - Message Content

    @ViewBuilder
    private var messageContent: some View {
        let text = message.content.textValue

        if message.messageRole == .assistant {
            VStack(alignment: .leading, spacing: TheaSpacing.sm) {
                // Collapsible thinking trace (from extended thinking / adaptive thinking)
                if let thinkingTrace = message.metadata?.thinkingTrace, !thinkingTrace.isEmpty {
                    thinkingTraceView(thinkingTrace)
                }

                Markdown(text)
                    .markdownTheme(theaMarkdownTheme)
                    .markdownCodeSyntaxHighlighter(TheaCodeHighlighter())
                    .textSelection(.enabled)
            }
        } else {
            Text(text)
                .font(.theaBody)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private func thinkingTraceView(_ trace: String) -> some View {
        DisclosureGroup(isExpanded: $isThinkingExpanded) {
            Text(trace)
                .font(.theaCaption1)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .padding(.top, TheaSpacing.xs)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 10))
                Text("Thinking")
                    .font(.theaCaption2.weight(.medium))
            }
            .foregroundStyle(Color.theaPrimaryDefault.opacity(0.8))
        }
        .tint(Color.theaPrimaryDefault.opacity(0.6))
    }

    // MARK: - Metadata Row

    private var metadataRow: some View {
        HStack(spacing: 8) {
            if message.isEdited || message.branchIndex > 0 {
                BranchInfoBadge(isEdited: message.isEdited, branchIndex: message.branchIndex)
            }

            // Device origin badge (shown when message has device info)
            if let deviceName = message.deviceName {
                DeviceOriginBadge(
                    deviceName: deviceName,
                    deviceType: message.deviceType,
                    isCurrentDevice: message.deviceID == DeviceRegistry.shared.currentDevice.id
                )
            }

            if let model = message.model {
                Text(model)
                    .font(.theaCaption2)
                    .foregroundStyle(.secondary)
            }

            // Token count display
            if let tokenCount = message.tokenCount {
                let inputTokens = message.metadata?.inputTokens
                let tokenText = inputTokens != nil
                    ? "\(Self.formatTokenCount(inputTokens!))→\(Self.formatTokenCount(tokenCount))"
                    : "\(Self.formatTokenCount(tokenCount)) tokens"
                Text(tokenText)
                    .font(.theaCaption2)
                    .foregroundStyle(.tertiary)
            }

            // Confidence badge with hallucination warning
            if let confidence = message.metadata?.confidence, confidence > 0 {
                HStack(spacing: 2) {
                    let hasHallucinationFlags = !(message.metadata?.hallucinationFlags ?? []).isEmpty
                    Image(systemName: hasHallucinationFlags
                        ? "exclamationmark.triangle.fill"
                        : confidence >= 0.8 ? "checkmark.shield.fill" : "shield")
                        .font(.system(size: 8))
                    Text("\(Int(confidence * 100))%")
                        .font(.theaCaption2)
                }
                .foregroundStyle(confidence >= 0.8 ? Color.theaSuccess : confidence >= 0.5 ? Color.theaWarning : Color.theaError)
                .help(confidenceHelpText)
            }

            // Respect timestampDisplay setting
            if settingsManager.timestampDisplay != "hidden" {
                if settingsManager.timestampDisplay == "relative" {
                    Text(message.timestamp, format: .relative(presentation: .named))
                        .font(.theaCaption2)
                        .foregroundStyle(.secondary)
                } else {
                    // "absolute" — show exact time
                    Text(message.timestamp, format: .dateTime.hour().minute())
                        .font(.theaCaption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Hover Action Bar

    #if os(macOS)
        /// Compact action bar shown below the message bubble on hover
        private var hoverActionBar: some View {
            HStack(spacing: 2) {
                // Copy
                actionButton(
                    icon: showCopiedFeedback ? "checkmark" : "doc.on.doc",
                    color: showCopiedFeedback ? Color.theaSuccess : .secondary,
                    help: "Copy"
                ) {
                    copyToClipboard()
                }

                // Edit (user messages) / Regenerate (assistant messages)
                if message.messageRole == .user {
                    actionButton(icon: "pencil", color: .secondary, help: "Edit & resend") {
                        if let onEdit { onEdit(message) } else { onAction?(.edit, message) }
                    }
                } else {
                    actionButton(icon: "arrow.clockwise", color: .secondary, help: "Regenerate") {
                        if let onRegenerate { onRegenerate(message) } else { onAction?(.regenerate, message) }
                    }
                }

                // Rewrite (assistant only: rephrase, shorten, expand)
                if message.messageRole == .assistant {
                    Menu {
                        Button { onAction?(.rewrite(.shorter), message) } label: {
                            Label("Make shorter", systemImage: "arrow.down.right.and.arrow.up.left")
                        }
                        Button { onAction?(.rewrite(.longer), message) } label: {
                            Label("Make longer", systemImage: "arrow.up.left.and.arrow.down.right")
                        }
                        Button { onAction?(.rewrite(.simpler), message) } label: {
                            Label("Simplify", systemImage: "text.badge.minus")
                        }
                        Button { onAction?(.rewrite(.moreDetailed), message) } label: {
                            Label("More detailed", systemImage: "text.badge.plus")
                        }
                        Button { onAction?(.rewrite(.moreFormal), message) } label: {
                            Label("More formal", systemImage: "textformat")
                        }
                        Button { onAction?(.rewrite(.moreCasual), message) } label: {
                            Label("More casual", systemImage: "face.smiling")
                        }
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.plain)
                    .help("Rewrite")
                    .accessibilityLabel("Rewrite response")
                }

                // Continue from here
                actionButton(icon: "arrow.right.to.line", color: .secondary, help: "Continue from here") {
                    onAction?(.continueFromHere, message)
                }

                // More menu (overflow)
                Menu {
                    Button { onAction?(.splitConversation, message) } label: {
                        Label("Split conversation here", systemImage: "scissors")
                    }

                    Button { onAction?(.selectText, message) } label: {
                        Label("Select text", systemImage: "selection.pin.in.out")
                    }

                    Divider()

                    Button { onAction?(.readAloud, message) } label: {
                        Label("Read aloud", systemImage: "speaker.wave.2")
                    }

                    Button { onAction?(.shareMessage, message) } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }

                    Button { onAction?(.pinMessage, message) } label: {
                        Label("Pin message", systemImage: "pin")
                    }

                    Divider()

                    Button(role: .destructive) { onAction?(.deleteMessage, message) } label: {
                        Label("Delete message", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .help("More actions")
                .accessibilityLabel("More actions")
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }

        /// Reusable small action button for the hover bar
        private func actionButton(icon: String, color: Color, help: String, action: @escaping () -> Void) -> some View {
            Button(action: action) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(color)
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .help(help)
            .accessibilityLabel(help)
        }
    #endif

}

// MARK: - MessageBubble + Context Menu

extension MessageBubble {
    @ViewBuilder
    var messageContextMenu: some View {
        Button { copyToClipboard() } label: {
            Label("Copy text", systemImage: "doc.on.doc")
        }

        if message.messageRole == .assistant {
            Button { copyAsMarkdown() } label: {
                Label("Copy as Markdown", systemImage: "doc.richtext")
            }
        }

        Divider()

        if message.messageRole == .user {
            Button {
                if let onEdit { onEdit(message) } else { onAction?(.edit, message) }
            } label: {
                Label("Edit & resend", systemImage: "pencil")
            }
        }

        if message.messageRole == .assistant {
            Button {
                if let onRegenerate { onRegenerate(message) } else { onAction?(.regenerate, message) }
            } label: {
                Label("Regenerate", systemImage: "arrow.clockwise")
            }

            Menu("Rewrite") {
                Button { onAction?(.rewrite(.shorter), message) } label: {
                    Label("Shorter", systemImage: "arrow.down.right.and.arrow.up.left")
                }
                Button { onAction?(.rewrite(.longer), message) } label: {
                    Label("Longer", systemImage: "arrow.up.left.and.arrow.down.right")
                }
                Button { onAction?(.rewrite(.simpler), message) } label: {
                    Label("Simpler", systemImage: "text.badge.minus")
                }
                Button { onAction?(.rewrite(.moreDetailed), message) } label: {
                    Label("More detailed", systemImage: "text.badge.plus")
                }
                Button { onAction?(.rewrite(.moreFormal), message) } label: {
                    Label("Formal tone", systemImage: "textformat")
                }
                Button { onAction?(.rewrite(.moreCasual), message) } label: {
                    Label("Casual tone", systemImage: "face.smiling")
                }
            }

            Menu("Retry with model") {
                Button { onAction?(.retryWithModel("gpt-4o"), message) } label: { Text("GPT-4o") }
                Button { onAction?(.retryWithModel("claude-4-sonnet"), message) } label: { Text("Claude 4 Sonnet") }
                Button { onAction?(.retryWithModel("gemini-2.5-pro"), message) } label: { Text("Gemini 2.5 Pro") }
                Button { onAction?(.retryWithModel("local"), message) } label: { Text("Local model") }
            }
        }

        Divider()

        Button { onAction?(.continueFromHere, message) } label: {
            Label("Continue from here", systemImage: "arrow.right.to.line")
        }

        Button { onAction?(.splitConversation, message) } label: {
            Label("Split conversation here", systemImage: "scissors")
        }

        Divider()

        Button { onAction?(.readAloud, message) } label: {
            Label("Read aloud", systemImage: "speaker.wave.2")
        }

        Button { onAction?(.shareMessage, message) } label: {
            Label("Share", systemImage: "square.and.arrow.up")
        }

        Button { onAction?(.pinMessage, message) } label: {
            Label("Pin message", systemImage: "pin")
        }

        Button { onAction?(.selectText, message) } label: {
            Label("Select text", systemImage: "selection.pin.in.out")
        }

        Divider()

        Button(role: .destructive) { onAction?(.deleteMessage, message) } label: {
            Label("Delete message", systemImage: "trash")
        }
    }

    func copyToClipboard() {
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

    func copyAsMarkdown() {
        #if os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(message.content.textValue, forType: .string)
        #else
            UIPasteboard.general.string = message.content.textValue
        #endif
    }

    var messageAccessibilityLabel: String {
        let role = message.messageRole == .user ? "You" : "Thea"
        let time = message.timestamp.formatted(.dateTime.hour().minute())
        let content = message.content.textValue
        let truncated = content.count > 200 ? String(content.prefix(200)) + "..." : content
        return "\(role), \(time): \(truncated)"
    }

    private var confidenceHelpText: String {
        guard let confidence = message.metadata?.confidence else { return "" }
        let flags = message.metadata?.hallucinationFlags ?? []
        var text = "Confidence: \(Int(confidence * 100))%"
        if !flags.isEmpty {
            let highRisk = flags.filter { $0.riskLevel == .high }.count
            let medRisk = flags.filter { $0.riskLevel == .medium }.count
            if highRisk > 0 { text += "\n\(highRisk) high-risk claim(s) flagged" }
            if medRisk > 0 { text += "\n\(medRisk) medium-risk claim(s) flagged" }
        }
        return text
    }
}

// MARK: - MessageBubble + Helpers

extension MessageBubble {
    /// Format token counts compactly: 1234 → "1.2K", 500 → "500"
    static func formatTokenCount(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000.0)
        }
        return "\(count)"
    }
}

// MARK: - MessageBubble + Styling

extension MessageBubble {
    var densityHorizontalPadding: CGFloat {
        switch settingsManager.messageDensity {
        case "compact": TheaSpacing.md
        case "spacious": TheaSpacing.xl
        default: TheaSpacing.lg
        }
    }

    var densityVerticalPadding: CGFloat {
        switch settingsManager.messageDensity {
        case "compact": TheaSpacing.sm
        case "spacious": TheaSpacing.lg
        default: TheaSpacing.md
        }
    }

    var backgroundColor: Color {
        switch message.messageRole {
        case .user:
            .theaUserBubble
        case .assistant:
            .theaAssistantBubble
        case .system:
            .theaSurface
        }
    }

    var foregroundColor: Color {
        switch message.messageRole {
        case .user:
            // Adaptive: ensures readability on user bubble in both light and dark modes
            Color(white: 1.0)
        case .assistant, .system:
            .primary
        }
    }

    var theaMarkdownTheme: MarkdownUI.Theme {
        let config = AppConfiguration.shared.themeConfig
        return MarkdownUI.Theme()
            .text {
                FontSize(config.bodySize)
            }
            .code {
                FontSize(config.codeInlineSize)
                BackgroundColor(.theaSurface)
            }
            .codeBlock { configuration in
                CodeBlockView(configuration: configuration)
            }
            .heading1 { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontWeight(.bold)
                        FontSize(config.title1Size)
                    }
                    .padding(.bottom, 8)
            }
            .heading2 { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontWeight(.semibold)
                        FontSize(config.title2Size)
                    }
                    .padding(.bottom, 6)
            }
            .heading3 { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontWeight(.semibold)
                        FontSize(config.title3Size)
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
