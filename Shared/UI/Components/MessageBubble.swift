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
            Markdown(text)
                .markdownTheme(theaMarkdownTheme)
                .markdownCodeSyntaxHighlighter(TheaCodeHighlighter())
                .textSelection(.enabled)
        } else {
            Text(text)
                .font(.theaBody)
                .textSelection(.enabled)
        }
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
                    color: showCopiedFeedback ? .green : .secondary,
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

    // MARK: - Context Menu

    @ViewBuilder
    private var messageContextMenu: some View {
        // --- Clipboard ---
        Button { copyToClipboard() } label: {
            Label("Copy text", systemImage: "doc.on.doc")
        }

        if message.messageRole == .assistant {
            Button { copyAsMarkdown() } label: {
                Label("Copy as Markdown", systemImage: "doc.richtext")
            }
        }

        Divider()

        // --- Edit / Regenerate ---
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

            // Rewrite submenu
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

            // Change model submenu
            Menu("Retry with model") {
                Button { onAction?(.retryWithModel("gpt-4o"), message) } label: { Text("GPT-4o") }
                Button { onAction?(.retryWithModel("claude-4-sonnet"), message) } label: { Text("Claude 4 Sonnet") }
                Button { onAction?(.retryWithModel("gemini-2.5-pro"), message) } label: { Text("Gemini 2.5 Pro") }
                Button { onAction?(.retryWithModel("local"), message) } label: { Text("Local model") }
            }
        }

        Divider()

        // --- Navigation / Flow ---
        Button { onAction?(.continueFromHere, message) } label: {
            Label("Continue from here", systemImage: "arrow.right.to.line")
        }

        Button { onAction?(.splitConversation, message) } label: {
            Label("Split conversation here", systemImage: "scissors")
        }

        Divider()

        // --- Utility ---
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

        // --- Destructive ---
        Button(role: .destructive) { onAction?(.deleteMessage, message) } label: {
            Label("Delete message", systemImage: "trash")
        }
    }

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

    private func copyAsMarkdown() {
        #if os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(message.content.textValue, forType: .string)
        #else
            UIPasteboard.general.string = message.content.textValue
        #endif
    }

    // MARK: - Accessibility

    private var messageAccessibilityLabel: String {
        let role = message.messageRole == .user ? "You" : "Thea"
        let time = message.timestamp.formatted(.dateTime.hour().minute())
        let content = message.content.textValue
        let truncated = content.count > 200 ? String(content.prefix(200)) + "..." : content
        return "\(role), \(time): \(truncated)"
    }

    // MARK: - Density Padding

    private var densityHorizontalPadding: CGFloat {
        switch settingsManager.messageDensity {
        case "compact": TheaSpacing.md
        case "spacious": TheaSpacing.xl
        default: TheaSpacing.lg  // "comfortable"
        }
    }

    private var densityVerticalPadding: CGFloat {
        switch settingsManager.messageDensity {
        case "compact": TheaSpacing.sm
        case "spacious": TheaSpacing.lg
        default: TheaSpacing.md  // "comfortable"
        }
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

// MARK: - Message Action Enum

/// All possible actions on a message/turn
enum MessageAction {
    case copy
    case copyAsMarkdown
    case edit
    case regenerate
    case rewrite(RewriteStyle)
    case retryWithModel(String)
    case continueFromHere
    case splitConversation
    case readAloud
    case shareMessage
    case pinMessage
    case selectText
    case deleteMessage

    /// Rewrite styles for assistant responses
    enum RewriteStyle: String, CaseIterable {
        case shorter
        case longer
        case simpler
        case moreDetailed
        case moreFormal
        case moreCasual

        var label: String {
            switch self {
            case .shorter: "Shorter"
            case .longer: "Longer"
            case .simpler: "Simpler"
            case .moreDetailed: "More detailed"
            case .moreFormal: "More formal"
            case .moreCasual: "More casual"
            }
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
        Color.theaSurface.opacity(0.8)
    }

    private var codeBackground: Color {
        Color.theaSurface.opacity(0.5)
    }

    private var borderColor: Color {
        Color.secondary.opacity(0.2)
    }
}

// MARK: - Code Syntax Highlighter for MarkdownUI

struct TheaCodeHighlighter: CodeSyntaxHighlighter {
    func highlightCode(_ code: String, language: String?) -> Text {
        Text(code)
            .font(.system(.body, design: .monospaced))
    }
}
